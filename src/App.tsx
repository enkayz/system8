import { useMemo, useState } from "react";

type Tool = {
  name: string;
  command: string;
  category: "Governance" | "Change" | "Continuity" | "Planning";
  description: string;
  mode: string;
};

const installer = "$url='https://raw.githubusercontent.com/enkayz/system8/56a8f9ddbd0789aa8c957a1bc09424c310e77d29/tools/s8/install.ps1'; $path=Join-Path $env:TEMP 'system8-install.ps1'; Invoke-WebRequest -UseBasicParsing $url -OutFile $path; if((Get-FileHash $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne 'f331e7daec7cba05d26791823880016062e2c290c887d9a7a86e34361b9c9471'){Remove-Item $path -Force; throw 'SHA256 mismatch; installation stopped.'}; & $path";

const tools: Tool[] = [
  { name: "m365", command: "s8m365 full", category: "Governance", description: "Tenant, user, role, licence, labels and sharing inventory with evidence output.", mode: "Microsoft Graph · read-only" },
  { name: "m365-governance", command: "s8gov full", category: "Governance", description: "Review Entra, consent, Conditional Access, stale identities, Teams and SharePoint.", mode: "Microsoft Graph · read-only" },
  { name: "m365-license-optimizer", command: "s8license full", category: "Planning", description: "Find dormant or disabled assignments and customer-priced savings candidates.", mode: "Live or offline fixture" },
  { name: "m365-tenant-diff", command: "s8diff compare", category: "Change", description: "Capture normalized tenant snapshots and explain added, removed and changed configuration.", mode: "Capture + offline comparison" },
  { name: "m365-sharepoint-modernizer", command: "s8spmodern full", category: "Planning", description: "Inventory sites and libraries, surface scale and lifecycle flags, and prepare a modernization plan.", mode: "Live or offline fixture" },
  { name: "m365-security-baseline", command: "s8baseline full", category: "Governance", description: "Assess Conditional Access, privileged roles and enterprise application posture.", mode: "Live or offline fixture" },
  { name: "m365-migration-estimator", command: "s8migrate estimate", category: "Planning", description: "Estimate effort, elapsed time, risk and optional customer-priced cost from CSV input.", mode: "Offline · no tenant access" },
  { name: "m365-entitlement-advisor", command: "s8entitlement assess", category: "Planning", description: "Compare service-plan entitlements with explicit persona and capability requirements.", mode: "Microsoft Graph · read-only" },
  { name: "m365-change-impact", command: "s8changes full", category: "Change", description: "Prioritize service health and Message Center changes against observed tenant scale.", mode: "Microsoft Graph · read-only" },
  { name: "m365-copilot-readiness", command: "s8copilot full", category: "Planning", description: "Assess licensing, site lifecycle, collaboration risk and pilot readiness.", mode: "Microsoft Graph · read-only" },
  { name: "m365-access-explainer", command: "s8access explain", category: "Governance", description: "Trace a user's access through nested membership, applications, ownership and licensing.", mode: "Microsoft Graph · read-only" },
  { name: "m365-leaver-readiness", command: "s8leaver assess", category: "Continuity", description: "Map ownership, reporting, membership and OneDrive dependencies before offboarding.", mode: "Microsoft Graph · read-only" },
  { name: "m365-recovery-readiness", command: "s8resilience full", category: "Continuity", description: "Review emergency access, privileged redundancy, domains and application credential recovery.", mode: "Microsoft Graph · read-only" },
];

const categories = ["All", "Governance", "Change", "Continuity", "Planning"] as const;

