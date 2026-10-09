# Auditoria de estado actual — HidroSmart

Fecha de verificacion: **2026-09-23**.

Este documento es la referencia del corte actual para la base de datos, el
backend, el frontend y la integracion IoT. Los documentos historicos conservan
el resultado de su propia fecha; cuando exista una diferencia, este corte y el
codigo aplicado tienen prioridad.

## Resultado ejecutivo

| Area | Estado actual |
|---|---|
| PostgreSQL | Saludable en `localhost:5433` |
| Liquibase | `validate` y `status` correctos; **239 changesets aplicados** |
| Backend | Saludable en `localhost:3000`; base de datos y MQTT arriba |
| Frontend | Contenedor levantado en `localhost:5173` |
| MQTT | Broker local arriba; el backend esta suscrito |
| IoT fisico | Pendiente de conectar nuevamente el ESP32 para generar datos persistentes |

## Base de datos

La base contiene **56 tablas de aplicacion**, **5 vistas materializadas** y 2
tablas internas de Liquibase. Las tablas de aplicacion estan distribuidas asi:

| Schema | Tablas |
|---|---:|
| `user_account` | 14 |
| `preference` | 4 |
| `home` | 7 |
| `device` | 6 |
| `consumption` | 5 |
| `alert_rate` | 7 |
| `analytics_support` | 9 |
| `audit` | 2 |
| `privacy` | 2 |
| **Total de aplicacion** | **56** |

No se elimino ninguna tabla. La revision encontro referencias desde funciones,
procedimientos, vistas, indices, claves foraneas, repositorios o rutas del
backend. Una tabla vacia no significa que sea inutil: en una instalacion sin
hogares ni dispositivos es normal que esten vacias `home`, `device`,
`sensor_reading`, alertas, reportes, tickets, privacidad y recomendaciones.

Las tablas de resumen y `consumption_prediction` estan preparadas para jobs y
funcionalidades de analitica que aun no generan datos en este entorno. Se
conservan para no romper el modelo ni eliminar una capacidad prevista.

### Correccion aplicada

Las restricciones de metricas IoT que estaban marcadas como `NOT VALID` fueron
validadas mediante el changeset
`20260923-validate-iot-metric-constraints`. Actualmente hay **0 restricciones
invalidas** y no se encontraron filas con valores fuera de rango.

El modelo de dispositivos conserva:

- `hardware_id` unico para identificar la placa fisica.
- `code` unico para identificar el dispositivo logico MQTT.
- `location`, `wifi_ssid`, `last_ip`, firmware y estado de aprovisionamiento.
- Ningun campo para guardar la contraseña Wi-Fi.
- Idempotencia de lecturas por `(device_id, mqtt_message_id)`.

## Backend y PostgreSQL

El backend usa `hidro_smart_app` para operaciones HTTP y
`hidro_smart_ingest` para ingesta MQTT controlada. La telemetria no entra por
una ruta REST: sigue el flujo:

```text
ESP32 -> Mosquitto -> MqttSubscriber -> parser/handler
      -> device.fn_ingest_sensor_reading -> consumption.sensor_reading
```

Comprobaciones realizadas:

- `GET /health/ready`: HTTP 200 con `database=up` y `mqtt=up`.
- `npm.cmd run check`: 215 archivos JavaScript validos.
- Pruebas unitarias: **172 aprobadas**.
- Integracion actual: **4 aprobadas, 0 fallidas y 2 omitidas** por no definir
  credenciales de usuario para los escenarios autenticados y de matriz de roles.
- Prueba MQTT: una lectura se persistio y el mismo `mqttMessageId` se rechazo
  como duplicado.
- RLS: la prueba de aislamiento por usuario/hogar fue aprobada.

Las 2 pruebas omitidas no indican un fallo de conexion; requieren ejecutar el
sembrador de cuentas de integracion y definir sus variables de entorno.

## Estado de datos del corte

Despues de limpiar los datos temporales de las pruebas:

```text
usuarios       = 4
hogares        = 0
dispositivos   = 0
home_device    = 0
lecturas IoT   = 0
auditoria      = 31
```

Por eso el frontend puede mostrar estados vacios aunque el circuito backend,
MQTT y PostgreSQL este operativo. Para ver datos reales hay que registrar y
vincular un dispositivo, encender el ESP32 y publicar usando el mismo `code`
registrado en `device.device`.

## Frontend

El frontend consume `/api/v1` y no se conecta directamente a PostgreSQL ni a
Mosquitto. Dashboard, Consumo y Dispositivos consultan la telemetria persistida
por HTTP; mientras no exista una lectura muestran estado vacio. El frontend
mantiene el polling actual y no expone credenciales MQTT en el navegador.

Los datos visuales de consumo, costos, alertas y reportes deben venir de las
respuestas del backend. Las cifras de las imagenes de referencia no son datos
de produccion.

## Pendientes reales

1. Registrar el ESP32 y asociarlo a un hogar.
2. Probar varios minutos de telemetria fisica del YF-S201.
3. Confirmar `ONLINE/OFFLINE`, RSSI, IP, ultima lectura y umbral en la pantalla.
4. Ejecutar las pruebas autenticadas de integracion con cuentas sembradas.
5. Completar pruebas frontend/E2E y pruebas BLE en dispositivo movil real.
6. Verificar SMTP real, backup/restore y una instalacion limpia.
7. Endurecer Mosquitto con usuarios, ACL y TLS antes de produccion.
8. Decidir y conectar la generacion automatica de predicciones y recomendaciones.

## Comandos de verificacion

Desde `PT_HS`:

```powershell
docker compose --env-file .env ps
docker compose --env-file .env --profile tooling run --rm liquibase validate
docker compose --env-file .env --profile tooling run --rm liquibase status --verbose
Invoke-WebRequest http://localhost:3000/health/ready
Invoke-WebRequest http://localhost:5173/health
```

Para ejecutar las pruebas desde Windows:

```powershell
npm.cmd run check --prefix BK_HS
npm.cmd test --prefix BK_HS
npm.cmd run test:integration --prefix BK_HS
```
