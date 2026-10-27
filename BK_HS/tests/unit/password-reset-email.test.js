const test = require('node:test');
const assert = require('node:assert/strict');
const { RequestPasswordReset } = require('../../src/core/application/use-cases/auth/RequestPasswordReset');
const { BrevoEmailSender } = require('../../src/core/infrastructure/notifications/BrevoEmailSender');
const { NotificationService } = require('../../src/core/application/services/notifications/NotificationService');

test('requests a reset only for a valid email address', async () => {
  const calls = [];
  const useCase = new RequestPasswordReset({
    authRepository: {
      createPasswordResetToken: async (input) => {
        calls.push(input);
        return 'reset-id';
      }
    },
    tokenService: {
      generate: () => 'a'.repeat(43),
      hash: () => 'b'.repeat(64),
      expiresAt: () => new Date('2026-01-01T01:00:00.000Z')
    },
    notificationService: {
      isConfigured: () => true,
      sendPasswordReset: async (input) => calls.push(input)
    }
  });

  await useCase.execute({ email: '  Usuario@Ejemplo.com ' });
  assert.equal(calls[0].login, 'usuario@ejemplo.com');
  assert.deepEqual(calls[1], { recipient: 'usuario@ejemplo.com', resetToken: 'a'.repeat(43) });
  await assert.rejects(() => useCase.execute({ email: 'usuario-invalido' }), (error) => error.status === 400);
});

test('keeps a neutral response for nonexistent accounts without sending email', async () => {
  let sent = false;
  const useCase = new RequestPasswordReset({
    authRepository: { createPasswordResetToken: async () => null },
    tokenService: { generate: () => 'a'.repeat(43), hash: () => 'b'.repeat(64), expiresAt: () => new Date() },
    notificationService: { isConfigured: () => true, sendPasswordReset: async () => { sent = true; } }
  });

  const result = await useCase.execute({ email: 'noexiste@ejemplo.com' });
  assert.ok(result.resetExpiresAt);
  assert.equal(sent, false);
});

test('sends reset email through Brevo with a frontend login link', async () => {
  const requests = [];
  const sender = new BrevoEmailSender({
    brevo: { apiKey: 'test-api-key', fromEmail: 'no-reply@example.com', fromName: 'HidroSmart' },
    fetchImpl: async (url, options) => {
      requests.push({ url, options });
      return { ok: true, status: 201, text: async () => JSON.stringify({ messageId: 'test-message' }) };
    }
  });

  const notifications = new NotificationService({
    sender,
    frontendUrl: 'http://localhost:5173',
    passwordResetUrl: 'http://localhost:5173/?from=email'
  });
  await notifications.sendPasswordReset({ recipient: 'usuario@ejemplo.com', resetToken: 'token_seguro' });

  const payload = JSON.parse(requests[0].options.body);
  const link = payload.textContent.match(/https?:\/\/[^\s]+/)[0];
  const resetUrl = new URL(link);
  assert.equal(requests[0].url, 'https://api.brevo.com/v3/smtp/email');
  assert.equal(payload.to[0].email, 'usuario@ejemplo.com');
  assert.equal(resetUrl.pathname, '/login');
  assert.equal(resetUrl.searchParams.get('resetToken'), 'token_seguro');
});

test('sends verification email through Brevo with the verification link', async () => {
  const requests = [];
  const sender = new BrevoEmailSender({
    brevo: { apiKey: 'test-api-key', fromEmail: 'no-reply@example.com' },
    fetchImpl: async (url, options) => {
      requests.push({ url, options });
      return { ok: true, status: 201, text: async () => JSON.stringify({ messageId: 'test-message' }) };
    }
  });
  const notifications = new NotificationService({
    sender,
    frontendUrl: 'https://pt-hs.pages.dev',
    passwordResetUrl: 'https://pt-hs.pages.dev/login'
  });

  await notifications.sendEmailVerification({ recipient: 'usuario@ejemplo.com', token: 'verify-token' });

  const payload = JSON.parse(requests[0].options.body);
  const link = payload.textContent.match(/https?:\/\/[^\s]+/)[0];
  const verificationUrl = new URL(link);
  assert.equal(requests[0].url, 'https://api.brevo.com/v3/smtp/email');
  assert.equal(payload.to[0].email, 'usuario@ejemplo.com');
  assert.equal(verificationUrl.pathname, '/verify-email');
  assert.equal(verificationUrl.searchParams.get('token'), 'verify-token');
});
