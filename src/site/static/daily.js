// Daily Draft: puzzles from src/daily.zig (daily/index.json lists them, daily/<n>.json
// each). Guess the hidden champion, then the winner; the reveal explains in words from
// this patch's games, never a win chance or points (production-key.md). Results, streak
// and archive stay in this browser (localStorage). Reasons: reasons.js.
"use strict";

const ROLES = [
  ["top", "Top"],
  ["jungle", "Jungle"],
  ["middle", "Mid"],
  ["bottom", "Bot"],
  ["utility", "Support"],
];
const roleName = Object.fromEntries(ROLES);
const SIDES = ["Blue", "Red"];
const KEY = "meiolol.daily.v1";
// Win-rate numbers are noise until there is a lot of data (draft model eval: level with
// a coin flip on 6k games). A pair edge needs PAIR_GAMES games and must clear chance
// (|pp| > 1.96 SE, SE = 50 / sqrt(n) points); reading whole drafts needs DRAFT_GAMES
// games on the patch
const PAIR_GAMES = 400;
const DRAFT_GAMES = 100000;
const clear = (pp, n) => n >= PAIR_GAMES && Math.abs(pp) > 98 / Math.sqrt(n);

const $ = (id) => document.getElementById(id);
const pad = (n) => String(n).padStart(2, "0");

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


// Tick and cross, not green and red squares: the shapes read without colour
const glyphs = (marks) => [...marks].map((m) => (m === "1" ? "✅" : "❌")).join("");
const marksText = (marks) =>
  ["pick", "winner"].map((q, i) => `${q} ${marks[i] === "1" ? "right" : "wrong"}`).join(", ");

const guessTag = (right) => tag(right ? "your guess, right" : "your guess");

