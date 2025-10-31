# Memory Development Environment - Portable Docker Container

A fully-configured, portable development environment in a Docker container with all necessary tools for memory service development.

## 🚀 Features

- **Complete Development Stack**: Git, Docker, GitHub CLI, Claude CLI, Python, Node.js
- **One-Command Setup**: Clone, configure, and start developing in minutes
- **Portable**: Works on any machine with Docker (Linux, Mac, Windows)
- **Consistent**: Same environment everywhere - no "works on my machine" issues
- **Automated Builds**: GitHub Actions automatically builds and publishes to GitHub Container Registry
- **Multi-Architecture**: Supports both AMD64 and ARM64 (Apple Silicon)

## 📋 Quick Start

### Prerequisites
- Docker 20.10+ and Docker Compose 2.0+
- GitHub account with Personal Access Token (PAT)

### 1. Clone Repository
```bash
git clone https://github.com/vovapetry/memory_graphiti.git
cd memory_graphiti
```

### 2. Configure Environment
```bash
# Copy template
cp .env.template .env

# Edit with your credentials
nano .env  # Set GITHUB_USER, GITHUB_EMAIL, GITHUB_TOKEN
```

### 3. Start Container
```bash
# Pull pre-built image (recommended)
docker pull ghcr.io/vovapetry/memory-dev-env:latest

# Start the environment
docker compose up -d

# Enter the container
docker exec -it memory-dev-env bash
```

You're now in a fully-configured development environment!

## 🛠️ What's Included

### Development Tools
| Tool | Version | Purpose |
|------|---------|---------|
| Git | 2.34.1 | Version control |
| Docker CLI | Latest | Container management |
| Docker Compose | 2.40+ | Container orchestration |
| GitHub CLI (gh) | 2.82+ | GitHub operations |
| Claude CLI | 2.0.29 | AI coding assistant |
| Python | 3.10+ | Programming language |
| Node.js | 20.x | JavaScript runtime |
| npm | 10.x | Package manager |

### System Utilities
- curl, wget - Download tools
- vim, nano - Text editors
- tmux - Terminal multiplexer
- htop - Process monitor
- jq - JSON processor
- build-essential - C/C++ compiler

## 📁 Project Structure

```
memory_graphiti/
├── Dockerfile              # Container definition
├── docker-compose.yml      # Orchestration configuration
├── .env.template           # Environment variables template
├── scripts/                # Setup and utility scripts
│   ├── entrypoint.sh      # Container startup script
│   ├── setup-git.sh       # Git configuration
│   └── setup-claude.sh    # Claude CLI configuration
├── .github/
│   └── workflows/
│       └── docker-publish.yml  # Automated build workflow
└── docs/
    ├── CONTAINER_USAGE.md      # Detailed usage guide
    └── GITHUB_WORKFLOW_IMPLEMENTATION.md
```

## 🎯 Common Use Cases

### 1. Development on Remote Server
```bash
# On remote server (Hetzner, AWS, etc.)
git clone https://github.com/vovapetry/memory_graphiti.git
cd memory_graphiti
cp .env.template .env
# Edit .env
docker compose up -d
docker exec -it memory-dev-env bash
```

### 2. Local Development
```bash
# On your laptop
git clone https://github.com/vovapetry/memory_graphiti.git
cd memory_graphiti
cp .env.template .env
# Edit .env with your credentials
docker compose up -d
docker exec -it memory-dev-env bash
```

### 3. Team Collaboration
```bash
# Team member pulls the same environment
docker pull ghcr.io/vovapetry/memory-dev-env:latest
# Everyone has identical development setup
```

### 4. CI/CD Pipeline
```yaml
# Use in GitHub Actions
jobs:
  test:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/vovapetry/memory-dev-env:latest
    steps:
      - uses: actions/checkout@v4
      - run: ./run-tests.sh
```

## 🔧 Configuration

### Environment Variables

Create `.env` from `.env.template` and configure:

```bash
# GitHub Configuration
GITHUB_USER=your_username
GITHUB_EMAIL=your@email.com
GITHUB_TOKEN=ghp_your_token_here

# Claude/Anthropic
ANTHROPIC_API_KEY=sk-ant-your_key_here

# Container Configuration
USER_UID=1000  # Match your host UID
USER_GID=1000  # Match your host GID
TZ=UTC
```

