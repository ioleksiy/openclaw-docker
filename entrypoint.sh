#!/bin/bash
set -e

# Install runtime packages if OPENCLAW_RUNTIME_PACKAGES is set
if [ -n "$OPENCLAW_RUNTIME_PACKAGES" ]; then
  echo "[openclaw-entrypoint] Installing: $OPENCLAW_RUNTIME_PACKAGES"
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $OPENCLAW_RUNTIME_PACKAGES
  rm -rf /var/lib/apt/lists/*
  echo "[openclaw-entrypoint] Done"
else
  echo "[openclaw-entrypoint] OPENCLAW_RUNTIME_PACKAGES not set; skipping runtime package installation"
fi

# Drop privileges only when explicitly requested.
# Default behavior is to run as current user (root in this image) to avoid
# authentication prompts from tools that may attempt privileged operations.
if [ "${OPENCLAW_RUN_AS_NODE:-false}" = "true" ]; then
  if [ "$(id -u)" -eq 0 ]; then
    if command -v gosu >/dev/null 2>&1; then
      echo "[openclaw-entrypoint] Dropping privileges to user: node (gosu)"
      exec gosu node "$@"
    fi

    if command -v runuser >/dev/null 2>&1; then
      echo "[openclaw-entrypoint] Dropping privileges to user: node (runuser)"
      exec runuser -u node -- "$@"
    fi

    echo "[openclaw-entrypoint] WARNING: OPENCLAW_RUN_AS_NODE=true but gosu/runuser not found; running as root"
    exec "$@"
  fi

  echo "[openclaw-entrypoint] OPENCLAW_RUN_AS_NODE=true but already non-root; continuing"
  exec "$@"
fi

echo "[openclaw-entrypoint] Running as current user (uid=$(id -u), user=$(id -un))"
exec "$@"