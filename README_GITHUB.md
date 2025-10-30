# Multi-Agent Orchestration System

> **One-Command Setup**: Clone from GitHub → Run wizard → Start working in 10 minutes

A sophisticated orchestration system for managing remote servers using Claude Code CLI with specialized agents for planning, development, and testing.

[![Setup Time](https://img.shields.io/badge/Setup-10%20min-brightgreen)](QUICK_REPLICATION_CHECKLIST.md)
[![Automation](https://img.shields.io/badge/Automation-Multi--Agent-blue)](.claude/agents)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20macOS%20%7C%20Windows-lightgrey)](README.md)

---

## 🎯 What Is This?

This project enables you to:
- **Deploy services** on remote servers using AI agents
- **Automatically plan, implement, and test** changes through iterative workflow
- **Leverage Claude Code CLI** on remote servers via SSH
- **Track complex tasks** through multi-iteration development cycles
- **Test implementations** using browser automation, API calls, or CLI commands

## 🚀 Quick Start (GitHub Clone Workflow)

### 1. Clone Repository

```bash
git clone https://github.com/YOUR_USERNAME/remote-orchestration.git
cd remote-orchestration
```

### 2. Run Setup Wizard

**Linux/Mac:**
```bash
./setup_wizard.sh
```

**Windows (PowerShell):**
```powershell
.\setup_wizard.ps1
```

### 3. Enter Your Information

The wizard will ask for:
- SSH server IP address
- SSH credentials
- Claude API token ([Get from here](https://claude.ai/settings))

### 4. Start Working

```bash
claude
```

**That's it! Total time: 10 minutes**

---

## 🏗️ Architecture

```
Local Machine (Windows/Linux/Mac)  │  Remote Server (Ubuntu)
┌─────────────────────────────┐   │  ┌──────────────────────────┐
│  Orchestrator (You)         │ SSH│  │  Claude Code CLI         │
│  ├─ plan-agent             │───┼─▶│  (claudedev user)        │
│  ├─ task-developer         │   │  │                          │
│  └─ tester-agent           │   │  │  Docker Services         │
│                             │   │  │  ├─ Service 1            │
│  Multi-Agent Workflow       │   │  │  ├─ Service 2            │
│  └─ Iteration Tracking      │   │  │  └─ Service N            │
└─────────────────────────────┘   │  └──────────────────────────┘
```

### The Three Agents

1. **plan-agent** - Analyzes tasks, estimates tokens (5-factor model), auto-splits large tasks
2. **task-developer** - Connects to remote Claude CLI, executes plans via SSH
3. **tester-agent** - Tests with browser (Playwright), API (curl), CLI (docker/ssh), or database queries

---

## 📋 Prerequisites

### What You Need:

- **Remote Server:** Ubuntu/Debian with SSH access, 2GB+ RAM
- **Local Machine:** Windows/Linux/macOS with SSH client
- **Claude Account:** API token from [claude.ai/settings](https://claude.ai/settings)

### What Gets Installed (Automatically):

On remote server:
- ✅ Docker & Docker Compose
- ✅ Python 3 & essential tools
- ✅ Claude Code CLI
- ✅ Non-root user (claudedev) for automation

---

## 🎮 Usage

### Basic Workflow

After setup, just open Claude Code and request tasks:

```
User: Deploy nginx service on port 8080
```

The system automatically:
1. **plan-agent** → Analyzes task, estimates 45K tokens, creates plan
2. **TodoWrite** → Tracks iteration 1/10
3. **task-developer** → SSH to server, executes via remote Claude CLI
4. **tester-agent** → Tests with curl http://server:8080
5. **Repeat** until success ✅

### Multi-Agent Pattern

```
plan-agent → estimate & create plan
    ↓
task-developer → execute on remote server
    ↓
tester-agent → test implementation
    ↓
PASS? → Done! 🎉
FAIL? → Iterate (max 10 times or 140K tokens)
```

### Example Tasks

```bash
# Simple deployment
User: Deploy PostgreSQL database with persistent storage

# Complex migration
User: Migrate existing MySQL database to ClickHouse with schema conversion

# Chaos testing
User: Implement circuit breaker pattern and test resilience

# Multi-service orchestration
User: Setup Grafana + Prometheus + ClickHouse monitoring stack
```

---

## 📁 Project Structure

```
remote-orchestration/
├── setup_wizard.sh          ⭐ Run this first (Linux/Mac)
├── setup_wizard.ps1         ⭐ Run this first (Windows)
│
├── .claude/agents/          🤖 Agent definitions
│   ├── plan-agent.md        → Planning & token estimation
│   ├── task-developer.md    → Remote execution via SSH
│   └── tester-agent.md      → Testing & validation
│
├── README.md                📖 This file
├── CLAUDE.md                📚 Technical reference
├── GITHUB_PUBLISHING_GUIDE.md  🚀 How to publish this
├── REPLICATION_GUIDE.md     📋 Detailed setup guide
├── QUICK_REPLICATION_CHECKLIST.md  ✅ Fast reference
│
├── config.template.json     🔧 Configuration template
├── .gitignore              🔒 Excludes credentials
│
└── Examples/ (Templates):
    ├── chaos_tests.sh       → Chaos engineering tests
    ├── deploy_resilient_system.sh  → Resilience deployment
    └── disaster_recovery.sh → DR scenarios
```

---

## 🔧 What the Setup Wizard Does

1. **Collects Information**
   - SSH server IP
   - SSH credentials
   - Claude API token

2. **Tests Connection**
   - Verifies SSH connectivity
   - Checks authentication

3. **Configures Remote Server**
   - Installs Docker, Python, tools
   - Creates claudedev user
   - Installs Claude Code CLI
   - Uploads your credentials

4. **Updates Local Configuration**
   - Replaces placeholder IPs in agent files
   - Creates config.json with your settings
   - Prepares environment

5. **Validates Setup**
   - Tests remote Claude CLI
   - Confirms everything works
   - Reports success ✅

**Total time: ~10 minutes**

---

## 📊 Token Management

- **Budget per task:** 200K tokens
- **Per iteration:** ~20K tokens
- **Safe limit:** 140K tokens (7 iterations)
- **Auto-split:** Tasks >150K split into subtasks

plan-agent uses 5-factor estimation:
```
TOTAL = (Context + Generation) × Complexity × Iteration × Learning
```

---

## 🧪 Testing Capabilities

tester-agent supports multiple methods:

| Method | Use Case | Example |
|--------|----------|---------|
| **Browser** | Web UIs, JavaScript apps | Playwright automation |
| **API** | REST endpoints, health checks | curl, HTTP requests |
| **CLI** | Docker, services, system | docker ps, ssh commands |
| **Database** | SQL queries, data validation | psql, mysql, clickhouse-client |
| **Logs** | Error detection, monitoring | grep, docker logs |

---

## 📚 Documentation

| File | Purpose |
|------|---------|
| **README.md** | Overview & quick start (you are here) |
| **CLAUDE.md** | Technical reference for Claude Code |
| **GITHUB_PUBLISHING_GUIDE.md** | How to publish to GitHub |
| **REPLICATION_GUIDE.md** | Detailed setup instructions |
| **QUICK_REPLICATION_CHECKLIST.md** | Fast reference checklist |

---

## 🔐 Security

- ✅ SSH key-based authentication
- ✅ Credentials never committed (`.gitignore`)
- ✅ OAuth tokens with 1-year expiry
- ✅ Docker isolation for services
- ✅ Non-root automation user
- ✅ Secure credential storage (600 perms)

---

## 🎯 Use Cases

- ✅ Service deployment (Docker-based)
- ✅ Server configuration
- ✅ Application development & testing
- ✅ Chaos engineering & resilience testing
- ✅ Disaster recovery implementation
- ✅ Multi-server management

---

## 📈 Performance

**Verified through 36 tests (97% success rate):**

- File operations: 5000+ lines supported
- Search operations: <3s response time
- Remote Claude CLI: <3s average response
- SSH latency: <1s
- Iterations to success: 2-4 average

---

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to contribute.

1. Fork the repository
2. Create a feature branch
3. Test with setup_wizard
4. Submit a pull request

---

## 🐛 Troubleshooting

### Setup wizard fails to connect

```bash
# Test SSH manually
ssh root@YOUR_SERVER_IP

# Setup SSH key if needed
ssh-copy-id root@YOUR_SERVER_IP
```

### Remote Claude CLI not working

```bash
# SSH to server and reinstall
ssh root@YOUR_SERVER_IP
su - claudedev
curl -fsSL https://claude.ai/install.sh | sh
```

### "Permission denied (docker)"

```bash
# Add claudedev to docker group
ssh root@YOUR_SERVER_IP 'usermod -aG docker claudedev'
```

See [QUICK_REPLICATION_CHECKLIST.md](QUICK_REPLICATION_CHECKLIST.md) for more solutions.

---

## 📝 License

MIT License - see [LICENSE](LICENSE) file

---

## 🔗 Resources

- **Claude Code:** https://claude.ai/code
- **Claude API:** https://claude.ai/settings
- **Docker Docs:** https://docs.docker.com
- **SSH Best Practices:** https://www.ssh.com/academy/ssh

---

## ⭐ Getting Started Checklist

After cloning:

- [ ] Run `./setup_wizard.sh` (or `.ps1` on Windows)
- [ ] Enter SSH server IP
- [ ] Enter Claude API token
- [ ] Wait for setup to complete (~10 min)
- [ ] Run `claude` to start working
- [ ] Test with: "Deploy nginx on port 8080"

**That's it! You're ready to orchestrate! 🚀**

---

**Current Status:** Production ready

**Version:** 1.0

**Last Updated:** 2025-10-30
