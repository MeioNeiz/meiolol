// Learn: lesson checks (embedded in learn.html) and practice drafts from
// learn/practice.json (src/learn.zig). Champions the player picks are scored with the
// site's recommender (meiolol.wasm, src/wasm.zig) when they join a draft's options.
// Progress stays in this browser (localStorage); no streaks, no timers.
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
const LEVELS = [
  ["easy", "Easy"],
  ["medium", "Medium"],
  ["hard", "Hard"],
];
const KEY = "meiolol.learn.v1";
// A champion counts as playing a role from this many games there (champions.json)
const POOL_MIN_GAMES = 15;
// Game length buckets need this many games each before a timing fact is shown
const LENGTH_MIN_GAMES = 40;
// Pseudo-games pulling a length bucket toward the champion's own win rate
const LENGTH_PRIOR = 30;
// Lane curves with fewer games are drawn greyed out
const THIN = 200;
// Model reasons smaller than this are left out of the plain-words list
const MIN_REASON_PP = 0.3;
// Pairs with fewer games are mostly chance at today's volumes
const MIN_REASON_GAMES = 50;

const $ = (id) => document.getElementById(id);
const el = (tag, cls, text) => {
  const e = document.createElement(tag);
  if (cls) e.className = cls;
  if (text !== undefined) e.textContent = text;
  return e;
};
const pct = (part, whole) => Math.round((100 * part) / whole);

function loadState() {
  try {
    const s = JSON.parse(localStorage.getItem(KEY));
    if (s && typeof s === "object" && !Array.isArray(s)) {
      return { lessons: {}, practice: 0, role: "", level: "easy", pool: [], ...s };
    }
  } catch {
    // Unreadable: start afresh
  }
  return { lessons: {}, practice: 0, role: "", level: "easy", pool: [] };
}

const state = loadState();

function save() {
  try {
    localStorage.setItem(KEY, JSON.stringify(state));
  } catch {
    // Private mode or storage blocked: works for this visit, then forgets
  }
}

const glossary = JSON.parse($("glossary").textContent);

// A word with its glossary tip, as in the server-rendered lessons
function term(key, text) {
  const d = el("dfn", "term", text);
  d.tabIndex = 0;
  d.dataset.tip = glossary[key];
  return d;
}

function renderProgress() {
  const keys = [...document.querySelectorAll(".lesson")].map((l) => l.dataset.lesson);
  const done = keys.filter((k) => lessonDone(k)).length;
  const n = state.practice;
  $("progress").textContent =
    `Lessons done: ${done} of ${keys.length} · Practice drafts played: ${n}`;
}

// ---- Lessons ----

const checks = JSON.parse($("checks").textContent);

function lessonDone(key) {
  const l = state.lessons[key];
  const qs = checks[key] || [];
  return !!l && qs.length > 0 && qs.every((_, i) => l.answers && l.answers[i] !== undefined);
}

let champs = null;
let ddragon = "";

function icon(id, size) {
  const c = champs && champs.get(id);
  if (!c) return null;
  const img = document.createElement("img");
  img.src = `https://ddragon.leagueoflegends.com/cdn/${ddragon}/img/champion/${c.key}.png`;
  img.alt = "";
  img.width = img.height = size;
  return img;
}

// `focus`: after a re-render the clicked button is gone, so keyboard focus moves to the
// answer's explanation ({why: i}) or the first choice ({first: true})
function renderCheck(box, focus = null) {
  const key = box.dataset.lesson;
  const qs = checks[key] || [];
  // Kept in state only once answered or opened, so rendering marks nothing as started
  const mine = state.lessons[key] || { seen: true, answers: [] };
  mine.answers ||= [];
  box.querySelectorAll(".q").forEach((q) => q.remove());
  // Focused once in the document; focus() on a detached element does nothing
  let focusAfter = null;
  qs.forEach((q, i) => {
    const wrap = el("div", "q");
    wrap.append(el("p", "q-text", `${i + 1}. ${q.q}`));
    const row = el("div", "choices");
    const answered = mine.answers[i] !== undefined;
    q.choices.forEach((c, j) => {
      const b = el("button");
      b.type = "button";
      const img = c.id !== undefined && c.id !== null ? icon(c.id, 28) : null;
      if (img) b.append(img);
      b.append(c.t);
      b.disabled = answered;
      if (answered) {
        b.classList.toggle("chosen", mine.answers[i] === j);
        b.classList.toggle("played", j === q.answer);
      }
      b.onclick = () => {
        mine.answers[i] = j;
        state.lessons[key] = mine;
        save();
        renderCheck(box, { why: i });
        renderLessonMarks();
        renderProgress();
      };
      row.append(b);
    });
    wrap.append(row);
    if (answered) {
      const right = mine.answers[i] === q.answer;
      const why = el("p", `why ${right ? "good" : "bad"}`);
      why.tabIndex = -1;
      why.append(el("b", "", right ? "Right. " : "Not quite. "), q.why);
      wrap.append(why);
      if (focus && focus.why === i) focusAfter = why;
    }
    box.append(wrap);
  });
  if (qs.length === 0) box.append(el("p", "q muted", "Not enough games yet for questions."));
  else if (qs.every((_, i) => mine.answers[i] !== undefined)) {
    const again = el("button", "q link", "Try these again");
    again.type = "button";
    again.onclick = () => {
      mine.answers = [];
      save();
      renderCheck(box, { first: true });
      renderLessonMarks();
      renderProgress();
    };
    box.append(again);
  }
  if (focus && focus.first) focusAfter = box.querySelector(".q button");
  if (focusAfter) focusAfter.focus();
}

