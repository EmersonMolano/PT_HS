# Auditoria del frontend y su integracion

Fecha de verificacion: **2026-09-23**.

## Estado comprobado

- El frontend se sirve en `http://localhost:5173`.
- En Docker usa `VITE_API_URL=/api/v1` y el proxy Nginx dirige las llamadas al
  backend.
- No se conecta directamente a PostgreSQL ni a Mosquitto.
- Dashboard, Consumo, Dispositivos y Reportes consumen respuestas del backend;
  no deben dejar cifras visuales quemadas.
- Hogares usa carrusel horizontal.
- Administrador integra gestion de usuarios, auditoria y tickets de soporte.
- Las preferencias de notificaciones se gestionan dentro de Configuracion.
- Dispositivos permite nombre, tipo, ubicacion y umbral, y muestra metadatos de
  Wi-Fi no sensibles (`wifiSsid`, `lastIp`, RSSI, hardware y estado).
- La contraseña Wi-Fi solo se envia por BLE al ESP32; no viaja al backend ni a
  PostgreSQL.

## Flujo de datos IoT

```text
ESP32 -> Mosquitto -> backend -> PostgreSQL -> API HTTP -> frontend
```

El frontend consulta la ultima lectura persistida y el historial mediante API.
Si no existe una lectura, muestra estado vacio. En el corte actual la base tiene
0 dispositivos y 0 lecturas porque el ESP32 no esta conectado y las pruebas
limpian sus datos temporales.

## Rutas principales

| Pantalla | Fuente |
|---|---|
| `/app` | dashboard y consumo avanzado |
| `/app/homes` | hogares, miembros y solicitudes |
| `/app/devices` | dispositivos, provisionamiento, historial y actuadores |
| `/app/consumption` | resumen, series y costos |
| `/app/reports` | reportes PDF/Excel e historial |
| `/app/support` | tickets propios |
| `/app/support/management` | bandeja del Administrador |
| `/app/admin` y `/app/users` | administracion |

## Pendientes

- Pruebas manuales con un hogar, un dispositivo vinculado y telemetria real.
- Pruebas frontend automatizadas y E2E.
- Estados de carga, vacio y error uniformes en todas las vistas.
- Prueba BLE en Android/iOS real.
- Canal push SSE/WebSocket si el producto requiere tiempo real sin polling.
