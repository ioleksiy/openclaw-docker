# Dockerfile Customization Guide

This document explains how to maintain the custom Dockerfile when the upstream OpenClaw Dockerfile changes.

## Current Customizations

The custom Dockerfile is based on the upstream OpenClaw Dockerfile with the following additions:

### 1. Himalaya Email CLI (Multi-arch)
**Location:** After `WORKDIR /app` and `ARG OPENCLAW_DOCKER_APT_PACKAGES` section  
**Purpose:** Multi-architecture email client for command-line email management  
**Version:** v1.1.0  
**Architectures:** x86_64-linux (amd64), aarch64-linux (arm64)

```dockerfile
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "amd64" ]; then \
      HIMALAYA_ARCH="x86_64-linux"; \
    elif [ "$ARCH" = "arm64" ]; then \
      HIMALAYA_ARCH="aarch64-linux"; \
    else \
      echo "Unsupported arch: $ARCH" && exit 1; \
    fi && \
    curl -sSL "https://github.com/pimalaya/himalaya/releases/download/v1.1.0/himalaya.${HIMALAYA_ARCH}.tgz" | tar xz -C /usr/local/bin/
```

### 2. mcporter (via pnpm)
**Location:** After Himalaya installation  
**Purpose:** Minecraft porter tool  
**Installation method:** pnpm global package  
**Note:** Requires PNPM_HOME environment variable and directory creation

```dockerfile
ENV PNPM_HOME="/root/.local/share/pnpm"
ENV PATH="$PNPM_HOME:${PATH}"
RUN mkdir -p $PNPM_HOME && pnpm add -g mcporter
```

### 3. uv (Python Package Installer)
**Location:** After mcporter installation  
**Purpose:** Fast Python package installer and resolver from Astral  
**Path addition:** `/root/.cargo/bin` added to PATH

```dockerfile
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.cargo/bin:${PATH}"
```

### 4. nano-pdf (via uv)
**Location:** After uv installation  
**Purpose:** PDF processing tool  
**Installation method:** uv tool  
**Note:** Installation failure is allowed to continue (non-blocking)

```dockerfile
RUN uv tool install nano-pdf || echo "nano-pdf installation failed, continuing..."
```

### 5. Chromium + Playwright
**Location:** After nano-pdf, before COPY commands  
**Purpose:** Browser automation for web scraping and testing  
**Components:**
- Chromium browser with driver
- Playwright automation library
- Required system dependencies and fonts
- Pre-configured environment variables

```dockerfile
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    chromium chromium-driver fonts-liberation fonts-noto-color-emoji \
    libasound2 libatk-bridge2.0-0 libatk1.0-0 libatspi2.0-0 libcups2 \
    libdbus-1-3 libdrm2 libgbm1 libgtk-3-0 libnspr4 libnss3 \
    libx11-xcb1 libxcomposite1 libxdamage1 libxfixes3 libxkbcommon0 \
    libxrandr2 xdg-utils && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

RUN npm install -g playwright && \
    npx playwright install chromium --with-deps

ENV CHROME_BIN=/usr/bin/chromium
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium
```

### 6. openclaw CLI Wrapper
**Location:** After build steps, before USER node  
**Purpose:** Convenience wrapper for running OpenClaw commands  
**Path:** `/usr/local/bin/openclaw`  
**Note:** Must be created before switching to node user

```dockerfile
RUN printf '#!/bin/sh\ncd /app && node openclaw.mjs "$@"\n' > /usr/local/bin/openclaw && \
    chmod +x /usr/local/bin/openclaw
```

## How to Update When Upstream Changes

When the upstream OpenClaw Dockerfile is updated, follow these steps:

### Step 1: Fetch the Latest Upstream Dockerfile

```bash
curl -o Dockerfile.upstream https://raw.githubusercontent.com/openclaw/openclaw/refs/heads/main/Dockerfile
```

### Step 2: Identify the Insertion Point

Open the upstream Dockerfile and find the section after:
- `WORKDIR /app`
- `ARG CLAWDBOT_DOCKER_APT_PACKAGES=""`
- The conditional APT packages installation block

This is where all custom installations should be inserted.

