# scripts/match-prediction/validation.py
# TODO: needs to be updated for new model architecture
import argparse
import json
import pickle
import os
from sklearn.preprocessing import LabelEncoder
from collections import defaultdict
from typing import Dict, List, Callable, Any, Tuple

import pandas as pd
import torch
from torch import nn
from torch.utils.data import DataLoader
from tqdm import tqdm
import numpy as np
from sklearn.calibration import calibration_curve  # Added for ECE calculation
import matplotlib.pyplot as plt  # Added for plotting
import matplotlib

matplotlib.use("Agg")  # Use non-interactive backend

from utils.match_prediction import (
    get_best_device,
    MODEL_PATH,
    TRAIN_BATCH_SIZE,
    CHAMPION_ID_ENCODER_PATH,
    PATCH_MAPPING_PATH,
    load_model_state_dict,
)
from utils.match_prediction.config import TrainingConfig
from utils.match_prediction.match_dataset import MatchDataset
from utils.match_prediction.model import Model
from utils.match_prediction.train_utils import collate_fn
from utils.match_prediction.task_definitions import TaskDefinition, TaskType
from utils import DATA_DIR, champion_play_rates_path
from utils.match_prediction.champions import Champion  # Added for champion name lookup


class FixedMaskCount:
    """Returns a fixed number of champions to mask."""

    def __init__(self, count: int):
        self.count = count

    def __call__(self) -> int:
        return self.count


def get_elo_subgroup(feature: torch.Tensor) -> str:
    """
    Determine the ELO subgroup for a sample based on its ELO feature.

    Parameters:
        feature (torch.Tensor): ELO feature for the sample (scalar tensor).

    Returns:
        str: Subgroup name.
    """
    # feature: scalar tensor
    elo = feature.item()
    subgroup_name = f"elo_{elo}"
    return subgroup_name


with open(CHAMPION_ID_ENCODER_PATH, "rb") as f:
    champion_id_encoder: LabelEncoder = pickle.load(f)["mapping"]

with open(PATCH_MAPPING_PATH, "rb") as f:
    patch_mapping = pickle.load(f)["mapping"]

reverse_patch_mapping = {v: k for k, v in patch_mapping.items()}


def get_patch_subgroup(feature: torch.Tensor) -> str:
    """
    Assign a subgroup based on the patch number.
    """
    patch_number = feature.item()
    subgroup_name = f"patch_{patch_number}"
    return subgroup_name


def get_playrate_subgroup_batch(
    champion_ids_batch: torch.Tensor,  # Shape: [batch_size, 10]
    play_rates: Dict[str, Dict[str, Dict[str, float]]],
    patches_batch: torch.Tensor,  # Shape: [batch_size]
) -> List[str]:
    """
    Vectorized version that processes entire batch at once.
    """
    batch_size = champion_ids_batch.shape[0]

    # global play rate buckets
    play_rate_buckets = [
        (0.01, "almost_never"),
        (0.05, "ultra_rare"),
        (0.1, "very_rare"),
        (0.5, "rare"),
        (1.0, "quite_rare"),
        (5.0, "moderately_common"),
        (10.0, "common"),
        (100.0, "very_common"),
    ]
    role_names = ["TOP", "JUNGLE", "MIDDLE", "BOTTOM", "UTILITY"]

    # Convert champion IDs for entire batch at once
    champion_ids_flat = champion_ids_batch.view(-1)  # Shape: [batch_size * 10]
    champion_original_ids = champion_id_encoder.inverse_transform(
        champion_ids_flat.cpu().numpy()
    )

    # Initialize play rate tensor
    play_rates_tensor = torch.ones(
        batch_size, 10, dtype=torch.float32
    )  # Shape: [batch_size, 10]

    patches = patches_batch.cpu().numpy()
    for b in range(batch_size):
        patch = reverse_patch_mapping[patches[b]]
        for pos in range(10):
            champ_name = champion_original_ids[b * 10 + pos]
            role = role_names[pos % 5]
            play_rates_tensor[b, pos] = (
                play_rates.get(patch, {}).get(champ_name, {}).get(role, 0.0)
            )

    # Ensure minimum play rate and find minimum per sample
    play_rates_tensor = torch.maximum(play_rates_tensor, torch.tensor(1e-7))
    min_play_rates, _ = play_rates_tensor.min(dim=1)  # Shape: [batch_size]

    # Vectorized bucket assignment
    result = []
    for min_rate in min_play_rates.cpu().numpy():
        for threshold, bucket_name in play_rate_buckets:
            if min_rate <= threshold:
                result.append(f"playrate_{bucket_name}")
                break
        else:
            result.append("playrate_unknown")

    return result


