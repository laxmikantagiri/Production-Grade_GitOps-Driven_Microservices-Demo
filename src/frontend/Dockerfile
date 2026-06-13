# syntax=docker/dockerfile:1
# ============================================================
# Stage 1 — Build
# ============================================================
FROM golang:1.25-alpine AS builder

WORKDIR /app

# Install git (needed for go mod download with some deps)
RUN apk add --no-cache git ca-certificates

# Copy dependency files first (layer cache — only re-runs when go.mod/go.sum change)
COPY go.mod go.sum ./
RUN go mod download

# Copy source
COPY . .

# Build a statically linked binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags="-w -s" -o /frontend .

# ============================================================
# Stage 2 — Runtime (minimal)
# ============================================================
FROM gcr.io/distroless/static-debian12:nonroot

WORKDIR /app

# Copy binary from builder
COPY --from=builder /frontend .

# Copy static assets and templates required at runtime
COPY --from=builder /app/static ./static
COPY --from=builder /app/templates ./templates

# distroless/nonroot runs as uid 65532 by default — no root
USER nonroot:nonroot

EXPOSE 8080

ENTRYPOINT ["/app/frontend"]
