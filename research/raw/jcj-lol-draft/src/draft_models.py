"""
Draft-only win-probability models with a common interface:

    model.tune(train_df, val_df, weights)  -> picks hyperparameters on val, leaves the best fit in place
    model.refit(fit_df, weights)           -> refits with the chosen hyperparameters
    model.predict(df)                      -> P(blue wins) for each row

Every model is symmetric between the two teams: swapping blue and red turns P into 1 - P,
apart from a single learned blue-side advantage.
"""
from __future__ import annotations

import copy
import math
from dataclasses import dataclass

import numpy as np
import pandas as pd
import torch
import xgboost as xgb
from scipy import sparse
from sklearn.linear_model import LogisticRegression
from torch import nn

from src.draft_eval import compute_metrics
from src.draft_features import BLUE_COLS, LABEL_COL, RED_COLS, ROLES, DraftFeaturizer

SEED = 42


def _labels(df: pd.DataFrame) -> np.ndarray:
    return df[LABEL_COL].to_numpy().astype(np.float64)


def _weights(df: pd.DataFrame, w: np.ndarray | None) -> np.ndarray:
    return np.ones(len(df)) if w is None else np.asarray(w, dtype=np.float64)


class DraftModel:
    name = "model"

    def __init__(self) -> None:
        self.config: dict = {}

    def tune(self, train_df: pd.DataFrame, val_df: pd.DataFrame, w: np.ndarray | None = None) -> dict:
        raise NotImplementedError

    def refit(self, fit_df: pd.DataFrame, w: np.ndarray | None = None) -> None:
        raise NotImplementedError

    def predict(self, df: pd.DataFrame) -> np.ndarray:
        raise NotImplementedError


# ------------------------------ constant ------------------------------
class ConstantModel(DraftModel):
    """Always predicts the (weighted) blue-side win rate of the training data."""

    name = "constant"

    def tune(self, train_df, val_df, w=None):
        self.refit(train_df, w)
        return {}

    def refit(self, fit_df, w=None):
        self.p = float(np.average(_labels(fit_df), weights=_weights(fit_df, w)))

    def predict(self, df):
        return np.full(len(df), self.p)


# ------------------------------ logistic regression ------------------------------
class LogRegModel(DraftModel):
    """L2 logistic regression on the antisymmetric one-hot features from draft_features.py."""

    def __init__(
        self,
        groups: list[str],
        name: str | None = None,
        c_grid: tuple[float, ...] = (0.003, 0.01, 0.03, 0.1),
        pair_scale_grid: tuple[float, ...] = (0.25, 0.5, 1.0),
        min_pair_count: int = 10,
    ):
        super().__init__()
        self.groups = groups
        self.name = name or "logreg:" + "+".join(groups)
        self.c_grid = c_grid
        self.has_pairs = any(g in ("matchup", "synergy") for g in groups)
        self.pair_scale_grid = pair_scale_grid if self.has_pairs else (1.0,)
        self.min_pair_count = min_pair_count

    def _fit(self, df, w, C, pair_scale):
        feat = DraftFeaturizer(self.groups, self.min_pair_count, pair_scale).fit(df)
        model = LogisticRegression(C=C, max_iter=5000)
        model.fit(feat.transform(df), _labels(df), sample_weight=_weights(df, w))
        return feat, model

    def tune(self, train_df, val_df, w=None):
        best = None
        y_val = _labels(val_df)
        for pair_scale in self.pair_scale_grid:
            for C in self.c_grid:
                feat, model = self._fit(train_df, w, C, pair_scale)
                loss = compute_metrics(y_val, model.predict_proba(feat.transform(val_df))[:, 1])["log_loss"]
                if best is None or loss < best[0]:
                    best = (loss, C, pair_scale, feat, model)
        _, C, pair_scale, self.feat, self.model = best
        self.config = {"C": C, "pair_scale": pair_scale}
        return self.config

    def refit(self, fit_df, w=None):
        self.feat, self.model = self._fit(fit_df, w, self.config["C"], self.config["pair_scale"])

    def predict(self, df):
        return self.model.predict_proba(self.feat.transform(df))[:, 1]


