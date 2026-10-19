---
name: kru-react-email
description: React Email 6 recipes. Use when writing or reviewing an email template, a `render()` call, or the code that sends one, in a repo with `react-email` or `@react-email/*` in `package.json`. Not MJML, not jsx-email.
---

**An email renders once, on the server, into a client you don't control — and React Email's own Tailwind decides what reaches it.** Its `<Tailwind>` is a second Tailwind that compiles at render time against the `config` prop and nothing else; a class it can't resolve stays in the markup as a bare `class=` that no inbox will ever style, and nothing fails. The preview server is the one place that hides the rest: it serves `static/`, and what it draws is the HTML part; the plain-text part your recipients' clients may fall back to sits only in its code panel's `md` tab. So check the output of `render()`, not the preview.

Reproduced on **`react-email@6.11.1`** (`@react-email/render@2.1.0`, `@react-email/ui@6.11.1`) with `react@19.3.0` and `resend@6.32.1`, 2026-10-10. Re-verify after a minor bump.

## Import from `react-email`
Components, `render`, `pixelBasedPreset` and `toPlainText` all export from **`react-email`**. **`@react-email/components`** — what most examples online, and older Context7 snippets, import from — is deprecated on npm at 1.0.12. In a repo still on it, keep its imports consistent within a file and move a file whole.

## `render()` is async
```tsx
const html = render(<Welcome name="Ann" />)   // Promise
`${html}`                                     // "[object Promise]"
```
Typed code catches it at a `string` parameter. Untyped code catches it nowhere: a nodemailer `html:` or a template literal sends the literal text `[object Promise]`. **`await` every `render()`.**

## Tailwind here is not the app's Tailwind
| you write | what ships |
|---|---|
| `<Tailwind>` with no preset, `text-base p-4` | `font-size:1rem;padding:1rem`. Client support for `rem` is uneven (caniemail.com → `rem`). **`config={{ presets: [pixelBasedPreset] }}`** gives `16px`/`16px` |
| `bg-brand` defined in the app's `@theme` or `tailwind.config` | `class="bg-brand"` with **no style at all**. With `text-white` beside it, you get white text on white. The email's Tailwind never reads the app's CSS |
| `` className={`text-${c}-500`} `` | **works**: classes are resolved from the rendered string at render time. The app-side scan that drops this belongs to the `tailwind` skill and doesn't apply here |
| `sm:text-lg` with the preset | the `<style>` rule's sizes convert (`font-size:18px`), its breakpoint doesn't: `@media (min-width:40rem)`. With no `<Head />` inside `<Tailwind>`, `render()` throws instead |

**Brand values go into the email's `config` as literal values** (`theme.extend.colors.brand: '#007bff'`), from one module every template imports. The app's token file is CSS custom properties, and `var()` support in mail clients is too patchy to rely on (caniemail.com). Grep the output for `class="` after any theme change: a surviving class with no style beside it names an unresolved token.

## The plain-text part is a different document
```tsx
await render(<Order />, { plainText: true })
// <Preview>Your code is 123456</Preview>   → absent (Preview is data-skip-in-text)
// <Row><Column>Qty</Column><Column>Price</Column></Row>   → "QtyPrice"
// <Button href=…>Reset</Button><Link href=…>Help</Link>   → "Reset https://…?t=abcHelp https://…"
```
Anything that appears only in the preview, such as a code, is missing from the text part. Columns and adjacent inline links run together with no separator. Where the text part matters, as with an OTP or an order total, the value belongs in the body, and each column's content ends in its own block element. Read the `plainText` output once for every template that has a table.

Who produces the text part depends on the provider:
- **Resend `react:`**: the SDK renders HTML only, and Resend's API derives the text part from that HTML when `text` is absent. That derivation is Resend's, not `plainText: true`'s.
- **Nodemailer, SES and the rest**: they send the parts you pass. Pass `text: await render(el, { plainText: true })` beside `html`, or there is no text part.

## `<Markdown>` does not sanitize
```tsx
<Markdown>{'Hi <img src=x onerror=…> [click](javascript:alert(1)) <a href="https://evil.test">bank</a>'}</Markdown>
// → the <img>, the javascript: href and the foreign <a> all ship verbatim
```
User-supplied text rendered through `<Markdown>`, such as a comment body in a notification, lets its author put arbitrary markup and links into mail sent from your domain. Mail clients strip scripts, not phishing links. Put user text in JSX children instead (`<Text>{body}</Text>`), where React escapes it (`<b>` ships as `&lt;b&gt;`), or sanitize it before it reaches `<Markdown>`.

## Every URL absolute, from the sending environment
The preview server serves `emails/static/` at `/static/`, so `<Img src="/static/logo.png">` looks right in `email dev` and is broken in every inbox. The `NODE_ENV === 'production' ? cdn : ''` base-URL pattern ships relative URLs from every non-production send: a staging signup, a local password reset to a real address. Read the origin from an env var every sending environment sets, and apply it to `<Img>`, `<Link>` and `<Button>` alike.

## Consult current docs (official sources first)
- **`https://react.email/docs/llms.txt`**: first-party. Its `llms-full.txt` carries the component catalog.
- **Resend's own agent skill**, `resend/react-email` → `skills/kru-react-email/` (MIT): the component, styling, i18n, sending and editor reference. Its "ask the user first" step is written for a chat session. A seat takes brand values and the production origin from the brief, and reports a missing one as a gap.
- **Context7** (`/resend/react-email`), for version-sensitive API details.
- **caniemail.com**, for whether a CSS property reaches a given client.

## Not this skill's job
- **The provider**: domain verification, webhooks, suppression, rate limits. These belong to the provider's docs (`https://resend.com/docs/llms.txt` for Resend).
- **The queue or cron that sends**: the platform seat's.
- **App UI**: components mounted in the app are `kru-react-ui-builder`'s, against the token file. An email template never mounts there.
- **The visual editor** (`@react-email/editor`): its own package, covered by upstream's `EDITOR.md`.
