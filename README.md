# OpenClaw on Coolify (Docker Deployment)

Deploy [OpenClaw](https://github.com/openclaw) (Personal AI Assistant) on a VPS using **Coolify** or standalone **Docker Compose**.

## Prerequisites

- A server with Docker and Docker Compose (or [Coolify](https://coolify.io))
- At least one LLM API key: **OpenRouter**, **OpenAI**, or **Anthropic**

## Quick Start

### Coolify

1. Create a new **Service** in Coolify.
2. Choose **Git Repository** as the source and enter this repo's URL.
3. Set **Build Pack** to `Docker Compose`.
4. Add the required environment variables (see [Environment Variables](#environment-variables) below).
5. Set your **Domain** with HTTPS (e.g. `https://openclaw.example.com`) and confirm the exposed port is `18789`.
6. **Deploy** the service.
7. Check the **Logs** — on the first deploy you will see the auto-generated gateway token. Copy it and save it as the `OPENCLAW_GATEWAY_TOKEN` environment variable.
8. Open your domain with the token: `https://your-domain/?token=YOUR_TOKEN`.
9. **Redeploy** the service (so it picks up the saved token).
10. Go to the **Service → Terminal** and run `openclaw onboard`. Follow the prompts to configure OAuth, models, and other settings.
11. **Redeploy** one more time, then open your domain and continue onboarding in the chat UI.

### Docker Compose (standalone)

```bash
git clone https://github.com/mklozinski/openclaw-coolify.git
cd openclaw-coolify

# Create .env with your keys
cat > .env <<EOF
OPENROUTER_API_KEY=sk-or-xxxx
OPENCLAW_GATEWAY_TOKEN=$(openssl rand -hex 32)
EOF

docker compose up -d --build
```

The gateway will be available at `http://localhost:18789`.

## Environment Variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `OPENROUTER_API_KEY` | one of these | — | OpenRouter API key |
| `OPENAI_API_KEY` | one of these | — | OpenAI API key |
| `ANTHROPIC_API_KEY` | one of these | — | Anthropic API key |
| `OPENCLAW_GATEWAY_TOKEN` | recommended | auto-generated | Token for gateway auth. Generate with `openssl rand -hex 32`. If not set, a random one is created on first start and printed in logs. |
| `OPENCLAW_MODEL` | no | `openrouter/google/gemini-3-flash-preview` | Default model ID |
| `OPENCLAW_CONFIG_CONTENT` | no | — | Inject a complete `openclaw.json` as a string (used only on first run, or with `OPENCLAW_FORCE_CONFIG`) |
| `OPENCLAW_FORCE_CONFIG` | no | `false` | Set to `true` to overwrite the existing config with `OPENCLAW_CONFIG_CONTENT`. Useful for one-time resets. |
| `TZ` | no | `UTC` | Container timezone |

## Persistence

Two named Docker volumes keep your data safe across redeploys and container rebuilds:

| Volume | Container path | What it stores |
|---|---|---|
| `openclaw-config` | `/home/linuxbrew/.openclaw` | `openclaw.json` (Telegram, OAuth, models, gateway settings) |
| `openclaw-workspace` | `/home/linuxbrew/openclaw` | `MEMORY.md`, `AGENTS.md`, `memory/`, skills, workspace files |

**Configuration is only auto-generated on first run.** If `openclaw.json` already exists on the volume, it is preserved — your Telegram integration, Google OAuth, custom model aliases, and all other settings survive redeploys.

### Resetting configuration

If you need to force a config reset:

1. Set `OPENCLAW_FORCE_CONFIG=true` and `OPENCLAW_CONFIG_CONTENT=<your json>` in your environment.
2. Redeploy. The entrypoint will overwrite the config with the content you provided.
3. **Remove** `OPENCLAW_FORCE_CONFIG` (or set it back to `false`) afterwards so future redeploys don't keep overwriting.

Alternatively, you can exec into the container and edit the config directly:

```bash
docker exec -it openclaw bash
nano ~/.openclaw/openclaw.json
# Then restart: docker restart openclaw
```

## Advanced Configuration

### Full config injection via `OPENCLAW_CONFIG_CONTENT`

For first-time setup, you can pass the entire `openclaw.json` as an environment variable. This is useful in Coolify where you can set env vars in the UI:

```json
{
  "gateway": {
    "mode": "local",
    "bind": "lan",
    "trustedProxies": ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"],
    "auth": { "token": "your-token-here" },
    "controlUi": { "allowInsecureAuth": true }
  },
  "agents": {
    "defaults": {
      "model": { "primary": "openrouter/google/gemini-3-flash-preview" }
    }
  },
  "telegram": {
    "token": "123456:ABC-DEF...",
    "allowedUsers": [123456789]
  }
}
```

After the first deploy, any changes you make through the OpenClaw UI or API are saved to the volume and will persist — you don't need to touch this env var again.

### Switching models at runtime

If you exec into the container, you can run one-off commands with a different model:

```bash
openclaw agent --model anthropic/claude-3-haiku --message "Quick check"
```

## Architecture

```
Dockerfile          → Builds the image (Node 22, Python, Homebrew, OpenClaw)
entrypoint.sh       → Startup script (config generation, migration, launch)
docker-compose.yaml → Service definition, volumes, networking
```

The container runs as non-root user `linuxbrew` for security, with `sudo` available for package installation by skills.
