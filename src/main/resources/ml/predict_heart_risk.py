#!/usr/bin/env python3
import sys, json
from pathlib import Path

import joblib
import pandas as pd
from tensorflow.keras.models import load_model

BASE = Path(__file__).resolve().parent
ART = BASE / "artifacts"

# Load artifacts once
ct = joblib.load(ART / "ct.joblib")
with open(ART / "train_columns.json") as f:
    TRAIN_COLUMNS = json.load(f)
model = load_model(ART / "heart_model.keras")

# Base feature names used during training (before get_dummies)
BASE_FEATURES = [
    "age", "anaemia", "creatinine_phosphokinase", "diabetes", "ejection_fraction",
    "high_blood_pressure", "platelets", "serum_creatinine", "serum_sodium",
    "sex", "smoking", "time"
]

def _coerce_row(person: dict) -> pd.DataFrame:
    """
    Build a single-row DataFrame with the expected raw feature keys,
    coerce to numeric, then one-hot (no-op for numeric) and align columns.
    """
    # extract only known keys, defaulting to 0 if missing
    row = {k: person.get(k, 0) for k in BASE_FEATURES}
    df = pd.DataFrame([row])

    # coerce everything to numeric
    for c in df.columns:
        df[c] = pd.to_numeric(df[c], errors="coerce")
    df = df.fillna(0)

    # mimic training preprocessing
    df = pd.get_dummies(df)

    # align to training columns (add any missing with 0)
    df = df.reindex(columns=TRAIN_COLUMNS, fill_value=0)

    return df

def main():
    try:
        raw = sys.stdin.read()
        payload = json.loads(raw) if raw.strip() else {}
    except Exception as e:
        print(json.dumps({"error": f"Invalid JSON: {e}"}))
        sys.exit(1)

    # Accept either flat or nested payloads
    person = payload.get("person", payload)
    try:
        thr = float(payload.get("threshold", 0.5))
    except Exception:
        thr = 0.5

    try:
        X = _coerce_row(person)
        Xt = ct.transform(X)
        p = float(model.predict(Xt, verbose=0).ravel()[0])
        risk = "High" if p >= thr else "Low"
        print(json.dumps({"probability": p, "risk": risk}))
    except Exception as e:
        # Emit a compact error JSON so your Java code surfaces it in logs
        print(json.dumps({"error": f"prediction_failed: {e}"}))
        sys.exit(1)

if __name__ == "__main__":
    main()
