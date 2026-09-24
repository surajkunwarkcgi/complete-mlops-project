import os
import subprocess
import zipfile
from src.datascience import logger
from src.datascience.entity.config_entity import DataIngestionConfig

## component for data ingestion

class DataIngestion:
    def __init__(self, config: DataIngestionConfig):
        self.config = config

    # Downloading the zip file
    def download_file(self):
        """
        Pull versioned data from S3 via DVC.
        DVC reads the .dvc pointer file committed in Git and downloads
        the exact data version from S3 remote storage.

        Falls back to original URL download if DVC is not initialized
        (e.g. first-time local setup before dvc init has been run)
        """

        dvc_pointer = os.path.join(
            self.config.unzip_dir, "winequality-red.csv.dvc"
        )

        if os.path.exists(".dvc/config"):
            logger.info("DVC config found - pulling versioned data from S3")
            result = subprocess.run(
                ["dvc", "pull"],
                capture_output=True,
                text=True
            )

            if result.returncode != 0:
                raise RuntimeError(
                    f"DVC pull failed:\n{result.stderr}\n"
                    "Ensure SAGEMAKER_BUCKET is set and AWS credentials are available."
                )
            logger.info("Data pulled successfully via DVC")
        else:
            # Fallback - original UrL download for first-time local setup
            import urllib.request as request  
            logger.warning(
                "DVC not initialized - falling back to URL download."
                "Run: dvc init && dvc add && dvc push to enable versioning."
            )      
            if not os.path.exists(self.config.local_data_file):
                filename, headers = request.urlretrieve(
                    url=self.config.source_URL,
                    filename=self.config.local_data_file
                )
                logger.info(f"{filename} downloaded with following info: \n{headers}")
            else:
                logger.info(f"File already exists - skipping download")

    def extract_zip_file(self):
        """
        Extracts the zip file into the data directory.
        Only runs when data was downloaded via URL.
        DVC pull extracts files directory - no zip involved.
        """
        # Skip extraction if CSV already exists (pulled via DVC)
        csv_path = os.path.join(self.config.unzip_dir, "winequality-red.csv")
        if os.path.exists(csv_path):
            logger.info("CSV already exists - skipping zip extraction")
            return

        unzip_path = self.config.unzip_dir
        os.makedirs(unzip_path, exist_ok=True)
        with zipfile.ZipFile(self.config.local_data_file, 'r') as zip_ref:
            zip_ref.extractall(unzip_path)
        logger.info(f"Extracted zip to {unzip_path}")