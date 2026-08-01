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
    let scores = [];

    for (const mcp of manifest.mcpServers) {
      const capabilityScore = scoreMcp(taskDescription, mcp);
      const costEfficiency = analyzeCost(mcp);

      // Score = (Capability Match × 50%) + (Keyword Match × 30%) + (Cost Efficiency × 20%)
      // capabilityScore already returns Capability Match and Keyword Match combined out of 80

      const totalScore = capabilityScore + (costEfficiency * 0.2);
      scores.push({ id: mcp.id, name: mcp.name, score: totalScore, preferredModel: mcp.costProfile.preferredModel });

      if (totalScore > bestScore) {
        bestScore = totalScore;
        bestMcp = mcp;
      }
    }

    if (!bestMcp) {
      return "No suitable MCP found for the given task.";
    }

    let response = `✅ Recommend using **${bestMcp.name}** for this task.\n`;
    response += `Reason: ${bestMcp.description}\n`;
    response += `Preferred Model: ${bestMcp.costProfile.preferredModel} (${bestMcp.costProfile.reasoning})\n`;

    return response;
  } catch (error) {
    return `Error recommending MCP: ${error.message}`;
  }
}
