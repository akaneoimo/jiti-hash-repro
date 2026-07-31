# vp layout minimal repro

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

## Real-environment verification (2026-08-01)

The same package (`ms@2.1.3`) installed by two package managers on macOS (Node 24.18.1):

**A. vp 0.2.6 - `vp install -g ms`**

Install dir:

```
~/.vite-plus/packages/ms#9102a239-bbfb-4e5d-ad83-72a676beec09/
  lib/node_modules/ms/package.json
```

```bash
node -e "import('<vite_plus_home>/packages/ms#9102a239-.../lib/node_modules/ms/index.js').then(m=>console.log('OK')).catch(e=>console.log(e.code))"
# -> FAIL: ERR_MODULE_NOT_FOUND (path truncated at #)

# %23-escaped file URL:
node -e "import('file://<vite_plus_home>/packages/ms%239102a239-.../lib/node_modules/ms/index.js').then(m=>console.log('OK')).catch(e=>console.log(e.code))"
# -> OK
```

**B. npm - `npm install ms`**

Install dir: `node_modules/ms/index.js` (no `#`)

```bash
node -e "import('/tmp/npm-ms-test/node_modules/ms/index.js').then(m=>console.log('OK')).catch(e=>console.log(e.code))"
# -> OK
```

Conclusion: the same package is loadable when installed by npm, and not when installed by vp.
