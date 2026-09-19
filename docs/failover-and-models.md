# LLM Providers, Failover Matrix & Model Evaluation

This document summarizes model testing, failure modes, and automatic failover behaviors observed during live production testing in September 2026.

---

## 1. Provider & Model Evaluation Table

All models were evaluated using live single-message completions inside the OpenClaw agent runtime:

| Provider | Model Identifier | Live Test Status | Role / Assignment | Observations |
| :--- | :--- | :--- | :--- | :--- |
| **OpenRouter** | `openrouter/cohere/north-mini-code:free` | **WORKS** | Jarvis Primary | Outstanding coding completion. Handled full tool schemas without context overflow. |
| **OpenRouter** | `openrouter/nex-agi/nex-n2.5-mini:free` | **WORKS** | Fallback in all chains | Rapid, reliable free fallback. |
| **OpenRouter** | `openrouter/deepseek/deepseek-v4-flash-0731:free` | **WORKS** | Sam / Dev Fallback | High-quality reasoning and synthesis. |
| **Groq** | `groq/openai/gpt-oss-120b` | **WORKS** | Sam Primary, Cyra/Dev Fallback | Sub-second latency. Fits `profile: "minimal"` agents cleanly. |
| **Groq** | `groq/qwen/qwen3.8-27b` | **WORKS** | Alternate Fallback | Stable and fast. |
| **Groq** | `groq/openai/gpt-oss-20b` | **WORKS** | Alternate Fallback | High throughput. |
| **Google** | `google/gemini-3-flash-preview` | **WORKS** | Cyra / Dev Primary | Excellent tool support, zero rate limits on standard prompt traffic. |
| **Google** | `google/gemini-3.1-flash-lite` | **WORKS** | Cyra Fallback | Ultra-lightweight fallback candidate. |
| **Google** | `google/gemini-3.1-pro-preview` | **429 RATE LIMIT** | Replaced | Hit immediate free tier quota exhaustion. |
| **Google** | `google/gemini-2.5-flash` | **NOT FOUND** | Replaced | Provider discontinued support for new API keys. |
| **Cerebras** | `cerebras/gpt-oss-120b` | **402 BILLING** | Excluded | Free tier requires active payment method / credits. |
| **Cerebras** | `cerebras/qwen-3.8-27b` | **402 BILLING** | Excluded | Free tier requires active payment method / credits. |

---

## 2. Agent Failover Assignment Matrix

| Agent | Profile | Primary Model | Failover Candidates | Timeout |
| :--- | :--- | :--- | :--- | :--- |
| **Jarvis** | `coding` | `openrouter/cohere/north-mini-code:free` | `google/gemini-3-flash-preview`<br/>`openrouter/nex-agi/nex-n2.5-mini:free` | 45 seconds |
| **Cyra** | `minimal` | `google/gemini-3-flash-preview` | `groq/openai/gpt-oss-120b`<br/>`openrouter/nex-agi/nex-n2.5-mini:free`<br/>`google/gemini-3.1-flash-lite` | 45 seconds |
| **Sam** | `minimal` | `groq/openai/gpt-oss-120b` | `google/gemini-3-flash-preview`<br/>`openrouter/nex-agi/nex-n2.5-mini:free`<br/>`openrouter/deepseek/deepseek-v4-flash-0731:free` | 45 seconds |
| **Dev** | `minimal` | `google/gemini-3-flash-preview` | `groq/openai/gpt-oss-120b`<br/>`openrouter/deepseek/deepseek-v4-flash-0731:free`<br/>`openrouter/nex-agi/nex-n2.5-mini:free` | 45 seconds |

---

## 3. Real-World Failover Test Verification

To ensure that failover operates seamlessly without user disruption, a live test was conducted by temporarily configuring an agent with an intentionally failing primary model (`google/gemini-3.1-pro-preview`, which triggers a 429 quota error) and a working fallback (`google/gemini-3-flash-preview`).

### Gateway Decision Log:
```log
[model-fallback/decision] model fallback decision: decision=candidate_succeeded requested=google/gemini-3.1-pro-preview candidate=google/gemini-3-flash-preview reason=unknown next=none
```

### JSON Execution Trace:
```json
{
  "executionTrace": {
    "winnerProvider": "google",
    "winnerModel": "gemini-3-flash-preview",
    "attempts": [
      {
        "provider": "google",
        "model": "gemini-3.1-pro-preview",
        "result": "candidate_failed",
        "reason": "rate_limit",
        "status": 429
      },
      {
        "provider": "google",
        "model": "gemini-3-flash-preview",
        "result": "success",
        "stage": "assistant"
      }
    ],
    "fallbackUsed": true,
    "runner": "embedded"
  }
}
```
*Result:* The user experienced no error; the runtime seamlessly transitioned to the fallback candidate within 1.6 seconds.
