// Your games: asks the service (src/api) for a Riot ID's recent ranked games and lays
// each lane over the typical curve for its matchup. Facts only, never advice. Every
// string from the service goes in with textContent, never as HTML.
"use strict";

const API = ["localhost", "127.0.0.1"].includes(location.hostname) && location.port !== "8090"
  ? "http://127.0.0.1:8090/api"
  : "/api";
// `meiolol your-example`: an anonymised player in the API's shape, for visitors (and
// Riot's reviewers) without a Riot ID
const EXAMPLE = "data/your-example.json";
const THIN = 200;
const MIN_N = 10;
const LANE_END = 14;
const POLL_MS = 3000;
const SVG = "http://www.w3.org/2000/svg";

const $ = (id) => document.getElementById(id);
const el = (tag, cls, text) => {
  const e = document.createElement(tag);
  if (cls) e.className = cls;
  if (text !== undefined) e.textContent = text;
  return e;
};
const signed = (x) => (x > 0 ? `+${x}` : `${x}`);
const clock = (s) => `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
const plural = (n, word) => `${n} ${word}${n === 1 ? "" : "s"}`;
const titleCase = (s) => s[0] + s.slice(1).toLowerCase();

let champs = new Map();
let ddragon = "";
let stat = "gold";
let current = null;
let pollTimer = 0;
let lookupId = "";

async function loadChamps() {
  try {
    const r = await fetch("data/champions.json");
    const j = await r.json();
    ddragon = j.ddragon;
    champs = new Map(j.champions.map((c) => [c.id, c]));
  } catch {
    // Names fall back to "?": the page still works
  }
}

function champ(id) {
  const c = champs.get(id);
  const a = el(c ? "a" : "span", "champ");
  if (c) {
    a.href = `champion/${c.slug}.html`;
    if (ddragon) {
      const img = el("img");
      img.src = `https://ddragon.leagueoflegends.com/cdn/${ddragon}/img/champion/${c.key}.png`;
      img.alt = "";
      img.width = img.height = 28;
      img.loading = "lazy";
      a.append(img);
    }
  }
  a.append(c ? c.name : "?");
  return a;
}

const champName = (id) => champs.get(id)?.name ?? "?";

function status(text) {
  const s = $("status");
  s.hidden = !text;
  s.textContent = text || "";
}

async function lookup(id) {
  clearTimeout(pollTimer);
  lookupId = id;
  const url = new URL(location.href);
  url.searchParams.delete("example");
  url.searchParams.set("id", id);
  history.replaceState(null, "", url);
  status("Looking up…");
  await poll();
}

async function poll() {
  const id = lookupId;
  let res;
  let body;
  try {
    res = await fetch(`${API}/games?id=${encodeURIComponent(id)}`);
    body = await res.json();
  } catch {
    status("The games service is not reachable right now. Try again later.");
    return;
  }
  if (id !== lookupId) return;
  if (body.state === "opted_out") {
    $("player").hidden = true;
    status("This player has asked us not to show their games.");
    return;
  }
  if (res.status === 404 || body.state === "not_found") {
    $("player").hidden = true;
    status("No Riot account with that name and tag. Check the spelling and the part after #.");
    return;
  }
  if (!res.ok) {
    status(body.error || "Something went wrong. Try again in a few minutes.");
    return;
  }
  current = body;
  if (body.player) render(body);
  if (body.state === "queued") {
    status(body.ahead ? `Queued behind ${plural(body.ahead, "lookup")}…` : "Queued…");
  } else if (body.state === "fetching") {
    const done = (body.total ?? 0) - (body.pending ?? 0);
    status(`Fetching games from Riot: ${done} of ${body.total ?? "?"}…`);
  } else {
    const p = body.player;
    status(p?.error ? `Last update failed (${p.error}); showing what is stored.` : "");
    return;
  }
  pollTimer = setTimeout(poll, POLL_MS);
}

async function showExample() {
  clearTimeout(pollTimer);
  lookupId = "";
  const url = new URL(location.href);
  url.searchParams.delete("id");
  url.searchParams.set("example", "");
  history.replaceState(null, "", url);
  let body;
  try {
    body = await (await fetch(EXAMPLE)).json();
  } catch {
    status("The example isn't available right now.");
    return;
  }
  body.example = true;
  current = body;
  render(body);
  status("An example: real ranked solo games of one player from our data, with their name left out and dates to the day. Enter your Riot ID above to see your own.");
}

