# =============================================================================
# CUSTOM DOCKERFILE FOR MOLTBOT
# =============================================================================
# Based on: https://raw.githubusercontent.com/moltbot/moltbot/refs/heads/main/Dockerfile
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

ARG CLAWDBOT_DOCKER_APT_PACKAGES=""
RUN if [ -n "$CLAWDBOT_DOCKER_APT_PACKAGES" ]; then \
      apt-get update && \
      DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $CLAWDBOT_DOCKER_APT_PACKAGES && \
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

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY ui/package.json ./ui/package.json
COPY patches ./patches
COPY scripts ./scripts

RUN pnpm install --frozen-lockfile

COPY . .
RUN CLAWDBOT_A2UI_SKIP_MISSING=1 pnpm build

# Force pnpm for UI build (Bun may fail on ARM/Synology architectures)
ENV CLAWDBOT_PREFER_PNPM=1
RUN pnpm ui:install
RUN pnpm ui:build

ENV NODE_ENV=production

# =============================================================================
# CUSTOM: Create moltbot CLI wrapper
# =============================================================================
RUN printf '#!/bin/sh\ncd /app && node moltbot.mjs "$@"\n' > /usr/local/bin/moltbot && \
    chmod +x /usr/local/bin/moltbot

# Security hardening: Run as non-root user
# The node:22-bookworm image includes a 'node' user (uid 1000)
# This reduces the attack surface by preventing container escape via root privileges
USER node

CMD ["node", "dist/index.js"]
