# Estado integral de HidroSmart

Fecha de corte: 2026-09-23.

> **Actualizacion vigente:** el corte anterior mencionaba 236 changesets y
> lecturas de desarrollo. La verificacion del 2026-09-23 confirma 239
> changesets, 172 pruebas unitarias, 4 integraciones aprobadas y 2 omitidas por
> falta de credenciales. La base quedo con 0 hogares, 0 dispositivos y 0
> lecturas despues de limpiar los datos temporales de prueba.

Este es el resumen transversal de la base de datos, backend, frontend, MQTT,
correo, Docker y firmware. Distingue lo que estÃ¡ implementado de lo que fue
comprobado en el entorno local y de lo que todavÃ­a requiere trabajo.

## Resumen ejecutivo

| Capa | Estado comprobado | Alcance actual |
|---|---|---|
| Base de datos | Operativa | PostgreSQL 16, Liquibase al día con 239 changesets, funciones, grants, RLS y restricciones IoT validadas |
| Backend | Operativo | API Express bajo `/api/v1`, autenticaciÃ³n, sesiones, dominios principales, SMTP, MQTT y persistencia IoT |
| Frontend web | Compila y se integra | React + TypeScript + Vite, rutas protegidas, cliente HTTP centralizado, roles e i18n |
| Frontend mÃ³vil | Bundle verificado | Expo + React Native + WebView, agrupado con Web bajo `FT_HS/frontend` |
| Docker | Operativo local | PostgreSQL, bootstrap, backend, frontend y Mosquitto |
| MQTT | Persistencia y control conectados | Telemetría, estados y comandos pasan por broker; la placa real aún requiere una prueba continua |
| SMTP | Gmail SMTP configurable | Nodemailer envÃ­a eventos mediante las variables `SMTP_*` del `.env`; la entrega real requiere credenciales locales válidas |
| Firmware | Estructura presente | Existe `firmware/` con ID eFuse, YF-S201, NVS, BLE y MQTT; falta compilar/cargar y validar la placa física |

## Evidencia ejecutada

- Liquibase `validate`: aprobado.
- Liquibase `status --verbose`: `up to date`, 239 changesets aplicados.
- Backend `npm.cmd run check`: aprobado.
- Backend `npm.cmd test`: 172/172 pruebas unitarias aprobadas.
- Frontend `npm.cmd run typecheck`, `npm.cmd run lint` y `npm.cmd run build`: aprobados.
- Frontend mÃ³vil `npm.cmd run mobile:prepare`: aprobado; genera el bundle web para WebView.
- Frontend `npm.cmd audit --omit=dev`: 19 vulnerabilidades de dependencias reportadas por Expo/Metro/Vite; resolverlas requiere una actualización mayor y no se aplicó `npm audit fix --force` automáticamente.
- `FT_HS/frontend` no tiene pruebas automatizadas descubiertas actualmente; `npm test`
  finaliza con 0 pruebas, por lo que no equivale a cobertura funcional.
- Docker: `backend` saludable, `postgres` saludable, `frontend` y
  `mosquitto` levantados en la Ãºltima verificaciÃ³n.
- Health backend: `http://localhost:3000/health/ready` respondiÃ³ HTTP 200.
- Health frontend: `http://localhost:5173/health` respondiÃ³ HTTP 200.
- La integraciÃ³n local actual ejecutÃ³ 4 pruebas aprobadas, 0 fallidas y 2
  omitidas por falta de credenciales de usuario. RLS usa un hogar temporal
  aislado y lo elimina al terminar; MQTT comprueba inserciÃ³n e idempotencia.
- La comprobaciÃ³n directa de PostgreSQL encontrÃ³ 0 hogares, 0 dispositivos y
  0 lecturas despuÃ©s de limpiar los datos temporales de integraciÃ³n. Esto no
  representa una falla del backend ni de la base.
