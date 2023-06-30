import Model, { attr, belongsTo } from '@ember-data/model';
import { task } from 'ember-concurrency';
import fetch from 'fetch';
import ENV from 'aittendee/config/environment';

const COST_PER_IMAGE = 0.02;

function b64toBlob(b64Data, contentType = '', sliceSize = 512) {
  const byteCharacters = atob(b64Data);
  const byteArrays = [];

  for (let offset = 0; offset < byteCharacters.length; offset += sliceSize) {
    const slice = byteCharacters.slice(offset, offset + sliceSize);

    const byteNumbers = new Array(slice.length);
    for (let i = 0; i < slice.length; i++) {
      byteNumbers[i] = slice.charCodeAt(i);
    }

    const byteArray = new Uint8Array(byteNumbers);
    byteArrays.push(byteArray);
  }

  const blob = new Blob(byteArrays, { type: contentType });
  return blob;
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

export default class IllustratorIllustrationModel extends Model {
  @attr('date')
  createdAt;

  @belongsTo('illustrator', { async: false })
  illustrator;

  @attr('string')
  name;

  @attr('string')
  prompt;

  @attr('string')
  reasoning;

  @attr('string')
  base64;

  @attr('number')
  lightestRowPct;

  @task
  *setLightestRowPctTask() {
    const { url } = this;
    if (!url) return;

    const lightestRowPct = yield getLightestRow(url, 50);

    this.lightestRowPct = lightestRowPct;
  }

  get base64Data() {
    const { base64 } = this;
    if (!base64) return null;

    return base64.replace(/^data:image\/(png|jpeg);base64,/, '');
  }

  get blob() {
    const { base64Data } = this;
    if (!base64Data) return null;

    return b64toBlob(base64Data, 'image/png');
  }

  get url() {
    const { blob } = this;
    if (!blob) return null;

    return URL.createObjectURL(blob);
  }

  @attr('number', { defaultValue: 0 })
  cost;

  @task
  *createImageTask() {
    const { prompt } = this;

    const data = {
      prompt,
      response_format: 'b64_json',
    };

    let response = yield fetch('https://api.openai.com/v1/images/generations', {
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
      const json = yield response.json();
      this.cost += COST_PER_IMAGE;
      this.base64 = json['data'][0]['b64_json'];
      this.setLightestRowPctTask.perform();
    }
  }
}
