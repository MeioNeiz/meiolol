//! Admin Models tab data (private), ui.data encoded: models.bin, the box's eval digest each
//! web round (src/adminmodels.zig), and the lab view the Mac uploads to /admin/training/
//! (`meiolol admin --training`, deploy/lab-push.sh): training.bin and each run's
//! runs/<run>/metrics.bin. Numbers the views say in words are read from the docs and TSVs
//! here, server side, so the island parses nothing
const std = @import("std");
const prose = @import("prose.zig");
const ad = @import("admindata.zig");

/// An estimate and its 95% half-width
pub const Pm = struct { mean: f32, ci: f32 };

/// docs/learned.md's ## headings that name a category
pub const Cat = enum(u8) { win, early, items, objectives, playstyle, player, data };

/// One row of the report's "Full draft, held-out games" table. acc: a share (0.557).
/// d: log loss against the shipped model on the same games, null for itself
pub const Model = struct { label: []const u8, ll: f32, acc: f32, auc: ?f32 = null, d: ?Pm = null };

/// Calibration: a tenth of the games by prediction, both in percent
pub const Decile = struct { predicted: f32, won: f32, games: u32 };

/// Log loss by training games on fixed test games, a column per model
pub const Curve = struct {
    cols: []const []const u8,
    games: []const u32,
    /// [size][col]
    ll: []const []const ?f32,
    /// Champion win rates' log loss gain per doubling over the largest four sizes, and
    /// their log loss at the largest
    per_doubling: ?f32 = null,
    last: f32 = 0,
};

/// eval-latest.md's numbers for the Win view. Indexes point into models
pub const Win = struct {
    games: u32,
    models: []const Model,
    /// "current model", else the lowest log loss that isn't a coin flip
    shipped: ?u16 = null,
    /// "champion base only"
    base: ?u16 = null,
    /// "current model"
    current: ?u16 = null,
    /// The best other model when it beats the shipped one
    experiment: ?u16 = null,
    deciles: []const Decile = &.{},
    /// Win rate (a share) and count of the shipped model's top-10% picks
    picks: ?struct { p: f32, n: u32 } = null,
    curve: ?Curve = null,
    /// "Player experience", history of the user only: the difference and effect per bin
    experience: ?struct { d: Pm, bins: []const f32 } = null,
    /// "Lane gold at 14 minutes": lane gold stacked on EB, and EB
    gold: ?[2]Model = null,
    /// Tuned term weights (1 = default)
    lane_weight: ?f32 = null,
    duo_weight: ?f32 = null,
};

/// models.bin
pub const Models = struct {
    now: i64,
    eval: []const ad.EvalRow,
    win: ?Win,
    report: prose.Doc,
    /// Matches stored a day over the newest week (admin-history.tsv)
    matches_per_day: ?f32,
};

pub const Host = enum(u8) { mac, gpu_box };
pub const State = enum(u8) { running, paused, stopped, finished, failed, died, other };
pub const Kind = enum(u8) { run, diagnose, screen, preds, other };
/// What the held-back selection games said
pub const Select = enum(u8) { none, new_best, no_change };

/// meiolol-lab's RESULT line (runs.tsv `last`)
pub const LabResult = struct {
    kind: Kind,
    /// Squared error against the baseline in the role's standard deviations; ci 0: a
    /// reference run, the baseline against itself
    dev: ?Pm = null,
    bias: ?Pm = null,
    select: Select = .none,
    /// screen: candidate inputs, and those clear of noise
    features: ?u32 = null,
    clear: ?u32 = null,
    /// preds: rows written
    rows: ?u64 = null,
};

/// result.tsv: removed is the % of the baseline's error removed; err_* the typical miss
/// in `unit`
pub const Result = struct {
    removed: ?Pm = null,
    err_base: ?f32 = null,
    err_cand: ?f32 = null,
    unit: []const u8 = "",
    select: Select = .none,
};

pub const EffectRow = struct { label: []const u8, value: f32, ci: f32, n: ?u32 = null };

/// An effects-*.tsv file: "# title | unit | what higher means", then a row per label
pub const Effect = struct { name: []const u8, title: []const u8, unit: []const u8, higher: []const u8, rows: []const EffectRow };

/// findings.tsv: a plain sentence and the effect file it rests on (index into effects)
pub const Finding = struct { campaign: []const u8, text: []const u8, effect: ?u16 = null };

pub const Run = struct {
    run: []const u8,
    state: State,
    /// Exit code when failed
    code: i32 = 0,
    started: ?i64 = null,
    ended: ?i64 = null,
    args: []const u8 = "",
    head: []const u8 = "",
    dirty: []const u8 = "",
    /// Its log's last line
    last: []const u8 = "",
    host: Host = .mac,
    cat: ?Cat = null,
    /// gold14, win, ... ("" when unknown)
    target: []const u8 = "",
    campaign: []const u8 = "",
    /// `exp ...`: a lab campaign's run
    lab: bool = false,
    /// train-demo: random curves, not a model
    synthetic: bool = false,
    res: ?LabResult = null,
    result: ?Result = null,
    findings: []const Finding = &.{},
    effects: []const Effect = &.{},
    /// runs/<run>/metrics.bin is there
    metrics: bool = false,
};

/// A learned.md item; short: its first sentence, before the evidence
pub const Learned = struct { cat: Cat, line: prose.Line, short: prose.Line };

pub const HypStatus = enum(u8) { reference, confirmed, refuted, parked, superseded, rejected, other };
pub const Hyp = struct { id: []const u8, status: HypStatus, word: []const u8, text: []const u8 };

pub const Campaign = struct {
    name: []const u8,
    /// Distinct runs it tagged or its hypotheses name
    runs: u32,
    new_best: u32,
    hyps: []const Hyp,
    /// null when it holds only headings
    digest: ?prose.Doc,
};

/// model.md's "Team effects on early outcomes" table: % of each outcome's variation each
/// step adds beyond the ones above it, and the total
pub const TeamEffects = struct {
    title: []const u8,
    outcomes: []const []const u8,
    steps: []const []const u8,
    /// [step][outcome]
    cells: []const []const ?Pm,
    total: []const ?Pm,
};

/// A docs/nn-results row: diff is log loss per game against `vs`, "-" for an absolute
/// log loss (the scaling file)
pub const NnRow = struct {
    model: []const u8,
    vs: []const u8,
    block: []const u8,
    diff: f32,
    ci: ?f32 = null,
    seeds: ?u32 = null,
    seed_lo: ?f32 = null,
    seed_hi: ?f32 = null,
    games: ?u64 = null,
    fit_games: []const u8 = "",
    source: []const u8 = "",
    note: []const u8 = "",
    /// The learned.md items its learned cell names (indexes into learned)
    learned: []const u16 = &.{},
};

pub const NnFile = struct { key: []const u8, title: []const u8, rows: []const NnRow };

/// training.bin
pub const Training = struct {
    /// The gpu-box last reached (the Mac reaches it on the home network only)
    gpu_seen: ?i64,
    /// Newest first
    runs: []const Run,
    learned: []const Learned,
    campaigns: []const Campaign,
    team: ?TeamEffects,
    nn: []const NnFile,
};

/// runs/<run>/metrics.bin: metrics.tsv, the first column the x axis; NaN where empty
pub const Metrics = struct { cols: []const []const u8, rows: []const []const f32 };
