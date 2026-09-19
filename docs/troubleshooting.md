# Troubleshooting & Operational Diagnostics

Common issues and their verified resolutions.

---

## 1. Telegram Bots Do Not Reply in Group

### Symptoms
You send a message in your Telegram group, but the bot does not respond.

### Diagnosis Steps
1. **Check if bot was mentioned**:
   If `requireMention: true` is configured, messages like `hello` will be silently ignored. You must send `@your_bot_name hello`.
2. **Check Gateway Polling Ingress**:
   ```bash
   docker logs --tail 50 openclaw-openclaw-gateway-1 | grep "isolated polling ingress"
   ```
   Verify that you see:
   `[telegram] [diag] isolated polling ingress started spool=...`
3. **Verify Group ID & User ID**:
   Inspect `openclaw.json`. Ensure your numerical user ID is present in `allowFrom` and `groupAllowFrom`. If an unauthorized user sends a message, it is intentionally dropped without error.

---

## 2. Upstream Model Returns 429 (Rate Limit)

### Symptoms
Bot takes slightly longer to reply or logs a `429 rate_limit` warning.

### Resolution
OpenClaw's automatic failover engine handles this transparently. If the primary model fails, the gateway tries the next model in the agent's `fallbacks` list. Verify the failover trace in logs:
```bash
docker logs --tail 100 openclaw-openclaw-gateway-1 | grep "model fallback decision"
```

---

## 3. Context Overflow Warning

### Symptoms
Agent returns:
`Context overflow: prompt too large for the model. Try /reset (or /new) to start a fresh session.`

### Resolution
This occurs when an ongoing chat session has accumulated too much conversation history for the model's context window.
- In Telegram: Send `/new` or `/reset` to clear active session history and start fresh.
- On the server: Delete session tables using SQLite if clearing all history globally.

---

## 4. Gateway Fails to Start After Configuration Edit

### Symptoms
Docker container exits immediately with code 1.

### Diagnosis Steps
Run the lint diagnostic:
```bash
docker exec openclaw-openclaw-gateway-1 openclaw doctor --lint --non-interactive
```
Common syntax mistakes:
- Missing commas in `openclaw.json`.
- Trailing commas in JSON objects (invalid in strict JSON).
- Incorrect permissions on `~/.openclaw` (must be owned by uid `1000:1000`). Run `sudo chown -R 1000:1000 ~/.openclaw`.
