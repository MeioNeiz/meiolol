// Patch-impact model: predicted win-rate change = k × (signed change score).
// k is not guessed — it is fitted by replaying past patches and comparing the parser's
// score with what actually happened to each hero's win rate. The fit doubles as an audit.
import cfg from '../config.js';
import { get, unix } from './api.js';
import { shrink, pearson, mean } from './stats.js';

async function wrByHero(fromDate, toDate, offline) {
  const rows = await get('/v1/analytics/hero-stats', { min_unix_timestamp: unix(fromDate), max_unix_timestamp: unix(toDate) }, { offline, ttlHours: 24 * 30 });
  const out = {};
  for (const r of rows) out[r.hero_id] = { wins: r.wins, games: r.matches, wr: shrink(r.wins, r.matches, cfg.shrinkGames) };
  return out;
}

export async function backtest(timeline, heroIdByName, { currentPatchId, offline, log = () => {} }) {
  const W = cfg.impact.windowDays * 864e5;
  const past = timeline.filter((p) => p.id !== currentPatchId && !p.custom).slice(-cfg.impact.maxBacktestPatches - 1);
  const points = [];
  const perPatch = [];
  for (let i = 0; i < past.length; i++) {
    const p = past[i];
    const d = new Date(p.date);
    const prevD = i > 0 ? new Date(past[i - 1].date) : new Date(d - W);
    const nextD = past[i + 1] ? new Date(past[i + 1].date) : new Date(timeline.find((x) => new Date(x.date) > d)?.date || Date.now());
    const preFrom = new Date(Math.max(d - W, +prevD)), postTo = new Date(Math.min(+d + W, +nextD, Date.now()));
    if ((d - preFrom) < 2 * 864e5 || (postTo - d) < 2 * 864e5) continue; // windows too short to trust
    log(`  backtest ${p.id} (${p.title})`);
    let pre, post;
    try { [pre, post] = [await wrByHero(preFrom, d, offline), await wrByHero(d, postTo, offline)]; } catch (e) { log(`   skipped: ${e.message}`); continue; }
    const pts = [];
    for (const [name, s] of Object.entries(p.summary)) {
      const id = heroIdByName[name];
      if (!id || !pre[id] || !post[id] || s.kind !== 'hero') continue;
      if (pre[id].games < 500 || post[id].games < 500) continue;
      pts.push({ patch: p.id, hero: name, score: s.score, observed: post[id].wr - pre[id].wr, nPost: post[id].games });
    }
    points.push(...pts);
    perPatch.push({ id: p.id, title: p.title, preDays: +((d - preFrom) / 864e5).toFixed(1), postDays: +((postTo - d) / 864e5).toFixed(1), heroes: pts.length });
  }

  const usable = points.filter((x) => x.score !== 0);
  let k = cfg.impact.fallbackK / 100, fitted = false;
  if (usable.length >= 12) {
    const num = usable.reduce((s, x) => s + x.score * x.observed, 0);
    const den = usable.reduce((s, x) => s + x.score * x.score, 0);
    if (den > 0 && num > 0) { k = num / den; fitted = true; }
  }
  const pred = usable.map((x) => k * x.score);
  const obs = usable.map((x) => x.observed);
  const signHits = usable.filter((x) => Math.sign(x.score) === Math.sign(x.observed)).length;
  const maeModel = mean(usable.map((x, i) => Math.abs(obs[i] - pred[i])));
  const maeNaive = mean(obs.map(Math.abs));
  return {
    k, fitted, n: usable.length,
    r: +pearson(usable.map((x) => x.score), obs).toFixed(3),
    signAccuracy: usable.length ? +(signHits / usable.length).toFixed(3) : null,
    maeModelPp: +(maeModel * 100).toFixed(3), maeNaivePp: +(maeNaive * 100).toFixed(3),
    patches: perPatch,
    points: points.map((x) => ({ ...x, predicted: k * x.score })),
  };
}
