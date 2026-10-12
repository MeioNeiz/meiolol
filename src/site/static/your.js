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
  renderHighlights(r.games);
  renderWeeks(r.weeks);
  renderMatchups(r.matchups);
  renderGames(r.games);
}

// Fun facts from the games in the report (newest first); each tile only when there is
// something to say, so a short history shows fewer tiles rather than empty ones
function renderHighlights(all) {
  // Under 5 minutes: an early surrender after a leaver. A real result (record and
  // streaks count it), but never a record for length, KDA or lane
  const played = all.filter((g) => !g.remake);
  const games = played.filter((g) => g.duration_s >= 300);
  const box = $("highlight-tiles");
  box.replaceChildren();
  $("highlights").hidden = !played.length;
  if (!played.length) return;
  const tile = (value, label, sub) => {
    const t = el("div", "tile");
    t.append(el("b", "", value), el("span", "", label));
    if (sub) t.append(el("small", "", sub));
    box.append(t);
  };
  const result = (g) => (g.win ? "win" : "loss");
  const date = (g) => new Date(g.start_ms).toLocaleDateString(undefined, { day: "numeric", month: "short" });
  const on = (g) => `${champName(g.champion)}${g.opponent !== undefined ? ` vs ${champName(g.opponent)}` : ""}, ${result(g)}, ${date(g)}`;
  const best = (xs, key) => xs.reduce((a, b) => (key(b) > key(a) ? b : a), xs[0]);
  const big = (x) => `${x > 0 ? "+" : ""}${x.toLocaleString("en-GB")}`;

  const wins = played.filter((g) => g.win).length;
  tile(`${wins}-${played.length - wins}`, "Record", `${Math.round((100 * wins) / played.length)}% wins in ${plural(played.length, "game")}`);

  let streak = 1;
  while (streak < played.length && played[streak].win === played[0].win) streak++;
  let longest = 0;
  for (let i = 0, run = 0; i < played.length; i++) {
    run = played[i].win ? run + 1 : 0;
    longest = Math.max(longest, run);
  }
  if (streak >= 2) tile(`${streak} ${played[0].win ? "wins" : "losses"}`, "Current streak");
  if (longest >= 2 && !(played[0].win && streak === longest)) tile(plural(longest, "win"), "Longest win streak");
  if (!games.length) return;

  const long = best(games, (g) => g.duration_s);
  tile(clock(long.duration_s), "Longest game", on(long));
  const won = games.filter((g) => g.win);
  if (won.length) {
    const fast = best(won, (g) => -g.duration_s);
    tile(clock(fast.duration_s), "Fastest win", on(fast));
  }
  const kda = (g) => (g.kills + g.assists) / Math.max(1, g.deaths);
  const top = best(games, kda);
  tile(kda(top).toFixed(1), "Best KDA", `${top.kills}/${top.deaths}/${top.assists}, ${on(top)}`);

  const at = LANE_END - 1;
  const lanes = games.filter((g) => g.lane && g.lane.gold.length > at);
  if (lanes.length) {
    const gold14 = (g) => g.lane.gold[at];
    const lead = best(lanes, gold14);
    // A lost lead shows below as the furthest-ahead loss
    if (gold14(lead) > 0 && lead.win) tile(big(gold14(lead)), `Biggest lane lead at ${LANE_END} min`, on(lead));
    const comeback = won.filter((g) => lanes.includes(g) && gold14(g) < 0);
    if (comeback.length) {
      const c = best(comeback, (g) => -gold14(g));
      tile(big(gold14(c)), "Won from furthest behind", `in lane at ${LANE_END} min: ${on(c)}`);
    }
    const thrown = lanes.filter((g) => !g.win && gold14(g) > 0);
    if (thrown.length) {
      const t = best(thrown, gold14);
      tile(big(gold14(t)), "Lost from furthest ahead", `in lane at ${LANE_END} min: ${on(t)}`);
    }
    const typical = (g) => (g.lane.curve && g.lane.curve.n[at] >= MIN_N ? gold14(g) - g.lane.curve.gold[at][1] : null);
    const vs = lanes.filter((g) => typical(g) !== null);
    if (vs.length) {
      const v = best(vs, typical);
      if (typical(v) > 0) tile(big(typical(v)), `Furthest above the typical game at ${LANE_END} min`, on(v));
    }
    const clean = lanes.filter((g) => g.lane.lane_deaths === 0).length;
    tile(`${clean} of ${lanes.length}`, `Lanes without a death before ${LANE_END} min`);
  }

  const costs = games.filter((g) => g.death_costs);
  const deaths = costs.flatMap((g) => g.death_costs.map((d) => ({ g, d })));
  if (costs.length) {
    const gold = deaths.reduce((a, x) => a + x.d.gold, 0);
    tile(Math.round(gold / costs.length).toLocaleString("en-GB"), "Kill gold given away per game", `${plural(deaths.length, "death")} in ${plural(costs.length, "game")}`);
  }
  if (deaths.length) {
    const worst = best(deaths, (x) => x.d.gold + 1000 * (x.d.lost?.length ?? 0));
    tile(`${worst.d.gold} gold`, "Most expensive death", `${clock(worst.d.t_s)}${worst.d.lost?.length ? `, then the enemy took ${list(worst.d.lost)}` : ""}: ${on(worst.g)}`);
    const followed = deaths.filter((x) => x.d.lost?.length).length;
    tile(`${followed} of ${deaths.length}`, "Deaths the enemy took an objective after", "within a minute");
  }
  const turns = games.filter((g) => g.turning);
  if (turns.length) {
    const swing = (g) => Math.abs(g.turning.to - g.turning.from);
    const b = best(turns, swing);
    tile(`${b.turning.from}% to ${b.turning.to}%`, "Biggest one-minute swing", `${b.turning.minute - 1}-${b.turning.minute} min: ${on(b)}`);
  }

  const counts = new Map();
  for (const g of games) {
    const c = counts.get(g.champion) ?? { games: 0, wins: 0 };
    c.games++;
    c.wins += g.win ? 1 : 0;
    counts.set(g.champion, c);
  }
  const [main, m] = [...counts].reduce((a, b) => (b[1].games > a[1].games ? b : a));
  if (m.games >= 2) tile(champName(main), "Most played", `${plural(m.games, "game")}, ${plural(m.wins, "win")}`);

  $("highlights-note").textContent = `From your last ${plural(played.length, "ranked solo game")}. A record book across every game you've played is coming, built when you ask for it.`;
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
  if (l) {
    card.append(chart(g, l));
    card.append(facts(g, l));
  } else {
    card.append(el("p", "muted", g.remake ? "Remake: no lane to show." : "No lane opponent or timeline for this game."));
  }
  if (g.win_chance?.length > 1) card.append(wholeGame(g));
  return card;
}

