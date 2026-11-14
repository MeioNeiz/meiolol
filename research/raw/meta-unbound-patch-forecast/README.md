# Meta Unbound

Patch-aware hero tiers, situations, matchups, synergies and draft picks for Deadlock — with every number traceable to its evidence. Node 18+; the only dependency is the Anthropic SDK, used by the optional `--llm` pass.

```bash
npm install                                         # only needed for --llm
node src/build.js                                   # analyse the latest balance patch (live data)
node src/serve.js                                   # open http://localhost:5178
node src/build.js --patch data/patches/notes.txt    # feed your own patch notes → forecast
node src/build.js --llm                             # + classify vague/rework lines with Claude
node src/build.js --offline                         # rebuild from cache
npm run pages                                       # rebuild + copy to docs/ for the GitHub Pages site
```

**Live dashboard:** https://kinetrafps.github.io/meta-unbound/ — a snapshot from the last `npm run pages` + push.

> Fan-made tool, not affiliated with or endorsed by Valve. Match data comes from the community API at [deadlock-api.com](https://deadlock-api.com); hero names and images belong to Valve.

## LLM pass (`--llm`)

The rule-based parser handles "X increased from A to B" well but guesses on qualitative lines ("now also disarms", reworks, interactions). With `--llm`, each patch's hero/item lines go to Claude (`claude-opus-5-5`, structured JSON output) and come back with a direction, magnitude, confidence and one-line reason per line.

* **Setup:** `npm install`, then set `ANTHROPIC_API_KEY` (or log in with `ant auth login`).
* **Policy** (`config.js` → `llm.mode`): `uncertain` (default) uses the LLM only where the rules were unsure (confidence < 0.7); `all` uses it for every hero/item line. Manual overrides still win over both.
* **Cost:** every patch in the timeline is classified once (so the backtest stays consistent), then cached in `data/llm-cache.json`. Re-runs make no API calls.
* **Is it worth it?** With `--llm` the Audit tab also replays the rules-only parser and shows both backtests side by side (r, direction accuracy, error), so you can see whether the LLM actually improves forecasts. Lines where the rules and the LLM disagree are listed there too.
* Requests use `fallbacks: "default"`, so if a safety classifier ever declines a request, the API retries it on a fallback model. If a request fails (bad key, outage), the run continues with rule-based verdicts and skips the LLM for the rest of that run.

## Overwatch

**Live:** https://kinetrafps.github.io/meta-unbound/overwatch/ — same design, switch games from the header.

```bash
node overwatch/build.js        # fetch stats + patch notes → dist-ow/ (served at /overwatch/ by node src/serve.js)
```

* **Data:** Blizzard's official Hero Statistics (win/pick/ban rate) via the community [OverFast API](https://overfast-api.tekrop.fr), competitive role queue, for every platform × region × rank (Bronze–Grandmaster) and per map; hero kits and perks from OverFast; patch notes and developer comments from Blizzard's patch-notes pages (Stadium-only changes excluded).
* **Views:** role-column tier board (tiers are relative within Tank / Damage / Support), win rate by rank, best maps per hero, strongest lineup per map, kit & perks, patch history with Blizzard's developer comments.
* **Patch impact:** each changed hero's patch-note forecast next to their current win rate, and the real before/after change once history exists. History comes from a daily snapshot (`.github/workflows/daily-refresh.yml` rebuilds and publishes both sites every day at 07:23 UTC; it never includes the personal-use matchups) plus copies of Blizzard's stats page from the Internet Archive (`overwatch/backfill.js`, Competitive copies only). After 12 measured hero changes, the forecast is backtested and shown in win-rate points, like Deadlock.
* **Limits:** no public source has Overwatch matchups, synergies or perk stats, and Blizzard publishes no game counts (rarely picked heroes are pulled toward 50% instead) or history. Each build saves a daily snapshot in `data/overwatch/snapshots/`; once snapshots straddle a patch, "since the patch" changes appear automatically.

### Overwatch matchups (personal copy only)

Counterwatch's hero-vs-hero counter ratings are allowed for personal, non-commercial use only, so they are **never on the public site**. Each person's local copy loads them automatically:

* **Windows:** double-click `start-local.cmd` (needs [Node.js](https://nodejs.org)). Anyone else: `npm start`.
* It updates the dashboards if they're more than a day old, starts the local server and opens http://localhost:5178/overwatch/.
* The server downloads the matchups in the background the first time (about a minute) and again whenever a new patch is out; the page shows "Loading matchups…" and fills in on its own. Keep the window open while you use the site.

Locally you get a **Matchups** tab: pick the enemy team and get the best answers per role (with heroes to avoid), each hero's "good against / struggles against" in plain words (Hard counter / Strong / Slight edge), and a full grid grouped by role. The data is stored in `data/overwatch/private/` (gitignored); `npm run pages` strips it and refuses to publish if any of it would slip through.

## What's in the dashboard

* **Meta** — tier board (or sortable table, or per-situation view) with risers, fallers and most-banned heroes since the patch. Filter by role, buffed/nerfed, or tag.
* **Hero pages** (`#/hero/<id>/build`, shareable) — meta build, why the hero is rated where they are, matchups, synergy and full patch history.
* **Meta builds** — for every hero, all ranks and Oracle+: core items in average buy order (timeline + per phase), hidden gems, traps, build identity (weapon/vitality/spirit share), and the most-played ability upgrade order. Items are judged against the hero's other items *of the same price tier*, because winning teams can afford more items and raw item win rates would mislead.
* **How to beat them** (hero pages) and **items to buy vs the enemy team** (Draft helper), from an E6 player's item matchup guide in `data/guides/deadlock-item-counters.json` (transcribed by KinetraFPS). Each recommended item gets a rough data check: its win rate in real games against that hero vs its usual win rate. Edit the JSON to add or correct entries.
* **Patch impact**, **Matchups** (clickable heatmap), **Draft helper**, **Audit** (backtest, disagreements, assumptions).
* Global hero search (press `/`), situation picker, light/dark toggle.

## How it works

```
deadlock-api.com ─┬─ hero / ban stats per situation (pre- and post-patch windows)
                  ├─ counters (full game + lane), synergies
                  └─ patch feed (Steam + forum)
                         │
patch notes ──► patchParser ──► signed changes ──► impact model (k fitted by backtest)
expert claims ─────────────────────────────────────┐          │
                                                   ▼          ▼
                     prior = pre-patch WR + patch forecast + expert shift
                     posterior = prior ⊕ post-patch games  (beta-binomial)
                                                   │
                     tiers · situations · lift · tags · disagreements ──► dist/
```

* **Bayesian blend.** Right after a patch the prior dominates; as games come in, real results take over. The "evidence mix" bar shows the split for each hero.
* **Patch forecast is backtested.** The parser's buff/nerf score is replayed against past patches to fit `k` (pp of win rate per unit of score). The Audit tab shows how accurate the forecast is — correlation, how often it got the direction right, and its error compared with assuming no change.
* **Situations.** All ranks, Oracle+, low ranks, short games, long games. Tags like *Late scaler* and *Skill-rewarding* come from those splits.
* **Lift, not raw win rate.** Matchup/synergy cells compare against what both heroes' overall strength predicts, shrunk for small samples.

## Your inputs

| File | Purpose |
|---|---|
| `data/patches/*.txt` | Paste patch notes (Valve's `- Hero: Ability - stat changed from X to Y` format) |
| `data/patch-overrides.json` | Correct a misread line: `{ "<line id or exact line>": { "direction": 1, "magnitude": 0.2 } }` |
| `data/experts/claims.json` | Coach/pro opinions: hero, rating −2..+2, source, date, optional context (see `claims.example.json`). Store paraphrases + links, not copied text |
| `data/theory.json` | Your own archetypes (e.g. `"dive": ["Abrams", ...]`) — feed tags and the archetype matrix |
| `config.js` | Every model knob; all are shown on the Audit tab |

## Known limits / next steps

* Without `--llm`, qualitative lines ("now also disarms") get small, low-confidence scores and reworks are flagged for review.
* Rank-filtered samples are much smaller (only matches with badge data for both teams).
* Situation splits apply the same patch forecast to every situation.
* Forecast mode overwrites `dist/`; re-run `node src/build.js` to return to live.
