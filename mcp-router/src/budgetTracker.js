import fs from "fs/promises";

export async function checkBudget(modelName, returnFull = false) {
  try {
    const trackerPath = process.env.BUDGET_TRACKER || process.env.USERPROFILE + "\\.config\\magnus\\budget-tracker.json";
    const data = await fs.readFile(trackerPath, "utf-8");
    const tracker = JSON.parse(data);

    const modelKey = modelName.toLowerCase();
    if (!tracker[modelKey]) {
      return returnFull ? { spent: 0, monthlyLimit: 0, percentage: 0 } : 100;
    }

    const { spent, monthlyLimit } = tracker[modelKey];
    if (monthlyLimit <= 0) return returnFull ? { spent, monthlyLimit, percentage: 100 } : 0;

    const percentage = (spent / monthlyLimit) * 100;
    
    if (returnFull) {
      return { spent, monthlyLimit, percentage };
    }

    // Return a score based on remaining budget
    // 100 score if 0% spent, 0 score if 100% spent
    return Math.max(0, 100 - percentage);
  } catch (error) {
    console.error("Budget tracker error:", error);
    return returnFull ? { spent: 0, monthlyLimit: 0, percentage: 0 } : 50;
  }
}
