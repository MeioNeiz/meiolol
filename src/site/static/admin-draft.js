// meiolol admin dashboard: the Draft tester (Models > Draft, admin.js draws the rest).
// Loaded before admin.js, whose first render calls draftView; uses its helpers (el,
// section, table, stored, store, getJson, render, ui, num, pct, sumR) only when called.
//
// Admin only: a draft board of two teams, the model's win chance for the whole draft, and
// a picker per slot showing what each champion would change. The model comes from
// meiolol-lab's `draft --export` (meiolol-88), sent by deploy/lab-push.sh as
// training/draft-model.json with reference pairs in draft-ref.json, checked at load. Nothing
// here reaches the public site, which must not claim "this draft wins X%"

const DRAFT_ROLES = [["top", "Top"], ["jungle", "Jungle"], ["mid", "Mid"], ["bot", "Bot"], ["support", "Support"]];
const SIDES = [["blue", "Blue"], ["red", "Red"]];
const DRAFT = { model: undefined, ref: null, err: null, check: null, m: null };

function draftState() {
  const d = stored("draft2", null) || {};
  return { blue: d.blue || {}, red: d.red || {}, locks: d.locks || {}, fb: d.fb || {}, bans: d.bans || [], open: d.open || null, sort: d.sort || "played", rank: d.rank || "low" };
}
function saveDraft(d) { store("draft2", d); render(true); }

async function loadDraftModel() {
  try {
    DRAFT.model = await getJson("training/draft-model.json");
    DRAFT.m = draftModel(DRAFT.model);
    if (!DRAFT.m) throw new Error(`draft-model.json is format "${DRAFT.model.format}" version ${DRAFT.model.version}; this page reads meiolol-draft-model versions 1 and 2`);
    DRAFT.ref = await getJson("training/draft-ref.json").catch(() => null);
    DRAFT.err = null;
    DRAFT.check = DRAFT.m && DRAFT.ref ? draftCheck(DRAFT.m, DRAFT.ref) : null;
  } catch (e) { DRAFT.model = null; DRAFT.m = null; DRAFT.err = e.message; }
  // The lane model is optional: without it the suggester shows only "Best for this draft"
  DRAFT.lane = null; DRAFT.laneErr = null; DRAFT.laneCheck = null;
  try {
    const L = await getJson("training/lane-model.json");
    DRAFT.lane = laneModel(L);
    if (!DRAFT.lane) throw new Error(`lane-model.json is format "${L.format}" version ${L.version}; this page reads meiolol-lane-model version 1`);
    const ref = await getJson("training/lane-ref.json").catch(() => null);
    DRAFT.laneCheck = ref ? laneCheck(DRAFT.lane, ref) : null;
  } catch (e) { if (!/^404/.test(e.message)) DRAFT.laneErr = e.message; }
  if (ui.tab === "models" && ui.cat === "draft") render(true);
}

