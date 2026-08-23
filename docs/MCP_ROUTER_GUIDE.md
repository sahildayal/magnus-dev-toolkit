# MCP Router Guide

The mcp-router is an MCP server that acts as a meta-router. It's a simple keyword/capability
heuristic, not a model - useful as a starting suggestion, not a ground-truth answer.

## How it scores
`Score = (Capability Match × 50%) + (Keyword Match × 30%) + (Cost Efficiency × 20%)`

Capability and keyword matching is whole-word (with basic plural/verb-form stemming), scored
against `config/mcp-manifest.json`, which has an entry for every MCP Phase 4 can configure
(GitHub, PostgreSQL, Playwright, Chrome DevTools, Filesystem, Memory, Git, Fetch, Sentry, Figma,
Docker). Cost efficiency is a static heuristic based on `costProfile.estimatedTokensPer100Calls`
where present, or a neutral default score otherwise - not measured telemetry.

If nothing in the task matches any MCP's capabilities or keywords, `recommend_mcp` says so
explicitly instead of asserting a confident-sounding but arbitrary pick.

## How to use
Pass a detailed `task_description` to the `recommend_mcp` tool. It will return the recommended MCP along with its preferred model (when that MCP has a cost profile).
