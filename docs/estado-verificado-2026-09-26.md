# Estado verificado de HidroSmart — 2026-09-26

Este documento es el corte vigente. Las auditorías y bitácoras con fecha
anterior se conservan como evidencia histórica y pueden contener cifras de ese
momento, por ejemplo 239 cambiosets.

## Resultado de la verificación

| Área | Resultado | Evidencia |
|---|---|---|
| Docker | Cumple | PostgreSQL, backend, frontend y Mosquitto activos; backend saludable. |
| Base de datos | Cumple | Liquibase `status --verbose` indica `up to date`; 245 cambiosets y 58 tablas de aplicación. |
| Backend | Cumple | 174 pruebas unitarias aprobadas. |
| Frontend | Cumple | `lint`, `typecheck` y build de producción aprobados; HTTP 200 en `localhost:5173`. |
| Firmware | Cumple en compilación | PlatformIO compila correctamente; RAM 17.6 % y Flash 82.0 %. |
| MQTT local | Cumple | Mosquitto escucha en TCP 1883 en IPv4 e IPv6 y el backend está saludable. |
| Datos locales | Existen | 2 dispositivos y 3,245 lecturas persistidas en PostgreSQL al cierre de la prueba. |

## Provisionamiento MQTT sin pedir IP al usuario

El requisito funcional se cumple en código y en la configuración local:

1. `.env` guarda `MQTT_DEVICE_HOST` y `MQTT_DEVICE_PORT`.
2. `FT_HS/frontend/.env` guarda los equivalentes públicos
   `VITE_MQTT_DEVICE_HOST` y `VITE_MQTT_DEVICE_PORT`.
3. Al enviar Wi-Fi por Bluetooth, el frontend envía `ssid`, `password`,
   `mqttHost`, `mqttPort` y `deviceCode` automáticamente.
4. El ESP32 guarda el host y puerto en NVS junto con el perfil Wi-Fi.
5. El formulario no muestra ni solicita una IP del PC al usuario.

La configuración local vigente usa `192.168.1.10:1883`. Si la dirección LAN
del PC cambia, se actualizan ambos `.env`, se reconstruye el frontend y se
envía nuevamente la configuración Wi-Fi por Bluetooth. La alternativa estable
es usar una reserva DHCP más un DNS local; el procedimiento está en
[MQTT del ESP32 en la red local](./mqtt-esp32-red-local.md).

## Cumplimiento y límites abiertos

| Requisito | Estado | Qué falta para cerrarlo |
|---|---|---|
| Backend, frontend y base integrados | Cumple | Nada para el entorno local actual. |
| Migraciones y estructura de BD | Cumple | Nada: Liquibase está al día. |
| Telemetría MQTT persistida | Cumple | Pruebas reales: mensajes consecutivos cada ~5 s, todos persistidos en PostgreSQL, tanto en reposo como con agua circulando. |
| Sin IP manual en interfaz | Cumple | La IP queda solo en configuración técnica `.env`. |
| IP del PC completamente transparente a cambios | Parcial | Configurar reserva DHCP y DNS local, o usar broker con dominio estable. |
| MQTT seguro para producción | No cumple aún | Autenticación, ACL por dispositivo, TLS y rotación de credenciales. |
| Hardware físico YF-S201 | Pendiente | Confirmar adaptación de señal para no aplicar 5 V al GPIO y calibrar caudal. |
| Alertas reales | Pendiente | Probar los cinco tipos de alerta con datos físicos y periodo de vacaciones. |
| Tiempo real push | Pendiente | Implementar SSE o WebSocket; actualmente hay polling HTTP cada 5 segundos. |
| Calidad frontend | Parcial | Añadir pruebas de componentes/E2E, accesibilidad, prueba móvil y reducir el chunk principal (>500 kB). |
| Operación | Pendiente | Backup/restore reproducible e instalación limpia. |

## Comandos de control

```powershell
docker compose --env-file .env ps
docker compose --env-file .env --profile tooling run --rm liquibase status --verbose
Test-NetConnection localhost -Port 1883
```

Pruebas físicas completadas el 2026-09-26 para el ESP32 `HS-141F47470968`:

- En reposo, seis mensajes consecutivos entre 20:39:32Z y 20:39:57Z, con
  intervalo cercano a 5 s, se persistieron sin duplicados.
- Con agua circulando, cinco mensajes consecutivos entre 21:48:38Z y
  21:48:58Z registraron entre 11.191 y 16.244 L/min, entre 420 y 610 pulsos
  por intervalo y entre 0.93333 y 1.35556 L por muestra. PostgreSQL incrementó
  exactamente cinco lecturas durante esa captura.
- La última evidencia persistida mantiene `ONLINE`, `MQTT_CONNECTED`, 12.332
  L/min, 463 pulsos, 1.029 L del intervalo, 30.822 L acumulados y RSSI -48 dBm.

El siguiente control es calibrar el caudal con un volumen conocido (por ejemplo
10 L medidos en un recipiente) para ajustar el factor del sensor si difiere.
