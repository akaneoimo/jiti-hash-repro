// Entry module: imports one of jiti's own submodules.
// The resolved path lands under `node_modules/jiti/`, which hits jiti's
// `isNativeRe` branch (native import, NO transpile fallback).
import "./node_modules/jiti/lib/jiti-static.mjs";

export const ok = true;
