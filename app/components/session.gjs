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
import { fn } from '@ember/helper';
import eq from 'ember-truth-helpers/helpers/eq';
import and from 'ember-truth-helpers/helpers/and';
import not from 'ember-truth-helpers/helpers/not';

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

function getLightestRow(imageData, padding) {
  return new Promise((resolve, reject) => {
    let img = new Image();
    img.onload = function () {
      let canvas = document.createElement('canvas');
      let ctx = canvas.getContext('2d');

      canvas.width = this.width;
      canvas.height = this.height;

      ctx.drawImage(this, 0, 0, this.width, this.height);

      let maxBrightness = 0;
      let maxBrightnessRowIndex = padding;

      for (let y = padding; y < this.height - padding; y += 5) {
        let rowBrightness = 0;
        let count = 0;  // keep track of how many pixels we've checked

        // Only check every 5th pixel along the row
        for (let x = 0; x < this.width; x += 5) {
          let pixelData = ctx.getImageData(x, y, 1, 1).data;

          // Calculate brightness
          let pixelBrightness = (pixelData[0] + pixelData[1] + pixelData[2]) / 3;

          rowBrightness += pixelBrightness;
          count++;
        }

        let averageRowBrightness = rowBrightness / count;  // divide by the number of pixels checked

        if (averageRowBrightness > maxBrightness) {
          maxBrightness = averageRowBrightness;
          maxBrightnessRowIndex = y;
        }
      }

      // Convert row index to percentage
      let percentage = (maxBrightnessRowIndex / this.height) * 100;

      resolve(percentage);
    };

    img.onerror = function () {
      reject('Failed to load image');
    };

    img.src = imageData;
  });
}

class Illustrations extends Component {
  constructor() {
    super(...arguments);
    next(() => {
      this.pollForNextTask.perform();
    });
  }

  get illustrations() {
    const { recording } = this.args;
    if (!recording) return [];

    return recording.illustrations;
  }

  @tracked
  selectedIllustration;

  get lightestRowPct() {
    const { selectedIllustration } = this;
    if (!selectedIllustration) return null;
    return selectedIllustration.lightestRowPct;
  }

  get selectedIllustrationUrl() {
    const { selectedIllustration } = this;
    if (!selectedIllustration) return '/images/illustration-default.png';
    return selectedIllustration.url;
  }

  get selectedIllustrationName() {
    const { selectedIllustration } = this;
    if (!selectedIllustration) return 'Selected Images';
    return selectedIllustration.name;
  }

  get selectedIllustrationReasoning() {
    const { selectedIllustration } = this;
    if (!selectedIllustration) return null;
    return selectedIllustration.reasoning;
  }

  @task
  *pollForNextTask() {
    while (true) {
      yield this.setNextTask.perform();
      yield timeout(10 * 1000);
    }
  }

  @task
  *setNextTask() {
    const { illustrations } = this;
    const { selectedIllustration } = this;

    if (!selectedIllustration) {
      if (illustrations.length === 0) {
        this.selectedIllustration = {
          url: '/images/illustration-default.png',
        };
      } else {
        this.selectedIllustration = illustrations[0];
      }
    } else {
      const index = illustrations.indexOf(selectedIllustration);
      if (index === illustrations.length - 1) {
        this.selectedIllustration = illustrations[0];
      } else {
        this.selectedIllustration = illustrations[index + 1];
      }
    }
  }

