# Step-by-Step Setup & Deployment Guide

This guide walks through deploying the complete multi-agent Telegram system on an Ubuntu Linux server.

---

## Phase 1: Create 4 Bots on Telegram

1. Open Telegram and search for [@BotFather](https://t.me/BotFather).
2. For each bot (`jarvis`, `cyra`, `sam`, `dev`), send `/newbot`.
3. Give your bot a display name and unique username ending in `bot` (e.g. `your_jarvis_bot`).
4. Save the HTTP API tokens provided by @BotFather.
5. In @BotFather:
   - Run `/mybots` -> Select each bot -> **Bot Settings** -> **Group Privacy** -> Ensure it is set to **Turn off** (Disabled) or **Turn on** (Enabled).
   - *Note on Group Privacy:* When Group Privacy is Enabled, bots only receive messages that start with `/` or mention their `@username`. When Group Privacy is Disabled, bots can see all messages. With OpenClaw's `requireMention: true`, privacy mode can remain enabled while mentions trigger the bot cleanly.
6. Create a private Telegram group.
7. Add all 4 bots as members of your private group.

---

## Phase 2: Obtain Free API Keys

1. **Google Gemini**: Obtain a free API key from [Google AI Studio](https://aistudio.google.com).
2. **Groq**: Obtain a free API key from [Groq Console](https://console.groq.com).
3. **OpenRouter**: Obtain an API key from [OpenRouter](https://openrouter.ai). OpenRouter hosts several permanently `:free` models.

---

## Phase 3: Prepare the Server

Connect to your server via SSH:
```bash
ssh -i <PATH_TO_PRIVATE_KEY> user@<SERVER_IP>
```

Clone this repository or create the project folder:
```bash
git clone https://github.com/ut30/openclaw-telegram-multi-agent.git ~/openclaw-telegram
cd ~/openclaw-telegram
```

Run the setup helper script to create the necessary directories and permission structures:
```bash
chmod +x scripts/*.sh
./scripts/setup-helper.sh
```

---

## Phase 4: Configure Credentials Securely

Populate `~/.openclaw/.env` using your favorite text editor:
```bash
sudo nano ~/.openclaw/.env
```

Add your keys (replace placeholders):
```env
GEMINI_API_KEY=<YOUR_GEMINI_API_KEY>
GROQ_API_KEY=<YOUR_GROQ_API_KEY>
OPENROUTER_API_KEY=<YOUR_OPENROUTER_API_KEY>
TELEGRAM_BOT_TOKEN_JARVIS=<BOT_TOKEN_JARVIS>
TELEGRAM_BOT_TOKEN_CYRA=<BOT_TOKEN_CYRA>
TELEGRAM_BOT_TOKEN_SAM=<BOT_TOKEN_SAM>
TELEGRAM_BOT_TOKEN_DEV=<BOT_TOKEN_DEV>
```

Ensure file permissions are restricted:
```bash
sudo chmod 600 ~/.openclaw/.env
sudo chown 1000:1000 ~/.openclaw/.env
```

---

## Phase 5: Configure `openclaw.json`

Copy the sanitized configuration template:
```bash
cp config/openclaw.example.json ~/.openclaw/openclaw.json
sudo chown 1000:1000 ~/.openclaw/openclaw.json
```

---

## Phase 6: Start OpenClaw Gateway

Start the service in detached mode:
```bash
docker compose -f docker-compose.override.yml up -d
```

Verify that all 4 bots have connected and polling ingress has begun:
```bash
docker logs --tail 50 openclaw-openclaw-gateway-1 | grep "starting provider"
```

---

## Phase 7: Lock Down Group & User Permissions

1. Open your private Telegram group and send any message (e.g. `test`).
2. Run this command on your server to inspect recent ingress events:
```bash
docker exec openclaw-openclaw-gateway-1 node -e "
const sqlite3 = require('sqlite3');
const db = new sqlite3.Database('/home/node/.openclaw/state/openclaw.sqlite');
db.all('SELECT lane_key FROM channel_ingress_events LIMIT 1', (err, rows) => {
  console.log('Group Key:', rows);
});
"
```
3. Locate your numerical group ID (e.g. `<GROUP_ID>` or `-<GROUP_ID>`).
4. Find your numerical Telegram User ID (using [@userinfobot](https://t.me/userinfobot)).
5. Edit `~/.openclaw/openclaw.json` and replace `<YOUR_TELEGRAM_USER_ID>` and `<GROUP_ID>` with your real numerical IDs.
6. Restart only the OpenClaw gateway:
```bash
docker compose -f docker-compose.override.yml restart openclaw-gateway
```
7. Validate configuration health:
```bash
docker exec openclaw-openclaw-gateway-1 openclaw doctor --lint --non-interactive
```