def compute_ece(y_true, y_prob, n_bins=20, strategy="quantile"):
    """
    Compute Expected Calibration Error (ECE).

    Parameters:
        y_true: Ground truth binary labels
        y_prob: Predicted probabilities
        n_bins: Number of bins for calibration (default: 20)
        strategy: Binning strategy ('uniform' or 'quantile', default: 'quantile')

    Returns:
        ece: Expected Calibration Error
        prob_true: True probabilities per bin
        prob_pred: Predicted probabilities per bin
        bins: Bin edges
    """
    # Get true and predicted probabilities for bins
    prob_true, prob_pred = calibration_curve(
        y_true, y_prob, n_bins=n_bins, strategy=strategy
    )

    # Get bin ids
    if strategy == "quantile":
        quantiles = np.linspace(0, 1, n_bins + 1)
        bins = np.percentile(y_prob, quantiles * 100)
    elif strategy == "uniform":
        bins = np.linspace(0.0, 1.0, n_bins + 1)
    else:
        raise ValueError("Invalid binning strategy.")

    bin_ids = np.searchsorted(bins[1:-1], y_prob)
    bin_total = np.bincount(bin_ids, minlength=n_bins)

    # Only consider non-empty bins
    # Note: prob_true and prob_pred come from calibration_curve and already
    # have the same length, which might be different from bin_total
    # if some bins are empty.
    nonzero = bin_total != 0

    # Calculate ECE directly without using nonzero indexing on prob arrays
    if len(prob_true) != len(bin_total):
        # If lengths don't match, we can't use the same mask
        # This happens when sklearn.calibration_curve already filtered out empty bins
        weights = bin_total / np.sum(bin_total)
        weights = weights[nonzero]  # Only consider non-empty bins
        ece = np.sum(np.abs(prob_pred - prob_true) * (weights / np.sum(weights)))
    else:
        # Lengths match, we can safely use the mask
        weights = bin_total[nonzero] / np.sum(bin_total[nonzero])
        ece = np.sum(np.abs(prob_pred[nonzero] - prob_true[nonzero]) * weights)

    return ece, prob_true, prob_pred, bins


def plot_calibration_curve(prob_true, prob_pred, bins, title, output_path):
    """
    Plot reliability diagram (calibration curve).

    Parameters:
        prob_true: True probabilities per bin
        prob_pred: Predicted probabilities per bin
        bins: Bin edges
        title: Plot title
        output_path: Path to save the plot
    """
    plt.figure(figsize=(10, 8))

    # Plot the perfectly calibrated line
    plt.plot(
        [0, 1], [0, 1], linestyle="--", label="Perfectly calibrated", color="black"
    )

    # Plot model calibration based on available data
    if len(prob_true) != len(bins) - 1:
        # When calibration_curve returns fewer bins than requested (due to empty bins)
        plt.plot(prob_pred, prob_true, marker="o", linewidth=2, label="Model")
    else:
        # Normal case when all bins have data
        bin_centers = (bins[:-1] + bins[1:]) / 2
        plt.plot(bin_centers, prob_true, marker="o", linewidth=2, label="Model")

    # Add scatter points for visibility
    plt.scatter(prob_pred, prob_true, alpha=0.5, color="red")

    # Set labels, title, and formatting
    plt.xlabel("Predicted probability")
    plt.ylabel("True probability (fraction of positives)")
    plt.title(title)
    plt.legend(loc="best")
    plt.grid(True)
    plt.xlim([0, 1])
    plt.ylim([0, 1])

    # Save and close
    plt.tight_layout()
    plt.savefig(output_path)
    plt.close()


def plot_ece_by_bucket(prob_true, prob_pred, bins, ece, n_samples, output_path):
    """
    Plot ECE by bucket showing the calibration gap for each bucket.

    Parameters:
        prob_true: True probabilities per bin
        prob_pred: Predicted probabilities per bin
        bins: Bin edges
        ece: Overall ECE value
        n_samples: Number of samples
        output_path: Path to save the plot
    """
    plt.figure(figsize=(12, 8))

    # Calculate bin centers based on available data
    bin_centers = (
        prob_pred if len(prob_true) != len(bins) - 1 else (bins[:-1] + bins[1:]) / 2
    )

    # Calculate calibration error per bin
    calibration_error = np.abs(prob_true - bin_centers)

    # Create bar plot of calibration error
    plt.bar(
        bin_centers,
        calibration_error,
        width=0.05,
        alpha=0.7,
        label="|Expected - Observed|",
        color="orangered",
    )

    # Add annotations showing the error for significant values
    for i, (x, y) in enumerate(zip(bin_centers, calibration_error)):
        if y > 0.01:  # Only annotate if error is significant
            plt.annotate(
                f"{y:.3f}",
                xy=(x, y),
                xytext=(0, 5),
                textcoords="offset points",
                ha="center",
            )

    # Add a reference line at 0
    plt.axhline(y=0, color="black", linestyle="-", alpha=0.3)

    # Set labels and title
    plt.xlabel("Predicted Probability")
    plt.ylabel("Calibration Error")
    plt.title(f"Expected Calibration Error by Bucket (ECE={ece:.4f}, n={n_samples})")
    plt.legend()
    plt.grid(True, alpha=0.3)
    plt.xlim([0, 1])

    # Save the plot
    plt.tight_layout()
    plt.savefig(output_path)
    plt.close()


