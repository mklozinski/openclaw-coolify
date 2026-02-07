# OpenClaw on Coolify (Docker Deployment)

This repository contains the necessary configuration to deploy OpenClaw (Personal AI Assistant) on a VPS using Coolify or standard Docker Compose.

## Prerequisites

-   A server with Docker and Docker Compose installed (or Coolify).
-   An OpenRouter API Key (or OpenAI API Key).

## Deployment

### Using Coolify

1.  Create a new Service in Coolify.
2.  Choose "Git Repository" as the source.
3.  Enter the URL of this public repository.
4.  Set the **Build Pack** to `Docker Compose`.
5.  In the **Environment Variables** section, add:
    -   `OPENROUTER_API_KEY`: Your OpenRouter API Key.
    -   `OPENCLAW_MODEL`: (Optional) The model you want to use, e.g., `anthropic/claude-3-opus`. Defaults to `anthropic/claude-3-opus-20240229`.
6.  Deploy the service.
7.  **Configuration in Coolify UI**:
    -   Go to **Service** -> **Settings**.
    -   Set **Domains** to your desired domain (e.g., `https://openclaw.your-domain.com`).
    -   Ensure **Port Exposes** (or **Ports Exposes**) maps to container port `18789`. Usually Coolify detects this from the docker-compose or lets you specify it.
    -   Save settings. Coolify should generate the Traefik configuration automatically.
8.  Access the OpenClaw Gateway at your domain.

### Using Docker Compose Locally

1.  Clone this repository.
2.  Create a `.env` file with your keys:
    ```env
    OPENROUTER_API_KEY=sk-or-xxxx
    ```
3.  Run:
    ```bash
    docker-compose up -d --build
    ```

## Configuration

The `entrypoint.sh` script automatically generates a `~/.openclaw/openclaw.json` configuration file based on the environment variables if one does not exist.

Supported Environment Variables:

-   `OPENROUTER_API_KEY`: Your OpenRouter API Key.
-   `OPENAI_API_KEY`: Your OpenAI API Key (if using OpenAI directly).
-   `ANTHROPIC_API_KEY`: Your Anthropic API Key (if using Anthropic directly).
-   `OPENCLAW_GATEWAY_TOKEN`: A secure token for accessing the gateway. Ideally generated (e.g. `openssl rand -hex 16`). If not provided, a random one is generated on startup and printed to logs.
-   `OPENCLAW_MODEL`: The model ID to use (e.g., `openai/gpt-4o`, `anthropic/claude-3-sonnet`).

## Persistence

The configuration and data are stored in `/root/.openclaw`. This directory is mounted as a volume (`openclaw_data`) to ensure persistence across restarts.


## Advanced Configuration: Multiple Models & Aliases

To use multiple models or specific models for different tasks (to save costs), you have a few options:

### 1. Using `OPENCLAW_CONFIG_CONTENT` (Recommended for Coolify)

You can inject a full `openclaw.json` configuration using the `OPENCLAW_CONFIG_CONTENT` environment variable. This allows you to define multiple models and advanced settings.

Example content for `OPENCLAW_CONFIG_CONTENT`:

```json
{
  "agent": {
    "model": "anthropic/claude-3-opus-20240229",
    "fallbackModels": ["anthropic/claude-3-sonnet-20240229"]
  },
  "llm": {
    "provider": "openrouter",
    "apiKey": "sk-or-your-key"
  }
}
```

### 2. Switching Models via CLI

You can switch models on the fly when interacting with the agent via CLI (if you sh exec into the container):

```bash
openclaw agent --model anthropic/claude-3-haiku --message "Quick check"
```

### 3. Thinking Modes

OpenClaw supports "Thinking Modes" which can adjust the depth of reasoning. While this doesn't directly map "low thinking" to a specific cheaper model by default without configuration, you can use:

-   Normal: standard model
-   `--thinking high`: Potentially uses more tokens/reasoning steps (check docs for specific model behavior).

 To strictly enforce cheaper models for simple tasks, setting a cheaper "primary" model and only using the expensive one explicitly (or vice versa) via configuration is the best approach.

