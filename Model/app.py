import os
import logging
import numpy as np
from flask import Flask, render_template, request
from prometheus_flask_exporter import PrometheusMetrics
from src.datascience.pipeline.prediction_pipeline import PredictionPipeline
from aws_sagemaker.prediction_capture import prediction_capture

app = Flask(__name__) # initializing a flask app
metrics = PrometheusMetrics(app) # exposes /metrics endpoint for Prometheus scraping

# Load model once at startup — not on every request
pipeline = PredictionPipeline()

# Input feature bounds for basic range validation
FEATURE_BOUNDS = {
    "fixed_acidity": (0.0, 20.0),
    "volatile_acidity": (0.0, 5.0),
    "citric_acid": (0.0, 2.0),
    "residual_sugar": (0.0, 100.0),
    "chlorides": (0.0, 1.0),
    "free_sulfur_dioxide": (0.0, 300.0),
    "total_sulfur_dioxide": (0.0, 500.0),
    "density": (0.9, 1.1),
    "pH": (2.0, 5.0),
    "sulphates": (0.0, 3.0),
    "alcohol": (0.0, 25.0),
}

@app.route("/", methods=["GET"])
def homePage():
    return render_template("index.html")

@app.route("/predict", methods=["POST", "GET"])
def index():
    if request.method == "POST":
        try:
            values = {}
            errors = []
            for field, (low, high) in FEATURE_BOUNDS.items():
                raw = request.form.get(field)
                if raw is None:
                    errors.append(f"Missing field: {field}")
                    continue
                try:
                    val = float(raw)
                except ValueError:
                    errors.append(f"'{field}' must be a number, got: {raw!r}")
                    continue
                if not (low <= val <= high):
                    errors.append(f"'{field}' value {val} out of expected range [{low}, {high}]")
                values[field] = val

            if errors:
                return render_template("index.html", errors=errors)

            data = np.array(list(values.values())).reshape(1, -1)
            predict = pipeline.predict(data)

            # Log to S3 for SageMaker Model Monitor (non-blocking)
            prediction_capture.capture(features=values, prediction=float(predict[0]))

            return render_template("results.html", prediction=f"{predict[0]:.2f}", **values)

        except Exception as e:
            logging.exception("Prediction failed")
            return render_template("index.html", errors=[f"Prediction error: {str(e)}"])

    return render_template("index.html")


if __name__ == "__main__":
    debug_mode = os.environ.get("FLASK_DEBUG", "false").lower() == "true"
    app.run(host="0.0.0.0", port=8080, debug=debug_mode)