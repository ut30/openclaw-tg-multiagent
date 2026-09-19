# Security Architecture & Hardening

Security and process isolation were treated as strict non-negotiables throughout this deployment. This document outlines the defense-in-depth measures implemented.

---

## 1. Secret Management: SecretRef Architecture
- **Zero Plaintext Tokens in Config**: Bot tokens are never hardcoded as plaintext strings in `openclaw.json`. Instead, they use OpenClaw's native `SecretRef` mechanism:
  ```json
  "botToken": {
    "source": "env",
    "provider": "default",
    "id": "TELEGRAM_BOT_TOKEN_JARVIS"
  }
  ```
- **Filesystem Permissions**: The `.env` file is stored at `~/.openclaw/.env` with mode `0600` (readable and writable only by the owner) and owned by uid `1000:1000` (the non-root `node` container user).
- **No Command-Line Leakage**: Keys are never passed via `docker run -e` command arguments or shell commands to prevent leakage into `/proc`, `ps aux`, or shell history files (`.bash_history`).

---

## 2. Network & Port Isolation
- **Loopback Binding**: The OpenClaw gateway port (`18789`) is mapped strictly to `127.0.0.1`:
  ```yaml
  ports:
    - "127.0.0.1:18789:18789"
  ```
- **No Public Attack Surface**: The port is completely inaccessible from the public internet. No reverse proxy or firewall port openings (e.g., UFW or Oracle Cloud Security Lists) are permitted.
- **SSH Tunnel for Dashboard**: Remote access to the web interface is exclusively performed through an authenticated, encrypted SSH tunnel:
  ```bash
  ssh -N -L 18789:127.0.0.1:18789 user@server-ip
  ```

---

## 3. Sandboxed Agent Permissions
OpenClaw enforces principle-of-least-privilege tool access:
- **Coding Specialist (`jarvis`)**: Given filesystem and patch modification privileges, but strictly restricted to its designated workspace directory (`workspaceOnly: true`). It cannot traverse into host filesystems or other agent folders.
- **Content & Research Specialists (`cyra`, `sam`, `dev`)**: Explicitly prohibited from executing shell commands or binary processes:
  ```json
  "deny": ["exec", "process", "terminal", "apply_patch"],
  "exec": { "mode": "deny" }
  ```
  Even in the event of prompt injection, these agents possess no capability to run arbitrary system code.

---

## 4. Telegram Group Lock Down
By default, Telegram bots can be added to unauthorized groups or direct messaged by unknown third parties. OpenClaw closes these attack vectors with three safeguards:
1. **`allowFrom`**: A whitelist of numerical Telegram user IDs permitted to interact with the bots. Messages from any other user are immediately dropped.
2. **`groupAllowFrom`**: A whitelist of user IDs permitted to invoke the bots in group contexts.
3. **`groups`**: Whitelist of specific Telegram group IDs. Interactions originating in any group not present in the configuration are ignored.
4. **`requireMention: true`**: Bots will never process or respond to background group banter; they respond exclusively when explicitly mentioned by `@username`.

---

## 5. Coexistence with Other Workloads
On servers hosting multiple applications, OpenClaw runs within its own isolated Docker bridge network (`openclaw-isolated-net`).
- Docker socket (`/var/run/docker.sock`) is **never mounted** into the container.
- CPU and memory limits are capped in `docker-compose.override.yml` (`limits.memory: 3072M`, `limits.cpus: "2.0"`), guaranteeing that high inference loads cannot starve neighboring services of resources.
