# vp layout repro

Demonstrates that vite-plus v0.2.6+'s install layout
(`packages/<name>#<installId>/`, containing a literal `#`) breaks Node ESM resolution,
while the same module installed the npm way works.

The layout here mimics what `vp install -g` produces under `~/.vite-plus/packages/`:

```
packages/@demo/my-pkg#a1b2c3d4/          <- vp layout (contains #)
  lib/node_modules/@demo/my-pkg/index.mjs
node_modules/@demo/my-pkg/index.mjs      <- npm layout (control, no #)
```

## Run

```bash
node repro.mjs
```

Expected output:

```
vp layout   (path contains #)       -> FAIL: Cannot find module '...' (truncated at #)
vp layout   (%23-escaped file URL)  -> OK ["ok"]
npm layout  (no #)                  -> OK ["ok"]
```

No dependencies, plain Node (tested with Node 24.18.1).
