# Magnus Dev Toolkit

A one-command developer bootstrap system for AI-native engineers. Automates tool installation, environment configuration, and MCP server setup across Gemini CLI, Cline, and Codex.

---

## Quick Start

```powershell
powershell -c "irm https://github.com/sahildayal/magnus-dev-toolkit/raw/main/scripts/install.ps1 | iex"
```

Silent install (uses an existing `state/user-config.json` instead of the interactive wizard):

```powershell
.\scripts\install.ps1 -SkipInteractive
```

The installer walks through 6 phases automatically: detect what you already have, install what's missing, configure your environment, set up MCP servers, validate them, and print a summary. See [Architecture](#architecture) below for details on each phase.

---

## Key Features

- **Zero manual setup** — answer a few prompts once, then everything runs automatically.
- **44 dev tools** — 15 always-on core CLI tools (Git, GitHub CLI, VS Code, ripgrep, fzf, bat, jq, lazygit, etc.), 13 opt-in power tools (Postman, Terraform, Helm, k9s, DBeaver, etc.), and 16 language/container/cloud tools selected in the wizard — installed via `winget` and `npm`.
- **9 pre-configured MCPs** — GitHub, PostgreSQL, Playwright, Figma, Sentry, Puppeteer, Filesystem, Memory, and Docker — plus `mcp-router` itself, auto-registered as a 10th server.
- **Intelligent routing (`mcp-router`)** — recommends the best MCP for a given task using capability, keyword, and cost scoring.
- **Multi-CLI compatible** — writes each CLI's config in its own native format and location.

---

## Architecture

```
magnus-setup
├── Phase 0  Interactive wizard (languages, MCPs, tokens)
├── Phase 1  Machine detection (audit existing tools)
├── Phase 2  Tool installation (winget + npm)
├── Phase 3  Environment config (git, aliases, VS Code, env vars)
├── Phase 4  MCP setup (npm install -g, correct CLI-specific configs)
├── Phase 4b MCP validation (stdio handshake test per server)
├── Phase 5  mcp-router install
└── Phase 6  Onboarding report
```

---

## MCP Configuration

Each CLI gets its config written in the correct format to the correct path:

| CLI | Config Path | Format |
|---|---|---|
| **Gemini CLI** | `~/.gemini/settings.json` | JSON with `type: "stdio"` |
| **Cline** | `~/.config/cline/cline_mcp_config.json` | JSON `mcpServers` |
| **Codex CLI** | `~/.codex/config.toml` | TOML `[mcp_servers.<name>]` |

> Sources: [Gemini CLI docs](https://github.com/google-gemini/gemini-cli), [Cline docs](https://github.com/cline/cline), [Codex CLI docs](https://github.com/openai/codex)

### MCP Package Registry

| MCP | npm Package | Token Required |
|---|---|---|
| GitHub | `@modelcontextprotocol/server-github` | GitHub PAT |
| PostgreSQL | `@modelcontextprotocol/server-postgres` | Connection string |
| Playwright | `@playwright/mcp` | No |
| Figma | `figma-mcp` | Figma API Key |
| Sentry | `@sentry/mcp-server` | Sentry Auth Token |
| Puppeteer | `@modelcontextprotocol/server-puppeteer` | No |
| Filesystem | `@modelcontextprotocol/server-filesystem` | No |
| Memory | `@modelcontextprotocol/server-memory` | No |
| Docker | `docker mcp gateway start` (Docker Desktop 4.59+) | No |

> Note: `git` and `fetch` MCPs are Python-only (`uvx`) and are not included in the npm-based installation.

---

## mcp-router Scoring

```
Score = (Capability Match × 50%) + (Keyword Match × 30%) + (Cost Efficiency × 20%)
```

---

## Testing

The CI runs a full end-to-end test on a **fresh `windows-latest` GitHub Actions runner** on every push:

[![E2E Install Test](https://github.com/sahildayal/magnus-dev-toolkit/actions/workflows/test-install.yml/badge.svg)](https://github.com/sahildayal/magnus-dev-toolkit/actions/workflows/test-install.yml)

The test does a **real install** of a representative subset on a fresh Windows runner (all 15 core tools, Python, kubectl, GitHub MCP — Docker Desktop is excluded since it needs virtualization hosted runners don't expose) and validates:

- Each phase script runs without errors
- The installed core tools are actually on `PATH` afterward
- `~/.gemini/settings.json` contains `mcpServers.github`
- `~/.config/cline/cline_mcp_config.json` is created
- `~/.codex/config.toml` contains TOML `[mcp_servers.github]` block
- MCP validation results are saved to `state/mcp-validation.json`
- `mcp-router`'s `recommend_mcp` returns a real, correctly-scored recommendation via an actual stdio call

---

## Documentation

| Doc | Description |
|---|---|
| [QUICK_START.md](docs/QUICK_START.md) | Get running in 5 minutes |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | System design overview |
| [MCP_CONFIGURATION.md](docs/MCP_CONFIGURATION.md) | Per-CLI config details |
| [MCP_ROUTER_GUIDE.md](docs/MCP_ROUTER_GUIDE.md) | How routing works |
| [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Common issues |
| [DEVELOPER_GUIDE.md](docs/DEVELOPER_GUIDE.md) | Contributing |

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---|---|---|
| MCP shows TIMEOUT in validation | Missing token | Re-run phase 4 and enter token when prompted |
| MCP shows FAIL | Wrong node path or bad package | Check `npm list -g` for package |
| Docker MCP not configured | Docker Desktop < 4.59 or MCP Toolkit not enabled | Update Docker Desktop |
| Codex doesn't see MCPs | Wrong path (Codex uses TOML not JSON) | Check `~/.codex/config.toml` |
| Gemini CLI doesn't see MCPs | Wrong path | Check `~/.gemini/settings.json` |

---

**Built for modern AI-assisted engineering workflows. Personal use.**
