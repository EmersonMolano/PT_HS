# Diagnóstico de autenticación y despliegue — 20 de octubre de 2026

## 1. Resumen ejecutivo

La causa confirmada del rechazo CSRF no está en el código actual de `hu-15-dev`: el frontend publicado por Cloudflare está sirviendo un bundle anterior. Ese cliente intenta leer `hidrosmart_csrf` desde `document.cookie` en `pt-hs.pages.dev`, pero la cookie pertenece al host `pt-hs.onrender.com` y no es legible desde el dominio de Pages. El backend exige que el encabezado `X-CSRF-Token` coincida con la cookie de Render cuando la petición lleva cookies de sesión. La petición llega sin el encabezado y se rechaza con `403 CSRF_INVALID`.

El código actual del frontend ya resuelve el cruce de dominios: hace `GET /auth/csrf` con `credentials: 'include'`, lee el token del encabezado CORS expuesto y lo manda en cada operación mutable. El backend también responde correctamente para el origen autorizado. **No se cambió la lógica de seguridad ni se relajaron CORS o CSRF.**

Queda pendiente publicar ese frontend desde GitHub. No se pudo acceder a la configuración autenticada de Cloudflare desde esta sesión. También quedan pendientes la comprobación de sesiones/correos reales y una prueba k6 contra un entorno aislado. La simulación local de 300 flujos con 300 conexiones simultáneas no pasó completamente: 68 flujos tuvieron `ECONNREFUSED`; la causa exacta del límite local aún no está confirmada.

## 2. Arquitectura y componentes revisados

- Frontend React/Vite: `FT_HS/frontend/src/shared/http/apiClient.ts` y `src/app/providers/AuthProvider.tsx`.
- Backend Express: `BK_HS/src/app.js`, `src/config/env.js`, `src/api/auth.routes.js`, `src/api/security/authCookies.js`, `src/api/middleware/auth.js` y `src/api/middleware/authRateLimit.js`.
- Casos de uso de sesión: `BK_HS/src/core/application/services/auth/AuthSessionService.js`.
- Pruebas unitarias de cookies/CSRF, rate limits, sesiones, correo y cliente HTTP.
- Rama observada: `hu-15-dev`, sincronizada con `origin/hu-15-dev` en `bfbcd53` (`ci: quitar servicio Mailpit inexistente`).

## 3. Problemas y evidencia

| Hallazgo | Evidencia | Estado |
| --- | --- | --- |
| Bundle de Pages desactualizado; provoca CSRF inválido cuando el navegador manda una cookie de sesión. | `https://pt-hs.pages.dev/login` carga `index-kX-D3cIE.js`. El bundle no contiene el bootstrap `/auth/csrf`; usa una función basada en `document.cookie` para intentar leer `hidrosmart_csrf`. El bundle local actual sí obtiene el token mediante la respuesta de `/auth/csrf`. | Causa raíz confirmada para el desajuste frontend/backend. Falta desplegar el bundle actual. |
| CORS del origen publicado funciona en la API actual. | `GET /api/v1/auth/csrf` desde `https://pt-hs.pages.dev`: HTTP 204, `Access-Control-Allow-Origin` coincide exactamente, credenciales permitidas, encabezado `X-CSRF-Token` presente y cookie CSRF `Secure; SameSite=None`. | Verificado en producción, lectura solamente. |
| Preflight de autenticación funciona. | `OPTIONS /api/v1/auth/login`: HTTP 204 y se permiten `Content-Type`, `Authorization` y `X-CSRF-Token`. | Verificado. |
| CORS no permite el origen de prueba ajeno. | Preflight con `https://untrusted.invalid` no recibió `Access-Control-Allow-Origin`. | Verificado; no se habilitó CORS abierto. |
| El backend distingue CSRF de autenticación. | Petición sintética a logout con cookie falsa y encabezado CSRF incorrecto: `403 CSRF_INVALID`. Con cookie/header sintéticos coincidentes, pasa CSRF y el JWT falso obtiene `401 UNAUTHORIZED`. No se usaron sesiones reales ni se modificaron cuentas. | Verificado en producción. |
| Los 401 pueden ser normales en el arranque anónimo; también pueden señalar cookie de sesión ausente, expirada o revocada. | Al inicializar, el frontend consulta `/users/me`; ante 401 intenta una sola renovación. Sin cookie refresh válida, esa renovación también responde 401 y se limpia el estado local. El cliente comparte una renovación concurrente y no repite indefinidamente. | Código revisado; causa de los 401 observados por el usuario requiere URL/Request ID de cada solicitud. |
| Los 429 dependen del limitador y su configuración efectiva. | El backend configura límites por credencial y por IP. Valores por defecto: 20 intentos por credencial y 1000 por IP en 15 minutos; las variables de Render pueden cambiarlos. `/auth/sessions` no tiene un limitador propio en las rutas revisadas; `/auth/refresh` sí comparte el limitador IP. | Código confirmado; configuración de Render y endpoint exacto del 429 no accesibles. |
| Cookies cross-site podrían ser bloqueadas por el navegador. | Pages y Render son sitios distintos; el backend emite cookies de sesión `HttpOnly`, y en producción la configuración predeterminada es `Secure` y `SameSite=None`. | Riesgo por validar en Chrome con una sesión real. No se cambió `Domain` ni `SameSite`. |
| La conexión Git de Cloudflare no pudo inspeccionarse desde su panel. | El bundle publicado no corresponde al cliente actual de la rama. El panel autenticado no estaba disponible en esta sesión; no se desconectó ni eliminó el proyecto. | Requiere revisar/reconectar desde Cloudflare. |

