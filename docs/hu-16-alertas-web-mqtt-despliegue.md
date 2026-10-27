# HU-16: alertas, recomendaciones y preparacion del despliegue

## Cambios incluidos

- La web independiente vive en `FT_HS/Web`; la app Expo permanece en `FT_HS/frontend`.
- El dashboard genera recomendaciones a partir de los resúmenes diarios y semanales de consumo devueltos por la API. Son reglas deterministas, no un modelo de IA.
- El panel de alertas permite editar los límites diarios y mensuales, administrar reglas adicionales y atender alertas.
- Cada hogar nuevo recibe límites iniciales editables de `0.50 m³/día` y `15 m³/mes`, junto con sus reglas activas.
- El contador de alertas pendientes consulta directamente eventos `Pending` y `Sent`, sin esperar al refresco de la vista materializada.
- Los flujos de registro, verificación, recuperación y notificaciones usan exclusivamente la API HTTPS de Brevo.
- El backend rechaza MQTT sin TLS o sin credencial cuando `NODE_ENV=production`; evita también credenciales dentro de `MQTT_BROKER_URL` y no registra la URL completa.
- CI valida backend, web, pruebas de navegador y el build de Pages. La integración opcional con Flespi solo se activa con credenciales QA provistas fuera del repositorio.

## Migraciones de base de datos

`BD_HS/01_ddl/06_functions/0000changelog.yaml` registra:

- `064_fn_home_creation_default_alerts.sql`: conserva la firma de creación de hogar de HU-15, agrega umbrales y reglas iniciales, y mantiene la sincronización de tarifa.
- `065_fn_get_home_pending_alerts_live.sql`: reemplaza la lectura potencialmente desactualizada de la vista materializada por el conteo actual de eventos.

Los rollbacks restauran las funciones previas. No borran configuraciones ni eventos ya creados.

Aplica cambios con Liquibase desde la raíz del repositorio:

```powershell
docker compose --env-file .env --profile tooling run --rm liquibase validate
docker compose --env-file .env --profile tooling run --rm liquibase update
```

## Variables y proveedores

Brevo es el único proveedor configurado por la aplicación:

```dotenv
BREVO_API_KEY=
BREVO_FROM_EMAIL=
BREVO_FROM_NAME=HidroSmart
```

Guarda la clave real en Render o en el almacén de secretos correspondiente. No la escribas en `.env.example`, documentación, logs ni commits. Configura también `FRONTEND_URL` y `PASSWORD_RESET_URL` con el dominio HTTPS vigente.

Para un servicio de producción conectado a Flespi, configura en Render:

```dotenv
NODE_ENV=production
MQTT_BROKER_URL=mqtts://mqtt.flespi.io:8883
MQTT_USERNAME=<token Flespi restringido por ACL>
MQTT_PASSWORD=
```

Asigna un token de backend separado de los tokens del ESP32. Restringe el backend a suscripciones de telemetría/estado y publicación de comandos/configuración. Cada placa debe tener credenciales propias y ACL limitada a su identificador de dispositivo. No reutilices el token de backend en firmware ni guardes credenciales en Git.

El bundle móvil envía `mqtt.flespi.io:8883` cuando no hay otra configuración
del host del dispositivo. Si se configura Flespi explícitamente, usa ese mismo
host y puerto en `MQTT_DEVICE_HOST` y `MQTT_DEVICE_PORT` durante el build. El
perfil `esp32dev-flespi` fija ese endpoint y rechaza un broker distinto. Cada
ESP32 requiere su propio token ACL en `provisioning/config.h`.

El entorno local conserva Mosquitto sin TLS dentro de la red de desarrollo. No expongas ese broker local a Internet.

## Despliegue de la web

En Cloudflare Pages, para este monorepo:

| Campo | Valor |
| --- | --- |
| Directorio raíz | `FT_HS/Web` |
| Comando de build | `npm run build` |
| Directorio de salida | `dist` |
| Node.js | `22` |
| Variable de build | `VITE_API_URL=https://pt-hs.onrender.com/api/v1` |

La configuración Vite detiene el build de producción si falta la URL de API o si una URL absoluta no usa HTTPS. En Docker local, el frontend móvil y su Nginx mantienen `/api/v1` como ruta relativa.

En Render, permite el origen de Pages en `CORS_ORIGIN` y conserva las cookies de producción con `Secure` y `SameSite=None`, además de CSRF activo. Las respuestas de preflight deben incluir `X-CSRF-Token` y credenciales.

## Comprobaciones

```powershell
npm.cmd --prefix BK_HS run check
npm.cmd --prefix BK_HS test
npm.cmd --prefix BK_HS run test:integration
npm.cmd --prefix FT_HS/Web test
npm.cmd --prefix FT_HS/Web run build
npm.cmd --prefix FT_HS/Web run test:e2e
```

La prueba real de Flespi es opcional y solo se ejecuta con un token de QA:

```powershell
$env:FLESPI_MQTT_TEST = '1'
$env:MQTT_BROKER_URL = 'mqtts://mqtt.flespi.io:8883'
$env:MQTT_USERNAME = '<token QA con permisos de suscripcion>'
npm.cmd --prefix BK_HS run test:integration:flespi
```

La prueba solo conecta y verifica suscripciones autorizadas; no publica telemetría ni comandos. Sin el token QA, queda omitida. No se afirma aquí una prueba física del ESP32 ni una verificación real de Flespi.
