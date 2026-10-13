"""
Compare draft-only models on one time-based split (test = latest patch), plus two experiments:

  1. Learning curves: train each model on 1/8, 1/4, 1/2 and all of the training games. If the
     models that learn matchups/synergies gain on the plain strength model as data grows,
     more data is worth collecting.
  2. Recency weighting: predict each of the last patches from the patches before it, with
     older patches down-weighted by gamma per patch. Does recent data matter more?

Run from the project root:
    python -m scripts.compare_models [--csv path] [--out dir] [--no-transformer]
"""
from __future__ import annotations

import argparse
import json
import time
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

from src.draft_eval import compute_metrics, paired_bootstrap_ci, per_row_log_loss
from src.draft_features import LABEL_COL, load_raw_drafts, time_split
from src.draft_models import (
    FM_CONFIGS,
    ConstantModel,
    LogRegModel,
    NeuralDraftModel,
    XGBoostModel,
    default_models,
)

DEFAULT_CSV = Path("data/processed/draft_dataset_multiregion_diamondplus_110000.csv")
DEFAULT_OUT = Path("outputs/model_comparison")
SEED = 42

CURVE_FRACTIONS = (0.125, 0.25, 0.5, 1.0)
CURVE_SEEDS = (0, 1)  # repeats for fractions < 1 (small subsets are noisy)
RECENCY_GAMMAS = (1.0, 0.7, 0.5, 0.3)
RECENCY_TARGETS = 3   # number of most recent patches to predict


def patch_key(patch: str) -> tuple[int, int]:
    major, minor = patch.split(".")
    return int(major), int(minor)


def curve_models() -> list:
    return [
        LogRegModel(["champ_role"], name="logreg_strength"),
        LogRegModel(["champ_role", "matchup", "synergy"], name="logreg_pairs"),
        NeuralDraftModel("fm", FM_CONFIGS, name="factorization_machine"),
        XGBoostModel(depth_grid=(2, 4)),
    ]


# ------------------------------ 1. main comparison ------------------------------
def run_main(train_df, val_df, test_df, include_transformer):
    trainval_df = pd.concat([train_df, val_df], ignore_index=True)
    y_val, y_test = val_df[LABEL_COL].to_numpy(), test_df[LABEL_COL].to_numpy()

    rows, configs, test_preds = [], {}, {}
    for model in default_models(include_transformer):
        t0 = time.time()
        configs[model.name] = model.tune(train_df, val_df)
        val_metrics = compute_metrics(y_val, model.predict(val_df))
        model.refit(trainval_df)
        p_test = model.predict(test_df)
        seconds = time.time() - t0

        test_preds[model.name] = p_test
        rows.append({"model": model.name, "split": "val", **val_metrics, "seconds": seconds})
        rows.append({"model": model.name, "split": "test", **compute_metrics(y_test, p_test), "seconds": seconds})
        print(f"  {model.name:<22} val {val_metrics['log_loss']:.5f} | test {rows[-1]['log_loss']:.5f} | {seconds:.0f}s | {configs[model.name]}")

    losses = {name: per_row_log_loss(y_test, p) for name, p in test_preds.items()}
    boot = []
    for name in losses:
        for ref in ("constant", "logreg_strength"):
            if name in ("constant", ref):
                continue
            mean, lo, hi = paired_bootstrap_ci(losses[ref], losses[name], SEED)
            boot.append({"model": name, "vs": ref, "log_loss_improvement": mean, "ci95_low": lo, "ci95_high": hi})
    return pd.DataFrame(rows), pd.DataFrame(boot), configs, test_preds


# ------------------------------ 2. learning curves ------------------------------
def run_learning_curves(train_df, val_df, test_df):
    y_test = test_df[LABEL_COL].to_numpy()
    rows = []
    for frac in CURVE_FRACTIONS:
        for seed in (CURVE_SEEDS if frac < 1 else CURVE_SEEDS[:1]):
            sub = train_df.sample(frac=frac, random_state=seed) if frac < 1 else train_df
            const = ConstantModel()
            const.tune(sub, val_df)
            const_loss = compute_metrics(y_test, const.predict(test_df))["log_loss"]
            for model in curve_models():
                model.tune(sub, val_df)
                loss = compute_metrics(y_test, model.predict(test_df))["log_loss"]
                rows.append({
                    "fraction": frac, "seed": seed, "train_games": len(sub), "model": model.name,
                    "test_log_loss": loss, "improvement_vs_constant": const_loss - loss,
                })
            print(f"  fraction {frac:<5} seed {seed}: done ({len(sub)} games)")
    return pd.DataFrame(rows)


