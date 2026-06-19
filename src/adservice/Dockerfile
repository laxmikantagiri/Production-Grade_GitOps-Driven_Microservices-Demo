FROM eclipse-temurin:21-jdk-alpine AS deps
WORKDIR /app
COPY build.gradle settings.gradle ./
COPY gradle/ gradle/
COPY gradlew .
RUN chmod +x gradlew && \
    ./gradlew downloadRepos --no-daemon -q 2>/dev/null || true

FROM eclipse-temurin:21-jdk-alpine AS builder
WORKDIR /app
COPY --from=deps /root/.gradle /root/.gradle
COPY build.gradle settings.gradle ./
COPY gradle/ gradle/
COPY gradlew .
COPY src/ src/
RUN chmod +x gradlew && \
    ./gradlew installDist --no-daemon -q

FROM eclipse-temurin:21-jre-alpine AS runtime
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
WORKDIR /app
COPY --from=builder --chown=appuser:appgroup /app/build/install/hipstershop/ .
USER appuser
ENV PORT=9555
ENV DISABLE_PROFILER=1
EXPOSE 9555
ENTRYPOINT ["bin/AdService"]
