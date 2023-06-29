import Model, { belongsTo, attr } from '@ember-data/model';

export default class SentimentEstimateModel extends Model {
  @belongsTo('sentiment-estimator', { async: false })
  estimator;

  @belongsTo('recording-chapter', { async: false })
  chapter;

  @attr('number')
  polarity;

  @attr('number')
  subjectivity;
}
