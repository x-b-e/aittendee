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

      this.addAttendees();

      const createChunk = (blob) => {
        this.recording.createChunk({ blob });
      }
      this.audio.startRecording({ onDataAvailable: createChunk });
    } else {
      this.audio.stopRecording();
    }
  }

  @action
  addAttendees() {
    const { recording } = this;
    const attributesList = [
      {
        name: 'Julie Bowen',
        voiceName: 'en-US-Neural2-F',
        profile: `
Julie Bowen (no relation to Matt and Trey Bowen of Superior Bowen) is a seasoned executive leader and financial professional based in the Kansas City Metropolitan Area. With a rich professional background, she possesses a unique combination of expertise in finance, accounting, auditing, and executive leadership, making her a versatile addition to any organization. Julie's robust academic foundation includes a Bachelor of Science in Business Administration, with concentrations in Accounting and Economics, and a Masters of Accountancy from Kansas State University. She's also a Certified Public Accountant (CPA) in both Kansas and Missouri and holds Series 66, 7, and 63 Securities Licenses.

Julie began her career in auditing as an Audit Senior Associate at KPMG, one of the Big Four accounting organizations. She then advanced into a role with Ferrell Capital, Inc., where she juggled three concurrent positions—Controller for Ferrell Capital, Chief Compliance Officer, and Investment Analyst for Samson Capital Management. In these roles, she showcased her ability to manage a diverse portfolio of responsibilities, from real estate management to the creation of robust compliance programs.

Following her tenure at Ferrell Capital, Inc., Julie assumed the role of Chief Financial Officer (CFO) at Tanner & White Properties, Inc. and its affiliated entities, including Woodside Health & Tennis Club. Here, she demonstrated her financial acumen in real estate development and operations, from securing financing for significant projects to implementing rigorous budgeting and forecasting processes.

In recent years, Julie has served as CFO for Samson Dental Partners, Bright Tiger Dental, and currently Legacy Infrastructure Group. At Samson Dental Partners, she orchestrated a strategic business shutdown while transitioning to Bright Tiger Dental. As CEO of Bright Tiger Dental, she led a substantial organizational change that resulted in 55% revenue growth in 11 months. Currently, as CFO at Legacy Infrastructure Group (owner of Superior Bowen and Haskell Lemon), she continues to leverage her expertise to guide the company's financial and operational leadership.

Overall, Julie exhibits the qualities of an adaptable, resilient leader. She is not only a problem solver but also an agent of change who thrives in dynamic, challenging environments. Her ability to construct and guide teams around common goals, coupled with her knack for building robust financial and operational structures, has consistently driven her organizations to success. She is known for her agility in the face of change, unwavering sense of urgency, and her commitment to the human side of business. She takes pride in building strong, committed teams and fostering workplace cultures where they can thrive.

On the personal side, Julie is a married mom of 2 elementary school age boys. She wears baseball hats on the weekend, but no golf shirts. She's actually quite stylish but does not identify as such. She's fit, but her Peloton output could be much higher. She's a fun extrovert that everyone loves to be around. She's a determined learner that figures out new things through steady commitment and smarts. She's got "it" whether or not she thinks so.

She's pretty practical and mostly focused on the financial here-and-now, but is up for conversation about just about anything regardless.
        `.trim(),
      }
    ];

    for (let attributes of attributesList) {
      this.store.createRecord('attendee', { recording, ...attributes });
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
            <div>
              <div class="text-sm font-bold mb-1">
                Questions
              </div>
              {{#each this.recording.attendees as |attendee|}}
                {{#if (gt attendee.questions.length 0)}}
                  <div>
                    <div class="text-sm font-bold mb-1">
                      {{attendee.name}}
                    </div>
                    <div class="text-xs">
                      <ul class="list-disc">
                        {{#each attendee.questions as |question|}}
                          <li>
                            {{question.question}}
                            {{#if question.audioUrl}}
                              <div>
                                <audio controls src={{question.audioUrl}}></audio>
                              </div>
                            {{/if}}
                          </li>
                        {{/each}}
                      </ul>
                    </div>
                  </div>
                {{/if}}
              {{/each}}
            </div>
          </div>
        </div>
      </div>
    </div>
  </template>
}