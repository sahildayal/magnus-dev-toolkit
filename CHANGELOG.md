# Changelog

## Unreleased

Correctness pass. `v1.0.0` shipped with a validation phase that never actually
validated anything, which in turn hid several real failures.

**Phase 4b validation was not real.** It wrote a UTF-8 BOM into each server's stdin,
so the first JSON-RPC message was always malformed and no server ever parsed it.
Every "PASS" came from a fallback "process exited cleanly" branch, which a completely
broken server also satisfies. Replaced with `scripts/mcp-probe.mjs`, which speaks the
real protocol via the official `@modelcontextprotocol/sdk` client: connects, performs
the initialize handshake, and enumerates tools. CI now also asserts the expected
servers actually *passed*, since "zero failures" is also true when everything skips.

**MCPs added / fixed**

- Chrome DevTools MCP ([`chrome-devtools-mcp`](https://github.com/ChromeDevTools/chrome-devtools-mcp)),
  Google's official Chrome automation server, replacing the Puppeteer stand-in.
  Runs headless + isolated with telemetry opt-out. Google Chrome added as a core tool.
- Git and Fetch MCPs now install and work. Both upstream packages declare `mcp` with
  no upper bound, so resolvers picked up SDK 2.0.0 and crashed on breaking API changes;
  pinned to `mcp<2`. Upstream: modelcontextprotocol/servers#4580, #4560.

**Bugs fixed**

- Stale `PATH`: a process's in-memory `PATH` doesn't refresh when an earlier phase's
  installer writes to the registry, so phases 3/4/4b/5 couldn't see freshly installed
  tools. This was also silently breaking VS Code extension installs.
- `npm root -g` is now queried instead of assuming `%APPDATA%\npm`.
- `npx` resolved to an absolute path - a bare `npx.cmd` resolves relative to the
  caller's working directory and breaks when that directory contains a `package.json`.
- `curl`/`wget` false "already installed" hits: PowerShell 5.1's built-in aliases were
  matching, so the real executables never got installed. Detection now requires a real
  `Application` command.
- `phase-1-detect.ps1` crashed on commands with no version info.
- Phase 4 no longer pre-registers `mcp-router` at a path that doesn't exist until
  Phase 5, which guaranteed a false validation failure every run.
- Phase 4 fails fast with a clear message when Node.js is missing, instead of erroring
  deep inside the install loop.

**Tools:** catalog grown to 49 - added `uv`, SQLite, Google Chrome (core) and MySQL,
Ollama (opt-in).

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
