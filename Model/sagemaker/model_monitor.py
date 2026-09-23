"""
Sagemaker Model Monitor Setup

Need to Run this script Once after the first successful training job to:
1. Create a baseline from training data
2. Schedule dailt monitoring against live prediction captures

Usage:
    python sagemaker/model_monitor.py
"""

import os
import logging
import boto3

from sagemaker.model_monitor import DefaultModelMonitor, CronExpressionGenerator
from sagemaker.model_monitor.dataset_format import DatasetFormat

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger(__name__)

def create_baseline(monitor: DefaultModelMonitor, bucket: str, region: str):
    """
    Run a Sagemaker baseline job against the training features CSV.
    This generates statistics.json and constraints.json in S3 - 
    the reference point for all future drift comparisons.
    """

    baseline_data_uri = f"s3://{bucket}/wine-quality/data/train_features.csv"
    baseline_results_uri = f"s3://{bucket}/wine-quality/monitor/baseline_results"

    logger.info("Creating Model Monitor baseline - this takes ~5 minutes...")

    monitor.suggest_baseline(
        baseline_dataset = baseline_data_uri,
        dataset_format = DatasetFormat.csv(header = True),
        output_s3_uri = baseline_results_uri,
        wait = True,
        logs = True
    )

    logger.info(f"Baseline created at: {baseline_results_uri}")
    return baseline_results_uri

def create_monitoring_schedule(monitor: DefaultModelMonitor, bucket: str, baseline_results_uri: str):
    """
    Schedule daily monitoring job.
    Compares prediction captures (logged by Flask app) against baseline.
    """

    capture_s3_uri = f"s3://{bucket}/wine-quality/prediction-captures"
    monitor_s3_uri = f"s3://{bucket}/wine-quality/monitor/reports"

    monitor.create_monitoring_schedule(
        monitor_schedule_name = "wine-quality-data-monitor",
        endpoint_input = capture_s3_uri,
        output_s3_uri = monitor_s3_uri,
        statistics = f"{baseline_results_uri}/stastistics.json",
        constraints = f"{baseline_results_uri}/constraints.json",
        schedule_cron_expression = CronExpressionGenerator.daily(),
        enable_cloudwatch_metrics = True
    )

    logger.info("Monitoring schedule created: wine-quality-data-monitor (runs daily)")


def create_cloudwatch_alarm(bucket: str, region: str):
    """Create a CloudWatch alarm that fires when drift is detected."""

    cw = boto3.client("cloudwatch", region_name = region)
    sns = boto3.client("sns", region_name = region)
    #accou

    # Create SNS topic for alerts
    topic_response = sns.create_topic(Name = "wine-quality-monitor-alerts")
    topic_arn = topic_response["TopicArn"]
    logger.info(f"SNS topic: {topic_arn}")
    logger.info("Subscribe your email to this SNS topic in the AWS Console to receive alerts")

    # Cloudwatch alarm on SageMaker Model Monitor metric
    cw.put_metric_alarm(
        AlarmName = "WineQualityModelDriftDetected"
        AlarmDescription = "Fires when Model Monitor detects data drift in wine quality predictions",
        Namespace = "aws/sagemaker/Endpoints/data-metrics",
        MetricName = "feature_baseline_drift_distance",
        Dimensions = [{
            "Name": "MonitoringSchedule",
            "Value": "wine-quality-data-monitor"
        }],
        Statistic = "Average",
        Period = 86400,  # 1 day
        EvaluationPeriods = 1,
        Threshold = 1.0  # 1 violation triggers alarm
        ComparisonOperator = "GreaterThanOrEqualToThreshold",
        AlarmActions = [topic_arn],
        TreatMissingData = "notBreaching"
    )

    logger.info("CloudWatch alarm created: WineQualityModelDriftDetected")
    return topic_arn


def main():
    region = os.environ["AWS_DEFAULT_REGION"]
    role_arn = os.environ["SAGEMAKER_ROLE_ARN"]
    bucket = os.environ["SAGEMAKER_BUCKET"]

    monitor = DefaultModelMonitor(
        role = role_arn,
        instance_count = 1,
        instance_type = "ml.m5.xlarge",
        volume_size_in_gb = 20,
        max_runtime_in_seconds = 3600,
        sagemaker_session = None
    )

    # Step 1 - Create baseline from training features
    baseline_results_uri = create_baseline(monitor, bucket, region)

    # Step 2 - Schedule daily monitoring
    create_monitoring_schedule(monitor, bucket, baseline_results_uri)

    # Step 3 - Create CloudWatch alarm + SNS alert
    topic_arn = create_cloudwatch_alarm(bucket, region)

    print("\n" + "="*10)
    print("Model Monitor setup complete !")
    print(f"Baseline results : s3://{bucket}/wine-quality/monitor/baseline_results")
    print(f"Monitor reports  : s3://{bucket}/wine-quality/monitor/reports")
    print(f"SNS topic        : {topic_arn}")
    print("Next step: subscribe your email to the SNS topic in AWS Console")
    print("="*5)

if __name__ == "__main__":
    main()