# syntax=docker/dockerfile:1
# ============================================================
# Stage 1 — Install dependencies
# ============================================================
FROM node:22-alpine AS deps

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --only=production

# ============================================================
# Stage 2 — Runtime
# ============================================================
FROM node:22-alpine

WORKDIR /app

RUN addgroup -S appgroup && adduser -S appuser -G appgroup

COPY --from=deps /app/node_modules ./node_modules
COPY . .

RUN chown -R appuser:appgroup /app

USER appuser

EXPOSE 50051

ENTRYPOINT ["node", "index.js"]