### Diagnóstico concreto del 403

El middleware `createCsrfProtection` compara la cookie CSRF recibida por Render con `X-CSRF-Token`. La versión publicada intenta obtener el encabezado leyendo `document.cookie` desde Pages. Por la política de mismo origen, ese script no puede leer una cookie host-only de `onrender.com`. El código actual evita ese problema leyendo el encabezado devuelto por `GET /auth/csrf`, que CORS expone.

El middleware solo aplica esta comprobación cuando la petición mutable lleva cookie de acceso o refresh. Por eso un `403` en login indica además que la petición llevaba una cookie de sesión (por ejemplo, una cookie vieja del navegador) o que el despliegue tiene una variante distinta del middleware; el código `CSRF_INVALID` permite identificar esta rama. No se debe desactivar CSRF para corregir el desfase.

## 4. Causa raíz confirmada o hipótesis pendientes

**Confirmada:** el bundle de Cloudflare no corresponde al cliente HTTP actual de `hu-15-dev`; el mecanismo de token basado en `document.cookie` no puede leer la cookie host-only que entrega Render. La prueba sintética contra producción confirma que un CSRF incorrecto da `403 CSRF_INVALID` y que una pareja CSRF válida supera esa capa y llega a autenticación (`401` para el JWT deliberadamente falso).

**Pendientes de confirmación:** la causa de cada `401` observado con una sesión real requiere revisar si el navegador envía las cookies access/refresh y si la sesión sigue activa. En el arranque anónimo, el primer 401 de `/users/me` y el intento fallido de refresh pueden ser comportamiento normal. Para un `429`, se necesita la ruta y `X-Request-Id`: el código tiene límite por IP y credencial, pero no limita directamente la ruta `/auth/sessions`.

No se modificó código de aplicación: la corrección del bootstrap ya está en la rama; lo que falta es publicar ese bundle. No se relajaron CORS, CSRF, cookies ni límites.

## 5. Plan de corrección

