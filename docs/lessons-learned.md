# Real-World Lessons Learned & Engineering Insights

Setting up an autonomous multi-agent gateway on production infrastructure surfaces nuances rarely mentioned in standard documentation. Here are the real-world lessons discovered during this implementation.

---

## 1. Local Image Builds vs. Prebuilt Binaries on Production Hosts
- **The Issue**: Building the OpenClaw container from source on an active server consumed high CPU and memory, tripping automated latency monitors on neighboring services.
- **The Fix**: Use the official prebuilt container image (`ghcr.io/openclaw/openclaw:latest`). Pulling a pre-compiled image requires negligible CPU and zero build memory overhead.

---

## 2. The Model Availability Horizon (September 2026)
- **`gemini-2.5-flash` Deprecation**: Documentation frequently cites `gemini-2.5-flash`. However, newly provisioned Gemini API keys returned `404 Not Found`. Switching to `google/gemini-3-flash-preview` resolved the issue immediately.
- **Gemini 3.1 Pro 429 Quotas**: While capable, `gemini-3.1-pro-preview` consistently exhausted free-tier rate limits during turn initialization. It is unsuitable as a primary model for high-cadence chat bots without a paid billing account.
- **Cerebras Billing Threshold**: Cerebras free tiers required an activated payment method or credit balance, returning `HTTP 402 Payment Required`.

---

## 3. Large Tool Schemas vs. Small Model Contexts
- **The Issue**: When attempting to assign Groq models (`groq/openai/gpt-oss-120b`) to the coding agent (`jarvis`), OpenClaw returned:
  `Context overflow: prompt too large for the model. Try /reset`.
- **The Cause**: The coding profile injects extensive tool definitions (filesystem manipulation, patch application, shell execution, status monitors) into the system prompt. Even before user input, this saturated Groq's input token headroom.
- **The Fix**:
  - Keep Groq as the primary model for **minimal agents** (`sam`, `cyra`, `dev`), where tool schemas are lightweight.
  - For coding agents with heavy toolsets, utilize large-context models like `openrouter/cohere/north-mini-code:free` or `google/gemini-3-flash-preview`.

---

## 4. Telegram Group Privacy vs. Mention Routing
- **The Issue**: When bots were added to a private Telegram group, regular chat messages did not appear in gateway logs.
- **The Cause**: By default, Telegram bots operate with **Group Privacy Enabled** in @BotFather, preventing them from intercepting messages that do not directly address them.
- **The Fix**: Pairing Telegram's native privacy mode with OpenClaw's `requireMention: true` provides optimal security. Bots ignore general conversational banter, waking up only when explicitly summoned with `@botname`.

---

## 5. Free Search Without Third-Party API Keys
- Instead of provisioning Google Custom Search Engine (CSE) or Tavily API keys with strict monthly quotas, OpenClaw features native **DuckDuckGo integration**. Enabling `web_search` and `web_fetch` allows agents to fetch real-time news and documentation with zero billing setup.
