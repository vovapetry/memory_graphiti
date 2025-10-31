# Container Usage Guide

## Quick Start

### 1. Prerequisites
- Docker and Docker Compose installed
- GitHub account with Personal Access Token (PAT)
- (Optional) Anthropic API key for Claude CLI

### 2. Clone and Configure

```bash
# Clone the repository
git clone https://github.com/vovapetry/memory_graphiti.git
cd memory_graphiti

# Create environment configuration
cp .env.template .env

# Edit .env with your credentials
nano .env  # or use your preferred editor
```

### 3. Build or Pull the Container

**Option A: Pull from GitHub Container Registry (Recommended)**
```bash
docker pull ghcr.io/vovapetry/memory-dev-env:latest
```

**Option B: Build Locally**
```bash
docker compose build
```

### 4. Start the Development Environment

```bash
# Start the container
docker compose up -d

# Enter the container
docker exec -it memory-dev-env bash
```

## Container Features

### Pre-installed Tools
- **Git** 2.34.1 - Version control
- **Docker CLI** - Docker commands (requires host socket mount)
- **Docker Compose** - Container orchestration
- **GitHub CLI** (gh) - GitHub operations from CLI
- **Claude CLI** 2.0.29 - AI coding assistant
- **Python** 3.10+ with pip
- **Node.js** 20.x with npm
- **System utilities**: curl, wget, vim, nano, tmux, htop, jq

### Directory Structure Inside Container

```
/home/claudedev/
├── .claude/           # Claude CLI configuration
├── .config/gh/        # GitHub CLI configuration
├── scripts/           # Setup scripts
│   ├── entrypoint.sh
│   ├── setup-git.sh
│   └── setup-claude.sh
└── workspace/         # Your project files (mounted from host)
```

## Common Workflows

### Working with Git

```bash
# Inside container
cd ~/workspace

# Git is already configured with your credentials
git clone https://github.com/yourusername/your-repo.git
cd your-repo

# Make changes and commit
git add .
git commit -m "Your commit message"
git push
```

### Using GitHub CLI

```bash
# Authenticate (if token not set via env)
echo $GITHUB_TOKEN | gh auth login --with-token

# Check authentication
gh auth status

# Create a new repository
gh repo create my-new-repo --public

# Create a pull request
gh pr create --title "My PR" --body "Description"

# List issues
gh issue list
```

### Using Claude CLI

```bash
# Check Claude CLI status
claude --version

# Start interactive session
claude

# Run Claude with a specific prompt
claude -p "Explain this code" < my-file.py
```

### Docker-in-Docker

The container has access to the host Docker socket, so you can run Docker commands:

```bash
# Inside container
docker ps
docker images
docker compose up -d

# Build and run containers from your project
cd ~/workspace/my-project
docker build -t my-image .
docker run my-image
```

## Environment Variables Reference

### Required Variables
- `GITHUB_USER` - Your GitHub username
- `GITHUB_EMAIL` - Your GitHub email
- `GITHUB_TOKEN` - GitHub Personal Access Token

### Optional Variables
- `ANTHROPIC_API_KEY` - Anthropic API key for Claude CLI
- `CLAUDE_CONFIG` - Custom Claude configuration (JSON)
- `USER_UID` - User ID for claudedev user (default: 1000)
- `USER_GID` - Group ID for claudedev user (default: 1000)
- `TZ` - Timezone (default: UTC)

## Volume Mounts

### Default Mounts
1. **Docker socket**: `/var/run/docker.sock` - Enables Docker-in-Docker
2. **Workspace**: `./workspace` → `/home/claudedev/workspace` - Your project files
3. **Home directory**: `dev-home` volume → `/home/claudedev` - Persistent configs
4. **SSH keys** (optional): `~/.ssh` → `/home/claudedev/.ssh` - For Git operations

### Adding Custom Mounts

Edit `docker-compose.yml`:
```yaml
volumes:
  - ./my-local-folder:/home/claudedev/my-folder
  - /host/path:/container/path
```

## Port Mappings

Default exposed ports:
- `8080` - Application port
- `8081` - Service port
- `8082` - API port
- `3000` - Frontend/Dashboard port
- `6379` - Redis/FalkorDB port

Customize in `docker-compose.yml` as needed.

## Troubleshooting

### Git Configuration Not Working
```bash
# Inside container, manually set:
git config --global user.name "Your Name"
git config --global user.email "your@email.com"
```

### GitHub CLI Not Authenticated
```bash
# Re-authenticate
echo $GITHUB_TOKEN | gh auth login --with-token

# Or manually
gh auth login
```

### Docker Commands Not Working
Ensure Docker socket is mounted:
```bash
# Check if socket exists
ls -la /var/run/docker.sock

# Test Docker access
docker version
```

### Permission Issues
If you encounter permission issues, rebuild with matching UID/GID:
```bash
# Add to .env
USER_UID=$(id -u)
USER_GID=$(id -g)

# Rebuild
docker compose build --no-cache
```

## Advanced Usage

### Running as Different User
```bash
docker compose run --user root dev-env bash
```

### Executing One-off Commands
```bash
docker compose run --rm dev-env git --version
docker compose run --rm dev-env python3 my-script.py
```

### Copying Files In/Out
```bash
# Copy file into container
docker cp ./local-file.txt memory-dev-env:/home/claudedev/

# Copy file from container
docker cp memory-dev-env:/home/claudedev/file.txt ./
```

### Container Maintenance

```bash
# View logs
docker compose logs -f

# Restart container
docker compose restart

# Stop container
docker compose down

# Remove everything including volumes
docker compose down -v

# Update to latest image
docker compose pull
docker compose up -d
```

## Security Best Practices

1. **Never commit `.env`** - It's in `.gitignore`, keep it that way
2. **Use read-only mounts** for sensitive data (`:ro` flag)
3. **Rotate tokens regularly** - Update GitHub and Anthropic tokens
4. **Limit Docker socket** access if possible (security trade-off)
5. **Review mounted volumes** - Only mount what's necessary

## Next Steps

- [Main README](./README.md) - Project overview
- [GitHub Workflow Implementation](./GITHUB_WORKFLOW_IMPLEMENTATION.md) - CI/CD details
- [Replication Guide](./REPLICATION_GUIDE.md) - Setting up on new servers

## Support

For issues or questions:
- Open an issue on GitHub
- Check existing documentation
- Review Docker and Docker Compose logs