def plot_matchup_calibration(matchup_data, output_dir, min_samples=30, n_bins=10):
    """
    Create calibration plots for individual champions, combining all their matchups.

    Parameters:
        matchup_data: Dictionary containing matchup-specific prediction data
        output_dir: Directory to save plots
        min_samples: Minimum number of samples required for a matchup
        n_bins: Number of bins for calibration
    """
    # Create directory structure
    os.makedirs(output_dir, exist_ok=True)

    # Track results
    champion_data = {}
    matchup_ece_data = {
        "matchup": [],
        "samples": [],
        "ece": [],
    }

    # Filter matchups with enough samples
    valid_matchups = {
        k: v for k, v in matchup_data.items() if len(v["true"]) >= min_samples
    }

    print(f"Processing data for {len(valid_matchups)} matchups...")

    # First pass: Calculate ECE for each matchup and group by champion
    for matchup, data in tqdm(valid_matchups.items(), desc="Calculating matchup ECE"):
        try:
            # Extract and validate data
            true_vals = np.array(data["true"])
            pred_vals = np.array(data["pred"])

            # Skip if insufficient variation in data
            if len(np.unique(true_vals)) <= 1 or len(np.unique(pred_vals)) <= 1:
                continue

            # Compute calibration
            ece, prob_true, prob_pred, bins = compute_ece(
                true_vals, pred_vals, n_bins=n_bins, strategy="uniform"
            )

            # Store data for summary
            matchup_ece_data["matchup"].append(matchup)
            matchup_ece_data["samples"].append(len(true_vals))
            matchup_ece_data["ece"].append(ece)

            # Parse matchup key to get champion and role
            parts = matchup.split("_vs_")
            first_part = parts[0].split("_")
            champion_id = int(first_part[0])
            role = "_".join(first_part[1:])

            # Create champion key
            champion_key = f"{champion_id}_{role}"

            # Initialize champion data if needed
            if champion_key not in champion_data:
                champion_data[champion_key] = {
                    "matchups": [],
                    "samples": [],
                    "ece_values": [],
                    "true_all": [],
                    "pred_all": [],
                }

            # Store the matchup info
            champion_data[champion_key]["matchups"].append(matchup)
            champion_data[champion_key]["samples"].append(len(true_vals))
            champion_data[champion_key]["ece_values"].append(ece)
            champion_data[champion_key]["true_all"].extend(true_vals)
            champion_data[champion_key]["pred_all"].extend(pred_vals)

        except Exception as e:
            print(f"Error processing {matchup}: {str(e)}")

    # Second pass: Create one plot per champion
    print(f"Generating plots for {len(champion_data)} champions...")
    for champion_key, data in tqdm(
        champion_data.items(), desc="Generating champion plots"
    ):
        try:
            # Parse champion key
            parts = champion_key.split("_")
            champion_id = int(parts[0])
            role = "_".join(parts[1:])

            # Get champion name
            try:
                original_champ_id = int(
                    champion_id_encoder.inverse_transform([champion_id])[0]
                )
                champion_name = get_champion_name(original_champ_id)
            except:
                champion_name = f"Unknown_{champion_id}"

            # Calculate overall calibration for this champion
            true_all = np.array(data["true_all"])
            pred_all = np.array(data["pred_all"])
            total_samples = len(true_all)

            ece_overall, prob_true, prob_pred, bins = compute_ece(
                true_all, pred_all, n_bins=n_bins, strategy="uniform"
            )

            # Create plot filename
            safe_champ_name = champion_name.replace(" ", "_").replace("/", "_")
            output_path = os.path.join(
                output_dir, f"{safe_champ_name}_{role}_calibration.png"
            )

            # Create figure with subplots
            fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(20, 8))

            # Plot 1: Calibration curve
            ax1.plot(
                [0, 1],
                [0, 1],
                linestyle="--",
                label="Perfectly calibrated",
                color="black",
            )
            ax1.plot(
                prob_pred, prob_true, marker="o", linewidth=2, label="All matchups"
            )

            # Add title and labels
            ax1.set_title(
                f"Calibration for {champion_name} ({role})\nSamples: {total_samples}, ECE: {ece_overall:.4f}"
            )
            ax1.set_xlabel("Predicted probability")
            ax1.set_ylabel("True probability")
            ax1.grid(True)
            ax1.legend()

            # Plot 2: ECE by matchup
            # Only include top 15 matchups if there are many
            matchups = data["matchups"]
            samples = data["samples"]
            ece_values = data["ece_values"]

            if len(matchups) > 15:
                # Sort by ECE and take top 15
                indices = np.argsort(ece_values)[-15:]
                matchups = [matchups[i] for i in indices]
                samples = [samples[i] for i in indices]
                ece_values = [ece_values[i] for i in indices]

            # Convert matchup IDs to readable names for display
            readable_matchups = [
                convert_matchup_key_to_readable(m).split("_vs_")[1] for m in matchups
            ]

            # Create bar chart
            bars = ax2.bar(range(len(readable_matchups)), ece_values, alpha=0.7)

            # Add sample annotations
            for i, (bar, sample_count) in enumerate(zip(bars, samples)):
                ax2.text(
                    bar.get_x() + bar.get_width() / 2,
                    bar.get_height() + 0.01,
                    f"n={sample_count}",
                    ha="center",
                    va="bottom",
                    rotation=90,
                    fontsize=8,
                )

            # Add horizontal line for average ECE
            avg_ece = np.mean(ece_values)
            ax2.axhline(
                y=avg_ece,
                color="red",
                linestyle="--",
                label=f"Average ECE: {avg_ece:.4f}",
            )

            # Set labels and formatting
            ax2.set_title(f"ECE by Opponent for {champion_name} ({role})")
            ax2.set_ylabel("Expected Calibration Error (ECE)")
            ax2.set_xlabel("Opponent")
            ax2.set_xticks(range(len(readable_matchups)))
            ax2.set_xticklabels(readable_matchups, rotation=45, ha="right")
            ax2.grid(True, alpha=0.3)
            ax2.legend()

            # Save the figure
            plt.tight_layout()
            plt.savefig(output_path)
            plt.close(fig)

        except Exception as e:
            print(f"Error creating plot for {champion_key}: {str(e)}")

    print(f"Created calibration plots for {len(champion_data)} champions")


