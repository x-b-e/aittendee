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
import divide from 'ember-math-helpers/helpers/div';
import perform from 'ember-concurrency/helpers/perform';
import { next } from '@ember/runloop';

const images = [];
for (let i = 1; i <= 12; i++) {
  images.push(`/images/diversions.png`);
}

function formatCost(cost, precision = 2) {
  return `$${cost.toFixed(precision)}`;
}

function formatSecondsAsMinutes(seconds, precision = 1) {
  return `${(seconds / 60).toFixed(precision)}`;
}

function numberWithPrecisionFormatter(precision = 0) {
  return (value) => value.toFixed(precision);
}

function numberAsPercentFormatter(precision = 0) {
  return (value) => `${(value * 100).toFixed(precision)}%`;
}

function dollarWithPrecisionFormatter(precision = 2) {
  return (value) => formatCost(value, precision);
}

class TopBanner extends Component {
  <template>
    <div class="text-center bg-gray-900 px-6 py-2.5">
      <p class="text-sm leading-6 text-white">
        <a href="#">
          <strong class="font-semibold">NAPA Midyear 2023</strong><svg viewBox="0 0 2 2" class="mx-2 inline h-0.5 w-0.5 fill-current" aria-hidden="true"><circle cx="1" cy="1" r="1" /></svg>
          Kansas City
        </a>
      </p>
    </div>
  </template>
}

class VocabularyFlashCards extends Component {
  constructor() {
    super(...arguments);
    next(() => {
      this.pollForNextTask.perform();
    });
  }

  @tracked
  timeoutSeconds = 20;

  @tracked
  term;

  get terms() {
    const { recording } = this.args;
    if (!recording) return [];
    return recording.vocabularyTerms.filter((term) => term.definition);
  }

  @task
  *pollForNextTask() {
    while (true) {
      yield this.setNextTask.perform();
      yield timeout(this.timeoutSeconds * 1000);
    }
  }

  @task
  *setNextTask() {
    const { term, terms } = this;
    if (!term) {
      this.term = terms[0];
    } else {
      const index = terms.indexOf(term);
      if (index === terms.length - 1) {
        this.term = terms[0];
      } else {
        this.term = terms[index + 1];
      }
    }
  }

