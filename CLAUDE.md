# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a **multi-agent orchestration system** for managing and deploying services on a remote Hetzner server (188.245.38.217) using Claude Code CLI. The system coordinates three specialized subagents (plan-agent, task-developer, tester-agent) to analyze, implement, and test tasks through an iterative workflow.

**Core Architecture:** Local Windows 11 orchestrator → Remote Ubuntu server via SSH → Remote Claude Code CLI execution → Multi-agent feedback loop

## Multi-Agent Workflow (MANDATORY)

When the user requests work involving the remote server (fixes, deployments, investigations), you MUST follow this workflow:

### Workflow Pattern

```
1. plan-agent → Analyze task, estimate tokens, create execution plan
2. TodoWrite → Initialize iteration tracking (max 10 iterations)
3. task-developer → SSH to remote Claude CLI, execute plan
4. tester-agent → Test implementation with appropriate method
5. Repeat steps 3-4 until PASS or limits reached
6. If limits hit (10 iterations / 140K tokens used) → Create HANDOFF document
```

### Agent Roles

- **plan-agent** (`.claude/agents/plan-agent.md`): Task analysis, realistic token estimation using 5-factor model, auto-splits tasks >150K tokens into subtasks
- **task-developer** (`.claude/agents/task-developer.md`): Connects to remote Claude Code CLI via SSH, delegates work, parses structured reports
- **tester-agent** (`.claude/agents/tester-agent.md`): Executes tests using browser (Playwright), API (curl), CLI (docker/ssh), logs, or databases

### Iteration Tracking

Use `TodoWrite` to track iterations:
- Maximum 10 iterations per task
- Context budget: 200K tokens total, exit at 70% (140K tokens)
- Each iteration consumes ~20K tokens for agent reports
- Track: STATUS (PASS/FAIL/PARTIAL), test results, next steps

## Remote Claude Code CLI

### Connection Pattern (Verified)

```bash
ssh root@188.245.38.217 'sudo -u claudedev bash -c "cd /home/claudedev/PROJECT && claude -p \"PROMPT\" --dangerously-skip-permissions --max-turns 30 --timeout 600000"'
```

**Critical requirements:**
- User: `claudedev` (required for `--dangerously-skip-permissions`)
- Working directory: Must cd to project directory first
- Quote escaping: Inner quotes must be `\"`
- Credentials: `/home/claudedev/.claude/.credentials.json` (600 perms)

**Verified capabilities** (36 tests, 97% success rate):
- File operations: Read, Write, Edit (supports 5000+ lines)
- Search: Glob patterns, Grep regex (<3s response time)
- Bash: Commands, chaining, Docker integration
- 16 tools available, <3s average response time

**Limitations:**
- Working directory resets between Bash calls (use absolute paths or `&&`)
- Output truncated at 30K characters
- No TTY support (no interactive commands)
- Edit requires exact string match (Read file first)
- Write requires Read for existing files

### Remote Server Details

- **IP:** 188.245.38.217 (Hetzner)
- **OS:** Ubuntu (Docker-based)
- **Users:** root / claudedev (both password: pAdLqeRvkpJu)
- **SSH:** Passwordless key-based authentication configured
- **Docker:** All services run in containers

## Task Planning & Token Estimation

### plan-agent 5-Factor Estimation Model

```
TOTAL = (Context + Generation) × Complexity × Iteration × Learning_Factor
```

**Factor 1: Context Reading**
- Get line counts: `ssh root@188.245.38.217 'cd ~/MODULE && wc -l *.py *.yaml'`
- Conversion: Total Lines × 4 tokens/line

**Factor 2: Code Generation**
- Simple fix: 200-500 tokens
- Medium feature: 1,000-2,000 tokens
- Complex feature: 5,000-10,000 tokens
- Full module: 20,000-50,000 tokens

**Factor 3: Complexity Multipliers**
- Base: 1.0x
- Medium files (5-20): +0.3x
- Many files (20+): +0.5x
- New dependency: +0.2x per dependency
- Database changes: +0.3x
- Security/auth: +0.25x

**Factor 4: Iteration Buffer**
- Simple: 1.3x
- Medium: 1.8x
- Complex: 2.2x
- Major: 2.5x

**Factor 5: Learning Factor**
- Read historical predictions from `~/MODULE/.claude-predictions/history.json`
- Calculate average accuracy: `actual_tokens / predicted_tokens`
- Default: 1.1x if no history

### Auto-Split for Large Tasks

When estimated tokens > 150K:
1. **Phase 1:** Investigation & Setup (40-60K tokens)
2. **Phases 2-N:** Implementation phases (100-120K tokens each)
3. **Final Phase:** Integration & Testing (50-80K tokens)

Each subtask must be independently testable with clear entry/exit conditions.

## Project Registry System

Remote projects are registered at `~/.claude-projects/registry.jsonl` on the server:

```json
{"project":"clickhouse","path":"~/clickhouse","status":"active","services":["clickhouse-server"],"docs":"docs/clickhouse/README.md","added":"2025-10-24"}
{"project":"grafana","path":"~/grafana","status":"active","services":["grafana"],"docs":"docs/grafana/README.md","added":"2025-10-24"}
```

plan-agent reads this registry to determine:
- Target module location
- Whether work is remote (registered) or local (not registered)
- Project documentation paths

## Docker-First Architecture

All services use Docker Compose with standard structure:

```
~/project-name/
├── docker-compose.yml
├── .env
├── README.md
├── data/
└── logs/
```

**Standard compose pattern:**
```yaml
services:
  service-name:
    image: official/image:latest
    container_name: service-name
    ports:
      - "port:port"
    volumes:
      - ./data:/app/data
    restart: unless-stopped
```

