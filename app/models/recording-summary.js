import Model, { belongsTo, attr } from '@ember-data/model';
import { task } from 'ember-concurrency';
import ENV from 'aittendee/config/environment';
import calculatChatCost from 'aittendee/utilities/calculate-chat-cost';

export default class RecordingSummaryModel extends Model {
  @attr('date')
  createdAt;

  @belongsTo('recording', { async: false })
  recording;

  @attr('string')
  summary;

  @attr('number', { defaultValue: 0 })
  cost;

  get audience() {
    return this.recording?.audience;
  }

  get summarizedChapters() {
    return this.recording?.chapters
      .filter((c) => c.summary)
      .sort((a, b) => a.number - b.number);
  }

  get chaptersSummary() {
    return this.summarizedChapters.map((c) => c.summary).join('\n');
  }

  @task
  *summarizeTask() {
    const messages = [];
    const systemMessage = {
      role: 'system',
      content: `You are an assistant that is creating a Axios-like "Smart Brevity"-style summary for the following audience:

${this.audience}`,
    };
    messages.push(systemMessage);

    const userMessage = {
      role: 'user',
      content: `Here's the full content:
${this.chaptersSummary}`,
    };
    messages.push(userMessage);

    const functions = [
      {
        name: 'summary',
        description:
          'Summarize the transcript in Axios-like "Smart Brevity" style.',
        parameters: {
          type: 'object',
          properties: {
            summary: {
              type: 'string',
              description: 'The summary of the transcript in Markdown.',
            },
          },
        },
      },
    ];

    const data = {
      model: 'gpt-4-0613',
      messages,
      functions,
      function_call: {
        name: 'summary',
      },
    };

    let tries = 3;
    while (tries > 0) {
      let response = yield fetch('https://api.openai.com/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${ENV.OPENAI_API_KEY}`,
        },
        body: JSON.stringify(data),
      });

      if (!response.ok) {
        throw new Error(
          `HTTP Error Response: ${response.status} ${response.statusText}`
        );
      } else {
        try {
          let json = yield response.json();
          this.cost += calculatChatCost(json);
          const functionArguments = JSON.parse(
            json['choices'][0]['message']['function_call']['arguments']
          );
          const summary = functionArguments['summary'];
          this.summary = summary;
          break;
        } catch (e) {
          console.error(e);
          tries--;
        }
      }
    }
  }
}
