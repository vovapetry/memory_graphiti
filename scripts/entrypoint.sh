#!/bin/bash
set -e

echo "=== Development Environment Starting ==="

# Run setup scripts
/home/claudedev/scripts/setup-git.sh
/home/claudedev/scripts/setup-claude.sh

echo "=== Setup Complete ==="
echo ""
echo "Available tools:"
echo "  - Git: $(git --version)"
echo "  - Docker: $(docker --version 2>/dev/null || echo 'Docker not available (need host socket mount)')"
echo "  - GitHub CLI: $(gh --version | head -1)"
echo "  - Claude CLI: $(claude --version)"
echo "  - Node.js: $(node --version)"
echo "  - Python: $(python3 --version)"
echo ""
echo "Ready for development!"
echo ""

# Execute the command passed to the container
exec "$@"
