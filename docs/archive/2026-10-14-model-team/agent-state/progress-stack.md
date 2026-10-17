# progress: stack (meiolol-97, session 93eff8bf)

Code: src/lab/stack.zig (uncommitted in main; lab_main.zig wiring blocked by another
session's uncommitted embfiles edits). Build tree: scratchpad of 93eff8bf, `tree/` (git
archive of HEAD a75878b + stack.zig + lab_main wiring, own throwaway git repo); run
lab-run from there with PATH=~/.local/bin first. Inputs copied to tree/stkin: f1/0a's
data/netcheck/f1/{m-big,w-big,x-resid,m-small}/preds.tsv, 52's data/pretrain/d12/preds.tsv.

Method: forward fit (fold k from folds < k, dev-val from folds 1-5), fold 1 unscored for
fitted rows; paired per game vs ratings and win-comp; permuted-input control.

| run | question | status | result |
| --- | --- | --- | --- |
| 214137Z-stk-all | first look, vs ratings | done | stacker folds2-5 -0.00079 ± 0.00047, dev +0.00009 ± 0.00070; avg -0.00040 ± 0.00013 / -0.00006 ± 0.00020; temps ratings ~0.8, gain ~0 |
| 215044Z-stk-all2 | vs ratings and win-comp | done | stacker vs comp -0.00034 ± 0.00035 (folds), -0.00021 ± 0.00044 dev: not detected |
| stk-perm1/2 | control: other inputs shuffled | done | +0.00005, +0.00010: no leak |
| stk-seed1/2/3 | seed spread | done | vs ratings -0.00052/-0.00061/-0.00082 |
| stk-sub | 4 inputs | done | stacker same as 6; average -0.00061 ± 0.00019 vs ratings |
| stk-l2 | L2 0.01 | done | worse (-0.00034) |
| 220120Z-stk-gb (+shy1/2) | 7 inputs incl. f7 win-exp, GBDT with compcheck profiles | done | stacker vs win-exp -0.00049 ± 0.00046 / dev -0.00005; trees worse than win-exp; shuffled-y worse, never better |

Written up: model.md 'Stacking, calibration and trees' + nn-results/stack.tsv (9522113).
Code committed 2840bce (stack.zig, gbdt.zig, lab_main wiring). Test look: no (coordinator, noise floor). Closed. Open for a successor: 4b audit; rerun on 0a sweep ensemble and f7 350k win-exp when they land.