### Volume Mounts

Customize `docker-compose.yml` to mount your project directories:

```yaml
volumes:
  - ./my-project:/home/claudedev/workspace/my-project
  - ~/.ssh:/home/claudedev/.ssh:ro
```

### Port Mappings

Exposed ports (customize as needed):
- `8080` - Application
- `8081` - Service
- `8082` - API
- `3000` - Frontend
- `6379` - Database

## 🚢 Distribution Methods

### Method 1: GitHub Container Registry (Recommended)
```bash
# Pull latest
docker pull ghcr.io/vovapetry/memory-dev-env:latest

# Pull specific version
docker pull ghcr.io/vovapetry/memory-dev-env:v1.0.0
```

### Method 2: Build from Source
```bash
# Clone and build
git clone https://github.com/vovapetry/memory_graphiti.git
cd memory_graphiti
docker compose build
```

### Method 3: Export/Import (Air-gapped)
```bash
# On machine with internet
docker pull ghcr.io/vovapetry/memory-dev-env:latest
docker save ghcr.io/vovapetry/memory-dev-env:latest | gzip > dev-env.tar.gz

# Transfer dev-env.tar.gz to air-gapped machine

# On air-gapped machine
docker load < dev-env.tar.gz
```

## 🔄 Updates

The container is automatically rebuilt on every push to main branch.

```bash
# Update to latest version
docker compose pull
docker compose up -d
```

## 🧪 Testing

```bash
# Test container build
docker compose build

# Test container startup
docker compose up -d
docker compose logs

# Verify tools inside container
docker exec memory-dev-env bash -c "
  git --version &&
  docker --version &&
  gh --version &&
  claude --version &&
  python3 --version &&
  node --version &&
  npm --version
"
```

## 🔒 Security

- **Never commit `.env`**: Contains sensitive credentials
- **Use read-only mounts**: For SSH keys and sensitive files
- **Rotate tokens regularly**: Update GitHub and Anthropic tokens
- **Docker socket access**: Required for Docker-in-Docker, but be aware of security implications
- **No-new-privileges**: Security option enabled in docker-compose.yml

## 📊 Benefits vs Traditional Setup

| Aspect | Traditional Setup | Container Setup |
|--------|------------------|-----------------|
| Setup Time | 1-2 hours | 5 minutes |
| Consistency | Varies by machine | 100% identical |
| Portability | Manual migration | Copy & run |
| Updates | Manual each tool | Single command |
| Team Onboarding | Hours/days | Minutes |
| Cleanup | Manual uninstall | Delete container |
| Isolation | Global installs | Containerized |

## 🐛 Troubleshooting

### Container won't start
```bash
# Check logs
docker compose logs

# Verify .env file exists
ls -la .env

# Rebuild from scratch
docker compose down -v
docker compose build --no-cache
docker compose up -d
```

### Git/GitHub not working
```bash
# Verify credentials
docker exec memory-dev-env bash -c "echo $GITHUB_USER"

# Manual configuration
docker exec -it memory-dev-env bash
git config --global user.name "Your Name"
git config --global user.email "your@email.com"
```

### Docker commands not working inside container
```bash
# Verify Docker socket mount
docker exec memory-dev-env ls -la /var/run/docker.sock

# Test Docker access
docker exec memory-dev-env docker ps
```

## 📚 Documentation

- **[Container Usage Guide](./CONTAINER_USAGE.md)** - Detailed usage instructions
- **[GitHub Workflow Implementation](./GITHUB_WORKFLOW_IMPLEMENTATION.md)** - CI/CD details
- **[Replication Guide](./REPLICATION_GUIDE.md)** - Server setup guide

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

This project is open source and available under the MIT License.

## 🙏 Acknowledgments

- Ubuntu for the base image
- Docker for containerization
- GitHub for container registry and CI/CD
- Anthropic for Claude CLI
- All contributors to the included tools

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/vovapetry/memory_graphiti/issues)
- **Discussions**: [GitHub Discussions](https://github.com/vovapetry/memory_graphiti/discussions)
- **Documentation**: [Project Wiki](https://github.com/vovapetry/memory_graphiti/wiki)

---

**Made with ❤️ for portable, reproducible development environments**
