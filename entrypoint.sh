#!/bin/bash
set -e

CONFIG_DIR="/home/linuxbrew/.openclaw"
CONFIG_FILE="$CONFIG_DIR/openclaw.json"
WORKSPACE_DIR="/home/linuxbrew/openclaw"

# Ensure directories exist with correct permissions
sudo mkdir -p "$CONFIG_DIR" "$WORKSPACE_DIR"
sudo chown -R linuxbrew:linuxbrew "$CONFIG_DIR" "$WORKSPACE_DIR"

# Migrate data from old location if it exists (one-time migration)
if [ -d "/root/.openclaw" ] && [ "$(ls -A /root/.openclaw 2>/dev/null)" ]; then
    echo "========================================="
    echo "Migrating data from /root/.openclaw to $CONFIG_DIR..."
    echo "========================================="
    sudo cp -rn /root/.openclaw/* "$CONFIG_DIR/" || true
    sudo chown -R linuxbrew:linuxbrew "$CONFIG_DIR"
    echo "Migration complete!"
fi

# Generate config ONLY if it doesn't already exist
# This preserves Telegram, OAuth, model, and other settings across redeploys
generate_config() {
    # OPENCLAW_CONFIG_CONTENT always wins — explicit full-config injection
    if [ -n "$OPENCLAW_CONFIG_CONTENT" ] && [ "$OPENCLAW_FORCE_CONFIG" = "true" ]; then
        echo "OPENCLAW_FORCE_CONFIG=true with OPENCLAW_CONFIG_CONTENT — overwriting config..."
        echo "$OPENCLAW_CONFIG_CONTENT" > "$CONFIG_FILE"
        return
    fi

    # If config already exists on the persistent volume, DO NOT overwrite it
    if [ -f "$CONFIG_FILE" ]; then
        echo "Existing configuration found at $CONFIG_FILE — preserving it."
        echo "(Set OPENCLAW_FORCE_CONFIG=true to overwrite with env-based config)"
        return
    fi

    echo "No existing config found. Generating $CONFIG_FILE..."

    # If full config content is provided via env, use it
    if [ -n "$OPENCLAW_CONFIG_CONTENT" ]; then
        echo "Using custom configuration from OPENCLAW_CONFIG_CONTENT..."
        echo "$OPENCLAW_CONFIG_CONTENT" > "$CONFIG_FILE"
        return
    fi

    # Default model if not specified
    MODEL=${OPENCLAW_MODEL:-"openrouter/google/gemini-3-flash-preview"}

    # Build minimal initial config
    if [ -n "$OPENROUTER_API_KEY" ] || [ -n "$OPENAI_API_KEY" ] || [ -n "$ANTHROPIC_API_KEY" ]; then
        echo "Generating initial config with model: $MODEL"
        cat > "$CONFIG_FILE" <<EOF
{
  "gateway": {
    "mode": "local",
    "bind": "lan",
    "trustedProxies": ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"],
    "auth": { "token": "${OPENCLAW_GATEWAY_TOKEN}" },
    "controlUi": { "allowInsecureAuth": true }
  },
  "agents": {
    "defaults": {
      "model": { "primary": "${MODEL}" }
    }
  }
}
EOF
    else
        echo "No API key found. Generating minimal gateway-only configuration..."
        cat > "$CONFIG_FILE" <<EOF
{
  "gateway": {
    "mode": "local",
    "bind": "lan",
    "trustedProxies": ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"],
    "auth": { "token": "${OPENCLAW_GATEWAY_TOKEN}" },
    "controlUi": { "allowInsecureAuth": true }
  }
}
EOF
    fi
}

# Generate gateway token if not set
if [ -z "$OPENCLAW_GATEWAY_TOKEN" ]; then
    echo "OPENCLAW_GATEWAY_TOKEN not set. Generating a random token..."
    OPENCLAW_GATEWAY_TOKEN=$(openssl rand -hex 32 2>/dev/null || head -c 32 /dev/urandom | od -A n -t x1 | tr -d ' \n')
    export OPENCLAW_GATEWAY_TOKEN
    echo "========================================================================"
    echo "GENERATED TOKEN: $OPENCLAW_GATEWAY_TOKEN"
    echo "Set OPENCLAW_GATEWAY_TOKEN in your environment to make it persistent."
    echo "========================================================================"
fi

generate_config

# Start OpenClaw
if [ "$#" -gt 0 ]; then
    exec "$@"
else
    ARGS="--port 18789 --verbose"

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "No configuration file found. Adding --allow-unconfigured flag."
        ARGS="$ARGS --allow-unconfigured"
    else
        echo "Configuration: $CONFIG_FILE"
    fi

    echo "Starting OpenClaw Gateway with args: $ARGS"
    exec openclaw gateway $ARGS
fi
