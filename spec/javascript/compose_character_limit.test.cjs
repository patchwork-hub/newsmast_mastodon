const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { test } = require('node:test');
const vm = require('node:vm');

const root = path.resolve(__dirname, '../../app/javascript/newsmast_mastodon/mastodon/features/compose');
const component = fs.readFileSync(path.join(root, 'components/compose_form.jsx'), 'utf8');
const container = fs.readFileSync(path.join(root, 'containers/compose_form_container.js'), 'utf8');

test('the composer reads updated character limits from the server item', () => {
  const expression = container.match(/maxChars: (.+),/)[1];
  const state = {
    server: { server: { item: { configuration: { statuses: { max_characters: 700 } } } } },
    getIn(keys, fallback) {
      return keys.reduce((value, key) => value?.[key], this) ?? fallback;
    },
  };

  assert.equal(vm.runInNewContext(expression, { state }), 700);
  state.server.server.item.configuration.statuses.max_characters = 900;
  assert.equal(vm.runInNewContext(expression, { state }), 900);
  state.server.server.item = undefined;
  assert.equal(vm.runInNewContext(expression, { state }), 500);
});

test('the connected refresh callback dispatches a new instance fetch', () => {
  const callback = container.match(/refreshInstanceConfiguration: \(\) => \{([\s\S]*?)\n  \}/)[1];
  const action = { type: 'server/fetch' };
  let dispatched;

  vm.runInNewContext(callback, {
    fetchServer: () => action,
    dispatch: value => { dispatched = value; },
  });

  assert.equal(dispatched, action);
});

test('the composer refreshes while visible and cleans up on unmount', () => {
  const methods = ['componentDidMount', 'componentWillUnmount', 'refreshInstanceConfiguration'].map(name => {
    const match = component.match(new RegExp(`  ${name}(?: \\(\\)| = \\(\\) =>) \\{[\\s\\S]*?\\n  \\};?`));
    assert.ok(match, `Missing ${name}`);
    return match[0];
  }).join('\n');
  let refreshes = 0;
  let tick;
  let listener;
  let cleared;
  const document = {
    visibilityState: 'visible',
    addEventListener(event, callback) {
      assert.equal(event, 'visibilitychange');
      listener = callback;
    },
    removeEventListener(event, callback) {
      assert.equal(event, 'visibilitychange');
      assert.equal(callback, listener);
      listener = undefined;
    },
  };
  const Composer = vm.runInNewContext(`(class { ${methods} })`, {
    document,
    setInterval(callback, delay) {
      assert.equal(delay, 60_000);
      tick = callback;
      return 42;
    },
    clearInterval: id => { cleared = id; },
    clearTimeout: () => {},
  });
  const composer = new Composer();
  composer._updateFocusAndSelection = () => {};
  composer.props = {
    fetchLocalOnlySetting: () => {},
    refreshInstanceConfiguration: () => { refreshes++; },
  };

  composer.componentDidMount();
  assert.equal(refreshes, 1);
  tick();
  assert.equal(refreshes, 2);
  document.visibilityState = 'hidden';
  tick();
  listener();
  assert.equal(refreshes, 2);
  document.visibilityState = 'visible';
  listener();
  assert.equal(refreshes, 3);
  composer.componentWillUnmount();
  assert.equal(cleared, 42);
  assert.equal(listener, undefined);
});
