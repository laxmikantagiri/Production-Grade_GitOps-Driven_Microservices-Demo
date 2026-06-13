# syntax=docker/dockerfile:1
# ============================================================
# Stage 1 — Install dependencies
# ============================================================
FROM node:22-alpine AS deps

WORKDIR /app

# Copy package files first (layer cache)
COPY package.json package-lock.json ./
RUN npm ci --only=production

# ============================================================
# Stage 2 — Runtime
# ============================================================
FROM node:22-alpine

WORKDIR /app

# Create non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Copy installed node_modules from deps stage
COPY --from=deps /app/node_modules ./node_modules

# Copy application source
COPY . .

# Own files by non-root user
RUN chown -R appuser:appgroup /app

USER appuser

EXPOSE 7000

ENTRYPOINT ["node", "server.js"]
