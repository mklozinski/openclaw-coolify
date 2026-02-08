FROM node:22-bookworm

# System dependencies needed for native node modules and skills
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    build-essential \
    git \
    curl \
    dos2unix \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Install uv (fast python package manager used by some skills)
ENV UV_INSTALL_DIR="/usr/local/bin"
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# Create non-root user for runtime
RUN useradd -m -s /bin/bash linuxbrew && \
    echo "linuxbrew ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    mkdir -p /home/linuxbrew/.linuxbrew && \
    chown -R linuxbrew:linuxbrew /home/linuxbrew/.linuxbrew

# Install Homebrew (required by some skills)
USER linuxbrew
ENV NONINTERACTIVE=1
RUN /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
USER root
ENV PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH"

# Install OpenClaw
RUN npm install -g openclaw@latest

# Create persistent directories
RUN mkdir -p /home/linuxbrew/.openclaw /home/linuxbrew/openclaw && \
    chown -R linuxbrew:linuxbrew /home/linuxbrew

# Copy and prepare entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN dos2unix /entrypoint.sh && chmod +x /entrypoint.sh && chown linuxbrew:linuxbrew /entrypoint.sh

# Runtime as non-root
USER linuxbrew
ENV HOME=/home/linuxbrew
WORKDIR /home/linuxbrew/openclaw

EXPOSE 18789

ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