// The exported model (docs/model.md "Draft model file"; Scorer in src/lab/draft.zig is the
// reference): champions, play share per role on the newest patch, blue's win chance with a
// 95% interval for a draft, and the candidates for a slot. A draft here is
// {blue: {role: id}, red: {role: id}}; an empty slot, or a champion with no term in the
// role, is average[role] with sd 0. Version 2 adds comp terms (model.comp, null without):
// each slot's profile p summed per team, P_b'S P_b - P_r'S P_r + P_b'A P_r
function draftModel(M) {
  if (!M || M.format !== "meiolol-draft-model" || (M.version !== 1 && M.version !== 2)) return null;
  const terms = new Map(M.model.terms.map(t => [t.champion + ":" + t.role, t]));
  const cells = new Map(M.cells.map(c => [c.champion + ":" + c.role, c]));
  const avg = M.average.map(a => ({ p: [], ...a, sd: 0 }));
  const { intercept, w, z } = M.model;
  const comp = M.model.comp || null;
  if (comp && (comp.team || []).length) throw new Error(`draft-model.json has team terms (${comp.team.map(t => t.kind).join(", ")}) this page can't score yet`);
  const k = comp ? comp.stats.length : 0;
  const dot = (a, b) => { let x = 0; for (let i = 0; i < a.length; i++) x += a[i] * b[i]; return x; };
  const sig = x => 1 / (1 + Math.exp(-x));
  const slots = teams => teams.map(t => t.map((id, r) => (id && terms.get(id + ":" + r)) || avg[r]));
  // A team's summed profile
  const prof = T => { const P = new Array(k).fill(0); for (const x of T) for (let i = 0; i < k; i++) P[i] += x.p[i]; return P; };
  const compPart = ([B, R]) => {
    if (!comp) return 0;
    const Pb = prof(B), Pr = prof(R);
    let x = 0;
    for (let i = 0; i < k; i++) for (let j = 0; j < k; j++) {
      x += comp.S[i * k + j] * (Pb[i] * Pb[j] - Pr[i] * Pr[j]);
      x += comp.A[i * k + j] * Pb[i] * Pr[j];
    }
    return x;
  };
  // teams[side][role]: champion id, 0 empty
  const score = teams => {
    const sl = slots(teams), [B, R] = sl;
    let logit = intercept + compPart(sl), v = 0;
    for (let r = 0; r < 5; r++) {
      logit += B[r].b - R[r].b;
      v += B[r].sd ** 2 + R[r].sd ** 2;
    }
    if (M.has_pairs) {
      for (let i = 0; i < 5; i++) for (let j = 0; j < 5; j++) logit += w[i * 5 + j] * (dot(B[i].u, R[j].v) - dot(R[i].u, B[j].v));
      for (let a = 0; a < 5; a++) for (let b = a + 1; b < 5; b++) logit += z[a * 5 + b] * (dot(B[a].s, B[b].s) - dot(R[a].s, R[b].s));
    }
    const h = 1.96 * Math.sqrt(v);
    return { p: sig(logit), lo: sig(logit - h), hi: sig(logit + h) };
  };
  const teamsOf = d => SIDES.map(([side]) => DRAFT_ROLES.map(([role]) => +d[side][role] || 0));
  const roleIdx = Object.fromEntries(DRAFT_ROLES.map(([r], i) => [r, i]));
  // Why the comp terms move a pick: each S and A entry's part of the change in the picking
  // side's logit when champion `id` fills its empty slot, in pp of that side's win (the
  // sigmoid's secant over the whole change, so the parts and the ratings add up to the
  // change), with a 95% half-width from the entry's sd; largest first
  const compReasons = (teams, side, r, id) => {
    if (!comp) return [];
    const t = teams.map(x => x.slice());
    const at = c => {
      t[side][r] = c;
      const sl = slots(t), p = score(t).p, q = side ? 1 - p : p;
      return { M: prof(sl[side]), T: prof(sl[1 - side]), logit: Math.log(q / (1 - q)) };
    };
    const x0 = at(0), x1 = at(id), l0 = x0.logit, l1 = x1.logit;
    const slope = Math.abs(l1 - l0) > 1e-9 ? (sig(l1) - sig(l0)) / (l1 - l0) : sig(l1) * (1 - sig(l1));
    const out = [];
    const add = (logit, sd, what) => out.push({ pp: 100 * slope * logit, half: 100 * slope * 1.96 * sd, what });
    const st = comp.stats, lean = x => x >= 0 ? "high" : "low";
    for (let i = 0; i < k; i++) for (let j = i; j < k; j++) {
      // S symmetric: an off-diagonal pair counts both halves
      const n = i === j ? 1 : 2, d = n * (x1.M[i] * x1.M[j] - x0.M[i] * x0.M[j]);
      add(comp.S[i * k + j] * d, comp.S_sd[i * k + j] * Math.abs(d),
        i === j ? `your ${st[i].label} ${lean(x1.M[i])}` : `your ${st[i].label} ${lean(x1.M[i])} with your ${st[j].label} ${lean(x1.M[j])}`);
    }
    // A from the picking side: mine'A theirs for blue, and for red too (A antisymmetric)
    for (let i = 0; i < k; i++) for (let j = 0; j < k; j++) {
      if (!comp.A[i * k + j]) continue;
      const d = x1.M[i] * x1.T[j] - x0.M[i] * x0.T[j];
      add(comp.A[i * k + j] * d, comp.A_sd[i * k + j] * Math.abs(d), `enemy ${st[j].label} ${lean(x1.T[j])} × your ${st[i].label} ${lean(x1.M[i])}`);
    }
    return out.sort((a, b) => Math.abs(b.pp) - Math.abs(a.pp));
  };
  const m = {
    M, score, teamsOf, comp, compReasons,
    compPart: teams => compPart(slots(teams)),
    champs: M.champions.slice().sort((a, b) => a.name.localeCompare(b.name)),
    rate: (id, role) => (cells.get(id + ":" + roleIdx[role]) || {}).patch_share || 0,
    games: (id, role) => (cells.get(id + ":" + roleIdx[role]) || {}).games || 0,
    win: d => score(teamsOf(d)),
    // Each slot's part of blue's logit, for tracing a number
    explain(teams) {
      const rows = [];
      teams.forEach((t, side) => t.forEach((id, r) => {
        const term = id && terms.get(id + ":" + r);
        const x = term || avg[r];
        rows.push({ side, role: r, champion: id || 0, average: !term, b: x.b, sd: x.sd, part: side === 0 ? x.b : -x.b });
      }));
      const c = compPart(slots(teams));
      const lin = intercept + c + sumR(rows.map(x => x.part));
      const p = score(teams);
      return { intercept, rows, comp: c, pairs: Math.log(p.p / (1 - p.p)) - lin, logit: Math.log(p.p / (1 - p.p)), p };
    },
    // A slot's candidates: games in the role >= min_games, not picked, not banned; win and
    // change for the side filling it, sorted by win then champion id (as draft-ref.json)
    slot(teams, bans, side, r, min = M.min_games) {
      const mine = x => side === 0 ? x : { p: 1 - x.p, lo: 1 - x.hi, hi: 1 - x.lo };
      const t = teams.map(x => x.slice());
      t[side][r] = 0;
      const empty = mine(score(t)).p;
      const out = new Set([...t.flat(), ...bans].filter(Boolean));
      const options = [];
      for (const c of M.cells) {
        if (c.role !== r || c.games < min || out.has(c.champion)) continue;
        t[side][r] = c.champion;
        const x = mine(score(t));
        options.push({ champion: c.champion, games: c.games, share: c.patch_share, win: x.p, lo: x.lo, hi: x.hi, change: x.p - empty });
      }
      options.sort((a, b) => b.win - a.win || a.champion - b.champion);
      const g = sumR(options.map(o => o.games));
      return { empty, average: g ? sumR(options.map(o => o.win * o.games)) / g : null, options };
    },
  };
  return m;
}

