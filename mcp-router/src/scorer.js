// Plain task.includes(keyword) matches substrings anywhere, so a short/generic
// keyword can hit inside an unrelated word - verified reproducible: "repo" (a GitHub
// MCP keyword) matched inside "crash reports", so a Sentry-flavored task was getting
// recommended GitHub instead. Whole-word matching fixes that, but on its own it then
// misses plain plural/verb forms ("files" no longer matching keyword "file") - also
// verified reproducible. A light stemmer closes both: "reports" stems to "report"
// (≠ "repo", so the false match is gone) while "files" stems to "file" (= "file", so
// the real match survives).
function stem(word) {
  if (word.length <= 3) return word;
  if (word.endsWith("ies")) return word.slice(0, -3) + "y";
  if (/[sxz]es$/.test(word) || /(ch|sh)es$/.test(word)) return word.slice(0, -2);
  if (word.endsWith("ing") && word.length > 5) return word.slice(0, -3);
  if (word.endsWith("ed") && word.length > 4) return word.slice(0, -2);
  if (word.endsWith("s") && !word.endsWith("ss")) return word.slice(0, -1);
  return word;
}

function hasWordMatch(task, phrase) {
  const phraseWords = phrase.split(/\s+/).map(stem);
  const taskWords = task.split(/\W+/).filter(Boolean).map(stem);
  if (phraseWords.length === 1) {
    return taskWords.includes(phraseWords[0]);
  }
  // Multi-word phrases: match the stemmed words as a contiguous run, in order.
  for (let i = 0; i <= taskWords.length - phraseWords.length; i++) {
    if (phraseWords.every((w, j) => taskWords[i + j] === w)) return true;
  }
  return false;
}

export function scoreMcp(taskDescription, mcp) {
  const task = taskDescription.toLowerCase();
  let capabilityMatch = 0;
  let keywordMatch = 0;

  // Calculate capability match (50% weight)
  if (mcp.capabilities) {
    let matches = 0;
    for (const cap of mcp.capabilities) {
      if (hasWordMatch(task, cap.toLowerCase().replace(/_/g, " "))) {
        matches++;
      }
    }
    capabilityMatch = mcp.capabilities.length > 0 ? (matches / mcp.capabilities.length) * 50 : 0;
    // Baseline boost for a loose match, but scaled by how many actually matched -
    // a flat floor here made 1-match and 3-match candidates score identically,
    // which is how two MCPs that each matched a different number of real keywords
    // still tied (verified reproducible: "figma" AND "design" both matching Figma's
    // keyword list scored the same as filesystem's single "file" match).
    if (matches > 0) capabilityMatch = Math.max(capabilityMatch, Math.min(25 + (matches - 1) * 5, 50));
  }

  // Calculate keyword match (30% weight)
  if (mcp.scoringRules && mcp.scoringRules.keywords) {
    let matches = 0;
    for (const kw of mcp.scoringRules.keywords) {
      if (hasWordMatch(task, kw.toLowerCase())) {
        matches++;
      }
    }
    keywordMatch = mcp.scoringRules.keywords.length > 0 ? (matches / mcp.scoringRules.keywords.length) * 30 : 0;
    if (matches > 0) keywordMatch = Math.max(keywordMatch, Math.min(15 + (matches - 1) * 5, 30));
  }

  return capabilityMatch + keywordMatch;
}
