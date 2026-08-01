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
- **49 dev tools** — 18 always-on core tools (Git, GitHub CLI, VS Code, Google Chrome, ripgrep, fzf, bat, jq, lazygit, uv, SQLite, etc.), 15 opt-in power tools (Postman, Terraform, Helm, k9s, DBeaver, MySQL, Ollama, etc.), and 16 language/container/cloud tools selected in the wizard — installed via `winget` and `npm`.
- **9 pre-configured MCPs** — GitHub, PostgreSQL, Playwright, Figma, Sentry, Chrome DevTools, Filesystem, Memory, and Docker — plus `mcp-router` itself, auto-registered as a 10th server. (Git and Fetch MCPs are implemented but disabled by default — see [MCP Package Registry](#mcp-package-registry).)
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

| MCP | Package / Command | Installer | Token Required |
|---|---|---|---|
| GitHub | `@modelcontextprotocol/server-github` | npm | GitHub PAT |
| PostgreSQL | `@modelcontextprotocol/server-postgres` | npm | Connection string |
| Playwright | `@playwright/mcp` | npm | No |
| Figma | `figma-mcp` | npm | Figma API Key |
| Sentry | `@sentry/mcp-server` | npm | Sentry Auth Token |
| Chrome DevTools | [`chrome-devtools-mcp`](https://github.com/ChromeDevTools/chrome-devtools-mcp) | `npx` | No |
| Filesystem | `@modelcontextprotocol/server-filesystem` | npm | No |
| Memory | `@modelcontextprotocol/server-memory` | npm | No |
| Git | `mcp-server-git` | `uvx` (Python) | **Disabled** |
| Fetch | `mcp-server-fetch` | `uvx` (Python) | **Disabled** |
| Docker | `docker mcp gateway start` (Docker Desktop 4.59+) | Docker CLI plugin | No |

> Chrome DevTools MCP is Google's official Chrome automation MCP - deep DevTools access (network inspection, performance traces, console, source-mapped stack traces), not just generic browser automation. Requires a real installed Google Chrome (added as a core tool). Runs via `npx.cmd chrome-devtools-mcp@latest --headless --isolated` per upstream's own recommendation (always latest version, no separate install step) - `npx.cmd` rather than bare `npx`, since Windows process-spawning APIs that bypass the shell can't resolve the bare `.cmd` shim.
>
> **Git and Fetch are both implemented but not auto-installed - both are currently broken upstream.** `mcp-server-git` and `mcp-server-fetch` on PyPI each have a dependency-version mismatch against the `mcp` SDK (`AttributeError: 'Server' object has no attribute 'list_tools'` for Git; `ImportError: cannot import name 'McpError'` for Fetch) that causes them to crash immediately on launch. Neither is fixable in this repo - both are kept in the registry (`scripts/phases/phase-4-mcp.ps1`) to re-enable with a one-line change once upstream publishes a fix.
>
> **Fetch is implemented but not auto-installed.** As of this writing, `mcp-server-fetch` on PyPI has a broken dependency - it imports `McpError` from the `mcp` SDK, which was renamed to `MCPError` in a newer SDK release that `mcp-server-fetch`'s own version constraints don't exclude. Running `uvx mcp-server-fetch` fails with an `ImportError` before the server even starts. This is an upstream bug, not something this toolkit can fix. To re-enable once upstream publishes a fix, add `"fetch"` to the always-included list in `scripts/phases/phase-4-mcp.ps1`.

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
