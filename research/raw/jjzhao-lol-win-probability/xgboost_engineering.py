from pathlib import Path

import pandas as pd
import polars as pl

from common import (
    BASIC_STATS,
    COMBAT_DAMAGE_STATS,
    INHIB_LANES,
    OBJECTIVES,
    PER_ROLE_BREAKOUT,
    ROLES,
    TOWER_PARTS,
)
from logging_utils import run_with_file_logging
from db import get_engine, MATCH_SNAPSHOTS_TABLE


OUTPUT_FILE = Path("xgb_engineered/xgb_clean_dataset.parquet")

LOG_DIR = Path("logs")

# Stats app.py's custom-scenario sliders write to directly; these keep a
# team-level diff column in addition to their per-role diffs.
TEAM_LEVEL_STATS = {"total_gold", "xp", "minions_killed", "kills", "assists", "deaths"}


def _tower_diff_groups():
    """Map each output tower-diff column to the raw TOWER_PARTS columns it sums."""
    groups = {}
    for part in TOWER_PARTS:
        name = "nexus_towers" if part.startswith("nexus_tower") else part
        groups.setdefault(name, []).append(part)
    return groups


TOWER_DIFF_GROUPS = _tower_diff_groups()


def load_lazyframe():
    """Pull the raw match snapshots out of Postgres as a Polars LazyFrame."""
    engine = get_engine()
    df = pd.read_sql_table(MATCH_SNAPSHOTS_TABLE, engine)
    return pl.from_pandas(df).lazy()


def cols(lf):
    return set(lf.collect_schema().names())


def team_total(existing, team, stat):
    expr = pl.lit(0)

    for role in ROLES:
        col = f"{role}_{team}_{stat}"
        if col in existing:
            expr = expr + pl.col(col)

    return expr


def add_features(lf):
    """Per-role diffs for every basic stat, plus team-level diffs for
    TEAM_LEVEL_STATS and a combined damage-to-champions diff."""
    existing = cols(lf)

    exprs = [
        (pl.col("timestamp_sec") / 60).alias("minute"),
        pl.col("team_100_win").cast(pl.Int8).alias("target"),
    ]

    for stat in BASIC_STATS:
        if stat not in TEAM_LEVEL_STATS:
            continue

        team_100 = team_total(existing, 100, stat)
        team_200 = team_total(existing, 200, stat)
        exprs.append((team_100 - team_200).alias(f"team_{stat}_diff"))

    for role in PER_ROLE_BREAKOUT:
        for stat in BASIC_STATS:
            c100 = f"{role}_100_{stat}"
            c200 = f"{role}_200_{stat}"

            if c100 in existing and c200 in existing:
                exprs.append((pl.col(c100) - pl.col(c200)).alias(f"{role}_{stat}_diff"))

    damage_100 = pl.lit(0)
    damage_200 = pl.lit(0)

    for stat in COMBAT_DAMAGE_STATS:
        damage_100 = damage_100 + team_total(existing, 100, stat)
        damage_200 = damage_200 + team_total(existing, 200, stat)

    exprs.append((damage_100 - damage_200).alias("team_damage_done_to_champions_diff"))

    for obj in OBJECTIVES:
        c100 = f"{obj}_100"
        c200 = f"{obj}_200"

        if c100 in existing and c200 in existing:
            exprs.append((pl.col(c100) - pl.col(c200)).alias(f"{obj}_diff"))

    lf = lf.with_columns(exprs)

    return lf


def add_tower_features(lf):
    """One diff column per tower group, plus an aggregate tower_diff."""
    existing = cols(lf)

    part_exprs = []
    total_100 = pl.lit(0)
    total_200 = pl.lit(0)

    for name, parts in TOWER_DIFF_GROUPS.items():
        group_100 = pl.lit(0)
        group_200 = pl.lit(0)
        found = False

        for part in parts:
            c100 = f"{part}_100_destroyed"
            c200 = f"{part}_200_destroyed"

            if c100 in existing and c200 in existing:
                group_100 = group_100 + pl.col(c100)
                group_200 = group_200 + pl.col(c200)
                found = True

        if found:
            part_exprs.append((group_100 - group_200).alias(f"{name}_diff"))
            total_100 = total_100 + group_100
            total_200 = total_200 + group_200

    lf = lf.with_columns(part_exprs)
    lf = lf.with_columns((total_100 - total_200).alias("tower_diff"))

    return lf


