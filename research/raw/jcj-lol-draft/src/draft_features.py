"""
Draft-only features for linear win-probability models.

Every feature is antisymmetric: blue terms are +1 and red terms are -1. Swapping
the two teams negates the feature vector, so a logistic regression on these
features automatically satisfies P(blue wins) = 1 - P(red wins) apart from the
intercept, which absorbs the blue-side advantage. This replaces the canonical
team ordering used in clean_draft_dataset.py.

No player features (win rate, games played) are used anywhere in this module.
"""
from __future__ import annotations

from collections import Counter
from pathlib import Path

import numpy as np
import pandas as pd
from scipy import sparse

ROLES = ["top", "jg", "mid", "adc", "sup"]
BLUE_COLS = [f"blue_{r}" for r in ROLES]
RED_COLS = [f"red_{r}" for r in ROLES]
LABEL_COL = "blue_win"

# head-to-head pairs between enemy champions: (blue role, red role)
MATCHUP_PAIRS = [
    ("top", "top"),
    ("jg", "jg"),
    ("mid", "mid"),
    ("adc", "adc"),
    ("sup", "sup"),
    ("adc", "sup"),  # adc vs enemy support (also covers support vs enemy adc)
]

# same-team pairs
SYNERGY_PAIRS = [
    ("adc", "sup"),
    ("jg", "mid"),
    ("jg", "top"),
    ("jg", "sup"),
]

FEATURE_GROUPS = ["champ", "champ_role", "matchup", "synergy"]
PAIR_GROUPS = {"matchup", "synergy"}


# ------------------------------ loading ------------------------------
def load_raw_drafts(csv_path: str | Path, min_major_patch: int = 16) -> pd.DataFrame:
    """
    Load the raw (blue/red) dataset produced by build_draft_dataset.py, keeping only
    draft columns. Patch is read as a string: as a float, "16.1" and "16.10" collide.
    """
    keep = {"match_id", "source_platform", "patch", "game_creation", *BLUE_COLS, *RED_COLS, LABEL_COL}
    df = pd.read_csv(csv_path, usecols=lambda c: c in keep, dtype={"patch": str})

    df["patch_major"] = df["patch"].str.split(".").str[0].astype(int)
    df["patch_minor"] = df["patch"].str.split(".").str[1].astype(int)
    if "game_creation" in df.columns:
        # collect_drafts.py exports have a real timestamp
        df["time_order"] = df["game_creation"].astype(np.int64)
    else:
        # older datasets: match ids increase over time within a platform, e.g. NA1_5516057846
        df["time_order"] = df["match_id"].str.split("_").str[1].astype(np.int64)

    df = df[df["patch_major"] >= min_major_patch]
    df = df.drop_duplicates("match_id").reset_index(drop=True)
    return df


def time_split(
    df: pd.DataFrame,
    val_frac_of_second_latest: float = 0.4,
) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    """
    test  = the latest patch
    val   = the latest `val_frac_of_second_latest` of the second-latest patch, per platform
    train = everything earlier
    """
    patch_order = df[["patch_major", "patch_minor"]].drop_duplicates().sort_values(["patch_major", "patch_minor"])
    patches = [f"{a}.{b}" for a, b in patch_order.itertuples(index=False)]
    if len(patches) < 2:
        raise ValueError("Need at least two patches for a time-based split.")
    test_patch, val_patch = patches[-1], patches[-2]

    test_mask = df["patch"] == test_patch
    in_val_patch = df["patch"] == val_patch

    # rank games within each platform by time, newest last
    pct = df[in_val_patch].groupby("source_platform")["time_order"].rank(pct=True)
    val_mask = pd.Series(False, index=df.index)
    val_mask.loc[pct.index] = pct > (1.0 - val_frac_of_second_latest)

    train_mask = ~test_mask & ~val_mask
    return (
        df[train_mask].reset_index(drop=True),
        df[val_mask].reset_index(drop=True),
        df[test_mask].reset_index(drop=True),
    )


