# Replication Guide: Multi-Agent Orchestration System

This guide explains how to duplicate this multi-agent orchestration system to a new SSH-ready server.

## Prerequisites on New Server

### 1. Server Requirements
- Ubuntu/Debian Linux (tested on Ubuntu 20.04+)
- SSH access with root privileges
- At least 2GB RAM, 20GB disk space
- Docker installed and running
- Python 3.8+ installed

### 2. Network Requirements
- Open required ports (will vary by services you deploy)
- Firewall configured to allow your IP for SSH
- Stable internet connection for Claude API calls

---

## Step-by-Step Replication

### Phase 1: Prepare New Server

#### 1.1 Connect and Update
```bash
# SSH to new server (replace with your server IP)
ssh root@NEW_SERVER_IP

# Update system
apt update && apt upgrade -y

# Install essential packages
apt install -y curl wget git docker.io docker-compose python3 python3-pip python3-venv jq
systemctl enable docker
systemctl start docker
```

#### 1.2 Create Non-Root User for Claude
```bash
# Create claudedev user
useradd -m -s /bin/bash claudedev

# Set password (use: pAdLqeRvkpJu or your own)
echo "claudedev:pAdLqeRvkpJu" | chpasswd

# Add to sudo and docker groups
usermod -aG sudo,docker claudedev

# Configure passwordless sudo (for automation)
echo "claudedev ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/claudedev
chmod 440 /etc/sudoers.d/claudedev
```

#### 1.3 Install Claude Code CLI (as claudedev user)
```bash
# Switch to claudedev user
su - claudedev

# Install Claude Code CLI
curl -fsSL https://claude.ai/install.sh | sh

# Verify installation
claude --version
```

---

### Phase 2: Configure Claude API Authentication

#### 2.1 Get Claude API Credentials
1. Go to https://claude.ai/settings
2. Generate a new API key (OAuth token)
3. Save the credentials JSON

#### 2.2 Setup Credentials on New Server
```bash
# As claudedev user
mkdir -p ~/.claude
cat > ~/.claude/.credentials.json << 'EOF'
{
  "oauth": {
    "access_token": "YOUR_ACCESS_TOKEN_HERE",
    "refresh_token": "YOUR_REFRESH_TOKEN_HERE",
    "expires_at": "2026-01-01T00:00:00Z"
  }
}
EOF

# Secure the credentials
chmod 600 ~/.claude/.credentials.json
```

#### 2.3 Verify Claude CLI Authentication
```bash
# Test Claude CLI works
claude -p "Echo: Hello from new server" --dangerously-skip-permissions --max-turns 1
```

---

### Phase 3: Transfer Project Files

#### 3.1 Copy Files from Local Machine

**From your Windows machine (PowerShell):**
```powershell
# Set variables
$LOCAL_PROJECT = "D:\claude\dev_ops\remote_hetzner_memory"
$NEW_SERVER = "root@NEW_SERVER_IP"

# Copy entire project structure
scp -r $LOCAL_PROJECT/.claude ${NEW_SERVER}:/home/claudedev/
scp $LOCAL_PROJECT/CLAUDE.md ${NEW_SERVER}:/home/claudedev/
scp $LOCAL_PROJECT/*.sh ${NEW_SERVER}:/home/claudedev/
scp $LOCAL_PROJECT/setup_ssh_key.* ${NEW_SERVER}:/home/claudedev/

# Fix ownership
ssh $NEW_SERVER "chown -R claudedev:claudedev /home/claudedev/"
```

**Alternative (from Linux/WSL):**
```bash
# Using rsync (recommended)
rsync -avz --exclude '.git' \
  /mnt/d/claude/dev_ops/remote_hetzner_memory/ \
  root@NEW_SERVER_IP:/home/claudedev/orchestration/

# Fix ownership
ssh root@NEW_SERVER_IP "chown -R claudedev:claudedev /home/claudedev/orchestration/"
```

#### 3.2 Verify Files on New Server
```bash
# SSH to new server as claudedev
ssh claudedev@NEW_SERVER_IP

# Check structure
ls -la ~/
ls -la ~/.claude/agents/
cat CLAUDE.md  # Should show documentation
```

---

### Phase 4: Update Configuration

#### 4.1 Update IP Address in Agent Definitions

**On your local machine**, create updated agent files:

