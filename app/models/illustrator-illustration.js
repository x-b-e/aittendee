import Model, { attr, belongsTo } from '@ember-data/model';
import { task } from 'ember-concurrency';
import fetch from 'fetch';
import ENV from 'aittendee/config/environment';

const COST_PER_IMAGE = 0.02;

export default class IllustratorIllustrationModel extends Model {
  @belongsTo('illustrator', { async: false })
  illustrator;

  @attr('string')
  name;

  @attr('string')
  prompt;

  @attr('string')
  url;

  @attr('number', { defaultValue: 0 })
  cost;

  @task
  *createImageTask() {
    const { prompt } = this;

    const data = {
      prompt,
    };

    let response = yield fetch('https://api.openai.com/v1/images/generations', {
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
      this.cost += COST_PER_IMAGE;
      const url = json['data'][0]['url'];
      this.url = url;
    }
  }
}
