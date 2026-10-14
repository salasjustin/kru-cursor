// stdin is one outbound tracker field. exit 1 when it carries a secret, an
// email or a phone. the patterns are scripts/leak-patterns.mjs — the same
// list scripts/privacy-scan.mjs uses for secrets. nothing here is printed.
import { readFileSync } from "node:fs"
import { leakIn } from "./leak-patterns.mjs"

const text = readFileSync(0, "utf8")
process.exit(leakIn(text) ? 1 : 0)
