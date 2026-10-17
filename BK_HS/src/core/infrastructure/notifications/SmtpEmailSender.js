const nodemailer = require('nodemailer');

class SmtpEmailSender {
  constructor({
    smtp,
    resend = {},
    transportFactory = nodemailer.createTransport,
    fetchImpl = globalThis.fetch
  }) {
    this.smtp = smtp;
    this.resend = resend;
    this.fetchImpl = fetchImpl;

    if (this.resend.apiKey) {
      this.transporter = null;
    } else {
      const transportOptions = {
        host: smtp.host,
        port: smtp.port,
        secure: smtp.secure
      };

      if (smtp.user || smtp.password) {
        transportOptions.auth = { user: smtp.user, pass: smtp.password };
      }

      this.transporter = transportFactory(transportOptions);
    }
  }

  isConfigured() {
    if (this.resend.apiKey) return Boolean(this.resend.from);

    const hasPartialAuth = Boolean(this.smtp.user) !== Boolean(this.smtp.password);
    return Boolean(this.smtp.host && this.smtp.port && this.smtp.from && !hasPartialAuth);
  }

  async verifyConfiguration() {
    if (!this.isConfigured()) return false;
    if (this.resend.apiKey) return true;

    await this.transporter.verify();
    return true;
  }

  async send({ recipient, subject, text, html }) {
    if (!this.isConfigured()) {
      const error = new Error('SMTP no está configurado para enviar correos');
      error.status = 503;
      throw error;
    }
    if (typeof recipient !== 'string' || !recipient.trim()) {
      const error = new Error('El destinatario es obligatorio');
      error.status = 400;
      throw error;
    }

    if (this.resend.apiKey) {
      return this.sendWithResend({ recipient, subject, text, html });
    }

    const result = await this.transporter.sendMail({ from: this.smtp.from, to: recipient.trim(), subject, text, html });
    return { messageId: result.messageId, accepted: result.accepted, rejected: result.rejected };
  }

  async sendWithResend({ recipient, subject, text, html }) {
    if (typeof this.fetchImpl !== 'function') {
      throw new Error('Este runtime no tiene soporte para fetch HTTPS');
    }

    const normalizedRecipient = recipient.trim();
    const response = await this.fetchImpl('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${this.resend.apiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        from: this.resend.from,
        to: [normalizedRecipient],
        subject,
        text,
        html
      }),
      signal: AbortSignal.timeout(15000)
    });

    const responseBody = await response.text();
    let result = {};

    try {
      result = responseBody ? JSON.parse(responseBody) : {};
    } catch {
      // Si Resend devolvio un cuerpo no JSON, se informa el estado HTTP sin filtrarlo.
    }

    if (!response.ok) {
      const error = new Error(
        `Resend rechazo el envio (HTTP ${response.status}): ${
          result.message || result.name || 'Error de envio'
        }`
      );
      error.status = 502;
      throw error;
    }

    return {
      messageId: result.id,
      accepted: [normalizedRecipient],
      rejected: []
    };
  }
}

module.exports = { SmtpEmailSender };
