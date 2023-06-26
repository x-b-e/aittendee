import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { on } from '@ember/modifier';
import { action } from '@ember/object';
import { service } from '@ember/service';
import { later } from '@ember/runloop';
import didInsert from '@ember/render-modifiers/modifiers/did-insert';
import gt from 'ember-truth-helpers/helpers/gt';
import WordCloud from 'aittendee/components/word-cloud';
import Markdown from 'aittendee/components/markdown';
import { task, timeout } from 'ember-concurrency';

function formatCost(cost, precision = 2) {
  return `$${cost.toFixed(precision)}`;
}

function formatSecondsAsMinutes(seconds, precision = 1) {
  return `${(seconds / 60).toFixed(precision)}`;
}

class AudioPlayer extends Component {
  get src() {
    return URL.createObjectURL(this.args.chunk.blob);
  }
  <template>
    <div class="flex">
      {{!-- <div class="flex-1">
        <audio src={{this.src}} controls></audio>
      </div> --}}
      <div class="flex-1">
        {{#if @chunk.transcript}}
          {{@chunk.transcript}}
        {{else}}
          Transcribing...
        {{/if}}
      </div>
    </div>
  </template>
}

export default class Microphone extends Component {
  constructor() {
    super(...arguments);
    this.setRandomQuote.perform();
  }

  @tracked
  isOn = false;

  @tracked
  stream;

  @tracked
  recording;

  @tracked
  vocabularyExtractor;

  @tracked
  randomPullQuote;

  @tracked
  blobs = [];

  @service
  audio;

  @service
  store;

  @action
  toggleIsOn() {
    this.isOn = !this.isOn;
    if (this.isOn) {
      this.recording = this.store.createRecord('recording', {
        audience: `The audience are executives attending the National Asphalt Pavement Association's mid-year meeting. They would tend to have a well rounded understanding of asphalt pavement and business topics, but would no relatively little about artificial intelligence and other emerging technologies. They are fairly sophisticated, so business jargon is well understood already.`
      });
      this.vocabularyExtractor = this.store.createRecord('vocabulary-extractor', {
        recording: this.recording,
      });
      this.recording.createMarketer();
      const createChunk = (blob) => {
        this.recording.createChunk({ blob });
      }
      this.audio.startRecording({ onDataAvailable: createChunk });
    } else {
      this.audio.stopRecording();
    }
  }

  get lastIllustration() {
    const { recording } = this;
    if (!recording) return;
    const { illustrators } = recording;
    let lastIllustration;
    for (let illustrator of illustrators) {
      for (let illustration of illustrator.illustrations) {
        if (illustration.url) {
          lastIllustration = illustration;
        }
      }
    }
    return lastIllustration;
  }

  @task
  *setRandomQuote() {
    while (true) {
      const { recording } = this;
      const pullQuotes = [];
      if (recording) {
        for (const marketer of recording.marketers) {
          for (const pullQuote of marketer.pullQuotes) {
            pullQuotes.push(pullQuote);
          }
        }
      }
      this.randomPullQuote = pullQuotes[Math.floor(Math.random() * pullQuotes.length)];
      yield timeout(1000 * 10);
    }
  }

  <template>
    <div class="">
      <div class="grid grid-cols-3">
        <div>
          <div>
            {{#if (gt this.recording.wordsPerMinute 0)}}
              {{this.recording.wordsPerMinute}} WPM
              <span class="text-xs">
                after {{formatSecondsAsMinutes this.recording.durationSeconds}} minutes
              </span>
            {{/if}}
          </div>
          <div>
            {{#if (gt this.recording.cost 0)}}
              <div>
                {{formatCost this.recording.cost 2}} total cost
              </div>
            {{/if}}
            {{#if (gt this.recording.costPerHour 0)}}
              <div>
                {{formatCost this.recording.costPerHour 0}} / hour
              </div>
            {{/if}}
          </div>
        </div>
        <div>
          <button
            class="
              rounded-lg border-4 p-4 block mx-auto
              {{if this.isOn "border-red-500" "border-gray-300"}}
            " type="button" {{on "click" this.toggleIsOn}}
          >
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-12 h-12">
              <path stroke-linecap="round" stroke-linejoin="round" d="M12 18.75a6 6 0 006-6v-1.5m-6 7.5a6 6 0 01-6-6v-1.5m6 7.5v3.75m-3.75 0h7.5M12 15.75a3 3 0 01-3-3V4.5a3 3 0 116 0v8.25a3 3 0 01-3 3z" />
            </svg>
          </button>
        </div>
        <div>

        </div>
      </div>

      {{#if this.randomPullQuote}}
        <div>
          <blockquote class="text-center text-xl font-semibold leading-8 text-gray-900 sm:text-2xl sm:leading-9 max-w-prose mx-auto my-8">
            “{{this.randomPullQuote.quote}}”
          </blockquote>
        </div>
      {{/if}}

      <div class="flex my-4">
        <div class="flex-1 max-w-prose mx-auto prose-sm">
          <div class="">
            {{#if this.recording.lastSummary}}
              <Markdown @markdown={{this.recording.lastSummary.summary}} />
            {{else}}
              <div class="text-lg text-gray-500">
                Waiting to write summary.
              </div>
            {{/if}}
          </div>
        </div>
        <div class="flex-none">
          <div class="flex flex-col space-y-2 w-72">
            <div>
              <WordCloud @terms={{this.vocabularyExtractor.terms}} />
            </div>
            <div>
              {{#if this.lastIllustration}}
                <div class="text-sm font-bold mb-1">
                  {{this.lastIllustration.name}}
                </div>
                <img
                  src={{this.lastIllustration.url}}
                  class=""
                />
              {{/if}}
            </div>
          </div>
        </div>
      </div>
    </div>
  </template>
}