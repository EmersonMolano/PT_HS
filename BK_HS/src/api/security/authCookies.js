const { randomBytes, timingSafeEqual } = require('crypto');

function parseCookieHeader(header = '') {
  return String(header)
    .split(';')
    .reduce((cookies, entry) => {
      const separator = entry.indexOf('=');
      if (separator < 1) return cookies;
      const name = entry.slice(0, separator).trim();
      const rawValue = entry.slice(separator + 1).trim();
      try {
        cookies[name] = decodeURIComponent(rawValue);
      } catch {
        // Una cookie malformada no debe invalidar la peticion completa.
      }
      return cookies;
    }, {});
}

function getCookie(req, name) {
  return parseCookieHeader(req.headers?.cookie)[name] || null;
}

function cookieOptions(config, { httpOnly, maxAge } = {}) {
  return {
    httpOnly,
    secure: config.secure,
    sameSite: config.sameSite,
    path: '/',
    ...(config.domain ? { domain: config.domain } : {}),
    ...(maxAge ? { maxAge } : {})
  };
}

function setCsrfCookie(res, csrfToken, config) {
  res.cookie(
    config.csrfTokenName,
    csrfToken,
    cookieOptions(config, { httpOnly: false, maxAge: config.refreshMaxAgeMs })
  );
  res.set(config.csrfHeaderName, csrfToken);
}

function getOrCreateCsrfToken(req, res, config) {
  const csrfToken = getCookie(req, config.csrfTokenName) || randomBytes(32).toString('base64url');
  setCsrfCookie(res, csrfToken, config);
  return csrfToken;
}

function setSessionCookies(res, session, config, existingCsrfToken) {
  const csrfToken = existingCsrfToken || randomBytes(32).toString('base64url');
  res.cookie(config.accessTokenName, session.accessToken, cookieOptions(config, { httpOnly: true }));
  res.cookie(
    config.refreshTokenName,
    session.refreshToken,
    cookieOptions(config, { httpOnly: true, maxAge: config.refreshMaxAgeMs })
  );
  setCsrfCookie(res, csrfToken, config);
}

function clearSessionCookies(res, config) {
  const expiration = { ...cookieOptions(config, { httpOnly: true }), maxAge: 0 };
  res.clearCookie(config.accessTokenName, expiration);
  res.clearCookie(config.refreshTokenName, expiration);
  res.clearCookie(config.csrfTokenName, { ...cookieOptions(config, { httpOnly: false }), maxAge: 0 });
}

function tokensEqual(left, right) {
  if (typeof left !== 'string' || typeof right !== 'string') return false;
  const leftBuffer = Buffer.from(left);
  const rightBuffer = Buffer.from(right);
  return leftBuffer.length === rightBuffer.length && timingSafeEqual(leftBuffer, rightBuffer);
}

function createCsrfProtection(config) {
  return (req, _res, next) => {
    if (!['POST', 'PUT', 'PATCH', 'DELETE'].includes(req.method)) return next();

    const requestPath = String(req.originalUrl || req.path || '').split('?')[0];
    const isLoginRequest = req.method === 'POST' && requestPath.endsWith('/auth/login');
    const hasSessionCookie = Boolean(
      getCookie(req, config.accessTokenName) || getCookie(req, config.refreshTokenName)
    );
    const hasCsrfCookie = Boolean(getCookie(req, config.csrfTokenName));
    // Los clientes que autentican con Authorization Bearer no son vulnerables a
    // CSRF porque el navegador no agrega ese header automaticamente.
    if (!hasSessionCookie && !hasCsrfCookie && !isLoginRequest) return next();

    const expected = getCookie(req, config.csrfTokenName);
    const received = req.get(config.csrfHeaderName);
    if (!tokensEqual(expected, received)) {
      const error = new Error('Token CSRF invalido o ausente');
      error.status = 403;
      return next(error);
    }
    return next();
  };
}

module.exports = {
  clearSessionCookies,
  createCsrfProtection,
  getCookie,
  getOrCreateCsrfToken,
  parseCookieHeader,
  setSessionCookies
};
