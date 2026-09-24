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

def register_model_to_sagemaker(model_package_group, metrics, model_s3_uri, region):
    """Register trained model to SageMaker Model Registry with PendingManualApproval."""
    sm_client = boto3.client("sagemaker", region_name = region)

    # Ensure model package group exists
    try:
        sm_client.create_model_package_group(
            ModelPackageGroupName = model_package_group,
            ModelPackageGroupDescription = "Wine Quality Predictor ElasticNet models"
        )

        logger.info(f"Created model package group: {model_package_group}")
    
    except sm_client.exceptions.ConflictException:
        logger.info(f"Model package group already exists: {model_package_group}")

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
                    "S3Uri": f"{model_s3_uri}/metrics.json"
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
    metrics = {"rmse": rmse, "mae": maem "r2": r2}
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