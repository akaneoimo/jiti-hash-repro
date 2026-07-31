---
title: 'Discussion: install layout `packages/<name>#<installId>` differs from every other package manager (literal "#" = URL fragment)'
labels: question
---

## Context

Since v0.2.6, `vp install -g` writes packages to
`~/.vite-plus/packages/<name>#<installId>/` - the immutable `packages/#` prefix introduced for
atomic installs ([#1906](https://github.com/voidzero-dev/vite-plus/issues/1906),
[#1945](https://github.com/voidzero-dev/vite-plus/issues/1945)).

I'd like to discuss one aspect of that layout: as far as I can tell, vp is the only major
package manager that puts a literal `#` (the URL fragment separator) into install paths.

## How other package managers lay out installs

| Manager | Global install path (typical) | Literal `#` in path? |
|---|---|---|
| npm | `$(npm prefix -g)/lib/node_modules/<name>/` | No |
| pnpm | content-addressed store (`<store>/v3/files/<hash>`), symlinked as `<name>/` | No |
| yarn | `node_modules/<name>/` (or `~/.yarn/berry/...`) | No |
| bun | `~/.bun/install/global/node_modules/<name>/` | No |
| **vite-plus** | `packages/<name>#<installId>/` | **Yes** |

`#` is legal in filesystem paths, but Node's ESM/CJS loaders parse path strings as URLs and
truncate at `#`:

- `node -e "import('<pkg>#<id>/.../index.js')"` -> `ERR_MODULE_NOT_FOUND` (truncated at `#`)
- Escaping `#` as `%23` (file:// URL) -> works

The practical consequence: the *same* package works when installed by npm/pnpm/yarn/bun, but
breaks when installed by vp, if anything at runtime resolves modules back into the install dir.
The atomic-install design could be kept without the URL hazard (e.g. `name-<installId>` or
`name/<installId>`).

## Observed case: Pi extensions

`pi` (`@earendil-works/pi-coding-agent`, Node mode) is installed here. Its extension
`ask_user_question` lazy-loads a TUI render graph; the graph's imports resolve into the package
dir and fail (via jiti native import, which has no fallback for `node_modules/jiti`), producing
an unrecoverable "stale module cache" error on every invocation.

- Works fine when the package is copied to a `#`-free path (e.g. `~/.pi/runtime/pi-coding-agent`).
- Bun binary mode (bundled virtual modules, no disk path resolution) is unaffected - only
  Node-mode execution is affected.
- Reinstalling Pi / the extension / restarting does not help (the install dir still contains `#`).

## Reproduction

Root cause in one line: vp's install layout puts a literal `#` (the URL fragment separator)
into package paths, which Node truncates when loading. The same package installed by
npm/pnpm/yarn/bun works fine (comparison above).

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

Additional repros in https://github.com/akaneoimo/jiti-hash-repro:

- `vp-layout-minimal/` - direct CLI repro, requires vp (v0.2.6+) and npm:
  `./verify-real.sh` installs the same package (`ms`) via `vp install -g` and `npm install`,
  then imports it from each layout (vp layout fails, npm layout works, `%23`-escape works).
  A zero-dependency simulated-layout version is also there (`node repro.mjs`).
- `jiti-minimal/` - jiti-side minimal repro: the failure surfaces through jiti's native import,
  which has no transpile fallback for `node_modules/jiti`.

## Environment

- vp 0.2.6 (latest check shows 0.2.7)
- pi 0.83.0, Node.js 24.18.1
- macOS arm64

## Open questions

- Was `#` in install dir names a deliberate choice, or an incidental separator? If deliberate,
  how should downstream Node-mode tooling be expected to handle it?
- Would aligning with common practice (no URL-special characters in install paths,
  e.g. `name-<installId>`) be acceptable? Happy to contribute the change.
