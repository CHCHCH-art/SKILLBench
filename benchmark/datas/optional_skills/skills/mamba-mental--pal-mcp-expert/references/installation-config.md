# Installation & Configuration Guide

## Prerequisites

- Python 3.10 or newer
- Git
- uv (Python package installer) or equivalent runtime

## Quick Start Installation

### Method 1: Auto-Configuration Script (Recommended)

```bash
git clone https://github.com/BeehiveInnovations/pal-mcp-server.git
cd pal-mcp-server
./run-server.sh
```

**What it does:**
- Handles setup, dependencies, API key configuration
- Auto-configures Claude Desktop, Claude Code, Gemini CLI, Codex CLI, Qwen CLI
- Creates .env file from system environment
- Manages Python virtual environment

### Method 2: Direct MCP Configuration

**For Claude Desktop:**
Edit `~/.claude/settings.json`:

```json
{
  "mcpServers": {
    "pal": {
      "command": "sh",
      "args": [
        "-c",
        "for p in $(which uvx 2>/dev/null) $HOME/.local/bin/uvx /opt/homebrew/bin/uvx /usr/local/bin/uvx uvx; do [ -x \"$p\" ] && exec \"$p\" --from git+https://github.com/BeehiveInnovations/pal-mcp-server.git pal-mcp-server; done; echo 'uvx not found' >&2; exit 1"
      ],
      "env": {
        "PATH": "/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:~/.local/bin",
        "GEMINI_API_KEY": "your_gemini_api_key_here",
        "OPENAI_API_KEY": "your_openai_api_key_here",
        "DISABLED_TOOLS": "analyze,refactor,testgen,secaudit,docgen,tracer",
        "DEFAULT_MODEL": "auto"
      }
    }
  }
}
```

**For Claude Code:**
Create `.mcp.json` in project root:

```json
{
  "mcpServers": {
    "pal": {
      "command": "sh",
      "args": ["-c", "uvx --from git+https://github.com/BeehiveInnovations/pal-mcp-server.git pal-mcp-server"],
      "env": {
        "GEMINI_API_KEY": "your_key",
        "OPENAI_API_KEY": "your_key",
        "DEFAULT_MODEL": "auto"
      },
      "tool_timeout_sec": 1200
    }
  }
}
```

**For Cursor:**
Settings → MCP Servers → Add Server → Configure as above

**For VS Code (Claude Dev Extension):**
Command Palette → Claude: Configure MCP Servers → Add configuration

## API Key Configuration

### Required (At Least One)

**Important:** Use EITHER native APIs OR OpenRouter, not both.

### Option 1: Native APIs (Recommended)

```bash
# .env or MCP config
GEMINI_API_KEY=your_gemini_key  # From https://makersuite.google.com/app/apikey
OPENAI_API_KEY=your_openai_key  # From https://platform.openai.com/api-keys
XAI_API_KEY=your_xai_key        # For Grok models
```

### Option 2: OpenRouter (Unified Cloud Access)

```bash
OPENROUTER_API_KEY=your_openrouter_key
```

### Option 3: Azure OpenAI

```bash
AZURE_OPENAI_API_KEY=your_azure_key
AZURE_OPENAI_ENDPOINT=https://your-resource.openai.azure.com
AZURE_OPENAI_API_VERSION=2024-02-15-preview
```

### Option 4: DIAL Platform (Enterprise)

```bash
DIAL_API_KEY=your_dial_key
DIAL_API_HOST=https://dial.example.com
DIAL_API_VERSION=v1
```

### Option 5: Custom/Local Models

```bash
CUSTOM_API_URL=http://localhost:11434  # Ollama, vLLM, etc.
CUSTOM_API_KEY=optional_key
CUSTOM_MODEL_NAME=llama3.1
```

## Configuration Options

### Model Selection

**Auto Mode (Recommended):**
```bash
DEFAULT_MODEL=auto  # Intelligent model selection per task
```

**Fixed Model:**
```bash
DEFAULT_MODEL=gemini-pro  # Always use Gemini Pro
```

**Per-Request Override:**
User can override in any request:
```
"Use chat with gpt-5-pro to implement auth"
```

### Tool Management

**Default Configuration:**
```bash
DISABLED_TOOLS="analyze,refactor,testgen,secaudit,docgen,tracer"
```

**Enable All Tools:**
```bash
DISABLED_TOOLS=""
```

**Custom Selection:**
```bash
DISABLED_TOOLS="testgen,docgen"  # Only disable these
```

