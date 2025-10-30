# Quick Replication Checklist

Use this checklist for fast replication to a new server.

## Prerequisites
- [ ] New server SSH-ready (Ubuntu/Debian preferred)
- [ ] Root access available
- [ ] Claude API credentials ready (OAuth token)
- [ ] At least 2GB RAM, 20GB disk on new server

---

## Method 1: Automated Setup (Recommended)

### Windows (PowerShell)
```powershell
# Run from project directory
.\setup_new_server.ps1 -ServerIP "YOUR_NEW_SERVER_IP"

# Follow the 6 steps printed at the end
```

### Linux/Mac (Bash)
```bash
# Run from project directory
bash setup_new_server.sh YOUR_NEW_SERVER_IP

# Follow the 6 steps printed at the end
```

### After Automated Setup
Complete these manual steps:

1. **Add Claude credentials** (on new server):
```bash
ssh root@NEW_SERVER_IP
su - claudedev
nano ~/.claude/.credentials.json
# Paste your OAuth credentials, save, chmod 600
```

2. **Copy agent files**:
```bash
# From local machine
scp -r .claude/agents root@NEW_SERVER_IP:/home/claudedev/.claude/
scp CLAUDE.md *.sh root@NEW_SERVER_IP:/home/claudedev/
ssh root@NEW_SERVER_IP "chown -R claudedev:claudedev /home/claudedev/"
```

3. **Update IP addresses** in local files:
```bash
# Replace 188.245.38.217 with YOUR_NEW_SERVER_IP in:
# - .claude/agents/task-developer.md
# - .claude/agents/tester-agent.md
# - CLAUDE.md
```

4. **Test connection**:
```bash
ssh root@NEW_SERVER_IP 'sudo -u claudedev bash -c "claude -p \"Test\" --dangerously-skip-permissions --max-turns 1"'
```

✅ **Done!** Your new server is ready.

---

## Method 2: Manual Setup (Step-by-Step)

### On New Server

#### Step 1: System Setup (5 min)
```bash
ssh root@NEW_SERVER_IP
apt update && apt upgrade -y
apt install -y docker.io docker-compose python3 python3-pip python3-venv jq curl wget git
systemctl enable docker && systemctl start docker
```

#### Step 2: User Setup (2 min)
```bash
useradd -m -s /bin/bash claudedev
echo "claudedev:pAdLqeRvkpJu" | chpasswd
usermod -aG sudo,docker claudedev
echo "claudedev ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/claudedev
chmod 440 /etc/sudoers.d/claudedev
```

#### Step 3: Install Claude CLI (2 min)
```bash
su - claudedev
curl -fsSL https://claude.ai/install.sh | sh
claude --version  # Verify
exit
```

#### Step 4: Setup Directories (1 min)
```bash
mkdir -p /root/.claude-projects
echo '' > /root/.claude-projects/registry.jsonl
su - claudedev
mkdir -p ~/.claude ~/.claude/agents ~/projects
exit
```

#### Step 5: Add Credentials (3 min)
```bash
su - claudedev
cat > ~/.claude/.credentials.json << 'EOF'
{
  "oauth": {
    "access_token": "YOUR_ACCESS_TOKEN_HERE",
    "refresh_token": "YOUR_REFRESH_TOKEN_HERE",
    "expires_at": "2026-01-01T00:00:00Z"
  }
}
EOF
chmod 600 ~/.claude/.credentials.json
exit
```

### On Local Machine

#### Step 6: Copy Files (2 min)
```bash
# Copy agent definitions
scp -r .claude/agents root@NEW_SERVER_IP:/home/claudedev/.claude/

# Copy project files
scp CLAUDE.md *.sh setup_ssh_key.* root@NEW_SERVER_IP:/home/claudedev/

# Fix ownership
ssh root@NEW_SERVER_IP "chown -R claudedev:claudedev /home/claudedev/"
```

