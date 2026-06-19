FROM golang:1.25-alpine AS builder
RUN apk add --no-cache git ca-certificates
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags="-s -w" -o /productcatalogservice .

FROM scratch AS runtime
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /productcatalogservice /productcatalogservice
COPY products.json /products.json
USER 65532:65532
ENV PORT=3550
ENV DISABLE_PROFILER=1
EXPOSE 3550
ENTRYPOINT ["/productcatalogservice"]