// The page's numbers against meiolol-lab's reference (draft-ref.json): whole drafts, and
// slot queries with their candidate lists
function draftCheck(m, ref) {
  const tol = ref.tolerance || 1e-9;
  let worst = 0, n = 0, bad = null;
  const cmp = (a, b, what) => { n++; const e = Math.abs(a - b); if (e > worst) { worst = e; if (e > tol) bad = what; } };
  for (const x of ref.drafts || []) {
    const s = m.score(x.teams);
    for (const k of ["p", "lo", "hi"]) cmp(s[k], x.blue[k], `${x.label}: ${k}`);
    if (x.comp != null) cmp(m.compPart(x.teams), x.comp, `${x.label}: comp part`);
  }
  for (const q of ref.slots || []) {
    const s = m.slot(q.teams, q.bans || [], q.side, q.role, q.min_games);
    cmp(s.empty, q.empty, `${q.label}: empty`);
    cmp(s.average, q.average, `${q.label}: average`);
    if (s.options.length !== q.options.length) { bad = `${q.label}: ${s.options.length} candidates, meiolol-lab has ${q.options.length}`; worst = Infinity; continue; }
    q.options.forEach((o, i) => {
      const mine = s.options[i];
      if (mine.champion !== o.champion) { bad = `${q.label}: order differs at ${i + 1}`; worst = Infinity; return; }
      for (const k of ["win", "lo", "hi", "change"]) cmp(mine[k], o[k], `${q.label}: ${k}`);
    });
  }
  if (!n) return null;
  return bad ? { ok: false, text: `Differs from meiolol-lab's reference (${bad}; largest gap ${isFinite(worst) ? worst.toExponential(1) : "order"}): don't trust these numbers.` }
    : { ok: true, text: `Matches meiolol-lab on ${(ref.drafts || []).length} reference drafts and ${(ref.slots || []).length} slot lists (largest gap ${worst.toExponential(1)}).` };
}

// The early-game lane model (docs/model.md "Lane model file"; Scorer in src/lab/lane.zig is
// the reference): expected gold14, lanediff14, cs10 and deaths15 for champion x in role r
// into lane opponent y, each with a 95% range for the average, and the champion's and the
// matchup's games. Every outcome array follows L.outcomes
function laneModel(L) {
  if (!L || L.format !== "meiolol-lane-model" || L.version !== 1) return null;
  const champ = new Map(L.champ.map(t => [t.champion + ":" + t.role, t]));
  const enemy = new Map(L.enemy.map(t => [t.champion + ":" + t.role, t]));
  const col = Object.fromEntries(L.pair_columns.map((c, i) => [c, i]));
  const pairs = new Map(L.pairs.map(p => [p[0] + ":" + p[1] + ":" + p[2], p]));
  const outs = L.outcomes.map((o, i) => i);
  // vc: the champion term's variance, shared by all its matchups; vr: the rest's
  const value = (x, y, r) => {
    const c = champ.get(x + ":" + r), e = enemy.get(y + ":" + r), p = pairs.get(x + ":" + y + ":" + r);
    const pt = p && { b: L.outcomes.map(o => p[col["b_" + o]]), sd: L.outcomes.map(o => p[col["sd_" + o]]) };
    const v = outs.map(o => L.intercept[o][r] + L.others[o][r] + (c ? c.b[o] : 0) + (e ? e.b[o] : 0) + (pt ? pt.b[o] : 0));
    const vc = outs.map(o => c ? c.sd[o] ** 2 : 0);
    const vr = outs.map(o => (e ? e.sd[o] ** 2 : 0) + (pt ? pt.sd[o] ** 2 : 0));
    const h = outs.map(o => 1.96 * Math.sqrt(vc[o] + vr[o]));
    return { value: v, lo: v.map((x, o) => x - h[o]), hi: v.map((x, o) => x + h[o]), vc, vr, champ_games: c ? c.n : 0, pair_games: p ? p[col.n] : 0 };
  };
  // Into a field of opponents [{id, w}] (w summing to 1): the weighted average, its range
  // (opponent and pair terms average down, the champion's own term doesn't) and each matchup
  const blind = (x, r, field) => {
    const each = field.map(f => ({ ...f, ...value(x, f.id, r) }));
    const v = outs.map(o => sumR(each.map(f => f.w * f.value[o])));
    const h = outs.map(o => 1.96 * Math.sqrt((each[0] ? each[0].vc[o] : 0) + sumR(each.map(f => f.w * f.w * f.vr[o]))));
    return { value: v, lo: v.map((x, o) => x - h[o]), hi: v.map((x, o) => x + h[o]), each, champ_games: (champ.get(x + ":" + r) || {}).n || 0 };
  };
  return { L, value, blind, at: Object.fromEntries(L.outcomes.map((o, i) => [o, i])) };
}

