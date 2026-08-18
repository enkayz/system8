import assert from "node:assert/strict";
import { readFile, readdir } from "node:fs/promises";
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
  const [app, bootstrap, cli] = await Promise.all([
    read("src/App.tsx"),
    read("tools/s8/install.ps1"),
    read("tools/s8/s8.ps1"),
  ]);
  assert.match(app, /github\.com\/enkayz\/system8/);
  assert.doesNotMatch(app, /raw\.githubusercontent\.com\/enkayz\/system8\/main\//);
  assert.doesNotMatch(app, /\|\s*iex/i);
  assert.match(app, /Get-FileHash/);
  assert.match(app, /SHA256 mismatch/);
  assert.doesNotMatch(bootstrap, /raw\.githubusercontent\.com\/enkayz\/system8\/main\//);
  assert.match(bootstrap, /Get-FileHash/);
  assert.match(cli, /120a14e61a86a693545f1709e35cafd483b2e175\/tools\/s8\/manifests\/stable\.json/);
  assert.match(cli, /6fc931ec2802b39111f8261553f708ec6b5b84fdc33ce95364b58cbadfd1bbc6/);
  assert.match(app, /Read-only by design/);
  assert.match(app, /No tenant credentials/);
});

test("every catalogue command is provided by its package launcher", async () => {
  const app = await read("src/App.tsx");
  const entries = [...app.matchAll(/name: "([^"]+)", command: "([^"]+)"/g)];
  assert.equal(entries.length, 13);
  for (const [, packageName, command] of entries) {
    const installer = await read(`tools/s8/packages/${packageName}/install.ps1`);
    const executable = command.split(/\s+/)[0];
    assert.match(installer, new RegExp(`${executable}\\.cmd`, "i"), `${packageName} does not install ${executable}`);
  }
});

test("published installation guidance has no mutable admin execution path", async () => {
  const packageEntries = await readdir(new URL("../tools/s8/packages/", import.meta.url), { withFileTypes: true });
  const packageReadmes = await Promise.all(packageEntries.filter((entry) => entry.isDirectory()).map(async (entry) => {
    try { return await read(`tools/s8/packages/${entry.name}/README.md`); } catch { return ""; }
  }));
  const [readme, dashboardReadme, bootstrap, cli] = await Promise.all([
    read("README.md"),
    read("tools/s8/dashboard/README.md"),
    read("tools/s8/install.ps1"),
    read("tools/s8/s8.ps1"),
  ]);
  const publishedGuidance = readme + dashboardReadme + packageReadmes.join("\n");
  assert.doesNotMatch(publishedGuidance, /raw\.githubusercontent\.com\/enkayz\/system8\/main\//);
  assert.doesNotMatch(publishedGuidance, /ScriptBlock\]::Create\(\(irm/i);
  assert.doesNotMatch(publishedGuidance, /s8tenantdiff|s8secure/);
  assert.match(dashboardReadme, /e2719096d0cc3d5491622eb7adf9a855dcfdbd282e5ef490c50065c9884765a2/);
  assert.doesNotMatch(readme, /s8tenantdiff|s8secure/);
  assert.match(readme, /s8diff/);
  assert.match(readme, /s8baseline/);
  assert.doesNotMatch(bootstrap, /&\s*\$cli\s+install\s+admx/i);
  assert.match(cli, /120a14e61a86a693545f1709e35cafd483b2e175\/tools\/s8\/manifests\/stable\.json/);
  assert.match(cli, /6fc931ec2802b39111f8261553f708ec6b5b84fdc33ce95364b58cbadfd1bbc6/);
});

test("copied starter commands run without missing mandatory arguments", async () => {
  const app = await read("src/App.tsx");
  const commands = new Map([...app.matchAll(/name: "([^"]+)", command: "([^"]+)"/g)].map(([, name, command]) => [name, command]));
  assert.equal(commands.get("m365-tenant-diff"), "s8diff doctor");
  assert.equal(commands.get("m365-migration-estimator"), "s8migrate template");
  assert.equal(commands.get("m365-entitlement-advisor"), "s8entitlement template");
  assert.equal(commands.get("m365-access-explainer"), "s8access doctor");
  assert.equal(commands.get("m365-leaver-readiness"), "s8leaver doctor");
});
