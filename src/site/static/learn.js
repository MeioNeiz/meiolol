// Learn: puzzles and lesson checks (embedded in learn.html) and practice drafts from
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
// Practice levels, by how clear the draft is (src/learn.zig Difficulty): one option
// brings the damage type the team lacks, then two, then a balanced team
const LEVELS = [
  ["easy", "Level 1", "Clear-cut"],
  ["medium", "Level 2", "Two fit"],
  ["hard", "Level 3", "Close call"],
];
const LEVEL_NEXT = {
  medium: "Two options now bring what your team lacks: the lane and the patch decide.",
  hard: "Balanced teams: nothing in the draft separates the options clearly.",
};
// Drills a level, then the next one is offered
const LEVEL_SIZE = 5;
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
// Reason lines per option in the reveal
const MAX_REASONS = 2;

const $ = (id) => document.getElementById(id);
const el = (tag, cls, text) => {
  const e = document.createElement(tag);
  if (cls) e.className = cls;
  if (text !== undefined) e.textContent = text;
  return e;
};
const pct = (part, whole) => Math.round((100 * part) / whole);
const button = (cls, text, onclick) => {
  const b = el("button", cls, text);
  b.type = "button";
  b.onclick = onclick;
  return b;
};

const fresh = () => ({
  lessons: {},
  practice: 0,
  role: "",
  level: "",
  pool: [],
  levels: {},
  view: "",
  lesson: "",
  // Puzzle id to the guess (a number) or the picked choice's index
  puzzles: {},
  puzzle: 0,
  puzzlesSeen: false,
});