### Conversation Settings

```bash
CONVERSATION_TIMEOUT_HOURS=5   # Thread retention time
MAX_CONVERSATION_TURNS=20      # Exchanges per thread
```

### Model Restrictions

**Development Environment:**
```bash
GOOGLE_ALLOWED_MODELS=flash,pro,flash-8b
OPENAI_ALLOWED_MODELS=gpt-5.1-codex,gpt-5-pro,o3,o4
```

**Production (Cost Control):**
```bash
GOOGLE_ALLOWED_MODELS=flash
OPENAI_ALLOWED_MODELS=gpt-5.1-codex-mini,o4-mini
```

**High Performance:**
```bash
GOOGLE_ALLOWED_MODELS=pro
OPENAI_ALLOWED_MODELS=gpt-5-pro,o3
```

### Environment Override

**For Multi-Client Conflicts:**
```bash
FORCE_ENV_OVERRIDE=true  # .env takes precedence over system vars
```

Use when:
- Running multiple AI tools simultaneously
- Experiencing API key conflicts
- Tools using cached credentials

### Logging

```bash
LOG_LEVEL=DEBUG    # Development (detailed)
LOG_LEVEL=INFO     # Production (standard)
LOG_LEVEL=WARNING  # Errors only
LOG_LEVEL=ERROR    # Critical only
```

### Gemini Endpoint Override

```bash
GEMINI_BASE_URL=https://custom-endpoint.example.com
```

## Timeout Configuration

### Why 20 Minutes?

PAL tools run multi-step workflows that can take significant time:
- thinkdeep: 2-10 minutes
- consensus: 5-15 minutes
- codereview: 3-10 minutes
- analyze: 5-20 minutes

### Claude Code (Auto-Configured)

Setup script automatically sets:
```json
{
  "tool_timeout_sec": 1200
}
```

### Claude Desktop (Manual)

Add to config:
```json
{
  "timeout": 1200000  // milliseconds
}
```

### Other Clients

Consult client documentation for timeout settings.

## Verification

### Check Installation

```bash
# Claude Desktop
# Open Claude → Should see zen-pal-nas tools

# Claude Code
claude mcp list --scope project  # Should show "pal" connected

# Test command
"Use pal to list available models"
```

### Common Issues

**uvx not found:**
- Install uv: `curl -LsSf https://astral.sh/uv/install.sh | sh`
- Or use one-line command: `uvx --from git+https://... pal-mcp-server`

**API Key errors:**
- Verify key format and validity
- Check FORCE_ENV_OVERRIDE if using multiple clients
- Restart MCP client after config changes

**Timeout errors:**
- Increase tool_timeout_sec to 1200
- Check network connectivity
- Verify model availability

**Tool not triggering:**
- Check DISABLED_TOOLS configuration
- Verify tool name spelling
- Try explicit tool call: "Use pal chat with..."

## Docker Integration

For user "zen-pal-nas" running in Docker container "zen-mcp-stack" on Synology NAS (192.168.86.97):

### Container Configuration

```yaml
# docker-compose.yml or similar
services:
  zen-mcp-stack:
    # ... container config
    environment:
      - GEMINI_API_KEY=${GEMINI_API_KEY}
      - OPENAI_API_KEY=${OPENAI_API_KEY}
      - DEFAULT_MODEL=auto
      - DISABLED_TOOLS=analyze,refactor,testgen,secaudit,docgen,tracer
```

### Host Integration

Claude Desktop/Code on host connects to containerized PAL via network or volume mounts.

## Version Management

### Check Version

```bash
# In repository
cat config.py | grep VERSION
# Or use tool
"Use pal version to check server version"
```

### Update

```bash
cd pal-mcp-server
git pull
./run-server.sh  # Reinstalls with latest
```

### Current Version
v9.8.2 (as of December 2024)

## Security Notes

- Never commit API keys to git
- Use .env files (in .gitignore)
- Rotate keys periodically
- Use environment-specific restrictions in production
- Enable FORCE_ENV_OVERRIDE to prevent key leakage across clients

## Platform-Specific Notes

### macOS
- uvx typically in `/opt/homebrew/bin/uvx`
- Python from Homebrew recommended

### Linux
- uvx in `~/.local/bin/uvx`
- May need to add to PATH

### Windows
- Use WSL2 for best compatibility
- PowerShell configuration similar to bash
- Path separators: use forward slashes in configs
