# Operación local

## Requisitos

- Docker Desktop iniciado.
- Node.js 22 para herramientas de backend y frontend.
- PlatformIO solo para compilar o cargar el ESP32.

## Levantar todo

Desde la raíz `PT_HS`:

```powershell
Copy-Item .env.example .env
docker compose --env-file .env config --quiet
docker compose --env-file .env up -d postgres db-bootstrap mosquitto
docker compose --env-file .env --profile tooling run --rm liquibase validate
docker compose --env-file .env --profile tooling run --rm liquibase update
docker compose --env-file .env up -d --build backend frontend
```

Comprueba el estado:

```powershell
docker compose --env-file .env ps
Invoke-WebRequest http://localhost:3000/health
Invoke-WebRequest http://localhost:5173/health
```

## Operación diaria

```powershell
docker compose --env-file .env up -d
docker compose --env-file .env logs -f backend
docker compose --env-file .env down
```

Para aplicar migraciones nuevas, ejecuta `validate` y `update` antes de
reiniciar el backend. No uses `down --volumes` salvo que quieras eliminar por
completo los datos locales.

## Desarrollo fuera de Docker

```powershell
# Backend, con BK_HS/.env configurado
Set-Location BK_HS
npm.cmd install
npm.cmd run dev

# Frontend web, en otra terminal
Set-Location FT_HS/frontend
npm.cmd install
npm.cmd run dev
```

Para el backend fuera de Docker, PostgreSQL y Mosquitto deben ser accesibles
desde Windows; usa los valores locales de `BK_HS/.env.example` como guía.

## Diagnóstico rápido

| Síntoma | Revisión |
| --- | --- |
| Backend no inicia | `docker compose logs backend` y las variables `DB_*`, JWT y MQTT de `.env`. |
| Migración falla | `docker compose --profile tooling run --rm liquibase status --verbose`. |
| No llega telemetría | `docker compose logs -f mosquitto backend`; comprueba host MQTT, código lógico y Wi-Fi del ESP32. |
| Web no consume API | Confirma `http://localhost:5173/health` y que Vite usa `/api/v1` en Docker. |
