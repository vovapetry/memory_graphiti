#!/bin/bash

echo "Configuring Git..."

# Only configure if environment variables are set
if [ -n "$GITHUB_USER" ]; then
    git config --global user.name "$GITHUB_USER"
    echo "  ✓ Set user.name: $GITHUB_USER"
fi

if [ -n "$GITHUB_EMAIL" ]; then
    git config --global user.email "$GITHUB_EMAIL"
    echo "  ✓ Set user.email: $GITHUB_EMAIL"
fi

# Set default configurations
git config --global init.defaultBranch main
git config --global pull.rebase false

echo "  ✓ Git configured"
