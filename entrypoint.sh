#!/bin/bash
set -e

# Ensure the config directory exists
mkdir -p /root/.openclaw

# Function to generate openclaw.json if it doesn't exist
generate_config() {
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
        # This structure is an approximation based on common patterns. 
        # Users might need to mount their own config if this simple generation isn't enough.
        # However, typically CLI tools allow setting keys via Env Vars too.
        # We will try to write a simple JSON.
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
    else
        echo "No API key found in environment variables (OPENROUTER_API_KEY or OPENAI_API_KEY)."
        echo "Starting with default/empty configuration. You may need to configure OpenClaw manually."
        # Initialize an empty safe config if needed, or just let OpenClaw handle it.
        # openclaw onboard might be needed.
    fi
}

generate_config

# If arguments are passed to the script, run them.
# Otherwise, run the default gateway command.
if [ "$#" -gt 0 ]; then
    exec "$@"
else
    echo "Starting OpenClaw Gateway..."
    # Ensure dependencies are installed if volume is empty/fresh (optional, but good for some setups)
    # python3 and build tools are in the image.
    
    # Run the gateway
    # Using --host 0.0.0.0 to ensure it listens on all interfaces within the container
    exec openclaw gateway --port 18789 --verbose
fi
