// Your games: asks the service (src/api) for a Riot ID's recent games and reviews each
// one (review.js): win chance by minute, key moments, death cost, lane against the
// typical game. Facts only, never advice. Every string from the service goes in with
// textContent, never as HTML.
"use strict";

const API = ["localhost", "127.0.0.1"].includes(location.hostname) && location.port !== "8090"
  ? "http://127.0.0.1:8090/api"
  : "/api";
// `meiolol your-example`: an anonymised player per role in the API's shape, for visitors
// (and Riot's reviewers) without a Riot ID
const EXAMPLE = "data/your-example.json";
const ROLES = [["top", "Top", "top laner"], ["jungle", "Jungle", "jungler"], ["mid", "Mid", "mid laner"], ["bot", "Bot", "bot laner"], ["support", "Support", "support"]];
const POLL_MS = 3000;
// Riot lists a game a few minutes after it ends: a check that finds nothing new repeats
// every minute for a while. The service refuses checks closer than check_at
const WATCH_MS = 60_000;
const WATCH_FOR_MS = 10 * 60_000;

const $ = (id) => document.getElementById(id);
const { el, plural, signed, clock } = Review;
const titleCase = (s) => s[0] + s.slice(1).toLowerCase();

let current = null;
let pollTimer = 0;
let lookupId = "";
let shown = 0;
// The game in the review by start, so games a fetch adds before it don't move it
let shownMs = 0;
// What is on screen: a poll every few seconds while fetching re-renders only what changed,
// so the minute or lane stat picked in the review stays
let rendered = "";
let reviewed = "";
let pager = null;
let watchUntil = 0;
let watchFrom = 0;
let watchTimer = 0;
let checkTimer = 0;
// From a game link (#id=...&game=start_ms): that game opens once the lookup lists it
let wantGame = 0;
// The newest game this device saw for the ID before this visit, 0 for none
let since = 0;
// Newer games are marked new in the film strip: since, or the newest before a check
let newAfter = 0;
// Preview: /api/ is behind basic auth until the production key. Asked without
// credentials first, so visitors read why instead of getting the browser's sign-in
// prompt; testers sign in from that note once per tab
let signIn = false;
try {
  signIn = sessionStorage.getItem("api-sign-in") === "1";
} catch {}

// The example's dates are to the day in UTC; a looked-up player's are their own
function date(g) {
  return new Date(g.start_ms).toLocaleDateString("en-GB", { day: "numeric", month: "short", ...(current?.example ? { timeZone: "UTC" } : {}) });
}

function status(text) {
  const s = $("status");
  s.hidden = !text;
  s.textContent = text || "";
}

const apiFetch = (url, opts = {}) => fetch(url, { ...opts, credentials: signIn ? "same-origin" : "omit" });

function previewNote() {
  const example = el("a", "", "See the example review");
  example.href = "your.html#example";
  example.addEventListener("click", (e) => {
    e.preventDefault();
    showExample();
  });
  const testers = el("button", "", "Preview testers: sign in");
  testers.type = "button";
  testers.addEventListener("click", () => {
    signIn = true;
    try {
      sessionStorage.setItem("api-sign-in", "1");
    } catch {}
    status("Looking up…");
    poll();
  });
  const s = $("status");
  s.hidden = false;
  s.replaceChildren(
    "Looking up Riot IDs opens once meiolol has its Riot Games production API key; the site is in review for it now. ",
    example,
    ". ",
    testers,
  );
}

// The Riot ID lives in the fragment, which never reaches the server or its logs
function setUrl(hash) {
  const url = new URL(location.href);
  url.search = "";
  url.hash = hash;
  history.replaceState(null, "", url);
}

const idHash = (id, game) => `id=${encodeURIComponent(id)}${game ? `&game=${game}` : ""}`;
const playerId = (p) => `${p.name}#${p.tag}`;
const sameId = (a, b) => a.toLowerCase() === b.toLowerCase();

// Recent Riot IDs on this device only, newest first, each with the newest game seen.
// Never sent anywhere; without storage the page just doesn't offer them
const RECENT = "your-recent";

function recentRead() {
  try {
    const list = JSON.parse(localStorage.getItem(RECENT) ?? "[]");
    return Array.isArray(list) ? list.filter((r) => typeof r?.id === "string") : [];
  } catch {
    return [];
  }
}

function recentWrite(list) {
  try {
    if (list.length) localStorage.setItem(RECENT, JSON.stringify(list.slice(0, 5)));
    else localStorage.removeItem(RECENT);
  } catch {}
  renderRecent();
}

function remember(id, newest) {
  const list = recentRead();
  const prev = list.find((r) => sameId(r.id, id));
  recentWrite([{ id, newest: Math.max(newest, prev?.newest ?? 0) }, ...list.filter((r) => r !== prev)]);
}

function renderRecent() {
  const box = $("recent");
  const list = recentRead();
  box.hidden = !list.length;
  box.replaceChildren();
  if (!list.length) return;
  box.append(el("span", "", "On this device:"));
  for (const r of list) {
    const a = el("a", "", r.id);
    a.href = `your.html#${idHash(r.id)}`;
    a.addEventListener("click", (e) => {
      e.preventDefault();
      $("riot-id").value = r.id;
      lookup(r.id);
    });
    box.append(a);
  }
  const forget = el("button", "link", "Forget on this device");
  forget.type = "button";
  forget.addEventListener("click", () => recentWrite([]));
  box.append(forget);
}

