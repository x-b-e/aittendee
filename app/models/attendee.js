import Model, { attr, hasMany, belongsTo } from '@ember-data/model';
import { task } from 'ember-concurrency';
import ENV from 'aittendee/config/environment';
import calculateChatCost from 'aittendee/utilities/calculate-chat-cost';

function buildSystemMessage(attendee) {
  const { name, profile, questions } = attendee;
  return {
    role: 'system',
    content: `
You are an attendee at a conference. Your name is ${name}.

The audience of the event is:

${attendee.recording.audience}

Here is your profile:

${profile}

Previously, you've asked the following questions:
${questions.map((q) => '- ' + q.question).join('\n')}

You are asking a question of the speaker. The question should be smart, brief, relevant to the speech, interesting to the audience, and make a lot of sense in the context of your profile (such as referencing your experience, responsibilities, or interests and in a voice that makes sense based on your profile). State your name and your role in the question.

You should not repeat a question that you've already asked.
    `.trim(),
  };
}

function buildUserMessage({ summary }) {
  return {
    role: 'user',
    content: `
Here's a summary of the speech that you're asking a question about:

"""
${summary}
"""

Ask the best possible question that you can think of!
    `.trim(),
  };
}

export default class AttendeeModel extends Model {
  @belongsTo('recording', { async: false })
  recording;

  @attr('string')
  name;

  @attr('string', { defaultValue: 'en-US-Neural2-J' })
  voiceName;

  @attr('string')
  profile;

  @hasMany('attendee-question', { async: false })
  questions;

  @attr('number', { defaultValue: 0 })
  cost;

  @task
  *askQuestionTask(summary) {
    const messages = [];
    const systemMessage = buildSystemMessage(this);
    const userMessage = buildUserMessage(summary);

    messages.push(systemMessage);
    messages.push(userMessage);

    const data = {
      model: 'gpt-4',
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
        let json;
        try {
          json = yield response.json();
          this.cost += calculateChatCost(json);
          const questionContent = json['choices'][0]['message']['content'];
          const question = this.store.createRecord('attendee-question', {
            attendee: this,
            question: questionContent,
          });
          question.generateAudioTask.perform();
          break;
        } catch (e) {
          console.error(e);
          tries--;
        }
      }
    }
  }
}
