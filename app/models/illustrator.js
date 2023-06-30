import Model, { belongsTo, attr, hasMany } from '@ember-data/model';
import { task } from 'ember-concurrency';
import fetch from 'fetch';
import ENV from 'aittendee/config/environment';
import calculatChatCost from 'aittendee/utilities/calculate-chat-cost';

export default class IllustratorModel extends Model {
  @belongsTo('recording', { async: false })
  recording;

  @attr('string')
  style;

  @attr('string')
  transcript;

  @attr('number', { defaultValue: 0 })
  cost;

  @hasMany('illustrator-illustrations', { async: false })
  illustrations;

  @task
  *illustrateTask() {
    const prompt = yield this.createPromptTask.perform();
    yield this.createIllustrationTask.perform(prompt);
  }

  @task
  *createPromptTask() {
    const messages = [];
    const systemMessage = {
      role: 'system',
      content: `
        You are an art director.
        You are creating a short 10 word prompt for an image based on following content provided by the user.
        The prompt should be a short description of a naturalist image that you want the artist to create inspired by this content.
        The prompt should not describe people.
        The prompt should be written in a way that is easy for the artist to understand and follow.
        The image should be a scene in the real world.
        The illustration should include no words.
        The style should be ${this.style} and the prompt must include the style.
      `.trim(),
    };
    messages.push(systemMessage);
    const userMessage = {
      role: 'user',
      content: `The content is as follows:
"""
${this.transcript}
"""

Please create a prompt for the artist and explain your reasoning as an art director.
`,
    };
    messages.push(userMessage);

    const functions = [];
    const promptFunction = {
      name: 'prompt',
      description: 'Create a prompt for the artist.',
      parameters: {
        type: 'object',
        properties: {
          prompt: {
            type: 'string',
            description: `The prompt for the artist.`,
          },
          name: {
            type: 'string',
            description: `A one to three word poetic name for the art.`,
          },
          reasoning: {
            type: 'string',
            description: `The reasoning for the prompt.`,
          },
        },
        required: ['prompt', 'name', 'reasoning'],
      },
    };
    functions.push(promptFunction);

    const data = {
      model: 'gpt-4-0613',
      messages,
      functions,
      function_call: {
        name: 'prompt',
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
          });

        if (!response.ok) {
          throw new Error(
            `HTTP Error Response: ${response.status} ${response.statusText}`
          );
        } else {
          const json = yield response.json();
          this.cost += calculatChatCost(json);
          const functionArguments = JSON.parse(
            json['choices'][0]['message']['function_call']['arguments']
          );
          const prompt = functionArguments['prompt'];
          const name = functionArguments['name'];
          const reasoning = functionArguments['reasoning'];
          return {
            prompt,
            name,
            reasoning,
          };
        }
      } catch (e) {
        console.error(e);
        tries--;
      }
    }
  }

  @task
  *createIllustrationTask(prompt) {
    const illustration = this.store.createRecord('illustrator-illustration', {
      illustrator: this,
      name: prompt.name,
      prompt: prompt.prompt,
      reasoning: prompt.reasoning,
    });
    yield illustration.createImageTask.perform();
  }
}
