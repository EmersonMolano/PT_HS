# HidroSmart

HidroSmart es una plataforma para monitorear el consumo de agua por hogar. Se
compone de una aplicación web, API REST, PostgreSQL, broker MQTT y firmware
para ESP32.

> Alcance verificado: desarrollo local y pruebas automáticas aisladas. Los
> La aplicación web tiene build y E2E automatizados; login, cookies y CSRF aún
> requieren comprobación visual en los dominios de Cloudflare Pages y Render.
> El código de MQTT/TLS está preparado para Flespi, pero faltan probar tokens
> ACL reales y el flujo físico del ESP32.

## Componentes

| Componente | Ubicación | Responsabilidad |
| --- | --- | --- |
| Base de datos | `BD_HS` | PostgreSQL, Liquibase, roles, RLS y funciones SQL. |
| Backend | `BK_HS` | API Express, autenticación, autorización, MQTT, reportes y trabajos programados. |
| Web | `FT_HS/Web` | Aplicación React/Vite para Cloudflare Pages. |
| Móvil y frontend Docker | `FT_HS/frontend` | App Expo/React Native y servicio web local de la pila Compose. |
| Firmware | `firmware` | ESP32, BLE, Wi-Fi, MQTT y lectura del caudalímetro. |
| Orquestación | `docker-compose.yml` | Pila local completa. |

## Inicio rápido local

Requisitos: Docker Desktop y Node.js 22. Para cargar el ESP32 se necesita
PlatformIO.

```powershell
Copy-Item .env.example .env
docker compose --env-file .env config --quiet
docker compose --env-file .env up -d postgres db-bootstrap mosquitto
docker compose --env-file .env --profile tooling run --rm liquibase update
docker compose --env-file .env up -d --build backend frontend
docker compose --env-file .env ps
```

Servicios disponibles en Windows:

| Servicio | Dirección |
| --- | --- |
| Aplicación web | `http://localhost:5173` |
| API | `http://localhost:3000` |
| Estado de la API | `http://localhost:3000/health` |
| PostgreSQL | `localhost:5433` |
| MQTT local | `localhost:1883` |

Las contraseñas de `.env` son exclusivamente locales. No se suben al
repositorio ni se copian a documentación.

## Comprobaciones

```powershell
# Backend
npm.cmd --prefix BK_HS run check
npm.cmd --prefix BK_HS test

# Frontend web
npm.cmd --prefix FT_HS/Web test
npm.cmd --prefix FT_HS/Web run build
npm.cmd --prefix FT_HS/Web run test:e2e

# App móvil / frontend Docker
npm.cmd --prefix FT_HS/frontend run lint
npm.cmd --prefix FT_HS/frontend run typecheck
npm.cmd --prefix FT_HS/frontend test
npm.cmd --prefix FT_HS/frontend run build
npm.cmd --prefix FT_HS/frontend run mobile:doctor
```

Consulta [docs/pruebas.md](docs/pruebas.md) para integración, simulación IoT y
Android.

## Documentación

El índice actualizado está en [docs/README.md](docs/README.md). Empieza por:

- [Arquitectura](docs/arquitectura.md)
- [Instalación de dependencias](docs/instalacion-dependencias.md)
- [Operación local](docs/operacion-local.md)
- [Flujo IoT](docs/iot.md)
- [Seguridad](docs/seguridad.md)
- [Estado actual y pendientes](docs/estado-actual.md)
- [HU-16: alertas, recomendaciones, MQTT y despliegue](docs/hu-16-alertas-web-mqtt-despliegue.md)
- [Documentación pendiente y evidencias](docs/pendientes-documentacion.md)

## Estado técnico

La API usa cookies `HttpOnly` para sesión y CSRF de doble envío. La base de
datos aplica roles técnicos y RLS. El ESP32 se vincula por código lógico y
conserva una identidad física (`hardwareId`) estable. La telemetría se publica
cada cinco segundos, se valida en el backend y se persiste de forma idempotente.

El broker Mosquitto incluido es para desarrollo local. Producción requiere
broker externo con TLS y credencial limitada por ACL. La guía de HU-16 describe
la configuración de Flespi y Cloudflare Pages.
