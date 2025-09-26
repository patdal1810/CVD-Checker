# ---------- Build stage (packages Spring Boot + Angular) ----------
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app

# Leverage Docker cache for deps
COPY pom.xml ./
COPY .mvn .mvn
COPY mvnw mvnw
RUN chmod +x mvnw

# Copy sources last (so earlier layers cache)
COPY src src

# JHipster prod build (bundles Angular into the jar)
RUN ./mvnw -Pprod -DskipTests package

# ---------- Runtime stage ----------
FROM eclipse-temurin:21-jre-jammy AS runtime
ENV SPRING_PROFILES_ACTIVE=prod \
    SERVER_PORT=8080

# ----- OPTIONAL: Python for your predictor -----
# If your app calls a Python script at runtime, keep this block.
# Otherwise you can delete it.
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-venv python3-pip && rm -rf /var/lib/apt/lists/*

# Copy ML scripts + artifacts if you keep them under resources/ml
# Adjust if you store them elsewhere.
WORKDIR /app
COPY src/main/resources/ml /app/ml

# If you have a requirements.txt for inference deps, install them into a venv.
# If you don't, this will simply be skipped safely.
RUN if [ -f /app/ml/requirements.txt ]; then \
      python3 -m venv /app/venv && \
      /app/venv/bin/pip install --no-cache-dir -U pip && \
      /app/venv/bin/pip install --no-cache-dir -r /app/ml/requirements.txt ; \
    fi

# Tell your Spring service how to call the Python predictor (match what your code expects)
# Example env your app can read (adjust the path/venv if you changed it):
ENV ML_PY_CMD="/app/venv/bin/python /app/ml/predict_heart_risk.py"

# Copy the packaged application
COPY --from=build /app/target/*.jar /app/app.jar

EXPOSE 8080
CMD ["sh","-c","java ${JAVA_OPTS} -jar /app/app.jar"]