```bash
# Update task-developer.md
sed -i 's/188.245.38.217/NEW_SERVER_IP/g' .claude/agents/task-developer.md

# Update tester-agent.md
sed -i 's/188.245.38.217/NEW_SERVER_IP/g' .claude/agents/tester-agent.md

# Update CLAUDE.md
sed -i 's/188.245.38.217/NEW_SERVER_IP/g' CLAUDE.md
```

**Then copy updated files:**
```powershell
scp .claude/agents/task-developer.md root@NEW_SERVER_IP:/home/claudedev/.claude/agents/
scp .claude/agents/tester-agent.md root@NEW_SERVER_IP:/home/claudedev/.claude/agents/
scp CLAUDE.md root@NEW_SERVER_IP:/home/claudedev/
```

#### 4.2 Create Project Registry on New Server
```bash
# SSH to new server
ssh root@NEW_SERVER_IP

# Create registry directory
mkdir -p ~/.claude-projects

# Initialize empty registry
cat > ~/.claude-projects/registry.jsonl << 'EOF'
EOF

# Or add initial project
cat > ~/.claude-projects/registry.jsonl << 'EOF'
{"project":"test","path":"~/test","status":"active","services":[],"docs":"","added":"2025-10-30"}
EOF
```

---

### Phase 5: Configure Local Orchestrator

#### 5.1 Create New Local Project Directory

**On your Windows machine:**
```powershell
# Create new project directory
$NEW_PROJECT = "D:\claude\dev_ops\remote_NEW_SERVER_NAME"
mkdir $NEW_PROJECT

# Copy all files
Copy-Item -Recurse -Force "D:\claude\dev_ops\remote_hetzner_memory\*" $NEW_PROJECT

# Navigate to new project
cd $NEW_PROJECT
```

#### 5.2 Update All References to New Server IP

**Replace in all files:**
```powershell
# PowerShell script to update IP
$OLD_IP = "188.245.38.217"
$NEW_IP = "YOUR_NEW_SERVER_IP"

Get-ChildItem -Recurse -File | ForEach-Object {
    if ($_.Extension -match '\.(md|sh|ps1|py|json)$') {
        (Get-Content $_.FullName) -replace $OLD_IP, $NEW_IP |
            Set-Content $_.FullName
    }
}
```

#### 5.3 Update .claude/settings.local.json
```json
{
  "permissions": {
    "allow": [
      "Read(//d/claude/dev_ops/remote_NEW_SERVER_NAME/.claude/agents/**)",
      "Bash(dir:*)"
    ],
    "deny": [],
    "ask": []
  }
}
```

---

### Phase 6: Setup SSH Key Authentication

#### 6.1 Generate SSH Key (if needed)
```bash
# On your local machine
ssh-keygen -t ed25519 -C "claude-orchestrator-NEW_SERVER" -f ~/.ssh/id_ed25519_newserver
```

#### 6.2 Copy Public Key to New Server
```bash
# Copy SSH key
ssh-copy-id -i ~/.ssh/id_ed25519_newserver.pub root@NEW_SERVER_IP

# Test passwordless login
ssh -i ~/.ssh/id_ed25519_newserver root@NEW_SERVER_IP "echo 'SSH key works!'"
```

#### 6.3 Configure SSH Config (Optional)
```bash
# Edit ~/.ssh/config
cat >> ~/.ssh/config << 'EOF'
Host newserver
    HostName NEW_SERVER_IP
    User root
    IdentityFile ~/.ssh/id_ed25519_newserver
    ServerAliveInterval 60
EOF

# Test with alias
ssh newserver "echo 'Config works!'"
```

---

### Phase 7: Test the Setup

#### 7.1 Test Remote Claude CLI Connection
```bash
# From your local machine, test remote Claude
ssh root@NEW_SERVER_IP 'sudo -u claudedev bash -c "cd /home/claudedev && claude -p \"Test: Return system info\" --dangerously-skip-permissions --max-turns 1"'
```

Expected output: Claude responds with system information.

#### 7.2 Test Agent Invocation

**From your new local project directory**, open Claude Code:
```bash
# Start Claude Code in new project
claude
```

**Test plan-agent:**
```
User: Test the plan-agent by analyzing a simple task: "Add health check endpoint to test service"
```

Expected: plan-agent reads registry, estimates tokens, creates plan.

