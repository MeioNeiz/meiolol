// Daily Draft: puzzles from src/daily.zig (daily/index.json lists them, daily/<n>.json
// each). Guess the hidden champion, then the winner. The options flip to one fact each
// and the reveal shows how the model reads the draft (puzzle.review: who it favoured and
// why, its picks for the hidden slot, every pick rated), the scoreboard and the lanes at
// 14, this game's and the patch's usual, with game counts. Words stay "the model's
// pick", never "best pick" (docs/production-key.md). Results, streaks and archive stay
// in this browser (localStorage); a finished puzzle's two answers go once to /api/daily, counted with
// nothing about who sent them, for the share of players picking each. Reasons: reasons.js.
"use strict";

const ROLES = [
  ["top", "Top"],
  ["jungle", "Jungle"],
  ["middle", "Mid"],
  ["bottom", "Bot"],
  ["utility", "Support"],
];
const roleName = Object.fromEntries(ROLES);
const roleIndex = Object.fromEntries(ROLES.map(([r], i) => [r, i]));
const SIDES = ["Blue", "Red"];
const SIDE_CLS = ["dd-blue", "dd-red"];
const KEY = "meiolol.daily.v1";
const API = ["localhost", "127.0.0.1"].includes(location.hostname) && location.port !== "8090"
  ? "http://127.0.0.1:8090/api"
  : "/api";
// Preview mode (no production key yet): the page carries html.zig's banner. No Share
// then, as its text links the site, and the site may not be advertised until the key
// (docs/production-key.md); it comes back with the public build
const PREVIEW = document.querySelector("div.preview") !== null;
// Win-rate numbers are noise until there is a lot of data (draft model eval: level with
// a coin flip on 6k games). A pair edge needs PAIR_GAMES games and must clear chance
// (|pp| > 1.96 SE, SE = 50 / sqrt(n) points); reading whole drafts needs DRAFT_GAMES
// games on the patch
const PAIR_GAMES = 400;
const DRAFT_GAMES = 100000;
const clear = (pp, n) => n >= PAIR_GAMES && Math.abs(pp) > 98 / Math.sqrt(n);
// Lane gold facts come with their side already judged (src/daily.zig LaneGold); under
// this many games the curve is thin
const LANE_GAMES = 200;
const LANE_MINUTE = 14;
// A smaller gold lead at 14 shows uncoloured: the number is always there (J12)
const MIN_LEAD = 200;
const APEX = new Set(["MASTER", "GRANDMASTER", "CHALLENGER"]);

const $ = (id) => document.getElementById(id);
const pad = (n) => String(n).padStart(2, "0");
const fmt = (n) => n.toLocaleString("en-GB");
const signed = (n) => `${n > 0 ? "+" : n < 0 ? "\u2212" : ""}${fmt(Math.abs(n))}`;
const kilo = (n) => `${(n / 1000).toFixed(1)}k`;
const pct = (x) => `${x.toFixed(1)}%`;
const points = (x) => `${x > 0 ? "+" : x < 0 ? "\u2212" : ""}${Math.abs(x).toFixed(1)}`;
function ordinal(n) {
  const t = n % 100;
  const s = t >= 11 && t <= 13 ? "th" : ["th", "st", "nd", "rd"][n % 10] || "th";
  return `${n}${s}`;
}
const title = (s) => s[0] + s.slice(1).toLowerCase();

// "Gold II", "Master"; "" when the player was not on the ladder
function rankText(pl) {
  if (!pl || !pl.tier) return "";
  return APEX.has(pl.tier) || !pl.division ? title(pl.tier) : `${title(pl.tier)} ${pl.division}`;
}
const reduceMotion = () => matchMedia("(prefers-reduced-motion: reduce)").matches;

function el(tag, cls, text) {
  const e = document.createElement(tag);
  if (cls) e.className = cls;
  if (text !== undefined) e.textContent = text;
  return e;
}

function loadResults() {
  try {
    const saved = JSON.parse(localStorage.getItem(KEY));
    return saved && typeof saved === "object" && !Array.isArray(saved) ? saved : {};
  } catch {
    return {};
  }
}

function saveResults(results) {
  try {
    localStorage.setItem(KEY, JSON.stringify(results));
  } catch {
    // Private mode or storage blocked: the game still works, it just forgets
  }
}

const getJson = (url) =>
  fetch(url).then((r) => {
    if (!r.ok) throw new Error(`${url}: ${r.status}`);
    return r.json();
  });