- La matriz de `Administrator`, `HomeUser` y `Guest` en
  `BK_HS/tests/integration/roles-permissions.test.js` se prepara con
  `BK_HS/scripts/seed-integration-users.js`; para producciÃ³n deben repetirse
  las pruebas con cuentas y datos no sintÃ©ticos.

## Corte vigente: avance y pendientes (2026-09-23)

Los porcentajes son estimaciones de alcance comprobado. No representan cobertura
de cÃ³digo ni sustituyen una prueba de aceptaciÃ³n. El porcentaje Ãºnico del
proyecto es **80% de funcionalidad local comprobada**; la preparaciÃ³n para
producciÃ³n es menor porque el ESP32 real aÃºn no estÃ¡ transmitiendo de forma
continua y el broker local no usa TLS.

| Ãrea | Avance | Evidencia actual | Faltante principal |
|---|---:|---|---|
| Base de datos | 94% | 239 changesets, 56 tablas de aplicaciÃ³n, 5 vistas materializadas y restricciones IoT validadas | backup/restore, instalaciÃ³n limpia y prueba sostenida con hardware |
| Backend | 91% | 215 archivos JS vÃ¡lidos, 172 pruebas unitarias y 4 integraciones aprobadas | E2E manual, SMTP real, actuadores y endurecimiento productivo |
| Frontend web | 84% | HTTP centralizado, pantallas conectadas, lint, TypeScript y build aprobados | pruebas frontend/E2E, accesibilidad, estados uniformes y refresco en tiempo real |
| Frontend mÃ³vil | 65% | bundle WebView y puente BLE preparados | development build y prueba BLE con la placa |
| Firmware/IoT | 60% | ID eFuse, YF-S201, NVS, BLE, Wi-Fi y MQTT implementados | carga/calibraciÃ³n y transmisiÃ³n continua de la placa real |
| OperaciÃ³n y seguridad | 72% | Docker saludable, validaciÃ³n automatizada y logs estructurados | TLS/ACL MQTT, rotaciÃ³n de secretos, backup/restore y vulnerabilidades |

### Evidencia de IoT en el corte

PostgreSQL no conserva lecturas IoT en el corte actual porque los datos
temporales de integración fueron eliminados. El backend sí está conectado a
Mosquitto y suscrito a telemetría, estados y actuadores.

Por tanto, la cadena está implementada y probada con mensajes de integración,
pero la transmisión física continua debe verificarse encendiendo,
provisionando y vinculando nuevamente el ESP32.

### Faltantes priorizados

1. **P0 - Prueba fÃ­sica completa:** ESP32/YF-S201 publicando durante varios
   minutos, MQTT recibiendo, backend persistiendo, PostgreSQL incrementando el
   contador y frontend mostrando la Ãºltima lectura.
2. **P1 - OperaciÃ³n de dispositivo:** comprobar `ONLINE/OFFLINE`, `last_seen`,
   RSSI, IP, umbral y la desapariciÃ³n de BLE cuando Wi-Fi estÃ© conectado.
3. **P1 - Actuadores:** validar comando, ACK, timeout y auditorÃ­a con firmware
   real.
4. **P1 - AceptaciÃ³n de usuario:** recorrer manualmente los tres roles, crear
   hogar, registrar/vincular dispositivo, consultar consumo, alertas, reportes
   PDF/Excel y tickets.
5. **P2 - ProducciÃ³n:** ACL/TLS MQTT, secretos fuera del repositorio, Gmail real,
   backup/restore e instalaciÃ³n limpia.
6. **P2 - Calidad de cliente:** pruebas de componentes/E2E, accesibilidad,
   iPhone/Android real, refresco en tiempo real y reducciÃ³n del chunk principal.
7. **P2 - Producto:** generaciÃ³n automÃ¡tica de recomendaciones y cierre del
   flujo administrativo de solicitudes ARCO.

## Base de datos

### Implementado

- Esquemas de usuarios, preferencias, hogares, dispositivos, consumo, tarifas,
  alertas, metas, vacaciones, soporte, auditorÃ­a, recomendaciones y analÃ­tica.
