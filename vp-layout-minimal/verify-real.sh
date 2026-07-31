#!/usr/bin/env bash
# Real CLI verification for the vite-plus issue.
# The same package installed by `vp install -g` vs `npm install`:
#   - vp layout  (packages/<name>#<installId>/) -> Node import FAILS (truncated at #)
#   - npm layout (node_modules/<name>/)        -> Node import OK
#
# Requires: vp (v0.2.6+), npm, node. Cleans up after itself.
set -euo pipefail

PKG="ms"
NODE="$(command -v node)"
VITE_PLUS_HOME="${VITE_PLUS_HOME:-$HOME/.vite-plus}"
TMP_PROJ="$(mktemp -d)"

cleanup() {
  vp uninstall -g "$PKG" >/dev/null 2>&1 || true
  rm -rf "$TMP_PROJ"
}
trap cleanup EXIT

echo "=== A. vp install -g $PKG (v0.2.6+ layout) ==="
vp install -g "$PKG" >/dev/null
DIR="$(find "$VITE_PLUS_HOME/packages" -maxdepth 1 -name "${PKG}#*" -type d | head -1)"
ENTRY="$(find "$DIR" -path "*/node_modules/$PKG/index.js" 2>/dev/null | head -1)"
echo "install dir: $DIR"
echo "entry:       $ENTRY"

echo
echo "--- node import (path contains #) ---"
"$NODE" -e "import('$ENTRY').then(()=>console.log('OK')).catch(e=>console.log('FAIL:', e.code))" || true

echo "--- node import (%23-escaped file URL) ---"
"$NODE" -e "import('file://$ENTRY'.replace(/#/g,'%23')).then(()=>console.log('OK')).catch(e=>console.log('FAIL:', e.code))"

echo
echo "=== B. npm install $PKG (control, no #) ==="
cd "$TMP_PROJ"
npm init -y >/dev/null 2>&1
npm install "$PKG" --no-audit --no-fund >/dev/null 2>&1
"$NODE" -e "import('$TMP_PROJ/node_modules/$PKG/index.js').then(()=>console.log('OK')).catch(e=>console.log('FAIL:', e.code))"
