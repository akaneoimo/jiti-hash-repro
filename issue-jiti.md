---
title: 'Discussion: loading modules from paths containing "#" (URL fragment) - native import vs transpile fallback'
labels: question
---

## Context

I ran into an interesting edge case and wanted to discuss it rather than file it as a
definite bug: what should jiti do when a module's resolved path contains the `#` character?

`#` is perfectly legal in filesystem paths, but it is the **URL fragment separator**. When
jiti hands a raw path string to Node's native `import()`, Node parses it as a URL and
truncates at `#` -> `ERR_MODULE_NOT_FOUND`. On the other hand, jiti's own `_resolve` already
handles this correctly via `pathToFileURL` (which percent-encodes `#` as `%23`).

So today the behavior is inconsistent: most modules under a `#`-containing path are rescued
by the transpile fallback, but the `isNativeRe` branch (`node_modules/jiti` / `node_modules/typescript`)
has no fallback, so those fail outright. I'm curious whether this is the intended design or
something worth reconsidering.

## Reproduction

A runnable copy of this repro is available at
https://github.com/akaneoimo/jiti-hash-repro (see `jiti-minimal/`).

```bash
# 1. Put the repro at a path containing `#`
mkdir -p '/tmp/jiti#repro' && cd '/tmp/jiti#repro'
npm install jiti@2.7.0

# 2. Entry module: import jiti's own submodule (hits node_modules/jiti -> isNativeRe)
cat > entry.mjs <<'EOF'
import "./node_modules/jiti/lib/jiti-static.mjs";
export const ok = true;
EOF

# 3. Repro script
cat > repro.mjs <<'EOF'
import { createJiti } from "jiti";
const jiti = createJiti(import.meta.url, { moduleCache: false });
try {
  const mod = await jiti.import("./entry.mjs");
  console.log("OK", Object.keys(mod));
} catch (e) {
  console.log("FAIL:", e.message.split("\n")[0]);
}
EOF

# 4. Directory contains `#` -> FAIL
node repro.mjs
# -> FAIL: Cannot find module '...' (path truncated at #)

# 5. Control: same files, directory without `#` -> OK
cp -R '/tmp/jiti#repro' /tmp/jitirepro && cd /tmp/jitirepro
node repro.mjs
# -> OK [ 'ok' ]
```

Also observable at the Node level: `import()` of the same file works when `#` is escaped as
`%23` in a `file://` URL.

## Environment

- jiti 2.7.0
- Node.js 24.18.1 (the truncation itself is standard Node URL semantics, not Node-specific to this version)
- macOS arm64

## Why I care

A package manager (`vite-plus` v0.2.6+) installs global packages to
`packages/<name>#<installId>/` directories (atomic installs). A coding agent (`pi`, Node mode)
is installed there, and extensions that lazy-load module graphs touching `node_modules/jiti`
fail unrecoverably (their module cache ends up in a poisoned state). Copying the package to a
`#`-free path makes everything work, so the path character is the only variable.

## Open questions / possible directions

- Is supporting `#` in load paths in scope for jiti? (Bun and Node both accept percent-encoded
  file URLs, so escaping is viable.)
- If yes, a minimal change would be to mirror `_resolve` in the native import path: convert
  absolute paths with `pathToFileURL` (so `#` -> `%23`) before calling `import()`.
- If it's considered out of scope, a documented note would still help downstream tools that
  install packages into arbitrary paths.
