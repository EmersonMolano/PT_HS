# Validacion de integracion local

Última ejecución comprobada: 2026-09-23. El resultado actual fue 4 pruebas
aprobadas, 0 fallidas y 2 omitidas porque no se definieron las credenciales de
usuario para los escenarios autenticados y la matriz de roles.

Este flujo comprueba el backend contra PostgreSQL, las politicas RLS, los
permisos de `Administrator`, `HomeUser` y `Guest`, y la ingesta MQTT.
Los usuarios que crea son exclusivos para pruebas y no deben usarse en
produccion.

## Preparar la pila

Desde `PT_HS`:

```powershell
docker compose --env-file .env up -d postgres db-bootstrap mosquitto
docker compose --env-file .env --profile tooling run --rm liquibase validate
docker compose --env-file .env --profile tooling run --rm liquibase update
docker compose --env-file .env up -d --build backend frontend
```

## Preparar las cuentas de prueba

En la misma sesion de PowerShell define la conexion administrativa y cuatro
correos/contraseñas de prueba. Las contraseñas deben cumplir la politica local:

```powershell
$env:INTEGRATION_ADMIN_DATABASE_URL = 'postgresql://hidro_smart_admin:CLAVE_ADMIN@localhost:5433/hidro_smart'
$env:INTEGRATION_ADMIN_EMAIL = 'ci-administrator@hidrosmart.local'
$env:INTEGRATION_ADMIN_PASSWORD = 'CiAdministrator123!'
$env:INTEGRATION_HOMEUSER_EMAIL = 'ci-homeuser@hidrosmart.local'
$env:INTEGRATION_HOMEUSER_PASSWORD = 'CiHomeuser123!'
$env:INTEGRATION_GUEST_EMAIL = 'ci-guest@hidrosmart.local'
$env:INTEGRATION_GUEST_PASSWORD = 'CiGuest123!'

npm.cmd run seed:integration --prefix BK_HS
```

El sembrador actualiza solo las cuentas identificadas por esos correos, asigna
un unico rol a cada una y no imprime las contraseñas.

## Ejecutar todas las pruebas de integracion

```powershell
$env:RUN_INTEGRATION = '1'
$env:INTEGRATION_DATABASE_URL = 'postgresql://hidro_smart_app:CLAVE_APP@localhost:5433/hidro_smart'
$env:INTEGRATION_MQTT_URL = 'mqtt://localhost:1883'
$env:INTEGRATION_USER_EMAIL = $env:INTEGRATION_HOMEUSER_EMAIL
$env:INTEGRATION_USER_PASSWORD = $env:INTEGRATION_HOMEUSER_PASSWORD

npm.cmd run test:integration --prefix BK_HS
```

Con las credenciales de usuario sembradas, el resultado esperado es `6 pass, 0 fail, 0 skipped`. La prueba RLS crea y
elimina sus datos temporales de hogar, reporte, ticket, respuesta y privacidad,
y comprueba cero filas sin contexto y visibilidad propia con el usuario
contextual. La prueba MQTT también elimina el dispositivo y la lectura de
prueba al finalizar.

La auditoría no concede acceso directo a la tabla al rol de aplicación. La
matriz de roles comprueba el endpoint administrativo: `Administrator` recibe
`200` y los demás roles reciben `403`.

En el último corte el resultado real fue `4 pass, 0 fail, 2 skipped`. Además,
`npm.cmd run check` y `npm.cmd test` del backend terminaron con 215 archivos
JavaScript válidos y 174 pruebas unitarias aprobadas. Esta
validación confirma el circuito backend–PostgreSQL–RLS–MQTT, pero no reemplaza
la prueba continua del ESP32/YF-S201 físico.

El frontend web consulta la última telemetría persistida cada 5 segundos en
Dashboard, Consumo y Dispositivos. Esto mantiene actualizadas las métricas
mientras se completa un canal push MQTT/SSE; la fuente sigue siendo siempre el
backend y no el broker expuesto al navegador.

## Validación completa

Para ejecutar BD, backend, frontend, mobile y las integraciones en una sola
secuencia usa desde `PT_HS`:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-all.ps1
```

Esta validación también ejecuta Liquibase, siembra las cuatro cuentas de
integración y reconstruye las imágenes Docker.

## CI

`.github/workflows/validate.yml` define credenciales efimeras de CI, ejecuta
`seed:integration` y luego corre la misma matriz. No copies esas credenciales a
los `.env` locales ni a un despliegue.

## Criterio de cierre IoT

Para considerar cerrado el flujo físico deben cumplirse simultáneamente:

1. El ESP32 publica el mismo `deviceCode` que existe en `device.device.code`.
2. Mosquitto recibe telemetría y estados durante varios minutos.
3. El backend registra mensajes aceptados sin rechazos de contrato.
4. El contador y `last_reading` de PostgreSQL aumentan.
5. El frontend muestra la última telemetría y el estado real del dispositivo.