// The viewer's own date, so the puzzle changes at their midnight
function localDate() {
  const d = new Date();
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

function longDate(iso) {
  const [y, m, d] = iso.split("-").map(Number);
  return new Date(y, m - 1, d).toLocaleDateString("en-GB", {
    day: "numeric",
    month: "long",
    year: "numeric",
  });
}

// "Good into Zed", for reason `r` (one that clears chance) with `other` its champion
function shortReason(r, other) {
  if (r.kind === "enemy") return r.pp > 0 ? `Good into ${other}` : `Struggles into ${other}`;
  return r.pp > 0 ? `Better with ${other}` : `Worse with ${other}`;
}

// Tick and cross, not green and red squares: the shapes read without colour
const glyphs = (marks) => [...marks].map((m) => (m === "1" ? "✅" : "❌")).join("");
const marksText = (marks) =>
  ["pick", "winner"].map((q, i) => `${q} ${marks[i] === "1" ? "right" : "wrong"}`).join(", ");

// Days in a row from each published puzzle (oldest first) finished on its own day or
// not: one missed puzzle between finished ones is forgiven (not counted), two in a row
// end the run (forgiving breaks bring players back: research/sources/duolingo-streaks.md
// ^f4). A day without a puzzle is no miss. Today's puzzle unfinished is pending, not
// missed, so the run ending yesterday, or with yesterday missed, is still alive.
// best: the longest run
function streaks(onTime) {
  const days = onTime.length && !onTime[onTime.length - 1] ? onTime.slice(0, -1) : onTime;
  let run = 0;
  let missed = 0;
  let best = 0;
  for (const ok of days) {
    if (ok) {
      run += 1;
      missed = 0;
      best = Math.max(best, run);
    } else if (++missed >= 2) {
      run = 0;
    }
  }
  return { streak: run, best };
}

async function start() {
  const status = $("status");
  try {
    const [index, meta] = await Promise.all([
      getJson("daily/index.json"),
      getJson("data/champions.json"),
    ]);
    // Puzzles are published a day or two early for viewers ahead of UTC
    const live = index.filter((p) => p.date <= localDate());
    if (live.length === 0) {
      status.textContent = "No puzzle yet. Come back tomorrow.";
      return;
    }
    const wanted = Number(new URLSearchParams(location.search).get("n"));
    // A future n falls back to today's: published early, not playable early
    const entry = live.find((p) => p.n === wanted) || live[live.length - 1];
    const puzzle = await getJson(`daily/${entry.n}.json`);
    status.hidden = true;
    $("daily").hidden = false;
    const game = new Game(puzzle, meta, live);
    game.render();
    if (game.done) game.fetchCrowd();
  } catch (e) {
    status.textContent = "Could not load the puzzle: " + e.message;
  }
}

class Game {
  constructor(p, meta, live) {
    this.p = p;
    this.live = live;
    this.byId = new Map(meta.champions.map((c) => [c.id, c]));
    this.ddragon = meta.ddragon;
    this.results = loadResults();
    this.mine = this.results[p.n] || {};
    // The question just answered, whose reveal animates; a reload shows it settled
    this.fresh = null;
    // /api/daily's counts for this puzzle once finished: null until they arrive
    this.crowd = null;
  }

  name(id) {
    const c = this.byId.get(id);
    return c ? c.name : "?";
  }

  champ(id, size = 32) {
    const c = this.byId.get(id);
    const a = document.createElement(c ? "a" : "span");
    a.className = "champ";
    if (c) {
      a.href = `champion/${c.slug}.html`;
      const img = document.createElement("img");
      img.src = `https://ddragon.leagueoflegends.com/cdn/${this.ddragon}/img/champion/${c.key}.png`;
      img.alt = "";
      img.width = img.height = size;
      img.loading = "lazy";
      a.append(img);
      a.title = c.name;
    }
    // A span so the phone lane rows can hide it visually, leaving the icon
    a.append(el("span", "name", this.name(id)));
    return a;
  }

  answer(field, value) {
    if (this.mine[field] !== undefined) return;
    this.mine[field] = value;
    if (this.done) {
      this.mine.marks = this.marks();
      // Streaks count puzzles finished on their own day, not archive catch-ups
      this.mine.on = localDate();
    }
    this.results[this.p.n] = this.mine;
    saveResults(this.results);
    this.fresh = field;
    this.render();
    if (this.done) this.fetchCrowd();
    if (field === "side") $("reveal").scrollIntoView({ behavior: reduceMotion() ? "auto" : "smooth", block: "start" });
  }

  // Sends this browser's answers the first time (mine.sent), else only reads the counts.
  // No API (local site, outage): no shares, the page as before
  async fetchCrowd() {
    const pick = this.p.options.findIndex((o) => o.id === this.mine.pick);
    const send = !this.mine.sent && pick >= 0;
    const url = `${API}/daily?n=${this.p.n}${send ? `&pick=${pick}&side=${this.mine.side}` : ""}`;
    try {
      const r = await fetch(url, { method: send ? "POST" : "GET", credentials: "omit" });
      if (!r.ok) return;
      this.crowd = await r.json();
    } catch {
      return;
    }
    if (send) {
      this.mine.sent = true;
      this.results[this.p.n] = this.mine;
      saveResults(this.results);
    }
    this.renderCrowd();
  }

  // Share of players picking each option and side, on the turned cards and side buttons
  renderCrowd() {
    const c = this.crowd;
    const enough = c && c.players > 0;
    const share = (k) => `${Math.round((100 * k) / c.players)}%`;
    for (const s of document.querySelectorAll(".dd-crowd")) s.remove();
    if (enough) {
      [...$("options").children].forEach((b, i) => {
        b.querySelector(".dd-back")?.append(el("small", "dd-crowd", `${share(c.picks[i] ?? 0)} picked`));
      });
      for (const b of $("q-side").querySelectorAll("button")) {
        b.append(el("small", "dd-crowd", `${share(c.sides[Number(b.dataset.side)] ?? 0)} chose`));
      }
    }
    const note = $("crowd");
    note.hidden = !c;
    if (c) {
      note.textContent = enough
        ? `How ${fmt(c.players)} ${c.players === 1 ? "player" : "players"} who finished this puzzle answered.`
        : "No one else has finished this puzzle yet.";
    }
  }

  get picked() {
    return this.mine.pick !== undefined;
  }

  get done() {
    return this.picked && this.mine.side !== undefined;
  }

  // The option the model rates highest, null on puzzles made before win chances
  get topOption() {
    const ws = this.p.options.filter((o) => o.win != null);
    if (ws.length < this.p.options.length) return null;
    return ws.reduce((a, b) => (b.win > a.win ? b : a)).id;
  }

  get enemy() {
    const p = this.p;
    return p.teams[1 - p.hidden_team][roleIndex[p.hidden_role]];
  }

  render() {
    const p = this.p;
    $("number").textContent = `#${p.n}`;
    this.renderBack();
    const tier = p.tier ? ` · ${p.tier[0]}${p.tier.slice(1).toLowerCase()}` : "";
    // The date is the puzzle's, not the game's
    $("about").textContent = `${longDate(p.date)} · EUW ranked solo/duo · patch ${p.patch}${tier}`;
    this.renderBoard();
    this.renderPick();
    this.renderSide();
    $("reveal").hidden = !this.done;
    if (this.done) this.renderReveal();
    this.renderCrowd();
    this.renderArchive();
  }

  renderBoard() {
    const p = this.p;
    for (const t of [0, 1]) {
      const list = $(`team-${t}`);
      list.replaceChildren();
      ROLES.forEach(([role, label], r) => {
        const li = document.createElement("li");
        li.append(el("span", "role", label));
        const hidden = t === p.hidden_team && role === p.hidden_role;
        if (hidden && !this.picked) {
          li.classList.add("hidden-slot");
          li.append("?");
        } else {
          if (hidden) li.classList.add("dd-was-hidden");
          li.append(this.champ(p.teams[t][r]));
        }
        // Always there, empty when unknown: the champion stays left either way
        li.append(el("span", "dd-rank", rankText(p.players?.[t][r])));
        list.append(li);
      });
      const bans = $(`bans-${t}`);
      // Per side in ban order: match data has no seat for a ban
      bans.replaceChildren(el("span", "", p.bans[t].length ? "Bans" : "No bans"));
      for (const id of p.bans[t]) {
        const b = this.champ(id, 24);
        b.removeAttribute("href");
        bans.append(b);
      }
    }
  }

  // One fact per option and the games behind it: a reason that clears chance, else
  // the lane against the enemy in the same role
  optionFact(o) {
    const p = this.p;
    const solid = o.reasons
      .filter((r) => r.kind !== "base" && detectedReason(p.hidden_role, r) && clear(r.pp, r.games))
      .sort((a, b) => Math.abs(b.pp) - Math.abs(a.pp));
    if (solid.length) {
      const r = solid[0];
      return { head: shortReason(r, this.name(r.id)), sub: `${fmt(r.games)} games`, tone: r.pp > 0 ? "up" : "down" };
    }
    const vs = `vs ${this.name(this.enemy)}`;
    const l = o.lane;
    if (!l || l.games < LANE_GAMES) {
      return { head: "Few games", sub: l ? `${vs} · ${fmt(l.games)} games` : vs, tone: "" };
    }
    const led = l.lane_games ? ` · led ${Math.round((100 * l.ahead) / l.lane_games)}%` : "";
    const sub = `${vs}${led} · ${fmt(l.games)} games`;
    const head = l.gold ? `${signed(l.gold)} gold at ${LANE_MINUTE}` : `Level at ${LANE_MINUTE}`;
    return { head, sub, tone: l.side > 0 ? "up" : l.side < 0 ? "down" : "" };
  }

  renderPick() {
    const p = this.p;
    $("q-pick-title").textContent = this.picked
      ? `${this.name(p.played)} was played`
      : `Last pick: ${SIDES[p.hidden_team].toLowerCase()} ${roleName[p.hidden_role].toLowerCase()}. Who did they lock in?`;
    const box = $("options");
    box.replaceChildren();
    const flip = this.picked && this.fresh === "pick" && !reduceMotion();
    p.options.forEach((o, i) => {
      const b = el("button", "dd-opt");
      b.type = "button";
      b.style.setProperty("--i", i);
      const card = el("span", "dd-card");
      const front = el("span", "dd-face dd-front");
      front.append(this.champ(o.id, 56));
      // The link inside would navigate away mid-game
      front.querySelector("a")?.removeAttribute("href");
      card.append(front);
      if (this.picked) {
        const played = o.id === p.played;
        const mine = this.mine.pick === o.id;
        b.classList.toggle("played", played);
        b.classList.toggle("chosen", mine);
        b.classList.toggle("missed", mine && !played);
        const back = el("span", "dd-face dd-back");
        back.append(this.champ(o.id, 32));
        back.querySelector("a")?.removeAttribute("href");
        // Words as well as the border colour, which some can't tell apart
        const mark = played ? (mine ? "✓ Played, your guess" : "✓ Played") : mine ? "✗ Your guess" : "";
        back.append(el("span", "dd-mark", mark || " "));
        const f = this.optionFact(o);
        back.append(el("b", `dd-fact ${f.tone}`, f.head), el("small", "dd-sub", f.sub));
        if (o.win != null) {
          const top = o.id === this.topOption;
          const w = el("small", `dd-owin${top ? " top" : ""}`, `${top ? "★ " : ""}${SIDES[p.hidden_team]} ${pct(o.win)}`);
          w.title = top
            ? "The model's pick of the four: the team's draft win chance with it"
            : "The team's draft win chance with this pick";
          back.append(w);
        }
        card.append(back);
        b.setAttribute("aria-label", `${this.name(o.id)}. ${mark ? mark.slice(2) + ". " : ""}${f.head}, ${f.sub}`);
      }
      b.append(card);
      b.disabled = this.picked;
      if (this.picked && !flip) b.classList.add("flipped");
      b.onclick = () => this.answer("pick", o.id);
      box.append(b);
    });
    // Two frames: the first lays the cards out face up, the second turns them
    if (flip) requestAnimationFrame(() => requestAnimationFrame(() => {
      for (const b of box.children) b.classList.add("flipped");
    }));
  }

  renderSide() {
    const p = this.p;
    $("q-side").hidden = !this.picked;
    const pop = this.fresh === "side" && !reduceMotion();
    for (const b of $("q-side").querySelectorAll("button")) {
      const side = Number(b.dataset.side);
      const won = this.done && p.winner === side;
      const mine = this.mine.side === side;
      b.className = `dd-side ${SIDE_CLS[side]}`;
      b.disabled = this.mine.side !== undefined;
      b.classList.toggle("chosen", mine);
      b.classList.toggle("won", won);
      b.classList.toggle("missed", this.done && mine && !won);
      b.classList.toggle("pop", won && pop);
      b.replaceChildren(el("span", "", `${SIDES[side]} side`));
      if (won) b.append(el("small", "dd-mark", mine ? "✓ Won, your guess" : "✓ Won"));
      else if (this.done && mine) b.append(el("small", "dd-mark", "✗ Your guess"));
      b.onclick = () => this.answer("side", side);
    }
  }

  renderReveal() {
    const p = this.p;
    const stats = this.record();
    this.renderScore(stats);

    const tile = (label, value, note) => {
      const d = el("div");
      d.append(el("span", "", label), el("b", "", value));
      if (note) d.append(el("small", "", note));
      return d;
    };
    const k = p.kills;
    const gold = p.gold.map(kilo);
    const winner = tile("Winner", `${SIDES[p.winner]}`, `in ${p.minutes} min`);
    winner.querySelector("b").className = `dd-win ${SIDE_CLS[p.winner]}`;
    $("happened").replaceChildren(
      winner,
      tile("Kills", `${k[0]} : ${k[1]}`, "blue : red"),
      tile("Gold", `${gold[0]} : ${gold[1]}`, "blue : red"),
    );

    const from = p.numbers_patch ?? p.patch;
    const games = `${fmt(p.games)} games on patch ${from}`;
    const est = $("estimate");
    est.replaceChildren(el("b", "", "On paper: "));
    let read;
    if (p.games < DRAFT_GAMES) {
      read = `too few games yet to read whole drafts (${games}).`;
    } else if (p.lean === "blue" || p.lean === "red") {
      const side = p.lean === "blue" ? 0 : 1;
      read = side === p.winner
        ? `leaned ${p.lean}, and ${p.lean} won (${games}).`
        : `leaned ${p.lean}, but ${SIDES[p.winner].toLowerCase()} won: a draft sets the odds, not the result (${games}).`;
    } else if (p.lean === "close") {
      read = `close; decided in play (${games}).`;
    } else {
      read = `the lanes (${games}).`;
    }
    est.append(read);
    est.hidden = !!p.review;
    this.renderVerdict();
    this.renderModelPicks();
    this.renderSeats();
    this.renderScoreboard();
    this.renderLanes();
    $("share-row").hidden = PREVIEW;
    $("share").onclick = () => this.share(stats.streak);
  }

  renderScore(stats) {
    const box = $("score");
    box.replaceChildren();
    box.classList.toggle("pop", this.fresh === "side" && !reduceMotion());
    const marks = el("div", "dd-marks");
    const m = this.mine.marks || this.marks();
    ["Pick", "Winner"].forEach((q, i) => {
      const ok = m[i] === "1";
      marks.append(el("span", ok ? "ok" : "no", `${ok ? "✓" : "✗"} ${q}`));
    });
    const right = [...m].filter((x) => x === "1").length;
    const head = el("div", "dd-result");
    head.append(el("b", "", ["Not this time", "One of two", "Both right"][right]), marks);
    const streak = el("div", "dd-streak");
    const n = el("b", stats.streak > 1 ? "hot" : "", String(stats.streak));
    streak.append(n, ` ${stats.streak === 1 ? "day" : "days"} in a row`);
    streak.title =
      "Puzzles finished on their own day. One missed day is forgiven; two in a row end it.";
    const more = [`best ${stats.best}`, `played ${stats.played}`, `both right ${stats.both}`];
    if (this.isToday) more.push(`next in ${untilMidnight()}`);
    streak.append(el("small", "", more.join(" · ")));
    box.append(head, streak);
  }

  // Who the model favoured: blue's chance as a bar with its 95% range, the result against
  // it, and the edge from each kind of term
  renderVerdict() {
    const p = this.p;
    const r = p.review;
    const box = $("verdict");
    box.hidden = !r;
    if (!r) return;
    box.replaceChildren(el("h2", "", "Who should have won, on paper"));
    const fav = r.blue_win >= 50 ? 0 : 1;
    const favWin = fav === 0 ? r.blue_win : 100 - r.blue_win;
    const clearSide = r.blue_low > 50 ? 0 : r.blue_high < 50 ? 1 : null;
    const head = el("p", "dd-v-head");
    head.append(el("b", SIDE_CLS[fav], `${SIDES[fav]} ${pct(favWin)}`));
    const sure = clearSide !== null;
    const upset = p.winner !== fav;
    head.append(sure ? " favoured. " : ", slightly ahead but not clear. ",
      el("b", SIDE_CLS[p.winner], `${SIDES[p.winner]} won`),
      sure ? (upset ? " against the odds." : " as expected.") : ".");
    box.append(head);

    const bar = el("div", "dd-wbar");
    bar.setAttribute("role", "img");
    bar.setAttribute("aria-label", `Blue ${pct(r.blue_win)}, red ${pct(100 - r.blue_win)}; blue's range ${pct(r.blue_low)} to ${pct(r.blue_high)}`);
    const blue = el("span", "dd-wb dd-blue", `Blue ${pct(r.blue_win)}`);
    blue.style.width = `${r.blue_win}%`;
    const red = el("span", "dd-wb dd-red", `${pct(100 - r.blue_win)} Red`);
    const band = el("span", "dd-wrange");
    band.style.left = `${r.blue_low}%`;
    band.style.width = `${r.blue_high - r.blue_low}%`;
    bar.append(blue, red, band, el("span", "dd-wmid"));
    box.append(bar);
    box.append(el("p", "muted dd-v-note", `95% range for blue: ${pct(r.blue_low)} to ${pct(r.blue_high)}. ` +
      (clearSide === null ? "It takes in 50%, so neither side is clear." : `It leaves out 50%: ${SIDES[clearSide].toLowerCase()} clear.`)));

    box.append(el("h3", "dd-h", "Where the edge came from"));
    const kinds = [
      ["champions", "Champions on the patch", "each champion's strength in its role"],
      ["lanes", "Lane matchups", "the five same-role pairs"],
      ["teammates", "Teammates together", "pairs on the same team"],
      ["matchups", "Other matchups", "every other pair across the teams"],
    ];
    const scale = Math.max(2, ...kinds.map(([k]) => Math.abs(r.edge[k])));
    const list = el("ul", "dd-edge");
    for (const [k, label, hint] of kinds) {
      const v = r.edge[k];
      const li = el("li");
      li.title = hint;
      const track = el("span", "dd-etrack");
      const fill = el("span", `dd-efill ${v >= 0 ? "dd-blue" : "dd-red"}`);
      fill.style.width = `${(50 * Math.abs(v)) / scale}%`;
      fill.style[v >= 0 ? "right" : "left"] = "50%";
      track.append(fill);
      const side = Math.abs(v) < 0.05 ? "even" : `${SIDES[v > 0 ? 0 : 1]} +${Math.abs(v).toFixed(1)}`;
      li.append(el("span", "", label), track, el("b", Math.abs(v) < 0.05 ? "" : SIDE_CLS[v > 0 ? 0 : 1], side));
      list.append(li);
    }
    box.append(list, el("p", "muted dd-v-note", "Points of blue's win chance each kind of term gives on its own."));
  }

  // The model's top picks for the hidden slot with the played one at its rank: the
  // team's draft win chance with each and the gap to the played champion
  renderModelPicks() {
    const p = this.p;
    const r = p.review;
    const box = $("model-picks");
    box.hidden = !r;
    if (!r) return;
    const seat = r.seats[p.hidden_team][roleIndex[p.hidden_role]];
    const side = SIDES[p.hidden_team];
    box.replaceChildren(el("h2", "", `Who should have been picked: ${side.toLowerCase()} ${roleName[p.hidden_role].toLowerCase()}`));
    const rows = r.picks.map((o, i) => ({ o, rank: i + 1 }));
    if (!r.picks.some((o) => o.id === p.played)) {
      const o = p.options.find((x) => x.id === p.played);
      rows.push(null, { o: { ...o, win: seat.win }, rank: seat.rank });
    }
    const lo = Math.min(...rows.filter(Boolean).map((x) => x.o.win)) - 0.5;
    const hi = Math.max(...rows.filter(Boolean).map((x) => x.o.win));
    const list = el("ol", "dd-mp");
    for (const row of rows) {
      if (!row) {
        list.append(el("li", "dd-mp-gap", "⋮"));
        continue;
      }
      const { o, rank } = row;
      const played = o.id === p.played;
      const li = el("li", played ? "played" : "");
      li.append(el("span", "dd-mp-rank", ordinal(rank)), this.champ(o.id, 32));
      const f = this.optionFact(o);
      const fact = el("span", "dd-mp-fact");
      fact.append(el("span", f.tone, f.head), el("small", "", f.sub));
      li.append(fact);
      const bar = el("span", "dd-mp-bar");
      const fill = el("span", SIDE_CLS[p.hidden_team]);
      fill.style.width = `${Math.max(4, (100 * (o.win - lo)) / Math.max(0.5, hi - lo))}%`;
      bar.append(fill);
      li.append(bar, el("b", "dd-mp-win", pct(o.win)));
      const gap = o.win - seat.win;
      const clearGap = Math.abs(gap) > seat.range;
      li.append(played
        ? el("span", "dd-mp-tag", "Played")
        : el("span", `dd-mp-gap-pts ${clearGap ? (gap > 0 ? "up" : "down") : ""}`, `${points(gap)} vs played`));
      list.append(li);
    }
    box.append(list);
    const top = this.name(seat.top);
    const gap = seat.top_win - seat.win;
    let verdict;
    if (seat.rank === 1) verdict = `${this.name(p.played)} was the model's own pick here.`;
    else if (gap > seat.range) verdict = `${top} over ${this.name(p.played)}: ${points(gap)} points, clear of the model's range (±${seat.range.toFixed(1)}).`;
    else verdict = `${top} rates ${points(gap)} points higher, inside the model's range (±${seat.range.toFixed(1)}): no clear difference.`;
    box.append(el("p", "dd-v-foot", verdict),
      el("p", "muted dd-v-note", `${side}'s draft win chance with each pick, the other nine and the bans as they were. ${this.name(p.played)} ranked ${ordinal(seat.rank)} of ${seat.of} with enough games in the role.`));
  }

  // Every seat as if it were the last pick: its rank among the open champions, the
  // model's pick and the gap, coloured only when clear of the range
  renderSeats() {
    const p = this.p;
    const r = p.review;
    const box = $("seats");
    box.hidden = !r;
    if (!r) return;
    box.replaceChildren(el("h2", "", "Every pick, rated"));
    const grid = el("div", "dd-sbs");
    for (const t of [0, 1]) {
      const table = el("table", `dd-sb dd-seat ${SIDE_CLS[t]}`);
      const head = el("tr");
      head.append(el("th", "l", SIDES[t]), el("th", "", "Rank"), el("th", "l", "Model's pick"), el("th", "", "Gap"));
      table.append(el("thead"), el("tbody"), el("tfoot"));
      table.tHead.append(head);
      let total = 0;
      let clearOnes = 0;
      ROLES.forEach(([role], i) => {
        const seat = r.seats[t][i];
        const tr = el("tr");
        if (t === p.hidden_team && role === p.hidden_role) tr.className = "dd-was-hidden";
        const who = el("td", "l");
        who.append(this.champ(p.teams[t][i], 24));
        const rank = el("td", seat.rank === 1 ? "dd-top" : "", seat.rank === 1 ? "★ 1st" : ordinal(seat.rank));
        rank.title = `${ordinal(seat.rank)} of ${seat.of} champions with enough games in the role`;
        const pick = el("td", "l");
        const gap = seat.top_win - seat.win;
        const clearGap = gap > seat.range;
        if (seat.rank === 1) pick.append(el("span", "muted", "same"));
        else pick.append(this.champ(seat.top, 24));
        const g = el("td", clearGap ? "dd-cost" : "muted", seat.rank === 1 ? "" : points(-gap));
        g.title = `Range ±${seat.range.toFixed(1)} points: ${clearGap ? "a clear gap" : "no clear difference"}`;
        total += gap;
        if (clearGap) clearOnes += 1;
        tr.append(who, rank, pick, g);
        table.tBodies[0].append(tr);
      });
      const foot = el("tr");
      const clears = clearOnes ? `${clearOnes} clear ${clearOnes === 1 ? "gap" : "gaps"}` : "No clear gaps";
      const sum = el("td", "l", `${clears} · ${points(-total)} points in all`);
      sum.colSpan = 4;
      foot.append(sum);
      table.tFoot.append(foot);
      grid.append(table);
    }
    box.append(grid, el("p", "muted dd-v-note",
      "Each pick as if it were the last: rank among the champions with enough games in the role, the model's top pick there and the points of win chance between them. Coloured when the gap is clear of the model's range."));
  }

  // Per team: each seat's K/D/A, CS, gold and damage to champions, by role
  renderScoreboard() {
    const p = this.p;
    const box = $("scoreboard");
    box.hidden = !p.players;
    if (!p.players) return;
    box.replaceChildren();
    for (const t of [0, 1]) {
      const table = el("table", `dd-sb ${SIDE_CLS[t]}`);
      const head = el("tr");
      const won = p.winner === t ? " · won" : "";
      head.append(el("th", "l", `${SIDES[t]}${won}`), ...["K / D / A", "CS", "Gold", "Damage"].map((h) => el("th", "", h)));
      table.append(el("thead"), el("tbody"));
      table.tHead.append(head);
      ROLES.forEach(([role], r) => {
        const pl = p.players[t][r];
        const tr = el("tr");
        if (t === p.hidden_team && role === p.hidden_role) tr.className = "dd-was-hidden";
        const who = el("td", "l");
        who.append(this.champ(p.teams[t][r], 24));
        tr.append(
          who,
          el("td", "", `${pl.kills} / ${pl.deaths} / ${pl.assists}`),
          el("td", "", fmt(pl.cs)),
          el("td", "", kilo(pl.gold)),
          el("td", "", kilo(pl.damage)),
        );
        table.tBodies[0].append(tr);
      });
      box.append(table);
    }
  }

  // Each lane at 14: this game's gold difference, then the patch's usual one (from the
  // lane curves: a side only when clear), with the games behind it
  renderLanes() {
    const p = this.p;
    const list = $("lanes");
    list.replaceChildren();
    ROLES.forEach(([, label], r) => {
      const lane = p.lanes[r];
      const g = lane.gold;
      const li = el("li");
      li.append(el("span", "role", label), this.champ(p.teams[0][r], 28));
      const mid = el("span", "dd-lane-fact");
      const b = p.players?.[0][r].gold14;
      const red = p.players?.[1][r].gold14;
      if (b != null && red != null) {
        const d = b - red;
        const side = d > 0 ? 0 : 1;
        const text = d ? `${SIDES[side]} ${signed(Math.abs(d))} at ${LANE_MINUTE}` : `Level at ${LANE_MINUTE}`;
        mid.append(el("span", `dd-chip ${Math.abs(d) < MIN_LEAD ? "" : SIDE_CLS[side]}`, text));
      }
      let chip, cls, games;
      if (g && g.games >= LANE_GAMES) {
        games = g.games;
        const side = g.gold > 0 ? 0 : 1;
        chip = g.gold ? `usually ${SIDES[side].toLowerCase()} ${signed(Math.abs(g.gold))}` : "usually level";
        if (g.side) cls = SIDE_CLS[g.side > 0 ? 0 : 1];
      } else {
        games = g ? g.games : lane.games;
        chip = "usually: few games";
      }
      if (!cls && b == null) li.classList.add("thin");
      mid.append(el("span", `dd-usual ${cls || ""}`, chip));
      // Who should win the lane: both champions' ratings and the matchup, the rest even.
      // Coloured from 2 points; older puzzles show the matchup edge only when clear
      if (lane.win != null) {
        const side = lane.win >= 50 ? 0 : 1;
        const w = side === 0 ? lane.win : 100 - lane.win;
        const fav = el("span", `dd-chip dd-fav ${w >= 52 ? SIDE_CLS[side] : ""}`, `${this.name(p.teams[side][r])} favoured ${pct(w)}`);
        fav.title = "Win chance from this lane alone: both champions on the patch and their matchup";
        mid.append(fav);
      } else if (clear(lane.pp, lane.games)) {
        const side = lane.pp > 0 ? 0 : 1;
        mid.append(el("span", `dd-chip ${SIDE_CLS[side]}`, `${SIDES[side]} wins it more`));
      }
      mid.append(el("small", "", `${fmt(games)} games`));
      li.append(mid, this.champ(p.teams[1][r], 28));
      list.append(li);
    });
  }

  get isToday() {
    return this.p.n === this.live[this.live.length - 1].n;
  }

  // From an archive puzzle, the way back to today's (the shared one)
  renderBack() {
    let back = $("back");
    if (this.isToday) {
      back?.remove();
      return;
    }
    if (!back) {
      back = document.createElement("p");
      back.id = "back";
      const a = document.createElement("a");
      a.href = location.pathname;
      a.textContent = "Today's puzzle";
      back.append("Archive puzzle: doesn't count towards days in a row. ", a);
      $("about").after(back);
    }
  }

  // Days in a row and best: see streaks(); played and both right count every puzzle
  record() {
    const done = (n) => {
      const r = this.results[n];
      return r && r.pick !== undefined && r.side !== undefined;
    };
    const onTime = (e) => done(e.n) && this.results[e.n].on === e.date;
    const { streak, best } = streaks(this.live.map(onTime));
    let played = 0;
    let both = 0;
    for (const e of this.live) {
      if (!done(e.n)) continue;
      played += 1;
      // Only today's puzzle is loaded; older ones keep the marks saved with them
      const r = this.results[e.n];
      if (r.marks === "11") both += 1;
    }
    return { played, streak, both, best };
  }

  marks() {
    return `${this.mine.pick === this.p.played ? 1 : 0}${this.mine.side === this.p.winner ? 1 : 0}`;
  }

  async share(streak) {
    const squares = glyphs(this.mine.marks);
    const url = `${location.origin}${location.pathname}?n=${this.p.n}`;
    const text = `meiolol Daily Draft #${this.p.n}\n${squares} (pick, winner)` +
      (streak > 1 ? `\n🔥 ${streak} days in a row` : "") + `\n${url}`;
    const note = $("share-note");
    try {
      if (navigator.share) {
        await navigator.share({ text });
        return;
      }
      await navigator.clipboard.writeText(text);
      note.textContent = "Copied";
    } catch (e) {
      if (e && e.name === "AbortError") return;
      note.textContent = text;
    }
  }

  renderArchive() {
    const list = $("archive");
    list.replaceChildren();
    for (const e of [...this.live].reverse()) {
      const li = el("li", "bx");
      const a = el("a", "box");
      a.href = `?n=${e.n}`;
      a.textContent = `#${e.n}, ${longDate(e.date)}`;
      if (e.n === this.p.n) a.setAttribute("aria-current", "page");
      li.append(a);
      const r = this.results[e.n];
      const span = el("span", "muted", r && r.marks ? glyphs(r.marks) : r ? "started" : "not played");
      if (r && r.marks) span.title = marksText(r.marks);
      li.append(span);
      list.append(li);
    }
  }
}

function untilMidnight() {
  const now = new Date();
  const next = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
  const mins = Math.ceil((next - now) / 60000);
  return `${Math.floor(mins / 60)}h ${pad(mins % 60)}m`;
}

start();
