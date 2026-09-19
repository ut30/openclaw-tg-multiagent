#!/usr/bin/env bash
# ==============================================================================
# OpenClaw Gateway Health & Security Check Script
# Validates port isolation, container status, and memory consumption.
# ==============================================================================

set -euo pipefail

echo "========================================================"
echo " OpenClaw Gateway Health & Isolation Audit"
echo "========================================================"

echo -e "\n[1] Verifying Gateway Port Binding (Must be 127.0.0.1 only):"
PORT_CHECK=$(sudo ss -ltnp | grep -E '18789' || true)
if [ -z "${PORT_CHECK}" ]; then
    echo "  WARNING: Port 18789 is not listening. Gateway might be stopped."
else
    echo "  ${PORT_CHECK}"
    if echo "${PORT_CHECK}" | grep -q '127.0.0.1:18789'; then
        echo "  [OK] Gateway is bound strictly to loopback (127.0.0.1)."
    else
        echo "  [CRITICAL ALERT] Gateway is bound to a public interface! Restrict immediately."
    fi
fi

echo -e "\n[2] Checking Gateway Container Status:"
docker ps --filter "name=openclaw-gateway" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo -e "\n[3] Gateway Container Resource Usage:"
docker stats openclaw-openclaw-gateway-1 --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"

echo -e "\n[4] Running OpenClaw Internal Doctor (Diagnostics):"
docker exec openclaw-openclaw-gateway-1 openclaw doctor --lint --non-interactive || true

echo -e "\n[5] Host Disk and Available Memory:"
df -h /
free -h

echo "========================================================"
echo " Health check complete."
echo "========================================================"
