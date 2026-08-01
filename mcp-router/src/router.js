import fs from "fs/promises";
import { scoreMcp } from "./scorer.js";
import { analyzeCost } from "./costOptimizer.js";
import { checkBudget } from "./budgetTracker.js";

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
      const budgetAvailable = await checkBudget(mcp.costProfile.preferredModel);
      
      // Score = (Capability Match × 40%) + (Keyword Match × 30%) + (Cost Efficiency × 20%) + (Budget Available × 10%)
      // Assuming capabilityScore returns both Capability Match and Keyword Match combined out of 70
      
      const totalScore = capabilityScore + (costEfficiency * 0.2) + (budgetAvailable * 0.1);
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
    response += `\nBudget Status for ${bestMcp.costProfile.preferredModel}: `;
    
    const budget = await checkBudget(bestMcp.costProfile.preferredModel, true);
    response += `${budget.spent} spent out of ${budget.monthlyLimit}.\n`;
    
    if (budget.percentage > 90) {
      response += `⚠️ WARNING: You are approaching your budget limit for ${bestMcp.costProfile.preferredModel}!\n`;
    }
    
    return response;
  } catch (error) {
    return `Error recommending MCP: ${error.message}`;
  }
}
