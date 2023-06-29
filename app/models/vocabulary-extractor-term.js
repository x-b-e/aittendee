import Model, { belongsTo, attr } from '@ember-data/model';
import { task } from 'ember-concurrency';
import ENV from 'aittendee/config/environment';
import fetch from 'fetch';
import calculatChatCost from 'aittendee/utilities/calculate-chat-cost';

export default class VocabularyExtractorTermModel extends Model {
  @attr('date')
  createdAt;

  @belongsTo('vocabulary-extractor', { async: false })
  vocabularyExtractor;

  @belongsTo('recording-chunk', { async: false })
  recordingChunk;

  @attr('number')
  count;

  @attr('number', { defaultValue: 0 })
  cost;

  @attr('string')
  _term;

  set term(value) {
    this._term = value;
  }

  get term() {
    return this._term;
  }

  @attr('number')
  utilityPct;

  @attr('string')
  definition;

  @task
  *defineTask() {
    const messages = [];
    const systemMessage = {
      role: 'system',
      content: `You are an assistant that is defining vocabulary terms for the following audience:

${this.vocabularyExtractor.audience}

The definitions should be no longer than 2 sentences, and they should be written in a way that is understandable by the audience.`,
    };
    messages.push(systemMessage);

    const userMessage = {
      role: 'user',
      content: this.term,
    };

    messages.push(userMessage);

    const functions = [];

    const defineTerm = {
      name: 'defineTerm',
      description: 'Defines a vocabulary term for a given audience.',
      parameters: {
        type: 'object',
        properties: {
          definition: {
            type: 'string',
          },
        },
      },
    };
    functions.push(defineTerm);

    const data = {
      model: 'gpt-4-0613',
      messages,
      functions,
      function_call: {
        name: 'defineTerm',
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
          const definition = functionArguments['definition'];
          this.definition = definition;
          break;
        }
      } catch (e) {
        console.error(e);
        tries--;
      }
    }
  }
}
