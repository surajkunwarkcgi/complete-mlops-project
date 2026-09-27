"""
SageMaker Training Entrypoint

SageMaker runs this script inside a managed ml.m5.large container.
It reads data from /opt/ml/input/data/, trains the model,
and saves the artifact to /opt/ml/model/ which SageMaker uploads to S3
"""

import os
import json
import joblib
import logging
import argparse
import numpy as np
import pandas as pd
import mlflow
import mlflow.sklearn
import boto3
import time

from pathlib import Path
from sklearn.linear_model import ElasticNet
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_squared_error, mean_absolute_error, r2_score

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger(__name__)

# SageMaker injects these paths automatically
INPUT_DATA_DIR  = "/opt/ml/input/data/training" 
MODEL_DIR       = "/opt/ml/model"
OUTPUT_DATA_DIR = "/opt/ml/output/data"

def eval_metrics(actual, pred):
    rmse = np.sqrt(mean_squared_error(actual, pred))
    mae  = mean_absolute_error(actual, pred)
    r2   = r2_score(actual, pred)
    return rmse, mae, r2

def register_model_to_sagemaker(model_package_group, metrics, model_s3_uri, metrics_s3_uri, region):
    """Register trained model to SageMaker Model Registry with PendingManualApproval."""
    sm_client = boto3.client("sagemaker", region_name = region)

    # Ensure model package group exists
    try:
        sm_client.create_model_package_group(
            ModelPackageGroupName = model_package_group,
            ModelPackageGroupDescription = "Wine Quality Predictor ElasticNet models"
        )

        logger.info(f"Created model package group: {model_package_group}")
    
    except sm_client.exceptions.ClientError as e:
        if e.response["Error"]["Code"] == "ValidationException":
            logger.info(f"Model package group already exists: {model_package_group}")
        else:
            raise
        
    response = sm_client.create_model_package(
        ModelPackageGroupName = model_package_group,
        ModelPackageDescription = f"ElasticNet wine quality predictor - RMSE = {metrics['rmse']:.4f}",
        ModelApprovalStatus = "PendingManualApproval",
        InferenceSpecification = {
            "Containers": [{
                "Image": f"763104351884.dkr.ecr.{region}.amazonaws.com/sklearn:1.2-1",
                "ModelDataUrl": model_s3_uri,
                "Framework": "SKLEARN",
                "FrameworkVersion": "1.2",
                "NearestModelName": "ElasticNet"
            }],
            "SupportedContentTypes": ["text/csv"],
            "SupportedResponseMIMETypes": ["text/csv"]
        },
        ModelMetrics = {
            "ModelQuality": {
                "Statistics": {
                    "ContentType": "application/json",
                    #"S3Uri": f"{model_s3_uri}/metrics.json"
                    "S3Uri": metrics_s3_uri
                }
            }
        }
    )

    model_package_arn = response["ModelPackageArn"]
    logger.info(f"Model registered: {model_package_arn}")
    return model_package_arn


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--alpha", type=float, default=0.2)
    parser.add_argument("--l1-ratio", type=float, default=0.1)
    parser.add_argument("--target-column", type=str, default="quality")
    parser.add_argument("--model-package-group", type=str, default="WineQualityPredictor")
    parser.add_argument("--region", type=str, default=os.environ.get("AWS_DEFAULT_REGION", "ap-northeast-1"))
    # SageMaker output path passed from sagemaker_pipeline.py so we can build the model S3 URI
    parser.add_argument("--output-s3-path", type=str, default="")
    args = parser.parse_args()

    # Load Data
    data_file = os.path.join(INPUT_DATA_DIR, "winequality-red.csv")
    logger.info(f"Loading data from {data_file}")
    data = pd.read_csv(data_file)

    train, test = train_test_split(data, test_size=0.25, random_state=42)
    train_x = train.drop([args.target_column], axis=1)
    train_y = train[args.target_column]
    test_x  = test.drop([args.target_column], axis=1)
    test_y  = test[args.target_column]

    
    # Save train data for Model Monitor baseline (needs raw training features)
    os.makedirs(OUTPUT_DATA_DIR, exist_ok=True)
    train_x.to_csv(os.path.join(OUTPUT_DATA_DIR, "train_features.csv"), index=False)
    logger.info("Saved train_features.csv for Model Monitor baseline")


    # Train
    logger.info(f"Training ElasticNet alpha={args.alpha} l1_ratio={args.l1_ratio}")
    model = ElasticNet(alpha=args.alpha, l1_ratio=args.l1_ratio, random_state=42)
    model.fit(train_x, train_y)


    # Evaluate
    predictions = model.predict(test_x)
    rmse, mae, r2 = eval_metrics(test_y, predictions)
    metrics = {"rmse": rmse, "mae": mae, "r2": r2}
    logger.info(f"Metrics: RMSE={rmse:.4f} MAE={mae:.4f} R2={r2:.4f}")

    # Save model artifact
    os.makedirs(MODEL_DIR, exist_ok=True)
    model_path = os.path.join(MODEL_DIR, "model.joblib")
    joblib.dump(model, model_path)
    logger.info(f"Model saved to {model_path}")

    # Save metrics alongside model for Model Registry
    metrics_path = os.path.join(MODEL_DIR, "metrics.json")
    with open(metrics_path, "w") as f:
        json.dump(metrics, f, indent=2)

    # Register model to SageMaker Model Registry (PendingManualApproval)
    # SageMaker injects SM_TRAINING_ENV with the job name so we can build the S3 URI
    training_env = json.loads(os.environ.get("SM_TRAINING_ENV", "{}"))
    job_name = training_env.get("job_name", "")
    if args.output_s3_path and job_name:
        model_s3_uri = f"{args.output_s3_path}/{job_name}/output/model.tar.gz"
        
        # metrics.json is packed inside model.tar.gz so it is not a standalone S3 object.
        # Upload it directly so the Model Registry has a valid, readable S3 URI.
        bucket_name = args.output_s3_path.split("/")[2]
        metrics_s3_key = f"wine-quality/model-artifacts/{job_name}/metrics.json"
        s3_client = boto3.client("s3", region_name=args.region)
        s3_client.put_object(
            Bucket      = bucket_name,
            Key         = metrics_s3_key,
            Body        = json.dumps(metrics, indent=2).encode("utf-8"),
            ContentType = "application/json"
        )
        metrics_s3_uri = f"s3://{bucket_name}/{metrics_s3_key}"
        logger.info(f"Metrics uploaded to {metrics_s3_uri}")

        max_retries = 5
        for attempt in range(max_retries):
            try:
                logger.info(f"Attempting model registration (attempt {attempt+1}/{max_retries})")
                register_model_to_sagemaker(args.model_package_group, metrics, model_s3_uri, metrics_s3_uri, args.region)
                break
            except Exception as e:
                if "Cannot find S3 object" in str(e) and attempt < max_retries - 1:
                    logger.warning(f"S3 object not ready yet, waiting 10s...")
                    time.sleep(10)
                else:
                    raise

        #register_model_to_sagemaker(args.model_package_group, metrics, model_s3_uri, metrics_s3_uri, args.region)
    else:
        logger.warning("Skipping Model Registry: --output-s3-path or SM_TRAINING_ENV job_name not available")    

    # Log to MLFLOW
    mlflow_uri       = os.environ.get("MLFLOW_TRACKING_URI")
    mlflow_username  = os.environ.get("MLFLOW_TRACKING_USERNAME")
    mlflow_password  = os.environ.get("MLFLOW_TRACKING_PASSWORD")

    if mlflow_uri:
        os.environ["MLFLOW_TRACKING_USERNAME"] = mlflow_username or ""
        os.environ["MLFLOW_TRACKING_PASSWORD"] = mlflow_password or ""
        mlflow.set_tracking_uri(mlflow_uri)

        with mlflow.start_run():
            mlflow.log_params({"alpha": args.alpha, "l1_ratio": args.l1_ratio})
            mlflow.log_metrics(metrics)
            mlflow.sklearn.log_model(model, "model", registered_model_name = "WineQualityPredictor")
        logger.info("Metrics and model logged to MLFlow")
    else:
        logger.warning("MLFLOW_TRACKING_URI not set - skipping MLFlow logging")

if __name__ == "__main__":
    main()