1. **Cloudflare Pages:** conectar o reparar la integración Git existente con `joseale879/PT_HS` sin eliminar el proyecto; configurar la raíz `FT_HS/frontend`, comando `npm run build`, salida `dist` y desplegar `hu-15-dev` como preview primero. Verificar la rama de producción antes de reemplazar la URL pública.
2. **Verificación navegador:** comprobar que el nuevo bundle contenga `/auth/csrf`; en DevTools confirmar `GET /auth/csrf` → 204 y `X-CSRF-Token`, login → 200, `/users/me` → 200, refresh → cookies rotadas, logout → 204 y cookies limpiadas. Probar también que un CSRF incorrecto da `403 CSRF_INVALID`.
3. **Cookies:** si Chrome bloquea cookies cross-site aun con `Secure; SameSite=None`, preparar un origen same-site o proxy controlado; no cambiar atributos a ciegas.
4. **Sesiones y claves expuestas:** revocar la sesión concreta desde un dispositivo confiable; rotar la clave Brevo expuesta y actualizar `BREVO_API_KEY`/remitente en Render sin registrarlos en logs.
5. **Email E2E:** con cuenta de prueba, solicitar verificación y recuperación una vez; confirmar evento aceptado/entregado/rebote en Brevo, abrir enlace, completar el flujo y verificar que el token venza/sea de un solo uso.
6. **Prueba k6:** instalar/usar k6 en un entorno QA autorizado, partir de 10, 50, 150 y 300 VUs con ramp-up y duración definida; usar cuentas ficticias existentes y no enviar correos en el escenario de carga.

## 6. Archivos modificados y justificación

- `docs/diagnostico-estabilizacion-despliegue-2026-10-20.md`: nuevo informe con evidencias, resultados reproducibles, límites y acciones pendientes.
- `docs/README.md`: enlace al informe en el índice de documentación.
- No se modificó ningún archivo de aplicación ni configuración de despliegue. `npm run build` generó `FT_HS/frontend/dist`, que es un artefacto local ignorado por Git.

Los archivos que ya estaban sin seguimiento al iniciar la revisión se preservaron y no se añadieron a este informe/commit.

## 7. Pruebas ejecutadas

| Comando | Resultado |
| --- | --- |
| `npm.cmd run check` en `BK_HS` | Correcto. |
| `npm.cmd test` en `BK_HS` | 204/204 pruebas unitarias pasaron. |
| `npm.cmd test` en `FT_HS/frontend` | 22/22 pruebas pasaron. |
| `npm.cmd run typecheck` en frontend | Correcto. |
| `npm.cmd run lint` en frontend | Correcto. |
| `npm.cmd run build` en frontend | Correcto; genera un bundle con el cliente HTTP actual. |
| Pruebas de CORS/CSRF públicas | CSRF 204, preflight 204, origen no autorizado sin permiso CORS; comprobación sintética 403/401 diferenciada. |

La integración con PostgreSQL/MQTT no se ejecutó porque requiere un entorno y cuentas de integración explícitamente aislados. No se hicieron login real, registro, cambio de contraseña, verificación de correo ni envío de prueba a una cuenta personal.

## 8. Configuración de despliegue validada

- Producción responde en `https://pt-hs.onrender.com/health` con HTTP 200.
- El origen permitido observado es exactamente `https://pt-hs.pages.dev`, con credenciales; el preflight permite el encabezado CSRF.
- `GET /api/v1/auth/csrf` devuelve HTTP 204, cookie CSRF `Secure`, `SameSite=None`, `Path=/`, sin `Domain` y sin `HttpOnly` (la cookie CSRF debe poder compararse con el encabezado). El encabezado `X-CSRF-Token` está presente y CORS lo expone.
- El proyecto Pages actual sirve `index-kX-D3cIE.js`, sin bootstrap `/auth/csrf`. Por ello no se da el despliegue del frontend por validado.
- Los valores actuales de Pages (repositorio conectado, rama de producción, variables y raíz configurada) no pudieron inspeccionarse en el panel autenticado. La raíz `FT_HS/frontend`, build `npm run build` y salida `dist` son valores previstos, no una configuración ya verificada en Cloudflare.

## 9. Resultados de la prueba de carga

Se ejecutó `BK_HS/scripts/stress-auth-csrf.js`, que crea un servidor temporal en `127.0.0.1`, usa tokens sintéticos y no consulta PostgreSQL ni crea usuarios. Cada flujo prueba bootstrap CSRF, refresh inválido y rechazo CSRF; también envía 300 refresh inválidos desde una IP simulada para comprobar el rate limit.

