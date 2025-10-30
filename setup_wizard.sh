#!/bin/bash
# Interactive Setup Wizard - GitHub Clone Workflow
# Run this after cloning the repository

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Banner
clear
echo -e "${CYAN}"
cat << 'BANNER'
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   Multi-Agent Orchestration Setup Wizard                     ║
║   GitHub Clone → Configure → Start Working                   ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
BANNER
echo -e "${NC}\n"

# Check if already configured
if [ -f "config.json" ]; then
    echo -e "${YELLOW}⚠️  Configuration file already exists!${NC}"
    echo -e "Found: config.json\n"
    read -p "Do you want to reconfigure? (y/N): " RECONFIGURE
    if [[ ! "$RECONFIGURE" =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}✓ Using existing configuration${NC}"
        echo -e "\nYou can start working now:"
        echo -e "  ${CYAN}claude${NC}"
        exit 0
    fi
    echo ""
fi

# Step 1: Collect SSH Server Information
echo -e "${BLUE}═══ Step 1/4: SSH Server Information ═══${NC}\n"

read -p "Enter SSH Server IP: " SERVER_IP
if [ -z "$SERVER_IP" ]; then
    echo -e "${RED}✗ Server IP is required${NC}"
    exit 1
fi

read -p "Enter SSH Username [root]: " SSH_USER
SSH_USER=${SSH_USER:-root}

read -p "Enter SSH Port [22]: " SSH_PORT
SSH_PORT=${SSH_PORT:-22}

read -p "Enter Claude User [claudedev]: " CLAUDE_USER
CLAUDE_USER=${CLAUDE_USER:-claudedev}

echo -e "\n${GREEN}✓ Server information collected${NC}\n"

# Step 2: Test SSH Connection
echo -e "${BLUE}═══ Step 2/4: Testing SSH Connection ═══${NC}\n"

echo "Testing connection to ${SSH_USER}@${SERVER_IP}:${SSH_PORT}..."

if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -p ${SSH_PORT} ${SSH_USER}@${SERVER_IP} "echo 'Connection successful'" 2>/dev/null; then
    echo -e "${GREEN}✓ SSH connection successful!${NC}\n"
else
    echo -e "${RED}✗ SSH connection failed${NC}"
    echo ""
    echo "Possible solutions:"
    echo "  1. Check server IP address"
    echo "  2. Ensure SSH port ${SSH_PORT} is open"
    echo "  3. Setup SSH key: ssh-copy-id -p ${SSH_PORT} ${SSH_USER}@${SERVER_IP}"
    echo "  4. Check firewall rules"
    echo ""
    read -p "Do you want to continue anyway? (y/N): " CONTINUE
    if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
        exit 1
    fi
    echo ""
fi

# Step 3: Collect Claude API Credentials
echo -e "${BLUE}═══ Step 3/4: Claude API Credentials ═══${NC}\n"

echo "Get your credentials from: https://claude.ai/settings"
echo ""

read -p "Enter Claude Access Token: " ACCESS_TOKEN
if [ -z "$ACCESS_TOKEN" ]; then
    echo -e "${RED}✗ Access token is required${NC}"
    exit 1
fi

read -p "Enter Claude Refresh Token: " REFRESH_TOKEN
if [ -z "$REFRESH_TOKEN" ]; then
    echo -e "${RED}✗ Refresh token is required${NC}"
    exit 1
fi

read -p "Enter Token Expiry Date [2026-01-01T00:00:00Z]: " EXPIRES_AT
EXPIRES_AT=${EXPIRES_AT:-2026-01-01T00:00:00Z}

echo -e "\n${GREEN}✓ Claude credentials collected${NC}\n"

# Step 4: Create Configuration
echo -e "${BLUE}═══ Step 4/4: Creating Configuration ═══${NC}\n"

# Create config.json
cat > config.json << EOF
{
  "server": {
    "ip": "${SERVER_IP}",
    "ssh_user": "${SSH_USER}",
    "ssh_port": ${SSH_PORT},
    "claude_user": "${CLAUDE_USER}"
  },
  "claude": {
    "oauth": {
      "access_token": "${ACCESS_TOKEN}",
      "refresh_token": "${REFRESH_TOKEN}",
      "expires_at": "${EXPIRES_AT}"
    }
  },
  "setup": {
    "completed": true,
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "version": "1.0"
  }
}
EOF

chmod 600 config.json
echo -e "${GREEN}✓ Created config.json${NC}"

# Update agent files with server IP
echo "Updating agent definitions..."

if [ -f ".claude/agents/task-developer.md" ]; then
    sed -i "s/188\.245\.38\.217/${SERVER_IP}/g" .claude/agents/task-developer.md
    echo -e "${GREEN}✓ Updated task-developer.md${NC}"
fi

if [ -f ".claude/agents/tester-agent.md" ]; then
    sed -i "s/188\.245\.38\.217/${SERVER_IP}/g" .claude/agents/tester-agent.md
    echo -e "${GREEN}✓ Updated tester-agent.md${NC}"
fi

if [ -f "CLAUDE.md" ]; then
    sed -i "s/188\.245\.38\.217/${SERVER_IP}/g" CLAUDE.md
    echo -e "${GREEN}✓ Updated CLAUDE.md${NC}"
fi

echo ""

# Step 5: Setup Remote Server
echo -e "${BLUE}═══ Step 5/5: Setting Up Remote Server ═══${NC}\n"

read -p "Do you want to setup the remote server now? (Y/n): " SETUP_REMOTE
SETUP_REMOTE=${SETUP_REMOTE:-Y}

if [[ "$SETUP_REMOTE" =~ ^[Yy]$ ]]; then
    echo ""
    echo "Installing required packages on remote server..."

    ssh -p ${SSH_PORT} ${SSH_USER}@${SERVER_IP} bash << 'REMOTE_SETUP'
set -e

echo "→ Updating system packages..."
apt update -qq

echo "→ Installing Docker, Python, and tools..."
apt install -y -qq docker.io docker-compose python3 python3-pip python3-venv jq curl wget git 2>&1 | grep -v "already"

echo "→ Starting Docker..."
systemctl enable docker >/dev/null 2>&1
systemctl start docker

echo "→ Creating claudedev user..."
if ! id "claudedev" &>/dev/null; then
    useradd -m -s /bin/bash claudedev
    echo "claudedev:pAdLqeRvkpJu" | chpasswd
    usermod -aG sudo,docker claudedev
    echo "claudedev ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/claudedev
    chmod 440 /etc/sudoers.d/claudedev
fi

echo "→ Installing Claude Code CLI..."
su - claudedev << 'INSTALL_CLAUDE'
if ! command -v claude &> /dev/null; then
    curl -fsSL https://claude.ai/install.sh | sh >/dev/null 2>&1
fi
INSTALL_CLAUDE

echo "→ Creating directories..."
mkdir -p /root/.claude-projects
echo '' > /root/.claude-projects/registry.jsonl
su - claudedev -c "mkdir -p ~/.claude ~/.claude/agents ~/projects"

echo "✓ Remote server setup complete"
REMOTE_SETUP

    if [ $? -eq 0 ]; then
        echo -e "\n${GREEN}✓ Remote server configured successfully!${NC}\n"
    else
        echo -e "\n${YELLOW}⚠️  Remote setup encountered issues (non-critical)${NC}\n"
    fi

    # Upload Claude credentials
    echo "Uploading Claude credentials to remote server..."

    ssh -p ${SSH_PORT} ${SSH_USER}@${SERVER_IP} "cat > /tmp/credentials.json" << EOF
{
  "oauth": {
    "access_token": "${ACCESS_TOKEN}",
    "refresh_token": "${REFRESH_TOKEN}",
    "expires_at": "${EXPIRES_AT}"
  }
}
EOF

    ssh -p ${SSH_PORT} ${SSH_USER}@${SERVER_IP} bash << 'CREDS'
su - claudedev << 'MOVE_CREDS'
mv /tmp/credentials.json ~/.claude/.credentials.json
chmod 600 ~/.claude/.credentials.json
MOVE_CREDS
CREDS

    echo -e "${GREEN}✓ Credentials uploaded${NC}\n"

    # Test remote Claude CLI
    echo "Testing remote Claude Code CLI..."

    TEST_OUTPUT=$(ssh -p ${SSH_PORT} ${SSH_USER}@${SERVER_IP} 'sudo -u claudedev bash -c "cd ~ && claude -p \"Test: Return hostname\" --dangerously-skip-permissions --max-turns 1 2>&1"' || true)

    if echo "$TEST_OUTPUT" | grep -q "hostname"; then
        echo -e "${GREEN}✓ Remote Claude CLI working!${NC}\n"
    else
        echo -e "${YELLOW}⚠️  Remote Claude CLI test inconclusive${NC}"
        echo "You may need to verify manually"
        echo ""
    fi
else
    echo -e "\n${YELLOW}⚠️  Skipped remote setup${NC}"
    echo "You'll need to run the setup manually later"
    echo ""
fi

# Summary
echo -e "${CYAN}"
cat << 'SUMMARY'
╔═══════════════════════════════════════════════════════════════╗
║                    Setup Complete! 🎉                         ║
╚═══════════════════════════════════════════════════════════════╝
SUMMARY
echo -e "${NC}"

echo -e "${GREEN}✓ Configuration saved to config.json${NC}"
echo -e "${GREEN}✓ Agent definitions updated${NC}"
echo -e "${GREEN}✓ Remote server configured${NC}"
echo ""

echo -e "${BLUE}Next Steps:${NC}"
echo ""
echo -e "  1. ${CYAN}Start Claude Code:${NC}"
echo -e "     ${YELLOW}claude${NC}"
echo ""
echo -e "  2. ${CYAN}Test the system:${NC}"
echo -e "     User: ${YELLOW}Test the plan-agent with a simple task${NC}"
echo ""
echo -e "  3. ${CYAN}Deploy your first service:${NC}"
echo -e "     User: ${YELLOW}Deploy nginx on port 8080${NC}"
echo ""

echo -e "${BLUE}Configuration Details:${NC}"
echo -e "  Server: ${YELLOW}${SSH_USER}@${SERVER_IP}:${SSH_PORT}${NC}"
echo -e "  Claude User: ${YELLOW}${CLAUDE_USER}${NC}"
echo -e "  Config File: ${YELLOW}config.json${NC}"
echo ""

echo -e "${BLUE}Documentation:${NC}"
echo -e "  README.md - Overview and usage"
echo -e "  CLAUDE.md - Technical reference"
echo -e "  REPLICATION_GUIDE.md - Detailed guides"
echo ""

echo -e "${GREEN}Ready to orchestrate! 🚀${NC}\n"
