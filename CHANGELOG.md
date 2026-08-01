# Changelog

## v1.0.0

Bootstrap system for AI-native dev environments: interactive setup wizard, 44-tool
catalog (15 always-on core CLI tools, 13 opt-in power tools, 16 language/container/cloud
tools), automatic MCP configuration across Gemini CLI, Cline, and Codex, and an
`mcp-router` recommendation engine.

- Phases 0-6: interactive wizard, machine detection, tool install, environment config,
  MCP setup, MCP stdio validation, onboarding report
- 8 MCP servers (GitHub, PostgreSQL, Playwright, Figma, Sentry, Puppeteer, Filesystem,
  Memory) plus Docker MCP Gateway, all package IDs verified live against the npm registry
- `mcp-router`: recommends the best MCP per task, scored as Capability (50%) + Keyword
  match (30%) + Cost efficiency (20%)
- All 43 winget package IDs verified live against `winget show`
- Real end-to-end CI on a fresh `windows-latest` GitHub Actions runner: installs the
  representative tool subset for real, verifies all three CLI configs are written
  correctly, and live-tests `mcp-router`'s recommendation via an actual stdio MCP call
- No fake budget/cost tracking - removed entirely rather than shipped as a stub
