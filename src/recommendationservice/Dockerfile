# syntax=docker/dockerfile:1
# ============================================================
# Stage 1 — Build/install dependencies
# ============================================================
FROM python:3.12-slim AS builder

WORKDIR /app

# Install pip dependencies into a prefix dir for clean copy
RUN pip install --upgrade pip
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ============================================================
# Stage 2 — Runtime
# ============================================================
FROM python:3.12-slim

WORKDIR /app

# Create non-root user
RUN groupadd -r appgroup && useradd -r -g appgroup appuser

# Copy installed packages from builder
COPY --from=builder /install /usr/local

# Copy application source
COPY . .

RUN chown -R appuser:appgroup /app

USER appuser

EXPOSE 8080

ENTRYPOINT ["python", "recommendation_server.py"]
