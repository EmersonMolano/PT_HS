# Correos de verificación y recuperación

El backend envía ambos correos con la API transaccional HTTPS de Brevo.
Configura estas variables en el entorno del backend:

| Variable | Valor |
| --- | --- |
| `BREVO_API_KEY` | API key v3 de Brevo; no es la clave SMTP |
| `BREVO_FROM_EMAIL` | Dirección registrada y verificada como remitente en Brevo |
| `BREVO_FROM_NAME` | `HidroSmart` |
| `FRONTEND_URL` | `https://pt-hs.pages.dev` |
| `PASSWORD_RESET_URL` | `https://pt-hs.pages.dev/login` |

Después de configurar las variables, reinicia el servicio backend para que las
cargue. El servidor registra cuáles variables de Brevo faltan. Cada solicitud
aceptada incluye un `messageId` en los logs; si Brevo rechaza el envío, el log
incluye el código HTTP. El mensaje aceptado debe revisarse en los registros de
transacciones de Brevo para confirmar que fue entregado y que no rebotó.

El registro y la recuperación mantienen respuestas públicas neutrales para no
revelar si una dirección tiene cuenta. Si no llegan correos, revisa los logs
del backend y busca el `messageId` en Brevo. Un remitente no verificado, una API
key inválida o límites de la cuenta son rechazos del proveedor y no se corrigen
desde el frontend.
