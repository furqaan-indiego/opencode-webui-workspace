FROM ubuntu:24.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

# Install base dependencies and tools
RUN apt-get update && apt-get install -y \
    software-properties-common \
    curl \
    wget \
    git \
    build-essential \
    ca-certificates \
    unzip \
    zip \
    jq \
    htop \
    tmux \
    openssh-client \
    rclone \
    magic-wormhole \
    && rm -rf /var/lib/apt/lists/*

# Install GitHub CLI (gh) - https://github.com/cli/cli/blob/trunk/docs/install_linux.md
RUN mkdir -p -m 755 /etc/apt/keyrings && \
    wget -nv -O- https://cli.github.com/packages/githubcli-archive-keyring.gpg | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null && \
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt-get update && apt-get install -y gh && \
    rm -rf /var/lib/apt/lists/*

# Install Tailscale - https://tailscale.com/download/linux
RUN curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null && \
    curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.tailscale-keyring.list | tee /etc/apt/sources.list.d/tailscale.list >/dev/null && \
    apt-get update && apt-get install -y tailscale && \
    rm -rf /var/lib/apt/lists/*

# Add deadsnakes PPA for Python 3.13
RUN add-apt-repository -y ppa:deadsnakes/ppa && \
    apt-get update && apt-get install -y \
    python3.13 \
    python3.13-venv \
    python3.13-dev \
    && apt-get install -y python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Set Python 3.13 as default and create alias
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.13 1 && \
    ln -sf /usr/bin/python3.13 /usr/bin/python

# Create opencode user and workspace
RUN useradd -m -s /bin/bash opencode && \
    mkdir -p /home/opencode/workspace && \
    chown -R opencode:opencode /home/opencode && \
    apt-get update && apt-get install -y sudo && \
    echo "opencode ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/opencode && \
    chmod 0440 /etc/sudoers.d/opencode && \
    rm -rf /var/lib/apt/lists/*

# Copy opencode config to workspace
COPY opencode.json /home/opencode/workspace/
RUN chown opencode:opencode /home/opencode/workspace/opencode.json

# Set working directory
WORKDIR /home/opencode/workspace

# Install Node.js (LTS)
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# Install Bun
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="${PATH}:/root/.bun/bin"

# Install uv (Python package manager)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="${PATH}:/root/.cargo/bin"

# Install Go (multi-arch)
RUN if [ "$(uname -m)" = "aarch64" ]; then \
      GOARCH=arm64; \
    elif [ "$(uname -m)" = "x86_64" ]; then \
      GOARCH=amd64; \
    else \
      GOARCH=$(uname -m); \
    fi && \
    wget https://go.dev/dl/go1.23.5.linux-${GOARCH}.tar.gz && \
    rm -rf /usr/local/go && tar -C /usr/local -xzf go1.23.5.linux-${GOARCH}.tar.gz && \
    rm go1.23.5.linux-${GOARCH}.tar.gz
ENV PATH="${PATH}:/usr/local/go/bin"

# Install Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="${PATH}:/root/.cargo/bin"

# Install OpenCode CLI
RUN curl -fsSL https://opencode.ai/install | bash && \
    export PATH="${PATH}:$(find /root -name opencode -type f -executable 2>/dev/null | xargs dirname | head -1)" || true
ENV PATH="${PATH}:/root/.local/bin:/root/.opencode/bin"

# Verify installations
RUN echo "=== Python ===" && python3 --version && \
    echo "=== Node.js ===" && node --version && \
    echo "=== npm ===" && npm --version && \
    echo "=== Bun ===" && bun --version && \
    echo "=== uv ===" && uv --version && \
    echo "=== Go ===" && go version && \
    echo "=== Rust ===" && rustc --version && \
    echo "=== Cargo ===" && cargo --version && \
    echo "=== GitHub CLI ===" && gh --version && \
    echo "=== Tailscale ===" && tailscale version && \
    echo "=== OpenCode ===" && opencode --version && \
    echo "=== Rclone ===" && rclone version

# Set proper permissions for workspace
RUN chown -R opencode:opencode /home/opencode/workspace

# Create Tailscale state directory
RUN mkdir -p /var/lib/tailscale /var/run/tailscale

# Create data directory structure for single volume mount
RUN mkdir -p /data/workspace /data/opencode-local /data/opencode-config && \
    rm -rf /home/opencode/workspace && \
    ln -sf /data/workspace /home/opencode/workspace && \
    mkdir -p /root/.local/share /root/.config && \
    ln -sf /data/opencode-local /root/.local/share/opencode && \
    ln -sf /data/opencode-config /root/.config/opencode && \
    chown -R opencode:opencode /data/workspace

# Create entrypoint script for Tailscale + OpenCode
RUN echo '#!/bin/bash\n\
set -e\n\
export PATH="${PATH}:/root/.local/bin:/root/.opencode/bin"\n\
\n\
# Ensure data directories exist and have correct permissions\n\
mkdir -p /data/workspace /data/opencode-local /data/opencode-config\n\
chown -R opencode:opencode /data/workspace 2>/dev/null || true\n\
\n\
# Start Tailscale if auth key is provided\n\
if [ -n "$TAILSCALE_AUTH_KEY" ]; then\n\
  echo "Starting Tailscale daemon..."\n\
  /usr/sbin/tailscaled --state=/var/lib/tailscale/tailscaled.state &\n\
  sleep 2\n\
  echo "Connecting to Tailscale network..."\n\
  tailscale up --auth-key="$TAILSCALE_AUTH_KEY" --accept-routes --ssh\n\
  echo "Waiting for Tailscale connection..."\n\
  for i in {1..30}; do\n\
    if tailscale status > /dev/null 2>&1; then\n\
      echo "Tailscale connected: $(tailscale ip -4)"\n\
      break\n\
    fi\n\
    echo "Waiting for connection... ($i/30)"\n\
    sleep 1\n\
  done\n\
fi\n\
\n\
# Run opencode with passed arguments\n\
exec opencode "$@"\n\
' > /entrypoint.sh && chmod +x /entrypoint.sh

# Set entrypoint and default command
ENTRYPOINT ["/entrypoint.sh"]
CMD ["web", "--port", "4096", "--hostname", "0.0.0.0"]