function laneCheck(lm, ref) {
  let worst = 0, n = 0, bad = null;
  for (const x of ref.refs || []) {
    const s = lm.value(x.champion, x.enemy, x.role);
    for (const k of ["value", "lo", "hi"]) x[k].forEach((v, o) => { n++; const e = Math.abs(s[k][o] - v); if (e > worst) worst = e; if (e > 0.01) bad = `${x.label}, role ${x.role}: ${k} ${lm.L.outcomes[o]}`; });
    if (s.champ_games !== x.champ_games || s.pair_games !== x.pair_games) bad = `${x.label}, role ${x.role}: games`;
  }
  if (!n) return null;
  return bad ? { ok: false, text: `Lane model differs from meiolol-lab's reference (${bad}; largest gap ${worst.toFixed(3)}): don't trust the lane suggestions.` }
    : { ok: true, text: `Lane model matches meiolol-lab on ${ref.refs.length} reference matchups (largest gap ${worst.toExponential(1)}).` };
}

// Search key: letters and digits only, so "kaisa" finds Kai'Sa and "nunu" Nunu & Willump
const champKey = s => (s || "").toLowerCase().normalize("NFD").replace(/[^a-z0-9]/g, "");
const takenIn = d => new Set([...Object.values(d.blue), ...Object.values(d.red), ...d.bans].map(String));

function draftView(body) {
  if (DRAFT.model === undefined) { loadDraftModel(); body.append(el("p", { class: "muted" }, "Loading the draft model…")); return; }
  const m = DRAFT.m, M = DRAFT.model || {}, meta = M.meta || {};
  const sec = section(body, "Draft tester", "Build two teams, swap champions in, see what the model thinks. Admin only: the public site never shows a draft's win chance.",
    el("button", { type: "button", class: "ghost", onclick: () => { DRAFT.model = undefined; render(true); } }, "Reload model"));
  if (!m) {
    if (DRAFT.err && !/^404/.test(DRAFT.err)) sec.append(el("div", { class: "health bad" }, el("b", {}, "The draft model didn't load: "), DRAFT.err));
    else sec.append(el("p", { class: "muted" }, "No draft model yet: meiolol-lab's `draft --export` writes it and deploy/lab-push.sh sends it."));
    return;
  }
  if (DRAFT.tags === undefined) loadTags();
  const d = draftState();
  const name = id => (m.champs.find(c => String(c.id) === String(id)) || { name: "#" + id }).name;
  const dev = meta.dev || {};
  sec.append(el("p", { class: "sub", title: dev.what || "" }, [meta.name, meta.training_games != null ? `${num(meta.training_games)} training games to ${meta.newest_game}` : null, meta.patch ? `play rates from patch ${meta.patch}` : null, dev.accuracy != null ? `right ${pct(dev.accuracy)} of ${num(dev.games)} practice games (coin flip 50%)` : null].filter(Boolean).join(" · ")));
  if (DRAFT.check) sec.append(el("div", { class: "health " + (DRAFT.check.ok ? "good" : "bad") }, el("b", {}, DRAFT.check.ok ? "✓ " : "⚠ "), DRAFT.check.text));
  if (DRAFT.laneErr) sec.append(el("div", { class: "health bad" }, el("b", {}, "The lane model didn't load: "), DRAFT.laneErr));
  if (DRAFT.laneCheck) sec.append(el("div", { class: "health " + (DRAFT.laneCheck.ok ? "good" : "bad") }, el("b", {}, DRAFT.laneCheck.ok ? "✓ " : "⚠ "), DRAFT.laneCheck.text));
  if (DRAFT.lane) {
    const lm = DRAFT.lane.L.meta, dev = (lm.dev || []).find(x => x.outcome === "lanediff14");
    sec.append(el("p", { class: "sub" }, `Lane suggestions: early-game model ${lm.name !== "candidate" ? lm.name + " " : ""}on ${num(lm.training_games)} games to ${lm.newest_game}.` +
      (dev ? ` It predicts the gold lead at 14 ${dev.removed_pct.toFixed(0)}% better than champion averages alone, so matchups nudge the numbers rather than decide them.` : "")));
  }
  if (m.comp) sec.append(el("p", { class: "sub" }, `Team comp terms: each champion in a role is described by ${m.comp.stats.length} numbers (${m.comp.stats.map(x => x.label).join(", ")}), summed per team, and the model weighs how they combine within a team and against the enemy. ` +
    "The range on a win chance covers the champion ratings only; each comp reason shows its own ± range."));
  else if (!M.has_pairs) sec.append(el("div", { class: "health warn" }, el("b", {}, "Caveat: "), "the model has no counter or synergy terms yet. It ranks by champion strength in the role; other picks shift the numbers, not the order."));

  const w = m.win(d);
  sec.append(el("div", { class: "winbar", role: "img", "aria-label": `Blue ${pct(w.p)}, range ${pct(w.lo)} to ${pct(w.hi)}` },
    el("div", { class: "labels" }, el("b", { class: "blue" }, `Blue ${pct(w.p)}`), el("span", { class: "sub" }, `range ${pct(w.lo)} to ${pct(w.hi)}`), el("b", { class: "red" }, `Red ${pct(1 - w.p)}`)),
    el("div", { class: "track" }, el("span", { class: "range", style: `left:${100 * w.lo}%;width:${100 * (w.hi - w.lo)}%` }), el("span", { class: "mark", style: `left:${100 * w.p}%` }), el("span", { class: "half" }))));

  sec.append(fillMenu(m, d));
  const board = el("div", { class: "draft" });
  sec.append(board);
  for (const [side, title] of SIDES) {
    const col = el("div", { class: "card team " + side }, el("h3", {}, title));
    for (const [role, label] of DRAFT_ROLES) {
      const key = side + "." + role, id = d[side][role], open = d.open === key, locked = !!d.locks[key];
      col.append(el("div", { class: "slotrow" + (open ? " open" : "") },
        el("span", { class: "role" }, label),
        el("button", { type: "button", class: "slot", "aria-expanded": String(open), title: d.fb[key] ? `Fallback: ${d.fb[key]}` : null, onclick: () => { d.open = open ? null : key; saveDraft(d); } },
          id != null ? name(id) : el("span", { class: "muted" }, "empty"), d.fb[key] && id != null ? el("span", { class: "fb" }, ` (${d.fb[key]})`) : null),
        el("button", { type: "button", class: "ghost icon", "aria-pressed": String(locked), title: locked ? "Unlock" : "Lock (random keeps it)", onclick: () => { d.locks[key] = !locked; saveDraft(d); } }, locked ? "locked" : "lock"),
        id != null ? el("button", { type: "button", class: "ghost icon", title: "Clear", "aria-label": "Clear " + name(id), onclick: () => { delete d[side][role]; delete d.fb[key]; saveDraft(d); } }, "×") : null));
      if (open) col.append(slotPicker(m, d, side, role));
    }
    board.append(col);
  }
  const bans = el("div", { class: "card bans" }, el("h3", {}, `Bans (${d.bans.length}), left out of random games and pickers`));
  const chips = el("div", { class: "chips" });
  for (const b of d.bans) chips.append(el("button", { type: "button", title: "Remove ban", onclick: () => { d.bans = d.bans.filter(x => x !== b); saveDraft(d); } }, name(b), " ×"));
  bans.append(chips);
  if (d.bans.length < 10) {
    const input = el("input", { type: "search", class: "bansearch", placeholder: "Ban a champion: type, Enter", "aria-label": "Ban a champion", autocomplete: "off", spellcheck: "false" });
    input.addEventListener("keydown", ev => {
      if (ev.key !== "Enter") return;
      const q = champKey(input.value), taken = takenIn(d);
      const c = m.champs.find(c => !taken.has(String(c.id)) && champKey(c.name).startsWith(q)) || m.champs.find(c => !taken.has(String(c.id)) && champKey(c.name).includes(q));
      if (q && c) { d.bans.push(c.id); saveDraft(d); }
    });
    bans.append(input);
  }
  sec.append(bans);
  sec.append(draftDebug(m, d, name));
}