function render(body) {
  const p = body.player;
  $("player").hidden = false;
  $("player-name").textContent = body.example ? p.name : `${p.name}#${p.tag}`;
  const tier = p.tier
    ? `${titleCase(p.tier)}${p.division && !["MASTER", "GRANDMASTER", "CHALLENGER"].includes(p.tier) ? ` ${p.division}` : ""}`
    : "Unranked in solo/duo";
  const updated = p.refreshed ? `, updated ${new Date(p.refreshed * 1000).toLocaleString()}` : "";
  $("player-rank").textContent = body.example
    ? `${p.platform}. Solo/duo rank at the newest game: ${tier}.`
    : `${p.platform}. Visible solo/duo rank: ${p.tier ? `${tier}, ${p.lp ?? 0} LP` : tier}${updated}.`;
  const r = body.report ?? { games: [], weeks: [], matchups: [] };
  renderWeeks(r.weeks);
  renderMatchups(r.matchups);
  renderGames(r.games);
}

function cell(text, num) {
  const td = el("td", num ? "num" : "", text);
  return td;
}

function renderWeeks(weeks) {
  const body = $("weeks");
  body.replaceChildren();
  for (const w of weeks) {
    const tr = el("tr");
    const d = new Date(`${w.start}T00:00:00Z`);
    tr.append(
      cell(d.toLocaleDateString(undefined, { day: "numeric", month: "short", timeZone: "UTC" })),
      cell(String(w.games), true),
      cell(String(w.wins), true),
      cell(w.gold14 !== undefined ? `${signed(w.gold14)} (${plural(w.lane_games, "game")})` : "-", true),
      cell(w.vs_typical14 !== undefined ? `${signed(w.vs_typical14)} (${plural(w.curve_games, "game")})` : "-", true),
    );
    body.append(tr);
  }
  if (!weeks.length) body.append(emptyRow(5, "No ranked solo games yet."));
}

function emptyRow(span, text) {
  const tr = el("tr");
  const td = el("td", "muted", text);
  td.colSpan = span;
  tr.append(td);
  return tr;
}

const mean = (xs) => Math.round(xs.reduce((a, b) => a + b, 0) / xs.length);

function renderMatchups(matchups) {
  const body = $("matchups");
  body.replaceChildren();
  for (const m of matchups) {
    const tr = el("tr");
    const you = el("td");
    you.append(champ(m.champion), el("span", "role", ` ${m.role}`));
    const them = el("td");
    them.append(champ(m.opponent));
    const golds = m.points.map((p) => p.gold10).filter((g) => g !== undefined);
    let trend = golds.slice(-8).map(signed).join(", ") || "-";
    if (golds.length >= 4) {
      const half = Math.floor(golds.length / 2);
      trend += `. Average ${signed(mean(golds.slice(0, half)))} in the older half, ${signed(mean(golds.slice(-half)))} in the newer`;
    }
    tr.append(you, them, cell(String(m.games), true), cell(String(m.wins), true), cell(trend));
    body.append(tr);
  }
  if (!matchups.length) body.append(emptyRow(5, "No lane matchups yet."));
}

function renderGames(games) {
  const box = $("games");
  box.replaceChildren();
  for (const g of games) box.append(gameCard(g));
  if (!games.length) box.append(el("p", "muted", "No ranked solo games in the last 60 days."));
}

function gameCard(g) {
  const card = el("article", "card your-game");
  const head = el("div", "your-head");
  const when = new Date(g.start_ms);
  head.append(el("b", g.win ? "good" : "bad", g.remake ? "Remake" : g.win ? "Win" : "Loss"));
  head.append(champ(g.champion));
  if (g.opponent !== undefined) {
    head.append(el("span", "muted", "vs"), champ(g.opponent));
  }
  head.append(el("span", "muted", [
    g.role ?? "no lane",
    `${g.kills}/${g.deaths}/${g.assists}`,
    clock(g.duration_s),
    `patch ${g.patch}`,
    when.toLocaleDateString(undefined, { day: "numeric", month: "short" }),
  ].join(" · ")));
  card.append(head);
  const l = g.lane;
  if (!l) {
    card.append(el("p", "muted", g.remake ? "Remake: no lane to show." : "No lane opponent or timeline for this game."));
    return card;
  }
  card.append(chart(g, l));
  card.append(facts(g, l));
  return card;
}

