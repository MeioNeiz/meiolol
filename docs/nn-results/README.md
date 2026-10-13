# Neural net programme results

Read by the admin Models tab, "Neural nets" (src/site/static/admin-nn.js); sent by
deploy/lab-push.sh. One file per question, `<question>.tsv`, owned by the session working
on it (keys in use: nets comp pretrain stack scaling player context embx ldai gains effects).
Append a row when you write the result up in docs/model.md; edit a row when a rerun
replaces it. Commit the file by path with the model.md write-up.

First line `# title: <the question in plain words>`; other `#` lines are ignored. Then a
header and one row per comparison, tab-separated, blank cell for unknown:

- model: plain name ("big net, 3 seeds" not "netcheck --net big")
- vs: ratings (today's model), win-comp, base (champion win rates), or `-` for an
  absolute log loss (scaling curves)
- block: folds (the 5 forward folds pooled), dev-val, test (a test look, one per model,
  only on the coordinator's go), random (LoLDraftAI-style random split), projection
  (a scaling fit's prediction at fit_games)
- diff: log loss per game, model minus vs; negative is better. Absolute when vs is `-`
- ci: 95% half-width, paired per game (clustered by game)
- seeds: number of seeds averaged (1 for non-net models); seed_lo, seed_hi: the single
  seeds' diffs, lowest and highest
- games: scored games; fit_games: fit games, a count or a share like `25%` (the scaling
  chart's x)
- source: commit or run name; note: one plain sentence, optional
- learned: optional, a docs/learned.md line this row supports, named by its start
  (`2026-10-13: Knowing that a team's damage`); the page shows the lines named (once
  each) under the question and in "What we learnt". Add the column to the header when
  you first use it

The headline for a question (top of the page, All view card) is its first row compared
with ratings on the best block there is (test, then folds, then dev-val): put the
question's main answer first, a breakdown by subset after it.

The page labels each row from diff and ci: below zero by more than ci "better", above by
more than ci "worse", else "tie (not detected)".
