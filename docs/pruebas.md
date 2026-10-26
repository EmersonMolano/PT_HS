# Pruebas y validación

## Calidad automática

```powershell
npm.cmd --prefix BK_HS run check
npm.cmd --prefix BK_HS test
npm.cmd --prefix FT_HS/frontend run lint
npm.cmd --prefix FT_HS/frontend run typecheck
npm.cmd --prefix FT_HS/frontend run build
```

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
mutables no fallan por CSRF y que el cierre de sesión limpia las cookies.

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

## Android

Con un emulador Android iniciado:

```powershell
Set-Location FT_HS/frontend
$env:REACT_NATIVE_ARCHITECTURES = 'x86_64'
npm.cmd run mobile:android
```

En otra terminal inicia Metro:

```powershell
npm.cmd run mobile:start -- --localhost
```

El emulador usa `adb reverse` desde el script. Un teléfono físico necesita una
URL de API alcanzable por la red, no `localhost`.
