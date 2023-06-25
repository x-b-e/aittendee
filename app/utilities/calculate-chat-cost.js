const COST_PER_PROMPT_TOKEN = 0.03 / 1000;
const COST_PER_COMPLETION_TOKEN = 0.06 / 1000;

function calculateChatCost(responseJson) {
  const { usage } = responseJson;
  if (!usage) return 0;

  const { completion_tokens: completionTokens } = usage;
  const { prompt_tokens: promptTokens } = usage;

  if (!completionTokens || !promptTokens) return 0;

  const cost =
    completionTokens * COST_PER_COMPLETION_TOKEN +
    promptTokens * COST_PER_PROMPT_TOKEN;

  return cost;
}

export default calculateChatCost;
