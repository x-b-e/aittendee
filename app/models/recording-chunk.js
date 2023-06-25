import Model, { belongsTo, attr } from '@ember-data/model';
import { task } from 'ember-concurrency';
import { service } from '@ember/service';
import Evented from '@ember/object/evented';

const COST_PER_SECOND = 0.006 / 60;

export default class RecordingChunkModel extends Model {
  constructor() {
    super(...arguments);
    Evented.apply(this);
  }

  @belongsTo('recording', { async: false })
  recording;

  @attr('date')
  createdAt;

  @attr('number')
  durationSeconds;

  get cost() {
    const { durationSeconds } = this;
    if (!durationSeconds) return 0;

    return durationSeconds * COST_PER_SECOND;
  }

  @attr()
  _blob;

  @attr('string')
  _transcript;

  set transcript(value) {
    this._transcript = value;
    this.trigger('transcribed', this);
  }

  get transcript() {
    return this._transcript;
  }

  @service
  transcription;

  @service
  audio;

  set blob(blob) {
    this._blob = blob;
    this.setDuration();
    this.transcribeTask.perform();
  }

  get blob() {
    return this._blob;
  }

  get previousChunk() {
    const chunks = this.recording.chunks.toArray();
    const sortedChunks = chunks.sort((a, b) => {
      return a.createdAt - b.createdAt;
    });
    const index = sortedChunks.indexOf(this);
    return sortedChunks[index - 1];
  }

  get wordCount() {
    const { transcript } = this;
    if (!transcript) return null;

    if (transcript.trim() === '') {
      return 0;
    }

    return transcript.trim().split(/\s+/).length;
  }

  get wordsPerMinute() {
    const { wordCount, durationSeconds } = this;
    if (!wordCount || !durationSeconds) return null;
    if (durationSeconds === 0) return null;

    return Math.round((wordCount / durationSeconds) * 60);
  }

  setDuration() {
    const { blob } = this;
    if (!blob) return;

    const blobUrl = URL.createObjectURL(blob);

    fetch(blobUrl)
      .then((response) => response.arrayBuffer())
      .then((arrayBuffer) => {
        var offlineCtx = new OfflineAudioContext(1, 44100 * 20, 44100);
        return offlineCtx.decodeAudioData(arrayBuffer);
      })
      .then((audioBuffer) => {
        this.durationSeconds = audioBuffer.duration;
      })
      .catch((e) => {
        console.error('There was an error loading the audio blob: ' + e);
      });
  }

  @task
  *transcribeTask() {
    let tries = 3;
    while (tries > 0) {
      tries--;
      const previousChunk = this.previousChunk;
      try {
        let transcription =
          yield this.transcription.createTranscriptionTask.perform({
            blob: this.blob,
            previousTranscript: previousChunk?.transcript,
          });
        this.transcript = transcription.text;
        break;
      } catch (e) {
        console.error(e);
        if (tries === 0) {
          throw e;
        }
      }
    }
  }
}
