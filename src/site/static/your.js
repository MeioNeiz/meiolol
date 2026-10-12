// Your games: asks the service (src/api) for a Riot ID's recent games and reviews each
// one (review.js): win chance by minute, key moments, death cost, lane against the
// typical game. Facts only, never advice. Every string from the service goes in with
// textContent, never as HTML.
"use strict";

const API = ["localhost", "127.0.0.1"].includes(location.hostname) && location.port !== "8090"
  ? "http://127.0.0.1:8090/api"
  : "/api";
// `meiolol your-example`: an anonymised player in the API's shape, for visitors (and
// Riot's reviewers) without a Riot ID
const EXAMPLE = "data/your-example.json";
const POLL_MS = 3000;

const $ = (id) => document.getElementById(id);
const { el, plural, signed, clock } = Review;
const titleCase = (s) => s[0] + s.slice(1).toLowerCase();

let current = null;
let pollTimer = 0;
let lookupId = "";
let shown = 0;

// The example's dates are to the day in UTC; a looked-up player's are their own
function date(g) {
  return new Date(g.start_ms).toLocaleDateString("en-GB", { day: "numeric", month: "short", ...(current?.example ? { timeZone: "UTC" } : {}) });
}

function status(text) {
  const s = $("status");
  s.hidden = !text;
  s.textContent = text || "";
}

// The Riot ID lives in the fragment, which never reaches the server or its logs
function setUrl(hash) {
  const url = new URL(location.href);
  url.search = "";
  url.hash = hash;
  history.replaceState(null, "", url);
}

async function lookup(id) {
  clearTimeout(pollTimer);
  lookupId = id;
  setUrl(`id=${encodeURIComponent(id)}`);
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
  const first = current?.player?.name !== body.player?.name;
  current = body;
  if (body.player) render(body, first);
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
  setUrl("example");
  let body;
  try {
    body = await (await fetch(EXAMPLE)).json();
  } catch {
    status("The example isn't available right now.");
    return;
  }
  body.example = true;
  current = body;
  render(body, true);
  status("An example: real ranked games of one player from our data, with their name left out and dates to the day. Enter your Riot ID above to review your own.");
}

function render(body, first) {
  const p = body.player;
  $("player").hidden = false;
  $("start").classList.add("compact");
  $("player-name").textContent = body.example ? p.name : `${p.name}#${p.tag}`;
  const tier = p.tier
    ? `${titleCase(p.tier)}${p.division && !["MASTER", "GRANDMASTER", "CHALLENGER"].includes(p.tier) ? ` ${p.division}` : ""}`
    : "Unranked in solo/duo";
  const updated = p.refreshed ? ` · updated ${new Date(p.refreshed * 1000).toLocaleString("en-GB", { dateStyle: "medium", timeStyle: "short" })}` : "";
  $("player-rank").textContent = body.example
    ? `${p.platform} · ${tier} at the newest game`
    : `${p.platform} · ${p.tier ? `${tier}, ${p.lp ?? 0} LP` : tier}${updated}`;
  const r = body.report ?? { games: [], weeks: [], matchups: [] };
  if (first) shown = 0;
  shown = Math.min(shown, Math.max(0, r.games.length - 1));
  renderRecord(r.games);
  renderFilm(r.games);
  renderReview(r.games);
  renderHighlights(r.games);
  renderMatchups(r.matchups);
  renderWeeks(r.weeks);
}

function renderRecord(games) {
  const box = $("record");
  box.replaceChildren();
  const played = games.filter((g) => !g.remake);
  if (!played.length) return;
  const wins = played.filter((g) => g.win).length;
  let streak = 1;
  while (streak < played.length && played[streak].win === played[0].win) streak++;
  const stat = (value, label) => {
    const d = el("div");
    d.append(el("b", "", value), el("span", "", label));
    box.append(d);
  };
  stat(`${wins}–${played.length - wins}`, "Record");
  stat(`${Math.round((100 * wins) / played.length)}%`, "Wins");
  stat(`${streak} ${played[0].win ? "W" : "L"}`, "Streak");
  const form = el("div");
  const dots = el("div", "form");
  dots.setAttribute("aria-label", `Newest first: ${games.map((g) => (g.remake ? "remake" : g.win ? "win" : "loss")).join(", ")}`);
  for (const g of games.slice(0, 20)) dots.append(el("i", g.remake ? "r" : g.win ? "w" : ""));
  form.append(el("span", "", "Form, newest first"), dots);
  box.append(form);
}

function renderFilm(games) {
  const box = $("film");
  box.replaceChildren();
  $("games-note").textContent = games.length ? `${plural(games.length, "game")}, newest first. Pick one to review it.` : "";
  games.forEach((g, i) => {
    const b = el("button");
    b.type = "button";
    b.setAttribute("role", "listitem");
    b.setAttribute("aria-current", String(i === shown));
    b.setAttribute("aria-label", `${g.remake ? "Remake" : g.win ? "Win" : "Loss"}, ${Review.champName(g.champion)}, ${date(g)}`);
    const top = el("span", "top");
    top.append(Review.icon(g.champion), el("span", g.remake ? "" : g.win ? "w" : "l", g.remake ? "R" : g.win ? "W" : "L"), el("span", "num", clock(g.duration_s)));
    b.append(top, Review.spark(g));
    b.addEventListener("click", () => show(i));
    box.append(b);
  });
  if (!games.length) box.append(el("p", "muted", "No solo/duo, flex, draft or Swiftplay games in the last 60 days."));
}

