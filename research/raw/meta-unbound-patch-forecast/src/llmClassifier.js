// Optional LLM pass over parsed patch lines (Claude API).
//
// The rule-based parser is good at "X increased from A to B" but weak on qualitative lines
// ("now also disarms", reworks, interactions). This module sends each patch's hero/item lines
// to Claude in one request and asks for a direction / magnitude / confidence per line.
//
// Policy (config.llm.mode):
//   "uncertain" (default) — LLM verdict replaces the rules only where the rules were unsure
//                           (no direction, or confidence below config.llm.replaceBelow).
//   "all"                 — LLM verdict replaces every hero/item line.
// Either way both opinions are kept on the change (c.rules, c.llm) and disagreements are reported.
// Results are cached per line in data/llm-cache.json, so re-runs cost nothing.
import fs from 'node:fs';
import crypto from 'node:crypto';
import cfg from '../config.js';

const SYSTEM = `You are a Deadlock (Valve's hero shooter / MOBA) balance analyst.
You will receive patch-note lines. For each line, judge how it changes the strength (win rate) of the hero or item named as its target.

Return for every line id:
- direction: 1 if it makes the target stronger, -1 if weaker, 0 if neutral (bug fixes, UI, cosmetic, pure QoL with no power change).
- magnitude: size of the power change on a relative-stat scale. Use 0.03 for tiny, 0.08 for small, 0.15 for moderate, 0.3 for large, up to 0.6 for a change that reshapes the kit. Use 0 when direction is 0.
- confidence: 0-1, how sure you are about direction and magnitude. Reworks whose net effect is unclear deserve low confidence.
- reason: one short sentence.

Things to get right:
- Lower cooldowns, cast times, buildup times and costs help the owner; longer ones hurt.
- Changes that make it easier for enemies to counter the target (e.g. "can no longer be used while cursed") are nerfs to the target.
- "T1/T2/T3" lines are ability upgrade tiers; judge them on their own but they usually matter less than base values.
- Bug fixes that previously gave the hero an unintended advantage are nerfs; fixes for bugs that hurt the hero are small buffs. Otherwise fixes are neutral.
- Judge each line on its own, but use the other lines for the same target as context.`;

const SCHEMA = {
  type: 'object',
  properties: {
    judgments: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          direction: { type: 'integer', enum: [-1, 0, 1] },
          magnitude: { type: 'number' },
          confidence: { type: 'number' },
          reason: { type: 'string' },
        },
        required: ['id', 'direction', 'magnitude', 'confidence', 'reason'],
        additionalProperties: false,
      },
    },
  },
  required: ['judgments'],
  additionalProperties: false,
};

const clamp = (x, a, b) => Math.max(a, Math.min(b, Number.isFinite(x) ? x : 0));
const keyOf = (model, c) => crypto.createHash('sha1').update(`${model}\n${c.target}\n${c.line}`).digest('hex').slice(0, 20);

let clientPromise = null;
async function defaultClient() {
  // Lazy import: the rest of the tool works without the SDK installed.
  clientPromise ??= import('@anthropic-ai/sdk').then(({ default: Anthropic }) => new Anthropic());
  return clientPromise;
}

async function callClaude(client, patchTitle, lines) {
  const body = lines.map((c) => `[${c.id}] (${c.kind === 'item' ? 'item' : 'hero'}: ${c.target}) ${c.line.replace(/^[-•*]\s*/, '')}`).join('\n');
  const response = await client.beta.messages.create({
    model: cfg.llm.model,
    max_tokens: 16000,
    betas: ['server-side-fallback-2026-07-01'],
    fallbacks: 'default', // if a safety classifier declines, the API re-runs on a fallback model
    output_config: { effort: cfg.llm.effort, format: { type: 'json_schema', schema: SCHEMA } },
    system: SYSTEM,
    messages: [{ role: 'user', content: `Patch: ${patchTitle}\n\n${body}` }],
  });
  if (response.stop_reason === 'refusal') throw new Error(`model declined (${response.stop_details?.category ?? 'no category'})`);
  if (response.stop_reason === 'max_tokens') throw new Error('response truncated at max_tokens');
  const text = response.content.filter((b) => b.type === 'text').map((b) => b.text).join('');
  const parsed = JSON.parse(text);
  return { judgments: parsed.judgments, usage: response.usage, model: response.model };
}

export function createLlmClassifier({ client, log = () => {}, cachePath = process.env.DMA_LLM_CACHE || 'data/llm-cache.json' } = {}) {
  const cache = fs.existsSync(cachePath) ? JSON.parse(fs.readFileSync(cachePath, 'utf8')) : {};
  const stats = { requests: 0, cachedLines: 0, newLines: 0, inputTokens: 0, outputTokens: 0, failures: [] };
  let gaveUp = false; // after one failed request, stop calling the API for the rest of this run
  const save = () => fs.writeFileSync(cachePath, JSON.stringify(cache, null, 1));

  async function classify(changes, { patchTitle }) {
    const targets = changes.filter((c) => c.kind === 'hero' || c.kind === 'hero?' || c.kind === 'item');
    const todo = targets.filter((c) => !cache[keyOf(cfg.llm.model, c)]);
    stats.cachedLines += targets.length - todo.length;

    for (let i = 0; i < todo.length && !gaveUp; i += cfg.llm.batchSize) {
      const batch = todo.slice(i, i + cfg.llm.batchSize);
      try {
        const cl = client ?? (await defaultClient());
        const { judgments, usage, model } = await callClaude(cl, patchTitle, batch);
        stats.requests++; stats.newLines += batch.length;
        stats.inputTokens += usage?.input_tokens ?? 0; stats.outputTokens += usage?.output_tokens ?? 0;
        const byId = Object.fromEntries(judgments.map((j) => [j.id, j]));
        for (const c of batch) {
          const j = byId[c.id];
          if (!j) continue; // missing id → stays rule-based, retried next run
          cache[keyOf(cfg.llm.model, c)] = {
            direction: [-1, 0, 1].includes(j.direction) ? j.direction : null,
            magnitude: clamp(j.magnitude, 0, 0.6), confidence: clamp(j.confidence, 0, 1),
            reason: String(j.reason).slice(0, 300), model,
          };
        }
        save();
        log(`    LLM: ${patchTitle} — classified ${batch.length} lines`);
      } catch (e) {
        stats.failures.push(`${patchTitle}: ${e.message}`);
        log(`    LLM failed for ${patchTitle}: ${e.message}\n    → skipping the LLM for the rest of this run; rule-based verdicts are used (cached LLM verdicts still apply)`);
        gaveUp = true; // don't hammer the API if something is wrong (bad key, rate limit, outage)
      }
    }

    return changes.map((c) => {
      const j = cache[keyOf(cfg.llm.model, c)];
      if (!j) return c;
      const rules = { direction: c.direction, magnitude: c.magnitude, confidence: c.confidence, reason: c.reason };
      const llm = { direction: j.direction, magnitude: +j.magnitude.toFixed(4), confidence: j.confidence, reason: j.reason };
      const disagree = rules.direction !== null && llm.direction !== null && rules.direction !== llm.direction && rules.confidence >= 0.7;
      const use = cfg.llm.mode === 'all' || rules.direction === null || rules.confidence < cfg.llm.replaceBelow;
      if (!use || llm.direction === null) return { ...c, rules, llm, disagree, source: 'rules' };
      return { ...c, direction: llm.direction, magnitude: llm.direction === 0 ? 0 : llm.magnitude, confidence: llm.confidence, reason: `LLM: ${llm.reason}`, rules, llm, disagree, source: 'llm' };
    });
  }

  return { classify, stats };
}
