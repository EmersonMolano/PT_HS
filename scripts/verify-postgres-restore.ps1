[CmdletBinding()]
param(
  [string]$EnvFile = '.env',
  [string]$BackupDirectory = 'backups',
  [string]$RestoreContainer = 'hidrosmart-restore-check'
)

$ErrorActionPreference = 'Stop'

function Invoke-Docker {
  param([string[]]$DockerArguments)
  & docker @DockerArguments
  if ($LASTEXITCODE -ne 0) { throw "Fallo Docker: docker $($DockerArguments -join ' ')" }
}

function Get-ComposeEnvValue {
  param([string]$Name, [string]$Default)
  $line = Get-Content $EnvFile | Where-Object { $_ -match "^$([regex]::Escape($Name))=(.*)$" } | Select-Object -First 1
  if (-not $line) { return $Default }
  $value = ($line -replace "^$([regex]::Escape($Name))=", '').Trim()
  return $value.Trim('"').Trim("'")
}

$existing = & docker ps -a --filter "name=^/$RestoreContainer$" --format '{{.ID}}'
if ($existing) {
  throw "Ya existe el contenedor temporal '$RestoreContainer'. Revisalo o eliminalo manualmente antes de ejecutar la prueba."
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\$BackupDirectory"))
$dumpFile = Join-Path $backupRoot "hidrosmart-restore-check-$timestamp.dump"
$dumpInContainer = "/tmp/hidrosmart-restore-check-$timestamp.dump"
$restoreDatabase = 'hidro_smart_restore_check'
$restoreUser = 'restore_check'
$sourceDatabase = Get-ComposeEnvValue -Name 'POSTGRES_DB' -Default 'hidro_smart'
$sourceUser = Get-ComposeEnvValue -Name 'POSTGRES_USER' -Default 'postgres'

New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null

try {
  Invoke-Docker -DockerArguments @('compose', '--env-file', $EnvFile, 'exec', '-T', 'postgres', 'pg_dump', '-U', $sourceUser, '-d', $sourceDatabase, '-Fc', '-f', $dumpInContainer)
  $sourceContainer = (& docker compose --env-file $EnvFile ps -q postgres).Trim()
  if (-not $sourceContainer) { throw 'No se encontro el contenedor PostgreSQL de origen.' }
  Invoke-Docker -DockerArguments @('cp', "${sourceContainer}:$dumpInContainer", $dumpFile)

  Invoke-Docker -DockerArguments @(
    'run', '-d', '--name', $RestoreContainer,
    '-e', "POSTGRES_DB=$restoreDatabase",
    '-e', "POSTGRES_USER=$restoreUser",
    '-e', 'POSTGRES_PASSWORD=restore-check-local-only',
    'postgres:16-alpine'
  )

  $ready = $false
  for ($attempt = 1; $attempt -le 12; $attempt += 1) {
    & docker exec $RestoreContainer pg_isready -U $restoreUser -d $restoreDatabase | Out-Null
    if ($LASTEXITCODE -eq 0) { $ready = $true; break }
    Start-Sleep -Seconds 2
  }
  if (-not $ready) { throw 'PostgreSQL temporal no estuvo listo a tiempo.' }

  # Los dumps de una base no incluyen roles globales. Las politicas RLS los
  # referencian, por lo que se recrean sin LOGIN antes de restaurar.
  foreach ($role in @('hidro_smart_app', 'hidro_smart_ingest', 'hidro_smart_readonly')) {
    Invoke-Docker -DockerArguments @('exec', $RestoreContainer, 'psql', '-U', $restoreUser, '-d', $restoreDatabase, '-c', "CREATE ROLE $role NOLOGIN")
  }

  Invoke-Docker -DockerArguments @('cp', $dumpFile, "${RestoreContainer}:$dumpInContainer")
  Invoke-Docker -DockerArguments @('exec', $RestoreContainer, 'pg_restore', '-U', $restoreUser, '-d', $restoreDatabase, '--no-owner', '--no-privileges', $dumpInContainer)

  $summarySql = 'SELECT (SELECT count(*) FROM pg_tables) AS tables, (SELECT count(*) FROM device.device) AS devices, (SELECT count(*) FROM home.home) AS homes;'
  $sourceSummary = & docker compose --env-file $EnvFile exec -T postgres psql -U $sourceUser -d $sourceDatabase -At -F '|' -c $summarySql
  if ($LASTEXITCODE -ne 0) { throw 'No se pudo consultar el resumen de origen.' }
  $restoredSummary = & docker exec $RestoreContainer psql -U $restoreUser -d $restoreDatabase -At -F '|' -c $summarySql
  if ($LASTEXITCODE -ne 0) { throw 'No se pudo consultar el resumen restaurado.' }

  if (-not $sourceSummary -or -not $restoredSummary) {
    throw 'La consulta de comparacion no devolvio resultados.'
  }

  if ($sourceSummary.Trim() -ne $restoredSummary.Trim()) {
    throw "La restauracion no coincide. Origen: $sourceSummary Restaurado: $restoredSummary"
  }

  Write-Host "Restauracion verificada correctamente: $($restoredSummary.Trim())"
  Write-Host "Respaldo conservado en: $dumpFile"
}
finally {
  $temporary = & docker ps -a --filter "name=^/$RestoreContainer$" --format '{{.ID}}'
  if ($temporary) { & docker rm -f $RestoreContainer | Out-Null }
}
