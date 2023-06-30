import Model, { belongsTo, attr } from '@ember-data/model';
import { task } from 'ember-concurrency';
import ENV from 'aittendee/config/environment';
import fetch from 'fetch';

const { GOOGLE_API_KEY } = ENV;

function base64ToArrayBuffer(base64) {
  let binaryString = window.atob(base64);
  let len = binaryString.length;
  let bytes = new Uint8Array(len);
  for (let i = 0; i < len; i++) {
    bytes[i] = binaryString.charCodeAt(i);
  }
  return bytes.buffer;
}

export default class AttendeeQuestionModel extends Model {
  @belongsTo('attendee', { async: false })
  attendee;

  @attr('string')
  question;

  @attr('string')
  name;

  @attr('string')
  audioUrl;

  @task
  *generateAudioTask() {
    const { question, attendee } = this;

    const data = {
      input: {
        text: question,
      },
      audioConfig: {
        audioEncoding: 'MP3',
        pitch: 0,
        speakingRate: 1.2,
      },
      voice: {
        languageCode: 'en-US',
        name: attendee.voiceName,
      },
    };

    let tries = 3;
    while (tries > 0) {
      const url = `https://content-texttospeech.googleapis.com/v1beta1/text:synthesize?alt=json&key=${GOOGLE_API_KEY}`;

      const response = yield fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(data),
      });

      if (!response.ok) {
        console.error(response);
        tries--;
      } else {
        const json = yield response.json();
        const audioContent = json['audioContent'];

        const audioBuffer = base64ToArrayBuffer(audioContent);
        const audioBlob = new Blob([audioBuffer], { type: 'audio/mp3' });
        const audioUrl = URL.createObjectURL(audioBlob);
        this.audioUrl = audioUrl;
        break;
      }
    }
  }
}
