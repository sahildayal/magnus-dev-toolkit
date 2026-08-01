// Real MCP server validator.
//
// Speaks the actual Model Context Protocol using the official client SDK: connects
// over stdio, performs the initialize handshake, and enumerates the server's tools.
//
// This replaces an earlier hand-rolled PowerShell handshake that never actually
// worked - it wrote a UTF-8 BOM into stdin, so the very first JSON-RPC message was
// malformed and no server ever parsed it. Every "PASS" came from a fallback
// "process exited cleanly" branch, which a completely broken server also satisfies.
// Using the real client means a PASS here means the server genuinely works.
//
// Usage:  node mcp-probe.mjs <path-to-spec.json>
//   where the file contains {"command": "...", "args": [...], "env": {...}}
// The spec is passed as a FILE rather than an inline argument on purpose: Windows
// PowerShell mangles embedded double quotes when passing strings to native commands.
// Emits exactly one line to stdout prefixed with __MAGNUS_PROBE__ followed by JSON.

import { readFileSync } from "fs";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";

const MARKER = "__MAGNUS_PROBE__";
const BOM = 0xfeff;
const TIMEOUT_MS = Number(process.env.MAGNUS_PROBE_TIMEOUT_MS ?? 60000);

function emit(result) {
  process.stdout.write(MARKER + JSON.stringify(result) + "\n");
}

let spec;
try {
  let rawSpec = readFileSync(process.argv[2], "utf-8");
  // Strip a leading BOM. Windows PowerShell's Out-File -Encoding UTF8 always writes
  // one and JSON.parse rejects it. (A stray BOM is exactly what silently broke the
  // previous validator, so guard against it explicitly rather than assume.)
  if (rawSpec.charCodeAt(0) === BOM) rawSpec = rawSpec.slice(1);
  spec = JSON.parse(rawSpec);
} catch (err) {
  emit({ ok: false, error: `could not read server spec: ${err?.message ?? err}` });
  process.exit(1);
}

if (!spec?.command) {
  emit({ ok: false, error: "server spec missing 'command'" });
  process.exit(1);
}

// Merge the server's own env over the current environment. Passing only the
// server's env would strip PATH/SystemRoot and break the spawn on Windows.
const env = { ...process.env, ...(spec.env ?? {}) };

const transport = new StdioClientTransport({
  command: spec.command,
  args: spec.args ?? [],
  env,
  stderr: "ignore",
});

const client = new Client(
  { name: "magnus-validator", version: "1.0.0" },
  { capabilities: {} },
);

const bail = setTimeout(() => {
  emit({ ok: false, timedOut: true, error: `no response within ${TIMEOUT_MS}ms` });
  process.exit(2);
}, TIMEOUT_MS);

try {
  await client.connect(transport);
  const server = client.getServerVersion();

  // listTools is optional in the protocol - a server with no tools is still valid,
  // so treat a failure here as "no tools" rather than a validation failure.
  let tools = [];
  try {
    tools = (await client.listTools()).tools.map((t) => t.name);
  } catch {
    tools = [];
  }

  clearTimeout(bail);
  emit({ ok: true, server, tools });
  try {
    await client.close();
  } catch {
    /* server may already be gone; the handshake already succeeded */
  }
  process.exit(0);
} catch (err) {
  clearTimeout(bail);
  emit({ ok: false, error: String(err?.message ?? err) });
  process.exit(1);
}
