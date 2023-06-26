import Model, { belongsTo, hasMany, attr } from '@ember-data/model';
import { task } from 'ember-concurrency';
import ENV from 'aittendee/config/environment';
import Evented from '@ember/object/evented';
import calculatChatCost from 'aittendee/utilities/calculate-chat-cost';

export default class RecordingChapterModel extends Model {
  constructor() {
    super(...arguments);
    Evented.apply(this);
  }

  @attr('number')
  number;

  @attr('number', { defaultValue: 0 })
  cost;

  @belongsTo('recording', { async: false })
  recording;

  get audience() {
    return this.recording?.audience;
  }

  @hasMany('recording-chunk', { async: false })
  chunks;

  @attr('string')
  _summary;

  set summary(value) {
    this._summary = value;
  }

  get summary() {
    return this._summary;
  }

  get sortedChunks() {
    return this.chunks
      .filter((c) => c.transcript)
      .sort((a, b) => {
        return a.createdAt - b.createdAt;
      });
  }

  get transcript() {
    return this.sortedChunks.map((c) => c.transcript).join(' ');
  }

  @task
  *summarizeTask() {
    const messages = [];
    const systemMessage = {
      role: 'system',
      content: `You are an assistant that is creating a bullet point summary for the following audience:

${this.audience}

The summary just needs to be a few bullet points that summarize the main points of the transcript.`,
    };

    messages.push(systemMessage);

    const userMessage = {
      role: 'user',
      content: `Here's the full content:
${this.transcript}`,
    };

    messages.push(userMessage);

    const data = {
      model: 'gpt-4-0613',
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
        try {
          let json = yield response.json();
          this.cost += calculatChatCost(json);
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
