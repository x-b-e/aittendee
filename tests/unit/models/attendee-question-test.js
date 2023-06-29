import { module, test } from 'qunit';

import { setupTest } from 'aittendee/tests/helpers';

module('Unit | Model | attendee question', function (hooks) {
  setupTest(hooks);

  // Replace this with your real tests.
  test('it exists', function (assert) {
    let store = this.owner.lookup('service:store');
    let model = store.createRecord('attendee-question', {});
    assert.ok(model);
  });
});
