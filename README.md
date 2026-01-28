# Moltbot Custom Docker Builder

This project provides a custom Docker builder for [moltbot](https://github.com/moltbot/moltbot) with additional tools and multi-architecture support.

## Features

- **Automated builds**: Pulls the latest main branch of moltbot on each build
- **Multi-architecture support**: Builds for both `linux/amd64` and `linux/arm64`
- **Enhanced tooling**: Includes additional tools not in the standard moltbot Docker image

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
   ./build.sh
   ```

## What the Build Script Does

1. **Clone/Update Repository**: Pulls the latest main branch of moltbot
2. **Replace Dockerfile**: Uses our custom Dockerfile with additional tools
3. **Setup Buildx**: Configures Docker buildx for multi-arch builds
4. **Build & Push**: Creates and pushes the multi-arch image to Docker Hub

## Build Configuration

The build uses the following configuration:

```bash
Platforms: linux/amd64,linux/arm64
Base Image: node:22-slim
Packages: git gh jq curl wget unzip ffmpeg imagemagick poppler-utils python3 python3-pip
```

## Customization

### Updating the Dockerfile

When the upstream moltbot Dockerfile changes, refer to [CUSTOMIZATION.md](CUSTOMIZATION.md) for detailed instructions on how to update while preserving custom additions.

**Quick reference:**
1. Fetch the latest upstream Dockerfile
2. Insert custom sections after the `ARG CLAWDBOT_DOCKER_APT_PACKAGES` block
3. Update the "Last synced" date in the header
4. All custom sections are clearly marked with `CUSTOM:` comments

See [CUSTOMIZATION.md](CUSTOMIZATION.md) for the complete update process.

### Adding More APT Packages

Edit the `CLAWDBOT_DOCKER_APT_PACKAGES` build arg in [build.sh](build.sh) (in the docker buildx build command).

### Adding More Tools

Add installation commands to [Dockerfile](Dockerfile) in the custom sections area (after APT packages, before COPY commands). Follow the existing patterns and add `CUSTOM:` comments.

See [CUSTOMIZATION.md](CUSTOMIZATION.md) for detailed guidelines.

### Changing Target Platforms

Edit the `PLATFORMS` variable in [build.sh](build.sh):

```bash
PLATFORMS="linux/amd64,linux/arm64,linux/arm/v7"
```

## Usage

After building, you can run the container:

```bash
docker run -d \
  -p 18789:18789 \
  -v ~/.clawdbot:/root/.clawdbot \
  ioleksiy/clawdbot-gateway:latest
```

Or use with docker-compose:

```yaml
version: '3.8'
services:
  moltbot:
    image: ioleksiy/clawdbot-gateway:latest
    ports:
      - "18789:18789"
    volumes:
      - ~/.clawdbot:/root/.clawdbot
    restart: unless-stopped
```

## Verification

Verify that all tools are installed:

```bash
docker run --rm ioleksiy/clawdbot-gateway:latest /bin/bash -c "
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

This project follows the same license as moltbot (MIT).

## Related Links

- [Moltbot GitHub Repository](https://github.com/moltbot/moltbot)
- [Moltbot Documentation](https://docs.molt.bot/)
- [Docker Buildx Documentation](https://docs.docker.com/buildx/working-with-buildx/)