  <template>
    <div class="bg-white shadow">
      <div class="px-4 py-5">
        <h3 class="text-base font-semibold leading-6 text-gray-900">
          {{#if this.term}}
            {{this.term.term}}
          {{else}}
            Possibly New Vocabulary Term
          {{/if}}
        </h3>
        <div class="mt-2 max-w-xl text-sm text-gray-500">
          <p>
            {{#if this.term.definition}}
              {{this.term.definition}}
            {{else}}
              Any words that might be new to you will be defined here.
            {{/if}}
          </p>
        </div>
        <div class="mt-3 text-sm leading-6">
          <button
            class="font-semibold text-gray-900 hover:text-gray-500"
            {{on "click" (perform this.setNextTask)}}
          >
            Go the the next
            <span aria-hidden="true"> &rarr;</span>
          </button>
        </div>
      </div>
    </div>
  </template>
}

class Summary extends Component {
  <template>
    <div class="bg-white shadow overflow-y-auto" ...attributes id="summary">
      <div class="px-4 py-5 ">
        <div class="prose prose-sm">
          {{#if @recording.lastSummary.summary}}
            <Markdown @markdown={{@recording.lastSummary.summary}} />
          {{else}}
            <h3 class="text-base font-semibold leading-6 text-gray-900">
              Live Summary
            </h3>
            <div class="mt-2 text-sm text-gray-500">
              <p>
                A live summary of the speech will be written in Smart Brevity style (like Axios).
              </p>
            </div>
          {{/if}}
        </div>
      </div>
    </div>
  </template>
}

class PullQuote extends Component {
  constructor() {
    super(...arguments);
    next(() => {
      this.pollForNextPullQuoteTask.perform();
    });
  }

  @tracked
  timeoutSeconds = 20;

  @tracked
  pullQuote;

  get pullQuotes() {
    const { recording } = this.args;
    if (!recording) return [];
    return recording.pullQuotes;
  }

  @task
  *pollForNextPullQuoteTask() {
    while (true) {
      yield this.setNextPullQuoteTask.perform();
      yield timeout(this.timeoutSeconds * 1000);
    }
  }

  @task
  *setNextPullQuoteTask() {
    const { pullQuote, pullQuotes } = this;
    if (!pullQuote) {
      this.pullQuote = pullQuotes[0];
    } else {
      const index = pullQuotes.indexOf(pullQuote);
      if (index === pullQuotes.length - 1) {
        this.pullQuote = pullQuotes[0];
      } else {
        this.pullQuote = pullQuotes[index + 1];
      }
    }
  }

  <template>
    <div class="flex items-center">
      <div class="flex-none">
        <img src="/images/daft-napa.jpg" class="w-48 rounded-lg" />
      </div>
      <div class="flex-grow">
        <div class="flex flex-col space-y-4">
          <button
            class="px-2 text-xl font-semibold leading-7 text-gray-900 text-left"
            {{on "click" (perform this.setNextPullQuoteTask)}}
          >
            {{#if this.pullQuote.quote}}
              "{{this.pullQuote.quote}}"
            {{else}}
              "Most people underestimate what they can achieve in a day, while overestimating the wonders of a decade from now."
            {{/if}}
          </button>
          <div class="flex items-center">
            <div class="flex-auto">
              <div class="px-2 text-base font-semibold text-gray-900">
                Sean Devine
              </div>
              <div class="px-2 text-sm text-gray-500">
                Founder &amp; CEO, XBE
              </div>
            </div>
            <div class="flex-none">
              {{yield to="button"}}
            </div>
          </div>
        </div>
      </div>
    </div>
  </template>
}

class Stats extends Component {
  <template>
    <div class="bg-gray-900 w-full">
      <div class="grid grid-cols-3">
        {{yield}}
      </div>
    </div>
  </template>
}

class Stat extends Component {
  get valueFormatter() {
    return this.args.valueFormatter || ((value) => value);
  }

  <template>
    <div class="bg-gray-900 py-6 px-8">
      <p class="text-sm font-medium leading-6 text-gray-400">{{@label}}</p>
      <p class="mt-2 flex items-baseline gap-x-2">
        {{#if @value}}
          <span class="text-4xl font-semibold tracking-tight text-white">{{this.valueFormatter @value}}</span>
          {{#if @suffix}}
            <span class="text-sm text-gray-400">{{@suffix}}</span>
          {{/if}}
        {{else}}
          <span class="text-4xl font-semibold tracking-tight text-white">
            &nbsp;
          </span>
        {{/if}}
      </p>
    </div>
  </template>
}

export default class Session extends Component {
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
      this.store.createRecord('sentiment-estimator', {
        recording: this.recording,
      });

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
    <div class="flex flex-col h-full">
      <div class="flex-none">
        <TopBanner />
      </div>

      <div class="flex-none">
        <div class="py-4 mx-auto flex items-center space-x-8">
          <div class="flex-grow px-8">
            <img src="/images/xbe-logo.png" class="w-24"/>
          </div>
          <div class="flex-none">
            <div class="flex items-center space-x-4">
              <div class="font-bold text-5xl">AiSPHALT</div>
              <div class="font-thin text-4xl">
                The Transformative Power of Artificial Intelligence on the Asphalt Paving Industry
              </div>
            </div>
          </div>
          <div class="flex-grow px-8">
            <div class="flex">
              <div class="flex-grow"></div>
              <div class="flex-none">
                <img src="/images/hey-napa-logo-hat-and-boots.png" class="w-8" />
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="flex-none">
        <div class="grid grid-cols-3 gap-4 items-center">
          <div class="">
            <Stats @cols={{4}}>
              <Stat
                @label="Pace"
                @value={{this.recording.wordsPerMinute}}
                @valueFormatter={{numberWithPrecisionFormatter 0}}
                @suffix="wpm"
              />
              <Stat
                @label="Duration"
                @value={{divide this.recording.durationSeconds 60}}
                @valueFormatter={{numberWithPrecisionFormatter 1}}
                @suffix="mins"
              />
              <Stat
                @label="Rate"
                @value={{this.recording.costPerHour}}
                @valueFormatter={{dollarWithPrecisionFormatter 0}}
                @suffix="/ hr"
              />
            </Stats>
          </div>
          <div class="">
            <PullQuote @recording={{this.recording}}>
              <:button>
                <button
                  type="button" {{on "click" this.toggleIsOn}}
                >
                  {{#if this.isOn}}
                    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class="w-8 h-8 text-red-600">
                      <path d="M8.25 4.5a3.75 3.75 0 117.5 0v8.25a3.75 3.75 0 11-7.5 0V4.5z" />
                      <path d="M6 10.5a.75.75 0 01.75.75v1.5a5.25 5.25 0 1010.5 0v-1.5a.75.75 0 011.5 0v1.5a6.751 6.751 0 01-6 6.709v2.291h3a.75.75 0 010 1.5h-7.5a.75.75 0 010-1.5h3v-2.291a6.751 6.751 0 01-6-6.709v-1.5A.75.75 0 016 10.5z" />
                    </svg>
                  {{else}}
                    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-8 h-8">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M12 18.75a6 6 0 006-6v-1.5m-6 7.5a6 6 0 01-6-6v-1.5m6 7.5v3.75m-3.75 0h7.5M12 15.75a3 3 0 01-3-3V4.5a3 3 0 116 0v8.25a3 3 0 01-3 3z" />
                    </svg>
                  {{/if}}
                </button>
              </:button>
            </PullQuote>
          </div>
          <div class="flex items-center">
            <Stats>
              <Stat
                @label="Spend"
                @value={{this.recording.cost}}
                @valueFormatter={{dollarWithPrecisionFormatter 2}}
              />

              <Stat
                @label="Polarity"
                @value={{this.recording.polarity}}
                @valueFormatter={{numberAsPercentFormatter 0}}
                @suffix={{if (gt this.recording.polarity 0) "positive" "negative"}}
              />

              <Stat
                @label="Subjectivity"
                @value={{this.recording.subjectivity}}
                @valueFormatter={{numberAsPercentFormatter 0}}
              />
            </Stats>
          </div>
        </div>
      </div>

      <div class="flex-1 h-full p-4 overflow-y-hidden">
        <div class="flex h-full">
          <div class="flex-1 h-full pr-4">
            <Summary @recording={{this.recording}} class="h-full" />
          </div>
          <div class="flex-1"></div>
          <div class="flex-1 pl-4">
            <VocabularyFlashCards @recording={{this.recording}} />
          </div>
        </div>
      </div>

      <div class="flex-none">
        <div class="bg-green-500 h-4"></div>
      </div>
    </div>
  </template>
}