async function lookup(id, game = 0) {
  clearTimeout(pollTimer);
  stopWatch();
  lookupId = id;
  fresh();
  wantGame = game;
  since = recentRead().find((r) => sameId(r.id, id))?.newest ?? 0;
  newAfter = since;
  setUrl(idHash(id, game));
  status("Looking up…");
  await poll();
}

async function poll(refresh) {
  const id = lookupId;
  let res;
  let body;
  try {
    res = await apiFetch(`${API}/games?id=${encodeURIComponent(id)}${refresh ? "&refresh=1" : ""}`);
    if (res.status === 401 && !signIn) {
      if (id === lookupId) previewNote();
      return;
    }
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
    stopWatch();
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
    const games = body.report?.games ?? [];
    const fresh = since ? games.filter((g) => g.start_ms > since).length : 0;
    since = 0;
    status(p?.error ? `Last update failed (${p.error}); showing what is stored.` : fresh ? `${plural(fresh, "new game")} since your last visit.` : "");
    if (wantGame) {
      wantGame = 0;
      setUrl(idHash(lookupId));
      if (games.length) status("That game is no longer among this player's recent games, so here is the newest.");
    }
    if (p) remember(playerId(p), newest(body));
    if (watchUntil) watchStep(body);
    renderCheck(body);
    return;
  }
  renderCheck(body);
  pollTimer = setTimeout(poll, POLL_MS);
}

const newest = (body) => body.report?.games?.[0]?.start_ms ?? 0;
const hhmm = (ms) => new Date(ms).toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit" });

function renderCheck(body) {
  const b = $("check");
  clearTimeout(checkTimer);
  b.hidden = !!body.example || !body.player;
  if (b.hidden) return;
  const busy = body.state === "queued" || body.state === "fetching";
  const wait = (body.check_at ?? 0) * 1000 - Date.now();
  b.textContent = watchUntil ? "Stop checking" : "Check for new games";
  b.disabled = !watchUntil && (busy || wait > 0);
  b.title = !watchUntil && !busy && wait > 0 ? `Checked just now; again from ${hhmm(body.check_at * 1000)}` : "";
  if (!watchUntil && !busy && wait > 0) checkTimer = setTimeout(() => renderCheck(current), wait + 500);
}

function startWatch() {
  if (watchUntil) {
    stopWatch();
    status("");
    renderCheck(current);
    return;
  }
  watchFrom = newest(current);
  watchUntil = Date.now() + WATCH_FOR_MS;
  status("Checking Riot for new games…");
  clearTimeout(pollTimer);
  poll(true);
}

function stopWatch() {
  watchUntil = 0;
  clearTimeout(watchTimer);
}

// After a check: stop when a newer game shows up, else try again a minute on while the
// tab is open
function watchStep(body) {
  if (newest(body) > watchFrom) {
    const fresh = body.report.games.filter((g) => g.start_ms > watchFrom).length;
    stopWatch();
    newAfter ||= watchFrom;
    markNew();
    show(0);
    status(`${plural(fresh, "new game")} added.`);
    return;
  }
  if (Date.now() >= watchUntil) {
    stopWatch();
    status("No new games. If you've just finished one, Riot can take a few minutes to list it: check again shortly.");
    return;
  }
  status(`No new game yet: Riot lists a game a few minutes after it ends. Checking every minute until ${hhmm(watchUntil)}.`);
  const next = Math.max(WATCH_MS, (body.check_at ?? 0) * 1000 - Date.now() + 1000);
  watchTimer = setTimeout(function again() {
    if (!watchUntil) return;
    if (document.hidden) watchTimer = setTimeout(again, WATCH_MS);
    else poll(true);
  }, next);
}

let examples;

// role: "" (or one not in the file) for the file's default. An older file is one
// example of no role
async function showExample(role = "") {
  clearTimeout(pollTimer);
  stopWatch();
  lookupId = "";
  newAfter = 0;
  try {
    examples ??= await (await fetch(EXAMPLE)).json();
  } catch {
    status("The example isn't available right now.");
    return;
  }
  const byRole = !examples.state;
  if (!byRole) role = "";
  else if (!examples[role]) role = examples.default;
  setUrl(role ? `example=${role}` : "example");
  const body = { ...(role ? examples[role] : examples), example: true, exampleRole: role };
  current = body;
  fresh();
  render(body);
  renderCheck(body);
  const who = ROLES.find((r) => r[0] === role)?.[2] ?? "player";
  status(`An example: real ranked games of one ${who} from our data, with their name left out and dates to the day. Enter your Riot ID above to review your own.`);
}