- Liquibase con changesets y rollbacks separados; no se deben editar changesets
  que ya fueron aplicados.
- Roles tÃ©cnicos separados: `hidro_smart_admin`, `hidro_smart_liquibase`,
  `hidro_smart_app`, `hidro_smart_ingest` y `hidro_smart_readonly`.
- Funciones protegidas para autenticaciÃ³n, sesiones, ciclo de cuenta, contexto de
  autorizaciÃ³n, auditorÃ­a e ingesta MQTT.
- RLS y controles de membresÃ­a para limitar el acceso por hogar.
- Ingesta MQTT mediante `device.fn_ingest_sensor_reading(...)`, sin `INSERT`
  directo del rol de ingesta sobre `consumption.sensor_reading`.
- La identidad `hardware_id` y el estado de aprovisionamiento del ESP32 se
  guardan en `device.device`; los estados MQTT y la telemetría nueva actualizan
  esos campos mediante funciones protegidas.
- Idempotencia por `mqttMessageId`, validaciÃ³n de dispositivo activo, separaciÃ³n
  entre `measured_at` y `received_at` y control de timestamps.
- Las funciones y vistas de consumo alimentan los endpoints agregados del backend.
- `consumption.fn_get_consumption_series(...)` entrega series diarias, horarias,
  mensuales y por ubicación con autorización de hogar, métricas de flujo y
  conteo de lecturas.
- El registro crea cuentas en estado `Pending`; el consumo de un token válido de
  verificación marca `email_verified_at` y activa la cuenta.
- `user_profile.avatar_data_url` permite una foto opcional validada por backend
  (JPG, PNG o WebP, máximo 2 MB) y `phone` admite hasta 60 caracteres.
- `consumption.sensor_reading` conserva litros con `NUMERIC(14,3)` y m³ con
  `NUMERIC(14,6)`, incluida la precisión de muestras de `0.040 L` del
  caudalímetro.

### Datos de desarrollo observados

Los conteos funcionales de roles en la base local durante la verificaciÃ³n fueron:

| Rol funcional | Usuarios observados |
|---|---:|
| `Administrator` | 1 |
| `HomeUser` | 1 |
| `Guest` | 1 |

La base local ya contiene cuentas para probar el panel administrativo y la gestión
de tickets. Estas cuentas son de desarrollo y no deben usarse como credenciales de
producción.

### Pendientes de BD

- No hay cambiosets pendientes en la base local. La precisiÃ³n de
  `consumption.sensor_reading` estÃ¡ versionada: litros en `NUMERIC(14,3)` y m3
  generado en `NUMERIC(14,6)`.
- La auditorÃ­a se consulta por funciÃ³n SQL y endpoint administrativo protegido;
  no se concede acceso directo a la tabla al rol de aplicaciÃ³n. La matriz de
  roles ya verifica `200` para administraciÃ³n y `403` para los demÃ¡s roles.
- Probar la persistencia de `online/offline` y `last_seen` con el contrato final
  del dispositivo real.
- El modelo, ACK, timeout y auditoría de comandos de actuadores ya están versionados;
  falta probar el contrato completo con el firmware real.
- Preparar backups, restauraciÃ³n y una instalaciÃ³n limpia como validaciÃ³n de
  entrega, no solo como flujo local de desarrollo.

## Backend

### Implementado

- API Express bajo `/api/v1` y health pÃºblico/operativo.
- Registro, login, access token, refresh token rotativo, logout, revocaciÃ³n de
  sesiones, cambio de contraseÃ±a, recuperaciÃ³n y restablecimiento.
- La verificación de correo se envía al registrarse, el reenvío invalida tokens
  anteriores y una cuenta `Pending` no puede iniciar sesión.
- VerificaciÃ³n y reenvÃ­o de correo, con Nodemailer y transporte configurable.
- Perfil, preferencias de idioma/moneda, hogares, miembros, solicitudes,
  dispositivos, consumo, tarifas, alertas, metas, vacaciones, recomendaciones,
  soporte, roles, auditorÃ­a, privacidad/ARCO y reportes PDF/Excel.
