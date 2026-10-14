# Split rules from snap-20261013T2253Z (Jacob via bd, 14 Oct; written by meiolol-33)

One global time split over every platform. No EUW1 slice, no platform-specific branch,
anywhere. Per-platform tables are description only, never a decision or a reading.

Universe
- Played game: stats.scan's rows (ranked solo, non-remake, complete roles) with
  duration_s >= 900. Only played games set the cuts, are fitted or are scored.
- Games under 900 s keep the window of their start time but are never fitted or scored.
- Order: (game_start, match_id) ascending. n = number of played games.

Cuts (computed once at the pin, written in model.md and split.tsv's header as ms)
- T (test cut) = game_start of the played game at sorted index n - round(0.15 n).
- D (dev cut) = game_start of the played game at sorted index n - round(0.25 n).
- Windows: test = start >= T; dev-val = D <= start < T; dev-visible = start < D.
  Ties at a cut go to the newer window (so a window may exceed its share by a few games).
- Folds: as now, on dev-visible played games sorted by start: b_k = start at index
  floor(len * (0.5 + 0.1 k)) for k = 0..4, b_5 = +inf. dev_old = start < b_0;
  fold k = b_{k-1} <= start < b_k.

Fits
- Fold k: played games with start < b_{k-1}. Dev-val: start < D. Test look (any --final):
  start < T. Shipped exports, after the look: every played game.
- Every tuning choice (L2, early stopping, profiles, norms) from the fit set only.

Code
- One shared function (harness) returns T, D and b_0..b_5 from rows.Data; every tool calls
  it: nnexport, winnet/netcheck, compcheck, effects, playernet, comps, carry (labCuts),
  pretrain, curve, stack, setnet. meiolol eval's eval.split uses the same rule (no
  test_platform). harness.cuts loses its eu argument; is_test = start >= T for every
  platform; Phase .select goes (or aliases .final).
- nn meta.json split codes keep their numbers (readers index split.u8 by code):
  0 dev_old, 1-5 fold1-5, 6 dev_val, 10 test; codes 7-9 (dev_val_other, selection,
  selection_other) stay in the names list and hold no games. Add "test_cut" and
  "dev_cut" to meta.json.
- split.tsv: every test game, all platforms (match_id, game_start, frames, reached15).
- nnexport's split test: bounds and windows equal across nnexport, harness, win-comp's
  blocks and compcheck, and no game in codes 7-9.

Reporting
- Folds pooled (5 blocks), dev-val, test: all-platform numbers only.
- Test looks ledgered in SNAP/test-looks.tsv, one per final model.
- Beside the pin in model.md: T, D, b_0..b_5, counts per window, patches per window, where
  2055Z's test games landed, and the leak note: fits for a window never see games at or
  after its cut (same-patch games on other platforms included).
