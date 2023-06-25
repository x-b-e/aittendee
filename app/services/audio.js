import Service from '@ember/service';

export default class AudioService extends Service {
  mediaRecorder = null;

  defaultOptions = {
    timeslice: 10 * 1000,
    onDataAvailable: () => {
      console.log('No onDataAvailable callback provided');
    },
  };

  startRecording({ timeslice, onDataAvailable }) {
    timeslice = timeslice || this.defaultOptions.timeslice;

    onDataAvailable = onDataAvailable || this.defaultOptions.onDataAvailable;

    navigator.mediaDevices
      .getUserMedia({ audio: true })
      .then((stream) => {
        this.mediaRecorder = new MediaRecorder(stream);

        this.mediaRecorder.ondataavailable = (e) => {
          onDataAvailable(e.data);
        };

        this.mediaRecorder.start();

        this.recordingInterval = setInterval(() => {
          this.mediaRecorder.stop();
          this.mediaRecorder.start();
        }, timeslice);
      })
      .catch((err) => {
        console.error('The following getUserMedia error occured: ', err);
      });
  }

  stopRecording() {
    if (this.mediaRecorder) {
      clearInterval(this.recordingInterval);
      this.mediaRecorder.stop();
      this.mediaRecorder = null;
    }
  }
}
