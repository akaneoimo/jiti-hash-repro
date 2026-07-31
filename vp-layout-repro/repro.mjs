// Repro: the same module, in three layouts.
//  1) vp layout:  packages/<name>#<installId>/...   -> FAIL (path truncated at #)
//  2) vp layout, %23-escaped file URL               -> OK
//  3) npm layout: node_modules/<name>/...           -> OK (no #)
//
// Mirrors what vp 0.2.6+ produces under ~/.vite-plus/packages/.
import { resolve } from "node:path";

const vpRel = "./packages/@demo/my-pkg#a1b2c3d4/lib/node_modules/@demo/my-pkg/index.mjs";
const npmRel = "./node_modules/@demo/my-pkg/index.mjs";

async function check(label, imp) {
  try {
    const m = await imp();
    console.log(label, "-> OK", JSON.stringify(Object.keys(m)));
  } catch (e) {
    console.log(label, "-> FAIL:", (e.code || e.message).split("\n")[0]);
  }
}

await check("vp layout   (path contains #)      ", () => import(vpRel));
await check(
  "vp layout   (%23-escaped file URL) ",
  () => import("file://" + resolve(import.meta.dirname, vpRel).replace(/#/g, "%23")),
);
await check("npm layout  (no #)                ", () => import(npmRel));
