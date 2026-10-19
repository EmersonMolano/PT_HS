# Seguridad

## Controles implementados

- Las sesiones web usan cookies de acceso y renovación `HttpOnly`; los JWT no
  se entregan al código de la interfaz ni se guardan en `sessionStorage`.
- Las solicitudes mutables autenticadas por cookie exigen el encabezado
  `X-CSRF-Token`, contrastado con la cookie CSRF de doble envío.
- CORS permite orígenes configurados y credenciales; `TRUST_PROXY_HOPS` es
  explícito.
- El backend usa Helmet, límite de peticiones de autenticación y validación de
  payloads.
- PostgreSQL usa roles técnicos separados, funciones controladas y RLS.
- `.env`, `config.h`, respaldos y archivos de contraseña están ignorados por
  Git. Solo deben contenerse en equipos y secretos autorizados.

## Límites del entorno local

El broker Mosquitto de `docker-compose.yml` es para desarrollo: no tiene TLS ni
autenticación por dispositivo. La pila local no debe publicarse directamente a
Internet. Antes de una publicación real se requiere una infraestructura con
HTTPS, DNS, certificados, firewall, MQTT autenticado, ACL por topic y TLS.

## Validación pendiente para Cloudflare Pages y Render

El cliente obtiene el token con `GET /api/v1/auth/csrf`. Si recibe `403` con
código `CSRF_INVALID`, renueva el token y reintenta una sola vez. Los demás
errores `403` no se reintentan.

`pt-hs.pages.dev` y `pt-hs.onrender.com` son sitios distintos. Aunque las
cookies usen `Secure; SameSite=None` y CORS permita credenciales, el navegador
puede bloquearlas como cookies de terceros. Las pruebas HTTP desde Node no
detectan esa restricción. Antes del despliegue definitivo, probar en un
navegador real login, refresh y logout, inspeccionando `Set-Cookie` y CSRF. Si
se bloquean las cookies, usar un proxy API bajo el mismo sitio del frontend o
dominios propios bajo un mismo sitio; no desactivar CSRF.

## Dependencias

El backend debe revisarse con:

```powershell
npm.cmd --prefix BK_HS audit --omit=dev
npm.cmd --prefix FT_HS/frontend audit --omit=dev
```

En la revisión del 18 de octubre de 2026 el backend reportó 0 hallazgos y el
frontend 15 altos, concentrados en la cadena Expo/Metro/React Native. Un
hallazgo de `npm audit` no demuestra por sí solo exposición en la web, pero
requiere evaluación y seguimiento. El frontend debe actualizarse de forma
controlada. No ejecutes `npm audit fix --force`: puede forzar saltos mayores de
Expo y React Native incompatibles con la decisión de mantener SDK 57.
Después de una actualización, ejecuta lint, typecheck, build, pruebas de
backend y una compilación Android.

## Reglas prácticas

1. Nunca confirmes `.env`, `config.h`, certificados, contraseñas ni backups.
2. Cambia las claves de ejemplo antes de compartir una pila local.
3. No reutilices la misma credencial MQTT ni el mismo `deviceCode` entre placas.
4. Revisa permisos Owner, Guest y Administrator al cambiar una ruta o pantalla.
5. Si una clave de API se publica en chat, capturas o logs, revócala y crea una
   nueva; borrar el mensaje o el archivo local no invalida la clave expuesta.