function renderLessonMarks() {
  for (const d of document.querySelectorAll(".lesson")) {
    const key = d.dataset.lesson;
    const mark = d.querySelector(".lesson-done");
    mark.textContent = lessonDone(key) ? "✓ Done" : state.lessons[key] ? "Started" : "";
  }
}

function setupLessons() {
  for (const d of document.querySelectorAll(".lesson")) {
    d.addEventListener("toggle", () => {
      if (!d.open) return;
      const key = d.dataset.lesson;
      state.lessons[key] ||= { seen: true, answers: [] };
      save();
      renderLessonMarks();
      renderProgress();
    });
  }
  for (const box of document.querySelectorAll(".check")) renderCheck(box);
  renderLessonMarks();
  // Open the first lesson not yet done, so a returning reader carries on there
  const next = [...document.querySelectorAll(".lesson")].find((d) => !lessonDone(d.dataset.lesson));
  if (next && !location.hash) next.open = true;
}

// ---- Practice ----

const getJson = (url) =>
  fetch(url).then((r) => {
    if (!r.ok) throw new Error(`${url}: ${r.status}`);
    return r.json();
  });

let wasm = null;

// The recommender, loaded only once the player has champions of their own
async function scorer() {
  if (wasm) return wasm;
  const [wasmBytes, model] = await Promise.all([
    fetch("meiolol.wasm").then((r) => r.arrayBuffer()),
    // The current patch view's, like the rest of Learn (html.View.shared)
    fetch("patch/data/stats.bin").then((r) => r.arrayBuffer()),
  ]);
  const { instance } = await WebAssembly.instantiate(wasmBytes, {});
  const x = instance.exports;
  const put = (bytes) => {
    const ptr = x.alloc(bytes.length);
    new Uint8Array(x.memory.buffer, ptr, bytes.length).set(bytes);
    return ptr;
  };
  const modelBytes = new Uint8Array(model);
  if (x.load(put(modelBytes), modelBytes.length) !== 0) throw new Error("bad model file");
  wasm = (req) => {
    const bytes = new TextEncoder().encode(JSON.stringify(req));
    const ptr = put(bytes);
    const out = x.suggest(ptr, bytes.length);
    x.free(ptr, bytes.length);
    if (!out) return [];
    return JSON.parse(new TextDecoder().decode(new Uint8Array(x.memory.buffer, out, x.result_len())));
  };
  return wasm;
}

class Practice {
  constructor(pack, facts, meta) {
    this.pack = pack;
    this.facts = new Map(facts.champions.map((c) => [c.id, c]));
    this.lengths = facts.lengths;
    this.meta = meta;
    this.byName = new Map(meta.champions.map((c) => [c.name.toLowerCase(), c]));
    this.queue = [];
    this.current = null;
  }

  name(id) {
    const c = champs.get(id);
    return c ? c.name : "?";
  }

  champ(id, size = 32, link = true) {
    const c = champs.get(id);
    const a = el(c && link ? "a" : "span", "champ");
    if (c && link) a.href = `champion/${c.slug}.html`;
    const img = icon(id, size);
    if (img) a.append(img);
    a.append(this.name(id));
    return a;
  }

  roleGames(id, role) {
    const c = champs.get(id);
    return c ? c.games[roleIndex[role]] : 0;
  }

