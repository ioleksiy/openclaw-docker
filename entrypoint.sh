#!/bin/bash
set -e

# Install runtime packages if OPENCLAW_RUNTIME_PACKAGES is set
if [ -n "$OPENCLAW_RUNTIME_PACKAGES" ]; then
  echo "[openclaw-entrypoint] Installing: $OPENCLAW_RUNTIME_PACKAGES"
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $OPENCLAW_RUNTIME_PACKAGES
  rm -rf /var/lib/apt/lists/*
  echo "[openclaw-entrypoint] Done"
fi

# Drop privileges to node user and exec CMD
exec gosu node "$@"