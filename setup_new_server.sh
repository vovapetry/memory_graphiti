#!/bin/bash
# Automated Setup Script for New Server
# Usage: bash setup_new_server.sh <new_server_ip>

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check arguments
if [ -z "$1" ]; then
    echo -e "${RED}Error: Server IP required${NC}"
    echo "Usage: bash setup_new_server.sh <new_server_ip>"
    exit 1
fi

NEW_SERVER_IP="$1"
CLAUDE_USER="claudedev"
CLAUDE_PASS="pAdLqeRvkpJu"

echo -e "${GREEN}=== Setting up Multi-Agent Orchestration on ${NEW_SERVER_IP} ===${NC}\n"

# Phase 1: Server Preparation
echo -e "${YELLOW}Phase 1: Preparing server...${NC}"
ssh root@${NEW_SERVER_IP} bash << 'PHASE1'
set -e

echo "Updating system packages..."
apt update && apt upgrade -y

echo "Installing essential packages..."
apt install -y curl wget git docker.io docker-compose python3 python3-pip python3-venv jq

echo "Enabling Docker..."
systemctl enable docker
systemctl start docker

echo "✓ Server preparation complete"
PHASE1

# Phase 2: User Setup
echo -e "\n${YELLOW}Phase 2: Creating claudedev user...${NC}"
ssh root@${NEW_SERVER_IP} bash << PHASE2
set -e

# Create user if doesn't exist
if ! id "${CLAUDE_USER}" &>/dev/null; then
    useradd -m -s /bin/bash ${CLAUDE_USER}
    echo "${CLAUDE_USER}:${CLAUDE_PASS}" | chpasswd
    echo "✓ Created user: ${CLAUDE_USER}"
else
    echo "✓ User ${CLAUDE_USER} already exists"
fi

# Add to groups
usermod -aG sudo,docker ${CLAUDE_USER}

# Configure passwordless sudo
echo "${CLAUDE_USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${CLAUDE_USER}
chmod 440 /etc/sudoers.d/${CLAUDE_USER}

echo "✓ User configuration complete"
PHASE2

# Phase 3: Install Claude CLI
echo -e "\n${YELLOW}Phase 3: Installing Claude Code CLI...${NC}"
ssh root@${NEW_SERVER_IP} bash << 'PHASE3'
set -e

# Switch to claudedev and install
su - claudedev << 'INSTALL_CLAUDE'
curl -fsSL https://claude.ai/install.sh | sh

# Verify installation
if command -v claude &> /dev/null; then
    echo "✓ Claude CLI installed successfully"
    claude --version
else
    echo "✗ Claude CLI installation failed"
    exit 1
fi
INSTALL_CLAUDE
PHASE3

# Phase 4: Setup Directories
echo -e "\n${YELLOW}Phase 4: Creating directory structure...${NC}"
ssh root@${NEW_SERVER_IP} bash << PHASE4
set -e

# Create directories as root
mkdir -p /root/.claude-projects

# Create directories as claudedev
su - claudedev << 'DIRS'
mkdir -p ~/.claude
mkdir -p ~/.claude/agents
mkdir -p ~/projects
DIRS

echo "✓ Directory structure created"
PHASE4

# Phase 5: Initialize Registry
echo -e "\n${YELLOW}Phase 5: Initializing project registry...${NC}"
ssh root@${NEW_SERVER_IP} bash << 'PHASE5'
cat > /root/.claude-projects/registry.jsonl << 'REGISTRY'
REGISTRY

echo "✓ Empty registry created at /root/.claude-projects/registry.jsonl"
PHASE5

echo -e "\n${GREEN}=== Server Setup Complete ===${NC}\n"

# Print next steps
cat << NEXT_STEPS
${GREEN}✓ Server ${NEW_SERVER_IP} is ready!${NC}

${YELLOW}Next Steps:${NC}

1. ${GREEN}Setup Claude API Credentials:${NC}
   ssh root@${NEW_SERVER_IP}
   su - claudedev
   cat > ~/.claude/.credentials.json << 'EOF'
   {
     "oauth": {
       "access_token": "YOUR_ACCESS_TOKEN",
       "refresh_token": "YOUR_REFRESH_TOKEN",
       "expires_at": "2026-01-01T00:00:00Z"
     }
   }
   EOF
   chmod 600 ~/.claude/.credentials.json

2. ${GREEN}Copy Agent Definitions:${NC}
   scp -r .claude/agents root@${NEW_SERVER_IP}:/home/claudedev/.claude/
   ssh root@${NEW_SERVER_IP} "chown -R claudedev:claudedev /home/claudedev/.claude"

3. ${GREEN}Copy Project Files:${NC}
   scp CLAUDE.md *.sh setup_ssh_key.* root@${NEW_SERVER_IP}:/home/claudedev/
   ssh root@${NEW_SERVER_IP} "chown -R claudedev:claudedev /home/claudedev/"

4. ${GREEN}Update IP addresses in agent files:${NC}
   sed -i 's/188.245.38.217/${NEW_SERVER_IP}/g' .claude/agents/*.md
   sed -i 's/188.245.38.217/${NEW_SERVER_IP}/g' CLAUDE.md
   # Then re-copy updated files

5. ${GREEN}Test Remote Claude CLI:${NC}
   ssh root@${NEW_SERVER_IP} 'sudo -u claudedev bash -c "cd ~ && claude -p \"Test: Echo hello\" --dangerously-skip-permissions --max-turns 1"'

6. ${GREEN}Setup SSH Key Authentication:${NC}
   ssh-copy-id root@${NEW_SERVER_IP}
   # Test: ssh root@${NEW_SERVER_IP} "echo 'SSH key works'"

${YELLOW}Server Details:${NC}
- IP: ${NEW_SERVER_IP}
- User: claudedev
- Password: ${CLAUDE_PASS}
- Docker: Installed and running
- Claude CLI: Installed

${YELLOW}Verify Installation:${NC}
ssh root@${NEW_SERVER_IP} "docker --version && python3 --version && su - claudedev -c 'claude --version'"

NEXT_STEPS