# ------------------------------ features ------------------------------
def draft_terms(
    blue: dict[str, str | None],
    red: dict[str, str | None],
    groups: list[str],
) -> list[tuple[tuple, float]]:
    """
    Return (feature key, value) terms for one draft.
    `blue` and `red` map role -> champion name. A missing (None) champion, e.g. a pick that has
    not happened yet, contributes no terms, i.e. it is treated like an average champion.
    """
    terms: list[tuple[tuple, float]] = []

    def add(key: tuple, value: float) -> None:
        if None not in key:
            terms.append((key, value))

    if "champ" in groups:
        for r in ROLES:
            add(("champ", blue.get(r)), 1.0)
            add(("champ", red.get(r)), -1.0)

    if "champ_role" in groups:
        for r in ROLES:
            add(("champ_role", r, blue.get(r)), 1.0)
            add(("champ_role", r, red.get(r)), -1.0)

    if "matchup" in groups:
        for r1, r2 in MATCHUP_PAIRS:
            if r1 == r2:
                # one key per unordered pair; sign says which side has the first champion
                a, b = blue.get(r1), red.get(r1)
                if a is None or b is None:
                    continue
                if a <= b:
                    add(("matchup", r1, r2, a, b), 1.0)
                else:
                    add(("matchup", r1, r2, b, a), -1.0)
            else:
                # ordered key (r1 champ, r2 champ); blue r1 vs red r2 is +1, red r1 vs blue r2 is -1
                add(("matchup", r1, r2, blue.get(r1), red.get(r2)), 1.0)
                add(("matchup", r1, r2, red.get(r1), blue.get(r2)), -1.0)

    if "synergy" in groups:
        for r1, r2 in SYNERGY_PAIRS:
            add(("synergy", r1, r2, blue.get(r1), blue.get(r2)), 1.0)
            add(("synergy", r1, r2, red.get(r1), red.get(r2)), -1.0)

    return terms


def row_teams(row) -> tuple[dict[str, str], dict[str, str]]:
    blue = {r: getattr(row, f"blue_{r}") for r in ROLES}
    red = {r: getattr(row, f"red_{r}") for r in ROLES}
    return blue, red


class DraftFeaturizer:
    """
    Builds a sparse design matrix from drafts. The vocabulary is fit on training rows;
    pair features seen fewer than `min_pair_count` times in training are dropped, and
    pair features are multiplied by `pair_scale` (a smaller scale means stronger
    effective L2 shrinkage for rare, noisy pair effects).
    """

    def __init__(self, groups: list[str], min_pair_count: int = 10, pair_scale: float = 1.0):
        unknown = set(groups) - set(FEATURE_GROUPS)
        if unknown:
            raise ValueError(f"Unknown feature groups: {unknown}")
        self.groups = groups
        self.min_pair_count = min_pair_count
        self.pair_scale = pair_scale
        self.vocab: dict[tuple, int] = {}
        self.counts: Counter = Counter()
        self.n_rows = 0

    def fit(self, df: pd.DataFrame) -> "DraftFeaturizer":
        counts: Counter = Counter()
        for row in df.itertuples(index=False):
            blue, red = row_teams(row)
            for key, _ in draft_terms(blue, red, self.groups):
                counts[key] += 1

        keys = [
            k for k, c in counts.items()
            if k[0] not in PAIR_GROUPS or c >= self.min_pair_count
        ]
        self.vocab = {k: i for i, k in enumerate(sorted(keys))}
        self.counts = counts
        self.n_rows = len(df)
        return self

    def transform_drafts(self, drafts: list[tuple[dict[str, str], dict[str, str]]]) -> sparse.csr_matrix:
        rows, cols, vals = [], [], []
        for i, (blue, red) in enumerate(drafts):
            for key, v in draft_terms(blue, red, self.groups):
                j = self.vocab.get(key)
                if j is None:
                    continue
                if key[0] in PAIR_GROUPS:
                    v *= self.pair_scale
                rows.append(i)
                cols.append(j)
                vals.append(v)
        return sparse.csr_matrix((vals, (rows, cols)), shape=(len(drafts), len(self.vocab)))

    def transform(self, df: pd.DataFrame) -> sparse.csr_matrix:
        return self.transform_drafts([row_teams(row) for row in df.itertuples(index=False)])

    def feature_names(self) -> list[tuple]:
        names = [None] * len(self.vocab)
        for k, i in self.vocab.items():
            names[i] = k
        return names