  // Games and wins in `role` by game length, from champs.json
  length(id, role) {
    const f = this.facts.get(id);
    const flat = f ? f.length[roleIndex[role]] : [];
    const out = [];
    for (let i = 0; i < flat.length; i += 2) out.push({ games: flat[i], wins: flat[i + 1] });
    return out;
  }

  magic(id) {
    const f = this.facts.get(id);
    return f && f.magic !== null ? Math.round(f.magic * 100) : null;
  }

  setup() {
    const roles = $("p-roles");
    for (const [r, label] of [["", "Any"], ...ROLES]) {
      const b = el("button", "", label);
      b.type = "button";
      b.dataset.role = r;
      b.onclick = () => {
        state.role = r;
        save();
        this.queue = [];
        this.renderSetup();
        this.next();
      };
      roles.append(b);
    }
    const levels = $("p-levels");
    for (const [l, label] of LEVELS) {
      const b = el("button", "", label);
      b.type = "button";
      b.dataset.level = l;
      b.onclick = () => {
        state.level = l;
        save();
        this.queue = [];
        this.renderSetup();
        this.next();
      };
      levels.append(b);
    }
    const list = $("p-champions");
    for (const c of this.meta.champions) {
      const o = document.createElement("option");
      o.value = c.name;
      list.append(o);
    }
    const input = $("p-pool-input");
    const add = () => {
      const c = this.byName.get(input.value.trim().toLowerCase());
      if (!c) return;
      if (!state.pool.includes(c.id)) state.pool.push(c.id);
      input.value = "";
      save();
      this.renderSetup();
    };
    input.addEventListener("change", add);
    input.addEventListener("keydown", (e) => {
      if (e.key === "Enter") add();
    });
    $("p-next").onclick = async () => {
      // May wait for the recommender to load; focus the question once it is drawn
      await this.next();
      $("drill").scrollIntoView({ behavior: "smooth", block: "start" });
      $("p-question").focus({ preventScroll: true });
    };
    this.renderSetup();
    this.next();
  }

  renderSetup() {
    for (const b of $("p-roles").children) b.setAttribute("aria-pressed", b.dataset.role === state.role);
    for (const b of $("p-levels").children) b.setAttribute("aria-pressed", b.dataset.level === state.level);
    const chips = $("p-pool");
    chips.replaceChildren();
    for (const id of state.pool) {
      const chip = el("span", "chip");
      chip.append(this.champ(id, 20, false));
      const x = el("button", "chip-x", "×");
      x.type = "button";
      x.setAttribute("aria-label", `Remove ${this.name(id)}`);
      x.onclick = () => {
        state.pool = state.pool.filter((p) => p !== id);
        save();
        this.renderSetup();
      };
      chip.append(x);
      chips.append(chip);
    }
  }

  // Drafts for the chosen role and level, each once in a random order, then again
  async next() {
    const status = $("p-status");
    if (this.queue.length === 0) {
      const fits = this.pack.filter(
        (d) => (!state.role || d.hidden_role === state.role) && d.difficulty === state.level,
      );
      if (fits.length === 0) {
        status.hidden = false;
        status.textContent = "No practice drafts for this choice yet. Try another role or level.";
        $("drill").hidden = true;
        return;
      }
      this.queue = fits.slice().sort(() => Math.random() - 0.5);
      if (this.current) status.textContent = "";
    }
    status.hidden = true;
    const d = this.queue.pop();
    this.current = { d, options: d.options, mine: null, pool: null };
    await this.withPool();
    $("drill").hidden = false;
    this.render();
  }

  // One of the player's champions in place of an option that does not bring what the
  // team needs (or any, on a balanced team), scored together by the recommender
  async withPool() {
    const cur = this.current;
    const d = cur.d;
    const taken = new Set([...d.teams.flat(), ...d.bans.flat()]);
    taken.delete(d.played);
    const own = state.pool.filter(
      (id) =>
        !taken.has(id) &&
        !d.options.some((o) => o.id === id) &&
        this.roleGames(id, d.hidden_role) >= POOL_MIN_GAMES,
    );
    if (own.length === 0) return;
    const mine = own[Math.floor(Math.random() * own.length)];
    const replace = d.options.findIndex((o) => !this.brings(d, o.id));
    if (replace < 0) return;
    const ids = d.options.map((o) => o.id);
    ids[replace] = mine;
    let scored;
    try {
      const score = await scorer();
      const allies = [];
      const enemies = [];
      ROLES.forEach(([r], i) => {
        if (r !== d.hidden_role) allies.push({ id: d.teams[d.hidden_team][i], role: r });
        enemies.push({ id: d.teams[1 - d.hidden_team][i], role: r });
      });
      scored = score({
        role: d.hidden_role,
        allies,
        enemies,
        bans: d.bans.flat(),
        pool: ids,
        top: 4,
        min_games: 0,
      });
    } catch {
      return;
    }
    if (scored.length !== 4) return;
    cur.pool = mine;
    cur.options = ids.map((id) => {
      const s = scored.find((x) => x.id === id);
      const lengths = this.length(id, d.hidden_role);
      const kept = d.options.find((o) => o.id === id);
      return {
        id,
        pp: s.pp,
        games: lengths.reduce((n, b) => n + b.games, 0),
        wins: lengths.reduce((n, b) => n + b.wins, 0),
        magic: this.magic(id),
        reasons: s.reasons,
        lane: kept ? kept.lane : null,
      };
    });
  }

