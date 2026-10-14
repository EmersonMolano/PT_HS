# HidroSmart

HidroSmart es una plataforma para monitorear el consumo de agua por hogar. Se
compone de una aplicación web, API REST, PostgreSQL, broker MQTT y firmware
para ESP32.

> Alcance actual: desarrollo local integrado. La configuración de dominio,
> HTTPS y MQTT/TLS para Internet se preparará cuando exista la infraestructura
> de despliegue definitiva.

## Componentes

| Componente | Ubicación | Responsabilidad |
| --- | --- | --- |
| Base de datos | `BD_HS` | PostgreSQL, Liquibase, roles, RLS y funciones SQL. |
| Backend | `BK_HS` | API Express, autenticación, autorización, MQTT, reportes y trabajos programados. |
| Frontend | `FT_HS/frontend` | Web React/Vite y adaptador móvil Expo/React Native. |
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
npm.cmd --prefix FT_HS/frontend run lint
npm.cmd --prefix FT_HS/frontend run typecheck
npm.cmd --prefix FT_HS/frontend run build
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

## Estado técnico

La API usa cookies `HttpOnly` para sesión y CSRF de doble envío. La base de
datos aplica roles técnicos y RLS. El ESP32 se vincula por código lógico y
conserva una identidad física (`hardwareId`) estable. La telemetría se publica
cada cinco segundos, se valida en el backend y se persiste de forma idempotente.

El broker incluido es para desarrollo local y no usa TLS. No se debe exponer a
Internet ni usar con credenciales reales sin endurecer la infraestructura.
