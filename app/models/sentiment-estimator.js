import Model, { belongsTo, hasMany } from '@ember-data/model';
import { task } from 'ember-concurrency';
import ENV from 'aittendee/config/environment';
import calculateChatCost from 'aittendee/utilities/calculate-chat-cost';

function buildSystemMessage({ recording }) {
  return {
    role: 'system',
    content: `
You are an assistant that is estimating the sentiment of a section of a speech for the following audience:

"""
${recording.audience}
"""

You are estimating the polarity and subjectivity of the speech. Polarity is a number between -1 and 1 that indicates how positive or negative the speech is. Subjectivity is a number between 0 and 1 that indicates how subjective or objective the speech is.
    `.trim(),
  };
}

function buildUserMessage({ chapter }) {
  return {
    role: 'user',
    content: `
Here's the section of the speech that you're estimating the sentiment of:

${chapter.summary}
    `.trim(),
  };
}

export default class SentimentEstimatorModel extends Model {
  @belongsTo('recording', { async: false })
  recording;

  get audience() {
    return this.recording?.audience;
  }

  @hasMany('sentiment-estimate', { async: false })
  estimates;

  @task
  *estimateSentimentTask(chapter) {
    const systemMessage = buildSystemMessage({ recording: this.recording });
    const userMessage = buildUserMessage({ chapter });

    const messages = [systemMessage, userMessage];
    const sentimentFunction = {
      name: 'sentiment',
      description: 'Estimate the sentiment of a section of a speech.',
      parameters: {
        type: 'object',
        properties: {
          polarity: {
            type: 'number',
            description: 'A number between -1 and 1 that indicates how positive or negative the speech is.',
          },
          subjectivity: {
            type: 'number',
            description: 'A number between 0 and 1 that indicates how subjective or objective the speech is.',
          },
        },
        required: ['polarity', 'subjectivity'],
      },
    };

    const data = {
      model: 'gpt-4-0613',
      messages,
      functions: [sentimentFunction],
      function_call: {
        name: 'sentiment',
      }
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
          this.cost += calculateChatCost(json);
          const functionArguments = JSON.parse(
            json['choices'][0]['message']['function_call']['arguments']
          );
          const polarity = functionArguments['polarity'];
          const subjectivity = functionArguments['subjectivity'];
          if (polarity > 1 || polarity < -1) {
            throw new Error(`Polarity ${polarity} is out of range.`);
          }
          if (subjectivity > 1 || subjectivity < 0) {
            throw new Error(`Subjectivity ${subjectivity} is out of range.`);
          }
          this.store.createRecord('sentiment-estimate', {
            estimator: this,
            chapter,
            polarity,
            subjectivity,
          });
          break;
        }
      } catch (e) {
        console.error(e);
        tries--;
      }
    }
  }
}