  <template>
    <div class="static">
      <button
        type="button"
        class="aspect-square relative w-full"
        {{on "click" (perform this.setNextTask)}}
      >
        <img src={{this.selectedIllustrationUrl}} class="absolute inset-0" />
        {{#if this.lightestRowPct}}
          <div class="absolute inset-x-0 p-6 font-permanent-marker text-2xl text-center" style="top: {{this.lightestRowPct}}%; transform: translateY(-50%);">
            {{this.selectedIllustrationName}}
          </div>
        {{/if}}
      </button>
      {{#if this.selectedIllustration.reasoning}}
        <div class="text-center text mt-4 font-permanent-marker">
          {{this.selectedIllustration.reasoning}}
        </div>
      {{/if}}
    </div>
  </template>
}

class AttendeeQuestions extends Component {
  @tracked
  selectedAttendee;

  @tracked
  selectedQuestion;

  get attendees() {
    const { recording } = this.args;
    if (!recording) return [];

    return recording.attendees;
  }

  @action
  selectAttendee(attendee) {
    this.selectedQuestion = null;
    if (this.selectedAttendee === attendee) {
      this.selectedAttendee = null;
    } else {
      this.selectedAttendee = attendee;
    }
  }

  @action
  selectQuestion(question) {
    if (this.selectedQuestion === question) {
      this.selectedQuestion = null;
    } else {
      this.selectedQuestion = question;
    }
  }

  <template>
    <div class="bg-white shadow" ...attributes>
      <div class="px-4 py-5 h-full">
        <div class="flex flex-col h-full space-y-4">
          <h3 class="text-base font-semibold leading-6 text-gray-900">
            Attendee Questions
          </h3>

          <div class="flex space-x-4">
            {{#each this.attendees as |attendee|}}
              <button
                {{on "click" (fn this.selectAttendee attendee)}}
              >
                <span class="relative inline-block">
                  <img
                    class="
                      h-24 w-24 rounded-md
                      {{if (and this.selectedAttendee (not (eq this.selectedAttendee attendee))) "opacity-50"}}
                    "
                    src={{attendee.imageUrl}}
                  >
                  {{#if attendee.hasQuestions}}
                    <span class="absolute right-0 top-0 block h-4 w-4 -translate-y-1/2 translate-x-1/2 transform rounded-full bg-green-400 ring-2 ring-white"></span>
                  {{/if}}
                </span>
              </button>
            {{/each}}
          </div>

          {{#if this.selectedAttendee}}
            <div class="flex-1">
              <div class="flex flex-col h-full space-y-2">
                <div class="text-2xl font-semibold flex-none">
                  {{this.selectedAttendee.name}}
                </div>
                {{#if this.selectedAttendee.hasQuestions}}
                  <div class="flex-none max-h-1/3 overflow-y-auto">
                    <div class="">
                      <ul role="list" class="divide-y divide-gray-200">
                        {{#each this.selectedAttendee.questions as |question|}}
                          <li class="py-2">
                            <button
                              {{on "click" (fn this.selectQuestion question)}}
                              class="block"
                            >
                              <div
                                class="
                                  flex items-center space-x-2
                                  {{if (eq this.selectedQuestion question) "font-bold"}}
                                "
                              >
                                <div>
                                  <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-6 h-6">
                                    <path stroke-linecap="round" stroke-linejoin="round" d="M9.879 7.519c1.171-1.025 3.071-1.025 4.242 0 1.172 1.025 1.172 2.687 0 3.712-.203.179-.43.326-.67.442-.745.361-1.45.999-1.45 1.827v.75M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-9 5.25h.008v.008H12v-.008z" />
                                  </svg>
                                </div>

                                <div>
                                  {{question.name}}
                                </div>
                              </div>
                            </button>
                          </li>
                        {{/each}}
                      </ul>
                    </div>
                  </div>
                  {{#if this.selectedQuestion}}
                    <div class="flex-1">
                      <div class="flex flex-col space-y-2">
                        <div>
                          <audio
                            controls
                            src={{this.selectedQuestion.audioUrl}}
                          />
                        </div>
                        <div class="flex-1 overflow-y-auto text-lg font-bangers">
                          {{this.selectedQuestion.question}}
                        </div>
                      </div>
                    </div>
                  {{/if}}
                {{/if}}
              </div>
            </div>
          {{/if}}
        </div>
      </div>
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
    <div class="bg-white shadow h-1/4" ...attributes>
      <div class="px-4 py-5 h-full">
        <div class="flex flex-col h-full">
          <div class="flex-none">
            <h3 class="text-base font-semibold leading-6">
              {{#if this.term}}
                {{this.term.term}}
              {{else}}
                New Vocabulary Terms
              {{/if}}
            </h3>
          </div>
          <div class="mt-2 max-w-xl text-sm text-gray-500 flex-1">
            <p>
              {{#if this.term.definition}}
                {{this.term.definition}}
              {{else}}
                Any words that might be new to you will be defined here.
              {{/if}}
            </p>
          </div>
          <div class="mt-3 text-sm leading-6 flex-none">
            <button
              class="font-semibold hover:text-gray-500"
              {{on "click" (perform this.setNextTask)}}
            >
              Go to the next term
              <span aria-hidden="true"> &rarr;</span>
            </button>
          </div>
        </div>
      </div>
    </div>
  </template>
}

class Summary extends Component {
  <template>
    <div class="bg-white shadow overflow-y-auto" ...attributes>
      <div class="px-4 py-5 ">
        <div class="prose">
          <h3 class="text-base font-semibold leading-6 text-gray-900">
            Live Summary
          </h3>
          {{#if @recording.lastSummary.summary}}
            <Markdown @markdown={{@recording.lastSummary.summary}} />
          {{else}}
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
              “{{this.pullQuote.quote}}”
            {{else}}
              “Most people underestimate what they can achieve in a day, while overestimating the wonders of a decade from now.”
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
        imageUrl: '/images/julie-bowen.jpg',
        profile: `
Julie Bowen (no relation to Matt and Trey Bowen of Superior Bowen) is a seasoned executive leader and financial professional based in the Kansas City Metropolitan Area. With a rich professional background, she possesses a unique combination of expertise in finance, accounting, auditing, and executive leadership, making her a versatile addition to any organization. Julie's robust academic foundation includes a Bachelor of Science in Business Administration, with concentrations in Accounting and Economics, and a Masters of Accountancy from Kansas State University. She's also a Certified Public Accountant (CPA) in both Kansas and Missouri and holds Series 66, 7, and 63 Securities Licenses.

Julie began her career in auditing as an Audit Senior Associate at KPMG, one of the Big Four accounting organizations. She then advanced into a role with Ferrell Capital, Inc., where she juggled three concurrent positions—Controller for Ferrell Capital, Chief Compliance Officer, and Investment Analyst for Samson Capital Management. In these roles, she showcased her ability to manage a diverse portfolio of responsibilities, from real estate management to the creation of robust compliance programs.

Following her tenure at Ferrell Capital, Inc., Julie assumed the role of Chief Financial Officer (CFO) at Tanner & White Properties, Inc. and its affiliated entities, including Woodside Health & Tennis Club. Here, she demonstrated her financial acumen in real estate development and operations, from securing financing for significant projects to implementing rigorous budgeting and forecasting processes.

In recent years, Julie has served as CFO for Samson Dental Partners, Bright Tiger Dental, and currently Legacy Infrastructure Group. At Samson Dental Partners, she orchestrated a strategic business shutdown while transitioning to Bright Tiger Dental. As CEO of Bright Tiger Dental, she led a substantial organizational change that resulted in 55% revenue growth in 11 months. Currently, as CFO at Legacy Infrastructure Group (owner of Superior Bowen and Haskell Lemon), she continues to leverage her expertise to guide the company's financial and operational leadership.

Overall, Julie exhibits the qualities of an adaptable, resilient leader. She is not only a problem solver but also an agent of change who thrives in dynamic, challenging environments. Her ability to construct and guide teams around common goals, coupled with her knack for building robust financial and operational structures, has consistently driven her organizations to success. She is known for her agility in the face of change, unwavering sense of urgency, and her commitment to the human side of business. She takes pride in building strong, committed teams and fostering workplace cultures where they can thrive.

On the personal side, Julie is a married mom of 2 elementary school age boys. She wears baseball hats on the weekend, but no golf shirts. She's actually quite stylish but does not identify as such. She's fit, but her Peloton output could be much higher. She's a fun extrovert that everyone loves to be around. She's a determined learner that figures out new things through steady commitment and smarts. She's got "it" whether or not she thinks so.

She's pretty practical and mostly focused on the financial here-and-now, but is up for conversation about just about anything regardless.
        `.trim(),
      },
      {
        name: 'Grant Wollenhaupt',
        voiceName: 'en-US-Neural2-D',
        imageUrl: '/images/grant-wollenhaupt.jpg',
        profile: `
Grant Wollenhaupt is a seasoned professional in the construction industry, currently serving as the Chief Customer Officer at XBE, a leading provider of operations management software to the horizontal construction industry. He has an extensive history working in various roles within the industry, demonstrating versatility and progressive growth in his career. Grant has a Bachelor of Arts degree focused in Political Science and Government, Constitutional Law, and Pre-Medicine from St. John's University.

Before assuming his current role at XBE, Grant worked as the company's Chief Commercial Officer for nearly four years. Prior to this, he worked for Superior Bowen for six and a half years, holding the positions of Vice President of Strategy and Innovation and Director of Business Development. Grant has also been serving as the Director of Business Operations at R2R "Research to Roads" for almost 14 years.

Grant's professional experience shows that he is a strong strategic thinker, as evidenced by his roles in strategy and business development at multiple organizations. His capacity to hold roles as both a Director of Business Development and Vice President of Strategy and Innovation suggests a creative and analytical mind, capable of recognizing business opportunities and driving growth.

His long-standing tenure at various organizations shows loyalty and commitment, and his progression into leadership roles indicates ambition, competence, and a capacity to inspire and lead teams. His expertise in budgeting, engineering, strategic planning, business development, and team building reflects strong leadership qualities, including financial acumen, technical knowledge, forward-thinking, and team-oriented mindset.

His educational background in Political Science, Government, Constitutional Law, and Pre-Medicine indicates a diverse set of interests and a potential knack for analytical thinking, problem-solving, and understanding complex systems. His transition from this diverse academic background into the construction industry could also suggest adaptability and a willingness to take on new challenges.

Grant's recent shift from the Chief Commercial Officer role to the Chief Customer Officer position at XBE might point towards a customer-centric approach in his work ethic. This shift suggests a focus on understanding and meeting customer needs, a crucial aspect of maintaining and expanding business relations.

On the personal side, Grant is a married father of 3 elementary school age kids. He loves tricked out trucks and old war memorabilia passed down from older generations in his family. He likes to lift weights, and cardio but only if its macho. He's funny but doesn't tell jokes. He's an outgoing extrovert that people like to be around, even when he tests limits. He cares!
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

      <div class="flex-grow h-full p-4">
        <div class="flex h-full">
          <div class="flex-1 h-full pr-4">
            <Summary @recording={{this.recording}} class="h-full" />
          </div>
          <div class="flex-1 h-full">
            <div class="flex flex-col space-y-8 h-full">
              <VocabularyFlashCards @recording={{this.recording}} class="flex-none" />

              <AttendeeQuestions @recording={{this.recording}} class="flex-1" />
            </div>
          </div>
          <div class="flex-1 pl-4">
            <div class="flex flex-col space-y-8">
              <Illustrations @recording={{this.recording}} />
            </div>
          </div>
        </div>
      </div>

      <div class="flex-none">
        <div class="bg-[#02AF7C] h-4"></div>
      </div>
    </div>
  </template>
}