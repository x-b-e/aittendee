import { module, test } from 'qunit';

import { setupTest } from 'aittendee/tests/helpers';

module('Unit | Model | recording summary', function (hooks) {
  setupTest(hooks);

  // Replace this with your real tests.
  test('it exists', function (assert) {
    let store = this.owner.lookup('service:store');
    let model = store.createRecord('recording-summary', {});
    assert.ok(model);
  });
});