// Data Dragon's tags (Tank, Assassin, ...) and attack/magic ratings per champion id, cached
// per version; null when it can't be reached (the fills that need them are hidden)
async function loadTags() {
  DRAFT.tags = "loading";
  try {
    const [v] = await (await fetch("https://ddragon.leagueoflegends.com/api/versions.json")).json();
    const cached = stored("ddragon", null);
    let data = cached && cached.v === v ? cached.data : null;
    if (!data) {
      const j = await (await fetch(`https://ddragon.leagueoflegends.com/cdn/${v}/data/en_US/champion.json`)).json();
      data = Object.values(j.data).map(c => [+c.key, c.tags, c.info.attack, c.info.magic]);
      store("ddragon", { v, data });
    }
    DRAFT.tags = new Map(data.map(([id, tags, attack, magic]) => [id, { tags, attack, magic }]));
  } catch (e) { DRAFT.tags = null; }
  if (ui.tab === "models" && ui.cat === "draft") render(true);
}

// Fill unlocked slots of `sides` (only empty ones when `emptyOnly`) with pick(role, taken)
// -> id, or {id, fb} when the pick fell back from what the fill asked for (shown on the slot)
function fillSlots(d, sides, pick, emptyOnly) {
  const taken = takenIn(d);
  for (const side of sides) for (const [role] of DRAFT_ROLES) {
    const key = side + "." + role;
    if (d.locks[key] || (emptyOnly && d[side][role] != null)) continue;
    if (d[side][role] != null) taken.delete(String(d[side][role]));
    delete d.fb[key];
    const x = pick(role, taken);
    const id = x != null && typeof x === "object" ? x.id : x;
    if (id == null) { delete d[side][role]; continue; }
    d[side][role] = id;
    taken.add(String(id));
    if (x.fb) d.fb[key] = x.fb;
  }
}

