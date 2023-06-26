import Model, { belongsTo, attr, hasMany } from '@ember-data/model';
import { task } from 'ember-concurrency';
import fetch from 'fetch';
import ENV from 'aittendee/config/environment';
import Fuse from 'fuse.js/dist/fuse.basic.esm.min.js';
import calculatChatCost from 'aittendee/utilities/calculate-chat-cost';

export default class VocabularyExtractorModel extends Model {
  @belongsTo('recording', { async: false })
  recording;

  @hasMany('vocabulary-extractor-term', { async: false })
  terms;

  @attr('number', { defaultValue: 0 })
  cost;

  get audience() {
    return this.recording?.audience;
  }

  @task
  *extractTermsTask(chunk) {
    const messages = [];
    const systemMessage = {
      role: 'system',
      content: `You are an assistant that is extracting key unknown vocabulary terms from a transcript for the following audience:

${this.audience}

It is fine if you don't extract any terms if you think the transcript is understandable by the given audience. Only extract terms that you know the meaning of confidently.`,
    };
    messages.push(systemMessage);
    const userMessage = {
      role: 'user',
      content: chunk.transcript,
    };
    messages.push(userMessage);

    const functions = [];
    const extractTerms = {
      name: 'extractTerms',
      description:
        'Extracts key unkonwn vocabulary terms from a transcript that are probably not understood by the given audience. Do not include terms that are probably understood by the given audience. The term only be capitalized if it is a proper noun. Do not include any punctuation.',
      parameters: {
        type: 'object',
        properties: {
          terms: {
            type: 'array',
            items: {
              type: 'object',
              properties: {
                term: {
                  type: 'string',
                },
                newnessPct: {
                  type: 'integer',
                  description:
                    'The probability % (0 to 100) that the term is not known by the given audience.',
                },
                valuePct: {
                  type: 'integer',
                  description:
                    'The probability % (0 to 100) that the term is worth knowing by the audience.',
                },
                definablePct: {
                  type: 'integer',
                  description:
                    'The probability % (0 to 100) that you are able to define the word accurately.',
                },
              },
              required: ['term', 'newnessPct', 'valuePct', 'knownPct'],
            },
          },
        },
        required: ['terms'],
      },
    };
    functions.push(extractTerms);

    const data = {
      model: 'gpt-4-0613',
      messages,
      functions,
      function_call: {
        name: 'extractTerms',
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
          const terms = functionArguments['terms'];
          console.log({ terms });
          const highValueTerms = terms.filter((t) => {
            return (
              t.newnessPct >= 70 && t.definablePct >= 70 && t.valuePct >= 70
            );
          });

          const previousTerms = this.terms.map((t) => t.term);
          const fuse = new Fuse(previousTerms, {
            keys: ['term'],
            isCaseSensitive: false,
            includeMatches: true,
            threshold: 0.6,
          });

          for (let term of highValueTerms) {
            const results = fuse.search(term.term);
            if (results.length > 0) {
              for (let result of results) {
                const matchedTerm = result.value;
                const matchedTermRecord = this.terms.find(
                  (t) => t.term === matchedTerm
                );
                if (matchedTermRecord) {
                  matchedTermRecord.count += 1;
                }
              }
            } else {
              const newTerm = this.store.createRecord(
                'vocabulary-extractor-term',
                {
                  vocabularyExtractor: this,
                  recordingChunk: chunk,
                  term: term.term,
                  count: 1,
                }
              );
              newTerm.defineTask.perform();
            }
          }
          break;
        }
      } catch (e) {
        console.error(e);
        tries--;
      }
    }
  }
}