# ------------------------------ gradient boosted trees ------------------------------
class XGBoostModel(DraftModel):
    """
    Boosted trees on the signed champion-in-role one-hot (+1 blue, -1 red). Trees can split on
    several champions at once, so they can learn matchups/synergies without pair features.
    Symmetry: train on every game twice (as played, and with teams swapped and the label
    flipped, marked by a side feature), and average both orientations at prediction time.
    """

    name = "xgboost"

    def __init__(self, depth_grid: tuple[int, ...] = (2, 4, 6), eta: float = 0.05, max_rounds: int = 3000):
        super().__init__()
        self.depth_grid = depth_grid
        self.eta = eta
        self.max_rounds = max_rounds

    def _matrix(self, df, side: float, flip: bool) -> sparse.csr_matrix:
        X = self.feat.transform(df)
        if flip:
            X = -X
        side_col = sparse.csr_matrix(np.full((X.shape[0], 1), side))
        return sparse.hstack([X, side_col]).tocsr()

    def _dtrain(self, df, w):
        y = _labels(df)
        X = sparse.vstack([self._matrix(df, 1.0, False), self._matrix(df, -1.0, True)]).tocsr()
        return xgb.DMatrix(X, label=np.concatenate([y, 1 - y]), weight=np.concatenate([_weights(df, w)] * 2))

    def _params(self, depth):
        return {
            "objective": "binary:logistic",
            "eval_metric": "logloss",
            "eta": self.eta,
            "max_depth": depth,
            "subsample": 0.8,
            "colsample_bytree": 0.8,
            "min_child_weight": 20,
            "lambda": 10.0,
            "tree_method": "hist",
            "seed": SEED,
        }

    def _predict_with(self, booster, df, rounds):
        it = (0, rounds)
        p_blue = booster.predict(xgb.DMatrix(self._matrix(df, 1.0, False)), iteration_range=it)
        p_red = booster.predict(xgb.DMatrix(self._matrix(df, -1.0, True)), iteration_range=it)
        return (p_blue + (1 - p_red)) / 2

    def tune(self, train_df, val_df, w=None):
        self.feat = DraftFeaturizer(["champ_role"]).fit(train_df)
        dtrain = self._dtrain(train_df, w)
        dval = xgb.DMatrix(self._matrix(val_df, 1.0, False), label=_labels(val_df))
        best = None
        for depth in self.depth_grid:
            booster = xgb.train(
                self._params(depth), dtrain, self.max_rounds,
                evals=[(dval, "val")], early_stopping_rounds=100, verbose_eval=False,
            )
            rounds = booster.best_iteration + 1
            loss = compute_metrics(_labels(val_df), self._predict_with(booster, val_df, rounds))["log_loss"]
            if best is None or loss < best[0]:
                best = (loss, depth, rounds, booster)
        _, depth, rounds, self.booster = best
        self.config = {"max_depth": depth, "rounds": rounds}
        return self.config

    def refit(self, fit_df, w=None):
        self.feat = DraftFeaturizer(["champ_role"]).fit(fit_df)
        self.booster = xgb.train(self._params(self.config["max_depth"]), self._dtrain(fit_df, w), self.config["rounds"])

    def predict(self, df):
        return self._predict_with(self.booster, df, self.config["rounds"])


# ------------------------------ neural models ------------------------------
class ChampionVocab:
    """Champion name -> integer id; id 0 is reserved for champions unseen in training."""

    def __init__(self, df: pd.DataFrame):
        champs = sorted(set(df[BLUE_COLS + RED_COLS].to_numpy().ravel()))
        self.to_id = {c: i + 1 for i, c in enumerate(champs)}
        self.size = len(champs) + 1

    def encode(self, df: pd.DataFrame) -> tuple[torch.Tensor, torch.Tensor]:
        def ids(cols):
            return torch.tensor(
                [[self.to_id.get(c, 0) for c in row] for row in df[cols].itertuples(index=False)],
                dtype=torch.long,
            )
        return ids(BLUE_COLS), ids(RED_COLS)


class SymmetricDraftNet(nn.Module):
    """
    logit = side_advantage + h(blue, red) - h(red, blue)
    h(us, them) = sum of champion-in-role strengths of `us` + interaction(us, them)

    The strength term is the same as the logistic regression; `interaction` is what each
    neural model adds on top.
    """

    def __init__(self, n_champs: int, interaction: nn.Module):
        super().__init__()
        self.side = nn.Parameter(torch.zeros(()))
        self.strength = nn.Embedding(n_champs * 5, 1)
        nn.init.zeros_(self.strength.weight)
        self.interaction = interaction
        self.register_buffer("role_ids", torch.arange(5))

    def h(self, us: torch.Tensor, them: torch.Tensor) -> torch.Tensor:
        strength = self.strength(us * 5 + self.role_ids).squeeze(-1).sum(1)
        return strength + self.interaction(us, them)

    def forward(self, blue: torch.Tensor, red: torch.Tensor) -> torch.Tensor:
        return self.side + self.h(blue, red) - self.h(red, blue)

    def penalty(self, lam_strength: float, lam_interaction: float) -> torch.Tensor:
        p = lam_strength * self.strength.weight.pow(2).sum()
        for param in self.interaction.parameters():
            if param.dim() >= 2:  # weights/embeddings, not biases or norm scales
                p = p + lam_interaction * param.pow(2).sum()
        return p


