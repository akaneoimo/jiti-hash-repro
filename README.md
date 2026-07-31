# jiti-hash-repro

Minimal reproduction for a module-loading failure caused by the `#` character in a package
install directory path.

## Background

- `vite-plus` v0.2.6 installs global packages to immutable `packages/<name>#<installId>/`
  directories (atomic install mechanism, [#1906](https://github.com/voidzero-dev/vite-plus/issues/1906)/[#1945](https://github.com/voidzero-dev/vite-plus/issues/1945)).
- `#` is legal in filesystem paths but is the **URL fragment separator**: Node's ESM loader
  truncates any path string at `#` when resolving it as a URL.
- `pi` (Node mode) is installed there; its extension `ask_user_question` lazy-loads a module
  graph that resolves into the package dir and fails via jiti native import (no fallback for
  `node_modules/jiti`) -> unrecoverable "stale module cache" error.
- Same files work from any path without `#`.

## Layout

| Path | What it is |
|---|---|
| `jiti-minimal/` | Standalone jiti repro (3 files + package.json). Put it at a path containing `#` -> fails; without `#` -> works. See its README. |
| `issue-jiti.md` | Issue body for **unjs/jiti** (native import should percent-encode `#`). |
| `issue-vite-plus.md` | Issue body for **voidzero-dev/vite-plus** (install dirs should not contain `#`). |

## Quick start

```bash
cd jiti-minimal
npm install
mkdir -p '/tmp/jiti#repro' && cp -R . '/tmp/jiti#repro/' && cd '/tmp/jiti#repro'
node repro.mjs          # -> FAIL: path truncated at #

mkdir -p /tmp/jitirepro && cp -R . /tmp/jitirepro/ && cd /tmp/jitirepro
node repro.mjs          # -> OK: [ 'ok' ]
```

## Environment tested

- jiti 2.7.0, Node.js 24.18.1, macOS arm64
- vp 0.2.6, pi 0.83.0 (Node mode)
