# ---------- Build stage (packages Spring Boot + Angular) ----------
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app

# copy everything (node_modules/target are excluded via .dockerignore)
COPY . .

# make wrapper executable
RUN chmod +x mvnw

# if sonar-project.properties is missing, create a tiny stub so the plugin doesn't fail
RUN [ -f sonar-project.properties ] || printf \
"sonar.projectKey=heart-risk-app\nsonar.projectName=heart-risk-app\nsonar.sources=src/main\n" \
> sonar-project.properties

# JHipster prod build (bundles Angular into the jar)
RUN ./mvnw -Pprod -DskipTests package

# ---------- Runtime stage ----------
FROM eclipse-temurin:21-jre-jammy AS runtime
ENV SPRING_PROFILES_ACTIVE=prod \
    SERVER_PORT=8080

# OPTIONAL: Python for your predictor (keep if your app shells out to Python)
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-venv python3-pip && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# copy ML scripts + artifacts if you keep them here; adjust path if needed
COPY src/main/resources/ml /app/ml

# OPTIONAL: install inference deps if you have a requirements.txt
RUN if [ -f /app/ml/requirements.txt ]; then \
      python3 -m venv /app/venv && \
      /app/venv/bin/pip install --no-cache-dir -U pip && \
      /app/venv/bin/pip install --no-cache-dir -r /app/ml/requirements.txt ; \
    fi

# let Spring know how to call the predictor (match your code)
ENV ML_PY_CMD="/app/venv/bin/python /app/ml/predict_heart_risk.py"

# copy the packaged app
COPY --from=build /app/target/*.jar /app/app.jar

EXPOSE 8080
CMD ["sh","-c","java ${JAVA_OPTS} -jar /app/app.jar"]