# ------------------------------ 3. recency weighting ------------------------------
def run_recency(df, main_configs):
    patches = sorted(df["patch"].unique(), key=patch_key)
    targets = patches[-RECENCY_TARGETS:] if len(patches) > RECENCY_TARGETS else patches[1:]
    rows = []
    for target in targets:
        history = [p for p in patches if patch_key(p) < patch_key(target)]
        fit_df = df[df["patch"].isin(history)].reset_index(drop=True)
        eval_df = df[df["patch"] == target].reset_index(drop=True)
        y = eval_df[LABEL_COL].to_numpy()
        # distance 0 = the newest training patch
        distance = fit_df["patch"].map({p: len(history) - 1 - i for i, p in enumerate(history)}).to_numpy()

        for gamma in RECENCY_GAMMAS:
            w = gamma ** distance
            const = ConstantModel()
            const.refit(fit_df, w)
            const_loss = compute_metrics(y, const.predict(eval_df))["log_loss"]
            for name, groups in (("logreg_strength", ["champ_role"]), ("logreg_pairs", ["champ_role", "matchup", "synergy"])):
                model = LogRegModel(groups, name=name)
                model.config = main_configs[name]
                model.refit(fit_df, w)
                loss = compute_metrics(y, model.predict(eval_df))["log_loss"]
                rows.append({
                    "target_patch": target, "train_patches": f"{history[0]}-{history[-1]}",
                    "train_games": len(fit_df), "gamma": gamma, "model": name,
                    "log_loss": loss, "improvement_vs_constant": const_loss - loss,
                })
        print(f"  predicting {target} from {history[0]}-{history[-1]}: done")
    return pd.DataFrame(rows)


# ------------------------------ plots ------------------------------
def plot_learning_curves(curves: pd.DataFrame, out_path: Path) -> None:
    agg = curves.groupby(["model", "fraction"]).agg(
        train_games=("train_games", "mean"), gain=("improvement_vs_constant", "mean")
    ).reset_index()
    plt.figure(figsize=(7, 5))
    for name, g in agg.groupby("model"):
        g = g.sort_values("train_games")
        plt.plot(g["train_games"], g["gain"] * 1000, marker="o", label=name)
    plt.axhline(0, color="k", linewidth=0.8)
    plt.xscale("log")
    plt.xlabel("Training games (log scale)")
    plt.ylabel("Test log-loss improvement over constant (x1000)")
    plt.title("Learning curves (higher is better)")
    plt.legend(fontsize=8)
    plt.tight_layout()
    plt.savefig(out_path, dpi=150)
    plt.close()


def plot_calibration(preds: dict[str, np.ndarray], y: np.ndarray, out_path: Path, n_bins: int = 10) -> None:
    plt.figure(figsize=(6, 6))
    lo, hi = 1.0, 0.0
    for name, p in preds.items():
        bins = np.array_split(np.argsort(p), n_bins)
        xs, ys = [p[b].mean() for b in bins], [y[b].mean() for b in bins]
        lo, hi = min(lo, *xs, *ys), max(hi, *xs, *ys)
        plt.plot(xs, ys, marker="o", label=name)
    plt.plot([lo - 0.01, hi + 0.01], [lo - 0.01, hi + 0.01], "k--", linewidth=1, label="perfect")
    plt.xlabel("Mean predicted P(blue win), decile")
    plt.ylabel("Actual blue win rate")
    plt.title("Test calibration (equal-count deciles)")
    plt.legend(fontsize=8)
    plt.tight_layout()
    plt.savefig(out_path, dpi=150)
    plt.close()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=Path, default=DEFAULT_CSV)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--no-transformer", action="store_true", help="skip the (slowest) transformer model")
    parser.add_argument("--skip-curves", action="store_true")
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)

    df = load_raw_drafts(args.csv)
    train_df, val_df, test_df = time_split(df)
    print(f"{args.csv}: train {len(train_df)} | val {len(val_df)} | test {len(test_df)} (patch {test_df['patch'].iloc[0]})")

    print("\n[1/3] Main comparison")
    results, boot, configs, test_preds = run_main(train_df, val_df, test_df, not args.no_transformer)
    results.to_csv(args.out / "results.csv", index=False)
    boot.to_csv(args.out / "test_bootstrap.csv", index=False)
    (args.out / "configs.json").write_text(json.dumps(configs, indent=2, default=str))
    plot_calibration({k: v for k, v in test_preds.items() if k != "constant"}, test_df[LABEL_COL].to_numpy(), args.out / "test_calibration_deciles.png")

    if not args.skip_curves:
        print("\n[2/3] Learning curves")
        curves = run_learning_curves(train_df, val_df, test_df)
        curves.to_csv(args.out / "learning_curves.csv", index=False)
        plot_learning_curves(curves, args.out / "learning_curves.png")

    print("\n[3/3] Recency weighting")
    recency = run_recency(df, configs)
    recency.to_csv(args.out / "recency.csv", index=False)

    with pd.option_context("display.width", 200, "display.float_format", lambda v: f"{v:.5f}"):
        print("\n=== Test results ===")
        print(results[results["split"] == "test"].drop(columns="split").to_string(index=False))
        print("\n=== Test log-loss improvement, paired bootstrap 95% CI (positive = better) ===")
        print(boot.to_string(index=False))
        if not args.skip_curves:
            print("\n=== Learning curves: mean improvement vs constant (x1000) ===")
            print((curves.groupby(["fraction", "model"])["improvement_vs_constant"].mean().unstack() * 1000).to_string())
        print("\n=== Recency: improvement vs constant (x1000), by gamma ===")
        print((recency.groupby(["model", "gamma"])["improvement_vs_constant"].mean().unstack() * 1000).to_string())
    print(f"\nSaved outputs to {args.out.resolve()}")


if __name__ == "__main__":
    main()
