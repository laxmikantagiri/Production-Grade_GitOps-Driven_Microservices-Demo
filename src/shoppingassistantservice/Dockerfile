# syntax=docker/dockerfile:1
# ============================================================
# Stage 1 — Build
# ============================================================
FROM python:3.12-slim AS builder

WORKDIR /app

# Install system dependencies required for building some python packages
RUN apt-get update && apt-get install -y --no-install-recommends 
    build-essential 
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for caching
COPY requirements.txt .

# Install dependencies into a local directory
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ============================================================
# Stage 2 — Runtime
# ============================================================
FROM python:3.12-slim

WORKDIR /app

# Create a non-root user and group
RUN groupadd -r appgroup && useradd -r -g appgroup appuser

# Copy installed dependencies from builder
COPY --from=builder /install /usr/local

# Copy application source
COPY shoppingassistantservice.py .

# Ensure the application files are owned by the non-root user
RUN chown -R appuser:appgroup /app

# Use the non-root user
USER appuser

# Port the application listens on
EXPOSE 8080

# Run the application
ENTRYPOINT ["python", "shoppingassistantservice.py"]
