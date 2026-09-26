"""
Prediction Capture Logger

Logs every prediction request to S3 in CSV format.
SageMaker Model Monitor reads from this S3 path daily
to compare against the training baseline.

Writes are async (background thread) so they don't slow down predictions.
"""

import os
import csv
import uuid
import logging
import threading
import io
from datetime import datetime
import boto3

logger = logging.getLogger(__name__)

FEATURE_COLUMNS = [
    "fixed_acidity", "volatile_acidity", "citric_acid", "residual_sugar",
    "chlorides", "free_sulfur_dioxide", "total_sulfur_dioxide",
    "density", "pH", "sulphates", "alcohol"
]

class PredictionCapture:
    def __init__(self):
        self.bucket = os.environ.get("SAGEMAKER_BUCKET")
        self.region = os.environ.get("AWS_DEFAULT_REGION", "ap-northeast-1")
        self.enabled = bool(self.bucket)

        if self.enabled:
            self.s3 = boto3.client("s3", region_name = self.region)
            logger.info(f"Prediction capture enabled - writing to s3://{self.bucket}/wine-quality/prediction-captures/")
        else:
            logger.warning("SAGEMAKER_BUCKET not set - prediction capture disabled")


    def capture(self, features: dict, prediction: float):
        """Log prediction asynchronously to avoid blocking the request."""

        if not self.enabled:
            return

        thread = threading.Thread(
            target = self._write_to_s3,
            args = (features, prediction),
            daemon = True
        )        
        thread.start()


    def _write_to_s3(self, features: dict, prediction: float):
        try:
            # One file per day under prediction-captures/YYYY/MM/DD/
            now    = datetime.utcnow()
            s3_key = (
                f"wine-quality/prediction-captures/"
                f"{now.year}/{now.month:02d}/{now.day:02d}/"
                f"{uuid.uuid4()}.csv"
            )

            # Write CSV row with feature values only (Model Monitor expects features, not prediction)
            buf = io.StringIO()
            writer = csv.DictWriter(buf, fieldnames = FEATURE_COLUMNS)
            writer.writeheader()
            writer.writerow({col: features.get(col, "") for col in FEATURE_COLUMNS})

            self.s3.put_object(
                Bucket = self.bucket,
                Key = s3_key,
                Body = buf.getvalue().encode("utf-8"),
                ContentType = "text/csv"
            )

        except Exception as e:
            logger.warning(f"Prediction capture failed (non-fatal): {e}")  


# Singleton - instantiated once at app startup
prediction_capture = PredictionCapture()  