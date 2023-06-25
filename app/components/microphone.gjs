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

function formatCost(cost, precision = 2) {
  return `$${cost.toFixed(precision)}`;
}

class Term extends Component {
  @tracked
  isVisible = true;

  constructor() {
    super(...arguments);
    this.startTimer();
  }

  @action
  startTimer() {
    const { term } = this.args;
    if (term.definition) {
      later(this, this.hideTerm, 10 * 1000)
    }
  }

  @action
  hideTerm() {
    this.isVisible = false;
  }

  <template>
    {{#if this.isVisible}}
      <li>
        <span class="font-bold">{{@term.term}}</span>:
        {{#if @term.definition}}
          <span
            {{didInsert this.startTimer}}
          >
            {{@term.definition}}
          </span>
        {{else if @term.defineTask.isRunning}}
          Defining...
        {{else}}
          <span class="italic text-grey-400">
            Not found
          </span>
        {{/if}}
      </li>
    {{/if}}
  </template>
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
  @tracked
  isOn = false;

  @tracked
  stream;

  @tracked
  recording;

  @tracked
  vocabularyExtractor;

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

  <template>
    <div class="">
      <div class="grid grid-cols-3">
        <div>
          <div>
            {{#if (gt this.recording.wordsPerMinute 0)}}
              {{this.recording.wordsPerMinute}} WPM
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

      <div class="flex my-4">
        <div class="flex-1 max-w-prose mx-auto prose-sm">
          <h3>Terms That Might Be New To You</h3>
          <p>
            The following terms were mentioned in this speech and might be new to you. They're being extracted and defined in real time.
          </p>
          <ul class="">
            {{#each this.vocabularyExtractor.terms as |term|}}
              <Term @term={{term}} />
            {{/each}}
          </ul>

          <h3>Word Cloud</h3>
          <WordCloud @terms={{this.vocabularyExtractor.terms}} />

          <h3>Summary</h3>
          <div class="">
            {{#if this.recording.lastSummary}}
              <Markdown @markdown={{this.recording.lastSummary.summary}} />
            {{else}}
              Waiting to write summary.
            {{/if}}
          </div>

          <h3>Chapter Summaries</h3>
          <ul>
            {{#each this.recording.chapters as |chapter|}}
              <li>
                {{#if chapter.summary}}
                  <Markdown @markdown={{chapter.summary}} />
                {{else if chapter.summarizeTask.isRunning}}
                  Summarizing...
                {{else}}
                  No summary
                {{/if}}
              </li>
            {{/each}}
          </ul>
        </div>
        <div class="flex-none">
          <div class="w-72">
            {{#if this.lastIllustration}}
              <div class="text-sm font-bold mb-1">
                {{this.lastIllustration.name}}
              </div>
              <img
                src={{this.lastIllustration.url}}
                class="w-full"
              />
            {{/if}}
          </div>
        </div>
      </div>
    </div>
  </template>
}