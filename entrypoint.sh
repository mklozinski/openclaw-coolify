#!/bin/bash
set -e

# Ensure the config directory exists
mkdir -p /root/.openclaw

# Function to generate openclaw.json if it doesn't exist
generate_config() {
    # Allow full config injection via env var
    if [ -n "$OPENCLAW_CONFIG_CONTENT" ]; then
        echo "Using custom configuration from OPENCLAW_CONFIG_CONTENT..."
        echo "$OPENCLAW_CONFIG_CONTENT" > /root/.openclaw/openclaw.json
        return
    fi

    if [ -f "/root/.openclaw/openclaw.json" ]; then
        echo "Config file already exists at /root/.openclaw/openclaw.json"
        return
    fi
    
    echo "Generating /root/.openclaw/openclaw.json from environment variables..."

    # Default model if not specified
    MODEL=${OPENCLAW_MODEL:-"anthropic/claude-3-opus-20240229"}
    
    # Check for OpenRouter specific config
    if [ -n "$OPENROUTER_API_KEY" ]; then
        echo "Configuring for OpenRouter..."
        # Basic configuration for OpenRouter
        cat <<EOF > /root/.openclaw/openclaw.json
{
  "agent": {
    "model": "${MODEL}"
  },
  "llm": {
    "provider": "openrouter",
    "apiKey": "${OPENROUTER_API_KEY}"
  }
}
EOF
    elif [ -n "$OPENAI_API_KEY" ]; then
         echo "Configuring for OpenAI..."
         cat <<EOF > /root/.openclaw/openclaw.json
{
  "agent": {
    "model": "${MODEL}"
  },
  "llm": {
    "provider": "openai",
    "apiKey": "${OPENAI_API_KEY}"
  }
}
EOF
    elif [ -n "$ANTHROPIC_API_KEY" ]; then
         echo "Configuring for Anthropic..."
         cat <<EOF > /root/.openclaw/openclaw.json
{
  "agent": {
    "model": "${MODEL}"
  },
  "llm": {
    "provider": "anthropic",
    "apiKey": "${ANTHROPIC_API_KEY}"
  }
}
EOF
    else
        echo "No API key found in environment variables (OPENROUTER_API_KEY or OPENAI_API_KEY)."
        echo "Starting with default/empty configuration. You may need to configure OpenClaw manually."
    fi
}

generate_config

# If arguments are passed to the script, run them.
# Otherwise, run the default gateway command, adding --allow-unconfigured if needed.
if [ "$#" -gt 0 ]; then
    exec "$@"
else
    ARGS=("--port" "18789" "--verbose")
    
    if [ ! -f "/root/.openclaw/openclaw.json" ]; then
        echo "No configuration file found at /root/.openclaw/openclaw.json. Adding --allow-unconfigured flag."
        ARGS+=("--allow-unconfigured")
    else
        echo "Configuration found at /root/.openclaw/openclaw.json."
    fi

    echo "Starting OpenClaw Gateway with args: ${ARGS[*]}"
    # Run the gateway
    exec openclaw gateway "${ARGS[@]}"
fi
