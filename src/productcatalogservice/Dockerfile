# syntax=docker/dockerfile:1
# ============================================================
# Stage 1 — Build
# ============================================================
FROM golang:1.25-alpine AS builder

WORKDIR /app

RUN apk add --no-cache git ca-certificates

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags="-w -s" -o /productcatalogservice .

# ============================================================
# Stage 2 — Runtime
# ============================================================
FROM gcr.io/distroless/static-debian12:nonroot

WORKDIR /app

COPY --from=builder /productcatalogservice .
# products.json is loaded at runtime from this path
COPY --from=builder /app/products.json .

USER nonroot:nonroot

EXPOSE 3550

ENTRYPOINT ["/app/productcatalogservice"]
