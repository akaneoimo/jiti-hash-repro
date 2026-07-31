---
title: Cannot load a module from a directory whose path contains '#' (native import treats it as URL fragment)
labels: bug
---

## Description

jiti fails to load a module when its resolved absolute path contains the `#` character
(legal in filesystem paths, but the URL fragment separator). The native import path passes
the **raw path string** to Node's `import()`, which parses it as a URL and truncates at `#`
-> `ERR_MODULE_NOT_FOUND`.

Notably, jiti's own `_resolve` handles this correctly via `pathToFileURL` (which
percent-encodes `#` as `%23`); only the native import path skips the escaping. And the
`isNativeRe` branch (`node_modules/jiti` / `node_modules/typescript`) has **no transpile
fallback**, so those cases fail outright instead of being rescued.

The exact same files load fine when the directory name has no `#`.

## Reproduction

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

# 4. Run: directory contains `#` -> FAIL
node repro.mjs
# -> FAIL: Cannot find module '...' (path truncated at #)

# 5. Control: same files, directory without `#` -> OK
cp -R '/tmp/jiti#repro' /tmp/jitirepro && cd /tmp/jitirepro
node repro.mjs
# -> OK [ 'ok' ]
```

Also reproducible by `%23`-escaping test: `import()` of the same file with `#` -> `%23` in a
`file://` URL succeeds.

## Environment

- jiti 2.7.0
- Node.js 24.18.1 (behavior is Node's standard URL semantics, reproduces across recent versions)
- macOS arm64

## Impact

Any project whose module graph is installed under a path containing `#` cannot be loaded.
Concrete case: the `pi` coding agent (`@earendil-works/pi-coding-agent`, Node mode) is installed
by `vite-plus` at `packages/@earendil-works/pi-coding-agent#<installId>/`. Its extensions that
lazy-load module graphs touching `node_modules/jiti` fail unrecoverably ("stale module cache").
Works fine when the package is copied to a path without `#`.

## Suggested fix

In the native import path, mirror `_resolve`: convert absolute paths with `pathToFileURL`
(so `#` -> `%23`) before handing them to `import()`.
