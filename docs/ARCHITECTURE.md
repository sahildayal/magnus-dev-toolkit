# Architecture

Magnus Dev Toolkit consists of:
1. **Bootstrapper:** Installs from a 49-tool catalog via Winget and npm — 18 always-on core tools, 15 opt-in power tools (Postman, Terraform, Helm, k9s, DBeaver, MySQL, Ollama, etc.), and 16 language/container/cloud tools, all selected in the interactive wizard except the core set.
2. **MCPs:** Auto-configures 11 core MCPs (GitHub, PostgreSQL, Playwright, Figma, Sentry, Chrome DevTools, Filesystem, Memory, Git, Fetch, Docker), plus `mcp-router` itself as a 12th server. Git and Fetch pin the `mcp` SDK below 2.0 to work around missing upper bounds in their upstream metadata (see README).
3. **Validation (Phase 4b):** Every configured server is verified with the official MCP client SDK — a real stdio handshake plus a tool listing — so a server that merely starts but doesn't speak the protocol is reported as failed, not passed.
3. **mcp-router:** An intelligent MCP that recommends the best MCP for your tasks based on Capability, Keywords, and Cost efficiency.