## Testing Patterns

tester-agent uses the most appropriate method for each test:

### 1. Browser Testing (Playwright MCP)
```javascript
mcp__playwright__browser_navigate("http://188.245.38.217:3000")
mcp__playwright__browser_take_screenshot("test.png")
mcp__playwright__browser_console_messages({onlyErrors: true})
```

### 2. API Testing (curl)
```bash
curl -I http://188.245.38.217:3000/api/health
curl -X POST http://188.245.38.217:3000/api/login -H "Content-Type: application/json" -d '{"user":"admin","password":"admin"}'
```

### 3. CLI/Docker Testing
```bash
ssh root@188.245.38.217 'docker ps | grep grafana'
ssh root@188.245.38.217 'docker logs grafana --tail 50'
ssh root@188.245.38.217 'docker exec grafana grafana-cli plugins ls'
```

### 4. Database Testing
```bash
ssh root@188.245.38.217 'docker exec clickhouse-server clickhouse-client --query "SELECT 1"'
```

## Structured Report Formats

### task-developer Report
```
=== TASK DEVELOPER REPORT ===
STATUS: [PASS | PARTIAL | FAIL]
ITERATION: [N/10]
CURRENT STATE:
- [Component]: [Status]
ISSUES IDENTIFIED:
1. [Issue]: [Description]
   - Root cause: [Analysis]
FIXES APPLIED:
1. [Fix]: [What was done]
   - Files modified: [List]
TEST INSTRUCTIONS FOR TESTER:
1. [Test name]:
   - Action: [What to test]
   - Method: [curl/browser/docker exec]
   - Expected: [What should happen]
EXPECTED RESULTS:
- [Outcome]
NEXT STEPS IF TESTS FAIL:
- [Guidance]
=== END REPORT ===
```

### tester-agent Report
```
=== TESTER AGENT REPORT ===
ITERATION: [N/10]
STATUS: [PASS | FAIL | PARTIAL]
TEST RESULTS:
- [Test]: [PASS/FAIL] - [Details]
FAILURES:
1. [Test Name]:
   - Expected: [Specific expected]
   - Actual: [Specific actual]
   - Evidence: [Screenshot/output/log]
FEEDBACK FOR DEVELOPER:
What's working correctly:
- [Item]
What's still broken:
- [Issue]
Specific issues to address:
1. [Specific issue with details]
Suggested debugging steps:
- [Command or check]
=== END REPORT ===
```

## Exit Conditions & HANDOFF

Create HANDOFF document when:
- ✅ Tests pass → Report success, done
- ❌ 10 iterations reached
- ❌ 70% context used (140K tokens)
- ❌ Estimated remaining < 2 iterations

HANDOFF includes:
- Completed work summary
- Remaining tasks
- Current state
- Test results
- Next steps for continuation

## Key Implementation Patterns

### Resilience Patterns (from example deployment)
When implementing resilient systems, use these proven patterns:
1. **Circuit Breaker:** 3-state FSM (CLOSED/OPEN/HALF_OPEN)
2. **Retry Logic:** Exponential backoff (e.g., 1s, 2s, 4s)
3. **Rate Limiting:** Per-IP limits (e.g., 100 req/min)
4. **Connection Pooling:** Max concurrent connections
5. **Timeout Handling:** Consistent timeouts across layers
6. **Graceful Degradation:** Fallback responses
7. **Health Checks:** Deep checks with dependencies
8. **Auto-Recovery:** Watchdog processes

### File Operations on Remote
Always follow this sequence:
1. Read file first (to get exact content)
2. Use Edit with exact string match
3. Verify change with Read

### Async Operations
Chain commands that must run sequentially:
```bash
ssh root@188.245.38.217 'cd ~/project && command1 && command2 && command3'
```

## Important Rules

### ✅ DO
- Always use multi-agent workflow for remote tasks
- Track iterations with TodoWrite (max 10)
- Use appropriate testing method for each test
- Capture evidence (screenshots, logs, outputs)
- Provide specific, actionable feedback
- Read files before editing on remote
- Use absolute paths or && chaining for remote commands

### ❌ DON'T
- Never skip plan-agent for complex tasks (>15K tokens)
- Don't exceed 10 iterations without HANDOFF
- Don't force browser testing when CLI is better
- Don't attempt local fixes for remote issues
- Don't use interactive commands on remote CLI (no TTY)
- Don't skip structured report formats
- Don't commit credentials or sensitive data

## Helper Scripts

If these scripts exist in the project:
- `verify-claude-auth.sh`: Check remote Claude authentication
- `update-claude-credentials.sh`: Update OAuth tokens
- `sync-remote-instructions.sh`: Sync agent definitions to remote
- `manage-registry.sh`: Manage project registry (list/add/status)

## Performance Metrics

**Remote Claude CLI:**
- Average response time: <3s
- File operations: Supports 5000+ lines
- Search operations: <3s response time
- Success rate: 97% (36 verified tests)

**Workflow:**
- Average iterations to success: 2-4
- Context per iteration: ~20K tokens
- Maximum safe iterations: 7 (140K tokens / 20K per iteration)

## Security

- **SSH:** Key-based authentication, no passwords in code
- **OAuth:** 1-year tokens in `/home/claudedev/.claude/.credentials.json` (600 perms)
- **Docker:** All services isolated, no host installs
- **Credentials:** Never commit `.env` or credential files

---

**Last Updated:** 2025-10-30
**Architecture:** Multi-agent orchestration (plan → develop → test → iterate)
**Status:** Production ready (CLI tested, 97% success rate)
