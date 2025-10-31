#!/bin/bash

echo "Configuring Claude CLI..."

# Create Claude config directory if it doesn't exist
mkdir -p ~/.claude

# If Claude config is provided via environment variable, use it
if [ -n "$CLAUDE_CONFIG" ]; then
    echo "$CLAUDE_CONFIG" > ~/.claude.json
    echo "  ✓ Claude CLI config loaded from environment"
fi

# If API key is provided, configure it
if [ -n "$ANTHROPIC_API_KEY" ]; then
    # Create or update Claude config with API key
    if [ -f ~/.claude.json ]; then
        # Config exists, update it
        jq '.apiKey = env.ANTHROPIC_API_KEY' ~/.claude.json > ~/.claude.json.tmp && mv ~/.claude.json.tmp ~/.claude.json
    else
        # Create new config
        echo "{\"apiKey\": \"$ANTHROPIC_API_KEY\"}" > ~/.claude.json
    fi
    echo "  ✓ Claude API key configured"
fi

echo "  ✓ Claude CLI configured"
