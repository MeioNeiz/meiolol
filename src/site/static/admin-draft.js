// meiolol admin dashboard: the Draft tester (Models > Draft, admin.js draws the rest).
// Loaded before admin.js, whose first render calls draftView; uses its helpers (el,
// section, table, stored, store, getJson, render, ui, num, pct, sumR) only when called.
//
// Admin only: a draft board of two teams, the model's win chance for the whole draft, and
// a picker per slot showing what each champion would change. The model comes from the box's
// daily `meiolol draft-model` (models/, deploy/web-loop.sh) or meiolol-lab's `draft --export`
// sent by deploy/lab-push.sh (training/), as draft-model.json with reference pairs in
// draft-ref.json, checked at load (modelFile). Nothing here reaches the public site, which
// must not claim "this draft wins X%"

const DRAFT_ROLES = [["top", "Top"], ["jungle", "Jungle"], ["mid", "Mid"], ["bot", "Bot"], ["support", "Support"]];
const SIDES = [["blue", "Blue"], ["red", "Red"]];
const DRAFT = { model: undefined, err: null, check: null, m: null, from: {}, gen: 0, loading: null };
const MODEL_DIRS = { models: "box daily", training: "lab pick" };
// The draft model the board scores with: the shipped one (the box's daily export, models/)
// or the lab experiment (whatever `lab-push.sh use draft` sent, training/); the old
// draftPrefer setting carries over
const DRAFT_SOURCES = [["shipped", "Shipped model"], ["lab", "Lab experiment"]];
const draftSource = () => stored("draftModel", stored("draftPrefer", "box") === "lab" ? "lab" : "shipped");
// Files the box's daily export writes; the rest (draft-comp.json) come from the lab only, so
// models/ isn't asked for them (a 404 there would only fill the console)
const BOX_FILES = new Set(["draft-model.json", "lane-model.json"]);

// A model file: the draft model from the chosen source only; the lane model from the box's
// daily export, else the lab's; the rest from the lab. References come from the same
// directory
async function modelFile(name) {
  const dirs = name === "draft-model.json" ? [draftSource() === "lab" ? "training" : "models"]
    : BOX_FILES.has(name) ? ["models", "training"] : ["training"];
  for (const [i, dir] of dirs.entries()) {
    try { return { json: await getJson(`${dir}/${name}`), dir }; }
    catch (e) { if (i === dirs.length - 1 || !/^404/.test(e.message)) throw e; }
  }
}

function draftState() {
  const d = stored("draft2", null) || {};
  return { blue: d.blue || {}, red: d.red || {}, locks: d.locks || {}, fb: d.fb || {}, bans: d.bans || [], open: d.open || null, order: d.order || "best" };
}
// undo: the board before a fill (JSON), for its Undo button; any other change drops it
function saveDraft(d, undo = null) { DRAFT.undo = undo; store("draft2", d); render(true); }

// One load at a time (draftView starts it); each builds in locals and sets DRAFT at the end,
// and only the newest load does, so a reload while one is under way can't mix their files
function startDraftLoad() {
  const gen = ++DRAFT.gen;
  DRAFT.loading = loadDraftModel().then(x => { if (gen === DRAFT.gen) Object.assign(DRAFT, x); })
    .finally(() => {
      if (gen !== DRAFT.gen) return;
      DRAFT.loading = null;
      if (ui.tab === "models" && ui.cat === "draft") render(true);
    });
}

function reloadDraft() { DRAFT.model = undefined; DRAFT.loading = null; render(true); }

async function loadDraftModel() {
  const x = { model: null, m: null, err: null, check: null, from: {}, cc: null, ccErr: null, lane: null, laneErr: null, laneCheck: null, net: null, netErr: null, netChecks: [] };
  // Champion-into-comp terms are optional: without them the model scores as exported
  try {
    const { json: C, dir } = await modelFile("draft-comp.json");
    x.from.comp = dir;
    x.cc = champComp(C);
    if (!x.cc) throw new Error(`draft-comp.json is format "${C.format}" version ${C.version}; this page reads meiolol-champcomp versions 1 and 2`);
  } catch (e) { if (!/^404/.test(e.message)) x.ccErr = e.message; }
  try {
    const { json: M, dir } = await modelFile("draft-model.json");
    x.model = M; x.from.draft = dir;
    x.m = draftModel(M, x.cc);
    if (!x.m) throw new Error(`draft-model.json is format "${M.format}" version ${M.version}; this page reads meiolol-draft-model versions 1 to 4`);
    const ref = await getJson(`${dir}/draft-ref.json`).catch(() => null);
    // draft-ref.json is the exported model alone: checked without the comp terms
    x.check = ref ? draftCheck(x.cc ? draftModel(M) : x.m, ref) : null;
  } catch (e) { x.model = null; x.m = null; x.err = e.message; }
  // The set net is optional and lab only (admin-setnet.js); shown only on the base it was
  // fitted on, so the draft model must match its reference games' offsets
  if (x.m && draftSource() === "lab") try {
    const { json: N } = await modelFile("draft-setnet.json");
    const net = setNets(N.nets || []);
    if (!net) throw new Error("draft-setnet.json has no meiolol-setnet version 1 nets");
    const worst = Math.max(...net.checks.map(c => c.worst)), base = setNetBaseCheck(net, x.m);
    x.netChecks.push({ ok: worst < 1e-4, text: `set net seeds ${net.seeds.join(", ")}: this page's forward pass against the export's ${net.checks[0].games} reference games, max |logit diff| ${worst.toExponential(1)}` });
    // Another draft model (the box's daily one by default) is expected, so only a note
    const same = base.games > 0 && base.worst < SETNET_BASE_TOL;
    x.netChecks.push({ ok: true, info: !same, text: same ? `set net base: the draft model against the offsets the nets were fitted on, ${base.games} EUW reference games, max |logit diff| ${base.worst.toFixed(4)}`
      : "Set net not shown: the lab experiment's draft model isn't the one the net was fitted on (send the matching export with `lab-push.sh use draft`)" });
    if (same && x.netChecks.every(c => c.ok)) x.net = net;
  } catch (e) { if (!/^404/.test(e.message)) x.netErr = e.message; }
  // The lane model is optional: without it the picker has no lane column
  try {
    const { json: L, dir } = await modelFile("lane-model.json");
    x.from.lane = dir;
    x.lane = laneModel(L);
    if (!x.lane) throw new Error(`lane-model.json is format "${L.format}" version ${L.version}; this page reads meiolol-lane-model version 1`);
    const ref = await getJson(`${dir}/lane-ref.json`).catch(() => null);
    x.laneCheck = ref ? laneCheck(x.lane, ref) : null;
  } catch (e) { if (!/^404/.test(e.message)) x.laneErr = e.message; }
  return x;
}

