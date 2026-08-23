import fs from "fs/promises";
import { scoreMcp } from "./scorer.js";
import { analyzeCost } from "./costOptimizer.js";

export async function recommendMcp(taskDescription) {
  try {
    const configPath = process.env.MCP_ROUTER_CONFIG || process.env.USERPROFILE + "\\.config\\magnus\\mcp-manifest.json";
    const data = await fs.readFile(configPath, "utf-8");
    const manifest = JSON.parse(data);

    let bestScore = -1;
    let bestMcp = null;
    let bestCapabilityScore = 0;
    let scores = [];

    for (const mcp of manifest.mcpServers) {
      const capabilityScore = scoreMcp(taskDescription, mcp);
      const costEfficiency = analyzeCost(mcp);

      // Score = (Capability Match × 50%) + (Keyword Match × 30%) + (Cost Efficiency × 20%)
      // capabilityScore already returns Capability Match and Keyword Match combined out of 80

      const totalScore = capabilityScore + (costEfficiency * 0.2);
      // costProfile is optional - not every MCP has a measured token/model estimate,
      // and a missing one should just fall back to the neutral default cost score
      // analyzeCost() already returns, not crash the whole recommendation.
      scores.push({ id: mcp.id, name: mcp.name, score: totalScore, preferredModel: mcp.costProfile?.preferredModel });

      if (totalScore > bestScore) {
        bestScore = totalScore;
        bestMcp = mcp;
        bestCapabilityScore = capabilityScore;
      }
    }

    if (!bestMcp) {
      return "No suitable MCP found for the given task.";
    }

    // If nothing actually matched a capability or keyword, the winner was chosen
    // purely by the cost-efficiency tiebreaker (max possible: 100 x 20% = 20) - not
    // because it's actually relevant. Verified reproducible: an unrelated task like
    // "what's the weather today" was confidently getting "Recommend using PostgreSQL
    // MCP" every time, just because Postgres has the cheapest cost estimate of the
    // MCPs that have one. Say so plainly instead of asserting a match that isn't there.
    if (bestCapabilityScore === 0) {
      return `No MCP clearly matches this task (nothing matched on capability or keyword). Closest weak guess: **${bestMcp.name}**, but treat that as a low-confidence tiebreak, not a real recommendation.\n`;
    }

    let response = `✅ Recommend using **${bestMcp.name}** for this task.\n`;
    response += `Reason: ${bestMcp.description}\n`;
    if (bestMcp.costProfile) {
      response += `Preferred Model: ${bestMcp.costProfile.preferredModel} (${bestMcp.costProfile.reasoning})\n`;
    }

    return response;
  } catch (error) {
    return `Error recommending MCP: ${error.message}`;
  }
}
