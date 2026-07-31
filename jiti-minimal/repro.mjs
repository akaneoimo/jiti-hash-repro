// Repro script - fully portable (relative paths only).
// Run it from a directory that CONTAINS a `#` in its path -> fails.
// Run the same files from a directory WITHOUT `#` -> succeeds.
import { createJiti } from "jiti";

const jiti = createJiti(import.meta.url, { moduleCache: false });

try {
  const mod = await jiti.import("./entry.mjs");
  console.log("OK:", Object.keys(mod));
} catch (e) {
  console.log("FAIL:", e.message.split("\n")[0]);
}
