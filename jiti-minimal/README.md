# jiti minimal repro

jiti cannot load modules located under a directory whose path contains `#`.

The `#` character is legal in filesystem paths but is the **URL fragment separator**, so Node's
ESM loader truncates the path at `#` when jiti hands it a raw path string via native `import()`.
`node_modules/jiti/` / `node_modules/typescript/` paths go through jiti's `isNativeRe` branch
(native import, **no transpile fallback**) -> loading fails outright.

## Reproduce

```bash
# 1. Install jiti
npm install

# 2. Put this folder at a path containing `#` and run
mkdir -p '/tmp/jiti#repro' && cp -R . '/tmp/jiti#repro/' && cd '/tmp/jiti#repro'
node repro.mjs
# -> FAIL: Cannot find module '...' (path truncated at #)

# 3. Control: same files, path without `#`
mkdir -p /tmp/jitirepro && cp -R . /tmp/jitirepro/ && cd /tmp/jitirepro
node repro.mjs
# -> OK: [ 'ok' ]
```

## Files

- `entry.mjs` - imports `./node_modules/jiti/lib/jiti-static.mjs` (hits `isNativeRe`)
- `repro.mjs` - `jiti.import("./entry.mjs")`
- `package.json` - pins `jiti@2.7.0`

Environment tested: jiti 2.7.0, Node.js 24.18.1, macOS arm64.
