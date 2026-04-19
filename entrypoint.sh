#!/bin/bash
set -e

CONFIG_DIR="/home/linuxbrew/.openclaw"
CONFIG_FILE="$CONFIG_DIR/openclaw.json"
WORKSPACE_DIR="/home/linuxbrew/.openclaw/workspace"
LEGACY_WORKSPACE_DIR="/home/linuxbrew/openclaw"
LOCAL_OPENCLAW_BIN="/home/linuxbrew/.local/bin/openclaw"
LOCAL_OPENCLAW_MODULE_DIR="/home/linuxbrew/.local/lib/node_modules/openclaw"
IMAGE_OPENCLAW_BIN="/usr/local/bin/openclaw"
BACKUP_SUFFIX="$(date +%Y%m%d%H%M%S)"

# Ensure the image-installed OpenClaw wins over persisted user-local binaries.
export PATH="/usr/local/bin:/usr/local/sbin:/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:/home/linuxbrew/.local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

directory_has_contents() {
    [ -n "$(find "$1" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]
}

ensure_directories() {
    sudo mkdir -p "$CONFIG_DIR" "$WORKSPACE_DIR" /home/linuxbrew/.linuxbrew /home/linuxbrew/.local
    sudo chown -R linuxbrew:linuxbrew "$CONFIG_DIR" "$WORKSPACE_DIR" /home/linuxbrew/.linuxbrew /home/linuxbrew/.local
}

migrate_legacy_workspace() {
    if [ -d "$LEGACY_WORKSPACE_DIR" ] && directory_has_contents "$LEGACY_WORKSPACE_DIR"; then
        if [ ! -d "$WORKSPACE_DIR" ] || ! directory_has_contents "$WORKSPACE_DIR"; then
            echo "Migrating legacy workspace from $LEGACY_WORKSPACE_DIR to $WORKSPACE_DIR"
            sudo mkdir -p "$WORKSPACE_DIR"
            sudo cp -a "$LEGACY_WORKSPACE_DIR"/. "$WORKSPACE_DIR"/
            sudo chown -R linuxbrew:linuxbrew "$WORKSPACE_DIR"
            echo "Legacy workspace copied. Old data at $LEGACY_WORKSPACE_DIR was left in place."
        else
            echo "Legacy workspace data detected at $LEGACY_WORKSPACE_DIR, but $WORKSPACE_DIR already has data. Skipping copy."
        fi
    fi
}

warn_or_backup_stale_local_openclaw() {
    local resolved_openclaw
    local local_install_detected=false

    if [ -e "$LOCAL_OPENCLAW_BIN" ] || [ -d "$LOCAL_OPENCLAW_MODULE_DIR" ]; then
        local_install_detected=true
    fi

    if [ "$local_install_detected" = false ]; then
        return
    fi

    resolved_openclaw="$(command -v openclaw 2>/dev/null || true)"

    echo "Detected a persisted user-local OpenClaw install under /home/linuxbrew/.local."
    if [ "$resolved_openclaw" = "$LOCAL_OPENCLAW_BIN" ]; then
        echo "WARNING: ~/.local/bin/openclaw is shadowing the image-installed CLI."
        echo "WARNING: The container expects $IMAGE_OPENCLAW_BIN to be the active OpenClaw binary."
    else
        echo "User-local OpenClaw exists but is not active because PATH now prefers $IMAGE_OPENCLAW_BIN."
    fi

    echo "User-local binary: $LOCAL_OPENCLAW_BIN"
    echo "User-local module dir: $LOCAL_OPENCLAW_MODULE_DIR"

    if [ "$OPENCLAW_RENAME_STALE_LOCAL_OPENCLAW" = "true" ]; then
        if [ -e "$LOCAL_OPENCLAW_BIN" ]; then
            sudo mv "$LOCAL_OPENCLAW_BIN" "${LOCAL_OPENCLAW_BIN}.bak.${BACKUP_SUFFIX}"
            echo "Moved stale user-local binary to ${LOCAL_OPENCLAW_BIN}.bak.${BACKUP_SUFFIX}"
        fi
        if [ -d "$LOCAL_OPENCLAW_MODULE_DIR" ]; then
            sudo mv "$LOCAL_OPENCLAW_MODULE_DIR" "${LOCAL_OPENCLAW_MODULE_DIR}.bak.${BACKUP_SUFFIX}"
            echo "Moved stale user-local module dir to ${LOCAL_OPENCLAW_MODULE_DIR}.bak.${BACKUP_SUFFIX}"
        fi
    else
        echo "Set OPENCLAW_RENAME_STALE_LOCAL_OPENCLAW=true to move the stale user-local install aside automatically."
    fi
}

install_optional_brew_packages() {
    local pkg
    local packages

    if [ -z "$OPENCLAW_BREW_PACKAGES" ]; then
        return
    fi

    read -r -a packages <<< "$OPENCLAW_BREW_PACKAGES"
    if [ "${#packages[@]}" -eq 0 ]; then
        return
    fi

    echo "Ensuring optional Homebrew packages are installed: ${packages[*]}"
    for pkg in "${packages[@]}"; do
        if brew list --versions "$pkg" >/dev/null 2>&1; then
            echo "Homebrew package already installed: $pkg"
        else
            echo "Installing Homebrew package: $pkg"
            brew install "$pkg"
        fi
    done
}

print_startup_diagnostics() {
    local resolved_openclaw
    local openclaw_version

    resolved_openclaw="$(command -v openclaw 2>/dev/null || true)"
    openclaw_version="$(openclaw --version 2>/dev/null || openclaw version 2>/dev/null || echo unavailable)"

    echo "OpenClaw CLI: ${resolved_openclaw:-not found}"
    echo "OpenClaw version: $openclaw_version"
    echo "Workspace path: $WORKSPACE_DIR"
    echo "Config path: $CONFIG_FILE"
}

# Configure Git with GitHub PAT for seamless repo access
if [ -n "$GITHUB_TOKEN" ]; then
    git config --global credential.helper store
    echo "https://x-access-token:${GITHUB_TOKEN}@github.com" > /home/linuxbrew/.git-credentials
    chmod 600 /home/linuxbrew/.git-credentials
    echo "GitHub token configured for git operations."
fi

ensure_directories
migrate_legacy_workspace

# Migrate data from old root-owned location if it exists.
if [ -d "/root/.openclaw" ] && [ "$(ls -A /root/.openclaw 2>/dev/null)" ]; then
    echo "========================================="
    echo "Migrating data from /root/.openclaw to $CONFIG_DIR..."
    echo "========================================="
    sudo cp -rn /root/.openclaw/. "$CONFIG_DIR"/ || true
    sudo chown -R linuxbrew:linuxbrew "$CONFIG_DIR"
    echo "Migration complete!"
fi

# Generate config ONLY if it doesn't already exist.
# This preserves Telegram, OAuth, model, and other settings across redeploys.
generate_config() {
    # OPENCLAW_CONFIG_CONTENT + FORCE always wins - explicit full-config injection.
    if [ -n "$OPENCLAW_CONFIG_CONTENT" ] && [ "$OPENCLAW_FORCE_CONFIG" = "true" ]; then
        echo "OPENCLAW_FORCE_CONFIG=true with OPENCLAW_CONFIG_CONTENT - overwriting config..."
        echo "$OPENCLAW_CONFIG_CONTENT" > "$CONFIG_FILE"
        return
    fi

    # If config exists AND force is NOT set, preserve it.
    if [ -f "$CONFIG_FILE" ] && [ "$OPENCLAW_FORCE_CONFIG" != "true" ]; then
        echo "Existing configuration found at $CONFIG_FILE - preserving it."
        echo "(Set OPENCLAW_FORCE_CONFIG=true to overwrite with env-based config)"
        return
    fi

    if [ "$OPENCLAW_FORCE_CONFIG" = "true" ]; then
        echo "OPENCLAW_FORCE_CONFIG=true - regenerating config from environment variables..."
    else
        echo "No existing config found. Generating $CONFIG_FILE..."
    fi

    # If full config content is provided via env, use it.
    if [ -n "$OPENCLAW_CONFIG_CONTENT" ]; then
        echo "Using custom configuration from OPENCLAW_CONFIG_CONTENT..."
        echo "$OPENCLAW_CONFIG_CONTENT" > "$CONFIG_FILE"
        return
    fi

    # Default model if not specified.
    MODEL=${OPENCLAW_MODEL:-"openrouter/google/gemini-3-flash-preview"}

    # Build minimal initial config.
    if [ -n "$OPENROUTER_API_KEY" ] || [ -n "$OPENAI_API_KEY" ] || [ -n "$ANTHROPIC_API_KEY" ]; then
        echo "Generating initial config with model: $MODEL"
        # Build elevated config if Telegram IDs are provided.
        ELEVATED_BLOCK=""
        if [ -n "$OPENCLAW_TELEGRAM_ELEVATED_IDS" ]; then
            # Sanitize: strip literal backslashes that Coolify/Docker may inject
            # when escaping quotes inside environment variable values.
            CLEAN_IDS=$(echo "$OPENCLAW_TELEGRAM_ELEVATED_IDS" | tr -d '\\')

            # Support both JSON array ["id1","id2"] and simple comma-separated id1,id2 formats.
            # If the value does NOT start with '[', treat it as comma-separated IDs and wrap them.
            if [[ "$CLEAN_IDS" != \[* ]]; then
                # Convert comma-separated list to JSON array: "id1,id2" -> ["id1","id2"]
                CLEAN_IDS=$(echo "$CLEAN_IDS" | sed 's/[[:space:]]//g; s/,/","/g; s/^/["/; s/$/"]/')
            fi

            ELEVATED_BLOCK=$(cat <<EOFTOOLS
  "tools": {
    "elevated": {
      "enabled": true,
      "allowFrom": {
        "telegram": ${CLEAN_IDS}
      }
    }
  },
EOFTOOLS
)
        fi

        # Build controlUi config with allowed origins.
        CONTROL_UI='"allowInsecureAuth": true'
        if [ -n "$OPENCLAW_DOMAIN" ]; then
            CONTROL_UI='"allowInsecureAuth": true, "allowedOrigins": ["https://'"$OPENCLAW_DOMAIN"'"]'
        fi

        cat > "$CONFIG_FILE" <<EOF
{
  "gateway": {
    "mode": "local",
    "bind": "lan",
    "trustedProxies": ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"],
    "auth": { "token": "${OPENCLAW_GATEWAY_TOKEN}" },
    "controlUi": { ${CONTROL_UI} }
  },
${ELEVATED_BLOCK}  "agents": {
    "defaults": {
      "model": { "primary": "${MODEL}" }
    }
  }
}
EOF
    else
        echo "No API key found. Generating minimal gateway-only configuration..."
        # Build controlUi config with allowed origins.
        CONTROL_UI_MIN='"allowInsecureAuth": true'
        if [ -n "$OPENCLAW_DOMAIN" ]; then
            CONTROL_UI_MIN='"allowInsecureAuth": true, "allowedOrigins": ["https://'"$OPENCLAW_DOMAIN"'"]'
        fi

        cat > "$CONFIG_FILE" <<EOF
{
  "gateway": {
    "mode": "local",
    "bind": "lan",
    "trustedProxies": ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"],
    "auth": { "token": "${OPENCLAW_GATEWAY_TOKEN}" },
    "controlUi": { ${CONTROL_UI_MIN} }
  }
}
EOF
    fi
}

# Generate gateway token if not set.
if [ -z "$OPENCLAW_GATEWAY_TOKEN" ]; then
    echo "OPENCLAW_GATEWAY_TOKEN not set. Generating a random token..."
    OPENCLAW_GATEWAY_TOKEN=$(openssl rand -hex 32 2>/dev/null || head -c 32 /dev/urandom | od -A n -t x1 | tr -d ' \n')
    export OPENCLAW_GATEWAY_TOKEN
    echo "========================================================================"
    echo "GENERATED TOKEN: $OPENCLAW_GATEWAY_TOKEN"
    echo "Set OPENCLAW_GATEWAY_TOKEN in your environment to make it persistent."
    echo "========================================================================"
fi

warn_or_backup_stale_local_openclaw
install_optional_brew_packages
generate_config
print_startup_diagnostics

# Start OpenClaw.
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
