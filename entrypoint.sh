#!/bin/bash
set -e

# Ensure the config directory exists
mkdir -p /root/.openclaw

# Function to generate openclaw.json
generate_config() {
    # Allow full config injection via env var
    if [ -n "$OPENCLAW_CONFIG_CONTENT" ]; then
        echo "Using custom configuration from OPENCLAW_CONFIG_CONTENT..."
        echo "$OPENCLAW_CONFIG_CONTENT" > /root/.openclaw/openclaw.json
        return
    fi

    echo "Generating /root/.openclaw/openclaw.json..."

    # Default model if not specified
    MODEL=${OPENCLAW_MODEL:-"anthropic/claude-3-opus-20240229"}
    
    # Check for OpenRouter specific config
    if [ -n "$OPENROUTER_API_KEY" ]; then
        echo "Configuring for OpenRouter..."
        printf '{\n  "gateway": {\n    "mode": "local",\n    "bind": "lan",\n    "trustedProxies": ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"],\n    "auth": { "token": "%s" },\n    "controlUi": { "allowInsecureAuth": true }\n  },\n  "agents": {\n    "defaults": {\n      "model": { "primary": "%s" }\n    }\n  }\n}\n' "${OPENCLAW_GATEWAY_TOKEN}" "$MODEL" > /root/.openclaw/openclaw.json
    elif [ -n "$OPENAI_API_KEY" ]; then
         echo "Configuring for OpenAI..."
         printf '{\n  "gateway": {\n    "mode": "local",\n    "bind": "lan",\n    "trustedProxies": ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"],\n    "auth": { "token": "%s" },\n    "controlUi": { "allowInsecureAuth": true }\n  },\n  "agents": {\n    "defaults": {\n      "model": { "primary": "%s" }\n    }\n  }\n}\n' "${OPENCLAW_GATEWAY_TOKEN}" "$MODEL" > /root/.openclaw/openclaw.json
    elif [ -n "$ANTHROPIC_API_KEY" ]; then
         echo "Configuring for Anthropic..."
         printf '{\n  "gateway": {\n    "mode": "local",\n    "bind": "lan",\n    "trustedProxies": ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"],\n    "auth": { "token": "%s" },\n    "controlUi": { "allowInsecureAuth": true }\n  },\n  "agents": {\n    "defaults": {\n      "model": { "primary": "%s" }\n    }\n  }\n}\n' "${OPENCLAW_GATEWAY_TOKEN}" "$MODEL" > /root/.openclaw/openclaw.json
    else
        echo "No API key found. Generating minimal configuration..."
        printf '{\n  "gateway": {\n    "mode": "local",\n    "bind": "lan",\n    "trustedProxies": ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"],\n    "auth": { "token": "%s" },\n    "controlUi": { "allowInsecureAuth": true }\n  }\n}\n' "${OPENCLAW_GATEWAY_TOKEN}" > /root/.openclaw/openclaw.json
    fi
}

# Check for Gateway Token
if [ -z "$OPENCLAW_GATEWAY_TOKEN" ]; then
    echo "OPENCLAW_GATEWAY_TOKEN not set. Generating a random token..."
    # Generate a random hex token
    OPENCLAW_GATEWAY_TOKEN=$(openssl rand -hex 32 2>/dev/null || head -c 32 /dev/urandom | od -A n -t x1 | tr -d ' \n')
    export OPENCLAW_GATEWAY_TOKEN
    echo "========================================================================"
    echo "GENERATED TOKEN: $OPENCLAW_GATEWAY_TOKEN"
    echo "Use this token to connect to your gateway."
    echo "To set a persistent token, add OPENCLAW_GATEWAY_TOKEN to your environment."
    echo "========================================================================"
fi


generate_config

# If arguments are passed to the script, run them.
# Otherwise, run the default gateway command, adding --allow-unconfigured if needed.
if [ "$#" -gt 0 ]; then
    exec "$@"
else
    ARGS="--port 18789 --verbose"
    
    if [ ! -f "/root/.openclaw/openclaw.json" ]; then
        echo "No configuration file found at /root/.openclaw/openclaw.json. Adding --allow-unconfigured flag."
        ARGS="$ARGS --allow-unconfigured"
    else
        echo "Configuration found at /root/.openclaw/openclaw.json."
    fi

    echo "Starting OpenClaw Gateway with args: $ARGS"
    # Run the gateway
    exec openclaw gateway $ARGS
fi