def plot_matchup_specific_ece(matchup_ece_data, output_path):
    """
    Create a bar chart showing ECE for each matchup.

    Parameters:
        matchup_ece_data: DataFrame containing matchup ECE data
        output_path: Path to save the plot
    """
    # This function is no longer needed as we're only generating champion-specific plots
    pass


def get_top_champions_by_role(play_rates, patch, top_n=20):
    """
    Get the top N most played champions for each role in a given patch.

    Parameters:
        play_rates: Dictionary of champion play rates
        patch: Patch version string
        top_n: Number of champions to return per role (default: 20)

    Returns:
        Dictionary mapping roles to lists of champion names
    """
    role_names = ["TOP", "JUNGLE", "MIDDLE", "BOTTOM", "UTILITY"]
    top_champions = {}

    # If patch doesn't exist, use the latest available patch
    if patch not in play_rates:
        patches = sorted(list(play_rates.keys()))
        if not patches:
            return {role: [] for role in role_names}
        patch = patches[-1]

    for role in role_names:
        # Get all champions with play rates for this role
        champions_with_rates = []
        for champ, roles in play_rates[patch].items():
            if role in roles and roles[role] > 0:
                champions_with_rates.append((champ, roles[role]))

        # Sort by play rate (descending) and take top N
        champions_with_rates.sort(key=lambda x: x[1], reverse=True)
        top_champions[role] = [champ for champ, _ in champions_with_rates[:top_n]]

    return top_champions