function tag(text) {
  const t = document.createElement("span");
  t.className = "tag";
  t.textContent = text;
  return t;
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
    // A span so the phone lane table can hide it visually, leaving the icon
    const name = document.createElement("span");
    name.className = "name";
    name.textContent = this.name(id);
    a.append(name);
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
    this.render();
  }

  get picked() {
    return this.mine.pick !== undefined;
  }

  get done() {
    return this.picked && this.mine.side !== undefined;
  }

  render() {
    const p = this.p;
    $("number").textContent = `#${p.n}`;
    this.renderBack();
    const tier = p.tier ? `, mostly ${p.tier[0]}${p.tier.slice(1).toLowerCase()} players` : "";
    // The date is the puzzle's, not the game's (src/daily.zig min_age_days)
    $("about").textContent =
      `Puzzle for ${longDate(p.date)}: a ranked solo/duo game from patch ${p.patch}, at least a week old${tier}.`;
    this.renderBoard();
    this.renderPick();
    $("q-side").hidden = !this.picked;
    for (const b of $("q-side").querySelectorAll("button")) {
      const side = Number(b.dataset.side);
      b.disabled = this.mine.side !== undefined;
      b.classList.toggle("chosen", this.mine.side === side);
      b.classList.toggle("played", this.done && p.winner === side);
      b.replaceChildren(`${SIDES[side]} side`);
      if (this.done && p.winner === side) b.append(" ", tag("won"));
      if (this.done && this.mine.side === side) b.append(" ", guessTag(p.winner === side));
      b.onclick = () => this.answer("side", side);
    }
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
        const tag = document.createElement("span");
        tag.className = "role";
        tag.textContent = label;
        li.append(tag);
        const hidden = t === p.hidden_team && role === p.hidden_role;
        if (hidden && !this.picked) {
          li.classList.add("hidden-slot");
          li.append("?");
        } else {
          li.append(this.champ(p.teams[t][r]));
        }
        list.append(li);
      });
      const bans = $(`bans-${t}`);
      bans.replaceChildren(p.bans[t].length ? "Bans: " : "No bans");
      p.bans[t].forEach((id, i) => {
        if (i > 0) bans.append(", ");
        bans.append(this.name(id));
      });
    }
  }

  renderPick() {
    const p = this.p;
    $("q-pick-title").textContent =
      `Which champion was played ${roleName[p.hidden_role].toLowerCase()} for ${SIDES[p.hidden_team].toLowerCase()} side?`;
    // Older puzzles hid a random slot
    $("q-pick-hint").hidden = p.hidden_by !== "fit";
    const box = $("options");
    box.replaceChildren();
    for (const o of p.options) {
      const b = document.createElement("button");
      b.type = "button";
      b.append(this.champ(o.id, 40));
      // The link inside would navigate away mid-game
      b.querySelector("a")?.removeAttribute("href");
      b.disabled = this.picked;
      b.classList.toggle("chosen", this.mine.pick === o.id);
      b.classList.toggle("played", this.picked && o.id === p.played);
      // Labels as well as the border colour, which some can't tell apart
      if (this.picked && o.id === p.played) b.append(tag("played"));
      if (this.picked && this.mine.pick === o.id) b.append(guessTag(o.id === p.played));
      b.onclick = () => this.answer("pick", o.id);
      box.append(b);
    }
  }

  renderReveal() {
    const p = this.p;
    const won = SIDES[p.winner];
    const k = p.kills;
    const gold = p.gold.map((g) => `${(g / 1000).toFixed(1)}k`);
    $("happened").textContent =
      `${this.name(p.played)} was played. ${won} side won in ${p.minutes} minutes, ` +
      `kills ${k[0]} to ${k[1]}, gold ${gold[0]} to ${gold[1]} (blue first). ` +
      `You guessed ${this.name(this.mine.pick)} and ${SIDES[this.mine.side].toLowerCase()} side.`;

    const enough = p.games >= DRAFT_GAMES;
    const from = p.numbers_patch ?? p.patch;
    const games = `${p.games.toLocaleString("en-GB")} ranked solo games on patch ${from}`;
    let read;
    if (!enough) {
      read = `Patch ${from} has ${p.games.toLocaleString("en-GB")} ranked solo games so far: too few to read whole drafts, so lanes and reasons below show only where the games behind them are enough.`;
    } else if (p.lean === "blue" || p.lean === "red") {
      const side = p.lean === "blue" ? 0 : 1;
      read = `On paper the draft leaned ${p.lean} (${games}). ` + (side === p.winner
        ? `${SIDES[side]} side won.`
        : `${SIDES[side]} side still lost: a draft sets the odds, not the result.`);
    } else if (p.lean === "close") {
      read = `On paper, close: the draft set up little, and the game was decided in play (${games}).`;
    } else {
      read = `From ${games}:`;
    }
    $("estimate").textContent = read;

    const lanes = $("lanes");
    lanes.replaceChildren();
    ROLES.forEach(([, label], r) => {
      const lane = p.lanes[r];
      const tr = document.createElement("tr");
      const shown = clear(lane.pp, lane.games);
      if (!shown) tr.className = "thin";
      const cell = (child, cls) => {
        const td = document.createElement("td");
        if (cls) td.className = cls;
        td.append(child);
        tr.append(td);
      };
      cell(label);
      cell(this.champ(p.teams[0][r], 24));
      cell(this.champ(p.teams[1][r], 24));
      const edge = shown
        ? lane.pp > 0 ? "blue" : "red"
        : lane.games < PAIR_GAMES ? "few games" : "no clear edge";
      cell(edge, "num");
      cell(String(lane.games), "num");
      lanes.append(tr);
    });

    const notes = $("option-notes");
    notes.replaceChildren();
    const role = roleName[p.hidden_role].toLowerCase();
    // Same order as the question: ranking them would read as a verdict on the pick
    for (const o of p.options) {
      const li = document.createElement("li");
      const head = document.createElement("div");
      head.append(this.champ(o.id));
      const sub = document.createElement("span");
      sub.className = "muted";
      sub.textContent = ` ${o.games} games in ${role} on patch ${from}`;
      head.append(sub);
      if (o.id === p.played) {
        const tag = document.createElement("span");
        tag.className = "tag";
        tag.textContent = "played";
        head.append(tag);
      }
      li.append(head);
      const solid = o.reasons.filter((r) =>
        r.kind !== "base" && detectedReason(p.hidden_role, r) && clear(r.pp, r.games));
      for (const r of solid) {
        const why = document.createElement("div");
        why.className = "why";
        why.textContent =
          `${reasonWords(r, this.name(r.id))} (${roleName[r.role].toLowerCase()}, ${r.games} games).`;
        li.append(why);
      }
      notes.append(li);
    }

    const stats = this.record();
    $("record").textContent =
      `Played ${stats.played} · ${stats.streak} ${stats.streak === 1 ? "day" : "days"} in a row · ` +
      `both guesses right ${stats.both}` +
      (this.isToday ? ` · next puzzle in ${untilMidnight()}` : "");
    $("share").onclick = () => this.share(stats.streak);
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
      back.append("Archive puzzle, not today's: it doesn't count towards days in a row. ", a);
      $("about").after(back);
    }
  }

  // Days in a row: consecutive published puzzles each finished on its own day, ending with
  // today's or the one before (a day without a puzzle does not break it)
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
    for (const e of this.live) {
      if (!done(e.n)) continue;
      played += 1;
      // Only today's puzzle is loaded; older ones keep the marks saved with them
      const r = this.results[e.n];
      if (r.marks === "11") both += 1;
    }
    return { played, streak, both };
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
      const span = document.createElement("span");
      span.className = "muted";
      span.textContent = r && r.marks ? glyphs(r.marks) : r ? "started" : "not played";
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