const list = (xs) => (xs.length > 1 ? `${xs.slice(0, -1).join(", ")} and ${xs[xs.length - 1]}` : xs[0] ?? "");

// Win chance by minute (src/winchance.zig), the turning minute and what each death cost
function wholeGame(g) {
  const box = el("div", "whole-game");
  const wc = g.win_chance;
  const t = g.turning;
  box.append(winChart(wc, t, g.death_costs ?? []));
  const ul = el("ul", "facts");
  if (t) {
    const what = [`${plural(t.kills, "kill")} and ${plural(t.deaths, "death")} for your team`];
    if (t.your_deaths) what.push(t.your_deaths > 1 ? `you died ${t.your_deaths} times` : "you died");
    else if (t.your_kills) what.push(`you took part in ${plural(t.your_kills, "kill")}`);
    if (t.taken?.length) what.push(`your team took ${list(t.taken)}`);
    if (t.lost?.length) what.push(`the enemy took ${list(t.lost)}`);
    ul.append(el("li", "", `Turning minute: ${t.minute - 1}-${t.minute} min, your team's win chance ${t.from}% to ${t.to}%. That minute: ${list(what)}.`));
  }
  box.append(ul);
  const deaths = g.death_costs ?? [];
  if (deaths.length) {
    const gold = deaths.reduce((a, d) => a + d.gold, 0);
    const det = el("details", "deaths");
    det.append(el("summary", "", `Death cost: ${plural(deaths.length, "death")}, ${gold.toLocaleString("en-GB")} kill gold to the enemy`));
    const dl = el("ul", "facts");
    for (const d of deaths) {
      let text = `${clock(d.t_s)}, ${d.killer !== undefined ? `killed by ${champName(d.killer)}` : "executed"}${d.assists ? ` and ${plural(d.assists, "other")}` : ""}: ${d.gold} gold to the enemy.`;
      if (d.lost?.length) text += ` In the next minute the enemy took ${list(d.lost)}.`;
      if (d.before !== undefined && d.after !== undefined) text += ` Win chance ${d.before}% at ${Math.floor(d.t_s / 60)}:00, ${d.after}% at ${Math.floor(d.t_s / 60) + 1}:00.`;
      dl.append(el("li", "", text));
    }
    det.append(dl);
    box.append(det);
  }
  return box;
}

const SVG_NS = "http://www.w3.org/2000/svg";
const svgEl = (tag, attrs) => {
  const e = document.createElementNS(SVG_NS, tag);
  for (const [k, v] of Object.entries(attrs)) e.setAttribute(k, v);
  return e;
};

