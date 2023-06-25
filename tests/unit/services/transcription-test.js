import { module, test } from 'qunit';
import { setupTest } from 'aittendee/tests/helpers';

module('Unit | Service | transcription', function (hooks) {
  setupTest(hooks);

  // TODO: Replace this with your real tests.
  test('it exists', function (assert) {
    let service = this.owner.lookup('service:transcription');
    assert.ok(service);
  });
});