  // Brings the damage type the team lacks
  brings(d, id) {
    const m = this.magic(id);
    if (!d.need || m === null) return false;
    return d.need === "magic" ? m >= 60 : m <= 40;
  }

  lacks(d, id) {
    const m = this.magic(id);
    if (!d.need || m === null) return false;
    return d.need === "magic" ? m <= 30 : m >= 70;
  }

  enemyLaner(d) {
    return d.teams[1 - d.hidden_team][roleIndex[d.hidden_role]];
  }

  render() {
    const { d, mine } = this.current;
    const tier = d.tier ? `, mostly ${d.tier[0]}${d.tier.slice(1).toLowerCase()} players` : "";
    const level = LEVELS.find(([l]) => l === d.difficulty)[1];
    $("p-about").textContent = `${level} · Ranked solo/duo, patch ${d.patch}${tier}.`;
    for (const t of [0, 1]) {
      const yours = t === d.hidden_team;
      $(`p-side-${t}`).textContent =
        `${yours ? "Your team" : "Enemy team"} (${t === 0 ? "blue" : "red"} side)`;
      const list = $(`p-team-${t}`);
      list.replaceChildren();
      ROLES.forEach(([role, label], r) => {
        const li = el("li");
        li.append(el("span", "role", label));
        if (yours && role === d.hidden_role) {
          if (mine === null) {
            li.classList.add("hidden-slot");
            li.append("You");
          } else {
            const you = el("span", "you");
            you.append(this.champ(mine), el("span", "tag", "you"));
            li.append(you);
          }
        } else li.append(this.champ(d.teams[t][r]));
        list.append(li);
      });
      const bans = $(`p-bans-${t}`);
      bans.replaceChildren(d.bans[t].length ? "Bans: " : "No bans");
      d.bans[t].forEach((id, i) => {
        if (i > 0) bans.append(", ");
        bans.append(this.name(id));
      });
    }
    $("p-question").textContent =
      `You are ${roleName[d.hidden_role].toLowerCase()} for your team. Which of these would you pick?`;
    this.renderHints();
    this.renderOptions();
    $("p-reveal").hidden = mine === null;
    if (mine !== null) this.renderReveal();
  }

  hints() {
    const { d, pool } = this.current;
    const out = [];
    const role = roleName[d.hidden_role].toLowerCase();
    const enemy = this.enemyLaner(d);
    const lane = [`You will face ${this.name(enemy)} in your `, term("lane", "lane"), "."];
    const t = this.timing(enemy, d.hidden_role);
    if (t) lane.push(` ${this.name(enemy)} does better in ${t.long ? "long" : "short"} games this patch.`);
    out.push(lane);
    const ally = (r) => d.teams[d.hidden_team][roleIndex[r]];
    if (d.need === "magic") {
      out.push(["Your team so far deals mostly ", term("physical", "physical damage"), ": the enemy can answer all of it with ", term("armour", "armour"), "."]);
    } else if (d.need === "physical") {
      out.push(["Your team so far deals mostly ", term("magic", "magic damage"), ": the enemy can answer all of it with magic resist."]);
    } else {
      out.push(["Your team's damage is already a mix of magic and physical, so damage type does not separate these options much."]);
    }
    if (d.hidden_role === "bottom") out.push([`Your support is ${this.name(ally("utility"))}: you share the lane.`]);
    if (d.hidden_role === "utility") out.push([`Your bot laner is ${this.name(ally("bottom"))}: you share the lane.`]);
    if (pool !== null) out.push([`You play ${this.name(pool)}, and it is one of the options.`]);
    return out;
  }