function fillMenu(m, d) {
  const legal = role => m.champs.filter(c => m.games(c.id, role) >= m.M.min_games && m.rate(c.id, role) > 0);
  const weighted = (list, role, taken) => {
    const pool = list.filter(c => !taken.has(String(c.id)));
    let x = Math.random() * sumR(pool.map(c => m.rate(c.id, role)));
    return (pool.find(c => (x -= m.rate(c.id, role)) <= 0) || pool[pool.length - 1] || {}).id;
  };
  const realistic = (role, taken) => weighted(legal(role), role, taken);
  const top = (role, n) => legal(role).sort((a, b) => m.rate(b.id, role) - m.rate(a.id, role)).slice(0, n);
  // Tag fills try each [test, note] in turn, so a role whose pool runs out takes the closest
  // class, then any role-legal champion, marked with the note
  const tagged = (...steps) => (role, taken) => {
    for (const [f, fb] of [...steps, [null, "any champion"]]) {
      const pool = f ? legal(role).filter(c => DRAFT.tags.has(c.id) && f(DRAFT.tags.get(c.id))) : legal(role);
      const id = weighted(pool, role, taken);
      if (id != null) return fb ? { id, fb } : id;
    }
  };
  const has = tag => t => t.tags.includes(tag);
  const fighter = [has("Fighter"), "fighter"];
  const go = f => () => { f(); d.open = null; saveDraft(d); };
  const both = ["blue", "red"];
  const btn = (label, f, title) => el("button", { type: "button", class: "action", title, onclick: go(f) }, label);
  const groups = [
    ["Realistic", [
      btn("Random realistic", () => fillSlots(d, both, realistic), "Each slot drawn by its play share in the role on the newest patch"),
      btn("Random generic", () => fillSlots(d, both, (r, t) => weighted(top(r, 15), r, t)), "Each slot from the role's 15 most played"),
      btn("Swap sides", () => {
        [d.blue, d.red] = [d.red, d.blue];
        const flip = o => Object.fromEntries(Object.entries(o).map(([k, v]) => [k.replace(/^(blue|red)/, x => x === "blue" ? "red" : "blue"), v]));
        d.locks = flip(d.locks);
        d.fb = flip(d.fb);
      }, "Same champions, sides swapped: a symmetry check"),
    ]],
  ];
  const tags = DRAFT.tags instanceof Map;
  if (tags) {
    const ad = tagged([t => t.attack > t.magic], [t => t.attack === t.magic, "mixed damage"]);
    const ap = tagged([t => t.magic > t.attack], [t => t.attack === t.magic, "mixed damage"]);
    groups.push(["Team styles", [
      btn("Blue full AD", () => fillSlots(d, ["blue"], ad)), btn("Red full AD", () => fillSlots(d, ["red"], ad)),
      btn("Blue full AP", () => fillSlots(d, ["blue"], ap)), btn("Red full AP", () => fillSlots(d, ["red"], ap)),
    ]]);
  }
  const debug = [];
  if (tags) {
    debug.push(btn("All tanks", () => fillSlots(d, both, tagged([has("Tank")], fighter))),
      btn("All assassins", () => fillSlots(d, both, tagged([has("Assassin")], fighter))));
  }
  debug.push(
    btn("Mirror", () => fillSlots(d, both, r => (top(r, 1)[0] || {}).id), "The most played champion in every role on both sides: only the intercept (blue side) should remain, about 50%"),
    btn("Empty board", () => { d.blue = {}; d.red = {}; d.locks = {}; d.fb = {}; }, "Every slot the role average"));
  groups.push(["Debug", debug]);
  const menu = el("details", { class: "fillmenu" }, el("summary", {}, "Fill…"));
  for (const [title, buttons] of groups) menu.append(el("div", { class: "fillgroup" }, el("span", { class: "sub" }, title), el("div", { class: "actions" }, ...buttons)));
  if (!tags) menu.append(el("p", { class: "sub" }, DRAFT.tags === null ? "AD, AP, tank and assassin fills need Data Dragon, which didn't answer." : "Loading Data Dragon tags…"));
  return el("div", { class: "fillbar" },
    el("button", { type: "button", class: "action", onclick: go(() => fillSlots(d, both, realistic)) }, "Random game"),
    el("button", { type: "button", class: "action", onclick: go(() => fillSlots(d, both, realistic, true)) }, "Fill empty"),
    menu);
}

// Blue's logit, slot by slot, so a number can be traced
function draftDebug(m, d, name) {
  const x = m.explain(m.teamsOf(d));
  const box = el("details", { class: "debug" }, el("summary", {}, "Debug: how the win chance is built"));
  const roles = DRAFT_ROLES.map(r => r[1]);
  table(box, "draft-debug", [
    { key: "side", label: "Side" }, { key: "role", label: "Role" }, { key: "champ", label: "Champion" },
    { key: "b", label: "Rating", num: true, fmt: v => v.toFixed(4) }, { key: "sd", label: "± sd", num: true, fmt: v => v.toFixed(4) },
    { key: "part", label: "Part of blue's logit", num: true, fmt: v => (v >= 0 ? "+" : "") + v.toFixed(4) },
  ], x.rows.map(r => ({ side: r.side ? "Red" : "Blue", role: roles[r.role], champ: r.champion ? name(r.champion) + (r.average ? " (no term: role average)" : "") : "empty (role average)", b: r.b, sd: r.sd, part: r.part })));
  const swapped = m.score(m.teamsOf(d).slice().reverse()).p;
  box.append(el("ul", { class: "readings" },
    el("li", {}, `Intercept (blue side, ${m.M.meta.platform || "EUW1"}): ${x.intercept >= 0 ? "+" : ""}${x.intercept.toFixed(4)}.`),
    el("li", {}, `Pair terms: ${m.M.has_pairs ? (x.pairs >= 0 ? "+" : "") + x.pairs.toFixed(4) : "none in this model"}.`),
    el("li", {}, `Comp terms: ${m.comp ? (x.comp >= 0 ? "+" : "") + x.comp.toFixed(4) : "none in this model"}.`),
    el("li", {}, `Logit ${x.logit.toFixed(4)}, so blue ${pct(x.p.p)} (range ${pct(x.p.lo)} to ${pct(x.p.hi)}).`),
    el("li", {}, `Sides swapped: blue would have ${pct(swapped)}; the two add up to ${pct(x.p.p + swapped)} (exactly 100% only without a side term).`)));
  return box;
}

