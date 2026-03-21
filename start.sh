#!/bin/bash
# MesterX Ultra Enterprise v6 — unified process launcher for Railway
set -e

echo "🚀 Starting MesterX Ultra Enterprise v6..."

# ── Apply database schema (first boot) ────────────────────────────────────────
if [ -f "database/schema.sql" ] && [ -n "$DATABASE_URL" ]; then
    echo "🗄  Applying database schema..."
    # Requires psql; install it if not present
    if ! command -v psql &>/dev/null; then
        apt-get update -qq && apt-get install -y -qq postgresql-client && rm -rf /var/lib/apt/lists/*
    fi
    psql "$DATABASE_URL" -f database/schema.sql || echo "⚠  Schema apply failed (may already exist — continuing)"
fi

# ── Backend (.NET 8) ───────────────────────────────────────────────────────────
BACKEND_PID=""
if [ -f "backend/publish/MesterX.dll" ]; then
    echo "📦 Starting .NET Backend (published) on port 5000..."
    ASPNETCORE_URLS="http://0.0.0.0:5000" \
    ASPNETCORE_ENVIRONMENT="Production" \
    dotnet backend/publish/MesterX.dll &
    BACKEND_PID=$!
elif [ -f "backend/MesterX.csproj" ]; then
    echo "📦 Starting .NET Backend (dotnet run) on port 5000..."
    cd backend
    ASPNETCORE_URLS="http://0.0.0.0:5000" \
    ASPNETCORE_ENVIRONMENT="Production" \
    dotnet run --configuration Release --no-build &
    BACKEND_PID=$!
    cd ..
else
    echo "⚠  No .NET backend found — skipping"
fi

# ── Frontend (Next.js 14) ──────────────────────────────────────────────────────
FRONTEND_PID=""
if [ -f "frontend/package.json" ]; then
    echo "🎨 Starting Next.js Frontend on port 3000..."
    cd frontend
    PORT=3000 npm run start &
    FRONTEND_PID=$!
    cd ..
else
    echo "⚠  No Next.js frontend found — skipping"
fi

# ── Wait for all background processes ─────────────────────────────────────────
echo "✅ All services started. Waiting..."
wait $BACKEND_PID $FRONTEND_PID