| Clientes virtuales / concurrencia máxima | Flujos | Solicitudes del flujo (3 por VU) | p95 por flujo | Errores |
| --- | ---: | ---: | ---: | ---: |
| 10 / 10 | 10/10 | 30 | 91 ms | 0 |
| 50 / 50 | 50/50 | 150 | 180 ms | 0 |
| 150 / 100 | 150/150 | 450 | 317 ms | 0 |
| 300 / 100 | 300/300 | 900 | 321 ms | 0 |
| 300 / 200 | 300/300 | 900 | 607 ms | 0 |
| 300 / 300 | 232/300 | 900 | 573 ms | 68 `ECONNREFUSED` |

En todas las ejecuciones el control adicional de IP compartida produjo 300 respuestas 401 y 0 respuestas 429; son 300 solicitudes adicionales por ejecución, además de las mostradas en la tabla. Esto valida ramas de seguridad y concurrencia del ensayo, **no** mide capacidad de Render o Neon. La falla a concurrencia máxima de 300 sucede en el listener local de Windows; subir el backlog configurado a 1024 en una prueba diagnóstica no cambió la proporción 232/68, así que no se declara causa raíz del rechazo local.

No hay Grafana k6 instalado ni se encontró un script k6. Por tanto no se hizo una prueba sostenida con 300 VUs, métricas de servidor, percentiles p99 o throughput. No se cargó producción: faltan un entorno de prueba separado, cuentas ficticias ya preparadas y acceso a métricas.

## 11. Pendientes y próximos pasos

| Actividad | Estado | Resultado o evidencia | Pendiente |
| --- | --- | --- | --- |
| Auditoría de frontend/backend | Completada | Código, pruebas y configuración CORS/CSRF revisados. | Mantener documentación al cambiar el contrato. |
| Diagnóstico CORS/CSRF | Causa CSRF confirmada | API pública y prueba sintética identifican el desajuste del bundle. | Revalidar después de publicar. |
| Corrección del cliente HTTP | Ya presente en la rama | Pruebas frontend 22/22 y build/typecheck correctos. | Publicar el bundle actual en Pages. |
| Sesiones/401/429 | Parcial | Código de renovación y límites revisado. | Obtener URL exacta, Request ID y configuración efectiva de Render. |
| Revocación/rotación de secretos | Pendiente externo | No se usaron ni mostraron secretos. | Rotar Brevo y revocar sesión expuesta desde los paneles/dispositivo autorizado. |
| Verificación de correo E2E | Pendiente | Unit tests de Brevo pasan; no se mandó correo. | Prueba única con usuario ficticio y logs de Brevo. |
| Reconexión Cloudflare–GitHub | Pendiente externo | Bundle publicado no coincide con la rama. | Acceso al panel y permisos GitHub/Cloudflare. |
| Pruebas de carga | Parcial local | 10/50/150 y 300 VUs con hasta 200 concurrencia pasan; 300 simultáneos tuvo 68 rechazos locales. | k6, 300 VUs sostenidos en QA y métricas de servidor. |

## 10. Riesgos y limitaciones

- Mientras Pages siga publicando el bundle antiguo, las operaciones con cookies de sesión pueden seguir devolviendo CSRF inválido.
- No se confirmó si el navegador bloquea cookies de terceros en la configuración del usuario.
- No se inspeccionaron las variables privadas de Render, los logs de Render/Brevo ni el panel de Cloudflare.
- Las pruebas unitarias verifican la integración de Brevo y que el error no filtre la API key, pero no se verificó una entrega real. Un HTTP 202 no prueba entrega; se debe corroborar el evento en Brevo y completar el flujo con una cuenta ficticia.
- Una API key de Brevo y cookies/tokens fueron compartidos previamente en la conversación. Deben revocarse/rotarse desde sus paneles propietarios; esta sesión no tiene acceso para hacerlo. No se deben copiar nuevos secretos al chat.
- No se revocaron sesiones reales: hacerlo en bloque podría cerrar sesiones de otros dispositivos. Revocar la sesión expuesta desde un dispositivo confiable o usando su identificador exacto.
- No se hicieron mutaciones reales de cuenta ni pruebas de carga contra producción.
- La medición local de Windows no sirve para inferir capacidad de producción ni sustituye la prueba k6 solicitada.
