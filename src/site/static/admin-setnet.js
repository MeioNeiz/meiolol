// meiolol admin dashboard: the set net beside the Draft tester's additive model (Models >
// Draft). Loaded before admin-draft.js, which calls setNets when training/ has
// setnet-s<seed>.json files (`meiolol-lab netcheck --export 1`, format in lab/setnet.zig
// writeExport) and gives it the additive model's logit for the draft.
//
// The net is a correction on that logit: blue's logit = (f(blue, red) - f(red, blue)) / 2 +
// c[platform] + a * base, f from each team's five slot units. It has no terms of its own,
// so its part is broken down by swapping: a pick replaced by its role's average (zero
// profile, the role's embedding row), or one profile trait zeroed across a team. Those
// parts don't add up to the whole (the net isn't additive); the seeds' spread is the range

// EUW1's index in the lab's platform list (protocol.platformIds, riot/endpoints.zig); the
// additive model's export scores on EUW1's side term
const SETNET_EUW = 6;
// Largest |logit diff| between the page's draft model and the nets' fitted base on their
// reference games: the export leaves out pair cells on fewer than 20 games
// (draft.zig default_pair_floor), which moves a few drafts slightly
const SETNET_BASE_TOL = 0.05;
// Words for a team high in profile feature f (lab/setnet.zig Feature, in order)
const SETNET_TRAITS = {
  magic: "magic damage share", true_dmg: "true damage share", dmg: "damage dealt", tank: "damage mitigated",
  taken: "damage taken", armour: "armour over magic resist", cc: "crowd control time", immob: "immobilisations",
  ally: "heals and shields on allies", heal: "self-healing", range: "attack range", buildings: "damage to buildings",
};

function setNet(S) {
  if (!S || S.format !== "meiolol-setnet" || S.version !== 1) return null;
  const { phi, rho, emb, cross, n_prof: np, layout: L, params: p } = S;
  const ids = new Map(S.ids.map(x => [x.champion + ":" + x.role, x.id]));
  const profs = new Map(S.profiles.map(x => [x.champion + ":" + x.role, x.z]));
  const zero = new Array(np).fill(0);
  // One slot's input: z profile, role one-hot, embedding row (an empty slot or an unknown
  // champion-role: zero profile and the role's row, as an average pick)
  const input = (id, r) => {
    const x = (id && profs.get(id + ":" + r)) || zero;
    const v = (id && ids.get(id + ":" + r)) ?? r;
    const out = x.slice();
    for (let k = 0; k < 5; k++) out.push(k === r ? 1 : 0);
    for (let k = 0; k < emb; k++) out.push(p[L.e + v * emb + k]);
    return out;
  };
  const unit = x => {
    const u = new Array(phi);
    for (let j = 0; j < phi; j++) {
      let s = p[L.b1 + j];
      for (let i = 0; i < L.in; i++) s += p[L.w1 + j * L.in + i] * x[i];
      u[j] = Math.max(0, s);
    }
    return u;
  };
  // f per side order from the ten slot inputs (blue by role, then red)
  const f = xs => {
    const t = [0, 1].map(side => {
      const v = new Array(phi).fill(0);
      for (let r = 0; r < 5; r++) unit(xs[side * 5 + r]).forEach((u, j) => { v[j] += 0.2 * u; });
      return v;
    });
    return [0, 1].map(o => {
      const rin = cross ? t[o].concat(t[1 - o]) : t[o];
      let out = 0;
      for (let j = 0; j < rho; j++) {
        let z = p[L.cb + j];
        for (let i = 0; i < L.rin; i++) z += p[L.v + j * L.rin + i] * rin[i];
        if (z > 0) out += p[L.out + j] * z;
      }
      return out;
    });
  };
  // teams[side][role]: champion id, 0 empty; edit(xs) may change the slot inputs in place
  const logit = (teams, base, platform = SETNET_EUW, edit = null) => {
    const xs = teams.flatMap(t => t.map((id, r) => input(id, r)));
    if (edit) edit(xs);
    const [fb, fr] = f(xs);
    return (fb - fr) / 2 + p[L.c + platform] + p[L.a] * base;
  };
  // Slot s's embedding row set to its role's (s % 5), as for an unknown champion-role
  const roleRow = (xs, s) => {
    for (let k = 0; k < emb; k++) xs[s][np + 5 + k] = p[L.e + (s % 5) * emb + k];
  };
  return { seed: S.seed, S, emb, logit, roleRow, features: S.features };
}

// The file's reference games through this page's forward pass: max |logit diff|
function setNetCheck(n) {
  let worst = 0;
  for (const r of n.S.refs) worst = Math.max(worst, Math.abs(n.logit(r.teams, r.offset, r.platform) - r.logit));
  return { games: n.S.refs.length, worst };
}

