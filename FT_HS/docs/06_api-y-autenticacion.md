# 06 API y autenticación del frontend

## Alcance

Describe cómo la interfaz web llama al backend y conserva la sesión. La fuente
principal del cliente compartido es `frontend/src/shared/http/apiClient.ts`;
la sesión de React se administra en `frontend/src/app/providers/AuthProvider.tsx`.
Los adaptadores de cada módulo viven junto a su feature.

## Configuración

- `VITE_API_URL` define la base de API. Si no existe, el valor local es
  `http://localhost:3000/api/v1`.
- El frontend web no debe contener contraseñas MQTT ni secretos del backend.
- `VITE_MQTT_DEVICE_HOST` y `VITE_MQTT_DEVICE_PORT` son valores públicos que
  pueden enviarse al ESP32 durante el aprovisionamiento; no son credenciales.
- El bundle móvil se prepara mediante `scripts/prepare-mobile-bundle.mjs` y
  necesita una URL de API alcanzable desde el dispositivo.

## Ciclo de sesión

1. `AuthProvider` consulta `GET /users/me` para restaurar la sesión.
2. Si la cookie de acceso ya venció, `apiClient` intenta una sola renovación
   compartida mediante `POST /auth/refresh` y repite la petición original una
   vez.
3. El login llama a `POST /auth/login` y vuelve a consultar `/users/me` para
   cargar roles y permisos.
4. Al cerrar sesión se llama a `POST /auth/logout`. El estado local y React
   Query se limpian si el servidor confirma el cierre o devuelve `401` porque
   la sesión ya no es válida. Ante fallo de red, CSRF o servidor se informa el
   error y se permite reintentar; no se finge un cierre exitoso.
5. Solo si la renovación devuelve `401` se limpia el estado local y se emite
   `hidrosmart:session-expired`. Los errores `429`, de red o `5xx` conservan la
   sesión local.
6. Si `/users/me` falla transitoriamente al arrancar, se presenta una pantalla
   para reintentar la comprobación de sesión en lugar de mostrar el login como
   si la sesión hubiera caducado.

Los tokens de acceso y renovación son cookies `HttpOnly`; JavaScript no los lee
ni los almacena. El cliente obtiene CSRF mediante `GET /auth/csrf` y lee el
encabezado `X-CSRF-Token` expuesto por CORS. Esto evita depender de leer la
cookie de otro dominio desde JavaScript. El backend emite también una cookie
CSRF no `HttpOnly` para compararla con ese encabezado.

## Llamadas HTTP y errores

- `apiClient.get/post/put/patch/delete` centraliza `fetch`.
- Todas las solicitudes usan `credentials: 'include'`.
- Antes de `POST`, `PUT`, `PATCH` o `DELETE`, el cliente obtiene y agrega el
  token CSRF. Si la respuesta es `403` con código `CSRF_INVALID`, lo renueva y
  reintenta una sola vez; no reintenta otros `403`.
- `ApiError` conserva el código HTTP y los detalles recibidos. Las pantallas
  deben mostrar mensajes entendibles y no filtrar payloads internos.
- Los reportes binarios usan `getBlob`; no conviertas una descarga PDF/XLSX en
  JSON.
- Una feature debe ampliar su adaptador API, no llamar `fetch` desde el JSX de
  una pantalla.

## Autorización en la interfaz

`GET /users/me` proporciona `roles` y `permissions`. `authorization.ts` los
normaliza para ocultar acciones o vistas que no aplican. Esto mejora la
experiencia, pero no concede acceso: el backend vuelve a autorizar y PostgreSQL
aplica el aislamiento de filas.

No mezclar los roles globales (`Administrator`, `HomeUser`, `Guest`) con los
roles de membresía de un hogar (`Owner`, `Member`, `Guest`). Un usuario puede
tener un rol global y una membresía distinta en cada hogar.

## Diagnóstico rápido

| Síntoma | Revisar |
| --- | --- |
| Error de conexión | `VITE_API_URL`, salud del backend, CORS y red del dispositivo. |
| 401 después de recargar | Cookies, expiración/refresh y dominio/SameSite. |
| 403 | Permiso devuelto por `/users/me`, guard del backend y membresía del hogar. |
| 403 `CSRF_INVALID` | Comprueba `GET /auth/csrf`, `Set-Cookie`, encabezado `X-CSRF-Token`, CORS y bloqueo de cookies de terceros. |
| 429 o 5xx al restaurar | Comprueba disponibilidad del backend; la pantalla de reintento no debe borrar una sesión válida. |
| Reporte vacío o descarga fallida | Formato de respuesta, `getBlob` y permisos `reports.read`. |

El inventario de rutas está en [`../../BK_HS/docs/openapi.yaml`](../../BK_HS/docs/openapi.yaml);
la matriz de permisos del servidor, en
[`../../BK_HS/docs/07_autorizacion-y-permisos.md`](../../BK_HS/docs/07_autorizacion-y-permisos.md).