function loadState() {
  try {
    const s = JSON.parse(localStorage.getItem(KEY));
    if (s && typeof s === "object" && !Array.isArray(s)) return { ...fresh(), ...s };
  } catch {
    // Unreadable: start afresh
  }
  return fresh();
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

const levelDone = (l) => (state.levels[l] || 0) >= LEVEL_SIZE;
const levelIndex = (l) => LEVELS.findIndex(([k]) => k === l);
// The chosen level, else the first not yet done
function currentLevel() {
  if (levelIndex(state.level) >= 0) return state.level;
  const open = LEVELS.find(([l]) => !levelDone(l));
  return (open || LEVELS[0])[0];
}

function renderTabs() {
  $("t-puzzles").textContent = `${puzzles.filter((p) => answer(p) !== undefined).length}/${puzzles.length}`;
  const done = lessonEls.filter((l) => lessonDone(l.dataset.lesson)).length;
  $("t-lessons").textContent = `${done}/${lessonEls.length}`;
  $("t-practice").textContent = LEVELS[levelIndex(currentLevel())][1];
}

function showView(view, focus = false) {
  state.view = view;
  save();
  for (const t of document.querySelectorAll(".learn-tabs button")) {
    t.setAttribute("aria-selected", t.dataset.view === view);
  }
  for (const s of document.querySelectorAll("section[data-view]")) s.hidden = s.dataset.view !== view;
  if (focus) document.querySelector(`.learn-tabs [data-view="${view}"]`).focus();
}

function setupTabs() {
  document.body.classList.add("learn-js");
  const tabs = document.querySelector(".learn-tabs");
  tabs.hidden = false;
  for (const t of tabs.querySelectorAll("button")) t.onclick = () => showView(t.dataset.view);
  const hash = location.hash.slice(1);
  // Puzzles are new: shown first once, even to readers who left on another tab
  const view = ["puzzles", "lessons", "practice"].includes(hash)
    ? hash
    : (state.puzzlesSeen && state.view) || "puzzles";
  state.puzzlesSeen = true;
  showView(view);
}

// ---- Puzzles: a committed guess, then the measured answer (src/site/puzzles.zig) ----

const puzzles = JSON.parse($("puzzle-data").textContent);
const num = (v) => v.toLocaleString("en-GB", { maximumFractionDigits: 1 });
const answer = (p) => state.puzzles[p.id];

// A guess within 4% of the slider's range is spot on, within 12% close
function verdict(p, g) {
  if (p.kind === "pick") return g === p.answer ? ["Right.", "good"] : ["Not this time.", "bad"];
  const off = Math.abs(g - p.answer);
  const range = p.max - p.min;
  if (off <= range * 0.04) return ["Spot on.", "good"];
  const by = `${num(Math.round(off * 10) / 10)}${p.unit === "%" ? " points" : p.unit}`;
  if (off <= range * 0.12) return [`Close: ${by} off.`, "good"];
  return [`${by} off.`, "bad"];
}

const gotIt = (p) => answer(p) !== undefined && verdict(p, answer(p))[1] === "good";

function pzBars(p) {
  const box = el("div", "pz-bars");
  const top = p.bar_unit === "%" ? 100 : Math.max(...p.bars.map((b) => b.v));
  for (const b of p.bars) {
    const row = el("div", b.hi ? "pz-bar hi" : "pz-bar");
    const track = el("span", "pz-track");
    const fill = el("i");
    fill.style.width = `${Math.max(1, (100 * b.v) / top)}%`;
    track.append(fill);
    const v = p.bar_unit === " points" ? `+${num(b.v)}` : num(b.v);
    const val = el("span", "pz-val", `${v}${p.bar_unit}`);
    val.append(el("small", "", ` ${num(b.n)} ${p.per}`));
    row.append(el("span", "pz-label", b.label), track, val);
    box.append(row);
  }
  return box;
}

function pzReveal(box, p, g) {
  const [say, cls] = verdict(p, g);
  const head = el("p", `pz-verdict ${cls}`, say);
  head.tabIndex = -1;
  box.append(head);
  if (p.kind === "guess") {
    const vs = el("p", "pz-vs");
    vs.append(
      el("span", "", "You "),
      el("b", "", `${num(g)}${p.unit}`),
      el("span", "", " Real "),
      el("b", "pz-real-n", `${num(p.answer)}${p.unit}`),
      el("span", "", p.real),
    );
    box.append(vs);
  } else {
    box.append(el("p", "pz-real", p.real));
  }
  if (p.bars.length) box.append(pzBars(p));
  box.append(el("p", "pz-why", p.why), el("p", "pz-tip", p.tip), el("p", "muted small", p.from));
  return head;
}

function pzChoice(b, c) {
  if (c.icon) {
    const img = document.createElement("img");
    img.src = c.icon;
    img.alt = "";
    img.width = img.height = 28;
    b.append(img);
  }
  b.append(c.t);
  return b;
}

function pzInput(box, p) {
  if (p.kind === "pick") {
    const row = el("div", "choices pz-choices");
    p.choices.forEach((c, j) => {
      row.append(pzChoice(button("", undefined, () => pzAnswer(p, j)), c));
    });
    box.append(row);
    return;
  }
  const start = Math.round((p.min + p.max) / 2 / p.step) * p.step;
  const wrap = el("div", "pz-guess");
  const out = el("output", "pz-out", `${num(start)}${p.unit}`);
  const range = document.createElement("input");
  range.type = "range";
  range.min = p.min;
  range.max = p.max;
  range.step = p.step;
  range.value = start;
  range.setAttribute("aria-label", "Your guess");
  range.oninput = () => (out.textContent = `${num(Number(range.value))}${p.unit}`);
  const ends = el("div", "pz-ends muted small");
  ends.append(el("span", "", `${num(p.min)}${p.unit}`), el("span", "", `${num(p.max)}${p.unit}`));
  wrap.append(out, range, ends, button("primary", "Lock in", () => pzAnswer(p, Number(range.value))));
  box.append(wrap);
}

function pzAnswer(p, g) {
  state.puzzles[p.id] = g;
  save();
  renderPuzzle("reveal");
}

// `focus`: "q" (a new puzzle) or "reveal" (an answer just given)
function renderPuzzle(focus = null) {
  const box = $("pz");
  box.hidden = false;
  box.replaceChildren();
  const at = Math.min(state.puzzle, puzzles.length);
  stepBar($("pz-bar"), puzzles.length, puzzles.filter((p) => answer(p) !== undefined).length, at);
  renderTabs();
  if (at === puzzles.length) return pzEnd(box, focus);
  const p = puzzles[at];
  box.append(el("p", "pz-topic muted small", `${at + 1} of ${puzzles.length}: ${p.topic}`));
  const q = el("h2", "pz-q", p.q);
  q.tabIndex = -1;
  box.append(q);
  const g = answer(p);
  let target = focus === "q" ? q : null;
  if (g === undefined) {
    pzInput(box, p);
  } else {
    if (p.kind === "pick") {
      const row = el("div", "choices pz-choices");
      p.choices.forEach((c, j) => {
        const b = pzChoice(button(j === g ? "chosen" : ""), c);
        b.disabled = true;
        if (j === p.answer) b.classList.add("played");
        const tag = [j === g && "your pick", j === p.answer && "answer"].filter(Boolean).join(", ");
        if (tag) b.append(el("span", "pick", tag));
        row.append(b);
      });
      box.append(row);
    }
    const head = pzReveal(box, p, g);
    if (focus === "reveal") target = head;
    const nav = el("div", "lesson-nav");
    nav.append(button("primary", at + 1 < puzzles.length ? "Next puzzle" : "See your score", () => pzGo(at + 1)));
    if (at > 0) nav.append(button("link", "Back", () => pzGo(at - 1)));
    box.append(nav);
  }
  if (target) target.focus();
}

function pzGo(i) {
  state.puzzle = i;
  save();
  renderPuzzle("q");
}

function pzEnd(box, focus) {
  const got = puzzles.filter(gotIt).length;
  const head = el("h2", "pz-q", `${got} of ${puzzles.length} right or close`);
  head.tabIndex = -1;
  box.append(head, el("p", "", "Every takeaway, for your next game:"));
  const tips = el("ul", "pz-tips");
  for (const p of puzzles) tips.append(el("li", "", p.tip));
  box.append(tips);
  const nav = el("div", "lesson-nav");
  nav.append(
    button("primary", "Basics for new players", () => showView("lessons", true)),
    button("link", "Puzzles again", () => {
      state.puzzles = {};
      pzGo(0);
    }),
  );
  box.append(nav);
  if (focus) head.focus();
}

function setupPuzzles() {
  // Resume at the first one not answered
  const open = puzzles.findIndex((p) => answer(p) === undefined);
  if (open >= 0 && open < state.puzzle) state.puzzle = open;
  renderPuzzle();
}

// ---- Lessons: one at a time, its short text above one question at a time ----

const checks = JSON.parse($("checks").textContent);
const lessonEls = [...document.querySelectorAll(".lesson")];

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

// Question shown in the current lesson, from 1; 0 when the lesson has none
let step = 1;

function currentLessonEl() {
  return (
    lessonEls.find((l) => l.dataset.lesson === state.lesson) ||
    lessonEls.find((l) => !lessonDone(l.dataset.lesson)) ||
    lessonEls[0]
  );
}

function lessonMine(key) {
  const mine = state.lessons[key] || { seen: true, answers: [] };
  mine.answers ||= [];
  return mine;
}

// The first question not yet answered, else the last
function resumeStep(key) {
  const qs = checks[key] || [];
  const mine = lessonMine(key);
  const first = qs.findIndex((_, i) => mine.answers[i] === undefined);
  return first < 0 ? qs.length : first + 1;
}

function openLesson(key, focus = false) {
  state.lesson = key;
  state.lessons[key] = lessonMine(key);
  save();
  step = resumeStep(key);
  renderLesson(focus ? "head" : null);
}

function renderDots() {
  const dots = $("lesson-dots");
  dots.hidden = false;
  dots.replaceChildren();
  const cur = currentLessonEl();
  lessonEls.forEach((l, i) => {
    const key = l.dataset.lesson;
    const li = el("li");
    const title = l.querySelector(".lesson-head > span:nth-child(2)").firstChild.textContent.trim();
    const b = button(lessonDone(key) ? "done" : "", `${i + 1}`, () => openLesson(key, true));
    b.title = title;
    b.setAttribute("aria-label", `Lesson ${i + 1}: ${title}${lessonDone(key) ? ", done" : ""}`);
    if (l === cur) b.setAttribute("aria-current", "step");
    li.append(b, el("span", "dot-label", title));
    dots.append(li);
  });
}

function stepBar(box, total, filled, at) {
  box.replaceChildren();
  for (let i = 0; i < total; i++) {
    const seg = el("i");
    if (i < filled) seg.className = "on";
    if (i === at) seg.classList.add("here");
    box.append(seg);
  }
}

// `focus`: "head" (a new lesson), "why" (an answer just given) or "first" (a question)
function renderLesson(focus = null) {
  const art = currentLessonEl();
  const key = art.dataset.lesson;
  const qs = checks[key] || [];
  const mine = lessonMine(key);
  for (const l of lessonEls) l.hidden = l !== art;
  step = Math.max(Math.min(step, qs.length), qs.length ? 1 : 0);
  let bar = art.querySelector(".stepbar");
  if (!bar) {
    bar = el("div", "stepbar");
    bar.setAttribute("aria-hidden", "true");
    art.querySelector(".lesson-head").after(bar);
  }
  const answered = qs.filter((_, i) => mine.answers[i] !== undefined).length;
  stepBar(bar, qs.length, answered, step - 1);
  const box = art.querySelector(".check");
  box.replaceChildren();
  let focusAfter = focus === "head" ? art.querySelector(".lesson-head") : null;
  if (step > 0) {
    const i = step - 1;
    const q = qs[i];
    const wrap = el("div", "q");
    wrap.append(el("p", "q-n muted small", `Question ${step} of ${qs.length}`));
    wrap.append(el("p", "q-text", q.q));
    const row = el("div", "choices");
    const done = mine.answers[i] !== undefined;
    q.choices.forEach((c, j) => {
      const b = button("", undefined, () => {
        mine.answers[i] = j;
        state.lessons[key] = mine;
        save();
        renderLesson("why");
      });
      const img = c.id !== undefined && c.id !== null ? icon(c.id, 28) : null;
      if (img) b.append(img);
      b.append(c.t);
      b.disabled = done;
      if (done) {
        b.classList.toggle("chosen", mine.answers[i] === j);
        b.classList.toggle("played", j === q.answer);
      }
      row.append(b);
    });
    wrap.append(row);
    if (done) {
      const right = mine.answers[i] === q.answer;
      const why = el("p", `why ${right ? "good" : "bad"}`);
      why.tabIndex = -1;
      why.append(el("b", "", right ? "Right. " : "Not quite. "), q.why);
      wrap.append(why);
      if (focus === "why") focusAfter = why;
    }
    box.append(wrap);
    if (focus === "first") focusAfter = row.querySelector("button");
  }
  renderLessonNav(art, qs, mine);
  if (!focusAfter && focus === "why") focusAfter = art.querySelector(".lesson-nav button");
  renderDots();
  renderTabs();
  if (focusAfter) focusAfter.focus();
}

function renderLessonNav(art, qs, mine) {
  const nav = art.querySelector(".lesson-nav");
  nav.replaceChildren();
  const idx = lessonEls.indexOf(art);
  const nextLesson = lessonEls[idx + 1];
  const onward = () =>
    nextLesson
      ? button("primary", "Next lesson", () => openLesson(nextLesson.dataset.lesson, true))
      : button("primary", "Practice drafts", () => showView("practice", true));
  const go = (at) => {
    step = at;
    renderLesson("first");
  };
  if (qs.length === 0) {
    nav.append(el("span", "muted small", "Not enough games yet for questions."), onward());
    return;
  }
  const i = step - 1;
  // Unanswered: the choices are the only buttons, so a tap there is the answer
  if (mine.answers[i] === undefined) return;
  if (step < qs.length) {
    nav.append(button("primary", "Next question", () => go(step + 1)));
    return;
  }
  const right = qs.filter((q, j) => mine.answers[j] === q.answer).length;
  nav.append(
    el("span", "score", `${right} of ${qs.length} right`),
    onward(),
    button("link", "Questions again", () => {
      mine.answers = [];
      save();
      go(1);
    }),
  );
}

function setupLessons() {
  const cur = currentLessonEl();
  // Pinned, so finishing it does not jump to the next one before the reader asks
  state.lesson = cur.dataset.lesson;
  step = resumeStep(cur.dataset.lesson);
  renderLesson();
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
    for (const [l, label, what] of LEVELS) {
      const b = button("level", undefined, () => this.goLevel(l));
      b.dataset.level = l;
      b.append(el("b", "", label), el("span", "", what), el("span", "level-n"));
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
      const after = LEVELS[levelIndex(this.current.d.difficulty) + 1];
      // A level just finished: on to the next one
      if (this.finished && after) {
        state.level = after[0];
        save();
        this.queue = [];
        this.renderSetup();
      }
      // May wait for the recommender to load; focus the question once it is drawn
      await this.next();
      $("p-levels").scrollIntoView({ behavior: "smooth", block: "start" });
      $("p-question").focus({ preventScroll: true });
    };
    this.renderSetup();
    this.next();
  }

  goLevel(l) {
    state.level = l;
    save();
    this.queue = [];
    this.renderSetup();
    this.next();
  }

  renderSetup() {
    for (const b of $("p-roles").children) b.setAttribute("aria-pressed", b.dataset.role === state.role);
    const lvl = currentLevel();
    for (const b of $("p-levels").children) {
      const l = b.dataset.level;
      const n = Math.min(state.levels[l] || 0, LEVEL_SIZE);
      b.setAttribute("aria-pressed", l === lvl);
      b.classList.toggle("done", levelDone(l));
      b.querySelector(".level-n").textContent = levelDone(l) ? "✓" : `${n}/${LEVEL_SIZE}`;
    }
    stepBar($("p-bar"), LEVEL_SIZE, Math.min(state.levels[lvl] || 0, LEVEL_SIZE), -1);
    renderTabs();
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
        (d) => (!state.role || d.hidden_role === state.role) && d.difficulty === currentLevel(),
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
    this.finished = false;
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
    const [, level, what] = LEVELS[levelIndex(d.difficulty)];
    const n = (state.levels[d.difficulty] || 0) + (mine === null ? 1 : 0);
    const drill = n <= LEVEL_SIZE ? `: drill ${n} of ${LEVEL_SIZE}` : "";
    $("p-about").textContent = `${level}, ${what.toLowerCase()}${drill} · patch ${d.patch}${tier}`;
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
            you.append(this.champ(mine, 32, false), el("span", "tag", "you"));
            li.append(you);
          }
        } else li.append(this.champ(d.teams[t][r], 32, false));
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
      `You are ${roleName[d.hidden_role].toLowerCase()}. Which would you pick?`;
    $("p-hints").hidden = mine !== null;
    if (mine === null) this.renderHints();
    this.renderOptions();
    $("p-reveal").hidden = mine === null;
    if (mine !== null) this.renderReveal();
  }

  hints() {
    const { d, pool } = this.current;
    const out = [];
    const ally = (r) => d.teams[d.hidden_team][roleIndex[r]];
    if (d.need === "magic") {
      out.push(["Your team is mostly ", term("physical", "physical damage"), "."]);
    } else if (d.need === "physical") {
      out.push(["Your team is mostly ", term("magic", "magic damage"), "."]);
    } else {
      out.push(["Your team's damage is already mixed."]);
    }
    const enemy = this.enemyLaner(d);
    const lane = [`You face ${this.name(enemy)} in `, term("lane", "lane"), "."];
    const t = this.timing(enemy, d.hidden_role);
    if (t) lane.push(` It does better in ${t.long ? "long" : "short"} games.`);
    out.push(lane);
    if (d.hidden_role === "bottom") out.push([`Your support: ${this.name(ally("utility"))}.`]);
    if (d.hidden_role === "utility") out.push([`Your bot laner: ${this.name(ally("bottom"))}.`]);
    if (pool !== null) out.push([`You play ${this.name(pool)}: it is an option.`]);
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
      if (cur.mine === o.id) b.append(el("span", "pick", "your pick"));
      if (cur.mine !== null) {
        const fit = this.brings(cur.d, o.id) ? "good" : this.lacks(cur.d, o.id) ? "bad" : "";
        if (fit) b.classList.add(fit);
        if (fit) b.append(el("span", `fit ${fit}`, fit === "good" ? `adds ${cur.d.need}` : "more of the same"));
      }
      b.onclick = () => {
        cur.mine = o.id;
        state.practice += 1;
        const l = cur.d.difficulty;
        // Stays on this level until the reader moves on, even once it is done
        state.level = l;
        const was = state.levels[l] || 0;
        state.levels[l] = was + 1;
        this.finished = was + 1 === LEVEL_SIZE;
        save();
        this.renderSetup();
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
    if (d.need && bring.length === 1) return `Only ${names(bring)} adds the ${kind} damage your team lacks.`;
    if (d.need && bring.length > 1) {
      return `${names(bring)} both add the ${kind} damage your team lacks: the lane and the patch decide between them.`;
    }
    return "Close: nothing here separates the four. The champion you know best matters more.";
  }

  renderReveal() {
    const cur = this.current;
    const { d, options, mine, pool } = cur;
    const notes = $("p-notes");
    notes.replaceChildren();
    $("p-reveal-title").textContent = this.summary();
    const role = roleName[d.hidden_role].toLowerCase();
    const enemy = this.enemyLaner(d);
    for (const o of options) {
      const li = el("li");
      const head = el("div");
      head.append(this.champ(o.id));
      if (o.id === mine) head.append(el("span", "tag", "your pick"));
      if (o.id === pool) head.append(el("span", "tag", "you play it"));
      if (o.id === d.played) head.append(el("span", "tag muted-tag", "real game"));
      li.append(head);
      const line = (cls, ...parts) => {
        const why = el("div", `why ${cls}`);
        why.append(...parts);
        li.append(why);
      };
      if (o.magic !== null && o.magic !== undefined) {
        const type = o.magic >= 50 ? "magic" : "physical";
        const share = type === "magic" ? o.magic : 100 - o.magic;
        const parts = [`${share}% `, term(type, type)];
        if (this.brings(d, o.id)) line("good", ...parts, ": adds what your team lacks");
        else if (this.lacks(d, o.id)) line("bad", ...parts, ": more of the same");
        else line("", ...parts);
      }
      if (o.games > 0) {
        const few = o.games < 100 ? ", few so far" : "";
        line("", `Wins ${pct(o.wins, o.games)}% of ${o.games} ${role} games${few}`);
      }
      const t = this.timing(o.id, d.hidden_role);
      if (t) {
        const b = this.length(o.id, d.hidden_role);
        line("", `Better in ${t.long ? "long" : "short"} games: ${pct(b[0].wins, b[0].games)}% under ${this.lengths[0]} min, ${pct(b[2].wins, b[2].games)}% from ${this.lengths[1]}`);
      }
      let shown = 0;
      for (const r of o.reasons) {
        if (r.kind === "base" || Math.abs(r.pp) < MIN_REASON_PP || r.games < MIN_REASON_GAMES) continue;
        if (!detectedReason(d.hidden_role, r) || shown++ >= MAX_REASONS) continue;
        const text = reasonWords(r, this.name(r.id));
        line(r.pp > 0 ? "good" : "bad", `${text} (${r.games} games)`);
      }
      li.append(this.laneCurve(o, enemy));
      notes.append(li);
    }
    $("p-real").textContent =
      `Real game: ${this.name(d.played)}, ${d.won ? "won" : "lost"} in ${d.minutes} min. One game says little.`;
    const done = $("p-done");
    const after = LEVELS[levelIndex(d.difficulty) + 1];
    done.hidden = !this.finished;
    if (this.finished) {
      const [, level] = LEVELS[levelIndex(d.difficulty)];
      done.textContent = after
        ? `${level} done. ${after[1]}: ${LEVEL_NEXT[after[0]]}`
        : `${level} done: all three levels. Drafts change every day.`;
    }
    $("p-next").textContent = this.finished && after ? `Start ${after[1].toLowerCase()}` : "Next draft";
  }

  // Gold difference against the lane opponent by minute, as a small inline chart
  laneCurve(o, enemy) {
    const box = el("div", "why lane-mini");
    if (!o.lane) {
      box.textContent = `vs ${this.name(enemy)}: too few games for a lane curve`;
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
    text.append(`vs ${this.name(enemy)}: typically ${lead} in `, term("gold", "gold"), ` at ${at + 1} min (${o.lane.games} games)`);
    box.append(svg, text);
    return box;
  }
}

async function start() {
  setupTabs();
  setupPuzzles();
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
    renderLesson();
    new Practice(pack, facts, meta).setup();
  } catch (e) {
    status.textContent = "Could not load practice drafts: " + e.message;
  }
}

start();