#### Step 7: Update IP Addresses (2 min)
```bash
# Create new project directory
OLD_IP="188.245.38.217"
NEW_IP="YOUR_NEW_SERVER_IP"

# Update task-developer.md
sed -i "s/$OLD_IP/$NEW_IP/g" .claude/agents/task-developer.md

# Update tester-agent.md
sed -i "s/$OLD_IP/$NEW_IP/g" .claude/agents/tester-agent.md

# Update CLAUDE.md
sed -i "s/$OLD_IP/$NEW_IP/g" CLAUDE.md

# Re-copy updated files
scp .claude/agents/*.md root@$NEW_IP:/home/claudedev/.claude/agents/
scp CLAUDE.md root@$NEW_IP:/home/claudedev/
```

#### Step 8: Setup SSH Keys (2 min)
```bash
# Copy your SSH key
ssh-copy-id root@NEW_SERVER_IP

# Test passwordless login
ssh root@NEW_SERVER_IP "echo 'SSH works!'"
```

#### Step 9: Test Everything (3 min)
```bash
# Test remote Claude CLI
ssh root@NEW_SERVER_IP 'sudo -u claudedev bash -c "cd ~ && claude -p \"Test: Return hostname\" --dangerously-skip-permissions --max-turns 1"'

# Should return server hostname - SUCCESS!
```

✅ **Total time: ~20 minutes**

---

## Verification Tests

After setup, verify everything works:

### Test 1: SSH Connection
```bash
ssh root@NEW_SERVER_IP "echo 'Connected'"
# Expected: "Connected"
```

### Test 2: Docker
```bash
ssh root@NEW_SERVER_IP "docker ps"
# Expected: List of containers (may be empty)
```

### Test 3: Claude CLI
```bash
ssh root@NEW_SERVER_IP 'su - claudedev -c "claude --version"'
# Expected: Claude Code version number
```

### Test 4: Remote Claude Execution
```bash
ssh root@NEW_SERVER_IP 'sudo -u claudedev bash -c "cd ~ && claude -p \"Write test.txt with content Hello\" --dangerously-skip-permissions --max-turns 1"'
# Expected: Claude creates file, confirms completion
```

### Test 5: Verify File Created
```bash
ssh root@NEW_SERVER_IP 'su - claudedev -c "cat ~/test.txt"'
# Expected: "Hello"
```

### Test 6: Multi-Agent Workflow
Open Claude Code in your local project:
```bash
cd /path/to/new/project
claude
```

Then test:
```
User: Test the plan-agent by estimating tokens for task: "Create simple health check endpoint"
```

Expected: plan-agent analyzes, estimates tokens, returns plan.

---

## Common Issues & Fixes

### Issue: "Authentication failed"
```bash
# Fix credentials
ssh root@NEW_SERVER_IP
su - claudedev
ls -la ~/.claude/.credentials.json  # Should be 600 perms
cat ~/.claude/.credentials.json     # Check content
```

### Issue: "claude: command not found"
```bash
# Reinstall Claude CLI
ssh root@NEW_SERVER_IP
su - claudedev
curl -fsSL https://claude.ai/install.sh | sh
source ~/.bashrc
```

### Issue: "Permission denied (docker)"
```bash
# Fix docker group
ssh root@NEW_SERVER_IP
usermod -aG docker claudedev
# Then logout/login claudedev
```

### Issue: "Connection timeout"
```bash
# Check firewall
ssh root@NEW_SERVER_IP 'ufw status'
# If blocking, allow SSH: ufw allow 22
```

---

## Quick Reference: Key Commands

**Test remote Claude:**
```bash
ssh root@IP 'sudo -u claudedev bash -c "cd ~ && claude -p \"PROMPT\" --dangerously-skip-permissions --max-turns 1"'
```

**Copy files to server:**
```bash
scp file.txt root@IP:/home/claudedev/
```

**Run command on server:**
```bash
ssh root@IP "command here"
```

**Check service status:**
```bash
ssh root@IP "docker ps"
ssh root@IP "systemctl status docker"
```

---

## What You Get After Setup

✅ Remote server ready for orchestration
✅ Claude Code CLI installed and authenticated
✅ Multi-agent system configured (plan, develop, test)
✅ Docker environment for containerized services
✅ Project registry initialized
✅ SSH key authentication enabled
✅ All agent definitions deployed

**Ready to deploy services using the multi-agent workflow!**

---

**Estimated Setup Time:**
- Automated: 10 minutes + manual steps
- Manual: 20 minutes

**Difficulty:** ⭐⭐⚪⚪⚪ (Easy-Medium)
