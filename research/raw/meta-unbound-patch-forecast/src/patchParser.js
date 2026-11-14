// Turns Deadlock patch-note text into structured, signed changes.
//
// Each line like "- Celeste: Shining Wonder - Cooldown increased from 160s to 170s"
// becomes { target, kind, ability, stat, from, to, magnitude, direction, weight, confidence }.
// direction: +1 buff, -1 nerf, 0 neutral/fix, null = could not tell (flagged for review).
// Anything the rules get wrong can be corrected in data/patch-overrides.json.

// Stats where a LOWER number is better for the owner.
const LOWER_IS_BETTER = /\b(cooldown|cast (time|delay)|cast point|windup|wind-up|delay|charge ?(up)? time|channel time|build ?up time|buildup|cycle time|cost|reload time|spin.?up|recovery|lockout|drop time|secure rate)\b/i;
// Stats about effects applied TO the owner by enemies (higher = worse for owner) are rare in hero lines; handled by overrides.
const UPGRADE_TIER = /\bT[123]\b/;
const BASE_STAT = /\b(base|bullet|gun) damage|\bmax health|\bbase health|\bammo|\bfire rate|\bmove ?speed|\bhealth\b(?! gained)|\bspirit (resist|resistance) scaling|\bbullet resist/i;

const num = (s) => parseFloat(String(s).replace(/[+]/g, ''));

