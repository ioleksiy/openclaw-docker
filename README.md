# OpenClaw Custom Docker Builder

This project provides a custom Docker builder for [OpenClaw](https://github.com/openclaw/openclaw) with additional tools and multi-architecture support.

## Features

- **Automated builds**: Pulls the latest main branch of OpenClaw on each build
- **Multi-architecture support**: Builds for both `linux/amd64` and `linux/arm64`
- **Enhanced tooling**: Includes additional tools not in the standard OpenClaw Docker image

## Additional Tools

### Himalaya Email CLI
Multi-architecture email client for managing emails from the command line.
- Version: v1.1.0
- Supported architectures: x86_64-linux, aarch64-linux

### mcporter
Installed globally via pnpm for Minecraft-related functionality.

### uv (Python Package Manager)
Fast Python package installer and resolver from Astral.

### nano-pdf
PDF processing tool installed via uv.

### nano-banana-pro
Advanced tool for nano-banana processing, installed via uv.

## Prerequisites

- Docker with buildx support
- Git
- Docker Hub account (or adjust the image name in [build.sh](build.sh))

## Quick Start

1. **Make the build script executable:**
   ```bash
   chmod +x build.sh
   ```

2. **Configure Docker image name** (optional):
   Edit [build.sh](build.sh) and change:
   ```bash
   DOCKER_IMAGE="ioleksiy/clawdbot-gateway"
   ```
   to your preferred image name.

3. **Run the build:**
   ```bash
   # Build from main branch (tagged as "latest")
   ./build.sh latest
   
   # Build a specific version tag
   ./build.sh v2026.1.30
   
   # Build a specific version and also tag as "latest"
   ./build.sh v2026.1.30 true
   ```

## Build Script Parameters

The build script requires one parameter and accepts one optional parameter:

```bash
./build.sh <tag> [isLatest]
```

- **tag** (REQUIRED): 
  - Use `latest` to build from the main branch
  - Use a version tag (e.g., `v2026.1.30`) to build from a specific OpenClaw release
  
- **isLatest** (OPTIONAL, default: `false`):
  - Set to `true` to tag the image as both the specified tag AND `latest`
  - Only applies when building a specific version tag

**Examples:**
```bash
# Build latest main branch
./build.sh latest

# Build specific version v2026.1.30
./build.sh v2026.1.30

# Build v2026.2.1 and also tag as latest
./build.sh v2026.2.1 true
```

## What the Build Script Does

1. **Clone/Update Repository**: Clones or fetches the OpenClaw repository
2. **Checkout Version**: Checks out the specified tag or latest main branch
3. **Replace Dockerfile**: Uses our custom Dockerfile with additional tools
4. **Setup Buildx**: Configures Docker buildx for multi-arch builds
5. **Build & Push**: Creates and pushes the multi-arch image to Docker Hub with appropriate tags

## GitHub Actions

This repository includes automated workflows for building and publishing Docker images to GitHub Container Registry.

### Build and Publish Image

Manually trigger a build via GitHub Actions:

1. Go to the **Actions** tab in this repository
2. Select **"Build and Publish Docker Image"** workflow
3. Click **"Run workflow"**
4. Enter parameters:
   - **tag**: Version to build (e.g., `latest`, `v2026.1.30`)
   - **isLatest**: Check to also tag as `latest`
5. Click **"Run workflow"**

The workflow will:
- Clone the OpenClaw repository at the specified tag
- Apply the custom Dockerfile
- Build for both linux/amd64 and linux/arm64
- Push to `ghcr.io/ioleksiy/openclaw-docker:TAG`

**Pull the image:**
```bash
docker pull ghcr.io/ioleksiy/openclaw-docker:v2026.1.30
```

### List Available Tags

To see available OpenClaw version tags for building:

1. Go to the **Actions** tab
2. Select **"List Available OpenClaw Tags"** workflow
3. Click **"Run workflow"**
4. View the workflow summary to see the latest 20 version tags

This workflow also runs daily to keep the tag list updated.

Alternatively, check tags directly at: https://github.com/openclaw/openclaw/tags

## Build Configuration

The build uses the following configuration:

```bash
Platforms: linux/amd64,linux/arm64
Base Image: node:22-slim
Packages: git gh jq curl wget unzip ffmpeg imagemagick poppler-utils python3 python3-pip
```

## Customization

### Updating the Dockerfile

When the upstream OpenClaw Dockerfile changes, refer to [CUSTOMIZATION.md](CUSTOMIZATION.md) for detailed instructions on how to update while preserving custom additions.

**Quick reference:**
1. Fetch the latest upstream Dockerfile
2. Insert custom sections after the `ARG CLAWDBOT_DOCKER_APT_PACKAGES` block
3. Update the "Last synced" date in the header
4. All custom sections are clearly marked with `CUSTOM:` comments

See [CUSTOMIZATION.md](CUSTOMIZATION.md) for the complete update process.

### Adding More APT Packages

Edit the `OPENCLAW_DOCKER_APT_PACKAGES` build arg in [build.sh](build.sh) (in the docker buildx build command).

### Adding More Tools

Add installation commands to [Dockerfile](Dockerfile) in the custom sections area (after APT packages, before COPY commands). Follow the existing patterns and add `CUSTOM:` comments.

See [CUSTOMIZATION.md](CUSTOMIZATION.md) for detailed guidelines.

### Changing Target Platforms

Edit the `PLATFORMS` variable in [build.sh](build.sh):

```bash
PLATFORMS="linux/amd64,linux/arm64,linux/arm/v7"
```

## Usage

After building (or using a pre-built image from GitHub Container Registry), you can run the container:

### Using Docker Hub image (built locally via build.sh):
```bash
docker run -d \
  -p 18789:18789 \
  -v ~/.clawdbot:/root/.clawdbot \
  ioleksiy/openclaw:latest
```

### Using GitHub Container Registry image (built via GitHub Actions):
```bash
docker run -d \
  -p 18789:18789 \
  -v ~/.clawdbot:/root/.clawdbot \
  ghcr.io/ioleksiy/openclaw-docker:latest
```

Or use with docker-compose:

```yaml
version: '3.8'
services:
  openclaw:
    # Use either Docker Hub or GitHub Container Registry
    image: ghcr.io/ioleksiy/openclaw-docker:latest
    # Or: image: ioleksiy/openclaw:latest
    ports:
      - "18789:18789"
    volumes:
      - ~/.clawdbot:/root/.clawdbot
    restart: unless-stopped
```

## Verification

Verify that all tools are installed:

```bash
# For GitHub Container Registry image:
docker run --rm ghcr.io/ioleksiy/openclaw-docker:latest /bin/bash -c "
  echo 'Checking installed tools...' && \
  himalaya --version && \
  mcporter --version && \
  uv --version && \
  uv tool list
"

# For Docker Hub image:
docker run --rm ioleksiy/openclaw:latest /bin/bash -c "
  echo 'Checking installed tools...' && \
  himalaya --version && \
  mcporter --version && \
  uv --version && \
  uv tool list
"
```

## Troubleshooting

### Build Fails on ARM64

Ensure your Docker Desktop or Docker Engine has ARM64 emulation enabled:
```bash
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
```

### Push Permission Denied

Make sure you're logged into Docker Hub:
```bash
docker login
```

### Buildx Not Found

Install buildx:
```bash
docker buildx install
```

## Contributing

Feel free to open issues or submit pull requests for improvements.

## License

This project follows the same license as OpenClaw (MIT).

## Related Links

- [OpenClaw GitHub Repository](https://github.com/openclaw/openclaw)
- [OpenClaw Documentation](https://docs.openclaw.ai/)
- [Docker Buildx Documentation](https://docs.docker.com/buildx/working-with-buildx/)