def validate_with_subgroups(
    model: Model,
    test_loader: DataLoader,
    device: torch.device,
    play_rates: Dict[str, Dict[str, Dict[str, float]]],
    test_patch_robustness: bool = False,
    n_calibration_bins: int = 20,
    matchup_specific_calibration: bool = False,
    calibration_strategy: str = "quantile",
) -> pd.DataFrame:
    """
    Validate the model and perform subgroup and calibration analysis.

    Parameters:
        model: The model to validate
        test_loader: DataLoader for test data
        device: The device to run validation on
        play_rates: Dictionary of champion play rates
        test_patch_robustness: If True, simulate using patch N-1 to predict patch N outcomes
        n_calibration_bins: Number of bins for calibration analysis
        matchup_specific_calibration: Whether to compute matchup-specific calibration
        calibration_strategy: Binning strategy for calibration analysis
    """
    model.eval()

    # For patch robustness testing
    if test_patch_robustness:
        # Find the first/earliest patch index to filter out
        patch_indices = list(patch_mapping.values())
        earliest_patch_index = min(patch_indices)

        # Create mapping of patches to their previous patch
        patch_to_previous = {}
        sorted_patches = sorted(patch_mapping.keys())
        for i in range(1, len(sorted_patches)):
            current_patch = sorted_patches[i]
            previous_patch = sorted_patches[i - 1]
            patch_to_previous[patch_mapping[current_patch]] = patch_mapping[
                previous_patch
            ]

    subgroup_total_loss: Dict[str, float] = defaultdict(float)
    subgroup_counts: Dict[str, int] = defaultdict(int)
    total_samples = 0

    # Add calibration tracking with more bins
    confidence_buckets = np.linspace(0.5, 1.0, n_calibration_bins + 1)
    calibration_correct = defaultdict(int)  # Tracks correct predictions per bucket
    calibration_total = defaultdict(int)  # Tracks total predictions per bucket

    # For overall ECE calculation
    all_win_probs = []
    all_win_labels = []

    # For matchup-specific calibration - FIX: Changed from nested defaultdict to simple dict
    matchup_data = {}

    # Get latest patch for matchup analysis
    latest_patch = sorted(list(play_rates.keys()))[-1] if play_rates else None

    # Determine popular champions for matchup analysis if needed
    top_champions_by_role = {}
    if matchup_specific_calibration and latest_patch:
        top_champions_by_role = get_top_champions_by_role(play_rates, latest_patch)

    TASKS = {
        "win_prediction": TaskDefinition(
            name="win_prediction",
            task_type=TaskType.BINARY_CLASSIFICATION,
            weight=1,
        ),
    }

    task_names = list(TASKS.keys())
    task_weights = torch.tensor(
        [TASKS[name].weight for name in task_names], device=device
    )  # Shape: [num_tasks]

    criterions = {}
    # could refactor code in common with train.py
    for task_name, task_def in TASKS.items():
        if task_def.task_type == TaskType.BINARY_CLASSIFICATION:
            criterions[task_name] = nn.BCEWithLogitsLoss(reduction="none")
        elif task_def.task_type == TaskType.REGRESSION:
            criterions[task_name] = nn.MSELoss(reduction="none")

    with torch.no_grad():
        for features_batch, labels_batch in tqdm(
            test_loader,
            desc=f"Validating {'patch robustness' if test_patch_robustness else 'model'}",
        ):
            # Move features and labels to device
            features_batch = {k: v.to(device) for k, v in features_batch.items()}
            labels_batch = {k: labels_batch[k].to(device) for k in TASKS.keys()}

            # For patch robustness testing
            if test_patch_robustness:
                # Filter out samples from the earliest patch
                patch_mask = features_batch["patch"] != earliest_patch_index
                if not patch_mask.any():
                    continue  # Skip this batch if all samples are from the earliest patch

                # Filter the batch to include only valid patches
                for k in features_batch:
                    if (
                        isinstance(features_batch[k], torch.Tensor)
                        and features_batch[k].shape[0] == patch_mask.shape[0]
                    ):
                        features_batch[k] = features_batch[k][patch_mask]

                for k in labels_batch:
                    if (
                        isinstance(labels_batch[k], torch.Tensor)
                        and labels_batch[k].shape[0] == patch_mask.shape[0]
                    ):
                        labels_batch[k] = labels_batch[k][patch_mask]

                if features_batch["patch"].shape[0] == 0:
                    continue  # Skip if no samples left after filtering

                # Store original patches for analysis and future reference
                original_patches = features_batch["patch"].clone()

                # Modify the patch index to simulate using previous patch's data
                modified_patches = torch.zeros_like(features_batch["patch"])
                for i, patch in enumerate(features_batch["patch"]):
                    patch_idx = patch.item()
                    modified_patches[i] = patch_to_previous.get(patch_idx, patch_idx)

                # Replace the patch feature with the modified version
                features_batch["patch"] = modified_patches

            batch_size = labels_batch["win_prediction"].size(0)
            total_samples += batch_size

            # Compute model outputs
            outputs_batch = model(features_batch)

            # Process calibration statistics for win prediction
            win_preds = torch.sigmoid(
                outputs_batch["win_prediction"].squeeze()
            )  # [batch_size]
            win_labels = labels_batch["win_prediction"].squeeze()  # [batch_size]

            # Store all predictions and labels for ECE calculation
            all_win_probs.extend(win_preds.cpu().numpy())
            all_win_labels.extend(win_labels.cpu().numpy())

            # Determine correctness of predictions
            predicted_classes = (win_preds >= 0.5).float()
            is_correct = predicted_classes == win_labels

            # Get the model's confidence in its prediction (always >= 0.5)
            confidences = torch.where(win_preds >= 0.5, win_preds, 1 - win_preds)

            # Process predictions by confidence
            for i in range(len(confidence_buckets) - 1):
                lower, upper = confidence_buckets[i], confidence_buckets[i + 1]
                bucket_name = f"{lower:.2f}-{upper:.2f}"

                # Find predictions that fall into this bucket
                mask = (confidences >= lower) & (confidences < upper)
                calibration_total[bucket_name] += mask.sum().item()
                calibration_correct[bucket_name] += (mask & is_correct).sum().item()

            # Process matchup-specific data if enabled
            if matchup_specific_calibration:
                champion_ids = (
                    features_batch["champion_ids"].cpu().numpy()
                )  # [batch_size, 10]
                patch_indices = features_batch["patch"].cpu().numpy()  # [batch_size]

                # Process each sample in the batch
                for i in range(batch_size):
                    patch_idx = patch_indices[i]
                    patch_str = reverse_patch_mapping.get(patch_idx, "unknown")

                    # Skip if patch info not available
                    if patch_str == "unknown" or patch_str not in play_rates:
                        continue

                    # Get champion names for this sample
                    champ_ids_sample = champion_ids[i]
                    champ_names = champion_id_encoder.inverse_transform(
                        champ_ids_sample
                    )

                    # Process matchups for popular champions
                    for role_idx, role in enumerate(
                        ["TOP", "JUNGLE", "MIDDLE", "BOTTOM", "UTILITY"]
                    ):
                        # Get champions for blue and red team in this role
                        blue_champ = champ_names[role_idx]
                        red_champ = champ_names[role_idx + 5]

                        # Check if blue champion is in our top champions list
                        if blue_champ in top_champions_by_role.get(role, []):
                            # Only include matchups against other popular champions
                            if red_champ in top_champions_by_role.get(role, []):
                                # Use champion IDs for the matchup key
                                blue_id = champion_id_encoder.transform([blue_champ])[0]
                                red_id = champion_id_encoder.transform([red_champ])[0]
                                matchup_key = f"{blue_id}_{role}_vs_{red_id}"

                                # Initialize matchup data if not already present
                                if matchup_key not in matchup_data:
                                    matchup_data[matchup_key] = {"true": [], "pred": []}
                                # Add the data
                                matchup_data[matchup_key]["pred"].append(
                                    win_preds[i].item()
                                )
                                matchup_data[matchup_key]["true"].append(
                                    win_labels[i].item()
                                )

                        # Check if red champion is in our top champions list
                        if red_champ in top_champions_by_role.get(role, []):
                            # Only include matchups against other popular champions
                            if blue_champ in top_champions_by_role.get(role, []):
                                # Use champion IDs for the matchup key
                                red_id = champion_id_encoder.transform([red_champ])[0]
                                blue_id = champion_id_encoder.transform([blue_champ])[0]
                                matchup_key = f"{red_id}_{role}_vs_{blue_id}"

                                # Initialize matchup data if not already present
                                if matchup_key not in matchup_data:
                                    matchup_data[matchup_key] = {"true": [], "pred": []}
                                # For red team, we need to invert the prediction and label
                                matchup_data[matchup_key]["pred"].append(
                                    1 - win_preds[i].item()
                                )
                                matchup_data[matchup_key]["true"].append(
                                    1 - win_labels[i].item()
                                )

            # Compute losses for entire batch at once
            batch_losses = []
            for task_name in task_names:
                output = outputs_batch[task_name].view(
                    batch_size, -1
                )  # [batch_size, feat_dim]
                label = labels_batch[task_name].view(
                    batch_size, -1
                )  # [batch_size, feat_dim]
                task_loss = criterions[task_name](output, label)  # [batch_size]
                batch_losses.append(task_loss)

            # Stack and compute total loss for all samples at once
            batch_losses_tensor = torch.stack(
                batch_losses, dim=1
            )  # [batch_size, num_tasks]
            total_losses = (batch_losses_tensor * task_weights).sum(
                dim=1
            )  # [batch_size]

            # Vectorized subgroup assignment
            elo_subgroups = [f"elo_{elo}" for elo in features_batch["elo"].tolist()]

            # Use original patches for subgroup assignment if in robustness testing mode,
            # otherwise use current patches (which may be modified)
            patch_feature = (
                original_patches if test_patch_robustness else features_batch["patch"]
            )
            patch_subgroups = [f"patch_{patch}" for patch in patch_feature.tolist()]

            playrate_subgroups = get_playrate_subgroup_batch(
                features_batch["champion_ids"], play_rates, patch_feature
            )

            # Process all subgroups at once using numpy operations
            all_subgroups = elo_subgroups + patch_subgroups + playrate_subgroups
            all_losses = total_losses.repeat_interleave(
                3
            )  # Repeat each loss 3 times for the 3 subgroup types

            for sg, loss in zip(all_subgroups, all_losses):
                subgroup_total_loss[sg] += loss.item()
                subgroup_counts[sg] += 1

    # Calculate overall ECE
    all_win_probs = np.array(all_win_probs)
    all_win_labels = np.array(all_win_labels)
    overall_ece, prob_true, prob_pred, bins = compute_ece(
        all_win_labels,
        all_win_probs,
        n_bins=n_calibration_bins,
        strategy=calibration_strategy,
    )

    # Create output directory for plots
    plots_dir = os.path.join(DATA_DIR, "validation")
    os.makedirs(plots_dir, exist_ok=True)

    # Plot overall calibration curve
    overall_plot_path = os.path.join(plots_dir, "overall_calibration.png")
    plot_calibration_curve(
        prob_true,
        prob_pred,
        bins,
        f"Overall Calibration (ECE={overall_ece:.4f}, n={len(all_win_labels)})",
        overall_plot_path,
    )

    # Plot overall ECE by bucket
    overall_ece_path = os.path.join(plots_dir, "overall_ece_by_bucket.png")
    plot_ece_by_bucket(
        prob_true, prob_pred, bins, overall_ece, len(all_win_labels), overall_ece_path
    )

    # Plot matchup-specific calibration curves if requested
    if matchup_specific_calibration:
        matchup_plots_dir = os.path.join(plots_dir, "matchups")
        plot_matchup_calibration(matchup_data, matchup_plots_dir)

    # Prepare results
    subgroup_data = {
        "mean_loss": {
            k: subgroup_total_loss[k] / subgroup_counts[k] for k in subgroup_total_loss
        },
        "count": subgroup_counts,
        "percentage": {
            k: 100.0 * subgroup_counts[k] / total_samples for k in subgroup_counts
        },
    }

    # Add calibration results
    calibration_data = {
        "confidence_bucket": [],
        "samples": [],
        "accuracy": [],
        "expected_accuracy": [],
    }

    for i in range(len(confidence_buckets) - 1):
        lower, upper = confidence_buckets[i], confidence_buckets[i + 1]
        bucket_name = f"{lower:.2f}-{upper:.2f}"

        if calibration_total[bucket_name] > 0:
            calibration_data["confidence_bucket"].append(
                f"{lower*100:.0f}-{upper*100:.0f}%"
            )
            calibration_data["samples"].append(calibration_total[bucket_name])
            calibration_data["accuracy"].append(
                calibration_correct[bucket_name] / calibration_total[bucket_name]
            )
            calibration_data["expected_accuracy"].append((lower + upper) / 2)

    # Process matchup-specific calibration results
    matchup_ece_data = {
        "matchup": [],
        "readable_matchup": [],
        "samples": [],
        "ece": [],
    }

    if matchup_specific_calibration:
        # Filter matchups with enough samples
        min_samples = 30  # Minimum samples for reliable calibration
        valid_matchups = {
            k: v for k, v in matchup_data.items() if len(v["true"]) >= min_samples
        }

        # Calculate ECE for each valid matchup
        for matchup, data in valid_matchups.items():
            true_vals = np.array(data["true"])
            pred_vals = np.array(data["pred"])

            # Skip if all predictions or all labels are the same
            if len(np.unique(true_vals)) <= 1 or len(np.unique(pred_vals)) <= 1:
                continue

            # Use fewer bins for matchup-specific calibration due to smaller sample size
            matchup_ece, _, _, _ = compute_ece(
                true_vals,
                pred_vals,
                n_bins=n_calibration_bins,
                strategy=calibration_strategy,
            )

            # Add both the raw matchup key and a readable version
            readable_matchup = convert_matchup_key_to_readable(matchup)
            matchup_ece_data["matchup"].append(matchup)
            matchup_ece_data["readable_matchup"].append(readable_matchup)
            matchup_ece_data["samples"].append(len(true_vals))
            matchup_ece_data["ece"].append(matchup_ece)

    # Combine all results into a single DataFrame
    df = pd.DataFrame(subgroup_data)
    df_calibration = pd.DataFrame(calibration_data)
    df_matchup_ece = (
        pd.DataFrame(matchup_ece_data)
        if matchup_specific_calibration
        else pd.DataFrame()
    )

    # Add a type column to distinguish between different result types
    df["analysis_type"] = "subgroup"
    df_calibration["analysis_type"] = "calibration"
    if matchup_specific_calibration:
        df_matchup_ece["analysis_type"] = "matchup_calibration"

    # Add overall ECE to a separate DataFrame
    df_overall_ece = pd.DataFrame(
        {
            "metric": ["ECE"],
            "value": [overall_ece],
            "n_bins": [n_calibration_bins],
            "strategy": [calibration_strategy],
            "analysis_type": ["overall_calibration"],
        }
    )

    # Combine the DataFrames
    combined_df = pd.concat(
        [df, df_calibration, df_overall_ece]
        + ([df_matchup_ece] if matchup_specific_calibration else []),
        axis=0,
    )

    return combined_df


