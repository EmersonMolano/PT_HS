# Configuración de entornos y conexión a PostgreSQL

Esta es la referencia única para los archivos `.env` de HidroSmart.

## Archivos que se usan

| Archivo | Uso | Host de PostgreSQL | Puerto |
|---|---|---|---:|
| `.env` | Compose integrado desde `PT_HS` | `postgres` dentro de Docker / `localhost` desde Windows | `5432` interno / `5433` externo |
| `BD_HS/.env` | Compose independiente de la base | `postgres` dentro de Docker / `localhost` desde Windows | `5432` interno / `5433` externo |
| `BK_HS/.env` | Backend directo o Compose independiente | `localhost` directo / `host.docker.internal` en Docker | `5433` |
| `FT_HS/frontend/.env` | Vite, Web y Mobile | No se conecta a PostgreSQL | API en `localhost:3000` |

Los archivos `.env.example` tienen los mismos nombres de variables que sus
respectivos archivos locales, pero no contienen secretos válidos.

## Credenciales locales actuales

Los tres archivos locales usan la misma base y los mismos roles:

```text
Base:              hidro_smart
Administrador:     hidro_smart_admin
Aplicación:        hidro_smart_app
Ingesta IoT:       hidro_smart_ingest
Liquibase:         hidro_smart_liquibase
Puerto Windows:    5433
Puerto Docker:     5432
```

Las contraseñas reales están únicamente en `.env`, `BD_HS/.env` y `BK_HS/.env`.
No se deben copiar a los archivos `.env.example` ni a la documentación.

## Conexión desde DBeaver, pgAdmin o TablePlus

Usa estos valores cuando el contenedor PostgreSQL esté levantado:

```text
Host:       localhost
Port:       5433
Database:   hidro_smart
User:       hidro_smart_admin
Password:   POSTGRES_PASSWORD de .env
SSL:        desactivado o prefer/preferido
```

Para una conexión con los permisos mínimos del backend:

```text
Host:       localhost
Port:       5433
Database:   hidro_smart
User:       hidro_smart_app
Password:   DB_PASSWORD de .env
```

No uses `postgres:5432` en DBeaver o pgAdmin instalados en Windows. Ese nombre
solo funciona desde otro contenedor de la misma red Docker.

## Comprobación desde PowerShell

Desde `PT_HS`, levanta la base y prueba los tres roles:

```powershell
docker compose --env-file .env up -d postgres db-bootstrap
docker compose --env-file .env ps postgres db-bootstrap

docker compose --env-file .env exec -T postgres pg_isready `
  -U hidro_smart_admin -d hidro_smart

docker compose --env-file .env exec -T postgres psql `
  -U hidro_smart_admin -d hidro_smart `
  -c "SELECT current_database(), current_user;"

docker compose --env-file .env exec -T postgres psql `
  -U hidro_smart_app -d hidro_smart `
  -c "SELECT current_database(), current_user;"
```

El resultado esperado es `accepting connections` y una fila para cada usuario.

## Compose integrado recomendado

```powershell
docker compose --env-file .env config --quiet
docker compose --env-file .env up -d
docker compose --env-file .env ps
```

En este modo el backend recibe internamente:

```text
DB_HOST=postgres
DB_PORT=5432
MQTT_BROKER_URL=mqtt://mosquitto:1883
```

## Backend directo desde Windows

Para ejecutar Node fuera de Docker usa `BK_HS/.env`:

```text
DB_HOST=localhost
DB_PORT=5433
MQTT_BROKER_URL=mqtt://localhost:1883
```

El backend debe conectarse al PostgreSQL del Compose y al Mosquitto publicado
en Windows.

## Qué no se debe hacer

- No uses `DB_PORT=5432` cuando el backend corre directamente en Windows.
- No uses `DB_HOST=localhost` dentro de un contenedor para acceder a PostgreSQL.
- No levantes simultáneamente el Compose integrado y el Compose independiente
  de `BD_HS` usando el mismo puerto `5433`.
- No cambies `POSTGRES_PASSWORD` esperando que cambie la contraseña de una
  base ya inicializada; el volumen conserva el rol existente.
- No uses `down --volumes` salvo que quieras borrar la base local.

## Si cambias una contraseña

Actualiza el archivo local correspondiente y vuelve a ejecutar el bootstrap:

```powershell
docker compose --env-file .env up -d postgres db-bootstrap
docker compose --env-file .env restart backend
```

Para la pila independiente:

```powershell
docker compose --env-file BD_HS/.env -p hidro_smart_bd `
  -f BD_HS/docker-compose.yml up -d postgres db-bootstrap
```

La contraseña del administrador, la del backend, la de ingesta y la de
Liquibase son independientes.
> Actualización 2026-09-26: la configuración MQTT que llega al ESP32 se define
> en `.env` y `FT_HS/frontend/.env`. Consulta la guía vigente
> [`mqtt-esp32-red-local.md`](./mqtt-esp32-red-local.md).
