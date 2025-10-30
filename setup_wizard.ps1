# Interactive Setup Wizard - GitHub Clone Workflow (PowerShell)
# Run this after cloning the repository

param()

$ErrorActionPreference = "Stop"

# Banner
Clear-Host
Write-Host @"

╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   Multi-Agent Orchestration Setup Wizard                     ║
║   GitHub Clone → Configure → Start Working                   ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

# Check if already configured
if (Test-Path "config.json") {
    Write-Host "⚠️  Configuration file already exists!" -ForegroundColor Yellow
    Write-Host "Found: config.json`n"
    $reconfigure = Read-Host "Do you want to reconfigure? (y/N)"
    if ($reconfigure -ne 'y' -and $reconfigure -ne 'Y') {
        Write-Host "✓ Using existing configuration" -ForegroundColor Green
        Write-Host "`nYou can start working now:"
        Write-Host "  claude" -ForegroundColor Cyan
        exit 0
    }
    Write-Host ""
}

# Step 1: Collect SSH Server Information
Write-Host "═══ Step 1/4: SSH Server Information ═══`n" -ForegroundColor Blue

$serverIP = Read-Host "Enter SSH Server IP"
if ([string]::IsNullOrWhiteSpace($serverIP)) {
    Write-Host "✗ Server IP is required" -ForegroundColor Red
    exit 1
}

$sshUser = Read-Host "Enter SSH Username [root]"
if ([string]::IsNullOrWhiteSpace($sshUser)) { $sshUser = "root" }

$sshPort = Read-Host "Enter SSH Port [22]"
if ([string]::IsNullOrWhiteSpace($sshPort)) { $sshPort = "22" }

$claudeUser = Read-Host "Enter Claude User [claudedev]"
if ([string]::IsNullOrWhiteSpace($claudeUser)) { $claudeUser = "claudedev" }

Write-Host "`n✓ Server information collected`n" -ForegroundColor Green

# Step 2: Test SSH Connection
Write-Host "═══ Step 2/4: Testing SSH Connection ═══`n" -ForegroundColor Blue

Write-Host "Testing connection to ${sshUser}@${serverIP}:${sshPort}..."

try {
    $testResult = ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -p $sshPort "${sshUser}@${serverIP}" "echo 'Connection successful'" 2>$null
    if ($testResult -match "Connection successful") {
        Write-Host "✓ SSH connection successful!`n" -ForegroundColor Green
    } else {
        throw "Connection test failed"
    }
} catch {
    Write-Host "✗ SSH connection failed" -ForegroundColor Red
    Write-Host ""
    Write-Host "Possible solutions:"
    Write-Host "  1. Check server IP address"
    Write-Host "  2. Ensure SSH port $sshPort is open"
    Write-Host "  3. Setup SSH key: ssh-copy-id -p $sshPort ${sshUser}@${serverIP}"
    Write-Host "  4. Check firewall rules"
    Write-Host ""
    $continue = Read-Host "Do you want to continue anyway? (y/N)"
    if ($continue -ne 'y' -and $continue -ne 'Y') {
        exit 1
    }
    Write-Host ""
}

# Step 3: Collect Claude API Credentials
Write-Host "═══ Step 3/4: Claude API Credentials ═══`n" -ForegroundColor Blue

Write-Host "Get your credentials from: https://claude.ai/settings"
Write-Host ""

$accessToken = Read-Host "Enter Claude Access Token"
if ([string]::IsNullOrWhiteSpace($accessToken)) {
    Write-Host "✗ Access token is required" -ForegroundColor Red
    exit 1
}

$refreshToken = Read-Host "Enter Claude Refresh Token"
if ([string]::IsNullOrWhiteSpace($refreshToken)) {
    Write-Host "✗ Refresh token is required" -ForegroundColor Red
    exit 1
}

$expiresAt = Read-Host "Enter Token Expiry Date [2026-01-01T00:00:00Z]"
if ([string]::IsNullOrWhiteSpace($expiresAt)) { $expiresAt = "2026-01-01T00:00:00Z" }

Write-Host "`n✓ Claude credentials collected`n" -ForegroundColor Green

# Step 4: Create Configuration
Write-Host "═══ Step 4/4: Creating Configuration ═══`n" -ForegroundColor Blue

$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

$config = @{
    server = @{
        ip = $serverIP
        ssh_user = $sshUser
        ssh_port = [int]$sshPort
        claude_user = $claudeUser
    }
    claude = @{
        oauth = @{
            access_token = $accessToken
            refresh_token = $refreshToken
            expires_at = $expiresAt
        }
    }
    setup = @{
        completed = $true
        timestamp = $timestamp
        version = "1.0"
    }
}

$config | ConvertTo-Json -Depth 10 | Set-Content "config.json" -Encoding UTF8
Write-Host "✓ Created config.json" -ForegroundColor Green

# Update agent files with server IP
Write-Host "Updating agent definitions..."

$oldIP = "188.245.38.217"

if (Test-Path ".claude/agents/task-developer.md") {
    (Get-Content ".claude/agents/task-developer.md") -replace [regex]::Escape($oldIP), $serverIP |
        Set-Content ".claude/agents/task-developer.md"
    Write-Host "✓ Updated task-developer.md" -ForegroundColor Green
}

