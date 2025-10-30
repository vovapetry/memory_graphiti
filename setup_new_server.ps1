# Automated Setup Script for New Server (PowerShell)
# Usage: .\setup_new_server.ps1 -ServerIP "1.2.3.4"

param(
    [Parameter(Mandatory=$true)]
    [string]$ServerIP,

    [Parameter(Mandatory=$false)]
    [string]$ClaudeUser = "claudedev",

    [Parameter(Mandatory=$false)]
    [string]$ClaudePassword = "pAdLqeRvkpJu"
)

$ErrorActionPreference = "Stop"

# Colors
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

Write-ColorOutput Green "=== Setting up Multi-Agent Orchestration on $ServerIP ==="
Write-Output ""

# Phase 1: Server Preparation
Write-ColorOutput Yellow "Phase 1: Preparing server..."
$phase1Script = @'
set -e
echo "Updating system packages..."
apt update && apt upgrade -y
echo "Installing essential packages..."
apt install -y curl wget git docker.io docker-compose python3 python3-pip python3-venv jq
echo "Enabling Docker..."
systemctl enable docker
systemctl start docker
echo "✓ Server preparation complete"
'@

ssh root@${ServerIP} $phase1Script
Write-ColorOutput Green "✓ Phase 1 complete"

# Phase 2: User Setup
Write-Output ""
Write-ColorOutput Yellow "Phase 2: Creating claudedev user..."
$phase2Script = @"
set -e
if ! id `"$ClaudeUser`" &>/dev/null; then
    useradd -m -s /bin/bash $ClaudeUser
    echo `"$ClaudeUser`:$ClaudePassword`" | chpasswd
    echo `"✓ Created user: $ClaudeUser`"
else
    echo `"✓ User $ClaudeUser already exists`"
fi
usermod -aG sudo,docker $ClaudeUser
echo `"$ClaudeUser ALL=(ALL) NOPASSWD:ALL`" > /etc/sudoers.d/$ClaudeUser
chmod 440 /etc/sudoers.d/$ClaudeUser
echo `"✓ User configuration complete`"
"@

ssh root@${ServerIP} $phase2Script
Write-ColorOutput Green "✓ Phase 2 complete"

# Phase 3: Install Claude CLI
Write-Output ""
Write-ColorOutput Yellow "Phase 3: Installing Claude Code CLI..."
$phase3Script = @"
set -e
su - $ClaudeUser << 'INSTALL_CLAUDE'
curl -fsSL https://claude.ai/install.sh | sh
if command -v claude &> /dev/null; then
    echo `"✓ Claude CLI installed successfully`"
    claude --version
else
    echo `"✗ Claude CLI installation failed`"
    exit 1
fi
INSTALL_CLAUDE
"@

ssh root@${ServerIP} $phase3Script
Write-ColorOutput Green "✓ Phase 3 complete"

# Phase 4: Setup Directories
Write-Output ""
Write-ColorOutput Yellow "Phase 4: Creating directory structure..."
$phase4Script = @"
set -e
mkdir -p /root/.claude-projects
su - $ClaudeUser << 'DIRS'
mkdir -p ~/.claude
mkdir -p ~/.claude/agents
mkdir -p ~/projects
DIRS
echo `"✓ Directory structure created`"
"@

ssh root@${ServerIP} $phase4Script
Write-ColorOutput Green "✓ Phase 4 complete"

# Phase 5: Initialize Registry
Write-Output ""
Write-ColorOutput Yellow "Phase 5: Initializing project registry..."
ssh root@${ServerIP} "echo '' > /root/.claude-projects/registry.jsonl"
Write-ColorOutput Green "✓ Phase 5 complete"

Write-Output ""
Write-ColorOutput Green "=== Server Setup Complete ==="
Write-Output ""

# Print next steps
Write-ColorOutput Yellow "Next Steps:"
Write-Output ""

Write-ColorOutput Green "1. Setup Claude API Credentials:"
Write-Output "   ssh root@$ServerIP"
Write-Output "   su - $ClaudeUser"
Write-Output '   cat > ~/.claude/.credentials.json << ''EOF'''
Write-Output '   {'
Write-Output '     "oauth": {'
Write-Output '       "access_token": "YOUR_ACCESS_TOKEN",'
Write-Output '       "refresh_token": "YOUR_REFRESH_TOKEN",'
Write-Output '       "expires_at": "2026-01-01T00:00:00Z"'
Write-Output '     }'
Write-Output '   }'
Write-Output '   EOF'
Write-Output '   chmod 600 ~/.claude/.credentials.json'
Write-Output ""

Write-ColorOutput Green "2. Copy Agent Definitions:"
Write-Output "   scp -r .claude/agents root@${ServerIP}:/home/$ClaudeUser/.claude/"
Write-Output "   ssh root@$ServerIP `"chown -R $ClaudeUser`:$ClaudeUser /home/$ClaudeUser/.claude`""
Write-Output ""

Write-ColorOutput Green "3. Copy Project Files:"
Write-Output "   scp CLAUDE.md *.sh setup_ssh_key.* root@${ServerIP}:/home/$ClaudeUser/"
Write-Output "   ssh root@$ServerIP `"chown -R $ClaudeUser`:$ClaudeUser /home/$ClaudeUser/`""
Write-Output ""

Write-ColorOutput Green "4. Update IP addresses in agent files:"
$currentDir = Get-Location
Write-Output "   # Update all references from 188.245.38.217 to $ServerIP"
Write-Output "   Get-ChildItem -Recurse -File | ForEach-Object {"
Write-Output "       if (`$_.Extension -match '\.(md|sh|ps1|py|json)$') {"
Write-Output "           (Get-Content `$_.FullName) -replace '188.245.38.217', '$ServerIP' |"
Write-Output "               Set-Content `$_.FullName"
Write-Output "       }"
Write-Output "   }"
Write-Output ""

Write-ColorOutput Green "5. Test Remote Claude CLI:"
Write-Output "   ssh root@$ServerIP 'sudo -u $ClaudeUser bash -c `"cd ~ && claude -p \`"Test: Echo hello\`" --dangerously-skip-permissions --max-turns 1`"'"
Write-Output ""

Write-ColorOutput Green "6. Setup SSH Key Authentication:"
Write-Output "   ssh-copy-id root@$ServerIP"
Write-Output "   # Test: ssh root@$ServerIP `"echo 'SSH key works'`""
Write-Output ""

Write-ColorOutput Yellow "Server Details:"
Write-Output "- IP: $ServerIP"
Write-Output "- User: $ClaudeUser"
Write-Output "- Password: $ClaudePassword"
Write-Output "- Docker: Installed and running"
Write-Output "- Claude CLI: Installed"
Write-Output ""

Write-ColorOutput Yellow "Verify Installation:"
Write-Output "ssh root@$ServerIP `"docker --version && python3 --version && su - $ClaudeUser -c 'claude --version'`""