// Candidates for one slot: search, play rate in the role, and the change to this team's win
// chance if picked; sorted by play rate or by that change
function slotPicker(m, d, side, role) {
  const box = el("div", { class: "slotpicker" });
  const cur = d[side][role];
  const ri = DRAFT_ROLES.findIndex(([r]) => r === role), si = side === "blue" ? 0 : 1;
  const q = m.slot(m.teamsOf(d), d.bans.map(Number), si, ri);
  const byId = new Map(m.champs.map(c => [c.id, c]));
  const all = q.options.map(o => ({ c: byId.get(o.champion) || { id: o.champion, name: "#" + o.champion }, rate: o.share, p: o.win, change: o.change }));
  const now = cur != null ? (all.find(x => String(x.c.id) === String(cur)) || {}).change ?? null : null;
  const input = el("input", { type: "search", placeholder: `Search ${all.length} champions played ${role}`, "aria-label": "Search champions", autocomplete: "off", spellcheck: "false" });
  const sortBtn = el("nav", { class: "switch", "aria-label": "Sort" });
  for (const [k, label] of [["played", "Most played"], ["best", "Best for this team"]]) {
    sortBtn.append(el("button", { type: "button", "aria-pressed": String(d.sort === k), onclick: () => { d.sort = k; saveDraft(d); } }, label));
  }
  const list = el("div", { class: "cands", role: "listbox" });
  const pick = id => { d[side][role] = id; delete d.fb[side + "." + role]; d.open = null; saveDraft(d); };
  const fill = () => {
    const q = champKey(input.value);
    const hits = all.filter(x => !q || champKey(x.c.name).includes(q) || champKey(x.c.alias).includes(q))
      .sort(d.sort === "best" ? (a, b) => b.p - a.p : (a, b) => b.rate - a.rate);
    list.replaceChildren(...hits.slice(0, 40).map(x => {
      const delta = x.change - (now ?? 0);
      return el("button", { type: "button", role: "option", class: String(x.c.id) === String(cur) ? "cur" : null, title: compWhy(m, d, si, ri, x.c.id), onclick: () => pick(x.c.id) },
        el("span", { class: "nm" }, x.c.name), el("span", { class: "rate" }, pct(x.rate)),
        el("b", { class: delta > 0.0005 ? "up" : delta < -0.0005 ? "down" : "" }, (Math.abs(delta) < 0.0005 ? "±" : delta > 0 ? "+" : "−") + Math.abs(delta * 100).toFixed(1) + "%"));
    }));
    if (hits.length > 40) list.append(el("p", { class: "sub" }, `${hits.length - 40} more: type to narrow.`));
  };
  input.addEventListener("input", fill);
  input.addEventListener("keydown", ev => {
    if (ev.key === "Enter") { const b = list.querySelector("button"); if (b) b.click(); }
    if (ev.key === "Escape") { d.open = null; saveDraft(d); }
  });
  box.append(suggest(m, d, all, q.options, cur, now, side, role, pick));
  box.append(el("div", { class: "pickhead" }, input, sortBtn), el("p", { class: "sub" }, `Share of the role's games on the newest patch, then the change to ${side}'s win chance ${now != null ? "against the current pick" : "against an empty slot"}. An average pick here: ${pct(q.average)}.`), list);
  fill();
  setTimeout(() => input.focus({ preventScroll: true }), 0);
  return box;
}

const SUGGEST_MIN_SHARE = 0.01;

// The two largest comp reasons for champion `id` in slot (si, ri), against an empty slot:
// "enemy magic damage high × your armour lean low: −1.2 pp (±0.8)"; null without comp terms
function compWhy(m, d, si, ri, id) {
  if (!m.comp) return null;
  const top = m.compReasons(m.teamsOf(d), si, ri, +id).slice(0, 2);
  if (!top.length || Math.abs(top[0].pp) < 0.05) return "team comp changes little";
  return top.map(x => `${x.what}: ${x.pp >= 0 ? "+" : "−"}${Math.abs(x.pp).toFixed(1)} pp (±${x.half.toFixed(1)})`).join("; ");
}