function chart(g, l) {
  const c = l.curve;
  const mine = l[stat];
  const band = c ? c[stat] : null;
  const thin = !c || c.games < THIN;
  const fig = el("figure", `chart${thin ? " thin" : ""}`);
  const W = 640, H = 220, left = 48, right = 12, top = 12, bottom = 26;
  const minutes = Math.max(mine.length, 1);
  const shown = (i) => band && c.n[i] >= MIN_N;
  let lo = 0, hi = 0;
  mine.forEach((v, i) => {
    lo = Math.min(lo, v);
    hi = Math.max(hi, v);
    if (shown(i)) {
      lo = Math.min(lo, band[i][0]);
      hi = Math.max(hi, band[i][2]);
    }
  });
  const span = Math.max(hi - lo, stat === "cs" ? 20 : 400);
  lo -= span * 0.08;
  hi += span * 0.08;
  const x = (m) => left + (m / minutes) * (W - left - right);
  const y = (v) => top + ((hi - v) / (hi - lo)) * (H - top - bottom);

  const svg = document.createElementNS(SVG, "svg");
  svg.setAttribute("viewBox", `0 0 ${W} ${H}`);
  svg.setAttribute("role", "img");
  svg.setAttribute("aria-label", `${stat} difference by minute, you minus your lane opponent`);
  const add = (tag, attrs, text) => {
    const n = document.createElementNS(SVG, tag);
    for (const [k, v] of Object.entries(attrs)) n.setAttribute(k, v);
    if (text !== undefined) n.textContent = text;
    svg.append(n);
    return n;
  };
  for (let m = 0; m <= minutes; m += 5) {
    add("line", { class: "grid", x1: x(m), x2: x(m), y1: top, y2: H - bottom });
    add("text", { x: x(m), y: H - 8, "text-anchor": "middle" }, `${m}`);
  }
  const step = niceStep((hi - lo) / 4);
  for (let v = Math.ceil(lo / step) * step; v <= hi; v += step) {
    if (v !== 0) add("line", { class: "grid", x1: left, x2: W - right, y1: y(v), y2: y(v) });
    add("text", { x: left - 6, y: y(v) + 4, "text-anchor": "end" }, signed(v));
  }
  add("line", { class: "zero", x1: left, x2: W - right, y1: y(0), y2: y(0) });
  add("text", { x: left + 6, y: top + 12, class: "side" }, "You ahead");
  add("text", { x: left + 6, y: H - bottom - 6, class: "side" }, "Opponent ahead");
  if (band) {
    const idx = [...band.keys()].filter((i) => shown(i) && i < minutes);
    if (idx.length) {
      const upper = [[0, 0], ...idx.map((i) => [i + 1, band[i][2]])];
      const lower = [[0, 0], ...idx.map((i) => [i + 1, band[i][0]])].reverse();
      add("polygon", { class: "band", points: [...upper, ...lower].map(([m, v]) => `${x(m)},${y(v)}`).join(" ") });
      add("polyline", { class: "median", points: [[0, 0], ...idx.map((i) => [i + 1, band[i][1]])].map(([m, v]) => `${x(m)},${y(v)}`).join(" ") });
    }
  }
  add("polyline", { class: "you", points: [[0, 0], ...mine.map((v, i) => [i + 1, v])].map(([m, v]) => `${x(m)},${y(v)}`).join(" ") });
  fig.append(svg);

  const cap = el("figcaption");
  cap.textContent = c
    ? `Typical: ${champName(g.champion)} vs ${champName(g.opponent)}, ${c.bracket}${c.pooled ? " (too few games at your rank)" : ""}, patch ${c.patch}, ${plural(c.games, "game")}${thin ? ". More data needed" : ""}.`
    : `No typical curve yet for ${champName(g.champion)} vs ${champName(g.opponent)} in this role: only your game is shown.`;
  fig.append(cap);
  return fig;
}

// 1, 2 or 5 times a power of ten, at least `raw`
function niceStep(raw) {
  const p = 10 ** Math.floor(Math.log10(Math.max(raw, 1)));
  return [1, 2, 5, 10].map((m) => m * p).find((s) => s >= raw);
}

function facts(g, l) {
  const ul = el("ul", "facts");
  const add = (text) => ul.append(el("li", "", text));
  const c = l.curve;
  const at = LANE_END - 1;
  if (l.gold.length > at) {
    let text = `Gold difference at ${LANE_END} min: ${signed(l.gold[at])}.`;
    if (c && c.n[at] >= MIN_N) {
      const [p25, p50, p75] = c.gold[at];
      const where = l.gold[at] < p25 ? "below" : l.gold[at] > p75 ? "above" : "within";
      text += ` Typical middle half ${signed(p25)} to ${signed(p75)} (median ${signed(p50)}): ${where} it.`;
    }
    add(text);
  }
  const ref = (s) => (s.against === "typical" ? "the typical game" : "an even lane");
  const during = (s) => `${plural(s.deaths, "death")} and ${plural(s.kills, "kill")} you took part in during those minutes.`;
  if (l.fall) add(`Biggest drop against ${ref(l.fall)}: ${l.fall.from}-${l.fall.to} min, ${signed(l.fall.change)} gold. ${during(l.fall)}`);
  if (l.rise) add(`Biggest gain against ${ref(l.rise)}: ${l.rise.from}-${l.rise.to} min, ${signed(l.rise.change)} gold. ${during(l.rise)}`);
  add(`Before ${LANE_END} min: ${plural(l.lane_deaths, "death")}, ${plural(l.lane_kills, "kill")} you took part in.`);
  if (l.cs10 !== undefined) add(`CS at 10 min: ${l.cs10}.`);
  const timing = (label, mineT, typical) => {
    if (!mineT || mineT[0] == null) return;
    let text = `${label} at ${clock(mineT[0])}`;
    if (mineT[1] != null) text += `, opponent ${clock(mineT[1])}`;
    if (typical && typical[0] != null) text += `. Typical ${clock(typical[0])}${typical[1] != null ? ` and ${clock(typical[1])}` : ""}`;
    add(`${text}.`);
  };
  timing("Level 6", l.level6, c?.level6);
  timing("First legendary item", l.first_item, c?.first_item);
  return ul;
}

