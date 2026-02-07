FROM node:22-bookworm

# Install necessary system dependencies
# python3 and build-essential are often needed for native modules
RUN apt-get update && apt-get install -y \
    python3 \
    build-essential \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install OpenClaw globally
RUN npm install -g openclaw@latest

# Set working directory
WORKDIR /app

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh

# Create the configuration directory and volume mount point
RUN mkdir -p /root/.openclaw

# Expose the gateway port
EXPOSE 18789

# Set the entrypoint
ENTRYPOINT ["/bin/sh", "/entrypoint.sh"]
