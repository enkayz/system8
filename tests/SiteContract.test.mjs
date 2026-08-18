import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../", import.meta.url);
const read = (path) => readFile(new URL(path, root), "utf8");

test("the web surface presents the System 8 M365 operator harness", async () => {
  const [app, html] = await Promise.all([read("src/App.tsx"), read("index.html")]);
  assert.match(html, /System 8 Microsoft 365 Operator Harness/);
  assert.match(app, /Microsoft 365 Operator Harness/);
  assert.match(app, /Run the verified fixture harness/);
  assert.match(app, /m365-license-optimizer/);
  assert.match(app, /m365-security-baseline/);
  assert.match(app, /m365-migration-estimator/);
});

test("the Netlify frontend is static and does not require Convex", async () => {
  const [main, app, pkg, netlify] = await Promise.all([
    read("src/main.tsx"),
    read("src/App.tsx"),
    read("package.json"),
    read("netlify.toml"),
  ]);
  assert.doesNotMatch(main + app, /ConvexReactClient|convex\/react|VITE_CONVEX_URL/);
  assert.doesNotMatch(pkg, /"convex"|"convex-helpers"/);
  assert.match(netlify, /command\s*=\s*"npm run build"/);
  assert.match(netlify, /publish\s*=\s*"dist"/);
});

test("the site exposes source, installer and safety boundaries", async () => {
  const app = await read("src/App.tsx");
  assert.match(app, /github\.com\/enkayz\/system8/);
  assert.match(app, /raw\.githubusercontent\.com\/enkayz\/system8\/main\/tools\/s8\/install\.ps1/);
  assert.match(app, /Read-only by design/);
  assert.match(app, /No tenant credentials/);
});
