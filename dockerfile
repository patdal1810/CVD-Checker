# =========================================================
# 1) CLIENT BUILD (Angular) — fast & isolated
# =========================================================
FROM node:20-bullseye AS client-build
ENV HUSKY=0 \
    CI=true \
    npm_config_audit=false \
    npm_config_fund=false \
    NPM_CONFIG_LOGLEVEL=warn \
    NODE_OPTIONS=--max-old-space-size=2048
WORKDIR /app

# Install deps first for better caching
COPY package.json package-lock.json* ./
# If your package.json lives under src/main/webapp/, use:
# COPY src/main/webapp/package*.json ./src/main/webapp/

RUN npm ci --no-audit --no-fund

# Copy the rest of the project
COPY . .

# Build Angular for production (JHipster script)
RUN npm run webapp:prod


# =========================================================
# 2) SERVER BUILD (Spring Boot) — skip client, package JAR
# =========================================================
FROM maven:3.9-eclipse-temurin-21 AS server-build
WORKDIR /app
COPY . .

# Make wrapper executable
RUN chmod +x mvnw

# If sonar file is missing, create a safe stub to avoid plugin failure
RUN [ -f sonar-project.properties ] || printf \
"sonar.projectKey=heart-risk-app\nsonar.projectName=heart-risk-app\nsonar.sources=src/main\n" \
> sonar-project.properties

# Copy built static assets from client stage into resources so they land in the jar
# (JHipster's webapp:prod emits to target/classes/static)
COPY --from=client-build /app/target/classes/static /app/src/main/resources/static

# Package prod jar without rebuilding the client
RUN ./mvnw -Pprod -DskipClient -DskipTests package


# =========================================================
# 3) RUNTIME — TensorFlow + Java 21 (no TF pip install!)
# =========================================================

ENV ML_PYTHON=python


# CPU image with Python + TF preinstalled (2.16.1)
FROM tensorflow/tensorflow:2.16.1 AS runtime

# Add Java 21 JRE
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates && \
    curl -L -o /tmp/jre.tar.gz \
      https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.4%2B7/OpenJDK21U-jre_x64_linux_hotspot_21.0.4_7.tar.gz && \
    mkdir -p /opt/java && tar -xzf /tmp/jre.tar.gz -C /opt/java --strip-components=1 && \
    rm -rf /var/lib/apt/lists/* /tmp/jre.tar.gz
ENV JAVA_HOME=/opt/java
ENV PATH="$JAVA_HOME/bin:${PATH}"

ENV SPRING_PROFILES_ACTIVE=prod \
    SERVER_PORT=8080 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Copy ML code & artifacts (ct.joblib, train_columns.json, heart_model.keras, predict_heart_risk.py, requirements.txt)
COPY src/main/resources/ml /app/ml

# Install lightweight Python deps (TensorFlow already present in base image)
# Ensure your /app/ml/requirements.txt does NOT list tensorflow
RUN python -m pip install --no-cache-dir -U pip && \
    if [ -f /app/ml/requirements.txt ]; then \
      python -m pip install --no-cache-dir -r /app/ml/requirements.txt ; \
    fi

# Command your Java app uses to invoke the predictor
ENV ML_PY_CMD="python /app/ml/predict_heart_risk.py"

# Copy packaged JAR from server build
COPY --from=server-build /app/target/*.jar /app/app.jar

EXPOSE 8080
CMD ["sh","-c","java ${JAVA_OPTS} -jar /app/app.jar"]