function App() {
  const [category, setCategory] = useState<(typeof categories)[number]>("All");
  const [query, setQuery] = useState("");
  const [copied, setCopied] = useState<string | null>(null);
  const [copyError, setCopyError] = useState<string | null>(null);

  const filtered = useMemo(() => {
    const tokens = query.trim().toLowerCase().split(/[\s-]+/).filter(Boolean);
    return tools.filter((tool) => {
      const haystack = `${tool.name} ${tool.description} ${tool.command}`.toLowerCase();
      return (category === "All" || tool.category === category) && tokens.every((token) => haystack.includes(token));
    });
  }, [category, query]);

  async function copy(value: string, label: string) {
    try {
      await navigator.clipboard.writeText(value);
      setCopyError(null);
      setCopied(label);
      window.setTimeout(() => setCopied(null), 1800);
    } catch {
      setCopied(null);
      setCopyError(`Could not copy ${label}. Select the command manually.`);
    }
  }

  return (
    <>
      <header className="masthead">
        <a className="brand" href="#top" aria-label="System 8 home"><span className="brand-mark">8</span><span>System 8</span></a>
        <nav aria-label="Primary navigation">
          <a href="#tools">Tools</a><a href="#harness">Harness</a><a href="#safety">Safety</a>
          <a href="https://github.com/enkayz/system8" target="_blank" rel="noreferrer">GitHub ↗</a>
        </nav>
      </header>

      <main id="main">
        <section className="hero" id="top">
          <div className="eyebrow">Microsoft 365 · operator toolkit</div>
          <h1 aria-label="Microsoft 365 Operator Harness">Microsoft 365<br />Operator Harness</h1>
          <p className="lede">Evidence-led tools for licensing, identity, SharePoint, security, migration and operational continuity. Built for bounded assessment work and honest partial results.</p>
          <div className="hero-actions">
            <a className="button primary" href="#install">Install the CLI <span>↓</span></a>
            <a className="button secondary" href="#tools">Explore {tools.length} tools <span>→</span></a>
          </div>
          <dl className="hero-metrics" aria-label="Toolkit summary">
            <div><dt>{tools.length}</dt><dd>operator packages</dd></div>
            <div><dt>5</dt><dd>fixture-tested core tools</dd></div>
            <div><dt>0</dt><dd>remediation commands</dd></div>
          </dl>
        </section>

        <section className="principles" id="safety" aria-labelledby="safety-title">
          <div><span className="section-index">01</span><h2 id="safety-title">Read-only by design</h2></div>
          <div className="principle-grid">
            <article><span className="status-dot" /> <h3>No silent remediation</h3><p>The Microsoft 365 packages collect and explain. They do not mutate tenant configuration.</p></article>
            <article><span className="status-dot" /> <h3>Evidence survives failure</h3><p>Denied or unavailable collections are preserved as evidence instead of being filled with invented results.</p></article>
            <article><span className="status-dot" /> <h3>Local output</h3><p>No tenant credentials or assessment data are entered into this portal. Reports are generated by the installed tools.</p></article>
          </div>
        </section>

        <section className="catalog" id="tools" aria-labelledby="catalog-title">
          <div className="section-heading"><div><span className="section-index">02</span><h2 id="catalog-title">Operator catalogue</h2></div><p>Choose the smallest tool that answers the operating question.</p></div>
          <div className="catalog-controls">
            <div className="tabs" role="group" aria-label="Filter by category">
              {categories.map((item) => <button key={item} className={category === item ? "active" : ""} onClick={() => setCategory(item)}>{item}</button>)}
            </div>
            <label className="search"><span>Search tools</span><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="licensing, SharePoint, access…" /></label>
          </div>
          <div className="tool-count" role="status">Showing {filtered.length} of {tools.length}</div>
          <div className="tool-grid">
            {filtered.map((tool, index) => (
              <article className="tool-card" key={tool.name}>
                <div className="tool-meta"><span>{String(index + 1).padStart(2, "0")}</span><span>{tool.category}</span></div>
                <h3>{tool.name}</h3><p>{tool.description}</p><small>{tool.mode}</small>
                <button className="command" onClick={() => copy(`s8 install ${tool.name}\n${tool.command}`, tool.name)} aria-label={`Copy install and run commands for ${tool.name}`}>
                  <code>{tool.command}</code><span>{copied === tool.name ? "Copied" : "Copy"}</span>
                </button>
              </article>
            ))}
          </div>
          {filtered.length === 0 && <p className="empty">No tools match this filter.</p>}
        </section>

        <section className="install" id="install" aria-labelledby="install-title">
          <div><span className="section-index light">03</span><h2 id="install-title">One command.<br />A governed toolkit.</h2><p>Run in Windows PowerShell 5.1 or PowerShell 7. The bootstrap self-elevates for the machine-wide installation.</p></div>
          <div className="terminal-card"><div className="terminal-bar"><span>PowerShell</span><span>machine install</span></div><code>{installer}</code><button onClick={() => copy(installer, "installer")}>{copied === "installer" ? "Copied to clipboard" : "Copy installer"}</button></div>
        </section>

        <section className="harness" id="harness" aria-labelledby="harness-title">
          <div><span className="section-index">04</span><h2 id="harness-title">Run the verified fixture harness</h2></div>
          <div className="harness-body">
            <p>The repository harness parses every PowerShell file, validates package manifest paths, installs five core packages into an isolated temporary root, runs help and offline fixture reports, compares tenant snapshots, and produces a migration estimate.</p>
            <div className="verification-list" aria-label="Harness checks"><span>SYNTAX_OK</span><span>MANIFEST_PATHS_OK</span><span>CLEAN_INSTALL_OK</span><span>HELP_AND_FIXTURE_REPORTS_OK</span><span>TENANT_DIFF_FIXTURE_OK</span><span>MIGRATION_FIXTURE_OK</span></div>
            <div className="code-block"><code>pwsh -NoProfile -File ./tests/Test-M365Packages.ps1</code><button onClick={() => copy("pwsh -NoProfile -File ./tests/Test-M365Packages.ps1", "harness")}>{copied === "harness" ? "Copied" : "Copy"}</button></div>
          </div>
        </section>
      </main>

      <footer><div><span className="brand-mark">8</span><strong>System 8</strong></div><p>Interfaces, automation and infrastructure treated as one operating system.</p><a href="https://github.com/enkayz/system8">Inspect the source ↗</a></footer>
      <div className="toast" aria-live="polite">{copyError ?? (copied ? `${copied} copied` : "")}</div>
    </>
  );
}

export default App;
