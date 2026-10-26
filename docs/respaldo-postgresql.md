# Respaldo y restauración PostgreSQL

Los datos se guardan en el volumen Docker `hidro_smart_postgres_data`. Un
respaldo es necesario antes de cambios manuales, actualizaciones de Docker o
pruebas destructivas.

## Crear un respaldo

Con la pila local levantada, desde `PT_HS`:

```powershell
New-Item -ItemType Directory -Force backups | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
docker compose --env-file .env exec -T postgres pg_dump -U hidro_smart_admin -Fc hidro_smart `
  > "backups\hidrosmart-$stamp.dump"
```

Los archivos `backups/` están ignorados por Git. Guárdalos fuera del equipo si
contienen datos que deban recuperarse ante una pérdida total.

## Verificar una restauración

El script crea un respaldo temporal, lo restaura en una base aislada y compara
un resumen básico de datos. No modifica la base en uso.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\verify-postgres-restore.ps1
```

Puedes indicar un archivo de variables alternativo:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\verify-postgres-restore.ps1 -EnvFile .env
```

## Restaurar manualmente

Detén los servicios que escriben en la base y usa una base destino vacía. No
restaures sobre producción sin confirmar el destino, el respaldo y una ventana
de mantenimiento.

```powershell
docker compose --env-file .env cp `
  .\backups\hidrosmart-AAAAMMDD-HHMMSS.dump postgres:/tmp/restore.dump
docker compose --env-file .env exec -T postgres pg_restore `
  -U hidro_smart_admin -d hidro_smart --clean --if-exists /tmp/restore.dump
```

Luego ejecuta:

```powershell
docker compose --env-file .env --profile tooling run --rm liquibase status --verbose
```

El resultado debe indicar que no hay migraciones pendientes. Un respaldo no
incluye automáticamente archivos `.env`, secretos externos ni roles globales
ajenos a la base respaldada.
