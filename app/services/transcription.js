import Service from '@ember/service';
import { task } from 'ember-concurrency';
import fetch from 'fetch';
import ENV from 'aittendee/config/environment';

export default class TranscriptionService extends Service {
  @task
  *createTranscriptionTask({ blob, previousTranscript, model = 'whisper-1' }) {
    let url = 'https://api.openai.com/v1/audio/transcriptions';
    let formData = new FormData();
    formData.append('file', blob, 'audio.webm');
    formData.append('model', model);
    if (previousTranscript) {
      const prompt = `The transcript of the previous audio chunk was: "${previousTranscript}"`;
      formData.append('prompt', prompt);
    }

    let response = yield fetch(url, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${ENV.OPENAI_API_KEY}`,
      },
      body: formData
    });

    if (!response.ok) {
      throw new Error(`HTTP Error Response: ${response.status} ${response.statusText}`);
    }

    let json = yield response.json();
    return json;
  }
}