  // Hints one at a time, so there is one thing to think about at once
  renderHints() {
    const box = $("p-hints");
    box.replaceChildren();
    const cur = this.current;
    const all = this.hints();
    cur.shown ||= 0;
    const list = el("ul", "hint-list");
    const shown = cur.mine === null ? cur.shown : all.length;
    for (const h of all.slice(0, shown)) {
      const li = el("li");
      li.append(...h);
      list.append(li);
    }
    if (shown > 0) box.append(list);
    if (shown < all.length) {
      const b = el("button", "link", shown === 0 ? "Show a hint" : "Another hint");
      b.type = "button";
      b.onclick = () => {
        cur.shown += 1;
        this.renderHints();
        // The button is re-created: keep focus on it, or on the options once hints run out
        const again = box.querySelector("button") || $("p-options").querySelector("button");
        if (again) again.focus();
      };
      box.append(b);
    }
  }

  renderOptions() {
    const cur = this.current;
    const box = $("p-options");
    box.replaceChildren();
    for (const o of cur.options) {
      const b = el("button");
      b.type = "button";
      b.append(this.champ(o.id, 40, false));
      b.disabled = cur.mine !== null;
      b.classList.toggle("chosen", cur.mine === o.id);
      b.onclick = () => {
        cur.mine = o.id;
        state.practice += 1;
        save();
        renderProgress();
        this.render();
        $("p-reveal").scrollIntoView({ behavior: "smooth", block: "nearest" });
        // The chosen button is now disabled: carry keyboard focus to the explanations
        $("p-reveal-title").focus({ preventScroll: true });
      };
      box.append(b);
    }
  }

  // Wins more of its long (or short) games, by a margin worth mentioning
  timing(id, role) {
    const b = this.length(id, role);
    if (b.length < 3 || b[0].games < LENGTH_MIN_GAMES || b[2].games < LENGTH_MIN_GAMES) return null;
    const games = b.reduce((n, x) => n + x.games, 0);
    const base = b.reduce((n, x) => n + x.wins, 0) / games;
    const rate = (x) => (x.wins + LENGTH_PRIOR * base) / (x.games + LENGTH_PRIOR);
    const diff = rate(b[2]) - rate(b[0]);
    if (Math.abs(diff) < 0.06) return null;
    return { long: diff > 0, short: b[0], longGames: b[2] };
  }

  summary() {
    const { d, options } = this.current;
    const names = (list) => list.map((o) => this.name(o.id)).join(" and ");
    const kind = d.need === "magic" ? "magic" : "physical";
    const bring = options.filter((o) => this.brings(d, o.id));
    if (d.need && bring.length === 1) {
      return `The clearest thing in this draft: your team lacks ${kind} damage, and ${names(bring)} is the only option that brings it.`;
    }
    if (d.need && bring.length > 1) {
      return `Your team lacks ${kind} damage, and ${names(bring)} both bring it. Between those two, the lane and how each does this patch are what is left to compare.`;
    }
    return "This one is close: nothing in the draft separates these four clearly. When it is this close, the champion you know best tends to matter more than any of the differences below.";
  }

