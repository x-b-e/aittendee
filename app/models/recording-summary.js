import Model, { belongsTo, attr } from '@ember-data/model';
import { task } from 'ember-concurrency';
import ENV from 'aittendee/config/environment';
import calculateChatCost from 'aittendee/utilities/calculate-chat-cost';
import Evented from '@ember/object/evented';

export default class RecordingSummaryModel extends Model {
  constructor() {
    super(...arguments);
    Evented.apply(this);
  }

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

"""
${this.audience}
"""

The summary should be written in Markdown.
`,
    };
    messages.push(systemMessage);

    const userMessage = {
      role: 'user',
      content: `Here's the full content:
${this.chaptersSummary}`,
    };
    messages.push(userMessage);

    const data = {
      model: 'gpt-4',
      messages,
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
        let json;
        try {
          json = yield response.json();
          this.cost += calculateChatCost(json);
          const summary = json['choices'][0]['message']['content'];
          this.summary = summary;
          this.trigger('summarized', this);
          break;
        } catch (e) {
          console.error(e);
          tries--;
        }
      }
    }
  }
}
