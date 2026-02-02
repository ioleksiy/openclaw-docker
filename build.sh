#!/bin/bash
set -e

# Usage: ./build.sh <tag> [isLatest]
#   tag      - REQUIRED: Git tag to build ("latest" for main branch, or e.g., "v2026.1.30")
#   isLatest - OPTIONAL: If "true", also tag image as "latest" (default: "false")
#
# Examples:
#   ./build.sh latest             # Build from main branch, tag as "latest"
#   ./build.sh latest true        # Build from main branch, tag as "latest" (same as above)
#   ./build.sh v2026.1.30         # Build tag v2026.1.30, tag image as "v2026.1.30"
#   ./build.sh v2026.1.30 true    # Build tag v2026.1.30, tag image as both "v2026.1.30" and "latest"

# Parse parameters
TAG="$1"
IS_LATEST="${2:-false}"

# Validate required parameters
if [ -z "$TAG" ]; then
    echo -e "\033[0;31mError: tag parameter is required\033[0m"
    echo ""
    echo "Usage: ./build.sh <tag> [isLatest]"
    echo ""
    echo "Examples:"
    echo "  ./build.sh latest              # Build from main branch"
    echo "  ./build.sh v2026.1.30          # Build specific version"
    echo "  ./build.sh v2026.1.30 true     # Build specific version and tag as latest"
    exit 1
fi

# Configuration
REPO_URL="https://github.com/openclaw/openclaw.git"
REPO_DIR="openclaw"
DOCKER_IMAGE="ioleksiy/openclaw"
PLATFORMS="linux/amd64,linux/arm64"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Custom OpenClaw Docker Builder${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Tag: ${GREEN}${TAG}${NC}"
echo -e "Also tag as latest: ${GREEN}${IS_LATEST}${NC}"
echo ""

# Step 1: Clone or update openclaw repository
if [ -d "$REPO_DIR" ]; then
    echo -e "${YELLOW}Updating existing openclaw repository...${NC}"
    cd "$REPO_DIR"
    git fetch origin
    
    if [ "$TAG" = "latest" ]; then
        echo -e "${YELLOW}Checking out latest main branch...${NC}"
        git reset --hard origin/main
    else
        echo -e "${YELLOW}Checking out tag ${TAG}...${NC}"
        git reset --hard "tags/${TAG}"
    fi
    
    git clean -fdx
    cd ..
else
    echo -e "${YELLOW}Cloning openclaw repository...${NC}"
    git clone "$REPO_URL" "$REPO_DIR"
    
    if [ "$TAG" != "latest" ]; then
        echo -e "${YELLOW}Checking out tag ${TAG}...${NC}"
        cd "$REPO_DIR"
        git checkout "tags/${TAG}"
        cd ..
    fi
fi

if [ "$TAG" = "latest" ]; then
    echo -e "${GREEN}✓ Repository updated to latest main branch${NC}"
else
    echo -e "${GREEN}✓ Repository updated to tag ${TAG}${NC}"
fi
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
echo -e "${YELLOW}Image: ${DOCKER_IMAGE}:${TAG}${NC}"
if [ "$IS_LATEST" = "true" ]; then
    echo -e "${YELLOW}Also tagging as: ${DOCKER_IMAGE}:latest${NC}"
fi
echo ""

cd "$REPO_DIR"

# Build the base tag
BUILD_TAGS="-t ${DOCKER_IMAGE}:${TAG}"

# Add latest tag if requested
if [ "$IS_LATEST" = "true" ]; then
    BUILD_TAGS="${BUILD_TAGS} -t ${DOCKER_IMAGE}:latest"
fi

docker buildx build \
  --platform "$PLATFORMS" \
  --build-arg CLAWDBOT_DOCKER_APT_PACKAGES="git gh jq curl wget unzip ffmpeg imagemagick poppler-utils python3 python3-pip" \
  ${BUILD_TAGS} \
  --push \
  -f Dockerfile .

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ Build completed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Image: ${GREEN}${DOCKER_IMAGE}:${TAG}${NC}"
if [ "$IS_LATEST" = "true" ]; then
    echo -e "Also tagged as: ${GREEN}${DOCKER_IMAGE}:latest${NC}"
fi
echo -e "Platforms: ${GREEN}${PLATFORMS}${NC}"
echo ""
echo -e "Additional tools installed:"
echo -e "  • ${GREEN}himalaya${NC} - Email CLI"
echo -e "  • ${GREEN}mcporter${NC} - via pnpm"
echo -e "  • ${GREEN}uv${NC} - Python package installer"
echo -e "  • ${GREEN}nano-pdf${NC} - via uv"
echo -e "  • ${GREEN}nano-banana-pro${NC} - via uv"
echo ""
