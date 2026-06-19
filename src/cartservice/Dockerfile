FROM mcr.microsoft.com/dotnet/sdk:10.0-alpine AS builder
WORKDIR /app
COPY src/*.csproj ./
RUN dotnet restore -r linux-musl-x64
COPY src/ .
RUN dotnet publish \
    -c Release \
    -r linux-musl-x64 \
    --no-restore \
    --self-contained true \
    -p:PublishSingleFile=false \
    -o /publish

FROM mcr.microsoft.com/dotnet/aspnet:10.0-alpine AS runtime
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
WORKDIR /app
COPY --from=builder --chown=appuser:appgroup /publish .
USER appuser
ENV ASPNETCORE_HTTP_PORTS=7070
ENV DISABLE_PROFILER=1
EXPOSE 7070
ENTRYPOINT ["./cartservice"]
