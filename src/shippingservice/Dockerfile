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
    go build -ldflags="-w -s" -o /shippingservice .

# ============================================================
# Stage 2 — Runtime
# ============================================================
FROM gcr.io/distroless/static-debian12:nonroot

WORKDIR /app

COPY --from=builder /shippingservice .

USER nonroot:nonroot

EXPOSE 50051

ENTRYPOINT ["/app/shippingservice"]
