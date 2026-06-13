# syntax=docker/dockerfile:1
# ============================================================
# Stage 1 — Build with Gradle
# ============================================================
FROM gradle:8.7-jdk21 AS builder

WORKDIR /app

# Copy Gradle wrapper and build files first (layer cache)
COPY gradlew gradlew.bat settings.gradle build.gradle ./
COPY gradle/ ./gradle/

# Download dependencies (cached layer — only invalidates when build.gradle changes)
RUN ./gradlew downloadRepos --no-daemon

# Copy source and build
COPY src/ ./src/
RUN ./gradlew installDist --no-daemon

# ============================================================
# Stage 2 — Runtime (Eclipse Temurin JRE — minimal JRE image)
# ============================================================
FROM eclipse-temurin:21-jre-alpine

WORKDIR /app

# Create non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Copy distribution from builder
COPY --from=builder /app/build/install/AdService/ .

RUN chown -R appuser:appgroup /app

USER appuser

EXPOSE 9555

ENTRYPOINT ["/app/bin/AdService"]
