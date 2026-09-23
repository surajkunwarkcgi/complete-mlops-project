"""
SageMaker Pipeline Orchestrator

This Script is called by GitHub Actions after tests pass.
It triggers a SageMaker Training Job and registers the model.
"""

import os
import logging
import boto3

from sagemaker.sklearn.estimator import SKLearn
from sagemaker.inputs import TrainingInput

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger(__name__)

def upload_training_data(bucket: str, region: str) -> str:
    """Upload local wine dataset to S3 and return S3 URI."""
    s3 = boto3.client("s3", region_name = region)
    local_path = "artifacts/data_ingestion/winequality-red.csv"

    if not os.path.exists(local_path):
        raise FileNotFoundError(
            f"{local_path} not found. Run data ingestion pipeline first"
        )

    s3_key = "wine-quality/data/winequality-red.csv"
    s3.upload_file(local_path, bucket, s3_key)
    s3_uri = f"s3://{bucket}/{s3_key}"
    logger.info(f"Uploaded training data to {s3_uri}")
    return f"s3://{bucket}/wine-quality/data"

def run_training_job(role_arn: str, bucket: str, region: str, data_s3_uri: str) -> str:
    """Launch SageMaker Training Job and return S3 URI of saved model."""

    estimator = SKLearn(
        entry_point = "train.py",
        source_dir = "sagemaker",
        role = role_arn,
        instance_type = "ml.m5.large",
        instance_count = 1,
        framework_version = "1.2-1",
        py_version = "py3",
        output_path = f"s3://{bucket}/wine-quality/model-artifacts",
        base_job_name = "wine-quality-training",
        hyperparameters = {
            "alpha"         : 0.2,
            "l1-ration"     : 0.1,
            "target-column" : "quality"
        },
        environment = {
            "MLFLOW_TRACKING_URI"      : os.environ.get("MLFLOW_TRACKING_URI", ""),
            "MLFLOW_TRACKING_USERNAME" : os.environ.get("MLFLOW_TRACKING_USERNAME", ""),
            "MLFLOW_TRACKING_PASSWORD" : os.environ.get("MLFLOW_TRACKING_PASSWORD", ""),
            "AWS_DEFAULT_REGION"       : region
        },
        sagemaker_session = None  # uses default boto3 session
    )

    training_input = TrainingInput(data_s3_uri, content_type = "text/csv")

    logger.info("Starting SageMaker Training Job...")
    estimator.fit({"training": training_input}, wait = True, logs = "All")

    model_s3_uri = estimator.model_data
    logger.info(f"Training Complete. Model artifact at: {model_s3_uri}")
    return model_s3_uri


def download_model_from_s3(model_s3_uri: str, region: str):
    """Download trained model.joblib from S3 so Docker build can copy it."""
    import tarfile
    import tempfile

    s3 = boto3.client("s3", region_name = region)

    # model_s3_uri is like s3://bucket/prefix/output/model.tar.gz
    bucket = model_s3_uri.split("/")[2]
    key    = "/".join(model_s3_uri.split("/")[3:])

    os.makedirs("artifacts/model_trainer", exist_ok = True)

    with tempfile.NamedTemporaryFile(suffix = ".tar.gz", delete = False) as tmp:
        s3.download_file(bucket, key, tmp.name)
        with tarfile.open(tmp.name, "r:gz") as tar:
            tar.extractall("artifacts/model_trainer")

    logger.info("Model downloaded and extracted to artifacts/model_trainer/model.joblib")        

def main():
    region = os.environ["AWS_DEFAULT_REGION"]
    role_arn = os.environ["SAGEMAKER_ROLE_ARN"]
    bucket = os.environ["SAGEMAKER_BUCKET"]

    # Step 1 - Upload training data to S3
    data_s3_uri = upload_training_data(bucket, region)

    # Step 2 - Run SageMaker Training Job
    model_s3_uri = run_training_job(role_arn, bucket, region, data_s3_uri)

    # Step 3 - Download model so Docker image can include it
    download_model_from_s3(model_s3_uri, region)

    # Step 4 - Write model S3 URI to file so GitHub Actions can read it
    with open("model_s3_uri.txt", "w") as f:
        f.write(model_s3_uri)

    logger.info(f"Wrote model S3 URI to model_s3_uri.txt: {model-model_s3_uri}")

if __name__ == "__main__":
    main()