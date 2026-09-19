#!/usr/bin/env bash
# ==============================================================================
# OpenClaw Multi-Agent Setup Helper Script
# Sets up directory structures, default permissions, and environment files.
# ==============================================================================

set -euo pipefail

OPENCLAW_CONFIG_DIR="${HOME}/.openclaw"
OPENCLAW_PROJECT_DIR="${HOME}/openclaw"

echo "=== Initializing OpenClaw Directories ==="
mkdir -p "${OPENCLAW_CONFIG_DIR}"
mkdir -p "${OPENCLAW_CONFIG_DIR}/workspace"
mkdir -p "${OPENCLAW_CONFIG_DIR}/workspaces/cyra"
mkdir -p "${OPENCLAW_CONFIG_DIR}/workspaces/sam"
mkdir -p "${OPENCLAW_CONFIG_DIR}/workspaces/dev"
mkdir -p "${OPENCLAW_PROJECT_DIR}"

echo "=== Setting Permissions (uid 1000:1000 for container user 'node') ==="
sudo chown -R 1000:1000 "${OPENCLAW_CONFIG_DIR}"

if [ ! -f "${OPENCLAW_CONFIG_DIR}/.env" ]; then
    echo "Creating empty ~/.openclaw/.env (permissions 0600)..."
    touch "${OPENCLAW_CONFIG_DIR}/.env"
    chmod 600 "${OPENCLAW_CONFIG_DIR}/.env"
    sudo chown 1000:1000 "${OPENCLAW_CONFIG_DIR}/.env"
    echo "Populate ~/.openclaw/.env with your API keys and bot tokens before starting."
else
    echo "~/.openclaw/.env already exists."
    chmod 600 "${OPENCLAW_CONFIG_DIR}/.env"
fi

if [ ! -f "${OPENCLAW_CONFIG_DIR}/openclaw.json" ]; then
    echo "Copying config template to ~/.openclaw/openclaw.json..."
    cp config/openclaw.example.json "${OPENCLAW_CONFIG_DIR}/openclaw.json"
    chmod 600 "${OPENCLAW_CONFIG_DIR}/openclaw.json"
    sudo chown 1000:1000 "${OPENCLAW_CONFIG_DIR}/openclaw.json"
fi

echo "=== Setup directories initialized successfully ==="
