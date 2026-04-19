# OpenClaw on Coolify (Docker Deployment)

Deploy [OpenClaw](https://github.com/openclaw) on a VPS using Coolify or standalone Docker Compose.

## Prerequisites

- A server with Docker and Docker Compose, or Coolify.
- At least one LLM API key: OpenRouter, OpenAI, or Anthropic.

## Quick Start

### Coolify

1. Create a new service in Coolify.
2. Choose Git Repository as the source and enter this repo URL.
3. Set Build Pack to `Docker Compose`.
4. Add the required environment variables.
5. Set your domain with HTTPS and confirm the exposed port is `18789`.
6. Deploy the service.
7. Check the logs. On the first deploy you will see the auto-generated gateway token. Save it as `OPENCLAW_GATEWAY_TOKEN`.
8. Open your domain with the token: `https://your-domain/?token=YOUR_TOKEN`.
9. Redeploy the service so it picks up the saved token.
10. Open the service terminal and run `openclaw onboard` to configure OAuth, models, and other settings.
11. Redeploy one more time, then continue onboarding in the UI.

### Docker Compose

```bash
git clone https://github.com/mklozinski/openclaw-coolify.git
cd openclaw-coolify

cat > .env <<EOF
OPENROUTER_API_KEY=sk-or-xxxx
OPENCLAW_GATEWAY_TOKEN=$(openssl rand -hex 32)
EOF

docker compose up -d --build
```

The gateway will be available at `http://localhost:18789`.

## Operator Model

This repository runs `openclaw gateway` as the foreground container process. It is not managed by `systemd` inside the container.

- Upgrade OpenClaw by rebuilding and redeploying the image.
- Restart OpenClaw by restarting or redeploying the container.
- Do not treat `openclaw update` as the normal upgrade path in this Docker/Coolify deployment.
- Do not rely on `openclaw gateway restart`, `start`, or `stop` for routine operations in this foreground-container deployment.

## Environment Variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `OPENROUTER_API_KEY` | one of these | none | OpenRouter API key |
| `OPENAI_API_KEY` | one of these | none | OpenAI API key |
| `ANTHROPIC_API_KEY` | one of these | none | Anthropic API key |
| `OPENCLAW_GATEWAY_TOKEN` | recommended | auto-generated | Token for gateway auth. If not set, one is generated on first start and printed in logs. |
| `OPENCLAW_MODEL` | no | `openrouter/google/gemini-3-flash-preview` | Default model ID |
| `OPENCLAW_CONFIG_CONTENT` | no | none | Inject a complete `openclaw.json` as a string. Used on first run, or with `OPENCLAW_FORCE_CONFIG=true`. |
| `OPENCLAW_FORCE_CONFIG` | no | `false` | Set to `true` to overwrite the existing config with `OPENCLAW_CONFIG_CONTENT`. |
| `OPENCLAW_BREW_PACKAGES` | no | none | Optional space-separated Homebrew packages to install once into persistent storage, for example `ffmpeg yt-dlp`. |
| `OPENCLAW_RENAME_STALE_LOCAL_OPENCLAW` | no | `false` | Set to `true` to move a stale `~/.local` OpenClaw install aside instead of only warning. |
| `OPENCLAW_TELEGRAM_ELEVATED_IDS` | no | none | JSON array of Telegram user IDs that should receive elevated access automatically. |
| `GITHUB_TOKEN` | no | none | GitHub PAT for repo access. Configured into git credentials at runtime. |
| `OPENCLAW_DOMAIN` | recommended | none | Your domain without `https://`. Added to `gateway.controlUi.allowedOrigins`. |
| `TZ` | no | `UTC` | Container timezone |

## Build Version Pinning

The image installs OpenClaw at build time. By default it uses `openclaw@latest`.

If you want reproducible builds, set the build arg `OPENCLAW_NPM_SPEC`.

Examples:

```bash
docker compose build --build-arg OPENCLAW_NPM_SPEC=openclaw@2026.4.15
docker compose up -d
```

Or add this to your environment before redeploying with Compose or Coolify:

```bash
OPENCLAW_NPM_SPEC=openclaw@2026.4.15
```

## Persistence

Named Docker volumes keep your data across restarts, rebuilds, and redeploys.

| Volume | Container path | What it stores |
|---|---|---|
| `openclaw-config` | `/home/linuxbrew/.openclaw` | `openclaw.json` and other OpenClaw config state |
| `openclaw-workspace` | `/home/linuxbrew/.openclaw/workspace` | `MEMORY.md`, `AGENTS.md`, `memory/`, skills, and other workspace files |
| `openclaw-homebrew` | `/home/linuxbrew/.linuxbrew` | Homebrew-installed shared tools |
| `openclaw-pip` | `/home/linuxbrew/.local` | pip user-installed Python packages and binaries |

Persistence model:

- Config persists in `/home/linuxbrew/.openclaw`.
- Workspace persists in `/home/linuxbrew/.openclaw/workspace`.
- Homebrew-installed tools persist in `/home/linuxbrew/.linuxbrew`.
- pip user-installed packages persist in `/home/linuxbrew/.local`.
- Runtime `apt-get install` changes inside the container are ephemeral unless baked into the image.
- Optional shared tools should be installed through persistent mechanisms, not ad hoc runtime `apt-get install`.
- This repo is generic and does not assume `ffmpeg` or any other optional tool for everyone.

Configuration is only auto-generated on first run. If `openclaw.json` already exists on the volume, it is preserved across redeploys.

Workspace migration is conservative. On startup, the entrypoint checks for legacy data at `/home/linuxbrew/openclaw`. If that legacy path contains data and `/home/linuxbrew/.openclaw/workspace` is empty, the contents are copied forward once. The old path is not deleted automatically.

The container now prefers `/usr/local/bin/openclaw` over `~/.local/bin/openclaw`. Startup logs print the resolved OpenClaw binary path, the resolved version, and the active workspace path so stale user-local installs are visible.

## Optional Shared Tools

To install reusable tools once and keep them across redeploys, set `OPENCLAW_BREW_PACKAGES` to a space-separated list.

Example:

```bash
OPENCLAW_BREW_PACKAGES="ffmpeg yt-dlp"
```

On startup, the container installs only missing Homebrew packages. Because `/home/linuxbrew/.linuxbrew` is persisted, those binaries are reusable across future sessions, skills, and redeploys.

Use this for optional shared tooling. Do not rely on runtime `apt-get install` if you need the binaries to survive container replacement.

## Updates And Restarts

### Updating OpenClaw

`openclaw update` is not the recommended upgrade mechanism in this Docker/Coolify deployment.

Why:

- The primary OpenClaw CLI is installed into the image at build time.
- In-container self-updates can be lost when the container is rebuilt or redeployed.
- A stale persisted `~/.local` install can shadow the image-installed CLI if PATH order is wrong.

Supported update workflow:

1. Choose the desired image version, optionally with `OPENCLAW_NPM_SPEC=openclaw@latest`.
2. Rebuild the image.
3. Redeploy the service.
4. Confirm the startup logs show `/usr/local/bin/openclaw` and the expected version.

### Restarting OpenClaw

`openclaw gateway restart` is for service-managed installs. This repository does not use `systemd`, so container lifecycle commands are the correct operator interface.

Examples:

- Coolify: use the service Restart action for a process restart, or Redeploy after image or environment changes.
- Docker Compose: `docker compose restart`
- Plain Docker: `docker restart <container>`

## Resetting Configuration

If you need to force a config reset:

1. Set `OPENCLAW_FORCE_CONFIG=true` and `OPENCLAW_CONFIG_CONTENT=<your json>`.
2. Redeploy.
3. Remove `OPENCLAW_FORCE_CONFIG` afterward so future redeploys do not keep overwriting the config.

Alternatively, edit the config directly inside the container:

```bash
docker exec -it openclaw bash
nano ~/.openclaw/openclaw.json
# Then restart the container
docker restart openclaw
```

## Advanced Configuration

### Full config injection via `OPENCLAW_CONFIG_CONTENT`

You can pass the entire `openclaw.json` as an environment variable for first-time setup.

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

After the first deploy, changes made through the OpenClaw UI or API are saved to the volume and persist without needing to keep this environment variable.

### Switching models at runtime

If you exec into the container, you can still run one-off commands with a different model:

```bash
openclaw agent --model anthropic/claude-3-haiku --message "Quick check"
```

## Architecture

```text
Dockerfile          -> Builds the image
entrypoint.sh       -> Startup script, migration logic, optional shared tools, launch
docker-compose.yaml -> Service definition, volumes, networking
```

The container runs as non-root user `linuxbrew`, with `sudo` available for controlled setup tasks during startup.