def add_inhib_features(lf):
    """One diff column per lane inhibitor, plus an aggregate inhib_diff."""
    existing = cols(lf)

    lane_exprs = []
    total_100 = pl.lit(0)
    total_200 = pl.lit(0)

    for lane in INHIB_LANES:
        c100 = f"{lane}_inhib_100_destroyed"
        c200 = f"{lane}_inhib_200_destroyed"

        if c100 in existing and c200 in existing:
            lane_exprs.append((pl.col(c100) - pl.col(c200)).alias(f"{lane}_inhib_diff"))
            total_100 = total_100 + pl.col(c100)
            total_200 = total_200 + pl.col(c200)

    lf = lf.with_columns(lane_exprs)
    lf = lf.with_columns((total_100 - total_200).alias("inhib_diff"))

    return lf


def add_event_features(lf):
    """first_blood_diff / first_tower_diff only."""
    existing = cols(lf)

    exprs = []

    if "first_blood_team" in existing and "first_blood_time_sec" in existing:
        happened = pl.col("first_blood_time_sec") <= pl.col("timestamp_sec")
        got_it_100 = (happened & (pl.col("first_blood_team") == 100)).cast(pl.Int8)
        got_it_200 = (happened & (pl.col("first_blood_team") == 200)).cast(pl.Int8)
        exprs.append((got_it_100 - got_it_200).alias("first_blood_diff"))

    if "first_tower_team" in existing and "first_tower_time_sec" in existing:
        happened = pl.col("first_tower_time_sec") <= pl.col("timestamp_sec")
        got_it_100 = (happened & (pl.col("first_tower_team") == 100)).cast(pl.Int8)
        got_it_200 = (happened & (pl.col("first_tower_team") == 200)).cast(pl.Int8)
        exprs.append((got_it_100 - got_it_200).alias("first_tower_diff"))

    if exprs:
        lf = lf.with_columns(exprs)

    return lf


def add_momentum_features(lf):
    """3-minute momentum deltas, excluding event flags and per-part
    tower/inhib diffs (their aggregates already get a delta_3min)."""
    no_momentum = {"first_blood_diff", "first_tower_diff"}
    no_momentum |= {f"{name}_diff" for name in TOWER_DIFF_GROUPS}
    no_momentum |= {f"{lane}_inhib_diff" for lane in INHIB_LANES}

    feature_cols = [c for c in cols(lf) if c.endswith("_diff") and c not in no_momentum]

    lf = lf.sort(["match_id", "timestamp_sec"])

    exprs = [
        (pl.col(c) - pl.col(c).shift(3).over("match_id"))
        .fill_null(0)
        .alias(f"{c}_delta_3min")
        for c in feature_cols
    ]

    return lf.with_columns(exprs)


def select_output_columns(lf):
    existing = cols(lf)

    keep = [
        "match_id",
        "timestamp_sec",
        "minute",
        "target",
    ]

    feature_cols = [
        c for c in existing
        if c.endswith("_diff") or c.endswith("_delta_3min")
    ]

    keep = keep + sorted(feature_cols)

    return lf.select([c for c in keep if c in existing])


def main():
    print(f"Reading from database table: {MATCH_SNAPSHOTS_TABLE}")

    lf = load_lazyframe()

    required = {"match_id", "timestamp_sec", "team_100_win"}
    missing = required - cols(lf)

    if missing:
        raise ValueError(f"Missing required columns: {sorted(missing)}")

    lf = add_features(lf)
    lf = add_tower_features(lf)
    lf = add_inhib_features(lf)
    lf = add_event_features(lf)
    lf = add_momentum_features(lf)
    lf = select_output_columns(lf)

    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)

    print(f"Writing: {OUTPUT_FILE}")

    lf.collect().write_parquet(
        OUTPUT_FILE,
        compression="zstd",
        statistics=True,
    )

    print("Done.")


if __name__ == "__main__":
    run_with_file_logging(LOG_DIR, "xgboost_engineering", main)
