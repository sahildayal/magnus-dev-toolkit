export function scoreMcp(taskDescription, mcp) {
  const task = taskDescription.toLowerCase();
  let capabilityMatch = 0;
  let keywordMatch = 0;

  // Calculate capability match (50% weight)
  if (mcp.capabilities) {
    let matches = 0;
    for (const cap of mcp.capabilities) {
      if (task.includes(cap.toLowerCase())) {
        matches++;
      }
    }
    capabilityMatch = mcp.capabilities.length > 0 ? (matches / mcp.capabilities.length) * 50 : 0;
    // Just to ensure some baseline if they just loosely match
    if (matches > 0 && capabilityMatch < 25) capabilityMatch = 25;
  }

  // Calculate keyword match (30% weight)
  if (mcp.scoringRules && mcp.scoringRules.keywords) {
    let matches = 0;
    for (const kw of mcp.scoringRules.keywords) {
      if (task.includes(kw.toLowerCase())) {
        matches++;
      }
    }
    keywordMatch = mcp.scoringRules.keywords.length > 0 ? (matches / mcp.scoringRules.keywords.length) * 30 : 0;
    if (matches > 0 && keywordMatch < 15) keywordMatch = 15;
  }

  return capabilityMatch + keywordMatch;
}