function show(i) {
  const games = current?.report?.games ?? [];
  if (i < 0 || i >= games.length) return;
  shown = i;
  for (const [k, b] of [...$("film").children].entries()) b.setAttribute("aria-current", String(k === i));
  renderReview(games);
}

function renderReview(games) {
  const box = $("review");
  if (!games.length) {
    box.replaceChildren();
    return;
  }
  Review.render(box, games[shown], { date, pager: { index: shown, count: games.length, go: show } });
}

function renderHighlights(games) {
  const all = Review.highlights(games, date);
  const box = $("highlight-tiles");
  box.replaceChildren(...all.filter((h) => h.key !== "record").map(Review.highlightCard));
  $("highlights").hidden = all.length < 2;
  const played = games.filter((g) => !g.remake).length;
  $("highlights-note").textContent = `From your last ${plural(played, "game")}. A record book across every game you've played is coming.`;
}

function cell(text, num) {
  return el("td", num ? "num" : "", text);
}

function emptyRow(span, text) {
  const tr = el("tr");
  const td = el("td", "muted", text);
  td.colSpan = span;
  tr.append(td);
  return tr;
}

function champCell(id, role) {
  const td = el("td");
  const span = el("span", "champ");
  span.append(Review.icon(id), Review.champName(id));
  td.append(span);
  if (role) td.append(el("span", "role", ` ${role}`));
  return td;
}

function renderWeeks(weeks) {
  const body = $("weeks");
  body.replaceChildren();
  for (const w of weeks) {
    const tr = el("tr");
    const d = new Date(`${w.start}T00:00:00Z`);
    tr.append(
      cell(d.toLocaleDateString("en-GB", { day: "numeric", month: "short", timeZone: "UTC" })),
      cell(String(w.games), true),
      cell(String(w.wins), true),
      cell(w.gold14 !== undefined ? `${signed(w.gold14)} (${plural(w.lane_games, "game")})` : "-", true),
      cell(w.vs_typical14 !== undefined ? `${signed(w.vs_typical14)} (${plural(w.curve_games, "game")})` : "-", true),
    );
    body.append(tr);
  }
  if (!weeks.length) body.append(emptyRow(5, "No games yet."));
}

const mean = (xs) => Math.round(xs.reduce((a, b) => a + b, 0) / xs.length);

function renderMatchups(matchups) {
  const body = $("matchups");
  body.replaceChildren();
  for (const m of matchups) {
    const tr = el("tr");
    const golds = m.points.map((p) => p.gold10).filter((g) => g !== undefined);
    let trend = golds.slice(-8).map(signed).join(", ") || "-";
    if (golds.length >= 4) {
      const half = Math.floor(golds.length / 2);
      trend += `. Average ${signed(mean(golds.slice(0, half)))} in the older half, ${signed(mean(golds.slice(-half)))} in the newer`;
    }
    tr.append(champCell(m.champion, m.role), champCell(m.opponent), cell(String(m.games), true), cell(String(m.wins), true), el("td", "wrap", trend));
    body.append(tr);
  }
  if (!matchups.length) body.append(emptyRow(5, "No lane matchups yet."));
}

function setTab(id) {
  for (const a of $("time-tabs").querySelectorAll("a")) {
    const on = a.dataset.tab === id;
    if (on) a.setAttribute("aria-current", "page");
    else a.removeAttribute("aria-current");
    $(a.dataset.tab).hidden = !on;
  }
}

// Objection: the service issues a starter profile icon, the player sets it, and the
// service re-reads it from Riot before removing and blocking the account
let forgetId = "";
let forgetTimer = 0;
let ddragon = "";

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
  await Review.init("", { lane: true });
  try {
    ddragon = (await (await fetch("data/champions.json")).json()).ddragon;
  } catch {
    // No profile icons in the removal steps: the text still says which
  }
  $("lookup").addEventListener("submit", (e) => {
    e.preventDefault();
    const id = $("riot-id").value.trim();
    if (!/^[^#]+#[^#]+$/.test(id)) {
      status("Enter your Riot ID as Name#TAG, for example Faker#KR1.");
      return;
    }
    lookup(id);
  });
  for (const a of $("time-tabs").querySelectorAll("a")) {
    a.addEventListener("click", (e) => {
      e.preventDefault();
      setTab(a.dataset.tab);
    });
  }
  $("forget").addEventListener("click", () => forget(false));
  $("forget-check").addEventListener("click", () => forget(true));
  $("example-link").addEventListener("click", (e) => {
    e.preventDefault();
    showExample();
  });
  // ?id= from the lookup forms on other pages and old links; lookup() moves it to #id=
  const params = new URLSearchParams(location.search);
  const hash = new URLSearchParams(location.hash.slice(1));
  const id = hash.get("id") ?? params.get("id");
  if (id) {
    $("riot-id").value = id;
    lookup(id);
  } else if (hash.has("example") || params.has("example")) {
    showExample();
  }
  try {
    $("example-offer").hidden = !(await fetch(EXAMPLE, { method: "HEAD" })).ok;
  } catch {
    // No example: the offer stays hidden
  }
}

start();
