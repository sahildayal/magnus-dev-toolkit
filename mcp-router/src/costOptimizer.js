export function analyzeCost(mcp) {
  // Simple heuristic for cost efficiency
  // Less estimated tokens = more cost efficient
  if (!mcp.costProfile || !mcp.costProfile.estimatedTokensPer100Calls) {
    return 50; // default 50/100 score
  }

  const tokens = mcp.costProfile.estimatedTokensPer100Calls;
  
  if (tokens < 2000) return 100;
  if (tokens < 5000) return 80;
  if (tokens < 8000) return 60;
  if (tokens < 10000) return 40;
  return 20;
}
