const test = require('node:test');
const assert = require('node:assert/strict');
const { BrevoEmailSender } = require('../../src/core/infrastructure/notifications/BrevoEmailSender');

test('sends transactional email through Brevo HTTPS', async () => {
  let request;
  const sender = new BrevoEmailSender({
    brevo: {
      apiKey: 'test-api-key',
      fromEmail: 'notifications@example.test',
      fromName: 'HidroSmart QA'
    },
    fetchImpl: async (url, options) => {
      request = { url, options };
      return {
        ok: true,
        status: 201,
        text: async () => JSON.stringify({ messageId: 'message-e2e-1' })
      };
    }
  });

  assert.equal(sender.isConfigured(), true);
  const result = await sender.send({
    recipient: ' user@example.test ',
    subject: 'Verify your HidroSmart account',
    text: 'Verification message',
    html: '<p>Verification message</p>'
  });

  assert.equal(request.url, 'https://api.brevo.com/v3/smtp/email');
  assert.equal(request.options.method, 'POST');
  assert.equal(request.options.headers['api-key'], 'test-api-key');
  assert.deepEqual(JSON.parse(request.options.body), {
    sender: { name: 'HidroSmart QA', email: 'notifications@example.test' },
    to: [{ email: 'user@example.test' }],
    subject: 'Verify your HidroSmart account',
    textContent: 'Verification message',
    htmlContent: '<p>Verification message</p>'
  });
  assert.equal(result.messageId, 'message-e2e-1');
  assert.deepEqual(result.accepted, ['user@example.test']);
  assert.deepEqual(result.rejected, []);
});

test('requires complete Brevo configuration and never falls back to another provider', async () => {
  const sender = new BrevoEmailSender({ brevo: { apiKey: 'test-api-key' } });
  assert.equal(sender.isConfigured(), false);
  await assert.rejects(
    () => sender.send({ recipient: 'user@example.test', subject: 'Test', text: 'Test' }),
    (error) => error.status === 503
  );
});

test('does not expose the Brevo API key when the provider rejects a request', async () => {
  const sender = new BrevoEmailSender({
    brevo: { apiKey: 'private-test-key', fromEmail: 'notifications@example.test' },
    fetchImpl: async () => ({
      ok: false,
      status: 401,
      text: async () => JSON.stringify({ message: 'Invalid API key' })
    })
  });

  await assert.rejects(
    () => sender.send({ recipient: 'user@example.test', subject: 'Test', text: 'Test' }),
    (error) => {
      assert.equal(error.status, 502);
      assert.match(error.message, /HTTP 401/);
      assert.doesNotMatch(error.message, /private-test-key/);
      return true;
    }
  );
});
