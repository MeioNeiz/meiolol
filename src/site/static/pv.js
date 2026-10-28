// Private numbers on the public champion and matchup pages (docs/plan/app.md "Private
// site"): the shipped draft model's win chances, which the public pages never show
// (production-key.md "Product rules"). Served from /p/ only, so nginx's login gate covers
// both this script and its data; the header script (html.zig admin_link) loads it for
// browsers that opened /admin/ or /p/, and for anyone else it is the login page's HTML,
// which never runs. Data: /p/models/champ/<id>.json (draftmodel.zig writeSlices).
// Champion pages (ui.champpage): a box under the head, outside every island so no wasm
// diff meets it, with each role's line and the model's figure for the matchup brief's
// opponent, redrawn as the islands change. Matchup pages (/matchups/ROLE/A-vs-B): a
// line in .hero
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
  const about = "Private, for admin logins only: the shipped draft model's estimate (every region and patch, refitted daily) of the team's win chance with every other pick its role's average. The public site never shows it.";

  if (document.readyState === "loading") await new Promise(r => document.addEventListener("DOMContentLoaded", r));
  const style = document.createElement("style");
  style.textContent = ".pv-line{margin:8px 0 0;font-size:13px;color:var(--t2)}.pv-line b{color:var(--accent)}" +
    ".pv-tag{font-size:11px;text-transform:uppercase;letter-spacing:.06em;color:var(--accent);margin-right:6px;cursor:help;text-decoration:underline dotted}" +
    ".pv-box{padding:0 var(--sp-4,16px)}.pv-box .pv-line{margin:0 0 4px}";
  const para = (...parts) => {
    const p = document.createElement("p");
    p.className = "pv-line";
    p.title = about;
    const tag = document.createElement("span");
    tag.className = "pv-tag";
    tag.textContent = "Private";
    p.append(tag, ...parts);
    return p;
  };
  const bold = text => { const b = document.createElement("b"); b.textContent = text; return b; };
  const champions = async () => (await getJson("/data/champions.json").catch(() => null))?.champions || [];

  const page = document.querySelector(".c-cpage[data-id]");
  if (page) {
    const [s, list] = await Promise.all([slice(page.dataset.id).catch(() => null), champions()]);
    const head = page.querySelector("[data-island=champion]");
    if (!s || !head) return;
    document.head.append(style);
    const roles = (page.dataset.roles || "").split(" ");
    const ids = new Map(list.map(c => [c.name, c.id]));
    const box = document.createElement("div");
    box.className = "pv-box";
    head.after(box);
    let drawn = "";
    const draw = () => {
      const want = new URLSearchParams(location.hash.slice(1)).get("role");
      const role = ROLES.indexOf(roles.includes(want) ? want : roles[0]);
      const r = s.roles.find(x => x.role === role);
      // The brief: its opponent's name, and "Top opponent" or "Mid ally"
      const who = page.querySelector(".c-mpick .t b")?.textContent || "";
      const rel = (page.querySelector(".c-mpick .t small")?.textContent || "").match(/^(\w+) (opponent|ally)/);
      const key = [role, who, rel?.[0]].join("|");
      // Our own redraw is a mutation too: only a change of what's shown draws
      if (key === drawn) return;
      drawn = key;
      // The shown role only: every role on one line read as clutter
      const lines = r ? [para("Draft model: ", bold(pct(r.win[0])), ` in ${WORDS[role]} against an average draft (${pct(r.win[1])} to ${pct(r.win[2])})`)] : [];
      const other = rel ? WORDS.indexOf(rel[1]) : -1;
      const ally = rel?.[2] === "ally";
      const x = r && other >= 0 && (ally ? r.with : r.vs).find(v => v[0] === other && v[1] === ids.get(who));
      if (x) lines.push(para(`Model, ${ally ? "with" : "against"} ${who} (${WORDS[other]}): the team `, bold(pct(x[2])), `, ${x[3].toLocaleString("en-GB")} games together; ${pct(r.win[0])} alone`));
      box.replaceChildren(...lines);
    };
    draw();
    // Role switches and picked dots: the islands patch in place, with no event of their own
    new MutationObserver(draw).observe(page, { childList: true, subtree: true, characterData: true });
    return;
  }

  const hero = document.querySelector(".hero");
  if (!hero) return;
  // Under the title's text, not a cell of its own in the hero's grid
  const line = (...parts) => (hero.querySelector("h1")?.parentElement || hero).append(para(...parts));

  const m = location.pathname.match(/\/matchups\/([a-z]+)\/(.+)-vs-(.+)$/);
  const role = m ? ROLES.indexOf(m[1]) : -1;
  if (role < 0) return;
  const list = await champions();
  const ids = [m[2], m[3]].map(slug => list.find(c => c.slug === slug));
  if (!ids[0] || !ids[1]) return;
  const [a, b] = await Promise.all(ids.map(c => slice(c.id).catch(() => null)));
  const ra = a?.roles.find(x => x.role === role), rb = b?.roles.find(x => x.role === role);
  const x = ra?.vs.find(v => v[0] === role && v[1] === ids[1].id);
  if (!ra || !x) return;
  document.head.append(style);
  line(`Model: ${ids[0].name}'s team `, bold(pct(x[2])), ` against ${ids[1].name}'s in ${WORDS[role]}; each alone against an average draft: ${ids[0].name} ${pct(ra.win[0])}` +
    (rb ? `, ${ids[1].name} ${pct(rb.win[0])}` : "") + ".");
})();