def main():
    """
    Main function to perform validation and subgroup analysis.
    """
    parser = argparse.ArgumentParser(description="Validate the match-prediction model")
    parser.add_argument(
        "--small",
        action="store_true",
        help="Use only a small subset of the dataset for quick iteration",
    )
    parser.add_argument(
        "--test-patch-robustness",
        action="store_true",
        help="Test model robustness by using patch N-1 to predict patch N outcomes",
    )
    parser.add_argument(
        "--mask-champions",
        type=int,
        default=0,
        help="Number of champions to randomly mask in each team composition (default: 0)",
    )
    parser.add_argument(
        "--calibration-bins",
        type=int,
        default=20,
        help="Number of bins for calibration analysis (default: 20)",
    )
    parser.add_argument(
        "--calibration-strategy",
        type=str,
        choices=["uniform", "quantile"],
        default="quantile",
        help="Binning strategy for calibration analysis (default: quantile)",
    )
    parser.add_argument(
        "--matchup-calibration",
        action="store_true",
        help="Compute champion-specific calibration for matchups between top 20 popular champions",
    )
    parser.add_argument(
        "--quick-test",
        action="store_true",
        help="Run on a very small subset (0.1%) for quick testing of code functionality",
    )
    args = parser.parse_args()

    device = get_best_device()

    # Initialize model
    config = TrainingConfig()
    model = Model(config=config, dropout=0, hidden_dims=config.hidden_dims)
    model = load_model_state_dict(model, device=device, path=MODEL_PATH)
    model.eval()

    # Get the unknown champion ID from the encoder
    unknown_champion_id = champion_id_encoder.transform(["UNKNOWN"])[0]

    # Define masking function if needed
    masking_function = None
    if args.mask_champions > 0:
        masking_function = FixedMaskCount(args.mask_champions)
        print(f"Masking {args.mask_champions} champions in each team composition")

    # Determine dataset fraction based on args
    dataset_fraction = 0.001 if args.quick_test else (0.01 if args.small else 1.0)
    if args.quick_test:
        print("QUICK TEST MODE: Using 0.1% of data for testing code functionality")
    elif args.small:
        print("SMALL MODE: Using 1% of data")

    # Initialize test dataset and loader
    test_dataset = MatchDataset(
        train_or_test="test",
        dataset_fraction=dataset_fraction,
        masking_function=masking_function,
        unknown_champion_id=unknown_champion_id,
    )
    test_loader = DataLoader(
        test_dataset,
        batch_size=TRAIN_BATCH_SIZE,
        collate_fn=collate_fn,
        num_workers=4,
        pin_memory=True,
    )

    with open(champion_play_rates_path, "r") as f:
        play_rates = json.load(f)

    # Run validation and subgroup analysis
    results_df = validate_with_subgroups(
        model,
        test_loader,
        device,
        play_rates,
        test_patch_robustness=args.test_patch_robustness,
        n_calibration_bins=args.calibration_bins,
        matchup_specific_calibration=args.matchup_calibration,
        calibration_strategy=args.calibration_strategy,
    )

    # Determine output filename based on mode
    base_filename = "validation_results"
    if args.test_patch_robustness:
        base_filename = "validation_patch_robustness_results"
    if args.mask_champions > 0:
        base_filename = f"{base_filename}_masked_{args.mask_champions}"
    if args.matchup_calibration:
        base_filename = f"{base_filename}_with_matchups"
    if args.quick_test:
        base_filename = f"{base_filename}_quick_test"

    output_file = DATA_DIR + "/" + base_filename + ".csv"

    # Print and save results
    print("\nValidation Results:")
    pd.set_option("display.max_rows", None)
    pd.set_option("display.max_columns", None)
    pd.set_option("display.width", None)

    # Print overall ECE first
    overall_ece = results_df[results_df["analysis_type"] == "overall_calibration"]
    if not overall_ece.empty:
        print("\nOverall Expected Calibration Error (ECE):")
        print(
            f"ECE = {overall_ece['value'].values[0]:.4f} (using {args.calibration_bins} bins)"
        )

    # Print matchup calibration info if enabled
    if args.matchup_calibration:
        matchup_results = results_df[
            results_df["analysis_type"] == "matchup_calibration"
        ]
        if not matchup_results.empty:
            avg_ece = matchup_results["ece"].mean()
            min_ece = matchup_results["ece"].min()
            max_ece = matchup_results["ece"].max()
            print("\nChampion-Specific Calibration Summary:")
            print(f"Number of matchups analyzed: {len(matchup_results)}")
            print(f"Average ECE across matchups: {avg_ece:.4f}")
            print(f"Min ECE: {min_ece:.4f}, Max ECE: {max_ece:.4f}")

            # Get the best and worst calibrated matchups
            best_idx = matchup_results["ece"].idxmin()
            worst_idx = matchup_results["ece"].idxmax()
            print(
                f"Best calibrated matchup: {matchup_results.loc[best_idx, 'readable_matchup']} (ECE={min_ece:.4f})"
            )
            print(
                f"Worst calibrated matchup: {matchup_results.loc[worst_idx, 'readable_matchup']} (ECE={max_ece:.4f})"
            )

    # Print visualization info
    validation_dir = os.path.join(DATA_DIR, "validation")
    print(f"\nVisualization outputs:")
    print(f"- All plots saved to: {validation_dir}")
    print(
        f"- Overall calibration curve: {os.path.join(validation_dir, 'overall_calibration.png')}"
    )
    print(
        f"- ECE by bucket: {os.path.join(validation_dir, 'overall_ece_by_bucket.png')}"
    )
    if args.matchup_calibration:
        print(
            f"- Champion-specific calibration plots: {os.path.join(validation_dir, 'matchups')}"
        )
        print(
            f"  Each plot shows a champion's calibration across matchups with other top 20 popular champions."
        )

    # Print full results
    print("\nDetailed Results:")
    print(results_df)

    pd.reset_option("display.max_rows")
    pd.reset_option("display.max_columns")
    pd.reset_option("display.width")

    # Save results to CSV
    results_df.to_csv(output_file)
    print(f"\nSaved validation results to '{output_file}'")


