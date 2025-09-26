import sys, json, joblib, pandas as pd
from tensorflow.keras.models import load_model
from pathlib import Path

BASE = Path(__file__).resolve().parent
ART = BASE / "artifacts"

ct = joblib.load(ART / "ct.joblib")
with open(ART / "train_columns.json") as f:
    TRAIN_COLUMNS = json.load(f)
model = load_model(ART / "heart_model.keras")

def predict_risk(person, threshold=0.5):
    x = pd.DataFrame([person])
    x = pd.get_dummies(x).reindex(columns=TRAIN_COLUMNS, fill_value=0)
    x_t = ct.transform(x)
    p = float(model.predict(x_t, verbose=0).ravel()[0])
    return {"probability": p, "risk": "High" if p >= threshold else "Low"}

def main():
    payload = json.loads(sys.stdin.read() or "{}")
    person = payload.get("person", {})
    threshold = float(payload.get("threshold", 0.5))
    result = predict_risk(person, threshold)
    print(json.dumps(result))

if __name__ == "__main__":
    main()
