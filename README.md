# Magnus Dev Toolkit 🚀

Magnus Dev Toolkit is a one-command developer bootstrap system designed for AI-native software engineers. It automates the setup of tools, environments, and Model Context Protocol (MCP) servers, integrating directly with Gemini CLI, Claude Code, and Codex.

---

## 🌟 Key Features

✅ **Zero Manual Setup** — Run one command, answer the interactive prompt once, and the rest is fully automated.  
✅ **Comprehensive Toolchain** — Installs 40+ developer tools via `winget` and `npm`, covering languages (Python, Node.js, C++), containers (Docker, K8s), and cloud CLIs.  
✅ **11 Pre-Configured MCPs** — Comes out-of-the-box with GitHub, PostgreSQL, Docker, Playwright, Figma, Sentry, Chrome, Git, Fetch, Filesystem, and Memory MCPs.  
✅ **Intelligent Routing (`mcp-router`)** — A custom meta-MCP that analyzes your task and recommends the best MCP based on capabilities, cost, and monthly budget tracking.  
✅ **Multi-CLI Compatible** — Symlinks a unified `mcp-config.json` to Gemini CLI, Claude, and Codex environments.

---

## 🏗️ Architecture

The system operates in 6 automated phases:

1. **Phase 1: Machine Detection** - Silently audits currently installed tools.
2. **Phase 2: Tool Installation** - Uses `winget` and `npm` to install missing packages selected by the user.
3. **Phase 3: Environment Config** - Sets up `git`, environment variables, PowerShell aliases, and VS Code extensions.
4. **Phase 4: MCP Setup** - Installs the 11 core MCP servers and configures the master `mcp-config.json`.
5. **Phase 5: mcp-router** - Installs the intelligent recommendation engine and cost tracker.
6. **Phase 6: Onboarding Report** - Generates a detailed completion summary.

---

## 🚀 Quick Start

To begin the interactive setup wizard, run the following in **PowerShell**:

```powershell
powershell -c "irm https://github.com/sahildayal/magnus-dev-toolkit/raw/main/scripts/install.ps1 | iex"
```

For a silent installation (using default configurations):
```powershell
.\scripts\install.ps1 -SkipInteractive
```

---

## 🧠 MCP Router Details

The custom `mcp-router` evaluates your tasks using the following algorithm:
`Score = (Capability Match × 40%) + (Keyword Match × 30%) + (Cost Efficiency × 20%) + (Budget Available × 10%)`

### Example Usage in CLI:
**You:** *"Analyze my GitHub repos for security issues"*  
**Router:** *"✅ Use GitHub MCP (capability match: 95%). Estimated cost is highly efficient on your $20 budget."*

---

## 📚 Documentation
For deeper dives, see the `docs/` folder:
- [Architecture](docs/ARCHITECTURE.md)
- [MCP Configuration](docs/MCP_CONFIGURATION.md)
- [Router Guide](docs/MCP_ROUTER_GUIDE.md)
- [Cost Tracking](docs/COST_TRACKING.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)

---

**Built for modern AI-assisted engineering workflows.**