### Step 3: Add Custom Sections

Insert all custom sections in this order **BEFORE** the `COPY package.json` line:
1. Himalaya email CLI
2. mcporter (via pnpm)
3. uv Python installer
4. nano-pdf (via uv)
5. Chromium + Playwright (browser automation)

Then, **AFTER** all build steps but **BEFORE** `USER node`:
6. openclaw CLI wrapper

```dockerfile
# Custom tools here (sections 1-5)
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
# ... build steps ...
# openclaw CLI wrapper here (section 6)
USER node
```

### Step 4: Update the Header

Update the header section at the top of the Dockerfile:
```dockerfile
# =============================================================================
# CUSTOM DOCKERFILE FOR OPENCLAW
# =============================================================================
# Based on: https://raw.githubusercontent.com/openclaw/openclaw/refs/heads/main/Dockerfile
# Last synced: YYYY-MM-DD  # <-- Update this date
#
# CUSTOM ADDITIONS (search for "CUSTOM:" comments):
# 1. Himalaya email CLI - Multi-arch email client (x86_64/aarch64)
# 2. mcporter - Minecraft porter tool (via pnpm)
# 3. uv - Python package installer (from Astral)
# 4. nano-pdf - PDF processing tool (via uv)
# 5. Chromium + Playwright - Browser automation for web scraping and testing
# 6. openclaw CLI wrapper - Convenience wrapper for running openclaw commands
# =============================================================================
```

### Step 5: Verify Structure

Ensure the final Dockerfile has this structure:

```
1. Header with customization documentation
2. FROM node:22-bookworm
3. Install Bun
4. Enable corepack
5. WORKDIR /app
6. ARG OPENCLAW_DOCKER_APT_PACKAGES
7. Conditional APT packages installation
8. ⭐ CUSTOM: Himalaya installation
9. ⭐ CUSTOM: mcporter installation
10. ⭐ CUSTOM: uv installation
11. ⭐ CUSTOM: nano-pdf installation
12. ⭐ CUSTOM: Chromium + Playwright installation
13. COPY package files
14. pnpm install
15. COPY all source
16. Build steps
17. UI build steps
18. ENV NODE_ENV=production
19. ⭐ CUSTOM: openclaw CLI wrapper
20. USER node (security)
21. CMD ["node", "dist/index.js"]
```

## Quick Update Script

You can use this script to semi-automate the update process:

```bash
#!/bin/bash
# update-dockerfile.sh

echo "Fetching latest upstream Dockerfile..."
curl -o Dockerfile.upstream https://raw.githubusercontent.com/openclaw/openclaw/refs/heads/main/Dockerfile

echo ""
echo "Please manually:"
echo "1. Open Dockerfile.upstream"
echo "2. Find the line: 'ARG CLAWDBOT_DOCKER_APT_PACKAGES' section"
echo "3. Copy all CUSTOM sections from current Dockerfile"
echo "4. Insert them after the APT packages conditional block"
echo "5. Update the 'Last synced' date in the header"
echo "6. Save as Dockerfile"
echo ""
echo "Upstream file saved as: Dockerfile.upstream"
```

## Verification

After updating, verify that all tools are present:

```bash
docker build -t test-openclaw .
docker run --rm test-openclaw /bin/bash -c "
  echo '=== Checking installed tools ===' && \
  himalaya --version && \
  mcporter --version && \
  uv --version && \
  uv tool list && \
  chromium --version && \
  npx playwright --version && \
  which openclaw
"
```

## Common Issues

### Issue: USER node prevents tool installation
**Solution:** All custom tools must be installed **before** the `USER node` line. They require root privileges to install to system directories.

### Issue: PATH not preserved for node user
**Solution:** Ensure PATH environment variables are set **before** `USER node` line so they persist for the node user.

### Issue: Architecture detection fails
**Solution:** The Himalaya installation uses `dpkg --print-architecture`. Ensure this runs during build, not at runtime.

## Maintaining This Document

When adding new customizations:
1. Add the tool to the "Current Customizations" section above
2. Update the header template in "Step 4"
3. Update the structure verification in "Step 5"
4. Update the verification script with the new tool check
