// meiolol admin dashboard: the neural net programme's results (Models > Neural nets).
// Loaded before admin.js; uses its helpers (el, section, grid, table, chart, intervalChart,
// learnedList, getText, render, ui, MODELS, TRAIN, PALETTE, num, signed) only when called.
//
// One table per question from docs/nn-results/<question>.tsv (format in its README.md),
// sent by deploy/lab-push.sh as training/nn/ with training/nn.txt listing the files, so the
// numbers come from what the modellers record, not from model.md's prose. learned.md lines
// show when a row's `learned` cell names one (its date and first words)

const NN = { at: undefined, files: [], err: null };
const NN_ORDER = ["nets", "structured", "comp", "embx", "pretrain", "stack", "context", "player", "ldai", "gains", "scaling"];
const NN_VS = { ratings: "today's model", "win-comp": "win-comp", base: "champion win rates" };
const NN_BLOCK = {
  folds: "5 forward rounds", "dev-val": "newest dev games", test: "test look",
  random: "random split (LoLDraftAI-style)", projection: "projection",
};

async function loadNn() {
  const at = TRAIN ? TRAIN.pushed : null;
  if (NN.at === at) return;
  NN.at = at;
  try {
    const list = (await getText("training/nn.txt")).split("\n").filter(Boolean);
    NN.files = await Promise.all(list.map(async name => nnFile(name.replace(/\.tsv$/, ""), await getText("training/nn/" + encodeURIComponent(name)))));
    NN.err = null;
  } catch (e) { NN.files = []; NN.err = /^404/.test(e.message) ? null : e.message; }
  if (ui.tab === "models" && (ui.cat === "nn" || ui.cat === "all")) render(true);
}