- Recomendaciones: listado propio, resumen por hogar y actualizaciÃ³n de estado o
  utilidad; el acceso queda respaldado por `reports.read` y RLS.
- ValidaciÃ³n compartida de rangos de consumo con mÃ¡ximo de 366 dÃ­as para resumen,
  costo y reportes PDF/Excel.
- `GET /api/v1/consumption/advanced` expone la serie agrupada para las pantallas
  de Dashboard, Consumo y Reportes.
- AutorizaciÃ³n por permiso y acceso al hogar/dispositivo; la visibilidad del
  frontend no reemplaza las guardas del backend ni RLS.
- MQTT con subscriber, parser, handlers, lÃ­mites de payload, persistencia SQL e
  idempotencia.
- Jobs de alertas, limpieza de auditoría, timeout de actuadores y actualización de
  vistas materializadas.
- Pruebas unitarias especÃ­ficas para validar guardar, consultar y eliminar el modo
  vacaciones, incluyendo fechas, objetivo diario y notificaciÃ³n de retorno.
- ValidaciÃ³n de correspondencia entre tipo y unidad de alerta, validaciÃ³n de la
  fecha opcional al consultar el modo vacaciones y normalizaciÃ³n estricta de
  timestamps MQTT a UTC.

### Rutas principales

`/api/v1/auth`, `/api/v1/users`, `/api/v1/homes`, `/api/v1/devices`,
`/api/v1/consumption`, `/api/v1/tariffs`, `/api/v1/alerts`, `/api/v1/goals`,
`/api/v1/vacation`, `/api/v1/support`, `/api/v1/roles`, `/api/v1/audit`,
`/api/v1/privacy`, `/api/v1/reports`, `/api/v1/recommendations` y
`/api/v1/actuators`.
La lista completa de mÃ©todos y permisos estÃ¡ en
[`BK_HS/docs/03-endpoints.md`](../BK_HS/docs/03-endpoints.md).

El alta IoT esta conectada mediante `POST /api/v1/devices`: crea el dispositivo y
la asignacion al hogar en una transaccion. La solicitud admite `location` para
identificar el lugar visible del sensor. Un equipo ya registrado se vincula con
`POST /api/v1/devices/link` usando su codigo MQTT exacto. La ultima muestra se
consulta con `GET /api/v1/devices/:deviceId/telemetry/latest`, protegido por
membresia.

La guia operativa completa para registrar, vincular, editar y comprobar equipos
esta en [`docs/dispositivos-iot.md`](dispositivos-iot.md).

### Pendientes de backend

- Completar las pruebas manuales de los tres roles contra la base real; la
  matriz automatizada local ya cubre Administrator, HomeUser y Guest; Administrator también gestiona tickets.
- Definir los cinco tipos de alerta de producto y completar la semÃ¡ntica del modo
  vacaciones segÃºn las reglas finales.
- Validar comandos, timeout, ACK y auditoría de actuadores con un ESP32 real.
- Aplicar paginaciÃ³n, filtros y ordenamiento en todas las consultas que lo
  necesiten, no solo en las que ya tienen respuesta paginada.
- Endurecer Mosquitto para un entorno real: autenticaciÃ³n, ACL por dispositivo,
  TLS y rotaciÃ³n de credenciales.
- Resolver la advertencia de `npm audit` sobre `qs`/Express mediante una decisiÃ³n
  explÃ­cita de migraciÃ³n a Express 5 o mitigaciÃ³n aprobada; no se cambia de major
  automÃ¡ticamente.

## Frontend web

### Implementado

- React Router con rutas pÃºblicas y protegidas bajo `/app/*`.
- `AuthProvider`, hogar activo, almacenamiento de sesiÃ³n y renovaciÃ³n ante `401`.
- Login, registro, recuperaciÃ³n/restablecimiento, logout y cambio de contraseÃ±a.
- Consumo del perfil `/users/me`, preferencias de idioma/moneda y permisos del
  backend.
