---
title: 'Global package install dirs `packages/<name>#<installId>` break Node ESM resolution (Pi extensions fail to load)'
labels: bug
---

## Description

Since v0.2.6, `vp install -g` writes packages to
`~/.vite-plus/packages/<name>#<installId>/` - the immutable `packages/#` prefix introduced for
atomic installs ([#1906](https://github.com/voidzero-dev/vite-plus/issues/1906), [#1945](https://github.com/voidzero-dev/vite-plus/issues/1945)).

The `#` character is legal in filesystem paths but is the **URL fragment separator**. Node's
ESM/CJS loaders parse path strings as URLs, so any module loaded from inside these directories
is truncated at `#` -> `ERR_MODULE_NOT_FOUND`:

- `node -e "import('<pkg>#<id>/.../index.js')"` -> `ERR_MODULE_NOT_FOUND` (path truncated at `#`)
- Escaping `#` as `%23` (file:// URL) -> works

Tools that load modules from the package at runtime (e.g. jiti-based extension loaders) fail
when their module graph resolves into the package directory.

## Concrete failure: Pi extensions

`pi` (`@earendil-works/pi-coding-agent`, **Node mode**) is installed here. Its extension
`ask_user_question` lazy-loads a TUI render graph; the graph's imports resolve into the package
dir and fail via jiti native import (which has **no fallback** for `node_modules/jiti`),
producing an unrecoverable "stale module cache" error on every invocation.

- Works fine when the package is copied to a path without `#` (e.g. `~/.pi/runtime/pi-coding-agent`).
- Bun binary mode (bundled virtual modules, no disk path resolution) is unaffected - only
  Node-mode execution breaks.
- Reinstalling Pi / the extension / restarting does not help (install dir still contains `#`).

## Reproduction

```bash
# 1. Install pi via vp (v0.2.6+); the install dir is:
#    ~/.vite-plus/packages/@earendil-works/pi-coding-agent#<uuid>/
vp install -g @earendil-works/pi-coding-agent

# 2. Direct check that Node cannot load from the # path:
node -e "import('<vite_plus_home>/packages/@earendil-works/pi-coding-agent#<id>/lib/node_modules/@earendil-works/pi-coding-agent/dist/index.js').then(()=>console.log('OK')).catch(e=>console.log(e.code))"
# -> ERR_MODULE_NOT_FOUND (truncated at #)
# with %23 escaping -> OK

# 3. End-to-end: install ask_user_question and invoke it
pi install npm:@juicesharp/rpiv-ask-user-question
# invoke the tool -> "the questionnaire UI cannot load - the host's module cache went stale..."
```

## Environment

- vp 0.2.6 (latest check shows 0.2.7)
- pi 0.83.0, Node.js 24.18.1
- macOS arm64

## Suggested fix

- Avoid `#` in install dir names (e.g. `name-<installId>` or `name/<installId>`); and/or
- Percent-encode (`#` -> `%23`) or pass `file://` URLs when Node-mode tools resolve package paths.
