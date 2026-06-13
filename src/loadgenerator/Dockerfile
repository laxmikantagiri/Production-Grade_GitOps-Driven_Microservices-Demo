# syntax=docker/dockerfile:1
# ============================================================
# Stage 1 — Install dependencies
# ============================================================
FROM python:3.12-slim AS builder

WORKDIR /app

RUN pip install --upgrade pip
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ============================================================
# Stage 2 — Runtime
# ============================================================
FROM python:3.12-slim

WORKDIR /app

RUN groupadd -r appgroup && useradd -r -g appgroup appuser

COPY --from=builder /install /usr/local

COPY . .

RUN chown -R appuser:appgroup /app

USER appuser

# FRONTEND_ADDR env var must be set at runtime
# e.g. FRONTEND_ADDR=frontend:80
ENV LOCUST_WEB_PORT=8089

EXPOSE 8089

ENTRYPOINT ["locust", "--host=http://$(FRONTEND_ADDR)", "-f", "locustfile.py", "--headless", "-u", "10", "-r", "1"]