- Perfil con avatar opcional persistido y teléfono de hasta 60 caracteres,
  sincronizado con el encabezado y la sesión actual.
- Dashboard, hogares, dispositivos, consumo, reportes PDF/Excel, alertas, metas,
  vacaciones, soporte, privacidad y administraciÃ³n consumen las APIs disponibles;
  recomendaciones se presenta como contenido visual informativo.
- Dashboard, Consumo y Reportes consultan series avanzadas del backend para no
  calcular agregados con cifras quemadas en el navegador.
- Dashboard consulta el historial real de alertas pendientes y ya no fabrica una
  alerta sintética a partir del contador.
- Hogares presenta sus tarjetas en un carrusel horizontal responsive.
- Navegación por roles `Administrator`, `HomeUser` y `Guest`; guardas
  tambiÃ©n al entrar directamente por URL.
- Panel administrativo con gestión de tickets integrada. `HomeUser` y `Guest` no
  muestran ni pueden abrir Soporte o Notificaciones.
- Soporte con detalle, historial, respuestas y actualizaciÃ³n de estado.
- Sidebar colapsable/hamburguesa, responsive base e internacionalizaciÃ³n en
  espaÃ±ol, inglÃ©s, portuguÃ©s e italiano.

La pantalla de dispositivos muestra la conectividad MQTT real y las metricas de
la ultima lectura persistida; un equipo sin muestras queda en estado vacio.
El boton **Configurar** abre un apartado unico para editar nombre, ubicacion y
umbral, consultar `wifiSsid`, `lastIp`, RSSI, hardware e historial, y
provisionar por BLE mientras Wi-Fi no este conectado. La contrasena solo se
envia por BLE y no se almacena ni se devuelve.

### Limitaciones y pendientes de frontend

- Hacer pruebas manuales de login, registro, refresh, logout y navegaciÃ³n con los
  cuatro usuarios funcionales reales.
- Uniformar estados de carga, vacÃ­o, error y reintento en todas las pantallas.
- Completar paginaciÃ³n, filtros y ordenamiento visual donde el backend ya entrega
  metadata.
- Migrar textos directos que aÃºn no usan i18n y revisar accesibilidad con teclado,
  foco, lector de pantalla y contraste.
- Crear pruebas de componentes y rutas protegidas; actualmente no hay suite
  frontend automatizada.
- Reducir el chunk principal del build web, que todavÃ­a supera 500 kB despuÃ©s de
  minificar aunque el build termina correctamente.
- Verificar visualmente en iPhone/Android real o emulador.
- Conectar tiempo real MQTT cuando exista el contrato definitivo del producto.
- Implementar eliminación/seguimiento completo de solicitudes ARCO y pruebas de
  comandos de actuadores cuando el contrato lo cierre.
- El indicador â€œflujo actualâ€ del dashboard representa el Ãºltimo punto agregado
  horario disponible; no debe documentarse como caudal MQTT en tiempo real.

### Actualización operativa 2026-09-23

- Backend: 172 pruebas unitarias; la integración actual tuvo 4 aprobadas y 2 omitidas por falta de credenciales.
- MQTT: el parser de estados acepta el RSSI negativo que publica el ESP32 y lo normaliza a calidad porcentual.
- Frontend: Dashboard, Consumo y Dispositivos refrescan la última telemetría persistida cada 5 segundos.
- La transmisión continua de la placa física sigue pendiente de confirmarse en esta sesión; el último mensaje retenido observado fue `OFFLINE`.

## MQTT, firmware y correo

### MQTT actual

Actualización 2026-09-23: el contrato nuevo de ESP32 ya incluye `hardwareId`,
`ssid`, `lastIp` y estado de aprovisionamiento. La prueba local publicó estado y telemetría por
Mosquitto; el backend los normalizó y PostgreSQL los persistió sin perder la
idempotencia por `mqttMessageId`. El detalle reproducible está en
[`integracion-esp32-bd-backend-front.md`](./integracion-esp32-bd-backend-front.md).

