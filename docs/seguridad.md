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

## Cookies entre Cloudflare Pages y Render

El frontend no puede leer con `document.cookie` una cookie host-only del
backend. Obtiene el token CSRF de `GET /api/v1/auth/csrf`, lo conserva en
memoria y lo envía en `X-CSRF-Token`. El backend expone ese encabezado en CORS
para sincronizar el token después de iniciar o renovar sesión.

Como `pt-hs.pages.dev` y `pt-hs.onrender.com` son sitios distintos, Render debe
usar `AUTH_COOKIE_SECURE=true` y `AUTH_COOKIE_SAME_SITE=none`; `CORS_ORIGIN`
debe contener el origen exacto de Pages. Deja `AUTH_COOKIE_DOMAIN` sin definir:
los dos servicios no comparten un dominio padre.

## Dependencias

El backend debe revisarse con:

```powershell
npm.cmd --prefix BK_HS audit --omit=dev
```

El frontend debe actualizarse de forma controlada. No ejecutes
`npm audit fix --force`: puede forzar saltos mayores de Expo y React Native.
Después de una actualización, ejecuta lint, typecheck, build, pruebas de
backend y una compilación Android.

## Reglas prácticas

1. Nunca confirmes `.env`, `config.h`, certificados, contraseñas ni backups.
2. Cambia las claves de ejemplo antes de compartir una pila local.
3. No reutilices la misma credencial MQTT ni el mismo `deviceCode` entre placas.
4. Revisa permisos Owner, Guest y Administrator al cambiar una ruta o pantalla.
