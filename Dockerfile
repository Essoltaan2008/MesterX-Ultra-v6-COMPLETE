# MesterX Ultra Enterprise v6 — Railway Deployment
# Extracts ZIP, builds .NET 8 backend + Next.js 14 frontend, then starts both.

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# ── System dependencies ────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y \
    unzip \
    curl \
    wget \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# ── .NET 8 ─────────────────────────────────────────────────────────────────────
RUN wget https://dot.net/v1/dotnet-install.sh -O dotnet-install.sh && \
    chmod +x dotnet-install.sh && \
    ./dotnet-install.sh --version 8.0 --install-dir /usr/local/dotnet && \
    ln -s /usr/local/dotnet/dotnet /usr/local/bin/dotnet && \
    rm dotnet-install.sh

ENV DOTNET_ROOT=/usr/local/dotnet
ENV PATH="${PATH}:/usr/local/dotnet"

# ── Node.js 20 ─────────────────────────────────────────────────────────────────
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# ── Working directory ──────────────────────────────────────────────────────────
WORKDIR /app

# Copy everything (ZIP + any other repo files)
COPY . .

# ── Extract ZIP ────────────────────────────────────────────────────────────────
# The ZIP contains a top-level directory; move its contents up to /app.
RUN unzip -q MesterX-Ultra-v6-COMPLETE.zip && \
    EXTRACTED=$(unzip -Z1 MesterX-Ultra-v6-COMPLETE.zip | head -1 | cut -d/ -f1) && \
    if [ -n "$EXTRACTED" ] && [ -d "$EXTRACTED" ]; then \
        cp -r "$EXTRACTED"/. . && \
        rm -rf "$EXTRACTED"; \
    fi && \
    rm -f MesterX-Ultra-v6-COMPLETE.zip

# ── Build Backend (.NET 8) ─────────────────────────────────────────────────────
RUN if [ -f "backend/MesterX.csproj" ]; then \
        echo "▶ Building .NET backend..." && \
        cd backend && \
        dotnet restore && \
        dotnet publish -c Release -o /app/backend/publish && \
        cd ..; \
    else \
        echo "⚠ backend/MesterX.csproj not found — skipping .NET build"; \
    fi

# ── Build Frontend (Next.js 14) ────────────────────────────────────────────────
RUN if [ -f "frontend/package.json" ]; then \
        echo "▶ Building Next.js frontend..." && \
        cd frontend && \
        npm ci --prefer-offline && \
        npm run build && \
        cd ..; \
    else \
        echo "⚠ frontend/package.json not found — skipping Next.js build"; \
    fi

# ── Database note ──────────────────────────────────────────────────────────────
RUN if [ -f "database/schema.sql" ]; then \
        echo "✔ database/schema.sql found — will be applied at runtime via start.sh"; \
    fi

# ── Permissions ────────────────────────────────────────────────────────────────
RUN chmod +x start.sh

# Railway injects PORT; expose the two internal ports as documentation.
EXPOSE 5000 3000

CMD ["./start.sh"]