// Champion-into-comp terms (draft-comp.json, `meiolol-lab champcomp --export`, docs/model.md
// "Draft model file"): each seat's own lean into the enemy's five and its four allies, on
// top of the shipped model (offset win-draft). A seat's term on its team's logit is
// sum_f dev[f] * ((x[f] - mean[f]) / sd[f] - centre[f]), x from seat values: AP share of
// the set's damage, then sums of the other traits; an empty slot or a champion-role with
// no profile is the role's seat, and a champion-role with no cell adds nothing. Version 2
// adds the auto-attack trait and, from `--groups`, kit groups: cell.group[f] is the part of
// dev[f] its groups predict, dev[f] - group[f] the champion's own
function champComp(C) {
  if (!C || C.format !== "meiolol-champcomp" || ![1, 2].includes(C.version)) return null;
  const nt = C.traits.length, F = C.features;
  const seats = new Map(C.seats.map(r => [r[0] + ":" + r[1], r.slice(2)]));
  const cells = new Map(C.cells.map(c => [c.champion + ":" + c.role, c]));
  const seatOf = (id, r) => (id && seats.get(id + ":" + r)) || C.role_seats[r];
  const traits = set => {
    const t = new Array(nt).fill(0);
    let magic = 0, dmg = 0;
    for (const s of set) { magic += s[0]; dmg += s[1]; for (let i = 1; i < nt; i++) t[i] += s[1 + i]; }
    t[0] = dmg > 0 ? magic / dmg : 0.5;
    return t;
  };
  // Seat (side, r)'s term and its parts by feature, null without a cell
  const seat = (teams, side, r) => {
    const cell = teams[side][r] && cells.get(teams[side][r] + ":" + r);
    if (!cell) return null;
    const S = teams.map(t => t.map((id, k) => seatOf(id, k)));
    const x = [...traits(S[1 - side]), ...traits(S[side].filter((_, k) => k !== r))];
    const parts = F.map((f, i) => cell.dev[i] * ((x[i] - f.mean) / f.sd - cell.centre[i]));
    const lean = F.map((f, i) => (x[i] - f.mean) / f.sd - cell.centre[i]);
    return { cell, parts, lean, term: parts.reduce((a, b) => a + b, 0) };
  };
  // Blue's part: blue's seat terms minus red's
  const part = teams => {
    let x = 0;
    for (let side = 0; side < 2; side++) for (let r = 0; r < 5; r++) {
      const s = seat(teams, side, r);
      if (s) x += side ? -s.term : s.term;
    }
    return x;
  };
  const check = () => {
    let worst = 0;
    for (const ref of C.refs || []) worst = Math.max(worst, Math.abs(part(ref.teams) - ref.blue));
    const n = (C.refs || []).length;
    if (!n) return null;
    return worst > 1e-6 ? { ok: false, text: `Champion-into-comp terms differ from meiolol-lab's reference (largest gap ${worst.toExponential(1)}): don't trust them.` }
      : { ok: true, text: `Champion-into-comp terms match meiolol-lab on ${n} reference games (largest gap ${worst.toExponential(1)}).` };
  };
  return { C, F, nt, seat, seatOf, part, check };
}

