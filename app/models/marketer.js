import Model, { belongsTo, hasMany, attr } from '@ember-data/model';
import { task } from 'ember-concurrency';
import ENV from 'aittendee/config/environment';
import calculatChatCost from 'aittendee/utilities/calculate-chat-cost';

function systemMessageContent({ audience }) {
  return `
You are a marketing assistant that is creating a pull quote for the following audience:

"""
${audience}
"""

The pull quote must come from the provided content and be no more than 1 sentence long.
Edit pull quotes to remove fix grammatical issues, remove filler words, and maximize the impact.
You will score all pull requests on a scale of 0 - 100 where 0 is not interesting and 100 is very interesting.
Only really interesting pull quotes should be giving a score of greater than 70.
  `.trim();
}

function userMessageContent(chapter) {
  return `
Here's the full content from which you can pull quotes:

"""
${chapter.transcript}
"""
  `.trim();
}

export default class MarketerModel extends Model {
  @belongsTo('recording', { async: false })
  recording;

  @hasMany('marketer-pull-quote', { async: false })
  pullQuotes;

  @attr('number', { defaultValue: 0 })
  cost;

  @task
  *createPullQuoteTask(chapter) {
    const messages = [];

    const systemMessage = {
      role: 'system',
      content: systemMessageContent({ audience: this.recording.audience }),
    };

    messages.push(systemMessage);

    const userMessage = {
      role: 'user',
      content: userMessageContent(chapter),
    };

    messages.push(userMessage);

    const functions = [];

    const pullQuotesFunction = {
      name: 'pullQuotes',
      description: 'A list of pull quotes.',
      parameters: {
        type: 'object',
        properties: {
          quotes: {
            type: 'array',
            items: {
              type: 'object',
              properties: {
                text: {
                  type: 'string',
                  description: `
The text of the pull quote.
It must be no more than 1 sentence long.
Edit pull quotes to remove fix grammatical issues, remove filler words, and maximize the impact.
                  `.trim(),
                },
                score: {
                  type: 'integer',
                  description:
                    'The score of the pull quote. 0 is not interesting. 100 is extremely interesting.',
                },
              },
            },
          },
        },
        required: ['quotes'],
      },
    };

    functions.push(pullQuotesFunction);

    const data = {
      model: 'gpt-4-0613',
      messages,
      functions,
      function_call: {
        name: 'pullQuotes',
      },
    };

    let tries = 3;
    while (tries > 0) {
      try {
        let response = yield fetch(
          'https://api.openai.com/v1/chat/completions',
          {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              Authorization: `Bearer ${ENV.OPENAI_API_KEY}`,
            },
            body: JSON.stringify(data),
          }
        );

        if (!response.ok) {
          throw new Error(
            `HTTP Error Response: ${response.status} ${response.statusText}`
          );
        } else {
          let json = yield response.json();
          this.cost += calculatChatCost(json);
          const functionArguments = JSON.parse(
            json['choices'][0]['message']['function_call']['arguments']
          );
          const quotes = functionArguments['quotes'];
          for (let quote of quotes) {
            if (quote.score >= 50) {
              this.store.createRecord('marketer-pull-quote', {
                marketer: this,
                quote: quote.text,
                score: quote.score,
              });
            }
          }
          break;
        }
      } catch (e) {
        tries--;
      }
    }
  }
}