function winChart(wc, turn, deaths) {
  const W = 640, H = 150, L = 40, R = 12, T = 10, B = 24;
  const last = wc.length - 1;
  const x = (m) => L + ((W - L - R) * m) / Math.max(last, 1);
  const y = (p) => T + ((H - T - B) * (100 - p)) / 100;
  const fig = el("figure", "chart win");
  const svg = svgEl("svg", { viewBox: `0 0 ${W} ${H}`, role: "img", "aria-label": "Your team's win chance by minute" });
  for (const p of [0, 50, 100]) {
    svg.append(svgEl("line", { class: p === 50 ? "zero" : "grid", x1: L, x2: W - R, y1: y(p), y2: y(p) }));
    const label = svgEl("text", { x: L - 6, y: y(p) + 4, "text-anchor": "end" });
    label.textContent = `${p}%`;
    svg.append(label);
  }
  for (let m = 5; m < last; m += 5) {
    const label = svgEl("text", { x: x(m), y: H - 6, "text-anchor": "middle" });
    label.textContent = `${m} min`;
    svg.append(label);
  }
  if (turn) svg.append(svgEl("rect", { class: "turn", x: x(turn.minute - 1), width: x(turn.minute) - x(turn.minute - 1), y: T, height: H - T - B }));
  svg.append(svgEl("polyline", { class: "median", points: wc.map((p, m) => `${x(m).toFixed(1)},${y(p).toFixed(1)}`).join(" ") }));
  for (const d of deaths) {
    const m = d.t_s / 60;
    if (m > last) continue;
    const lo = Math.floor(m), hi = Math.min(lo + 1, last);
    const p = wc[lo] + (wc[hi] - wc[lo]) * (m - lo);
    svg.append(svgEl("circle", { class: "death", cx: x(m), cy: y(p), r: 4 }));
  }
  fig.append(svg);
  fig.append(el("figcaption", "", "Your team's win chance by minute, from the gold and XP lead and objectives held, as in Platinum+ games. Shaded: the turning minute. Dots: your deaths."));
  return fig;
}

function chart(g, l) {
  const c = l.curve;
  const mine = l[stat];
  const band = c ? c[stat] : null;
  const thin = !c || c.games < THIN;
  const fig = el("figure", `chart${thin ? " thin" : ""}`);
  // Typical minutes while enough games are still going (a prefix: games only end)
  const shown = band ? band.slice(0, mine.length).filter((_, i) => c.n[i] >= MIN_N) : [];
  const svg = laneSvg(
    `${stat} difference by minute, you minus your lane opponent`,
    "You",
    "Opponent",
    shown.map((q) => [q[0], q[2]]),
    shown.map((q) => q[1]),
    mine,
  );
  if (svg) fig.insertAdjacentHTML("afterbegin", svg);

  const cap = el("figcaption");
  cap.textContent = c
    ? `Typical: ${champName(g.champion)} vs ${champName(g.opponent)}, ${c.bracket}${c.pooled ? " (too few games at your rank)" : ""}, patch ${c.patch}, ${plural(c.games, "game")}${thin ? ". More data needed" : ""}.`
    : `No typical curve yet for ${champName(g.champion)} vs ${champName(g.opponent)} in this role: only your game is shown.`;
  fig.append(cap);
  return fig;
}

let chartWasm = null;

async function loadChart() {
  try {
    const { instance } = await WebAssembly.instantiateStreaming(fetch("chart.wasm"));
    chartWasm = instance.exports;
  } catch {
    // Charts left out; captions and facts still show
  }
}

// The matchup pages' chart (src/site/lanechart.zig) through chart_wasm.zig, whose
// header has the input layout. Names come back escaped by the Zig templates, so the
// SVG may go in as markup
function laneSvg(aria, a, b, band, line, you) {
  const w = chartWasm;
  if (!w) return null;
  const enc = new TextEncoder();
  const texts = [aria, a, b].map((t) => enc.encode(t));
  const ints = [...texts.map((t) => t.length), band.length, line.length, you.length, ...band.flat(), ...line, ...you];
  const len = 4 * ints.length + texts.reduce((n, t) => n + t.length, 0);
  const view = new DataView(w.memory.buffer, w.input(), len);
  ints.forEach((v, i) => view.setInt32(4 * i, v, true));
  let at = 4 * ints.length;
  for (const t of texts) {
    new Uint8Array(w.memory.buffer, w.input() + at, t.length).set(t);
    at += t.length;
  }
  const n = w.render(len);
  return n ? new TextDecoder().decode(new Uint8Array(w.memory.buffer, w.output(), n)) : null;
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
  await Promise.all([loadChamps(), loadChart()]);
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
