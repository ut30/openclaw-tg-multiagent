# System Architecture & Component Design

This document details the multi-agent routing topology, runtime isolation, and model failover architecture of the OpenClaw deployment on an ARM64 Linux server.

---

## 1. High-Level Architecture Diagram

```mermaid
flowchart TD
    subgraph Telegram ["Telegram Cloud"]
        TG_GROUP["Private Telegram Group<br/>(Only Allowed Users & Chat ID)"]
        BOT_JARVIS["@your_jarvis_bot"]
        BOT_CYRA["@your_cyra_bot"]
        BOT_SAM["@your_sam_bot"]
        BOT_DEV["@your_dev_bot"]
        
        TG_GROUP -->|Mention @your_jarvis_bot| BOT_JARVIS
        TG_GROUP -->|Mention @your_cyra_bot| BOT_CYRA
        TG_GROUP -->|Mention @your_sam_bot| BOT_SAM
        TG_GROUP -->|Mention @your_dev_bot| BOT_DEV
    end

    subgraph Host ["Ubuntu Host (Oracle Cloud ARM64)"]
        subgraph NetIsolation ["Network & Process Isolation"]
            LOCAL_BIND["Loopback Bind Only<br/>127.0.0.1:18789"]
            OTHER_APP["Another App on Same Server<br/>(Independent Stack / Zero Downtime)"]
        end

        subgraph DockerContainer ["Docker Container: openclaw-gateway"]
            GW_PROCESS["OpenClaw Gateway Engine<br/>(Node runtime, uid 1000)"]
            INGRESS_SPOOL["Isolated Polling Ingress Spool"]
            ROUTING["1-to-1 Account-to-Agent Bindings"]
            
            BOT_JARVIS -.->|Long-polling HTTPS| INGRESS_SPOOL
            BOT_CYRA -.->|Long-polling HTTPS| INGRESS_SPOOL
            BOT_SAM -.->|Long-polling HTTPS| INGRESS_SPOOL
            BOT_DEV -.->|Long-polling HTTPS| INGRESS_SPOOL

            INGRESS_SPOOL --> GW_PROCESS
            GW_PROCESS --> ROUTING
            
            subgraph Agents ["Isolated Autonomous Agents"]
                A_JARVIS["Agent: jarvis<br/>Role: Coding Specialist<br/>Profile: coding (workspace restricted)"]
                A_CYRA["Agent: cyra<br/>Role: News Specialist<br/>Profile: minimal (exec: deny)"]
                A_SAM["Agent: sam<br/>Role: Writing Specialist<br/>Profile: minimal (exec: deny)"]
                A_DEV["Agent: dev<br/>Role: Research Specialist<br/>Profile: minimal (exec: deny)"]
            end
            
            ROUTING --> A_JARVIS
            ROUTING --> A_CYRA
            ROUTING --> A_SAM
            ROUTING --> A_DEV
        end
    end

    subgraph Providers ["Multi-LLM Failover Engine (45s Request Timeout)"]
        subgraph OpenRouter ["OpenRouter API (:free)"]
            OR_CODE["cohere/north-mini-code:free"]
            OR_MINI["nex-agi/nex-n2.5-mini:free"]
            OR_DEEP["deepseek/deepseek-v4-flash-0731:free"]
        end

        subgraph GroqCloud ["Groq API (Free Tier)"]
            GROQ_120B["openai/gpt-oss-120b"]
            GROQ_QWEN["qwen/qwen3.8-27b"]
        end

        subgraph GoogleGemini ["Google Gemini API (Free Tier)"]
            GEMINI_FLASH["google/gemini-3-flash-preview"]
            GEMINI_LITE["google/gemini-3.1-flash-lite"]
        end
    end

    A_JARVIS -->|Primary| OR_CODE
    A_JARVIS -.->|Fallback 1| GEMINI_FLASH
    A_JARVIS -.->|Fallback 2| OR_MINI

    A_CYRA -->|Primary| GEMINI_FLASH
    A_CYRA -.->|Fallback 1| GROQ_120B
    A_CYRA -.->|Fallback 2| OR_MINI

    A_SAM -->|Primary| GROQ_120B
    A_SAM -.->|Fallback 1| GEMINI_FLASH
    A_SAM -.->|Fallback 2| OR_MINI

    A_DEV -->|Primary| GEMINI_FLASH
    A_DEV -.->|Fallback 1| GROQ_120B
    A_DEV -.->|Fallback 2| OR_DEEP
```

---

## 2. Core Components

### 2.1 Telegram Polling Ingress
- OpenClaw utilizes **long-polling** over outbound HTTPS (`api.telegram.org`) rather than incoming webhooks.
- **Why long-polling?** Long-polling eliminates the need to expose ports publicly, assign public domain names, or manage inbound SSL certificates. The server port stays locked strictly to `127.0.0.1`.
- Each bot account maintains its own isolated polling spool directory inside `/home/node/.openclaw/telegram/ingress-spool-<agent>`, ensuring one slow bot never blocks another.

### 2.2 Discrete Agent Workspaces
Each agent operates with its own distinct workspace directory:
- `jarvis`: `~/.openclaw/workspace`
- `cyra`: `~/.openclaw/workspaces/cyra`
- `sam`: `~/.openclaw/workspaces/sam`
- `dev`: `~/.openclaw/workspaces/dev`

Each workspace holds persona files:
- `SOUL.md`: High-level directives, tone of voice, and behavioural guardrails.
- `IDENTITY.md`: Name, role, and self-conception.
- `AGENTS.md`: Operating boundaries and interaction rules.

### 2.3 Least-Privilege Tool Policies
OpenClaw enforces sandboxed permissions on a per-agent basis:
1. **Coding Agent (`jarvis`)**:
   - `profile: "coding"`
   - `fs.workspaceOnly: true` (Can only inspect/modify files inside its designated workspace directory).
   - `exec.applyPatch.workspaceOnly: true` (Diff patch application restricted to workspace).
2. **Minimal Agents (`cyra`, `sam`, `dev`)**:
   - `profile: "minimal"`
   - `alsoAllow: ["read", "write", "edit", "web_search", "web_fetch"]`
   - `deny: ["exec", "process", "terminal", "apply_patch"]`
   - `exec.mode: "deny"` (Cannot spawn shells, execute binary code, or call host processes).
   - Key-free search enabled via built-in DuckDuckGo integration.

### 2.4 Multi-Provider Failover Matrix
Every agent is assigned a primary model and a priority chain of secondary models. If an upstream provider returns HTTP 429 (rate limit exceeded), 503 (service unavailable), or fails within 45 seconds, the runtime automatically invokes the next fallback candidate.