// The seeds' nets as one: blue's chance the mean of theirs, the range their spread
function setNets(files) {
  const nets = files.map(setNet).filter(Boolean);
  if (!nets.length) return null;
  const sig = x => 1 / (1 + Math.exp(-x));
  const chance = (teams, base, edit) => nets.map(n => sig(n.logit(teams, base, SETNET_EUW, edit)));
  const mean = a => a.reduce((s, x) => s + x, 0) / a.length;
  return {
    nets,
    seeds: nets.map(n => n.seed),
    checks: nets.map(n => ({ seed: n.seed, ...setNetCheck(n) })),
    // base: the additive model's logit for blue (no temperature, no lab comp terms)
    score(teams, base) {
      const ps = chance(teams, base);
      return { p: mean(ps), lo: Math.min(...ps), hi: Math.max(...ps), base: sig(base) };
    },
    // The net's part of blue's chance (net minus base, pp) and what it comes from: each
    // pick against its role's average pick, each team's traits zeroed one at a time, and
    // the champion-role embeddings (every pick's own row swapped for its role's)
    explain(teams, base) {
      const full = chance(teams, base);
      // A swap's part in pp: the seeds' mean and spread of full minus swapped
      const part = ps => {
        const d = ps.map((x, k) => 100 * (full[k] - x));
        return { pp: mean(d), lo: Math.min(...d), hi: Math.max(...d) };
      };
      const picks = [], traits = [];
      teams.forEach((t, side) => t.forEach((id, r) => {
        if (!id) return;
        const u = teams.map(x => x.slice());
        u[side][r] = 0;
        picks.push({ side, role: r, champion: id, ...part(chance(u, base)) });
      }));
      nets[0].features.forEach((name, i) => [0, 1].forEach(side => {
        const ps = chance(teams, base, xs => { for (let r = 0; r < 5; r++) xs[side * 5 + r][i] = 0; });
        traits.push({ side, feature: name, words: SETNET_TRAITS[name] || name, ...part(ps) });
      }));
      const identity = nets[0].emb ? part(nets.map(n => sig(n.logit(teams, base, SETNET_EUW, xs => xs.forEach((_, s) => n.roleRow(xs, s)))))) : null;
      return { ...part(full.map(() => sig(base))), picks, traits, identity };
    },
  };
}

// The additive model's logit for blue as the net takes it: the page's draft model without
// the lab's champion-into-comp terms and before its temperature
function setNetBase(m, teams) {
  const e = m.explain(teams);
  return e.logit - e.champcomp;
}

// The page's draft model against the base the nets were fitted on: their reference games
// on EUW1 (the export scores on EUW1's side term), max |logit diff|. A different model
// (the box's daily one, an export on other games) shows as a large diff
function setNetBaseCheck(net, m) {
  let worst = 0, games = 0;
  for (const r of net.nets[0].S.refs) {
    if (r.platform !== SETNET_EUW) continue;
    worst = Math.max(worst, Math.abs(setNetBase(m, r.teams) - r.offset));
    games++;
  }
  return { games, worst };
}

// The net's card under the win bar: its chance for blue beside the additive model's, then
// what its part comes from (largest first). name: champion id -> name
function setNetView(net, m, teams, name) {
  const base = setNetBase(m, teams), s = net.score(teams, base), x = net.explain(teams, base);
  const sgn = v => (v >= 0 ? "+" : "−") + Math.abs(v).toFixed(1);
  const side = k => k ? "red" : "blue";
  const ROLE = ["top", "jungle", "mid", "bot", "support"];
  // Parts for blue; red's picks and traits read from red's side
  const own = (k, v) => k ? -v : v;
  const top = (rows, n) => rows.filter(r => Math.abs(r.pp) >= 0.1).sort((a, b) => Math.abs(b.pp) - Math.abs(a.pp)).slice(0, n);
  const line = (text, r, k) => el("li", {}, `${text}: ${sgn(own(k, r.pp))} pp `, el("span", { class: "sub" }, `(seeds ${sgn(own(k, k ? r.hi : r.lo))} to ${sgn(own(k, k ? r.lo : r.hi))})`));
  const picks = top(x.picks, 5).map(r => line(`${name(r.champion)} (${side(r.side)} ${ROLE[r.role]}), in place of an average ${ROLE[r.role]}`, r, r.side));
  const traits = top(x.traits, 5).map(r => line(`${side(r.side)}'s ${r.words}`, r, r.side));
  return el("div", { class: "card setnet" },
    el("h3", {}, "Neural net estimate (lab, not confirmed)"),
    el("p", {}, el("b", {}, `Blue ${pct(s.p)}`), ` with the net (seeds ${pct(s.lo)} to ${pct(s.hi)}), additive model alone ${pct(s.base)}: the net moves blue by ${sgn(x.pp)} pp.`),
    el("p", { class: "sub" }, `The net is a correction on top of the additive model above, from each team's champion profiles together. It has no terms of its own, so its part is broken down by swapping: a pick for its role's average, or one trait blanked across a team. ` +
      "The pieces overlap and don't add up to the whole. Each line is in its own team's chance."),
    picks.length ? el("details", { open: "" }, el("summary", {}, "From the picks"), el("ul", {}, ...picks)) : null,
    traits.length ? el("details", {}, el("summary", {}, "From team traits"), el("ul", {}, ...traits)) : null,
    x.identity ? el("p", { class: "sub" }, `Champion-specific part (each pick's own learnt row, beyond its profile): ${sgn(x.identity.pp)} pp for blue (seeds ${sgn(x.identity.lo)} to ${sgn(x.identity.hi)}).`) : null);
}
