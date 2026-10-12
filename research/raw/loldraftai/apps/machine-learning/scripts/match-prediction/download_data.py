# scripts/match-prediction/download_data.py
# Downloads latest raw data from Azure Blob Storage
import os
import argparse
from datetime import datetime, timedelta
from typing import List, Tuple
from azure.storage.blob import BlobServiceClient, BlobProperties
from tqdm import tqdm
from dotenv import load_dotenv
from utils.match_prediction import RAW_AZURE_DIR
from concurrent.futures import ThreadPoolExecutor, as_completed

load_dotenv()

CONTAINER_NAME = "league-matches"
PROCESSED_DATA_PREFIX = "processed"


def get_blobs_for_timespan(container_client, months: int = 3) -> List[BlobProperties]:
    """
    Get blobs from the last N months.

    Args:
        container_client: Azure container client
        months: Number of months to look back

    Returns:
        List of blob properties
    """
    all_blobs: List[BlobProperties] = []
    current_date = datetime.now()

    for month_offset in range(months):
        date = current_date - timedelta(days=30 * month_offset)
        prefix = f"{PROCESSED_DATA_PREFIX}/{date.year}/{date.month:02d}/"

        # List blobs for this month
        month_blobs = container_client.list_blobs(name_starts_with=prefix)
        all_blobs.extend(list(month_blobs))

    return all_blobs


def download_single_file(args: Tuple[str, str, BlobProperties]) -> str:
    """
    Download a single file from Azure Blob Storage.

    Args:
        args: Tuple containing (connection_string, output_dir, blob)

    Returns:
        str: Name of the downloaded file
    """
    connection_string, output_dir, blob = args
    file_name = os.path.basename(blob.name)
    output_path = os.path.join(output_dir, file_name)

    # Create new client for each thread to ensure thread safety
    blob_service_client = BlobServiceClient.from_connection_string(connection_string)
    container_client = blob_service_client.get_container_client(CONTAINER_NAME)
    blob_client = container_client.get_blob_client(blob.name)

    with open(output_path, "wb") as file:
        download_stream = blob_client.download_blob()
        file.write(download_stream.readall())

    return file_name


def download_new_parquet_files(output_dir: str, months: int = 3) -> None:
    """
    Download new parquet files from Azure that don't exist locally.

    Args:
        output_dir: Directory where to save the downloaded files
        months: Number of months of data to download
    """
    # Validate Azure connection string
    connection_string = os.getenv("AZURE_CONNECTION_STRING")
    if not connection_string:
        raise ValueError("AZURE_CONNECTION_STRING environment variable is not set")

    # Create output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)

    # Initialize Azure client
    blob_service_client = BlobServiceClient.from_connection_string(connection_string)
    container_client = blob_service_client.get_container_client(CONTAINER_NAME)

    # Get list of existing local files
    local_files = set(os.listdir(output_dir))

    # Get all blobs from the last N months
    azure_files = get_blobs_for_timespan(container_client, months=months)

    # Filter files that need to be downloaded
    files_to_download = [
        blob for blob in azure_files if os.path.basename(blob.name) not in local_files
    ]

    print(f"Found {len(azure_files)} files in Azure from the last {months} months")
    print(f"Files already downloaded: {len(azure_files) - len(files_to_download)}")

    if not files_to_download:
        print("No new files to download")
        return

    # Prepare arguments for parallel download
    download_args = [
        (connection_string, output_dir, blob) for blob in files_to_download
    ]

    # Use ThreadPoolExecutor for parallel downloads
    # Number of workers can be adjusted based on your system
    max_workers = min(32, len(files_to_download))  # Limit max workers to 32

    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        # Submit all download tasks
        future_to_blob = {
            executor.submit(download_single_file, args): args[2].name
            for args in download_args
        }

        # Process completed downloads with progress bar
        with tqdm(total=len(files_to_download), desc="Downloading files") as pbar:
            for future in as_completed(future_to_blob):
                blob_name = future_to_blob[future]
                try:
                    file_name = future.result()
                    pbar.update(1)
                except Exception as e:
                    print(f"Error downloading {blob_name}: {str(e)}")

    print(f"Downloaded {len(files_to_download)} new files")


def main():
    parser = argparse.ArgumentParser(
        description="Download new parquet files from Azure"
    )
    parser.add_argument(
        "--months",
        type=int,
        default=3,
        help="Number of months of data to download (default: 3)",
    )
    args = parser.parse_args()

    download_new_parquet_files(RAW_AZURE_DIR, args.months)


if __name__ == "__main__":
    main()