// The exported model (docs/model.md "Draft model file"; Scorer in src/lab/draft.zig is the
// reference): champions, play share per role on the newest patch, blue's win chance with a
// 95% interval for a draft, and the candidates for a slot. A draft here is
// {blue: {role: id}, red: {role: id}}; an empty slot, or a champion with no term in the
// role, is average[role] with sd 0. Version 2 adds comp terms (model.comp, null without):
// each slot's profile p summed per team, P_b'S P_b - P_r'S P_r + P_b'A P_r. Version 3 adds
// model.temperature: chances are sigmoid(temperature * logit) (calibration, draft.zig).
// Version 4 adds model.pairs (null without): the additive model's pair cells, one number
// per pair of champions (Scorer.pairLogit). cc (champComp, or null) adds its seat terms
function draftModel(M, cc = null) {
  if (!M || M.format !== "meiolol-draft-model" || ![1, 2, 3, 4].includes(M.version)) return null;
  const terms = new Map(M.model.terms.map(t => [t.champion + ":" + t.role, t]));
  const cells = new Map(M.cells.map(c => [c.champion + ":" + c.role, c]));
  const avg = M.average.map(a => ({ p: [], raw: [], ...a, sd: 0 }));
  const { intercept, w, z } = M.model;
  const temp = M.model.temperature ?? 1;
  const comp = M.model.comp || null;
  // Team terms on f, the team's damage-weighted magic share (draft.zig TeamTerm)
  const FORMS = { mix: d => d * d, ad_heavy: d => Math.min(d, 0) ** 2, ap_heavy: d => Math.max(d, 0) ** 2 };
  const RAW_MAGIC = 0, RAW_DMG = 2;
  const team = comp ? comp.team || [] : [];
  const unknown = team.filter(t => !FORMS[t.kind]);
  if (unknown.length) throw new Error(`draft-model.json has team terms (${unknown.map(t => t.kind).join(", ")}) this page can't score yet`);
  const magicShare = T => {
    let num = 0, den = 0;
    for (const x of T) { num += x.raw[RAW_DMG] * x.raw[RAW_MAGIC]; den += x.raw[RAW_DMG]; }
    return den > 0 ? num / den : 0.5;
  };
  const k = comp ? comp.stats.length : 0;
  const dot = (a, b) => { let x = 0; for (let i = 0; i < a.length; i++) x += a[i] * b[i]; return x; };
  const sig = x => 1 / (1 + Math.exp(-x));
  const slots = teams => teams.map(t => t.map((id, r) => (id && terms.get(id + ":" + r)) || avg[r]));
  // Pair cells by group:a:b, [theta, games]; an empty slot (0) touches none
  const pairs = M.model.pairs || null;
  const pcell = new Map(pairs ? pairs.cells.map(([g, a, b, x, n]) => [g + ":" + a + ":" + b, [x, n]]) : []);
  const cellOf = (g, a, b) => (a && b && pcell.get(g + ":" + a + ":" + b)) || null;
  const cellX = (g, a, b) => (cellOf(g, a, b) || [0])[0];
  const pairPart = ([B, R]) => {
    if (!pairs) return 0;
    let x = 0;
    pairs.groups.forEach((g, i) => {
      const { r, q } = g;
      if (g.kind === "ally") x += cellX(i, B[r], B[q]) - cellX(i, R[r], R[q]);
      else if (r !== q) x += cellX(i, B[r], R[q]) - cellX(i, R[r], B[q]);
      else if (B[r] !== R[r]) x += (B[r] < R[r] ? 1 : -1) * cellX(i, Math.min(B[r], R[r]), Math.max(B[r], R[r]));
    });
    return x;
  };
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
    if (team.length) {
      const fb = magicShare(B), fr = magicShare(R);
      for (const t of team) x += t.weight * (FORMS[t.kind](fb - t.centre) - FORMS[t.kind](fr - t.centre));
    }
    return x;
  };
  // teams[side][role]: champion id, 0 empty
  const score = teams => {
    const sl = slots(teams), [B, R] = sl;
    let logit = intercept + compPart(sl) + pairPart(teams) + (cc ? cc.part(teams) : 0), v = 0;
    for (let r = 0; r < 5; r++) {
      logit += B[r].b - R[r].b;
      v += B[r].sd ** 2 + R[r].sd ** 2;
    }
    if (M.has_pairs) {
      for (let i = 0; i < 5; i++) for (let j = 0; j < 5; j++) logit += w[i * 5 + j] * (dot(B[i].u, R[j].v) - dot(R[i].u, B[j].v));
      for (let a = 0; a < 5; a++) for (let b = a + 1; b < 5; b++) logit += z[a * 5 + b] * (dot(B[a].s, B[b].s) - dot(R[a].s, R[b].s));
    }
    const h = 1.96 * Math.sqrt(v);
    return { p: sig(temp * logit), lo: sig(temp * (logit - h)), hi: sig(temp * (logit + h)) };
  };
  const teamsOf = d => SIDES.map(([side]) => DRAFT_ROLES.map(([role]) => +d[side][role] || 0));
  const roleIdx = Object.fromEntries(DRAFT_ROLES.map(([r], i) => [r, i]));
  const names = new Map(M.champions.map(c => [c.id, c.name]));
  const who = c => names.get(c) || "#" + c;
  const ROLE = ["top", "jungle", "mid", "bot", "support"];
  const botLane = (a, b) => a !== b && a >= 3 && b >= 3;
  // Why `id` in slot (side, r) moves that side's win chance against the role's average pick:
  // the change in pp, split into parts that add up to it (the sigmoid's secant over the
  // whole change). Named parts are the ones that test as real (docs/learned.md "Win"): the
  // champion's strength, the lane matchup, bot and support with and against each other, and
  // clear comp leans the draft actually triggers. The other pairings (top against their mid,
  // support with the jungler) and the shrunk leans don't show one by one, so they are summed
  // unnamed
  const why = (teams, side, r, id) => {
    const t = teams.map(x => x.slice());
    t[side][r] = 0;
    const p0 = score(t).p, comp0 = compPart(slots(t)), cc0 = cc && t.map((x, s) => x.map((_, k) => cc.seat(t, s, k)));
    t[side][r] = id;
    const sl = slots(t), p1 = score(t).p, comp1 = compPart(sl);
    const q0 = side ? 1 - p0 : p0, q1 = side ? 1 - p1 : p1;
    const l0 = Math.log(q0 / (1 - q0)), l1 = Math.log(q1 / (1 - q1));
    const slope = Math.abs(l1 - l0) > 1e-9 ? (sig(l1) - sig(l0)) / (l1 - l0) : sig(l1) * (1 - sig(l1));
    // Parts are in the model's logit; the shown chance moves by temperature times them
    const pp = x => 100 * slope * temp * x;
    const parts = [], lumped = { leans: 0 }, others = [];
    let named = 0;
    const add = (x, part) => { parts.push({ pp: pp(x), ...part }); named += x; };
    const mine = t[side], theirs = t[1 - side], cellAvg = cells.get(id + ":" + r);
    const own = sl[side][r];
    add(own.b - avg[r].b, { kind: "strength", chip: `${own.b >= avg[r].b ? "strong" : "weak"} ${ROLE[r]}`,
      text: `${who(id)}'s strength as a ${ROLE[r]} pick`, note: `${num(cellAvg ? cellAvg.games : 0)} games, ±${Math.abs(pp(1.96 * own.sd)).toFixed(1)} (95% range)` });
    if (pairs) pairs.groups.forEach((g, i) => {
      const { r: a, q: b } = g;
      let c = null, sign = 1, other = 0, ally = g.kind === "ally";
      if (ally) {
        if (a === r) [c, other] = [cellOf(i, id, mine[b]), b];
        else if (b === r) [c, other] = [cellOf(i, mine[a], id), a];
      } else if (a === b) {
        const o = theirs[a];
        if (a === r && o && o !== id) [c, sign, other] = [cellOf(i, Math.min(id, o), Math.max(id, o)), id < o ? 1 : -1, a];
      } else if (a === r) [c, other] = [cellOf(i, id, theirs[b]), b];
      else if (b === r) [c, sign, other] = [cellOf(i, theirs[a], id), -1, a];
      if (!c) return;
      const o = who((ally ? mine : theirs)[other]);
      if (!(a === b || botLane(a, b))) { others.push({ pp: pp(sign * c[0]), text: `${ally ? "with" : "into"} ${o} (${ROLE[other]})` }); return; }
      add(sign * c[0], { kind: ally ? "duo" : "lane", chip: ally ? `with ${o}` : `into ${o}`,
        text: ally ? `With your ${o} (${ROLE[other]})` : `Into their ${o} (${ROLE[other]})`, note: `${num(c[1])} games of the pair in the draft model` });
    });
    if (cc) {
      const { F, nt } = cc;
      // Words for a team high or low in trait i (draft-comp.json traits, in order)
      const TRAIT = [["magic-heavy", "AD-heavy"], ["melee-heavy", "ranged-heavy"], ["high-CC", "low-CC"], ["engage-heavy", "low-engage"],
        ["dive-heavy", "low-dive"], ["tanky", "squishy"], ["high-sustain", "low-sustain"], ["early-game", "late-game"], ["auto-attack-heavy", "spell-heavy"]];
      const ADDS = [["magic damage", "physical damage"], ["a melee champion", "a ranged champion"], ["crowd control", "less crowd control"], ["engage", "less engage"],
        ["dive", "less dive"], ["tankiness", "squishiness"], ["sustain", "less sustain"], ["early power", "late-game power"], ["auto-attacks", "fewer auto-attacks"]];
      const s1 = cc.seat(t, side, r), groups = cc.C.groups || [];
      if (s1) F.forEach((f, i) => {
        if (!s1.parts[i]) return;
        // Named only when clear and the team really is that way (its z, not just the lean
        // from this champion's usual opponents, points the same way)
        const z = s1.lean[i] + s1.cell.centre[i], real = Math.abs(z) >= 0.5 && Math.sign(z) === Math.sign(s1.lean[i]);
        const enemy = i < nt, words = TRAIT[i % nt][z > 0 ? 0 : 1];
        const like = `${enemy ? "into " + (/^(AD|[aeiou])/i.test(words) ? "an" : "a") : "with"} ${words} ${enemy ? "team" : "allies"} like this one`;
        const chip = good => `${good ? "good" : "weak"} ${enemy ? "into" : "with"} ${words}${enemy ? "" : " allies"}`;
        // A clear kit group's part is named apart from the champion's own lean beyond it
        const mine = (s1.cell.member || []).map(g => groups[g]).filter(g => g.feature === i && g.sd > 0 && Math.abs(g.gamma) / g.sd >= 2.58);
        let rest = s1.parts[i];
        if (mine.length && real) {
          const x = s1.cell.group[i] * s1.lean[i], kin = mine.map(g => g.words).join(" and "), g0 = mine[0];
          add(x, { kind: "lean", chip: chip(x > 0), text: `${who(id)} ${x > 0 ? "does better" : "does worse"} ${like}, like other ${kin}`,
            note: `kit group lean, not yet confirmed on fresh games, ±${Math.abs(pp(1.96 * g0.sd * s1.cell.group[i] / g0.gamma * s1.lean[i])).toFixed(1)} (95% range)` });
          rest -= x;
          if (!s1.cell.clear.includes(i) || Math.abs(pp(rest)) < 0.5) { lumped.leans += rest; return; }
          add(rest, { kind: "lean", text: `${who(id)}'s own lean beyond other ${kin}`, note: "clear lean, its part beyond its group" });
          return;
        }
        if (!s1.cell.clear.includes(i) || !real) { lumped.leans += rest; return; }
        add(rest, { kind: "lean", chip: chip(rest > 0), text: `${who(id)} ${rest > 0 ? "does better" : "does worse"} ${like}`,
          note: `clear lean, ±${Math.abs(pp(1.96 * s1.cell.sd[i] * s1.lean[i])).toFixed(1)} (95% range)` });
      });
      // The pick changes what the other seats see. Named when their lean is clear and the pick
      // clearly brings that trait: magic damage only from a champion that mostly deals it
      const pick = cc.seatOf(id, r), base = cc.seatOf(0, r), share = s => s[1] > 0 ? s[0] / s[1] : 0.5;
      const brings = {};
      for (let s = 0; s < 2; s++) for (let k = 0; k < 5; k++) {
        if (s === side && k === r) continue;
        const a = cc0[s][k], b = cc.seat(t, s, k);
        if (!b) continue;
        b.parts.forEach((x, j) => {
          const d = (x - a.parts[j]) * (s === side ? 1 : -1), dz = b.lean[j] - a.lean[j], ti = j % nt;
          if (Math.abs(d) < 1e-12) return;
          const clear = b.cell.clear.includes(j) && Math.abs(dz) >= 0.3 &&
            (ti !== 0 || (dz > 0 ? share(pick) >= 0.55 && share(pick) > share(base) : share(pick) <= 0.35 && share(pick) < share(base)));
          if (!clear) { lumped.leans += d; return; }
          const key = ti + (dz > 0 ? "+" : "-");
          const x0 = brings[key] || (brings[key] = { x: 0, ti, up: dz > 0, seats: [] });
          x0.x += d;
          x0.seats.push({ name: who(t[s][k]), text: `${s === side ? "your" : "their"} ${who(t[s][k])} ${(s === side) === (d > 0) ? "better" : "worse"} ${s === side ? "with" : "against"} it` });
        });
      }
      for (const b of Object.values(brings)) {
        const adds = ADDS[b.ti][b.up ? 0 : 1];
        add(b.x, { kind: "brings", chip: `adds ${adds}`,
          text: `Brings ${adds}: ${b.seats.map(x => x.text).join("; ")}`, note: "their clear lean" });
      }
    }
    const comp = comp1 - comp0;
    const rest = (l1 - l0) / temp - named - lumped.leans - comp;
    if (Math.abs(rest) > 1e-12) {
      const big = others.sort((a, b) => Math.abs(b.pp) - Math.abs(a.pp)).slice(0, 3).filter(x => Math.abs(x.pp) >= 0.2);
      parts.push({ pp: pp(rest), kind: "rest", text: "Other matchups and duos, summed (each pair too thin to name alone)",
        note: big.length ? "largest: " + big.map(x => `${x.text} ${x.pp >= 0 ? "+" : "−"}${Math.abs(x.pp).toFixed(1)}`).join(", ") : null });
    }
    if (Math.abs(lumped.leans) > 1e-12) parts.push({ pp: pp(lumped.leans), kind: "rest", text: "Other comp leans, summed (each shrunk or not clear)" });
    if (Math.abs(comp) > 1e-12) parts.push({ pp: pp(comp), kind: "rest", text: "Team comp terms" });
    const chips = parts.filter(x => x.chip && Math.abs(x.pp) >= 0.5).sort((a, b) => Math.abs(b.pp) - Math.abs(a.pp)).slice(0, 3);
    // The unnamed parts as one muted chip when they matter, so a row's chips come close to
    // its number
    const unnamed = sumR(parts.filter(x => x.kind === "rest").map(x => x.pp));
    if (Math.abs(unnamed) >= 1) chips.push({ pp: unnamed, kind: "rest", chip: "unnamed, summed" });
    return { total: 100 * (q1 - q0), parts, chips };
  };
  const m = {
    M, score, teamsOf, comp, pairs, cc, why,
    compPart: teams => compPart(slots(teams)),
    pairPart,
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
      const c = compPart(slots(teams)), ccx = cc ? cc.part(teams) : 0;
      const lin = intercept + c + ccx + sumR(rows.map(x => x.part));
      const p = score(teams), logit = Math.log(p.p / (1 - p.p)) / temp;
      return { intercept, rows, comp: c, champcomp: ccx, pairs: logit - lin, logit, temp, p };
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
    if (x.pairs != null) cmp(m.pairPart(x.teams), x.pairs, `${x.label}: pair part`);
  }
  for (const q of ref.slots || []) {
    const s = m.slot(q.teams, q.bans || [], q.side, q.role, q.min_games);
    cmp(s.empty, q.empty, `${q.label}: empty`);
    cmp(s.average, q.average, `${q.label}: average`);
    if (s.options.length !== q.options.length) { bad = `${q.label}: ${s.options.length} candidates, the reference has ${q.options.length}`; worst = Infinity; continue; }
    q.options.forEach((o, i) => {
      const mine = s.options[i];
      if (mine.champion !== o.champion) { bad = `${q.label}: order differs at ${i + 1}`; worst = Infinity; return; }
      for (const k of ["win", "lo", "hi", "change"]) cmp(mine[k], o[k], `${q.label}: ${k}`);
    });
  }
  if (!n) return null;
  return bad ? { ok: false, text: `Differs from its reference (${bad}; largest gap ${isFinite(worst) ? worst.toExponential(1) : "order"}): don't trust these numbers.` }
    : { ok: true, text: `Matches its reference on ${(ref.drafts || []).length} reference drafts and ${(ref.slots || []).length} slot lists (largest gap ${worst.toExponential(1)}).` };
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
  return bad ? { ok: false, text: `Lane model differs from its reference (${bad}; largest gap ${worst.toFixed(3)}): don't trust the lane suggestions.` }
    : { ok: true, text: `Lane model matches its reference on ${ref.refs.length} reference matchups (largest gap ${worst.toExponential(1)}).` };
}

