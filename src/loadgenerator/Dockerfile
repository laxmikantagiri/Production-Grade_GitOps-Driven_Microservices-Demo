FROM python:3.12-slim AS builder
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM python:3.12-slim AS runtime
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser
WORKDIR /app
COPY --from=builder /install /usr/local
COPY --chown=appuser:appgroup . .
USER appuser
EXPOSE 8089
ENV LOCUST_HOST=""
ENV LOCUST_USERS=10
ENV LOCUST_SPAWN_RATE=1
CMD locust --headless -f locustfile.py \
    --host="${LOCUST_HOST}" \
    --users="${LOCUST_USERS}" \
    --spawn-rate="${LOCUST_SPAWN_RATE}"
