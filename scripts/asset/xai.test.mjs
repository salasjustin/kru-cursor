// unit tests for the xai image backend (scripts/asset/xai.mjs): request
// building, backend choice and model fallback, against a mocked fetch — no
// network, no key. run: node --test scripts/asset/xai.test.mjs
import { test } from "node:test"
import assert from "node:assert/strict"
import { buildRequest, generate, pickBackend, XAI_IMAGE_MODELS } from "./xai.mjs"

const KEY = "xai-test-not-a-key"
const png = Buffer.from("fake-png-bytes")

// a fetch that records calls and answers from a queue of [status, body] pairs
function mockFetch(answers) {
  const calls = []
  const fn = async (url, init) => {
    calls.push({ url, init, body: init?.body ? JSON.parse(init.body) : null })
    const [status, body] = answers.shift() ?? [500, "no answer queued"]
    const text = typeof body === "string" ? body : JSON.stringify(body)
    return { ok: status >= 200 && status < 300, status, text: async () => text, arrayBuffer: async () => png }
  }
  fn.calls = calls
  return fn
}

test("a generation request: endpoint, auth header, body", () => {
  const { url, init } = buildRequest({ apiKey: KEY, model: "grok-imagine-image-2.0", prompt: "brass texture", aspect: "16:9", resolution: "2K", quality: "medium" })
  assert.equal(url, "https://api.x.ai/v1/images/generations")
  assert.equal(init.method, "POST")
  assert.equal(init.headers.Authorization, `Bearer ${KEY}`)
  assert.equal(init.headers["Content-Type"], "application/json")
  assert.deepEqual(JSON.parse(init.body), { model: "grok-imagine-image-2.0", prompt: "brass texture", n: 1, response_format: "b64_json", aspect_ratio: "16:9", resolution: "2k", quality: "medium" })
})

test("quality goes only to the model that takes it; unknown values are dropped", () => {
  const body = JSON.parse(buildRequest({ apiKey: KEY, model: "grok-imagine-image", prompt: "p", aspect: "7:5", resolution: "4K", quality: "medium" }).init.body)
  assert.deepEqual(body, { model: "grok-imagine-image", prompt: "p", n: 1, response_format: "b64_json" })
})

test("an edit sends the source as a base64 data url to /images/edits", () => {
  const { url, init } = buildRequest({ apiKey: KEY, model: "grok-imagine-image-2.0", prompt: "warm light", inputB64: "QUJD", inputMime: "image/jpeg" })
  assert.equal(url, "https://api.x.ai/v1/images/edits")
  assert.deepEqual(JSON.parse(init.body).image, { url: "data:image/jpeg;base64,QUJD", type: "image_url" })
})

test("no key, no request", () => {
  assert.throws(() => buildRequest({ apiKey: "", model: "m", prompt: "p" }), /XAI_API_KEY/)
})

test("generate decodes b64_json and reports the serving model", async () => {
  const f = mockFetch([[200, { model: "grok-imagine-image-2.0", data: [{ b64_json: png.toString("base64") }] }]])
  const out = await generate({ apiKey: KEY, prompt: "p", fetchImpl: f })
  assert.deepEqual(out.bytes, png)
  assert.equal(out.model, "grok-imagine-image-2.0")
  assert.equal(f.calls.length, 1)
  assert.equal(f.calls[0].body.model, XAI_IMAGE_MODELS[0])
})

test("a rejected model falls back to grok-imagine-image", async () => {
  const f = mockFetch([[404, { error: "model not found" }], [200, { data: [{ b64_json: png.toString("base64") }] }]])
  const logs = []
  const out = await generate({ apiKey: KEY, prompt: "p", quality: "low", fetchImpl: f, log: (l) => logs.push(l) })
  assert.deepEqual(f.calls.map((c) => c.body.model), ["grok-imagine-image-2.0", "grok-imagine-image"])
  assert.equal(f.calls[1].body.quality, undefined)
  assert.equal(out.model, "grok-imagine-image")
  assert.equal(logs.length, 1)
})

test("an auth failure does not retry, and the error never carries the key", async () => {
  const f = mockFetch([[401, { error: "invalid api key" }]])
  await assert.rejects(generate({ apiKey: KEY, prompt: "p", fetchImpl: f }), (err) => {
    assert.match(err.message, /401/)
    assert.ok(!err.message.includes(KEY))
    return true
  })
  assert.equal(f.calls.length, 1)
})

test("a url response is downloaded", async () => {
  const f = mockFetch([[200, { data: [{ url: "https://imgen.x.ai/tmp/a.jpg" }] }], [200, ""]])
  const out = await generate({ apiKey: KEY, prompt: "p", fetchImpl: f })
  assert.equal(f.calls[1].url, "https://imgen.x.ai/tmp/a.jpg")
  assert.equal(f.calls[1].init, undefined)
  assert.deepEqual(out.bytes, png)
})

test("backend choice: xai only with the key, stills only, google when asked", () => {
  const key = { XAI_API_KEY: KEY }
  assert.equal(pickBackend({ env: {} }).backend, "google")
  assert.equal(pickBackend({ env: key }).backend, "xai")
  assert.equal(pickBackend({ env: key, model: "imagen-4.0-generate-001" }).backend, "google")
  assert.equal(pickBackend({ env: key, model: "grok-imagine-image" }).backend, "xai")
  assert.equal(pickBackend({ env: key, backend: "google" }).backend, "google")
  assert.equal(pickBackend({ env: key, isVideo: true }).backend, "google")
  assert.equal(pickBackend({ env: key, isCutout: true }).backend, "google")
  const unset = pickBackend({ env: {}, backend: "xai" })
  assert.equal(unset.backend, "google")
  assert.match(unset.note, /XAI_API_KEY is not set/)
})
