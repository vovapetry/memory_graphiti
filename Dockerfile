# Multi-stage Dockerfile for portable development environment
# Based on Ubuntu 22.04 LTS with all development tools pre-installed

FROM ubuntu:22.04 AS base

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Install system dependencies and basic tools
RUN apt-get update && apt-get install -y     ca-certificates     curl     wget     gnupg     lsb-release     apt-transport-https     software-properties-common     git     vim     nano     tmux     htop     unzip     jq     build-essential     sudo     && rm -rf /var/lib/apt/lists/*

# Install Docker CLI and Docker Compose
RUN install -m 0755 -d /etc/apt/keyrings &&     curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc &&     chmod a+r /etc/apt/keyrings/docker.asc &&     echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu     $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null &&     apt-get update &&     apt-get install -y docker-ce-cli docker-compose-plugin &&     rm -rf /var/lib/apt/lists/*

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg &&     chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg &&     echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" |     tee /etc/apt/sources.list.d/github-cli.list > /dev/null &&     apt-get update &&     apt-get install -y gh &&     rm -rf /var/lib/apt/lists/*

# Install Node.js 20.x and npm
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - &&     apt-get install -y nodejs &&     rm -rf /var/lib/apt/lists/*

# Install Python and pip
RUN apt-get update &&     apt-get install -y python3 python3-pip python3-venv &&     rm -rf /var/lib/apt/lists/*

# Install Claude CLI
RUN npm install -g @anthropic-ai/claude-code

# Create claudedev user with sudo privileges
ARG USER_UID=1000
ARG USER_GID=1000
RUN groupadd --gid $USER_GID claudedev &&     useradd --uid $USER_UID --gid $USER_GID -m -s /bin/bash claudedev &&     echo "claudedev ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Create necessary directories
RUN mkdir -p /home/claudedev/.claude /home/claudedev/.config/gh &&     chown -R claudedev:claudedev /home/claudedev

# Copy setup scripts
COPY --chown=claudedev:claudedev scripts/ /home/claudedev/scripts/
RUN chmod +x /home/claudedev/scripts/*.sh

# Switch to claudedev user
USER claudedev
WORKDIR /home/claudedev

# Set up default Git configuration (will be overridden by env vars)
RUN git config --global init.defaultBranch main &&     git config --global pull.rebase false

# Expose common ports
EXPOSE 8080 8081 8082 3000 6379

# Set entrypoint
ENTRYPOINT ["/home/claudedev/scripts/entrypoint.sh"]
CMD ["/bin/bash"]
