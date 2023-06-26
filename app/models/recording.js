import Model, { hasMany, attr } from '@ember-data/model';
import { action } from '@ember/object';
import Evented from '@ember/object/evented';
import { tracked } from '@glimmer/tracking';

export default class RecordingModel extends Model {
  constructor() {
    super(...arguments);
    Evented.apply(this);
  }

  chunksPerIllustration = 6;

  @tracked
  lastChunkIllustrated = null;

  chunksPerChapter = 6;

  @hasMany('recording-chunk', { async: false })
  chunks;

  @hasMany('vocabulary-extractor', { async: false })
  vocabularyExtractors;

  @hasMany('illustrator', { async: false })
  illustrators;

  @hasMany('marketer', { async: false })
  marketers;

  @hasMany('recording-chapter', { async: false })
  chapters;

  @hasMany('recording-summary', { async: false })
  summaries;

  @attr('string')
  audience;

  get sortedSummaries() {
    return this.summaries
      .toArray()
      .sort((a, b) => a.createdAt - b.createdAt)
      .filter((s) => s.summary);
  }

  get lastSummary() {
    return this.sortedSummaries[this.sortedSummaries.length - 1];
  }

  get transcribedChunks() {
    return this.chunks.filter((chunk) => {
      return chunk.wordCount;
    });
  }

  get wordCount() {
    return this.transcribedChunks.reduce((sum, chunk) => {
      return sum + chunk.wordCount;
    }, 0);
  }

  get durationSeconds() {
    return this.transcribedChunks.reduce((sum, chunk) => {
      return sum + chunk.durationSeconds;
    }, 0);
  }

  get wordsPerMinute() {
    const { wordCount, durationSeconds } = this;
    if (!wordCount || !durationSeconds) return null;
    if (durationSeconds === 0) return null;

    return Math.round((wordCount / durationSeconds) * 60);
  }

  get sortedChapters() {
    return this.chapters.toArray().sort((a, b) => {
      return a.number - b.number;
    });
  }

  get cost() {
    let costs = [];
    for (let illustrator of this.illustrators.toArray()) {
      costs.push(illustrator.cost);
      for (let illustration of illustrator.illustrations.toArray()) {
        costs.push(illustration.cost);
      }
    }
    for (let chunk of this.chunks.toArray()) {
      costs.push(chunk.cost);
    }
    for (let chapter of this.chapters.toArray()) {
      costs.push(chapter.cost);
    }
    for (let summary of this.summaries.toArray()) {
      costs.push(summary.cost);
    }
    for (let extractor of this.vocabularyExtractors.toArray()) {
      costs.push(extractor.cost);
      for (let term of extractor.terms.toArray()) {
        costs.push(term.cost);
      }
    }
    for (let marketer of this.marketers.toArray()) {
      costs.push(marketer.cost);
    }
    return costs.reduce((sum, cost) => sum + cost, 0);
  }

  get costPerHour() {
    const { cost, durationSeconds } = this;
    if (!cost || !durationSeconds) return null;
    if (durationSeconds === 0) return null;

    return Math.round((cost / durationSeconds) * 60 * 60);
  }

  @action
  createChunk({ blob }) {
    const chunk = this.store.createRecord('recording-chunk', {
      recording: this,
      blob,
      createdAt: new Date(),
    });
    chunk.on('transcribed', this, this.didTranscribeChunk);
  }

  @action
  createChapter() {
    const chapterCount = this.chapters.length;
    const chapter = this.store.createRecord('recording-chapter', {
      recording: this,
      number: chapterCount + 1,
    });
    chapter.on('summarized', this.didSummarizeChapter);
    return chapter;
  }

  @action
  didTranscribeChunk(chunk) {
    for (let extractor of this.vocabularyExtractors) {
      extractor.extractTermsTask.perform(chunk);
    }
    this.createIllustrator();
    this.updateChapters(chunk);
  }

  @action
  didSummarizeChapter(chapter) {
    this.createSummary();
    this.createPullQuotes(chapter);
  }

  @action
  createSummary() {
    const summary = this.store.createRecord('recording-summary', {
      createdAt: new Date(),
      recording: this,
    });
    summary.summarizeTask.perform();
  }

  createMarketer() {
    this.store.createRecord('marketer', {
      recording: this,
    });
  }

  @action
  createPullQuotes(chapter) {
    for (let marketer of this.marketers) {
      marketer.createPullQuoteTask.perform(chapter);
    }
  }

  @action
  updateChapters(chunk) {
    const { chunksPerChapter, sortedChapters } = this;

    let lastChapter = sortedChapters[sortedChapters.length - 1];
    if (!lastChapter) {
      lastChapter = this.createChapter();
    }

    const lastChapterChunkCount = lastChapter.chunks.length;
    if (lastChapterChunkCount >= chunksPerChapter) {
      lastChapter = this.createChapter();
    }

    chunk.chapter = lastChapter;

    if (lastChapter.chunks.length >= chunksPerChapter) {
      lastChapter.summarizeTask.perform();
    }
  }

  @action
  createIllustrator() {
    const transcribedChunks = this.chunks.filter((chunk) => {
      return chunk.transcript;
    });

    const { lastChunkIllustrated, chunksPerIllustration } = this;
    const transcribedChunksCount = transcribedChunks.length;
    const transcribedChunksNotIllustratedCount = Math.max(
      0,
      transcribedChunksCount - (this.lastChunkIllustrated || 0) + 1
    );
    if (transcribedChunksNotIllustratedCount >= this.chunksPerIllustration) {
      const chunksToIllustrate = transcribedChunks.slice(
        lastChunkIllustrated || 0,
        (lastChunkIllustrated || 0) + chunksPerIllustration
      );
      const transcript = chunksToIllustrate
        .map((chunk) => {
          return chunk.transcript;
        })
        .join(' ');

      const illustrator = this.store.createRecord('illustrator', {
        recording: this,
        style: 'Sumi-e.',
        transcript,
      });

      illustrator.illustrateTask.perform();
      this.lastChunkIllustrated =
        (lastChunkIllustrated || 0) + chunksPerIllustration - 1;
    }
  }
}
