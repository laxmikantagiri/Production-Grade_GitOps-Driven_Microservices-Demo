FROM golang:1.25-alpine AS builder
RUN apk add --no-cache git ca-certificates
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags="-s -w" -o /frontend .

FROM gcr.io/distroless/static-debian12:nonroot AS runtime
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /frontend /frontend
COPY --chown=65532:65532 static/ /app/static/
COPY --chown=65532:65532 templates/ /app/templates/
WORKDIR /app
USER 65532:65532
ENV PORT=8080
ENV DISABLE_PROFILER=1
EXPOSE 8080
ENTRYPOINT ["/frontend"]
