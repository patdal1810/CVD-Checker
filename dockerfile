# =========================================================
# 1) CLIENT BUILD (Angular) — separate, reliable, fast cache
# =========================================================
FROM node:20-bullseye AS client-build
ENV HUSKY=0 \
    CI=true \
    npm_config_audit=false \
    npm_config_fund=false \
    NPM_CONFIG_LOGLEVEL=warn \
    NODE_OPTIONS=--max-old-space-size=2048

WORKDIR /app

# Copy only files needed to resolve deps first for better caching
COPY package.json package-lock.json* ./
# If your package.json lives at the repo root (JHipster default), this is correct.
# If it's in src/main/webapp/, move the two COPY lines accordingly:
# COPY src/main/webapp/package*.json ./src/main/webapp/

RUN npm ci --no-audit --no-fund

# Now copy the rest of the repo (Angular sources etc.)
COPY . .

# Build Angular for production. In JHipster this script emits to target/classes/static
RUN npm run webapp:prod

# =========================================================
# 2) SERVER BUILD (Spring Boot) — skip client, package JAR
# =========================================================
FROM maven:3.9-eclipse-temurin-21 AS server-build
WORKDIR /app

# Bring in the full project
COPY . .

# Make wrapper executable
RUN chmod +x mvnw

# If sonar-project.properties is missing, create a safe stub so the properties plugin won't fail
RUN [ -f sonar-project.properties ] || printf \
"sonar.projectKey=heart-risk-app\nsonar.projectName=heart-risk-app\nsonar.sources=src/main\n" \
> sonar-project.properties

# Copy the already-built static assets into resources
# This ensures the JAR contains the Angular build, while we skip the frontend plugin
COPY --from=client-build /app/target/classes/static /app/src/main/resources/static

# Package the Spring Boot app, skipping client + tests
RUN ./mvnw -Pprod -DskipClient -DskipTests package

# =========================================================
# 3) RUNTIME — small JRE image (+ optional Python for your predictor)
# =========================================================
FROM eclipse-temurin:21-jre-jammy AS runtime
ENV SPRING_PROFILES_ACTIVE=prod \
    SERVER_PORT=8080

# ---- OPTIONAL: Python for your ML predictor ----
# Keep this block if your app shells out to Python; remove if not needed.
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-venv python3-pip && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# If you ship ML scripts/artifacts with the app, copy them in:
# (adjust path if yours live elsewhere)
COPY src/main/resources/ml /app/ml

# If you need Python deps at runtime, drop a requirements.txt in src/main/resources/ml
RUN if [ -f /app/ml/requirements.txt ]; then \
      python3 -m venv /app/venv && \
      /app/venv/bin/pip install --no-cache-dir -U pip && \
      /app/venv/bin/pip install --no-cache-dir -r /app/ml/requirements.txt ; \
    fi

# Tell Spring how to call the predictor (match your code)
ENV ML_PY_CMD="/app/venv/bin/python /app/ml/predict_heart_risk.py"

# Copy packaged JAR from server-build
COPY --from=server-build /app/target/*.jar /app/app.jar

EXPOSE 8080
CMD ["sh","-c","java ${JAVA_OPTS} -jar /app/app.jar"]