// Search key: letters and digits only, so "kaisa" finds Kai'Sa and "nunu" Nunu & Willump
const champKey = s => (s || "").toLowerCase().normalize("NFD").replace(/[^a-z0-9]/g, "");
const takenIn = d => new Set([...Object.values(d.blue), ...Object.values(d.red), ...d.bans].map(String));

function draftView(body) {
  if (DRAFT.model === undefined) { if (!DRAFT.loading) startDraftLoad(); body.append(el("p", { class: "muted" }, "Loading the draft model…")); return; }
  const m = DRAFT.m, M = DRAFT.model || {}, meta = M.meta || {};
  const lab = draftSource() === "lab";
  const sec = section(body, "Draft tester", "Build two teams, swap champions in, see what the model thinks. Admin only: the public site never shows a draft's win chance.",
    el("span", { class: "actions" }, el("button", { type: "button", class: "ghost", onclick: reloadDraft }, "Reload model")));
  // Which model scores the board, in words; the lab's name comes from its file
  const modelName = lab ? (meta.name ? `Lab: ${meta.name.split(":")[0]}` : "Lab experiment") : "Shipped model";
  sec.append(el("div", { class: "modelpick" }, el("span", { class: "sub" }, "Model"),
    switcher(DRAFT_SOURCES, lab ? "lab" : "shipped", k => { if (k !== draftSource()) { store("draftModel", k); reloadDraft(); } }, "Draft model"),
    el("span", { class: "sub" }, !m ? "" : lab ? `${meta.name || "an export"}${DRAFT.net ? ", with the neural net on top" : ""}, sent from the lab (${meta.snapshot || "snapshot unknown"}); not used by the app or site.`
      : "What the app and site use, refitted daily by the box on the newest games.")));
  if (!m) {
    if (DRAFT.err && !/^404/.test(DRAFT.err)) sec.append(el("div", { class: "health bad" }, el("b", {}, "The draft model didn't load: "), DRAFT.err));
    else if (lab) sec.append(el("p", { class: "muted" }, "No lab experiment loaded: send one with `deploy/lab-push.sh use draft RUN|DIR` (meiolol-lab's `draft --export`), or switch to the shipped model."));
    else sec.append(el("p", { class: "muted" }, "No shipped model yet: the box writes one daily (`meiolol draft-model`). The lab experiment may have one."));
    return;
  }
  if (DRAFT.tags === undefined) loadTags();
  const d = draftState();
  const name = id => (m.champs.find(c => String(c.id) === String(id)) || { name: "#" + id }).name;
  // Problems show; the models' description folds into one line, passed checks and model
  // stats go under Debug
  const dev = meta.dev || {}, about = [], bad = [], checks = [];
  const health = (x, label) => x.ok ? checks.push(`✓ ${label || ""}${x.text}`) : bad.push(el("div", { class: "health bad" }, el("b", {}, "⚠ "), label || "", x.text));
  if (DRAFT.check) health(DRAFT.check);
  if (DRAFT.ccErr) health({ ok: false, text: DRAFT.ccErr }, "The champion-into-comp terms didn't load: ");
  const ccCheck = m.cc && m.cc.check();
  if (ccCheck) health(ccCheck);
  if (DRAFT.laneErr) health({ ok: false, text: DRAFT.laneErr }, "The lane model didn't load: ");
  if (DRAFT.laneCheck) health(DRAFT.laneCheck);
  if (DRAFT.netErr) health({ ok: false, text: DRAFT.netErr }, "The set net didn't load: ");
  for (const c of DRAFT.netChecks || []) c.info ? checks.push(c.text) : health(c);
  sec.append(...bad);
  if (dev.accuracy != null) about.push(el("p", { class: "sub" }, `In plain words: on ${num(dev.games)} recent games it wasn't fitted on, the model picked the winner ${pct(dev.accuracy)} of the time; a coin manages 50%. ` +
    "The Models tab's headline is a different reading (the best of the daily eval's models on the final test games), so the two numbers differ."));
  if (m.pairs && M.model.kind === "draft") about.push(el("p", { class: "sub" }, "The shipped model, as the app and site score drafts: each champion's strength in its role plus every pair of allies and every matchup, each pulled towards what the two champions' strengths predict and weighted as the daily eval tuned them. " +
    "The range on a win chance covers the champion ratings only."));
  else if (m.pairs) about.push(el("p", { class: "sub" }, `Pair terms: one learnt number for each pair of allies and each matchup seen in at least ${num(m.pairs.min_games)} games (rarer pairs count as average), plus the team's mix of magic and physical damage. ` +
    "The range on a win chance covers the champion ratings only."));
  else if (m.comp) about.push(el("p", { class: "sub" }, `Team comp terms: each champion in a role is described by ${m.comp.stats.length} numbers (${m.comp.stats.map(x => x.label).join(", ")}), summed per team, and the model weighs how they combine within a team and against the enemy.`));
  else if (!M.has_pairs) sec.append(el("div", { class: "health warn" }, el("b", {}, "Caveat: "), "the model has no counter or synergy terms yet. It ranks by champion strength in the role; other picks shift the numbers, not the order."));
  if (m.cc) {
    const cm = m.cc.C.meta, g = x => `${x.mean >= 0 ? "+" : "−"}${Math.abs(1000 * x.mean).toFixed(2)} ± ${(1000 * x.half).toFixed(2)}`;
    about.push(el("p", { class: "sub", title: cm.what }, `Champion-into-comp terms on top: each champion's own lean into the enemy team's and its allies' ${m.cc.C.traits.join(", ")}, beyond the matchups and duos. ` +
      "Only leans that are clear on the numbers are named as reasons." +
      ((m.cc.C.groups || []).length ? ` Kit groups (${m.cc.C.groups.map(g => g.words).join(", ")}) set each member's starting guess, which its own games then move; a group's lean is named "like other ..." and is not yet confirmed on fresh games.` : ""),
    ));
    checks.push(`Champion-into-comp: ${cm.clear} of ${num(cm.tests)} leans are clear; with them the model predicted newer games better in ${cm.better} of 5 rounds, on ${num(cm.fit_games)} games, before looking at the games kept back for the final test; log loss change per game ${g(cm.folds)} milli-nats (negative is better), ${cm.snapshot}.`);
  }
  if (DRAFT.lane) {
    const lm = DRAFT.lane.L.meta, dev = (lm.dev || []).find(x => x.outcome === "lanediff14");
    checks.push(`Lane model: ${lm.name} on ${num(lm.training_games)} games to ${lm.newest_game}.`);
    about.push(el("p", { class: "sub" }, `Lane column: an early-game model on ${num(lm.training_games)} games to ${lm.newest_game}.` +
      (dev ? ` It predicts the gold lead at 14 ${dev.removed_pct.toFixed(0)}% better than champion averages alone, so matchups nudge the numbers rather than decide them.` : "")));
  }
  if (dev.accuracy != null) checks.push(`Accuracy: this page's model, refitted on older games and scored on the ${num(dev.games)} played games just before the final test cut (the 10% of games before the newest 15%).`);
  const from = [["draft", "draft model"], ["comp", "comp terms"], ["lane", "lane model"]].filter(([k]) => DRAFT.from[k]).map(([k, label]) => `${label} ${MODEL_DIRS[DRAFT.from[k]]}`);
  checks.push(`Files: ${from.join(", ")}.`);
  if (meta.name) checks.unshift(`Draft model: ${meta.name}.`);
  // The crawl's scope (docs/learned.md, docs/data.md): ranked solo, Platinum IV and up, nearly
  // all EUW
  sec.append(el("details", { class: "about" }, el("summary", { class: "sub" }, ["ranked solo, Platinum IV and up, mostly EUW",
    meta.training_games != null ? `${num(meta.training_games)} games to ${meta.newest_game}` : null,
    dev.accuracy != null ? `picks the winner in ${pct(dev.accuracy)} of ${num(dev.games)} recent games it wasn't fitted on (a coin: 50%; not the Models tab's test reading)` : null,
    bad.length || !(DRAFT.check || ccCheck || DRAFT.laneCheck) ? null : "page matches the model files (a software check, details under Debug)"].filter(Boolean).join(" · ")), ...about));

  const w = m.win(d), none = !Object.keys(d.blue).length && !Object.keys(d.red).length;
  sec.append(el("div", { class: "winbar", role: "img", "aria-label": `Blue ${pct(w.p)}, ${none ? "no picks yet" : `95% range ${pct(w.lo)} to ${pct(w.hi)}`}` },
    el("div", { class: "labels" }, el("b", { class: "blue" }, `Blue ${pct(w.p)}`), el("span", { class: "sub" }, `${modelName} · ${none ? "no picks yet: the blue side alone" : `95% range ${pct(w.lo)} to ${pct(w.hi)}`}`), el("b", { class: "red" }, `Red ${pct(1 - w.p)}`)),
    el("div", { class: "track" }, el("span", { class: "range", style: `left:${100 * w.lo}%;width:${100 * (w.hi - w.lo)}%` }), el("span", { class: "mark", style: `left:${100 * w.p}%` }), el("span", { class: "half" }))));
  if (DRAFT.net) sec.append(setNetView(DRAFT.net, m, m.teamsOf(d), name));

  sec.append(fillMenu(m, d), el("p", { class: "sub" }, "Random game and the fills redraw every slot not marked keep (Fill empty: only the empty ones)."));
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
        el("button", { type: "button", class: "ghost icon", "aria-pressed": String(locked), title: locked ? "Kept: click to let Random game and the fills redraw it" : "Keep: Random game and the fills leave this slot as it is", onclick: () => { d.locks[key] = !locked; saveDraft(d); } }, locked ? "kept" : "keep"),
        id != null ? el("button", { type: "button", class: "ghost icon", title: "Clear", "aria-label": "Clear " + name(id), onclick: () => { delete d[side][role]; delete d.fb[key]; saveDraft(d); } }, "×") : null));
    }
    board.append(col);
  }
  if (!d.open) DRAFT.pick = null;
  else {
    const [side, role] = d.open.split(".");
    sec.append(el("div", { class: "card picker " + side }, el("div", { class: "pickertitle" },
      el("h3", {}, `${side === "blue" ? "Blue" : "Red"} ${DRAFT_ROLES.find(([r]) => r === role)[1].toLowerCase()}`),
      el("button", { type: "button", class: "ghost icon", "aria-label": "Close", onclick: () => { d.open = null; saveDraft(d); } }, "×")), slotPicker(m, d, side, role)));
  }
  const bans = el("div", { class: "card bans" }, el("h3", {}, `Bans (${d.bans.length}), both teams' in one list, left out of random games and pickers`));
  const chips = el("div", { class: "chips" });
  for (const b of d.bans) chips.append(el("button", { type: "button", title: "Remove ban", onclick: () => { d.bans = d.bans.filter(x => x !== b); saveDraft(d); } }, name(b), " ×"));
  bans.append(chips);
  if (d.bans.length < 10) {
    const input = el("input", { type: "search", class: "bansearch", placeholder: "Ban a champion: type, Enter", "aria-label": "Ban a champion", autocomplete: "off", spellcheck: "false" });
    const hint = el("p", { class: "sub" });
    // The name typed first, then names starting with it, then any containing it
    const match = () => {
      const q = champKey(input.value), free = m.champs.filter(c => !taken.has(String(c.id)));
      return q ? free.find(c => champKey(c.name) === q) || free.find(c => champKey(c.name).startsWith(q)) || free.find(c => champKey(c.name).includes(q)) : null;
    };
    const taken = takenIn(d);
    input.addEventListener("input", () => {
      const c = match();
      hint.textContent = input.value ? (c ? `Enter bans ${c.name}` : "No champion matches") : "";
    });
    input.addEventListener("keydown", ev => {
      if (ev.key !== "Enter") return;
      const c = match();
      if (c) { d.bans.push(c.id); saveDraft(d); }
    });
    bans.append(input, hint);
  }
  sec.append(bans);
  sec.append(draftDebug(m, d, name, checks));
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
  // The picks the picker lists: 1%+ of the role's games on the newest patch
  const legal = role => m.champs.filter(c => m.games(c.id, role) >= m.M.min_games && m.rate(c.id, role) >= PICK_MIN_SHARE);
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
  const go = f => () => { const before = JSON.stringify(d); f(); d.open = null; saveDraft(d, before); };
  const both = ["blue", "red"];
  const btn = (label, f, title) => el("button", { type: "button", class: "action", title, onclick: go(f) }, label);
  const groups = [
    ["More", [
      btn("Random, top 15 only", () => fillSlots(d, both, (r, t) => weighted(top(r, 15), r, t)), "Each slot drawn by play share from the role's 15 most played"),
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
    btn("Mirror", () => fillSlots(d, both, r => (top(r, 1)[0] || {}).id), "The most played champion in every role on both sides: only the intercept (blue side) should remain, about 50%"));
  groups.push(["Debug", debug]);
  const menu = el("details", { class: "fillmenu" }, el("summary", {}, "Fill…"));
  for (const [title, buttons] of groups) menu.append(el("div", { class: "fillgroup" }, el("span", { class: "sub" }, title), el("div", { class: "actions" }, ...buttons)));
  if (!tags) menu.append(el("p", { class: "sub" }, DRAFT.tags === null ? "AD, AP, tank and assassin fills need Data Dragon, which didn't answer." : "Loading Data Dragon tags…"));
  const drawn = "each slot drawn by its play share in the role on the newest patch, from the picks the picker lists (1%+ of the role's games); locked slots stay";
  return el("div", { class: "fillbar" },
    btn("Random game", () => fillSlots(d, both, realistic), "Every slot: " + drawn),
    btn("Fill empty", () => fillSlots(d, both, realistic, true), "Empty slots only: " + drawn),
    btn("Empty board", () => { d.blue = {}; d.red = {}; d.locks = {}; d.fb = {}; }, "Every slot empty: each counts as the role's average pick"),
    DRAFT.undo ? el("button", { type: "button", class: "ghost", title: "The board as it was before the last fill", onclick: () => saveDraft(JSON.parse(DRAFT.undo)) }, "Undo") : null,
    menu);
}

// Blue's logit, slot by slot, so a number can be traced
function draftDebug(m, d, name, checks = []) {
  const x = m.explain(m.teamsOf(d));
  const box = el("details", { class: "debug" }, el("summary", {}, "Debug: how the win chance is built, model files and checks"));
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
    el("li", {}, `Champion-into-comp terms: ${m.cc ? (x.champcomp >= 0 ? "+" : "") + x.champcomp.toFixed(4) : "none loaded (draft-comp.json)"}.`),
    el("li", {}, `Logit ${x.logit.toFixed(4)}${x.temp !== 1 ? `, times the calibration temperature ${x.temp} = ${(x.temp * x.logit).toFixed(4)}` : ""}, so blue ${pct(x.p.p)} (range ${pct(x.p.lo)} to ${pct(x.p.hi)}).`),
    el("li", {}, `Sides swapped: blue would have ${pct(swapped)}; the two add up to ${pct(x.p.p + swapped)} (exactly 100% only without a side term).`)));
  if (checks.length) box.append(el("p", { class: "sub" }, el("b", {}, "Model files and checks")), el("ul", { class: "readings" }, ...checks.map(t => el("li", {}, t))));
  return box;
}