function setStat(s) {
  stat = s;
  for (const b of $("stat-tabs").querySelectorAll("button")) b.setAttribute("aria-pressed", String(b.dataset.stat === s));
  if (current?.report) renderGames(current.report.games);
}

// Objection: the service issues a starter profile icon, the player sets it, and the
// service re-reads it from Riot before removing and blocking the account
let forgetId = "";
let forgetTimer = 0;

async function forget(check) {
  if (!check) {
    const id = prompt("Riot ID to remove (Name#TAG):", lookupId || $("riot-id").value.trim());
    if (!id || !/^[^#]+#[^#]+$/.test(id.trim())) return;
    forgetId = id.trim();
  }
  clearTimeout(forgetTimer);
  forgetShow("Contacting Riot…");
  try {
    const r = await fetch(`${API}/forget?id=${encodeURIComponent(forgetId)}${check ? "&check=1" : ""}`, { method: "POST" });
    forgetState(await r.json());
  } catch {
    forgetShow("Could not reach the service just now. Try again, or email us (see the privacy page).");
  }
}

async function forgetPoll() {
  try {
    const r = await fetch(`${API}/forget?id=${encodeURIComponent(forgetId)}`);
    forgetState(await r.json());
  } catch {
    forgetShow("Could not reach the service just now. Try again in a moment.");
  }
}

function forgetShow(text, icon, canCheck) {
  $("forget-box").hidden = false;
  $("forget-text").textContent = text;
  const img = $("forget-icon");
  img.hidden = icon === undefined;
  if (icon !== undefined && ddragon) img.src = `https://ddragon.leagueoflegends.com/cdn/${ddragon}/img/profileicon/${icon}.png`;
  $("forget-check").hidden = !canCheck;
}

function forgetState(j) {
  const until = j.expires ? new Date(j.expires * 1000).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" }) : "";
  const steps = `In the League client, open your profile, change your icon to this one (icon ${j.icon}, one of the free starter icons) and press check below, before ${until}. You can change it back afterwards.`;
  switch (j.state) {
    case "pending":
    case "checking":
      forgetShow(j.state === "pending" ? "Contacting Riot…" : "Checking your icon with Riot…");
      forgetTimer = setTimeout(forgetPoll, 2000);
      return;
    case "issued":
      return forgetShow(`To prove ${forgetId} is yours: ${steps}`, j.icon, true);
    case "mismatch":
      return forgetShow(`Riot doesn't show that icon on ${forgetId} yet (it can take a minute after you change it). ${steps}`, j.icon, true);
    case "done":
      if (forgetId.toLowerCase() === lookupId.toLowerCase()) {
        clearTimeout(pollTimer);
        current = null;
        $("player").hidden = true;
        status("");
      }
      return forgetShow(`Done: everything stored about ${forgetId} is deleted, and we won't fetch its games again.`);
    case "not_found":
      return forgetShow("No Riot account with that name and tag.");
    case "expired":
      return forgetShow("That check expired. Press \"Remove a Riot ID\" to get a new icon.");
    default:
      return forgetShow(j.error || "Something went wrong. Try again, or email us (see the privacy page).");
  }
}

async function start() {
  await loadChamps();
  $("lookup").addEventListener("submit", (e) => {
    e.preventDefault();
    const id = $("riot-id").value.trim();
    if (!/^[^#]+#[^#]+$/.test(id)) {
      status("Enter your Riot ID as Name#TAG, for example Faker#KR1.");
      return;
    }
    lookup(id);
  });
  for (const b of $("stat-tabs").querySelectorAll("button")) b.addEventListener("click", () => setStat(b.dataset.stat));
  $("forget").addEventListener("click", () => forget(false));
  $("forget-check").addEventListener("click", () => forget(true));
  $("example-link").addEventListener("click", (e) => {
    e.preventDefault();
    showExample();
  });
  const params = new URLSearchParams(location.search);
  const id = params.get("id");
  if (id) {
    $("riot-id").value = id;
    lookup(id);
  } else if (params.has("example")) {
    showExample();
  }
  try {
    $("example-offer").hidden = !(await fetch(EXAMPLE, { method: "HEAD" })).ok;
  } catch {
    // No example: the offer stays hidden
  }
}

start();
