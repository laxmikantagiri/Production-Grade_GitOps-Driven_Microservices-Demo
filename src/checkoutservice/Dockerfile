FROM golang:1.25-alpine AS builder
RUN apk add --no-cache git ca-certificates
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags="-s -w" -o /checkoutservice .

FROM scratch AS runtime
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /checkoutservice /checkoutservice
USER 65532:65532
ENV PORT=5050
ENV DISABLE_PROFILER=1
EXPOSE 5050
ENTRYPOINT ["/checkoutservice"]
