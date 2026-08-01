# Architecture

Magnus Dev Toolkit consists of:
1. **Bootstrapper:** Installs from a 48-tool catalog via Winget and npm — 17 always-on core CLI tools, 15 opt-in power tools (Postman, Terraform, Helm, k9s, DBeaver, MySQL, Ollama, etc.), and 16 language/container/cloud tools, all selected in the interactive wizard except the core set.
2. **MCPs:** Auto-configures 11 core MCPs (GitHub, PostgreSQL, Playwright, Figma, Sentry, Puppeteer, Filesystem, Memory, Git, Fetch, Docker), plus `mcp-router` itself as a 12th server.
3. **mcp-router:** An intelligent MCP that recommends the best MCP for your tasks based on Capability, Keywords, and Cost efficiency.