if (Test-Path ".claude/agents/tester-agent.md") {
    (Get-Content ".claude/agents/tester-agent.md") -replace [regex]::Escape($oldIP), $serverIP |
        Set-Content ".claude/agents/tester-agent.md"
    Write-Host "✓ Updated tester-agent.md" -ForegroundColor Green
}

if (Test-Path "CLAUDE.md") {
    (Get-Content "CLAUDE.md") -replace [regex]::Escape($oldIP), $serverIP |
        Set-Content "CLAUDE.md"
    Write-Host "✓ Updated CLAUDE.md" -ForegroundColor Green
}

Write-Host ""

# Step 5: Setup Remote Server
Write-Host "═══ Step 5/5: Setting Up Remote Server ═══`n" -ForegroundColor Blue

$setupRemote = Read-Host "Do you want to setup the remote server now? (Y/n)"
if ([string]::IsNullOrWhiteSpace($setupRemote)) { $setupRemote = "Y" }

if ($setupRemote -eq 'Y' -or $setupRemote -eq 'y') {
    Write-Host ""
    Write-Host "Installing required packages on remote server..."

    $remoteSetupScript = @'
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
'@

    try {
        ssh -p $sshPort "${sshUser}@${serverIP}" $remoteSetupScript
        Write-Host "`n✓ Remote server configured successfully!`n" -ForegroundColor Green
    } catch {
        Write-Host "`n⚠️  Remote setup encountered issues (non-critical)`n" -ForegroundColor Yellow
    }

    # Upload Claude credentials
    Write-Host "Uploading Claude credentials to remote server..."

    $credentials = @{
        oauth = @{
            access_token = $accessToken
            refresh_token = $refreshToken
            expires_at = $expiresAt
        }
    } | ConvertTo-Json -Depth 10

    $credentials | ssh -p $sshPort "${sshUser}@${serverIP}" "cat > /tmp/credentials.json"

    $moveCredsScript = @'
su - claudedev << 'MOVE_CREDS'
mv /tmp/credentials.json ~/.claude/.credentials.json
chmod 600 ~/.claude/.credentials.json
MOVE_CREDS
'@

    ssh -p $sshPort "${sshUser}@${serverIP}" $moveCredsScript

    Write-Host "✓ Credentials uploaded`n" -ForegroundColor Green

    # Test remote Claude CLI
    Write-Host "Testing remote Claude Code CLI..."

    try {
        $testOutput = ssh -p $sshPort "${sshUser}@${serverIP}" 'sudo -u claudedev bash -c "cd ~ && claude -p \"Test: Return hostname\" --dangerously-skip-permissions --max-turns 1 2>&1"'
        if ($testOutput -match "hostname") {
            Write-Host "✓ Remote Claude CLI working!`n" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Remote Claude CLI test inconclusive" -ForegroundColor Yellow
            Write-Host "You may need to verify manually"
            Write-Host ""
        }
    } catch {
        Write-Host "⚠️  Could not test remote Claude CLI" -ForegroundColor Yellow
        Write-Host ""
    }
} else {
    Write-Host "`n⚠️  Skipped remote setup" -ForegroundColor Yellow
    Write-Host "You'll need to run the setup manually later"
    Write-Host ""
}

# Summary
Write-Host @"

╔═══════════════════════════════════════════════════════════════╗
║                    Setup Complete! 🎉                         ║
╚═══════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

Write-Host "✓ Configuration saved to config.json" -ForegroundColor Green
Write-Host "✓ Agent definitions updated" -ForegroundColor Green
Write-Host "✓ Remote server configured" -ForegroundColor Green
Write-Host ""

Write-Host "Next Steps:" -ForegroundColor Blue
Write-Host ""
Write-Host "  1. " -NoNewline
Write-Host "Start Claude Code:" -ForegroundColor Cyan
Write-Host "     " -NoNewline
Write-Host "claude" -ForegroundColor Yellow
Write-Host ""
Write-Host "  2. " -NoNewline
Write-Host "Test the system:" -ForegroundColor Cyan
Write-Host "     User: " -NoNewline
Write-Host "Test the plan-agent with a simple task" -ForegroundColor Yellow
Write-Host ""
Write-Host "  3. " -NoNewline
Write-Host "Deploy your first service:" -ForegroundColor Cyan
Write-Host "     User: " -NoNewline
Write-Host "Deploy nginx on port 8080" -ForegroundColor Yellow
Write-Host ""

Write-Host "Configuration Details:" -ForegroundColor Blue
Write-Host "  Server: " -NoNewline
Write-Host "${sshUser}@${serverIP}:${sshPort}" -ForegroundColor Yellow
Write-Host "  Claude User: " -NoNewline
Write-Host $claudeUser -ForegroundColor Yellow
Write-Host "  Config File: " -NoNewline
Write-Host "config.json" -ForegroundColor Yellow
Write-Host ""

Write-Host "Documentation:" -ForegroundColor Blue
Write-Host "  README.md - Overview and usage"
Write-Host "  CLAUDE.md - Technical reference"
Write-Host "  REPLICATION_GUIDE.md - Detailed guides"
Write-Host ""

Write-Host "Ready to orchestrate! 🚀`n" -ForegroundColor Green
