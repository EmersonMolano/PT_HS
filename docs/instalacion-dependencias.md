# Instalación de dependencias en Windows

Esta guía prepara un equipo nuevo para desarrollar HidroSmart. El proyecto se
divide en tres alcances: la aplicación web y la pila Docker, el firmware del
ESP32 y la aplicación Android. Instala primero lo obligatorio y añade lo
opcional solo cuando vayas a trabajar esa parte.

> HidroSmart usa Node.js 22 en sus imágenes Docker. El frontend móvil usa Expo
> SDK 54 y React Native 0.81; no instales ni actualices Expo globalmente.

## 1. Descargas obligatorias para la aplicación web

| Herramienta | Versión o criterio | Para qué se usa | Descargar |
| --- | --- | --- | --- |
| Git | Versión estable actual | Clonar, actualizar y subir el repositorio. | [git-scm.com](https://git-scm.com/download/win) |
| Docker Desktop | Versión estable actual, con WSL 2 habilitado | Ejecutar PostgreSQL, Mosquitto, Liquibase, backend y frontend. | [Docker Desktop](https://www.docker.com/products/docker-desktop/) |
| Node.js | **22 LTS** | Ejecutar las pruebas, herramientas del backend, Vite y Expo. | [nodejs.org](https://nodejs.org/) |
| Navegador Chromium | Edge o Chrome actual | Usar la web y Web Bluetooth durante el aprovisionamiento. | Edge o [Chrome](https://www.google.com/chrome/) |

Visual Studio Code es recomendado para editar el proyecto, pero no es un
requisito de ejecución. Se puede descargar desde [code.visualstudio.com](https://code.visualstudio.com/).

### Lo que **no** debes instalar por separado

Docker Compose descarga y ejecuta estas dependencias con las versiones fijadas
en `docker-compose.yml`:

- PostgreSQL 16.
- Eclipse Mosquitto 2.0.21.
- Liquibase y el controlador PostgreSQL para aplicar migraciones.
- Nginx para servir el frontend construido.

Tampoco instales Express, React, Vite, Expo, ArduinoJson, PubSubClient o
NimBLE manualmente. Los gestores del proyecto resuelven sus versiones desde los
archivos `package-lock.json` y `platformio.ini`.

## 2. Verificar las herramientas base

Abre una terminal nueva de PowerShell y ejecuta:

```powershell
git --version
docker --version
docker compose version
node --version
npm.cmd --version
```

`node --version` debe mostrar `v22.x`. En este proyecto se usa `npm.cmd` en
PowerShell para evitar el bloqueo de ejecución de `npm.ps1` que puede aplicar
Windows a los scripts.

Si Docker Desktop solicita WSL 2 o virtualización, completa ese asistente y
reinicia Windows antes de continuar. No es necesario instalar PostgreSQL local
ni configurar un servidor MQTT de Windows.

## 3. Descargar dependencias del repositorio

Desde la raíz `PT_HS`, crea la configuración local y descarga las dependencias
JavaScript exactas de cada aplicación:

```powershell
Copy-Item .env.example .env
npm.cmd --prefix BK_HS ci
npm.cmd --prefix FT_HS/frontend ci
```

`npm ci` usa las versiones bloqueadas del repositorio y recrea `node_modules`.
Úsalo para instalar o recuperar un entorno; usa `npm.cmd install` solamente
cuando modifiques deliberadamente un `package.json` y su lockfile.

No ejecutes `npm audit fix --force`: puede cambiar Expo, React Native o Vite de
forma incompatible. Las actualizaciones de dependencias se revisan y prueban
por separado.

## 4. Levantar la plataforma local

Con Docker Desktop iniciado, ejecuta desde `PT_HS`:

```powershell
docker compose --env-file .env config --quiet
docker compose --env-file .env up -d postgres db-bootstrap mosquitto
docker compose --env-file .env --profile tooling run --rm liquibase validate
docker compose --env-file .env --profile tooling run --rm liquibase update
docker compose --env-file .env up -d --build backend frontend
docker compose --env-file .env ps
```

Luego comprueba:

```powershell
Invoke-WebRequest http://localhost:3000/health
Invoke-WebRequest http://localhost:5173/health
```

La aplicación queda disponible en `http://localhost:5173`. La API se publica
solo en `localhost:3000`, PostgreSQL en `localhost:5433` y MQTT en el puerto
`1883` de la red local configurada para desarrollo.

Antes de conectar un ESP32 real, cambia las contraseñas de ejemplo en `.env` y
define `MQTT_DEVICE_HOST` con un nombre DNS o reserva DHCP que el ESP32 pueda
resolver desde la Wi-Fi. Nunca uses `localhost` ni el nombre interno
`mosquitto` como host del dispositivo físico.

## 5. Solo si vas a compilar o cargar el ESP32

### Descargas adicionales

| Herramienta o material | Cuándo hace falta |
| --- | --- |
| [PlatformIO IDE para VS Code](https://platformio.org/install/ide?install=vscode) **o** PlatformIO Core | Siempre que compiles, monitorees o cargues firmware. Elige una de las dos opciones; la extensión es la más cómoda. |
| Controlador USB CP210x o CH340 | Solo si Windows no crea un puerto `COM` al conectar la placa. Identifica primero el chip USB de tu placa; no instales controladores al azar. |
| Cable USB de datos | Siempre. Algunos cables solo cargan y no crean un puerto serie. |
| ESP32 Dev Module y caudalímetro YF-S201 | Para la prueba física del firmware actual. |

PlatformIO descarga automáticamente la plataforma `espressif32`, el framework
Arduino y las bibliotecas declaradas (`PubSubClient`, `ArduinoJson` y
`NimBLE-Arduino`) al ejecutar la compilación.

### Primera compilación

```powershell
Set-Location firmware
Copy-Item provisioning\config.example.h provisioning\config.h
pio run
pio device list
pio run -t upload --upload-port COM6
pio device monitor --baud 115200
```

Sustituye `COM6` por el puerto mostrado por `pio device list`. `config.h` queda
ignorado por Git: contiene Wi-Fi y, si corresponde, las credenciales MQTT de la
placa. No lo confirmes ni lo envíes por chat.

Si aparece `PermissionError(13)` o "port is busy", cierra el monitor serie,
Arduino IDE y cualquier programa que esté usando ese puerto. La guía funcional
del dispositivo está en [IoT](iot.md) y el contrato de telemetría en
[firmware/mqtt/contract.md](../firmware/mqtt/contract.md).

## 6. Solo si vas a trabajar Android/móvil

El móvil sigue en estabilización; prepara primero la web y la pila Docker. Para
una compilación nativa necesitas un *development build*, no Expo Go, porque
HidroSmart utiliza `react-native-ble-plx` para Bluetooth.

### Descargas adicionales

1. Instala [Android Studio](https://developer.android.com/studio/install) y
   acepta el asistente de instalación estándar.
2. Instala **JDK 17**. Expo documenta JDK 17 para Android en Windows; Android
   Studio suele traer su propio entorno, pero el JDK evita fallos de Gradle en
   terminal.
3. En **Settings > Languages & Frameworks > Android SDK**, instala:
   - Android SDK Platform **36** y sus fuentes.
   - Android SDK Build-Tools.
   - Android SDK Platform-Tools (`adb`).
   - Android Emulator.
   - Android SDK Command-line Tools (latest).
4. En Device Manager crea y arranca un emulador x86_64 con Google APIs. La
   virtualización VT-x/AMD-V debe estar activa en BIOS/UEFI.

Android Studio suele instalar el SDK en
`%LOCALAPPDATA%\Android\Sdk`. Crea la variable de usuario `ANDROID_HOME` con
esa ruta y añade estas rutas a `Path`:

```text
%ANDROID_HOME%\platform-tools
%ANDROID_HOME%\emulator
%ANDROID_HOME%\cmdline-tools\latest\bin
```

Cierra y abre PowerShell; después verifica el acceso a ADB:

```powershell
adb --version
adb devices
```

Si `adb` no se reconoce, el SDK está instalado pero `platform-tools` no está en
`Path`. Corrige la variable antes de intentar compilar.

### Preparar y ejecutar Android

Con el emulador encendido:

```powershell
Set-Location FT_HS/frontend
npm.cmd run mobile:doctor
npm.cmd run mobile:android
```

Cuando el *development build* ya esté instalado, inicia Metro en otra terminal:

```powershell
Set-Location FT_HS/frontend
npm.cmd run mobile:start -- --localhost
```

El emulador puede comunicarse con servicios locales mediante `adb reverse`,
que ejecutan los scripts del proyecto. Un teléfono físico no puede usar
`localhost`: deberá recibir una URL HTTPS o una dirección/nombre accesible en
la LAN para la API.

Las instrucciones oficiales para Android confirman el uso de Platform 36,
`ANDROID_HOME`, Platform-Tools y `adb`: [guía Expo para Android
Studio](https://docs.expo.dev/workflow/android-studio-emulator/). Consulta el
[catálogo de Expo SDK 54](https://docs.expo.dev/versions/v54.0.0/) antes de
modificar React Native, React o paquetes `expo-*`.

## 7. Validación después de instalar

Ejecuta estas comprobaciones desde `PT_HS`:

```powershell
npm.cmd --prefix BK_HS run check
npm.cmd --prefix BK_HS test
npm.cmd --prefix FT_HS/frontend run lint
npm.cmd --prefix FT_HS/frontend run typecheck
npm.cmd --prefix FT_HS/frontend run build
```

Para los comandos diarios, diagnóstico de contenedores y pruebas de integración
consulta [Operación local](operacion-local.md) y [Pruebas](pruebas.md).
