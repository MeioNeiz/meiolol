// Daily Draft: puzzles from src/daily.zig (daily/index.json lists them, daily/<n>.json
// each). Guess the hidden champion, then the winner. The options flip to one fact each
// and the reveal reads the lanes, in words and game counts from this patch's games: never
// a win chance, points or gold amounts (J1, docs/plan/decisions.md). Results, streaks and
// archive stay in this browser (localStorage); nothing is sent. Reasons: reasons.js.
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

const $ = (id) => document.getElementById(id);
const pad = (n) => String(n).padStart(2, "0");
const fmt = (n) => n.toLocaleString("en-GB");
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
    new Game(puzzle, meta, live).render();
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
    if (field === "side") $("reveal").scrollIntoView({ behavior: reduceMotion() ? "auto" : "smooth", block: "start" });
  }

  get picked() {
    return this.mine.pick !== undefined;
  }

  get done() {
    return this.picked && this.mine.side !== undefined;
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
    // The date is the puzzle's, not the game's (src/daily.zig min_age_days)
    $("about").textContent = `${longDate(p.date)} · EUW ranked solo/duo · patch ${p.patch}${tier}`;
    this.renderBoard();
    this.renderPick();
    this.renderSide();
    $("reveal").hidden = !this.done;
    if (this.done) this.renderReveal();
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
    const sub = `${vs} · ${fmt(l.games)} games`;
    if (l.side > 0) return { head: `Ahead at ${LANE_MINUTE} min`, sub: `gold ${sub}`, tone: "up" };
    if (l.side < 0) return { head: `Behind at ${LANE_MINUTE} min`, sub: `gold ${sub}`, tone: "down" };
    return { head: "No clear lane lead", sub, tone: "" };
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
    const gold = p.gold.map((g) => `${(g / 1000).toFixed(1)}k`);
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
    this.renderLanes();
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
    const more = [`best ${stats.best}`, `played ${stats.played}`, `both right ${stats.both}`];
    if (this.isToday) more.push(`next in ${untilMidnight()}`);
    streak.append(el("small", "", more.join(" · ")));
    box.append(head, streak);
  }

  // Each lane: who was ahead in gold at 14 (or nothing clear), and the games behind it
  renderLanes() {
    const p = this.p;
    const list = $("lanes");
    list.replaceChildren();
    ROLES.forEach(([, label], r) => {
      const lane = p.lanes[r];
      const g = lane.gold;
      const li = el("li");
      li.append(el("span", "role", label), this.champ(p.teams[0][r], 28));
      let chip, cls, games;
      if (g && g.games >= LANE_GAMES) {
        games = g.games;
        if (g.side) {
          const side = g.side > 0 ? 0 : 1;
          chip = `${SIDES[side]} ahead at ${LANE_MINUTE}`;
          cls = `${SIDE_CLS[side]}`;
        } else chip = "No clear lead";
      } else {
        games = g ? g.games : lane.games;
        chip = "Few games";
      }
      if (!cls) li.classList.add("thin");
      const mid = el("span", "dd-lane-fact");
      mid.append(el("span", `dd-chip ${cls || ""}`, chip));
      // The draft model's lane edge, when it clears chance (rare until a lot of data)
      if (clear(lane.pp, lane.games)) {
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

  // Days in a row: consecutive published puzzles each finished on its own day, ending with
  // today's or the one before (a day without a puzzle does not break it); best, the
  // longest such run
  record() {
    const done = (n) => {
      const r = this.results[n];
      return r && r.pick !== undefined && r.side !== undefined;
    };
    const onTime = (e) => done(e.n) && this.results[e.n].on === e.date;
    let i = this.live.length - 1;
    if (!onTime(this.live[i])) i -= 1;
    let streak = 0;
    while (i >= 0 && onTime(this.live[i])) {
      streak += 1;
      i -= 1;
    }
    let played = 0;
    let both = 0;
    let best = 0;
    let run = 0;
    for (const e of this.live) {
      run = onTime(e) ? run + 1 : 0;
      best = Math.max(best, run);
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
      const li = document.createElement("li");
      const a = document.createElement("a");
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