function renderRoles(body) {
  let nav = $("example-roles");
  if (!nav) {
    nav = el("nav", "tabs");
    nav.id = "example-roles";
    nav.setAttribute("aria-label", "Example role");
    $("player").prepend(nav);
  }
  nav.hidden = !body.exampleRole;
  if (nav.hidden) return;
  nav.replaceChildren(...ROLES.filter(([role]) => examples[role]).map(([role, label]) => {
    const a = el("a", "", label);
    a.href = `#example=${role}`;
    if (role === body.exampleRole) a.setAttribute("aria-current", "page");
    a.addEventListener("click", (e) => {
      e.preventDefault();
      showExample(role);
    });
    return a;
  }));
}

function fresh() {
  shownMs = 0;
  rendered = "";
  reviewed = "";
}

function render(body) {
  const p = body.player;
  $("player").hidden = false;
  renderRoles(body);
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
  const json = JSON.stringify(r);
  if (json === rendered) return;
  rendered = json;
  const want = wantGame || shownMs;
  shown = Math.max(0, want ? r.games.findIndex((g) => g.start_ms === want) : 0);
  if (wantGame && r.games[shown]?.start_ms === wantGame) wantGame = 0;
  shownMs = r.games[shown]?.start_ms ?? 0;
  if (!body.example && !wantGame) setUrl(idHash(playerId(p), shown ? shownMs : 0));
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
    const top = el("span", "top");
    top.append(Review.icon(g.champion), el("span", g.remake ? "" : g.win ? "w" : "l", g.remake ? "R" : g.win ? "W" : "L"), el("span", "num", clock(g.duration_s)));
    b.append(top, Review.spark(g));
    b.addEventListener("click", () => show(i));
    box.append(b);
  });
  if (!games.length) box.append(el("p", "muted", "No solo/duo, flex, draft or Swiftplay games in the last 60 days."));
  markNew();
}

function markNew() {
  const games = current?.report?.games ?? [];
  for (const [k, b] of [...$("film").children].entries()) {
    const g = games[k];
    if (!g) continue;
    const isNew = newAfter > 0 && g.start_ms > newAfter;
    b.classList.toggle("new", isNew);
    b.setAttribute("aria-label", `${isNew ? "New: " : ""}${g.remake ? "Remake" : g.win ? "Win" : "Loss"}, ${Review.champName(g.champion)}, ${date(g)}`);
  }
}

function show(i) {
  const games = current?.report?.games ?? [];
  if (i < 0 || i >= games.length) return;
  shown = i;
  shownMs = games[i].start_ms;
  for (const [k, b] of [...$("film").children].entries()) b.setAttribute("aria-current", String(k === i));
  // Without game= the link opens whatever is newest then
  if (!current.example) setUrl(idHash(playerId(current.player), i ? games[i].start_ms : 0));
  renderReview(games);
}

function renderReview(games) {
  const box = $("review");
  const g = games[shown];
  const json = JSON.stringify(g ?? null);
  if (json === reviewed) {
    pager?.move(shown, games.length);
    return;
  }
  reviewed = json;
  if (!g) {
    box.replaceChildren();
    return;
  }
  const link = current.example ? undefined : `${location.origin}${location.pathname}#${idHash(playerId(current.player), g.start_ms)}`;
  pager = { index: shown, count: games.length, go: show };
  Review.render(box, g, { date, pager, link });
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
    const r = await apiFetch(`${API}/forget?id=${encodeURIComponent(forgetId)}${check ? "&check=1" : ""}`, { method: "POST" });
    if (r.status === 401 && !signIn) {
      forgetShow("Removing a Riot ID here opens with the production key, like lookups. Until then, email us (address on the privacy page) and we remove it by hand.");
      return;
    }
    forgetState(await r.json());
  } catch {
    forgetShow("Could not reach the service just now. Try again, or email us (see the privacy page).");
  }
}

async function forgetPoll() {
  try {
    const r = await apiFetch(`${API}/forget?id=${encodeURIComponent(forgetId)}`);
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
      recentWrite(recentRead().filter((r) => !sameId(r.id, forgetId)));
      if (sameId(forgetId, lookupId)) {
        clearTimeout(pollTimer);
        stopWatch();
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

// ?id= from the lookup forms on other pages and old links; lookup() moves it to #id=
function fromUrl() {
  const params = new URLSearchParams(location.search);
  const hash = new URLSearchParams(location.hash.slice(1));
  const id = hash.get("id") ?? params.get("id");
  if (id) {
    $("riot-id").value = id;
    lookup(id, Number(hash.get("game")) || 0);
  } else if (hash.has("example") || params.has("example")) {
    showExample(hash.get("example") ?? params.get("example") ?? "");
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
  $("check").addEventListener("click", startWatch);
  $("forget").addEventListener("click", () => forget(false));
  $("forget-check").addEventListener("click", () => forget(true));
  $("example-link").addEventListener("click", (e) => {
    e.preventDefault();
    showExample();
  });
  const recent = el("p", "recent");
  recent.id = "recent";
  $("lookup").after(recent);
  renderRecent();
  fromUrl();
  // A link to another game pasted into this tab changes only the fragment
  addEventListener("hashchange", fromUrl);
  try {
    $("example-offer").hidden = !(await fetch(EXAMPLE, { method: "HEAD" })).ok;
  } catch {
    // No example: the offer stays hidden
  }
}

start();
