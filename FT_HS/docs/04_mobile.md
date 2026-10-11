# 04_mobile: Expo, WebView y aprovisionamiento BLE

## Propósito

La aplicación móvil reutiliza la interfaz web empaquetada y la muestra en un
WebView de React Native. El código nativo se mantiene pequeño: estado visual,
conectividad del WebView y aprovisionamiento BLE de un ESP32 desde Android.

## Archivos de src/mobile

- **App.jsx:** arranca el contenedor React Native y configura la barra de navegación Android.
- **AppStatusBar.jsx:** ajusta la barra de estado nativa de la aplicación.
- **HidroSmartWebView.jsx:** carga el bundle web, expone mensajes nativos y gestiona errores del WebView.
- **MobileShell.jsx:** aplica el contenedor visual nativo de la aplicación.
- **WebViewLoading.jsx:** muestra carga y recuperación mientras se inicializa el WebView.
- **webView.js:** resuelve la URL o bundle que cargará el WebView según el entorno.
- **colors.js:** centraliza colores usados por el shell nativo.
- **layout.js:** centraliza constantes de distribución para el shell nativo.
- **bleProvisioning.js:** implementa escaneo, conexión, lectura de estado y envío de Wi-Fi/MQTT por BLE nativo.
- **webBundle.js:** implementa FT HS/frontend/src/mobile/web Bundle.

## Flujo BLE

1. bleProvisioning solicita permisos Android y verifica que Bluetooth esté
   encendido.
2. Escanea dispositivos cuyo nombre comienza por HidroSmart-.
3. Conecta, descubre el servicio GATT y lee o monitoriza el estado.
4. Envía SSID, contraseña, host MQTT, puerto y código lógico como JSON Base64.
5. El ESP32 guarda la red, intenta MQTT y apaga BLE tras completar el
   aprovisionamiento.

Los UUID deben mantenerse alineados con firmware/mqtt/contract.md y el
firmware cargado en la placa.

## Android generado

La carpeta android es el proyecto nativo generado por Expo. Incluye
MainActivity.kt, MainApplication.kt, manifests, reglas ProGuard, Gradle,
recursos de icono y splash por densidad, y configuraciones de color/tema.
No se debe editar manualmente salvo una necesidad nativa justificada: los
cambios normales se definen en app.json y se regeneran con Expo prebuild.

## Scripts móviles

- **prepare-mobile-bundle.mjs:** compila la web con Vite y copia el bundle que
  consumirá Expo.
- **run-android.mjs:** ejecuta Android, detecta el emulador y configura los
  reenvíos ADB requeridos.
- **index.js:** registra la entrada Expo de la aplicación.
- **metro.config.cjs:** configura Metro para resolver el bundle y recursos.
