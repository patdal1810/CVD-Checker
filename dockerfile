# =========================================================
# 1) CLIENT BUILD (Angular)
# =========================================================
FROM node:20-bullseye AS client-build
ENV HUSKY=0 \
    CI=true \
    npm_config_audit=false \
    npm_config_fund=false \
    NPM_CONFIG_LOGLEVEL=warn \
    NODE_OPTIONS=--max-old-space-size=2048
WORKDIR /app

# Install deps first for caching
COPY package.json package-lock.json* ./
RUN npm ci --no-audit --no-fund

# Copy the rest and build the webapp (JHipster script)
COPY . .
RUN npm run webapp:prod


# =========================================================
# 2) SERVER BUILD (Spring Boot) — package jar without rebuilding client
# =========================================================
FROM maven:3.9-eclipse-temurin-21 AS server-build
WORKDIR /app
COPY . .

# Make wrapper executable
RUN chmod +x mvnw

# If sonar file is missing, create a stub so the plugin won't fail
RUN [ -f sonar-project.properties ] || printf \
"sonar.projectKey=heart-risk-app\nsonar.projectName=heart-risk-app\nsonar.sources=src/main\n" \
> sonar-project.properties

# Bring over the built static assets from the client stage
# (so mvn -DskipClient won't rebuild the UI)
RUN mkdir -p /app/src/main/resources/static
COPY --from=client-build /app/target/classes/static /app/src/main/resources/static

# Package the Spring Boot jar for prod
RUN ./mvnw -Pprod -DskipClient -DskipTests package


# =========================================================
# 3) RUNTIME — TensorFlow + Java 21 (no TF pip install)
# =========================================================
# CPU image with Python + TensorFlow (2.16.1) preinstalled
FROM tensorflow/tensorflow:2.16.1 AS runtime

# Install Java 21 JRE
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates && \
    curl -L -o /tmp/jre.tar.gz \
      https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.4%2B7/OpenJDK21U-jre_x64_linux_hotspot_21.0.4_7.tar.gz && \
    mkdir -p /opt/java && tar -xzf /tmp/jre.tar.gz -C /opt/java --strip-components=1 && \
    rm -rf /var/lib/apt/lists/* /tmp/jre.tar.gz
ENV JAVA_HOME=/opt/java
ENV PATH="$JAVA_HOME/bin:${PATH}"

# App/runtime env
ENV SPRING_PROFILES_ACTIVE=prod \
    SERVER_PORT=8080 \
    PYTHONUNBUFFERED=1 \
    ML_PYTHON=python \
    ML_PY_CMD="python /app/ml/predict_heart_risk.py"

WORKDIR /app

# Copy ML code & artifacts (ct.joblib, train_columns.json, heart_model.keras, predict_heart_risk.py, requirements.txt)
COPY src/main/resources/ml /app/ml

# Install lightweight Python deps (TensorFlow is already in the base image)
# Ensure your /app/ml/requirements.txt does NOT list tensorflow
RUN python -m pip install --no-cache-dir -U pip && \
    python -m pip install --no-cache-dir pandas==2.2.2 joblib==1.4.2 scikit-learn==1.5.1 && \
    if [ -f /app/ml/requirements.txt ]; then \
      python -m pip install --no-cache-dir -r /app/ml/requirements.txt ; \
    fi

# Build-time sanity check — fail the image build if imports are missing
RUN python - <<'PY'
import pandas, joblib, sklearn, tensorflow
print("Python ML imports OK")
PY

# Copy packaged JAR from server stage
COPY --from=server-build /app/target/*.jar /app/app.jar

EXPOSE 8080
CMD ["sh","-c","java ${JAVA_OPTS} -jar /app/app.jar"]