  renderReveal() {
    const cur = this.current;
    const { d, options, mine, pool } = cur;
    const notes = $("p-notes");
    notes.replaceChildren();
    const intro = el("li", "reveal-summary");
    intro.textContent = this.summary();
    notes.append(intro);
    const role = roleName[d.hidden_role].toLowerCase();
    const enemy = this.enemyLaner(d);
    for (const o of options) {
      const li = el("li");
      const head = el("div");
      head.append(this.champ(o.id));
      if (o.id === mine) head.append(el("span", "tag", "your pick"));
      if (o.id === pool) head.append(el("span", "tag", "you play this"));
      if (o.id === d.played) head.append(el("span", "tag muted-tag", "in the real game"));
      li.append(head);
      const line = (cls, ...parts) => {
        const why = el("div", `why ${cls}`);
        why.append(...parts);
        li.append(why);
      };
      if (o.magic !== null && o.magic !== undefined) {
        const type = o.magic >= 50 ? "magic" : "physical";
        const share = type === "magic" ? o.magic : 100 - o.magic;
        const parts = [`Deals mostly `, term(type, `${type} damage`), ` (${share}%)`];
        if (this.brings(d, o.id)) line("good", ...parts, `: adds the ${d.need} damage your team lacks.`);
        else if (this.lacks(d, o.id)) line("bad", ...parts, `: more of what your team already has.`);
        else line("", ...parts, ".");
      }
      if (o.games > 0) {
        const few = o.games < 100 ? " (few games so far)" : "";
        line("", `Wins ${pct(o.wins, o.games)}% of its ${o.games} ${role} games this patch${few}.`);
      }
      const t = this.timing(o.id, d.hidden_role);
      if (t) {
        const b = this.length(o.id, d.hidden_role);
        line("", `Does better in ${t.long ? "long" : "short"} games: ${pct(b[0].wins, b[0].games)}% under ${this.lengths[0]} minutes, ${pct(b[2].wins, b[2].games)}% from ${this.lengths[1]}.`);
      }
      for (const r of o.reasons) {
        if (r.kind === "base" || Math.abs(r.pp) < MIN_REASON_PP || r.games < MIN_REASON_GAMES) continue;
        const other = this.name(r.id);
        const text = r.kind === "enemy"
          ? r.pp > 0 ? `Tends to do well against ${other}` : `Tends to struggle against ${other}`
          : r.pp > 0 ? `Tends to win more with ${other}` : `Tends to win less with ${other}`;
        line(r.pp > 0 ? "good" : "bad", `${text} (${roleName[r.role].toLowerCase()}, ${r.games} games).`);
      }
      li.append(this.laneCurve(o, enemy));
      notes.append(li);
    }
    const real = d.won ? "won" : "lost";
    $("p-real").textContent =
      `In the real game this slot was ${this.name(d.played)}, and that team ${real} in ${d.minutes} minutes. One game says little; the reasons above come from all of this patch's games.`;
    const c3 = $("p-c3");
    c3.hidden = pool === null;
    if (pool !== null) {
      c3.textContent =
        `You play ${this.name(pool)}. Players who know their champion win about 7 points more often than players new to theirs, more than most counters are worth (see the Counters lesson).`;
    }
  }

  // Gold difference against the lane opponent by minute, as a small inline chart
  laneCurve(o, enemy) {
    const box = el("div", "why lane-mini");
    if (!o.lane) {
      box.textContent = `Lane against ${this.name(enemy)}: not enough games yet for a curve.`;
      return box;
    }
    const g = o.lane.gold;
    const w = 160;
    const h = 44;
    const max = Math.max(100, ...g.map(Math.abs));
    const x = (i) => (i / (g.length - 1)) * (w - 4) + 2;
    const y = (v) => h / 2 - (v / max) * (h / 2 - 3);
    const ns = "http://www.w3.org/2000/svg";
    const svg = document.createElementNS(ns, "svg");
    svg.setAttribute("viewBox", `0 0 ${w} ${h}`);
    svg.setAttribute("class", o.lane.games < THIN ? "spark thin" : "spark");
    svg.setAttribute("role", "img");
    const zero = document.createElementNS(ns, "line");
    zero.setAttribute("x1", 0);
    zero.setAttribute("x2", w);
    zero.setAttribute("y1", h / 2);
    zero.setAttribute("y2", h / 2);
    zero.setAttribute("class", "zero");
    const line = document.createElementNS(ns, "polyline");
    line.setAttribute("points", g.map((v, i) => `${x(i).toFixed(1)},${y(v).toFixed(1)}`).join(" "));
    line.setAttribute("class", "median");
    svg.append(zero, line);
    const at = Math.min(13, g.length - 1);
    const v = g[at];
    const lead = v === 0 ? "even" : `${Math.abs(v)} ${v > 0 ? "ahead" : "behind"}`;
    svg.setAttribute("aria-label", `Gold difference against ${this.name(enemy)} by minute`);
    const text = el("span");
    text.append(`Lane against ${this.name(enemy)}: typically ${lead} in `, term("gold", "gold"), ` at ${at + 1} minutes (${o.lane.games} games).`);
    box.append(svg, text);
    return box;
  }
}

async function start() {
  renderProgress();
  setupLessons();
  const status = $("p-status");
  try {
    const [meta, pack, facts] = await Promise.all([
      getJson("data/champions.json"),
      getJson("learn/practice.json"),
      getJson("learn/champs.json"),
    ]);
    champs = new Map(meta.champions.map((c) => [c.id, c]));
    ddragon = meta.ddragon;
    // Icons in the checks need the champion list
    for (const box of document.querySelectorAll(".check")) renderCheck(box);
    new Practice(pack, facts, meta).setup();
  } catch (e) {
    status.textContent = "Could not load practice drafts: " + e.message;
  }
}

start();