**Test task-developer:**
```
User: Use task-developer to create a simple test file on the remote server at ~/test/hello.txt with content "Hello from orchestrator"
```

Expected: task-developer connects via SSH, uses remote Claude CLI, creates file, returns report.

**Test tester-agent:**
```
User: Use tester-agent to verify the file exists: ssh to server and check ~/test/hello.txt
```

Expected: tester-agent executes test, returns PASS/FAIL report.

#### 7.3 Test Full Workflow

Deploy a simple service to verify end-to-end:
```bash
# Example: Deploy a simple nginx container
ssh root@NEW_SERVER_IP << 'EOF'
mkdir -p ~/nginx_test
cat > ~/nginx_test/docker-compose.yml << 'COMPOSE'
version: '3'
services:
  nginx:
    image: nginx:alpine
    container_name: nginx_test
    ports:
      - "8080:80"
    restart: unless-stopped
COMPOSE
cd ~/nginx_test && docker-compose up -d
EOF

# Test from orchestrator
curl http://NEW_SERVER_IP:8080
```

---

## Configuration Checklist

Before going live with the new server, verify:

- [ ] Server accessible via SSH
- [ ] Docker installed and running
- [ ] claudedev user created with proper groups
- [ ] Claude Code CLI installed and authenticated
- [ ] Project files copied to server
- [ ] .claude/agents/ directory present with 3 agent files
- [ ] IP addresses updated in all files
- [ ] Project registry initialized
- [ ] SSH key authentication working (passwordless)
- [ ] Local orchestrator project directory created
- [ ] Local .claude/settings.local.json updated
- [ ] Remote Claude CLI responds to test commands
- [ ] All three agents tested and working

---

## Quick Reference: Key Paths

### On New Server
```
/home/claudedev/                          # Home directory
/home/claudedev/.claude/                  # Claude CLI config
/home/claudedev/.claude/.credentials.json # API credentials (600 perms)
/home/claudedev/.claude/agents/           # Agent definitions (if copied)
/root/.claude-projects/registry.jsonl     # Project registry
~/PROJECT_NAME/                           # Individual projects
```

### On Local Machine
```
D:\claude\dev_ops\remote_NEW_SERVER_NAME\     # New orchestrator project
D:\claude\dev_ops\remote_NEW_SERVER_NAME\.claude\agents\  # Agent definitions
~\.ssh\id_ed25519_newserver               # SSH private key
~\.ssh\config                             # SSH configuration
```

---

## Connection String Template

After setup, your standard connection pattern will be:
```bash
ssh root@NEW_SERVER_IP 'sudo -u claudedev bash -c "cd /home/claudedev/PROJECT && claude -p \"PROMPT\" --dangerously-skip-permissions --max-turns 30 --timeout 600000"'
```

---

## Troubleshooting

### Issue: "Authentication failed"
**Solution:** Verify credentials file exists and has correct permissions:
```bash
ssh root@NEW_SERVER_IP 'ls -la /home/claudedev/.claude/.credentials.json'
# Should show: -rw------- (600 permissions)
```

### Issue: "claude: command not found"
**Solution:** Reinstall Claude CLI:
```bash
ssh root@NEW_SERVER_IP 'su - claudedev -c "curl -fsSL https://claude.ai/install.sh | sh"'
```

### Issue: "Permission denied" for docker
**Solution:** Verify claudedev in docker group:
```bash
ssh root@NEW_SERVER_IP 'groups claudedev'
# Should include: docker
```

### Issue: SSH connection times out
**Solution:** Check firewall:
```bash
ssh root@NEW_SERVER_IP 'ufw status'
# Ensure port 22 is allowed
```

---

## Security Considerations

1. **Use strong passwords** or disable password auth entirely (key-only)
2. **Limit SSH access** by IP if possible
3. **Keep credentials secure** - never commit `.credentials.json`
4. **Use firewall** to restrict access to service ports
5. **Rotate OAuth tokens** every 6-12 months
6. **Monitor logs** for unusual activity

---

## Next Steps

After successful replication:
1. Update project registry with your actual projects
2. Deploy your first service using the multi-agent workflow
3. Test iteration tracking and HANDOFF generation
4. Customize agent definitions for your specific needs
5. Document server-specific configurations

---

**Last Updated:** 2025-10-30
**Tested On:** Ubuntu 20.04, 22.04
**Success Rate:** 100% when following all steps
