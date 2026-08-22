# Changelog

## Unreleased

Fixes from a fresh-machine production-readiness pass, before running this on an
actual new Windows 10 laptop, plus adding Claude Code as an installed tool.

**Added Claude Code CLI as a core tool** (`@anthropic-ai/claude-code` via npm). It's
core rather than opt-in, so it installs even for users who never selected Node.js as
a language - which meant it needed its own dependency handling:

- Phase 2 now bootstraps Node.js automatically (reusing the manifest's own Node.js
  entry, so it's installed through the same verified path and shown in the
  confirmation gate) whenever a selected tool needs npm and npm isn't already there.
- PATH is now refreshed immediately after each successful winget install inside
  Phase 2's loop, not just once at the top of the phase - otherwise Node.js landing
  mid-loop wouldn't be visible yet to Claude Code's npm install right after it in the
  same run.
- Tool count: 49 -> 50 (18 -> 19 core tools).

Scope note: this adds *installation* only. Claude Code's own MCP config
(`~/.claude.json`) is not written by Phase 4 - that file also holds auth/session
state, and merging into it safely is a separate piece of work, not requested here.

- **Phase 4 corrupted `~/.codex/config.toml` on every re-run.** It appended a fresh
  `[mcp_servers.*]` table for every configured server instead of overwriting, so
  re-running Phase 4 (e.g. to add a token or fix an MCP) wrote duplicate TOML tables
  for every server, all previous ones included. Same duplication bug already fixed
  for the PowerShell alias block, just missed here. Now overwrites, matching how Cline's
  config is already handled.
- **Phase 4's PyPI reachability check could fail silently on older Windows 10.**
  Windows PowerShell 5.1's `Invoke-WebRequest` doesn't enable TLS 1.2 by default on
  every Windows 10 / .NET Framework combination. Without it, the check that decides
  whether `mcp-server-git`/`mcp-server-fetch` are reachable comes back with a `$null`
  status instead of an exception, and both get silently skipped as "unreachable" even
  though the network is fine. `SecurityProtocol` is now forced to TLS 1.2 up front.
- **Phase 2 had no winget preflight check.** On a Windows 10 machine where winget/App
  Installer isn't present or is out of date, every single tool install would have
  failed one at a time with no indication of the actual cause. Now fails fast with a
  direct link to update it.
- **The final onboarding report referenced commands that don't exist**
  (`magnus-token-status`, `magnus-update`, `magnus-check-versions`, `magnus-reset`) -
  none of these were ever implemented as aliases or scripts. Removed; replaced with
  steps that reflect what the toolkit actually does. Also removed a fabricated
  "Codex is 10x cheaper than Claude" example number that no code path computes, and
  softened a few "OK X done" lines that were unconditionally true even when the
  underlying step (e.g. VS Code extensions) was actually skipped.
- **Documented a real coverage gap**: `mcp-router`'s manifest only has scoring entries
  for 3 of the 11 configured MCPs (GitHub, PostgreSQL, Playwright) - Figma, Sentry,
  Chrome, Filesystem, Memory, Git, Fetch, and Docker have no entry, so a task matching
  any of them gets no relevant recommendation. Added to Known limitations rather than
  papering over it with invented cost/capability numbers for services never measured.

## v1.1.1

Fixes for bugs found while auditing production readiness — several had already
fired on a real machine.

**The advertised one-liner install could never have worked.** `install.ps1` derived
its own location from `$MyInvocation.MyCommand.Definition`, which under
`irm ... | iex` returns the script *text* rather than a path. Every phase lookup
resolved to nonsense, so the primary documented entry point failed immediately. It
now uses `$PSScriptRoot` and, when running with no file on disk, bootstraps by
downloading the repo archive (not via `git`, which it is itself responsible for
installing). A `-ResolveOnly` switch plus a CI step now guard this path — nothing
tested it before, which is why it stayed broken.

**Phase 3 was destructive.** It wrote a shipped placeholder identity
(`bikash@example.com`) straight over the user's global git config, so every later
commit was authored to a fake address GitHub cannot attribute. It now only fills in
a genuinely missing identity, never overwrites an existing one, and refuses
placeholder values.

- `JAVA_HOME` / `PYTHON_HOME` were hardcoded to paths that frequently do not exist
  (`Python311` while the manifest installs 3.13) and were set even when the language
  was never installed. Both are now derived from where the tool actually resolves,
  and skipped when absent.
- Shell aliases were appended on every run, duplicating themselves. They now live in
  a replaceable marker block, so re-runs are idempotent.
- VS Code extension installs now report clearly when `code` is not on `PATH`.

**The `mcp<2` constraint is now self-healing.** Phase 4 tries the unconstrained
resolution first and verifies the server actually starts — really launching it,
since `--help` exits before the crashing code path is reached. The constraint applies
only when the latest genuinely fails, so the day upstream publishes a fixed release
it stops being used automatically, with no edit to this repo.

## v1.1.0

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
