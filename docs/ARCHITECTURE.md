# Architecture

Magnus Dev Toolkit consists of:
1. **Bootstrapper:** Installs from a 49-tool catalog via Winget and npm — 18 always-on core tools, 15 opt-in power tools (Postman, Terraform, Helm, k9s, DBeaver, MySQL, Ollama, etc.), and 16 language/container/cloud tools, all selected in the interactive wizard except the core set.
2. **MCPs:** Auto-configures 9 core MCPs (GitHub, PostgreSQL, Playwright, Figma, Sentry, Chrome DevTools, Filesystem, Memory, Docker), plus `mcp-router` itself as a 10th server. Git and Fetch MCPs are implemented but disabled by default (both currently broken upstream - see README).
3. **mcp-router:** An intelligent MCP that recommends the best MCP for your tasks based on Capability, Keywords, and Cost efficiency.
