# syntax=docker/dockerfile:1
# ============================================================
# Stage 1 — Build
# ============================================================
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS builder

WORKDIR /app

# Copy solution and project files first (layer cache)
COPY cartservice.sln ./
COPY src/*.csproj ./src/
RUN dotnet restore src/cartservice.csproj

# Copy full source and publish
COPY src/ ./src/
RUN dotnet publish src/cartservice.csproj \
    -c Release \
    -o /publish \
    --no-restore

# ============================================================
# Stage 2 — Runtime
# ============================================================
FROM mcr.microsoft.com/dotnet/aspnet:10.0-noble-chiseled

WORKDIR /app

# chiseled images run as non-root (uid 1654) by default
COPY --from=builder /publish .

EXPOSE 7070

ENTRYPOINT ["dotnet", "cartservice.dll"]