export function htmlToText(html) {
  return html
    .replace(/<br\s*\/?>/gi, '\n').replace(/<\/(p|li|div|h\d)>/gi, '\n')
    .replace(/<[^>]+>/g, '')
    .replace(/&nbsp;/g, ' ').replace(/&amp;/g, '&').replace(/&quot;/g, '"').replace(/&#0?39;/g, "'").replace(/&lt;/g, '<').replace(/&gt;/g, '>');
}

function parseValues(text) {
  // Overwatch style: "increased to 20% (Up from 15%)", "reduced to 25 (Down from 50)"
  const ow = text.match(/\bto\s+([+-]?\d*\.?\d+)\s*%?[^()]*\((?:up|down)\s+from\s+([+-]?\d*\.?\d+)/i);
  if (ow) {
    const from = num(ow[2]), to = num(ow[1]);
    const a = Math.abs(from), b = Math.abs(to);
    return { from, to, rel: a === 0 ? (b === 0 ? 0 : 1) : (b - a) / a };
  }
  // "... increased from +18 DPS to +22", "reduced from -32% Movement to -28%", "from 0.8s to 1.5s"
  const m = text.match(/\bfrom\s+([+-]?\d*\.?\d+)\s*%?[^]*?\bto\s+([+-]?\d*\.?\d+)/i);
  if (m) {
    const from = num(m[1]), to = num(m[2]);
    const a = Math.abs(from), b = Math.abs(to);
    const rel = a === 0 ? (b === 0 ? 0 : 1) : (b - a) / a;
    return { from, to, rel };
  }
  // "... increased by 5%", "reduced by 8%", "by +0.5m"
  const by = text.match(/\bby\s+\+?(-?\d*\.?\d+)\s*(%)?/i);
  if (by) {
    const v = Math.abs(num(by[1]));
    const rel = by[2] ? v / 100 : Math.min(v / 10, 0.3); // absolute units: rough guess, low confidence
    const sign = /\b(reduc|decreas|lower)/i.test(text) ? -1 : 1;
    return { from: null, to: null, rel: sign * rel, approx: !by[2] };
  }
  return null;
}

function classifyDirection(stat, text, vals) {
  if (/^\s*fixed\b|\bfixed (a |some |an )?bug|\bbug\b/i.test(text)) return { direction: 0, reason: 'bug fix', confidence: 0.9 };
  if (/\b(ui|indicator|color|vfx|sfx|sound|visual|tooltip)\b/i.test(stat) && !vals) return { direction: 0, reason: 'cosmetic/UI', confidence: 0.8 };
  if (/\b(reticle|crosshair|animation|voice ?lines?|settings? menu|options)\b/i.test(text) && !/damage|cooldown|speed|duration|health/i.test(text)) return { direction: 0, reason: 'cosmetic/UI', confidence: 0.75 };

  if (vals) {
    let wordSign = 0;
    if (/\b(increas|raised|improv)/i.test(text)) wordSign = 1;
    else if (/\b(reduc|decreas|lower)/i.test(text)) wordSign = -1;
    // Prefer the numbers; fall back to the verb when numbers are signed weirdly.
    const valueSign = Math.sign(vals.rel) || wordSign;
    // Short stat labels like "T1" carry no noun, so look at the whole sentence instead.
    const polarity = LOWER_IS_BETTER.test(stat.replace(UPGRADE_TIER, '').trim().length > 3 ? stat : text) ? -1 : 1;
    const direction = valueSign * polarity;
    return { direction, reason: polarity < 0 ? 'lower-is-better stat' : 'higher-is-better stat', confidence: vals.approx ? 0.55 : 0.8 };
  }

  // Qualitative lines
  if (/\bno longer (interrupted|affected|stopped|cancel)/i.test(text)) return { direction: 1, reason: 'removes a weakness', confidence: 0.6 };
  if (/\b(can no longer|no longer (can|be used|works?|applies|affects|counts|grants|gives))/i.test(text)) return { direction: -1, reason: 'removes a capability', confidence: 0.55 };
  if (/\b(now also|now additionally|now (grants|gives|applies|refunds|ends|disarms|silences|stuns|heals|deals))\b/i.test(text)) return { direction: 1, reason: 'adds an effect', confidence: 0.55 };
  if (/\bnow only\b/i.test(text)) return { direction: -1, reason: 'restricts effect', confidence: 0.5 };
  if (/\bchanged from\b|\breworked?\b|\bnow (channels|works)\b/i.test(text)) return { direction: null, reason: 'rework – needs review', confidence: 0.2 };
  return { direction: null, reason: 'unclassified – needs review', confidence: 0.2 };
}

export function parsePatch(text, { heroNames = [], itemNames = [], patchId = 'custom' } = {}) {
  const heroes = new Map(heroNames.map((n) => [n.toLowerCase(), n]));
  // Patch notes sometimes shorten names ("Nurse" for "Nurse Harrow"): add unique first words as aliases.
  const firstWords = {};
  for (const n of heroNames) if (/^the\s/i.test(n)) heroes.set(n.slice(4).toLowerCase(), n); // "Doorman" → "The Doorman"
  for (const n of heroNames) { const w = n.replace(/^the\s+/i, '').split(/\s+/)[0].toLowerCase(); (firstWords[w] ??= []).push(n); }
  for (const [w, ns] of Object.entries(firstWords)) if (ns.length === 1 && !heroes.has(w)) heroes.set(w, ns[0]);
  const items = new Map(itemNames.map((n) => [n.toLowerCase(), n]));
  const lines = htmlToText(text).split(/\n/).map((l) => l.trim()).filter(Boolean);
  const changes = [];
  let section = 'general';

  lines.forEach((raw, i) => {
    const header = raw.match(/^\[?\s*(general|items?|heroes|hero|abilities)\s*\]?:?$/i) || raw.match(/(?:^|update)\s*(General|Items|Heroes):\s*$/);
    if (header) { section = header[1].toLowerCase().startsWith('hero') ? 'hero' : header[1].toLowerCase().startsWith('item') ? 'item' : 'general'; return; }
    const m = raw.match(/^[-•*]\s*([^:]{2,40}):\s*(.+)$/);
    if (!m) return;
    const [, rawTarget, rest] = m;
    const key = rawTarget.trim().toLowerCase();
    let kind = 'general', target = rawTarget.trim();
    if (heroes.has(key)) { kind = 'hero'; target = heroes.get(key); }
    else if (items.has(key)) { kind = 'item'; target = items.get(key); }
    else if (section === 'hero' && !items.has(key)) kind = 'hero?'; // unknown hero name (new hero / typo)
    else if (section === 'item') kind = 'item';

    // "Ability - stat sentence" or just "stat sentence"
    let ability = null, statText = rest;
    const dash = rest.match(/^([^-–]{2,40}?)\s+[-–]\s+(.+)$/);
    if (dash && kind.startsWith('hero')) { ability = dash[1].trim(); statText = dash[2]; }
    const stat = statText.split(/\b(increased|reduced|decreased|lowered|changed|raised|now|no longer)\b/i)[0].trim() || statText;

    const vals = parseValues(statText);
    const dir = classifyDirection(stat, statText, vals);
    let magnitude = vals ? Math.min(Math.abs(vals.rel), 0.6) : 0.08; // qualitative ≈ small change
    let weight = 1;
    if (UPGRADE_TIER.test(statText)) weight = 0.6;            // ability upgrade tiers matter less than base values
    if (!ability && BASE_STAT.test(statText)) weight = 1.6;  // base hero stats affect every fight
    if (ability && /\b(ultimate)\b/i.test(statText)) weight = 0.8;
    if (dir.direction === 0) magnitude = 0;

    changes.push({
      id: `${patchId}:${i}`, line: raw, kind, target, ability, stat,
      from: vals?.from ?? null, to: vals?.to ?? null, magnitude: +magnitude.toFixed(4),
      direction: dir.direction, weight, confidence: dir.confidence, reason: dir.reason,
    });
  });
  return changes;
}

// Collapse a change list into one signed score per hero (and per item).
// score ≈ Σ direction × magnitude × weight × confidence. Unclassified lines add uncertainty instead.
export function summarize(changes) {
  const out = {};
  for (const c of changes) {
    if (!c.kind.startsWith('hero') && c.kind !== 'item') continue;
    const s = (out[c.target] ??= { target: c.target, kind: c.kind, score: 0, buffs: 0, nerfs: 0, neutral: 0, unknown: 0, lines: [] });
    s.lines.push(c.id);
    if (c.direction === null) { s.unknown++; continue; }
    if (c.direction === 0) { s.neutral++; continue; }
    c.direction > 0 ? s.buffs++ : s.nerfs++;
    s.score += c.direction * c.magnitude * c.weight * c.confidence;
  }
  for (const s of Object.values(out)) {
    s.score = +s.score.toFixed(4);
    s.verdict = s.score > 0.02 ? 'buff' : s.score < -0.02 ? 'nerf' : (s.buffs || s.nerfs) ? 'mixed' : s.unknown ? 'rework' : 'fixes';
  }
  return out;
}

export function applyOverrides(changes, overrides = {}) {
  // overrides: { "<line text or id>": { direction, magnitude, weight } }
  return changes.map((c) => {
    const o = overrides[c.id] || overrides[c.line];
    return o ? { ...c, ...o, confidence: o.confidence ?? 1, reason: 'manual override' } : c;
  });
}
