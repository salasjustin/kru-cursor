// xai image backend for gen-asset.ts (graphic-designer's generator): Grok
// Imagine stills and edits over xAI's REST API. plain js, no deps (global
// fetch), so run.sh copies it beside the generator and node --test covers it
// without a TS loader (scripts/asset/xai.test.mjs).
//
// official source: docs.x.ai → Inference API → Images (POST /v1/images/generations,
// POST /v1/images/edits) and Model Capabilities → Image Generation. re-read them
// before changing a field or a model id — do not trust memory. MODELS.md cites both.
//
// the key is read from XAI_API_KEY in the environment only, sent in the
// Authorization header, and never printed: errors carry the status and the
// response body, never the request.

export const XAI_BASE = "https://api.x.ai/v1"
// first is the pick, the rest the fallbacks tried in order when the api rejects
// the model (grok-imagine-image-2.0 → grok-imagine-image, 1.0)
export const XAI_IMAGE_MODELS = ["grok-imagine-image-2.0", "grok-imagine-image"]
// the only model the api accepts `quality` on (Image Generation → Quality)
const QUALITY_MODELS = new Set(["grok-imagine-image-2.0"])
const ASPECTS = new Set(["1:1", "3:4", "4:3", "9:16", "16:9", "2:3", "3:2", "9:19.5", "19.5:9", "9:20", "20:9", "1:2", "2:1", "21:9", "5:2", "auto"])
const RESOLUTIONS = new Set(["1k", "1.5k", "2k"])
const QUALITIES = new Set(["low", "medium", "auto"])

// pickBackend decides which backend a gen-asset run uses. xai when the key is
// set and the run is a still (no video, no cutout) on no explicit google model,
// or on an explicit grok-imagine-* model or `--backend xai`. without the key it
// is always google — the existing backend — and `note` says why when the run
// asked for xai.
export function pickBackend({ env = {}, backend, model, isVideo = false, isCutout = false }) {
  const hasKey = Boolean(env.XAI_API_KEY)
  const asked = backend === "xai" || (typeof model === "string" && model.startsWith("grok-imagine"))
  if (isVideo || isCutout) return { backend: "google", note: asked ? "xai backend covers stills and edits only; using the existing path" : null }
  if (backend === "google") return { backend: "google", note: null }
  if (!hasKey) return { backend: "google", note: asked ? "XAI_API_KEY is not set; falling back to the Google backend" : null }
  if (asked || model === undefined) return { backend: "xai", note: null }
  return { backend: "google", note: null }
}

// buildRequest returns the fetch arguments for one call: a generation, or an
// edit when inputB64 is given (sent as a base64 data url, which the edits
// endpoint accepts in image.url)
export function buildRequest({ apiKey, model, prompt, aspect, resolution, quality, inputB64, inputMime = "image/png" }) {
  if (!apiKey) throw new Error("xai: XAI_API_KEY is not set")
  if (!prompt) throw new Error("xai: a prompt is required")
  const body = { model, prompt, n: 1, response_format: "b64_json" }
  if (aspect && ASPECTS.has(aspect)) body.aspect_ratio = aspect
  const res = resolution?.toLowerCase()
  if (res && RESOLUTIONS.has(res)) body.resolution = res
  if (quality && QUALITIES.has(quality) && QUALITY_MODELS.has(model)) body.quality = quality
  if (inputB64) body.image = { url: `data:${inputMime};base64,${inputB64}`, type: "image_url" }
  return {
    url: `${XAI_BASE}/images/${inputB64 ? "edits" : "generations"}`,
    init: {
      method: "POST",
      headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" },
      body: JSON.stringify(body),
    },
  }
}

// a rejection that names the model is worth one retry on the next model; any
// other failure (auth, quota, a refused prompt) would fail the same way again
const modelRejected = (status, text) =>
  status === 404 || ((status === 400 || status === 422) && /model/i.test(text) && /not found|does not exist|unknown|not available|no access/i.test(text))

// generate returns the image bytes, trying each model in XAI_IMAGE_MODELS order
// (or just `model` when one is named) until one is accepted
export async function generate({ apiKey, prompt, model, aspect, resolution, quality, inputB64, inputMime, fetchImpl = globalThis.fetch, log = () => {} }) {
  const models = model ? [model] : XAI_IMAGE_MODELS
  let last = ""
  for (const m of models) {
    const { url, init } = buildRequest({ apiKey, model: m, prompt, aspect, resolution, quality, inputB64, inputMime })
    const resp = await fetchImpl(url, init)
    const text = await resp.text()
    if (!resp.ok) {
      last = `xai ${m}: ${resp.status} ${text.slice(0, 300)}`
      if (modelRejected(resp.status, text) && m !== models.at(-1)) {
        log(`${last} — trying ${models[models.indexOf(m) + 1]}`)
        continue
      }
      throw new Error(last)
    }
    let json
    try {
      json = JSON.parse(text)
    } catch {
      throw new Error(`xai ${m}: response is not json`)
    }
    const item = json?.data?.[0]
    if (item?.b64_json) return { bytes: Buffer.from(item.b64_json, "base64"), model: json.model ?? m }
    if (item?.url) {
      const img = await fetchImpl(item.url)
      if (!img.ok) throw new Error(`xai ${m}: image download failed: ${img.status}`)
      return { bytes: Buffer.from(await img.arrayBuffer()), model: json.model ?? m }
    }
    throw new Error(`xai ${m}: returned no image`)
  }
  throw new Error(last || "xai: no model to try")
}
