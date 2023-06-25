import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import didInsert from '@ember/render-modifiers/modifiers/did-insert';
import didUpdate from '@ember/render-modifiers/modifiers/did-update';
import { action } from '@ember/object';
import showdown from 'showdown/dist/showdown';

export default class MarkdownComponent extends Component {
  @tracked
  html;

  @action
  setHtml() {
    const converter = new showdown.Converter();
    let html = converter.makeHtml(this.args.markdown);
    if (this.args.stripImages) {
      html = html.replace(/<img[^>]*>/g, '<p class="italic">Image present in original document</p>');
    }
    this.html = html;
  }

  <template>
    <div
      {{didInsert this.setHtml}}
      {{didUpdate this.setHtml @markdown}}
      ...attributes
    >
      {{{this.html}}}
    </div>
  </template>
}