// Suggestions for the open slot, each with its reason as a plain sentence. Ranked by the
// range's low end by default, so a champion on few games can't top a list (as the site's
// lane opponents). The lane lists need the lane model (DRAFT.lane)
function suggest(m, d, all, options, cur, now, side, role, pick) {
  const byId = new Map(options.map(o => [o.champion, o]));
  const low = d.rank !== "guess";
  const ri = DRAFT_ROLES.findIndex(([r]) => r === role), roleName = DRAFT_ROLES[ri][1].toLowerCase();
  const nameOf = id => (m.champs.find(c => c.id === +id) || { name: "#" + id }).name;
  // Off-role picks (carries in support, say) farm more than the role's regulars and, on a few
  // hundred games, top the lists; suggestions keep the role's regular picks
  const cands = all.filter(x => String(x.c.id) !== String(cur) && x.rate >= SUGGEST_MIN_SHARE);
  const rank = el("nav", { class: "switch", "aria-label": "Rank by" });
  for (const [k, label] of [["low", "Likely (low end)"], ["guess", "Best guess"]]) {
    rank.append(el("button", { type: "button", "aria-pressed": String(d.rank === k), onclick: () => { d.rank = k; saveDraft(d); } }, label));
  }
  const box = el("div", { class: "suggest" }, el("div", { class: "suggesthead" }, el("h4", {}, "Suggestions"), el("span", { class: "sub" }, "Rank by"), rank),
    el("p", { class: "sub" }, `Champions with at least ${pct(SUGGEST_MIN_SHARE)} of the ${roleName} role's games this patch.`));
  const list = (title, rows, empty) => {
    box.append(el("h5", {}, title));
    if (!rows.length) { box.append(el("p", { class: "muted" }, empty)); return; }
    box.append(el("ol", {}, ...rows.map(([id, text]) => el("li", {}, el("button", { type: "button", class: "link", onclick: () => pick(id) }, nameOf(id)), ": ", text))));
  };
  const pts = x => `${x >= 0 ? "+" : "−"}${Math.abs(x * 100).toFixed(1)} points`;
  const gold = x => `${x >= 0 ? "+" : "−"}${Math.abs(Math.round(x)).toLocaleString("en-GB")}`;
  // "320 gold ahead of Ahri", "40 gold behind"
  const lead = (x, who) => `${Math.abs(Math.round(x)).toLocaleString("en-GB")} gold ${x >= 0 ? "ahead" : "behind"}${who ? (x >= 0 ? " of " : " ") + who : ""}`;

  const best = cands.slice().sort((a, b) => low ? byId.get(b.c.id).lo - byId.get(a.c.id).lo : b.p - a.p).slice(0, 5);
  list("Best for this draft", best.map(x => {
    const o = byId.get(x.c.id);
    const why = compWhy(m, d, side === "blue" ? 0 : 1, ri, x.c.id);
    return [x.c.id, `${side} would win ${pct(x.p)} of games (likely ${pct(o.lo)} to ${pct(o.hi)}), ${pts(x.change - (now ?? 0))} against ${now != null ? "the current pick" : "an empty slot"}, from ${num(o.games)} games in the role.` + (why ? ` Comp, against an empty slot: ${why}.` : "")];
  }), "No candidates left for this slot.");

  const lm = DRAFT.lane;
  if (!lm) { box.append(el("p", { class: "sub" }, "Best into your lane opponent and safest blind pick need the lane model (meiolol-lab lane --export).")); return box; }
  const { lanediff14: G, cs10: C, deaths15: D } = lm.at;
  const by = r => low ? r.lo[G] : r.value[G];
  if (ri === 1 || ri === 4) box.append(el("p", { class: "sub" }, `For ${roleName === "jungle" ? "junglers" : "supports"}, gold at 14 says more about how much a champion farms than about who wins the lane.`));
  const other = side === "blue" ? "red" : "blue", opp = d[other][role];
  if (opp != null) {
    const rows = cands.map(x => [x.c.id, lm.value(x.c.id, +opp, ri)]).sort((a, b) => by(b[1]) - by(a[1])).slice(0, 5);
    list(`Best into ${nameOf(opp)}`, rows.map(([id, r]) => [id,
      `${lead(r.value[G], nameOf(opp))} at 14 (likely ${gold(r.lo[G])} to ${gold(r.hi[G])}), ${r.value[C].toFixed(0)} CS at 10 and ${r.value[D].toFixed(1)} deaths before 15, ` +
      (r.pair_games ? `from ${num(r.pair_games)} games of this matchup and ${num(r.champ_games)} on ${nameOf(id)} in the ${roleName} role.` : `from ${num(r.champ_games)} games on ${nameOf(id)} in the ${roleName} role; no games of this matchup yet, so averages only.`)]), "No candidates left for this slot.");
  } else {
    box.append(el("h5", {}, "Best into your lane opponent"), el("p", { class: "muted" }, `Pick ${other}'s ${roleName} first: that's the lane opponent.`));
  }
  // Likely opponents: the role's champions by play share on the newest patch, without
  // picks and bans; the "worst common matchup" is among the 10 most played
  const taken = takenIn(d);
  const field = m.champs.filter(c => !taken.has(String(c.id)) && m.rate(c.id, role) > 0).map(c => ({ id: c.id, w: m.rate(c.id, role) }));
  const blind = cands.map(x => {
    const f = field.filter(o => o.id !== x.c.id), t = sumR(f.map(o => o.w));
    return [x.c.id, lm.blind(x.c.id, ri, f.map(o => ({ id: o.id, w: o.w / t })))];
  }).sort((a, b) => by(b[1]) - by(a[1])).slice(0, 5);
  list("Safest blind pick", blind.map(([id, r]) => {
    const worst = r.each.slice().sort((a, b) => b.w - a.w).slice(0, 10).sort((a, b) => a.value[G] - b.value[G])[0];
    return [id, `${lead(r.value[G], "the lane opponent")} at 14 on average across likely opponents (likely ${gold(r.lo[G])} to ${gold(r.hi[G])})` +
      (worst ? `; worst common matchup ${nameOf(worst.id)}, ${lead(worst.value[G])}` : "") + `; from ${num(r.champ_games)} games on ${nameOf(id)} in the ${roleName} role.`];
  }), "No candidates left for this slot.");
  return box;
}
