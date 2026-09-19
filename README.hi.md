# 🚀 OpenClaw Multi-Agent Telegram System: Setup & Replication Guide

An end-to-end production guide for deploying a team of **4 autonomous AI agents** on Telegram using **OpenClaw** inside Docker on an **Oracle Cloud ARM64 (Ubuntu)** instance with automatic model failover across **OpenRouter, Groq, and Google Gemini**.

---

## 📋 Table of Contents
1. [System Architecture](#-system-architecture)
2. [Prerequisites](#-prerequisites)
3. [Step-by-Step Setup Guide](#-step-by-step-setup-guide)
   - [Phase 1: Bot Creation on Telegram](#phase-1-bot-creation-on-telegram)
   - [Phase 2: Docker & OpenClaw Deployment](#phase-2-docker--openclaw-deployment)
   - [Phase 3: Secure Credential Ingestion (.env)](#phase-3-secure-credential-ingestion-env)
   - [Phase 4: Agent & Failover Configuration (`openclaw.json`)](#phase-4-agent--failover-configuration-openclawjson)
   - [Phase 5: Gateway Launch & Telegram Polling](#phase-5-gateway-launch--telegram-polling)
   - [Phase 6: Private Group Lockdown](#phase-6-private-group-lockdown)
4. [Ready-to-Use AI Prompts (For Cursor / Claude Code / Antigravity)](#-ready-to-use-ai-prompts)
5. [Operations & Maintenance Runbook](#-operations--maintenance-runbook)

---

## 🏛 System Architecture

```
                    Telegram Private Group (with requireMention: true)
                                       │
        ┌──────────────────────────────┼──────────────────────────────┐
        ▼                              ▼                              ▼
  @Jarvis_308_bot                @Cyra_news_bot                 @Sam_write3_bot                 @Dev_reserch_bot
  (Coding Agent)                 (News Agent)                   (Writing Agent)                 (Research Agent)
        │                              │                              │                              │
        ▼                              ▼                              ▼                              ▼
 ┌─────────────┐                ┌─────────────┐                ┌─────────────┐                ┌─────────────┐
 │   jarvis    │                │    cyra     │                │     sam     │                │     dev     │
 ├─────────────┤                ├─────────────┤                ├─────────────┤                ├─────────────┤
 │Profile:     │                │Profile:     │                │Profile:     │                │Profile:     │
 │  coding     │                │  minimal    │                │  minimal    │                │  minimal    │
 ├─────────────┤                ├─────────────┤                ├─────────────┤                ├─────────────┤
 │Primary:     │                │Primary:     │                │Primary:     │                │Primary:     │
 │North-Mini   │                │Gemini 3 Fl. │                │Groq 120B    │                │Gemini 3 Fl. │
 ├─────────────┤                ├─────────────┤                ├─────────────┤                ├─────────────┤
 │Failovers:   │                │Failovers:   │                │Failovers:   │                │Failovers:   │
 │Gemini 3 Fl. │                │Groq 120B    │                │Gemini 3 Fl. │                │Groq 120B    │
 │Nex-Mini     │                │Nex-Mini     │                │Nex-Mini     │                │DeepSeek-V4  │
 └─────────────┘                └─────────────┘                └─────────────┘                └─────────────┘
                                       ▲
                                       │
                     OpenClaw Gateway (Port: 127.0.0.1:18789)
```

---

## 🛠 Prerequisites

1. **Linux Server**: Ubuntu 22.04 / 24.04 (ARM64 or x86_64) with Docker & Docker Compose installed.
2. **Telegram Accounts**:
   - 4 bot tokens from [@BotFather](https://t.me/BotFather).
   - Your numerical Telegram User ID (get it from [@userinfobot](https://t.me/userinfobot)).
3. **Free LLM Provider API Keys**:
   - **OpenRouter**: [openrouter.ai](https://openrouter.ai) (Free tier models available).
   - **Groq**: [console.groq.com](https://console.groq.com) (Free tier models available).
   - **Google Gemini**: [aistudio.google.com](https://aistudio.google.com) (Free tier API key).

---

## 🚀 Step-by-Step Setup Guide

### Phase 1: Bot Creation on Telegram
1. Open [@BotFather](https://t.me/BotFather) on Telegram.
2. Use `/newbot` to create 4 distinct bots:
   - **Jarvis** (Coding) -> e.g. `@your_jarvis_bot`
   - **Cyra** (News) -> e.g. `@your_cyra_bot`
   - **Sam** (Writing) -> e.g. `@your_sam_bot`
   - **Dev** (Research) -> e.g. `@your_dev_bot`
3. Save the 4 HTTP API tokens securely (e.g. `<YOUR_BOT_TOKEN_JARVIS>`).
4. In @BotFather, go to `/mybots` -> Select Bot -> **Bot Settings** -> **Group Privacy** -> Keep **Enabled** (this ensures the bot only triggers when specifically mentioned).
5. Create a **Private Telegram Group** and add all 4 bots into the group.

---

### Phase 2: Docker & OpenClaw Deployment
On your server, create the OpenClaw working directory:

```bash
mkdir -p ~/openclaw ~/.openclaw
cd ~/openclaw
```

Create `docker-compose.yml`:
```yaml
services:
  openclaw-gateway:
    image: ghcr.io/openclaw/openclaw:latest
    restart: unless-stopped
    ports:
      - "127.0.0.1:18789:18789"
    volumes:
      - /home/ubuntu/.openclaw:/home/node/.openclaw
      - /home/ubuntu/.openclaw/workspace:/home/node/.openclaw/workspace
    environment:
      - OPENCLAW_GATEWAY_PORT=18789
      - OPENCLAW_GATEWAY_BIND=0.0.0.0
      - OPENCLAW_DISABLE_BONJOUR=true
```

Ensure permissions are owned by container user `node` (uid 1000):
```bash
sudo chown -R 1000:1000 ~/.openclaw
```

---

### Phase 3: Secure Credential Ingestion (.env)
Never pass tokens or keys in command-line arguments or git repos. Store them in `~/.openclaw/.env` with strict `0600` permissions:

```bash
sudo bash -c 'cat << "EOF" > /home/ubuntu/.openclaw/.env
GEMINI_API_KEY=your_gemini_api_key_here
GROQ_API_KEY=your_groq_api_key_here
OPENROUTER_API_KEY=your_openrouter_api_key_here
TELEGRAM_BOT_TOKEN_JARVIS=your_jarvis_bot_token_here
TELEGRAM_BOT_TOKEN_CYRA=your_cyra_bot_token_here
TELEGRAM_BOT_TOKEN_SAM=your_sam_bot_token_here
TELEGRAM_BOT_TOKEN_DEV=your_dev_bot_token_here
EOF'

sudo chmod 600 /home/ubuntu/.openclaw/.env
sudo chown 1000:1000 /home/ubuntu/.openclaw/.env
```

---

### Phase 4: Agent & Failover Configuration (`openclaw.json`)
Create `/home/ubuntu/.openclaw/openclaw.json`:

```json
{
  "gateway": {
    "port": 18789,
    "bind": "0.0.0.0",
    "auth": { "mode": "none" }
  },
  "agents": {
    "defaults": {
      "timeoutSeconds": 45,
      "model": {
        "primary": "google/gemini-3-flash-preview",
        "fallbacks": [
          "groq/openai/gpt-oss-120b",
          "openrouter/cohere/north-mini-code:free",
          "openrouter/nex-agi/nex-n2.5-mini:free"
        ]
      }
    },
    "entries": {
      "jarvis": {
        "name": "jarvis",
        "model": {
          "primary": "openrouter/cohere/north-mini-code:free",
          "fallbacks": ["google/gemini-3-flash-preview", "openrouter/nex-agi/nex-n2.5-mini:free"]
        },
        "tools": {
          "profile": "coding",
          "fs": { "workspaceOnly": true },
          "exec": { "applyPatch": { "workspaceOnly": true } }
        }
      },
      "cyra": {
        "name": "cyra",
        "model": {
          "primary": "google/gemini-3-flash-preview",
          "fallbacks": ["groq/openai/gpt-oss-120b", "openrouter/nex-agi/nex-n2.5-mini:free", "google/gemini-3.1-flash-lite"]
        },
        "tools": {
          "profile": "minimal",
          "alsoAllow": ["read", "write", "edit", "web_search", "web_fetch"],
          "deny": ["exec", "process", "terminal", "apply_patch"],
          "fs": { "workspaceOnly": true },
          "exec": { "mode": "deny" }
        }
      },
      "sam": {
        "name": "sam",
        "model": {
          "primary": "groq/openai/gpt-oss-120b",
          "fallbacks": ["google/gemini-3-flash-preview", "openrouter/nex-agi/nex-n2.5-mini:free", "openrouter/deepseek/deepseek-v4-flash-0731:free"]
        },
        "tools": {
          "profile": "minimal",
          "alsoAllow": ["read", "write", "edit", "web_search", "web_fetch"],
          "deny": ["exec", "process", "terminal", "apply_patch"],
          "fs": { "workspaceOnly": true },
          "exec": { "mode": "deny" }
        }
      },
      "dev": {
        "name": "dev",
        "model": {
          "primary": "google/gemini-3-flash-preview",
          "fallbacks": ["groq/openai/gpt-oss-120b", "openrouter/deepseek/deepseek-v4-flash-0731:free", "openrouter/nex-agi/nex-n2.5-mini:free"]
        },
        "tools": {
          "profile": "minimal",
          "alsoAllow": ["read", "write", "edit", "web_search", "web_fetch"],
          "deny": ["exec", "process", "terminal", "apply_patch"],
          "fs": { "workspaceOnly": true },
          "exec": { "mode": "deny" }
        }
      }
    }
  },
  "channels": {
    "telegram": {
      "groups": {
        "*": { "requireMention": true }
      },
      "accounts": {
        "jarvis": { "botToken": { "source": "env", "provider": "default", "id": "TELEGRAM_BOT_TOKEN_JARVIS" } },
        "cyra":   { "botToken": { "source": "env", "provider": "default", "id": "TELEGRAM_BOT_TOKEN_CYRA" } },
        "sam":    { "botToken": { "source": "env", "provider": "default", "id": "TELEGRAM_BOT_TOKEN_SAM" } },
        "dev":    { "botToken": { "source": "env", "provider": "default", "id": "TELEGRAM_BOT_TOKEN_DEV" } }
      }
    }
  },
  "bindings": [
    { "channel": "telegram", "account": "jarvis", "agentId": "jarvis" },
    { "channel": "telegram", "account": "cyra",   "agentId": "cyra" },
    { "channel": "telegram", "account": "sam",    "agentId": "sam" },
    { "channel": "telegram", "account": "dev",    "agentId": "dev" }
  ]
}
```

Fix ownership:
```bash
sudo chown -R 1000:1000 ~/.openclaw
```

---

### Phase 5: Gateway Launch & Telegram Polling
Start OpenClaw:
```bash
cd ~/openclaw
docker compose up -d
```

Verify that all 4 bots have started polling:
```bash
docker logs --tail 50 openclaw-openclaw-gateway-1 | grep "starting provider"
```
*Expected output:*
```log
[telegram] [jarvis] starting provider (@your_jarvis_bot)
[telegram] [cyra] starting provider (@your_cyra_bot)
[telegram] [sam] starting provider (@your_sam_bot)
[telegram] [dev] starting provider (@your_dev_bot)
```

---

### Phase 6: Private Group Lockdown
1. Send any test message into your private Telegram group (e.g. `hello team`).
2. Run this command on the server to inspect incoming channel events and extract your `chat_id`:
```bash
docker exec openclaw-openclaw-gateway-1 node -e "
const sqlite3 = require('sqlite3');
const db = new sqlite3.Database('/home/node/.openclaw/state/openclaw.sqlite');
db.all('SELECT lane_key FROM channel_ingress_events LIMIT 1', (err, rows) => {
  console.log('Group Lane Key:', rows);
});
"
```
3. Look for the negative ID (e.g. `<GROUP_ID>` or `-<GROUP_ID>`).
4. Update `channels.telegram` in `~/.openclaw/openclaw.json` to lock down access:

```json
"telegram": {
  "allowFrom": ["YOUR_NUMERICAL_USER_ID"],
  "groupAllowFrom": ["YOUR_NUMERICAL_USER_ID"],
  "groups": {
    "-YOUR_GROUP_ID": { "requireMention": true },
    "-100YOUR_GROUP_ID": { "requireMention": true }
  },
  "accounts": { ... }
}
```
5. Restart the gateway:
```bash
docker compose -f ~/openclaw/docker-compose.yml restart openclaw-gateway
```
6. Run `openclaw doctor` to verify:
```bash
docker exec openclaw-openclaw-gateway-1 openclaw doctor --lint --non-interactive
```

---

## 🤖 Ready-to-Use AI Prompts

If you are using an AI coding assistant like **Antigravity, Claude Code, or Cursor**, you can copy and paste these exact prompts to have the agent set up everything automatically!

### 🎯 Prompt 1: Full Automated Deployment Prompt
```text
I want to set up an OpenClaw multi-agent Telegram system on my remote Ubuntu server.
Requirements:
1. I have an info.md file containing my API keys (Google Gemini, Groq, OpenRouter) and 4 Telegram bot tokens (jarvis, cyra, sam, dev) and my Telegram user ID.
2. NEVER print, echo, or expose any API keys or tokens in logs, chat, or CLI commands. Pass secrets over stdin into /home/ubuntu/.openclaw/.env (chmod 600, uid 1000).
3. Do not touch any existing production containers on the server.
4. Bind OpenClaw gateway strictly to loopback (127.0.0.1:18789).
5. Configure 4 separate agents:
   - jarvis (coding): primary openrouter/cohere/north-mini-code:free, profile: "coding".
   - cyra (news): primary google/gemini-3-flash-preview, profile: "minimal".
   - sam (writing): primary groq/openai/gpt-oss-120b, profile: "minimal".
   - dev (research): primary google/gemini-3-flash-preview, profile: "minimal".
6. Add automatic failover chains for each agent using the verified working models.
7. Set up 1-to-1 routing bindings from each Telegram bot account to its respective agent.
8. Enforce group lockdown: allowFrom and groupAllowFrom to my Telegram user ID only, and requireMention: true on the group.
9. Verify with openclaw doctor and report live one-message test results.
```

### 🎯 Prompt 2: Safe Failover Test Prompt
```text
Run a safe failover verification test on OpenClaw:
1. Temporarily configure an agent's primary model to google/gemini-3.1-pro-preview (which triggers a 429 quota error) and set fallback to google/gemini-3-flash-preview.
2. Send a test message with --json using an isolated session ID.
3. Show the JSON executionTrace showing attempt 1 rate_limit 429 and attempt 2 success with fallbackUsed: true.
4. Immediately restore the original configuration and verify with openclaw doctor.
```

---

## 📖 Operations & Maintenance Runbook

### 1. Restart Only OpenClaw Gateway
```bash
docker compose -f ~/openclaw/docker-compose.yml -f ~/openclaw/docker-compose.override.yml restart openclaw-gateway
```

### 2. View Live Logs in Real Time
```bash
docker logs -f --tail 100 openclaw-openclaw-gateway-1
```

### 3. Open Web Dashboard via SSH Tunnel
From your local PC:
```powershell
ssh -i "<PATH_TO_PRIVATE_KEY>" -N -L 18789:127.0.0.1:18789 user@<SERVER_IP>
```
Visit in browser: **`http://localhost:18789/`**

### 4. How to Test Your Bots
In your private Telegram group:
- `@your_jarvis_bot write a python script to parse a json string`
- `@your_cyra_bot summarize latest tech news`
- `@your_sam_bot write an introductory email for a product launch`
- `@your_dev_bot compare docker vs podman architecture`

---

## Disclaimers & Noticies

> [!IMPORTANT]
> **OpenClaw Disclaimer**: Yeh repository ek independent open-source configuration guide hai. Yeh **OpenClaw project ke sath affiliated ya endorsed nahi hai**.

> [!WARNING]
> **Free Tier Model Data Notice**: Free-tier model endpoints prompts ko log ya train kar sakte hain. Koi bhi sensitive production keys ya data free models ko mat bhejiye.

> [!NOTE]
> **Model Identifiers**: Model availability aur identifiers **September 2026** ke mutabiq hain aur samay ke sath change ho sakte hain.