# Create a mapping from champion_id to champion name for quick lookup
def create_champion_id_to_name_mapping():
    """
    Create a mapping from champion ID to champion name using the Champion enum.

    Returns:
        Dict[int, str]: A dictionary mapping champion IDs to their display names
    """
    champion_id_to_name = {}
    for champion in Champion:
        champion_id_to_name[champion.id] = champion.display_name
    return champion_id_to_name


# Create the champion mapping once to avoid repeated lookups
CHAMPION_ID_TO_NAME = create_champion_id_to_name_mapping()


def get_champion_name(champion_id):
    """
    Get the display name for a champion ID.

    Parameters:
        champion_id (int): The ID of the champion

    Returns:
        str: The display name of the champion or "Unknown" if not found
    """
    return CHAMPION_ID_TO_NAME.get(champion_id, f"Unknown_{champion_id}")


def convert_matchup_key_to_readable(matchup_key):
    """
    Convert a matchup key with encoded IDs to a readable format with champion names.

    Parameters:
        matchup_key (str): The matchup key in format "ID_ROLE_vs_ID"

    Returns:
        str: A readable matchup key in format "ChampionName_ROLE_vs_ChampionName"
    """
    try:
        # Parse the matchup key (format: "ID_ROLE_vs_ID")
        parts = matchup_key.split("_vs_")
        if len(parts) != 2:
            return matchup_key  # Can't parse, return as is

        first_part = parts[0].split("_")
        if len(first_part) < 2:
            return matchup_key  # Can't parse, return as is

        # Get encoded champion IDs
        champion1_id = int(first_part[0])
        role = "_".join(first_part[1:])
        champion2_id = int(parts[1])

        try:
            # Step 1: Decode the encoded IDs to get original champion IDs
            original_champ1_id = int(
                champion_id_encoder.inverse_transform([champion1_id])[0]
            )
            original_champ2_id = int(
                champion_id_encoder.inverse_transform([champion2_id])[0]
            )

            # Step 2: Get champion names from their original IDs
            champion1_name = get_champion_name(original_champ1_id)
            champion2_name = get_champion_name(original_champ2_id)

            # Create readable key
            return f"{champion1_name}_{role}_vs_{champion2_name}"
        except Exception:
            # If lookup fails, return a formatted string with the raw IDs
            return f"Unknown{champion1_id}_{role}_vs_Unknown{champion2_id}"
    except (ValueError, IndexError):
        # If parsing fails, return the original key
        return matchup_key


if __name__ == "__main__":
    main()
