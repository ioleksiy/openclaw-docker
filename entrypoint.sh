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

# Drop privileges to node user only when running as root
if [ "$(id -u)" -eq 0 ]; then
  if command -v gosu >/dev/null 2>&1; then
    exec gosu node "$@"
  fi

  if command -v runuser >/dev/null 2>&1; then
    exec runuser -u node -- "$@"
  fi

  echo "[openclaw-entrypoint] WARNING: gosu/runuser not found; running as root"
  exec "$@"
fi

# Already non-root; run command as current user
exec "$@"