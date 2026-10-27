class BrevoEmailSender {
  constructor({ brevo = {}, fetchImpl = globalThis.fetch } = {}) {
    this.brevo = brevo;
    this.fetchImpl = fetchImpl;
  }

  isConfigured() {
    return Boolean(this.brevo.apiKey && this.brevo.fromEmail);
  }

  async verifyConfiguration() {
    return this.isConfigured();
  }

  async send({ recipient, subject, text, html }) {
    if (!this.isConfigured()) {
      const error = new Error('Brevo no está configurado correctamente');
      error.status = 503;
      throw error;
    }
    if (typeof recipient !== 'string' || !recipient.trim()) {
      const error = new Error('El destinatario es obligatorio');
      error.status = 400;
      throw error;
    }
    if (typeof this.fetchImpl !== 'function') {
      const error = new Error('Este runtime no tiene soporte para fetch HTTPS');
      error.status = 503;
      throw error;
    }

    const normalizedRecipient = recipient.trim();
    const response = await this.fetchImpl('https://api.brevo.com/v3/smtp/email', {
      method: 'POST',
      headers: {
        'api-key': this.brevo.apiKey,
        'Content-Type': 'application/json',
        Accept: 'application/json'
      },
      body: JSON.stringify({
        sender: {
          name: this.brevo.fromName || 'HidroSmart',
          email: this.brevo.fromEmail
        },
        to: [{ email: normalizedRecipient }],
        subject,
        textContent: text,
        htmlContent: html
      }),
      signal: AbortSignal.timeout(15000)
    });

    const responseBody = await response.text();
    let result = {};
    try {
      result = responseBody ? JSON.parse(responseBody) : {};
    } catch {
      // No propagamos cuerpos de respuesta no validados.
    }

    if (!response.ok) {
      const error = new Error(
        `Brevo rechazó el envío (HTTP ${response.status}): ${result.message || 'Error de envío'}`
      );
      error.status = 502;
      throw error;
    }

    return {
      messageId: result.messageId,
      accepted: [normalizedRecipient],
      rejected: []
    };
  }
}

module.exports = { BrevoEmailSender };