function nnFile(key, text) {
  const lines = text.replace(/\r/g, "").split("\n");
  const title = (lines.find(l => /^#\s*title:/.test(l)) || "").replace(/^#\s*title:\s*/, "").trim();
  const rows = tsvRaw(lines.filter(l => !l.startsWith("#")).join("\n")).map(r => ({
    ...r, diff: nnNum(r.diff), ci: nnNum(r.ci), seeds: nnNum(r.seeds), seed_lo: nnNum(r.seed_lo), seed_hi: nnNum(r.seed_hi), games: nnNum(r.games),
  })).filter(r => r.model && r.diff != null);
  return { key, title: title || key, rows };
}
// Today's model's edge over a coin flip, log loss per game: the scale for a net's gain
const NN_EDGE = 0.0023;
const nnNum = v => v == null || v === "" || !isFinite(+v) ? null : +v;

// Better / tie / worse than the row's comparison model, from the 95% interval
function nnVerdict(r) {
  const who = NN_VS[r.vs] || r.vs;
  if (r.ci == null) return { text: "no interval", cls: "" };
  if (r.diff + r.ci < 0) return { text: `better than ${who}`, cls: "good" };
  if (r.diff - r.ci > 0) return { text: `worse than ${who}`, cls: "bad" };
  return { text: `tie with ${who} (not detected)`, cls: "" };
}
const nnDiff = r => signed(r.diff, 5) + (r.ci != null ? " ± " + r.ci.toFixed(5) : "");
// How big, for the All view's pill: a clear gain or loss against today's model, as a share
// of its edge
const nnSize = r => r.vs === "ratings" && r.ci != null && Math.abs(r.diff) > r.ci ? `${signed(r.diff, 4)} a game, ${Math.round(100 * Math.abs(r.diff) / NN_EDGE)}% of its edge over a coin flip` : null;
const nnBlock = r => NN_BLOCK[r.block] || r.block || "–";

// The row that best answers a question: a test look first, then the folds, then dev-val;
// among those, the comparison with today's model, first in the file (never the best
// diff: in a breakdown by subset that would pick the luckiest subset)
function nnHeadline(f) {
  const rank = { test: 0, folds: 1, "dev-val": 2, random: 3 };
  const rows = f.rows.filter(r => r.vs !== "-" && r.block in rank);
  rows.sort((a, b) => rank[a.block] - rank[b.block] || (a.vs === "ratings" ? 0 : 1) - (b.vs === "ratings" ? 0 : 1));
  return rows[0] || null;
}

function nnView(body) {
  loadNn();
  const intro = section(body, "Neural net programme",
    "Can a neural net call the winner from the draft better than today's model (ratings: each champion's strength in its role)? " +
    "Every number is the change in log loss per game against the model named, with its 95% range: below zero is better. " +
    `For scale, today's model beats a coin flip by about ${NN_EDGE} a game, so -${NN_EDGE} would double its edge. ` +
    "Dev results come from older games scored on newer ones; a test look is the one check on held-back games per model.");
  if (NN.err) intro.append(el("div", { class: "health bad" }, el("b", {}, "Could not load the results: "), NN.err));
  if (NN.at === undefined) { intro.append(el("p", { class: "muted" }, "Loading results…")); return; }
  const files = nnSorted();
  if (!files.length) { intro.append(el("p", { class: "muted" }, "No results yet (docs/nn-results/).")); return; }

  intro.append(nnHeadlines(files, true));

  const learnt = section(body, "What we learnt", "Final findings the results below link to (docs/learned.md).");
  const lines = [...new Set(files.flatMap(nnLearned))];
  if (!lines.length) learnt.append(el("p", { class: "muted" }, "None linked yet (the learned column in docs/nn-results)."));
  else {
    learnedList(learnt, lines, 0, true);
    const d = el("details", {}, el("summary", {}, "In full, with evidence"));
    learnedList(d, lines);
    learnt.append(d);
  }

  for (const f of files) (f.key === "scaling" ? nnScaling : nnQuestion)(body, f);
}
const nnRank = k => { const i = NN_ORDER.indexOf(k); return i < 0 ? NN_ORDER.length - 1 : i; };
const nnSorted = () => NN.files.slice().sort((a, b) => nnRank(a.key) - nnRank(b.key));

// One line per question: its headline row's verdict (full: with model, block and numbers)
function nnHeadlines(files, full) {
  const ul = el("ul", { class: "readings" });
  for (const f of files.filter(f => f.key !== "scaling")) {
    const h = nnHeadline(f);
    if (!h) continue;
    const v = nnVerdict(h);
    const look = h.block === "test" ? el("span", { class: "pill warn" }, "test look") : null;
    if (full) ul.append(el("li", {}, el("b", {}, f.title), " ", h.model, ": ", el("span", { class: "pill " + v.cls }, v.text), ` on ${nnBlock(h)}, ${nnDiff(h)}`, look));
    else ul.append(el("li", {}, f.title, " ", el("span", { class: "pill " + v.cls }, v.text), nnSize(h) ? el("span", { class: "sub" }, ` (${nnSize(h)})`) : null, look ? " " : null, look));
  }
  return ul;
}

// The All view's card
function nnCard(cards) {
  loadNn();
  const card = el("button", { type: "button", class: "card catcard", onclick: () => setCat("nn") }, el("h3", {}, "Neural nets"));
  if (NN.files.length) card.append(nnHeadlines(nnSorted(), false));
  else card.append(el("p", { class: "muted" }, NN.at === undefined ? "Loading results…" : "No results yet."));
  cards.append(card);
}

// learned.md lines (any heading, not struck) a question's rows name in their learned cell
function nnLearned(f) {
  const all = Object.values(MODELS.learned).flat().filter(t => !/^~~/.test(t));
  const keys = [...new Set(f.rows.map(r => (r.learned || "").trim()).filter(Boolean))];
  return keys.flatMap(k => all.filter(t => t.startsWith(k)));
}

function nnQuestion(body, f) {
  const sec = section(body, f.title, `docs/nn-results/${f.key}.tsv`);
  const rows = f.rows.map(r => ({ ...r, verdict: nnVerdict(r).text, against: NN_VS[r.vs] || r.vs }));
  table(sec, "nn-" + f.key, [
    { key: "model", label: "Model", fmt: (v, r) => el("span", {}, v, r.note ? el("span", { class: "sub" }, " " + r.note) : null) },
    { key: "against", label: "Against" },
    { key: "block", label: "Measured on", fmt: (v, r) => v === "test" ? el("span", { class: "pill warn" }, "test look") : nnBlock(r) },
    { key: "diff", label: "Change in log loss", num: true, fmt: (v, r) => nnDiff(r) },
    { key: "verdict", label: "Verdict", fmt: (v, r) => el("span", { class: "pill " + nnVerdict(r).cls }, v) },
    { key: "seeds", label: "Seeds", num: true, fmt: (v, r) => v == null ? "–" : v + (r.seed_lo != null ? ` (single ${signed(r.seed_lo, 5)} to ${signed(r.seed_hi, 5)})` : "") },
    { key: "games", label: "Games", num: true },
    { key: "source", label: "Source", fmt: v => v ? el("code", {}, v) : "–" },
  ], rows);
  const learnt = nnLearned(f);
  if (learnt.length) learnedList(sec, learnt, 0, true);
  const shown = f.rows.filter(r => r.vs !== "-" && r.block !== "projection");
  if (shown.length) {
    intervalChart(grid(sec), {
      title: f.title, left: "better", right: "worse", fmt: v => signed(v, 4),
      rows: shown.map(r => ({ label: `${r.model} vs ${NN_VS[r.vs] || r.vs}, ${r.block}`, value: r.diff, ci: r.ci || 0 })),
      caption: "Change in log loss per game, 95% intervals. Blue: clear of zero.",
    });
  }
}

// Absolute log loss against fit games (lines per model, projections apart) and each
// model's difference at each size
function nnScaling(body, f) {
  const sec = section(body, f.title, `docs/nn-results/${f.key}.tsv. Log loss as the models see more games; lower is better.`);
  const g = grid(sec);
  const abs = f.rows.filter(r => r.vs === "-");
  for (const share of [true, false]) {
    const pts = abs.filter(r => /%$/.test(r.fit_games || "") === share && isFinite(parseFloat(r.fit_games)));
    if (!pts.length) continue;
    const xs = [...new Set(pts.map(r => parseFloat(r.fit_games)))].sort((a, b) => a - b);
    const names = [...new Set(pts.map(r => r.model + (r.block === "projection" ? " (projected)" : "")))];
    chart(g, {
      id: "nn-scaling-" + share, title: share ? "Log loss by share of fit games" : "Log loss by fit games", type: "line", fit: true, x: xs,
      xFmt: v => share ? v + "%" : num(v) + " games", xTicks: numTicks(share ? v => v + "%" : num), fmt: v => v == null ? "–" : v.toFixed(5),
      series: names.map((n, i) => ({
        name: n, color: PALETTE[i % PALETTE.length],
        values: xs.map(x => (pts.find(r => r.model + (r.block === "projection" ? " (projected)" : "") === n && parseFloat(r.fit_games) === x) || {}).diff ?? null),
      })),
    });
  }
  const rel = f.rows.filter(r => r.vs !== "-");
  if (rel.length) {
    intervalChart(g, {
      title: "Against the comparison model at each size", left: "better", right: "worse", fmt: v => signed(v, 4),
      rows: rel.map(r => ({ label: `${r.model} vs ${NN_VS[r.vs] || r.vs}, ${r.fit_games || "?"}`, value: r.diff, ci: r.ci || 0 })),
      caption: "Change in log loss per game, 95% intervals. A gap that shrinks as games grow would mean more data helps the net more.",
    });
  }
}
