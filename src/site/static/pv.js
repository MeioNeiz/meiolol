// Private numbers on the public champion and matchup pages (docs/plan/app.md "Private
// site"): the shipped draft model's win chances, which the public pages never show
// (production-key.md "Product rules"). Served from /p/ only, so nginx's login gate covers
// both this script and its data; the header script (html.zig admin_link) loads it for
// browsers that opened /admin/ or /p/, and for anyone else it is the login page's HTML,
// which never runs. Data: /p/models/champ/<id>.json (draftmodel.zig writeSlices).
// Champion pages: a line in .hero and a Model column on the opponent and duo tables
// (opp-ROLE, opp-ROLE-OTHER, duo-ROLE-OTHER), put back when filters.js redraws a table.
// Matchup pages (matchup/ROLE/A-vs-B.html): a line in .hero
"use strict";

(async () => {
  const ROLES = ["top", "jungle", "mid", "bot", "support"];
  const WORDS = ["Top", "Jungle", "Mid", "Bot", "Support"];
  const pct = p => (100 * p).toFixed(1) + "%";
  const getJson = async url => {
    const r = await fetch(url, { credentials: "same-origin", cache: "no-cache" });
    if (!r.ok || !(r.headers.get("content-type") || "").includes("json")) throw new Error(`${r.status} ${url}`);
    return r.json();
  };
  const slice = id => getJson(`/p/models/champ/${id}.json`);
  const about = "The shipped draft model (every region and patch, refitted daily): the team's win chance with every other pick its role's average. Private: the public site never shows it.";

  if (document.readyState === "loading") await new Promise(r => document.addEventListener("DOMContentLoaded", r));
  const hero = document.querySelector(".hero");
  if (!hero) return;
  const style = document.createElement("style");
  style.textContent = ".pv-line{margin:8px 0 0;font-size:13px;color:var(--t2)}.pv-line b{color:var(--accent)}" +
    ".pv-tag{font-size:11px;text-transform:uppercase;letter-spacing:.06em;color:var(--accent);margin-right:6px}" +
    "td.pv,th.pv{color:var(--accent);white-space:nowrap}.og-key .pv{color:var(--accent)}";
  const line = (...parts) => {
    const p = document.createElement("p");
    p.className = "pv-line";
    p.title = about;
    const tag = document.createElement("span");
    tag.className = "pv-tag";
    tag.textContent = "Private";
    p.append(tag, ...parts);
    // Under the title's text, not a cell of its own in the hero's grid
    (hero.querySelector("h1")?.parentElement || hero).append(p);
  };
  const bold = text => { const b = document.createElement("b"); b.textContent = text; return b; };

  const f = document.querySelector("[data-filters][data-id]");
  if (f) {
    const s = await slice(f.dataset.id).catch(() => null);
    if (!s) return;
    document.head.append(style);
    const parts = ["Model, against an average draft: "];
    // The roles the page has opponents for: not the handful of games elsewhere
    s.roles.filter(r => document.getElementById(`opp-${ROLES[r.role]}`)).forEach((r, i) => parts.push(i ? ", " : "", `${WORDS[r.role]} `, bold(pct(r.win[0])), ` (${pct(r.win[1])} to ${pct(r.win[2])})`));
    line(...parts);
    for (const table of document.querySelectorAll("table.og[id]")) {
      const m = table.id.match(/^(opp|duo)-([a-z]+)(?:-([a-z]+))?$/);
      const role = m && ROLES.indexOf(m[2]);
      const r = m && s.roles.find(x => x.role === role);
      if (!r) continue;
      const other = m[3] ? ROLES.indexOf(m[3]) : role;
      const by = new Map((m[1] === "opp" ? r.vs : r.with).filter(x => x[0] === other).map(x => [String(x[1]), x]));
      const fill = () => {
        const head = table.tHead && table.tHead.rows[0];
        if (head && !head.querySelector("th.pv")) {
          const th = document.createElement("th");
          th.className = "pv";
          th.textContent = "Model";
          th.title = about;
          head.append(th);
        }
        for (const row of table.tBodies[0]?.rows || []) {
          if (!row.dataset.id || row.querySelector("td.pv")) continue;
          const x = by.get(row.dataset.id), td = document.createElement("td");
          td.className = "pv";
          td.textContent = x ? pct(x[2]) : "–";
          if (x) td.title = `${pct(x[2])} for the team with both, ${x[3].toLocaleString("en-GB")} games together; ${pct(r.win[0])} with this champion alone`;
          row.append(td);
        }
      };
      // The tiles show no column heads: the key above them names the last line
      const key = table.closest("[data-panel]")?.querySelector(".og-key");
      if (key && !key.querySelector(".pv")) {
        const k = document.createElement("span");
        k.className = "pv";
        k.title = about;
        k.textContent = ". Private, last line: the model's win chance for the team with both";
        key.append(k);
      }
      fill();
      // fill's own cells come back here too, and add nothing the second time
      new MutationObserver(fill).observe(table, { childList: true, subtree: true });
    }
    return;
  }

  const m = location.pathname.match(/\/matchup\/([a-z]+)\/(.+)-vs-(.+)\.html$/);
  const role = m ? ROLES.indexOf(m[1]) : -1;
  if (role < 0) return;
  const list = await getJson("/data/champions.json").catch(() => null);
  const ids = [m[2], m[3]].map(slug => (list?.champions || []).find(c => c.slug === slug));
  if (!ids[0] || !ids[1]) return;
  const [a, b] = await Promise.all(ids.map(c => slice(c.id).catch(() => null)));
  const ra = a?.roles.find(x => x.role === role), rb = b?.roles.find(x => x.role === role);
  const x = ra?.vs.find(v => v[0] === role && v[1] === ids[1].id);
  if (!ra || !x) return;
  document.head.append(style);
  line(`Model: ${ids[0].name}'s team `, bold(pct(x[2])), ` against ${ids[1].name}'s in ${WORDS[role]}; each alone against an average draft: ${ids[0].name} ${pct(ra.win[0])}` +
    (rb ? `, ${ids[1].name} ${pct(rb.win[0])}` : "") + ".");
})();