class FMInteraction(nn.Module):
    """
    Factorization-machine interactions. Each champion gets a small vector (plus a vector for its
    role); a pair's effect is computed from the two vectors, so rare pairs borrow strength from
    similar champions instead of needing their own games.
      synergy(us)       = sum over teammate pairs (i<j) of a_ij * <e_i, e_j>
      matchup(us, them) = sum over enemy pairs (i, j)  of b_ij * e_i^T K e_j
    a_ij / b_ij are learned weights per role pair (e.g. how much bot-lane pairs matter).
    """

    def __init__(self, n_champs: int, k: int):
        super().__init__()
        self.champ = nn.Embedding(n_champs, k)
        nn.init.normal_(self.champ.weight, std=0.01)
        self.role = nn.Parameter(torch.zeros(5, k))
        self.K = nn.Parameter(torch.eye(k) * 0.1)
        self.syn_w = nn.Parameter(torch.ones(5, 5))
        self.mu_w = nn.Parameter(torch.ones(5, 5))
        self.register_buffer("upper", torch.triu(torch.ones(5, 5), diagonal=1))

    def forward(self, us: torch.Tensor, them: torch.Tensor) -> torch.Tensor:
        e_us = self.champ(us) + self.role
        e_them = self.champ(them) + self.role
        syn = torch.einsum("nik,njk->nij", e_us, e_us)
        mu = torch.einsum("nik,kl,njl->nij", e_us, self.K, e_them)
        return (syn * self.syn_w * self.upper).sum((1, 2)) + (mu * self.mu_w).sum((1, 2))


class TransformerInteraction(nn.Module):
    """
    A small transformer over the 10 picks (champion + role + team embeddings, plus a summary
    [CLS] token). Self-attention lets every pick look at every other pick, so it can in
    principle learn any synergy/counter pattern; the [CLS] output is turned into one number.
    """

    def __init__(self, n_champs: int, d: int = 32, layers: int = 2, heads: int = 4, ff: int = 64, dropout: float = 0.1):
        super().__init__()
        self.champ = nn.Embedding(n_champs, d)
        self.role = nn.Embedding(5, d)
        self.team = nn.Embedding(2, d)
        self.cls = nn.Parameter(torch.zeros(1, 1, d))
        layer = nn.TransformerEncoderLayer(d, heads, ff, dropout, batch_first=True, norm_first=True)
        self.encoder = nn.TransformerEncoder(layer, layers, enable_nested_tensor=False)
        self.head = nn.Sequential(nn.LayerNorm(d), nn.Linear(d, 1))
        nn.init.zeros_(self.head[1].weight)
        nn.init.zeros_(self.head[1].bias)
        self.register_buffer("role_ids", torch.arange(5).repeat(2))
        self.register_buffer("team_ids", torch.tensor([0] * 5 + [1] * 5))

    def forward(self, us: torch.Tensor, them: torch.Tensor) -> torch.Tensor:
        picks = torch.cat([us, them], dim=1)
        x = self.champ(picks) + self.role(self.role_ids) + self.team(self.team_ids)
        x = torch.cat([self.cls.expand(x.size(0), -1, -1), x], dim=1)
        return self.head(self.encoder(x)[:, 0]).squeeze(-1)


@dataclass
class NetConfig:
    lam_interaction: float          # L2 strength for interaction weights, times 1/N
    k: int = 8                      # FM vector size / transformer width
    lr_strength: float = 1e-3       # strengths start at the logistic-regression fit, so only fine-tuned
    lr_interaction: float = 1e-2
    batch_size: int = 1024
    max_epochs: int = 60
    patience: int = 4
    lam_strength: float = 50.0      # times 1/N; equals sklearn C=0.01 for the strength term


