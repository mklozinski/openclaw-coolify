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
7.  Access the OpenClaw Gateway on port `18789`.

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
-   `OPENCLAW_MODEL`: The model ID to use (e.g., `openai/gpt-4o`, `anthropic/claude-3-sonnet`).

## Persistence

The configuration and data are stored in `/root/.openclaw`. This directory is mounted as a volume (`openclaw_data`) to ensure persistence across restarts.

## Troubleshooting

You can view the logs to see the startup process:

```bash
docker-compose logs -f openclaw
```
