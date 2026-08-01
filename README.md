# Magnus Dev Toolkit 🚀

A one-command developer bootstrap system for AI-native engineers. Automates tool installation, environment configuration, and MCP server setup across Gemini CLI, Cline, and Codex.

---

## 🌟 Key Features

✅ **Zero Manual Setup** — Interactive prompt once, then fully automated.  
✅ **40+ Dev Tools** — Installed via `winget` and `npm` (Python, Node.js, Go, Rust, Docker, cloud CLIs).  
✅ **11 Pre-Configured MCPs** — GitHub, PostgreSQL, Playwright, Figma, Sentry, Puppeteer, Filesystem, Memory + mcp-router.  
✅ **Intelligent Routing (`mcp-router`)** — Recommends the best MCP per task using capability, cost, and budget scoring.  
✅ **Multi-CLI Compatible** — Writes correct config to each CLI in its own native format.

---

## 🏗️ Architecture

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

## 🚀 Quick Start

```powershell
powershell -c "irm https://github.com/sahildayal/magnus-dev-toolkit/raw/main/scripts/install.ps1 | iex"
```

Silent install (uses existing `state/user-config.json`):
```powershell
.\scripts\install.ps1 -SkipInteractive
```

---

## 🔌 MCP Configuration

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

## 🧠 mcp-router Scoring

```
Score = (Capability Match × 40%) + (Keyword Match × 30%) + (Cost Efficiency × 20%) + (Budget Available × 10%)
```

---

## 🧪 Testing

The CI runs a full end-to-end test on a **fresh `windows-latest` GitHub Actions runner** on every push:

[![E2E Install Test](https://github.com/sahildayal/magnus-dev-toolkit/actions/workflows/test-install.yml/badge.svg)](https://github.com/sahildayal/magnus-dev-toolkit/actions/workflows/test-install.yml)

The test validates:
- Each phase script runs without errors
- `~/.gemini/settings.json` contains `mcpServers.github`
- `~/.config/cline/cline_mcp_config.json` is created
- `~/.codex/config.toml` contains TOML `[mcp_servers.github]` block
- `budget-tracker.json` is initialized with `spent: 0`
- MCP validation results are saved to `state/mcp-validation.json`

---

## 📚 Documentation

| Doc | Description |
|---|---|
| [QUICK_START.md](docs/QUICK_START.md) | Get running in 5 minutes |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | System design overview |
| [MCP_CONFIGURATION.md](docs/MCP_CONFIGURATION.md) | Per-CLI config details |
| [MCP_ROUTER_GUIDE.md](docs/MCP_ROUTER_GUIDE.md) | How routing works |
| [COST_TRACKING.md](docs/COST_TRACKING.md) | Budget monitoring |
| [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Common issues |
| [DEVELOPER_GUIDE.md](docs/DEVELOPER_GUIDE.md) | Contributing |

---

## 🔧 Troubleshooting

| Symptom | Likely Cause | Fix |
|---|---|---|
| MCP shows TIMEOUT in validation | Missing token | Re-run phase 4 and enter token when prompted |
| MCP shows FAIL | Wrong node path or bad package | Check `npm list -g` for package |
| Docker MCP not configured | Docker Desktop < 4.59 or MCP Toolkit not enabled | Update Docker Desktop |
| Codex doesn't see MCPs | Wrong path (Codex uses TOML not JSON) | Check `~/.codex/config.toml` |
| Gemini CLI doesn't see MCPs | Wrong path | Check `~/.gemini/settings.json` |

---

**Built for modern AI-assisted engineering workflows. Personal use.**