class NeuralDraftModel(DraftModel):
    def __init__(self, kind: str, configs: list[NetConfig], name: str | None = None):
        super().__init__()
        if kind not in ("fm", "transformer"):
            raise ValueError(kind)
        self.kind = kind
        self.configs = configs
        self.name = name or kind

    def _build(self, cfg: NetConfig, n_champs: int) -> SymmetricDraftNet:
        torch.manual_seed(SEED)
        if self.kind == "fm":
            interaction = FMInteraction(n_champs, cfg.k)
        else:
            interaction = TransformerInteraction(n_champs, d=cfg.k)
        return SymmetricDraftNet(n_champs, interaction)

    def _train(self, cfg, df, w, val_df=None, epochs=None):
        """Train on df; early-stop on val_df if given, otherwise run exactly `epochs` epochs."""
        self.vocab = ChampionVocab(df)
        blue, red = self.vocab.encode(df)
        y = torch.tensor(_labels(df), dtype=torch.float32)
        weights = torch.tensor(_weights(df, w), dtype=torch.float32)
        weights = weights / weights.mean()
        n = len(df)

        net = self._build(cfg, self.vocab.size)
        self._warm_start(net, df, weights.numpy(), cfg)
        opt = torch.optim.Adam([
            {"params": [net.side, *net.strength.parameters()], "lr": cfg.lr_strength},
            {"params": net.interaction.parameters(), "lr": cfg.lr_interaction},
        ])
        bce = nn.BCEWithLogitsLoss(reduction="none")
        lam_s, lam_i = cfg.lam_strength / n, cfg.lam_interaction / n

        if val_df is not None:
            val_blue, val_red = self.vocab.encode(val_df)
            val_y = torch.tensor(_labels(val_df), dtype=torch.float32)

        def val_loss() -> float:
            net.eval()
            with torch.no_grad():
                return bce(net(val_blue, val_red), val_y).mean().item()

        gen = torch.Generator().manual_seed(SEED)
        # epoch 0 = the warm start (pure logistic regression); kept if interactions never help
        best = (val_loss(), 0, copy.deepcopy(net.state_dict())) if val_df is not None else (math.inf, 0, None)
        n_epochs = epochs if epochs is not None else cfg.max_epochs
        for epoch in range(1, n_epochs + 1):
            net.train()
            perm = torch.randperm(n, generator=gen)
            for start in range(0, n, cfg.batch_size):
                idx = perm[start:start + cfg.batch_size]
                # batch estimate of: mean loss over all games + L2 penalty
                loss = (bce(net(blue[idx], red[idx]), y[idx]) * weights[idx]).mean()
                loss = loss + net.penalty(lam_s, lam_i)
                opt.zero_grad()
                loss.backward()
                opt.step()

            if val_df is not None:
                loss_now = val_loss()
                if loss_now < best[0]:
                    best = (loss_now, epoch, copy.deepcopy(net.state_dict()))
                elif epoch - best[1] >= cfg.patience:
                    break

        if val_df is not None:
            net.load_state_dict(best[2])
            return net, best[1], best[0]
        return net, n_epochs, None

    def _warm_start(self, net: SymmetricDraftNet, df: pd.DataFrame, w: np.ndarray, cfg: NetConfig) -> None:
        """Set side advantage + strengths to the logistic regression with the same L2 penalty."""
        feat = DraftFeaturizer(["champ_role"]).fit(df)
        # mean loss + lam/N * |w|^2  <=>  sklearn C = 1 / (2 * lam)
        lr = LogisticRegression(C=1 / (2 * cfg.lam_strength), max_iter=5000)
        lr.fit(feat.transform(df), _labels(df), sample_weight=w)
        with torch.no_grad():
            net.side.fill_(float(lr.intercept_[0]))
            for (_, role, champ), j in feat.vocab.items():
                net.strength.weight[self.vocab.to_id[champ] * 5 + ROLES.index(role), 0] = float(lr.coef_[0, j])

    def tune(self, train_df, val_df, w=None):
        best = None
        for cfg in self.configs:
            net, epochs, val_loss = self._train(cfg, train_df, w, val_df=val_df)
            if best is None or val_loss < best[0]:
                best = (val_loss, cfg, epochs, net, self.vocab)
        _, self.cfg, self.epochs, self.net, self.vocab = best
        self.config = {**self.cfg.__dict__, "epochs": self.epochs}
        return self.config

    def refit(self, fit_df, w=None):
        self.net, _, _ = self._train(self.cfg, fit_df, w, epochs=self.epochs)

    def predict(self, df):
        blue, red = self.vocab.encode(df)
        self.net.eval()
        out = []
        with torch.no_grad():
            for start in range(0, len(df), 8192):
                out.append(torch.sigmoid(self.net(blue[start:start + 8192], red[start:start + 8192])))
        return torch.cat(out).numpy().astype(np.float64)


FM_CONFIGS = [
    NetConfig(lam_interaction=c, k=k, lr_interaction=1e-3, max_epochs=30, patience=5)
    for k in (4, 8) for c in (5.0, 20.0)
]
TRANSFORMER_CONFIGS = [
    NetConfig(lam_interaction=c, k=32, lr_interaction=1e-3, batch_size=512, max_epochs=30, patience=3)
    for c in (1.0, 5.0, 20.0)
]


def default_models(include_transformer: bool = True) -> list[DraftModel]:
    models: list[DraftModel] = [
        ConstantModel(),
        LogRegModel(["champ_role"], name="logreg_strength"),
        LogRegModel(["champ_role", "matchup", "synergy"], name="logreg_pairs"),
        NeuralDraftModel("fm", FM_CONFIGS, name="factorization_machine"),
        XGBoostModel(),
    ]
    if include_transformer:
        models.append(NeuralDraftModel(
            "transformer",
            TRANSFORMER_CONFIGS,
            name="transformer",
        ))
    return models