La asociación física ahora se hace con `GET /api/v1/devices/hardware/:hardwareId`
y `POST /api/v1/devices/:deviceId/claim-hardware`; el flujo BLE del front envía
`deviceCode` al ESP32 después de confirmar ese vínculo.

```text
ESP32 -> Mosquitto -> MqttSubscriber -> parser -> handler -> IngestReading -> PostgreSQL
```

Topics de entrada:

- `hidrosmart/devices/{deviceCode}/telemetry`
- `hidrosmart/devices/{deviceCode}/status`
- `hidrosmart/devices/{deviceCode}/actuators/{valve|pump}/status`

El broker local es anÃ³nimo y sin TLS. La persistencia se validÃ³ con el payload
del ESP32 y con la prueba automatizada de MQTT; la prueba fÃ­sica continua aÃºn
debe ejecutarse con el equipo encendido y publicando durante varios minutos.

### Firmware

Existe la carpeta `firmware/` con estructura para provisioning, Wi-Fi, MQTT,
sensores, actuadores, OTA, almacenamiento y pruebas. El código actual genera el
ID `HS-141F47470968` según el eFuse, anuncia `HidroSmart-470968`, guarda hasta
cinco perfiles Wi-Fi/MQTT y expone el contrato BLE de configuración/estado.
La compilación/carga, calibraciÃ³n y transmisiÃ³n sostenida sobre la placa y el
caudalÃ­metro reales siguen pendientes de evidencia.

### Correo

Gmail se configura
por SMTP con una clave de aplicaciÃ³n en el `.env` local; las credenciales reales
no pertenecen a ningÃºn documento ni commit. Falta verificar el envÃ­o real de cada
evento en una cuenta Gmail y revisar plantillas, enlaces y expiraciÃ³n en un
entorno controlado.

## EjecuciÃ³n y URLs locales

Desde la raÃ­z `PT_HS`:

```powershell
docker compose --env-file .env up -d --build
docker compose --env-file .env ps
```

- Frontend: `http://localhost:5173`
- Backend: `http://localhost:3000`
- Backend readiness: `http://localhost:3000/health/ready`
- Frontend health: `http://localhost:5173/health`
- PostgreSQL externo: `localhost:5433`
- MQTT: `localhost:1883`

Para validar la base:

```powershell
docker compose --env-file .env --profile tooling run --rm liquibase validate
docker compose --env-file .env --profile tooling run --rm liquibase status --verbose
```

## Prioridad siguiente

1. Ejecutar la prueba fÃ­sica P0: ESP32/YF-S201 â†’ Mosquitto â†’ backend â†’
   PostgreSQL â†’ frontend durante varios minutos.
2. Validar con la placa `ONLINE/OFFLINE`, `last_seen`, RSSI, IP, umbral y
   aprovisionamiento BLE; registrar la evidencia y actualizar este documento.
3. Probar actuadores reales con ACK, timeout y auditorÃ­a.
4. Hacer recorrido manual/E2E de los tres roles y de los flujos de hogar,
   dispositivo, consumo, alertas, reportes y soporte.
5. Endurecer el entorno antes de producciÃ³n: ACL/TLS MQTT, rotaciÃ³n de secretos,
   Gmail controlado, backup/restore e instalaciÃ³n limpia.
6. Completar calidad frontend: pruebas de componentes, accesibilidad, mÃ³vil
   real, refresco en tiempo real y reducciÃ³n del chunk principal.
- Bitácora de cambios verificados del 2026-09-14: `cambios-2026-09-14.md`.
> Nota vigente (2026-09-26): este documento conserva el corte histórico del
> 2026-09-23. Para el estado comprobado actual, incluidas 245 migraciones y la
> configuración MQTT automática por `.env`, consulta
> [`estado-verificado-2026-09-26.md`](./estado-verificado-2026-09-26.md).
