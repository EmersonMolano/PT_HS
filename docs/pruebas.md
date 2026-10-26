# Pruebas y validación

## Calidad automática

```powershell
npm.cmd --prefix BK_HS run check
npm.cmd --prefix BK_HS test
npm.cmd --prefix FT_HS/frontend run lint
npm.cmd --prefix FT_HS/frontend run typecheck
npm.cmd --prefix FT_HS/frontend test
npm.cmd --prefix FT_HS/frontend run build
npm.cmd --prefix FT_HS/frontend run mobile:doctor
```

En la revisión del 18 de octubre de 2026 pasaron 204 pruebas unitarias del
backend y 22 del frontend (HTTP, reglas y puente BLE simulado). Esto no valida
PostgreSQL, MQTT ni el comportamiento de cookies en un navegador real. El comando
`docker compose config --quiet` valida el archivo Compose, pero no demuestra
que el motor esté
iniciado ni que los servicios respondan.

La integración requiere la pila levantada y cuentas de prueba. En CI se crean
con las variables `INTEGRATION_*` de GitHub Actions.

```powershell
npm.cmd --prefix BK_HS run seed:integration
npm.cmd --prefix BK_HS run test:integration
```

## Validación manual por rol

| Rol | Casos mínimos |
| --- | --- |
| Owner / HomeUser | Crear o seleccionar hogar, vincular/desvincular, configurar dispositivo, revisar consumo, alertas y reportes. |
| Guest | Consultar solo el hogar compartido; no debe gestionar dispositivos ni miembros. |
| Administrator | Gestionar usuarios, roles, auditoría y solicitudes de privacidad. |

Comprueba también que la sesión continúa tras recargar, que las operaciones
mutables no fallan por CSRF y que el cierre de sesión revoca la sesión y limpia
las cookies. Repite login → recarga → refresh → logout en el navegador de
destino, especialmente con Cloudflare Pages y Render: sus dominios distintos
pueden provocar bloqueo de cookies de terceros. Comprueba los encabezados
`Set-Cookie`, `X-CSRF-Token` y, ante `403`, el código `CSRF_INVALID`.

## Simulación HTTP aislada (sin cuentas reales)

```powershell
node BK_HS/scripts/stress-auth-csrf.js 300 100
```

El primer número es clientes virtuales y el segundo, concurrencia máxima.
Cada cliente prueba bootstrap CSRF, refresh inválido y rechazo CSRF. El script
levanta un servidor local temporal, no crea usuarios y evita la base de datos
usando un refresh deliberadamente inválido. La ejecución de 300 clientes
realizó 900 solicitudes previstas sin errores; **no representa 300 inicios
de sesión reales ni una prueba de capacidad de Render/PostgreSQL**. La carga
real necesita un entorno aislado, datos ficticios y métricas del servidor.

## Simulación IoT

El simulador realiza: inicio sin hogar, login, vínculo, `confirm_link`, tres
lecturas separadas cinco segundos y desvinculación. Usa exclusivamente un
usuario, hogar y dispositivo de prueba porque el flujo modifica su asociación.

```powershell
$env:SIM_OWNER_LOGIN = 'owner-de-prueba@hidrosmart.local'
$env:SIM_OWNER_PASSWORD = 'CLAVE_DE_PRUEBA'
$env:SIM_HOME_ID = 'UUID_DEL_HOGAR_DE_PRUEBA'
$env:SIM_DEVICE_CODE = 'HS-7A3F91C8D2E4'
npm.cmd --prefix BK_HS run simulate:iot
```

## Expo Go en teléfono Android

Con Docker Desktop y el stack activos, PC y teléfono en la misma red:

```powershell
Set-Location FT_HS/frontend
npm.cmd run mobile:start
```

El script prepara el bundle con la IP LAN y abre Metro. Si la web/API no
responde en `http://IP_DEL_PC:5173/health`, primero corrige Docker o la red.
Expo Go permite probar la UI, no el BLE nativo.

## Android nativo para BLE (opcional)

Con SDK Android y un emulador iniciado:

```powershell
Set-Location FT_HS/frontend
$env:REACT_NATIVE_ARCHITECTURES = 'x86_64'
npm.cmd run mobile:android
```

`mobile:android` prepara y compila el proyecto nativo y usa `adb reverse` en el
emulador. Un teléfono físico necesita una URL de API alcanzable por la red,
no `localhost`.
