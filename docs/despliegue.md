# Despliegue y operación

## Arquitectura de ambientes

| Capa | Servicio previsto | Configuración principal |
|---|---|---|
| Web | Cloudflare Pages | Compilar `FT_HS/Web`; salida `dist`; `VITE_API_URL` apunta a la API HTTPS. |
| API | Render | Ejecutar `BK_HS`; configurar CORS con el origen exacto de Pages. |
| PostgreSQL | Neon | `DATABASE_URL` para el pool principal y `DB_INGEST_DATABASE_URL` cuando se separe el usuario de ingesta. Requerir TLS del proveedor. |
| MQTT | Flespi | `mqtts://mqtt.flespi.io:8883`; token ACL como usuario MQTT; contraseña vacía. |
| Correo | Brevo | `BREVO_API_KEY`, remitente verificado y nombre de remitente. |

Esta tabla describe la arquitectura objetivo de PT_HS. No sustituye la comprobación del commit ni de las variables guardadas en cada proveedor.

## Variables

Los nombres de las variables se documentan; sus valores secretos se cargan desde el administrador de secretos del proveedor y nunca se guardan en Git.

### Render (backend)

- `NODE_ENV=production`, `PORT`, `CORS_ORIGIN`, `FRONTEND_URL` y `PASSWORD_RESET_URL`.
- `DATABASE_URL` o `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`.
- `DB_INGEST_DATABASE_URL` o `DB_INGEST_USER`, `DB_INGEST_PASSWORD` y `DB_INGEST_POOL_MAX`.
- `JWT_SECRET`, `JWT_EXPIRES_IN`, `JWT_REFRESH_EXPIRES_IN`, `JWT_ISSUER` y `JWT_AUDIENCE`.
- `BREVO_API_KEY`, `BREVO_FROM_EMAIL` y `BREVO_FROM_NAME`.
- `MQTT_BROKER_URL`, `MQTT_CLIENT_ID`, `MQTT_USERNAME`, `MQTT_PASSWORD` y `MQTT_QOS`.

Para el sitio actual, incluye `https://pt-hs.pages.dev` en `CORS_ORIGIN` y úsalo como `FRONTEND_URL`. Configura `PASSWORD_RESET_URL=https://pt-hs.pages.dev/login` para que los enlaces de recuperación vuelvan a la web publicada. `CORS_ORIGIN` acepta una lista separada por comas si se permiten otros orígenes.

Para Flespi usa una URL TLS y un token ACL con permisos mínimos. El token del backend debe poder suscribirse a telemetría/estado de dispositivos y publicar únicamente configuración/comandos autorizados. Cada ESP32 debe tener su propio token ACL, limitado a publicar los topics de su dispositivo. No reutilices el token maestro ni el del backend en el firmware.

### Cloudflare Pages (web)

- Root directory: `FT_HS/Web` si se conecta el repositorio PT_HS.
- Build command: `npm run build`.
- Build output: `dist`.
- Node.js: `22`.
- `VITE_API_URL=https://pt-hs.onrender.com/api/v1` para producción. Usa la URL HTTPS de la API del ambiente correspondiente en previews.

Define `VITE_API_URL` tanto en Production como en Preview. El `vite.config.js` detiene el build de producción si falta esta variable y exige HTTPS en Cloudflare Pages; así evita generar un bundle que intente llamar a `localhost` o a una API insegura.

`VITE_*` se incorpora al bundle del navegador: nunca pongas tokens, contraseñas ni claves privadas en estas variables.

Cloudflare Pages sirve las rutas de una SPA desde `index.html` si no se publica un `404.html` de nivel superior. Mantén la salida de Vite sin un `404.html` estático para que `/login` y las demás rutas del frontend abran directamente.

## Promoción

1. Seleccionar el commit y la rama que aprobaron la revisión y CI.
2. Verificar que la migración Liquibase esté incluida y que el backup de la base esté vigente.
3. Aplicar migraciones en el ambiente destino con credenciales de despliegue restringidas.
4. Desplegar backend y verificar `/health` y logs de arranque.
5. Desplegar Pages y comprobar login, hogar, consumo, alertas y correo en el ambiente.
6. Con credenciales MQTT seguras, confirmar conexión TLS y suscripción del backend sin publicar datos de prueba en topics productivos.

## Desarrollo local

Desde la raíz de PT_HS, copia `.env.example` a `.env`, reemplaza los valores de ejemplo y no compartas ese archivo:

```powershell
Copy-Item .env.example .env
docker compose --env-file .env up -d postgres db-bootstrap mosquitto
docker compose --env-file .env --profile tooling run --rm liquibase validate
docker compose --env-file .env --profile tooling run --rm liquibase update
docker compose --env-file .env up -d --build backend frontend
```

Comprueba `http://localhost:3000/health` y `http://localhost:5173/health`. Mosquitto anónimo sin TLS se limita al desarrollo local y no debe exponerse a Internet ni a una red compartida.

## Reversión

Si una promoción falla, detén la promoción posterior, conserva logs y el identificador del commit, revierte la aplicación al último artefacto estable y usa el rollback Liquibase solo después de evaluar compatibilidad/datos. No restaures una base sobre producción sin aprobación operativa y backup verificado.
