#!/bin/bash
set -e

# Configuration
REPO_URL="https://github.com/moltbot/moltbot.git"
REPO_DIR="moltbot"
DOCKER_IMAGE="ioleksiy/moltbot-docker"
DOCKER_TAG="latest"
PLATFORMS="linux/amd64,linux/arm64"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Custom Moltbot Docker Builder${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Step 1: Clone or update moltbot repository
if [ -d "$REPO_DIR" ]; then
    echo -e "${YELLOW}Updating existing moltbot repository...${NC}"
    cd "$REPO_DIR"
    git fetch origin
    git reset --hard origin/main
    git clean -fdx
    cd ..
else
    echo -e "${YELLOW}Cloning moltbot repository...${NC}"
    git clone "$REPO_URL" "$REPO_DIR"
fi

echo -e "${GREEN}✓ Repository updated to latest main branch${NC}"
echo ""

# Step 2: Copy our custom Dockerfile
echo -e "${YELLOW}Replacing Dockerfile with custom version...${NC}"
cp Dockerfile "$REPO_DIR/Dockerfile"
echo -e "${GREEN}✓ Custom Dockerfile in place${NC}"
echo ""

# Step 3: Setup Docker buildx if not already configured
echo -e "${YELLOW}Setting up Docker buildx...${NC}"
if ! docker buildx ls | grep -q "multiarch-builder"; then
    docker buildx create --name multiarch-builder --use
    docker buildx inspect --bootstrap
else
    docker buildx use multiarch-builder
fi
echo -e "${GREEN}✓ Docker buildx ready${NC}"
echo ""

# Step 4: Build and push multi-arch image
echo -e "${YELLOW}Starting multi-arch Docker build...${NC}"
echo -e "${YELLOW}Platforms: ${PLATFORMS}${NC}"
echo -e "${YELLOW}Image: ${DOCKER_IMAGE}:${DOCKER_TAG}${NC}"
echo ""

cd "$REPO_DIR"
docker buildx build \
  --platform "$PLATFORMS" \
  --build-arg CLAWDBOT_DOCKER_APT_PACKAGES="git gh jq curl wget unzip ffmpeg imagemagick poppler-utils python3 python3-pip" \
  -t "${DOCKER_IMAGE}:${DOCKER_TAG}" \
  --push \
  -f Dockerfile .

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ Build completed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Image: ${GREEN}${DOCKER_IMAGE}:${DOCKER_TAG}${NC}"
echo -e "Platforms: ${GREEN}${PLATFORMS}${NC}"
echo ""
echo -e "Additional tools installed:"
echo -e "  • ${GREEN}himalaya${NC} - Email CLI"
echo -e "  • ${GREEN}mcporter${NC} - via pnpm"
echo -e "  • ${GREEN}uv${NC} - Python package installer"
echo -e "  • ${GREEN}nano-pdf${NC} - via uv"
echo -e "  • ${GREEN}nano-banana-pro${NC} - via uv"
echo ""
