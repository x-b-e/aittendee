class AudioProcessor extends AudioWorkletProcessor {
  constructor(options = {}) {
    super();
    this.buffer = [];
    this.bufferSize = options.processorOptions.sampleRate * 3; // 3 seconds of audio
  }

  process(inputs) {
    const input = inputs[0];
    if (input.length === 2) {
      this.buffer.push(...input[0]);

      if (this.buffer.length > this.bufferSize) {
        const segment = this.buffer.slice(0, this.bufferSize);
        this.buffer = this.buffer.slice(this.bufferSize);
        this.port.postMessage(segment);
      }
      return true;
    } else {
      return false;
    }
  }
}

registerProcessor('audio-processor', AudioProcessor);