// Picks for one slot, a row each: the change to this side's win chance against an average
// pick, the lane lead at 14 (top, mid and bot: for junglers and supports gold says more about
// farming than winning), draft fit (the change less the champion's own strength: an off-meta
// pick that suits this draft) and the main reasons; a row opens to the whole breakdown,
// which adds up to the change. Regular picks only (1%+ of the role's games this
// patch: off-role picks farm more and top lists on a few hundred games) unless searched
const PICK_MIN_SHARE = 0.01;

function slotPicker(m, d, side, role) {
  const box = el("div");
  const cur = d[side][role] != null ? +d[side][role] : null;
  const ri = DRAFT_ROLES.findIndex(([r]) => r === role), si = side === "blue" ? 0 : 1, roleName = DRAFT_ROLES[ri][1].toLowerCase();
  const teams = m.teamsOf(d);
  const q = m.slot(teams, d.bans.map(Number), si, ri);
  const byId = new Map(m.champs.map(c => [c.id, c]));
  const nameOf = id => (byId.get(id) || { name: "#" + id }).name;
  const other = side === "blue" ? "red" : "blue", opp = d[other][role] != null ? +d[other][role] : null;
  const lm = DRAFT.lane && [0, 2, 3].includes(ri) ? DRAFT.lane : null;
  const G = lm && lm.at.lanediff14;
  // Blind: likely opponents by play share, without picks and bans
  const taken = takenIn(d);
  const field = lm && opp == null ? m.champs.filter(c => !taken.has(String(c.id)) && m.rate(c.id, role) > 0).map(c => ({ id: c.id, w: m.rate(c.id, role) })) : null;
  const laneOf = id => {
    if (!lm) return null;
    if (opp != null) return lm.value(id, opp, ri);
    const f = field.filter(o => o.id !== id), t = sumR(f.map(o => o.w));
    return lm.blind(id, ri, f.map(o => ({ id: o.id, w: o.w / t })));
  };
  const rows = q.options.map(o => ({ ...o, c: byId.get(o.champion) || { id: o.champion, name: "#" + o.champion }, lane: laneOf(o.champion) }));
  // why() scores the draft a few dozen times; the fit sort needs it for every listed row
  const whys = new Map();
  const whyOf = x => whys.get(x.champion) || whys.set(x.champion, m.why(teams, si, ri, x.champion)).get(x.champion);
  const fitOf = x => { const w = whyOf(x); return w.total - sumR(w.parts.filter(p => p.kind === "strength").map(p => p.pp)); };
  const signed = (x, digits = 1) => (Math.abs(x) < 0.5 * 10 ** -digits ? "±" : x > 0 ? "+" : "−") + Math.abs(x).toFixed(digits);
  const tone = (x, eps) => x > eps ? "up" : x < -eps ? "down" : "";
  const gold = x => `${x >= 0 ? "+" : "−"}${Math.abs(Math.round(x)).toLocaleString("en-GB")}`;
  // The search and open row live in DRAFT, not here: the page re-renders (sort, a poll of the
  // box's data) and a re-render must not close a breakdown or clear the search
  const key = side + "." + role;
  if (!DRAFT.pick || DRAFT.pick.key !== key) DRAFT.pick = { key, q: "", opened: null, fresh: true };
  const P = DRAFT.pick;

  const input = el("input", { type: "search", placeholder: `Search all ${rows.length} ${roleName} picks`, "aria-label": "Search champions", autocomplete: "off", spellcheck: "false" });
  input.value = P.q;
  const sorts = [["best", "Surest win"], ["fit", "Best draft fit"], ...(lm ? [["lane", opp != null ? `Most gold into ${nameOf(opp)}` : "Most lane gold, blind"]] : [])];
  const sort = sorts.some(([k]) => k === d.order) ? d.order : "best";
  const sortNav = el("nav", { class: "switch", "aria-label": "Sort" });
  for (const [k, label] of sorts) sortNav.append(el("button", { type: "button", "aria-pressed": String(sort === k), onclick: () => { d.order = k; saveDraft(d); } }, label));
  const pick = id => { d[side][role] = id; delete d.fb[side + "." + role]; d.open = null; saveDraft(d); };
  const list = el("div", { class: "cands", role: "list" });

  const breakdown = x => {
    const w = whyOf(x);
    const named = w.parts.filter(p => p.kind !== "rest").sort((a, b) => Math.abs(b.pp) - Math.abs(a.pp));
    const line = p => el("li", { class: p.kind === "rest" ? "muted" : null }, el("b", { class: tone(p.pp, 0.05) }, signed(p.pp)), " ", p.text, p.note ? el("span", { class: "sub" }, ` (${p.note})`) : null);
    const out = el("div", { class: "breakdown" },
      el("ul", {}, ...named.map(line), ...w.parts.filter(p => p.kind === "rest").map(line)),
      el("p", { class: "sub" }, `= ${signed(w.total)} points (lines rounded): ${side} wins ${pct(x.win)} (95% range ${pct(x.lo)} to ${pct(x.hi)}) against ${pct(q.empty)} with an average ${roleName}; ${num(x.games)} games of ${x.c.name} ${roleName}, ${pct(x.share)} of the role's games on the newest patch.`));
    const L = x.lane;
    if (L) {
      const { cs10: C, deaths15: D } = lm.at;
      if (opp != null) out.append(el("p", { class: "sub" }, `Lane into ${nameOf(opp)}: ${gold(L.value[G])} gold at 14 (95% range ${gold(L.lo[G])} to ${gold(L.hi[G])}), ${L.value[C].toFixed(0)} CS at 10, ${L.value[D].toFixed(1)} deaths before 15; ` +
        (L.pair_games ? `${num(L.pair_games)} games of the matchup in the lane model.` : "no games of the matchup in the lane model yet, champion averages only.")));
      else {
        const worst = L.each.slice().sort((a, b) => b.w - a.w).slice(0, 10).sort((a, b) => a.value[G] - b.value[G])[0];
        out.append(el("p", { class: "sub" }, `Blind lane: ${gold(L.value[G])} gold at 14 on average over likely opponents (95% range ${gold(L.lo[G])} to ${gold(L.hi[G])})` +
          (worst ? `; hardest common one ${nameOf(worst.id)}, ${gold(worst.value[G])}.` : ".")));
      }
    }
    out.append(el("button", { type: "button", class: "action", onclick: () => pick(x.champion) }, `Pick ${x.c.name}`));
    return out;
  };

  const fill = () => {
    const s = champKey(input.value);
    const by = sort === "fit" ? (a, b) => fitOf(b) - fitOf(a) : sort === "lane" ? (a, b) => b.lane.lo[G] - a.lane.lo[G] : (a, b) => b.lo - a.lo;
    // Searching, the name typed comes first (Enter picks it: "vi" is Vi, not Viego), then
    // names starting with it, then the rest, each in the sort's order
    const match = x => Math.min(...[x.c.name, x.c.alias].map(champKey).map(k => k === s ? 0 : k.startsWith(s) ? 1 : k.includes(s) ? 2 : 3));
    const hits = s ? rows.map(x => ({ x, k: match(x) })).filter(h => h.k < 3).sort((a, b) => a.k - b.k || by(a.x, b.x)).map(h => h.x)
      : rows.filter(x => x.share >= PICK_MIN_SHARE || x.champion === cur).sort(by);
    // The top two's 95% ranges overlapping is said plainly; no rule for a safe pick
    const range = sort === "best" ? x => [x.lo, x.hi] : sort === "lane" ? x => [x.lane.lo[G], x.lane.hi[G]] : null;
    const tie = !s && range && hits.length > 1 && range(hits[1])[1] >= range(hits[0])[0]
      ? el("p", { class: "sub tie" }, `The top two, ${hits[0].c.name} and ${hits[1].c.name}, have overlapping 95% ${sort === "lane" ? "gold " : ""}ranges: too close to call on these numbers.`) : null;
    const head = (k, label, title) => el("span", { title: title + (sort === k ? ". Sorted by this" + (k === "fit" ? "" : ", by the low end of its range") : "") }, label + (sort === k ? " ▾" : ""));
    list.replaceChildren(el("div", { class: "candhead" + (lm ? " lane" : "") }, el("span", {}, "Champion"), head("best", "Win", `Change to ${side}'s win chance against an average ${roleName}`),
      lm ? head("lane", "Gold", `Gold lead at 14 minutes ${opp != null ? "into " + nameOf(opp) : "on average over likely opponents (blind)"}, lane model`) : null, head("fit", "Fit", `Win less the champion's own strength as a ${roleName}: what this draft adds (matchups, duos, comp)`), el("span", { class: "whyh" }, "Why"), el("span", { class: "pickh" })));
    if (tie) list.prepend(tie);
    for (const x of hits) {
      const open = P.opened === x.champion;
      const w = whyOf(x), fit = fitOf(x);
      const row = el("div", { class: "cand" + (lm ? " lane" : "") + (x.champion === cur ? " cur" : "") + (open ? " open" : ""), role: "listitem" },
        el("button", { type: "button", class: "more", "aria-expanded": String(open), title: open ? "Close the breakdown" : "Why: the whole breakdown", onclick: () => { P.opened = open ? null : x.champion; fill(); } },
          el("span", { class: "name" }, el("span", { class: "caret", "aria-hidden": "true" }, open ? "▾ " : "▸ "), x.c.name),
          el("b", { class: tone(x.change, 0.0005), title: `${side} wins ${pct(x.win)} (95% range ${pct(x.lo)} to ${pct(x.hi)})` }, signed(100 * x.change)),
          lm ? el("span", { class: "gold " + tone(x.lane.value[G], 50) }, gold(x.lane.value[G])) : null,
          el("span", { class: "fit " + tone(fit, 0.05), title: `${signed(w.total)} less ${signed(w.total - fit)} for ${x.c.name}'s strength as a ${roleName}` }, signed(fit)),
          el("span", { class: "why" }, ...w.chips.map(c => el("span", c.kind === "rest" ? { class: "chip", title: "Parts too thin or unclear to name one by one: open the row" } : { class: "chip " + tone(c.pp, 0) }, `${c.chip} ${signed(c.pp)}`)))),
        el("button", { type: "button", class: "ghost pick", title: `Put ${x.c.name} in the slot`, onclick: () => pick(x.champion) }, "Pick"));
      list.append(row);
      if (open) list.append(breakdown(x));
    }
    if (!hits.length) list.append(el("p", { class: "muted" }, "No pick matches."));
  };
  input.addEventListener("input", () => { P.q = input.value; fill(); });
  input.addEventListener("keydown", ev => {
    if (ev.key === "Enter") { const b = list.querySelector(".cand button.pick"); if (b) b.click(); }
    if (ev.key === "Escape") { d.open = null; saveDraft(d); }
  });
  box.append(el("div", { class: "pickhead" }, input, sortNav),
    el("p", { class: "sub" }, `Win: change in ${side}'s win chance for the whole game, in percentage points, against an average ${roleName} (${pct(q.empty)})` +
      (lm ? `. Gold: gold ahead at 14 ${opp != null ? "into " + nameOf(opp) : "on average over likely opponents"}, from the lane model; ` +
        "it can disagree with Win (lane bullies against late scalers)" : "") +
      `. Fit: Win less the champion's own strength as a ${roleName}, so what this draft adds (matchups, duos, comp)` +
      (sort === "fit" ? ". Sorted by fit: an off-meta pick that suits this draft tops a strong meta one"
        : `. Sorted surest first: by the low end of the ${sort === "lane" ? "gold" : "win"} range, so a sure small gain can top an unsure bigger one`) + ". Click a row for why; Pick puts it in the slot."),
    list);
  fill();
  setTimeout(() => {
    input.focus({ preventScroll: true });
    // On opening, bring the picker up when it starts below the fold (a phone, where it sits
    // under both team cards)
    if (!P.fresh) return;
    P.fresh = false;
    const card = box.closest(".picker"), top = card && card.getBoundingClientRect().top;
    if (!card || top < 0.6 * window.innerHeight) return;
    // Clear of the sticky header and tabs
    const cover = Math.max(0, ...[...document.querySelectorAll("header.top, nav.tabs")]
      .filter(e => ["sticky", "fixed"].includes(getComputedStyle(e).position)).map(e => e.getBoundingClientRect().bottom));
    window.scrollTo({ top: window.scrollY + top - cover - 8, behavior: "smooth" });
  }, 0);
  return box;
}
