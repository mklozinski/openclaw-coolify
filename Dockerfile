FROM node:22-bookworm

# Install necessary system dependencies
# python3 and build-essential are often needed for native modules
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    build-essential \
    git \
    dos2unix \
    curl \
    procps \
    file \
    && rm -rf /var/lib/apt/lists/*

# Install uv (fast python package manager)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.cargo/bin:$PATH"

# Install Homebrew (required for some skills)
# define NONINTERACTIVE to avoid prompts
ENV NONINTERACTIVE=1
RUN /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# Add brew to path
ONBUILD ENV PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH"
ENV PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH"

# Install OpenClaw globally
RUN npm install -g openclaw@latest

# Set working directory
WORKDIR /app

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN dos2unix /entrypoint.sh && chmod +x /entrypoint.sh

# Create the configuration directory and volume mount point
RUN mkdir -p /root/.openclaw

# Expose the gateway port
EXPOSE 18789

# Set the entrypoint
ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
