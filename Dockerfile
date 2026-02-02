# =============================================================================
# CUSTOM DOCKERFILE FOR OPENCLAW
# =============================================================================
# Based on: https://raw.githubusercontent.com/openclaw/openclaw/refs/heads/main/Dockerfile
# Last synced: 2026-01-28
#
# CUSTOM ADDITIONS (search for "CUSTOM:" comments):
# 1. Himalaya email CLI - Multi-arch email client (x86_64/aarch64)
# 2. mcporter - Minecraft porter tool (via pnpm)
# 3. uv - Python package installer (from Astral)
# 4. nano-pdf - PDF processing tool (via uv)
# 5. nano-banana-pro - Banana processing tool (via uv)
#
# To update this file with a new upstream Dockerfile:
# 1. Replace everything from FROM to CMD with the new upstream content
# 2. Re-add the CUSTOM: sections below in the appropriate places
# 3. Update "Last synced" date above
# =============================================================================

FROM node:22-bookworm

# Install Bun (required for build scripts)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

RUN corepack enable

WORKDIR /app

ARG OPENCLAW_DOCKER_APT_PACKAGES=""
RUN if [ -n "$OPENCLAW_DOCKER_APT_PACKAGES" ]; then \
      apt-get update && \
      DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $OPENCLAW_DOCKER_APT_PACKAGES && \
      apt-get clean && \
      rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*; \
    fi

# =============================================================================
# CUSTOM: Install himalaya email CLI (multi-arch)
# =============================================================================
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "amd64" ]; then \
      HIMALAYA_ARCH="x86_64-linux"; \
    elif [ "$ARCH" = "arm64" ]; then \
      HIMALAYA_ARCH="aarch64-linux"; \
    else \
      echo "Unsupported arch: $ARCH" && exit 1; \
    fi && \
    curl -sSL "https://github.com/pimalaya/himalaya/releases/download/v1.1.0/himalaya.${HIMALAYA_ARCH}.tgz" | tar xz -C /usr/local/bin/

# =============================================================================
# CUSTOM: Setup pnpm global bin directory and install mcporter
# =============================================================================
ENV PNPM_HOME="/root/.local/share/pnpm"
ENV PATH="$PNPM_HOME:${PATH}"
RUN mkdir -p $PNPM_HOME && pnpm add -g mcporter

# =============================================================================
# CUSTOM: Install uv (Python package installer and resolver)
# =============================================================================
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    mv /root/.cargo/bin/uv /usr/local/bin/uv || mv /root/.local/bin/uv /usr/local/bin/uv || true

# =============================================================================
# CUSTOM: Install nano-pdf via uv
# Note: nano-banana-pro package doesn't exist in PyPI, removed
# =============================================================================
RUN uv tool install nano-pdf || echo "nano-pdf installation failed, continuing..."

# =============================================================================
# END CUSTOM ADDITIONS - Resume original Dockerfile content
# =============================================================================

# =============================================================================
# CUSTOM: Install Chromium + Playwright for browser automation
# =============================================================================

# Install Chromium dependencies
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    chromium \
    chromium-driver \
    # Fonts for proper rendering
    fonts-liberation \
    fonts-noto-color-emoji \
    # Additional libraries Chromium needs
    libasound2 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libatspi2.0-0 \
    libcups2 \
    libdbus-1-3 \
    libdrm2 \
    libgbm1 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libx11-xcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxkbcommon0 \
    libxrandr2 \
    xdg-utils \
    # Cleanup
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Install Playwright (with browsers)
RUN npm install -g playwright && \
    npx playwright install chromium --with-deps

# Set environment for headless Chrome
ENV CHROME_BIN=/usr/bin/chromium
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium

# =============================================================================
# END CUSTOM: Browser automation ready
# =============================================================================

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY ui/package.json ./ui/package.json
COPY patches ./patches
COPY scripts ./scripts

RUN pnpm install --frozen-lockfile

COPY . .

# Build with A2UI skip flag - some releases may not include A2UI sources
RUN OPENCLAW_A2UI_SKIP_MISSING=1 pnpm build || \
    (echo "Build failed, attempting without A2UI..." && \
     pnpm build --filter '!@openclaw/canvas-a2ui' || \
     (echo "Trying alternative build approach..." && \
      pnpm -r run build --if-present --workspace-concurrency=1))

# Force pnpm for UI build (Bun may fail on ARM/Synology architectures)
ENV OPENCLAW_PREFER_PNPM=1
RUN pnpm ui:install || echo "UI install step skipped or failed"
RUN pnpm ui:build || echo "UI build step skipped or failed"

ENV NODE_ENV=production

# =============================================================================
# CUSTOM: Create openclaw CLI wrapper
# =============================================================================
RUN printf '#!/bin/sh\ncd /app && node openclaw.mjs "$@"\n' > /usr/local/bin/openclaw && \
    chmod +x /usr/local/bin/openclaw

# Security hardening: Run as non-root user
# The node:22-bookworm image includes a 'node' user (uid 1000)
# This reduces the attack surface by preventing container escape via root privileges
USER node

CMD ["node", "dist/index.js"]
