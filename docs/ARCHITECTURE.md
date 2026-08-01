# Architecture

Magnus Dev Toolkit consists of:
1. **Bootstrapper:** Installs from a 48-tool catalog via Winget and npm — 17 always-on core CLI tools, 15 opt-in power tools (Postman, Terraform, Helm, k9s, DBeaver, MySQL, Ollama, etc.), and 16 language/container/cloud tools, all selected in the interactive wizard except the core set.
2. **MCPs:** Auto-configures 10 core MCPs (GitHub, PostgreSQL, Playwright, Figma, Sentry, Puppeteer, Filesystem, Memory, Git, Docker), plus `mcp-router` itself as an 11th server. Fetch MCP is implemented but disabled by default (broken upstream dependency in `mcp-server-fetch` on PyPI).
3. **mcp-router:** An intelligent MCP that recommends the best MCP for your tasks based on Capability, Keywords, and Cost efficiency.
