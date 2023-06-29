import Model, { belongsTo, attr } from '@ember-data/model';

export default class MarketerPullQuoteModel extends Model {
  @attr('date')
  createdAt;

  @belongsTo('marketer', { async: false })
  marketer;

  @attr('string')
  quote;

  @attr('number')
  score;
}
