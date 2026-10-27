# Configurar el host MQTT para el ESP32

## Hay dos destinos MQTT distintos

| Variable                                | Quién la usa                                      | Ejemplo local                     |
| --------------------------------------- | ------------------------------------------------- | --------------------------------- |
| `MQTT_BROKER_URL`                       | Backend dentro de Docker.                         | `mqtt://mosquitto:1883`           |
| `MQTT_DEVICE_HOST` y `MQTT_DEVICE_PORT` | ESP32 en la Wi-Fi; el frontend los envía por BLE. | `hidrosmart-broker.local`, `1883` |

`mosquitto` es un nombre interno de Docker; `localhost` apunta al propio dispositivo cuando se usa desde el ESP32. Ninguno de los dos sirve como dirección de la placa hacia el broker.

## Fuente de configuración

Para Docker, define una sola vez en el `.env` de la raíz:

```dotenv
MQTT_DEVICE_HOST=hidrosmart-broker.local
MQTT_DEVICE_PORT=1883
MQTT_BROKER_URL=mqtt://mosquitto:1883
```

Compose entrega `MQTT_DEVICE_HOST` y `MQTT_DEVICE_PORT` como variables de construcción del frontend. La preparación móvil también toma esos valores del `.env` raíz. Las variables MQTT definidas en el proceso tienen prioridad; si no existe configuración raíz, el bundle usa los valores `VITE_*` locales del frontend. Así no hace falta duplicar el host y puerto en `FT_HS/frontend/.env` para el flujo normal.

Si ejecutas Vite directamente desde `FT_HS/frontend`, puedes usar estas variables locales como excepción o sobreescritura:

```dotenv
VITE_MQTT_DEVICE_HOST=hidrosmart-broker.local
VITE_MQTT_DEVICE_PORT=1883
```

El host es información pública del cliente compilado, no pongas contraseñas en variables `VITE_*`.

## Evitar una IP manual

El nombre `hidrosmart-broker.local` solo funciona si el router o un DNS/mDNS de la red lo resuelve hacia el equipo que publica Mosquitto. Para que la dirección no cambie:

1. Reserva por DHCP la dirección del PC/servidor que ejecuta Docker.
2. Configura en el router un nombre local, por ejemplo `hidrosmart-broker.local`, asociado a esa reserva.
3. Permite el puerto TCP `1883` entre la Wi-Fi del ESP32 y el host.
4. Comprueba el nombre desde la misma red antes de provisionar la placa.

Si la red no ofrece DNS local, se puede usar una IP LAN fija/reservada en `MQTT_DEVICE_HOST`; no se pide al usuario en la pantalla, pero esa IP debe mantenerse estable.

## Aplicar cambios

Después de modificar el `.env` raíz, reconstruye el frontend para que el host quede incluido en el bundle web:

```powershell
docker compose --env-file .env up -d --build frontend
```

Para Expo Go, desde otra terminal:

```powershell
Set-Location FT_HS/frontend
npm.cmd run mobile:start
```

El comando prepara el bundle con los valores del `.env` raíz. La API móvil usa la LAN detectada por el script; es un destino separado del host MQTT que recibe el ESP32. Expo Go no incluye BLE, así que esta ejecución no habilita aprovisionamiento Bluetooth.

## Verificar la red

```powershell
docker compose --env-file .env ps mosquitto
Test-NetConnection hidrosmart-broker.local -Port 1883
```

Después de aprovisionar, revisa los topics y el estado desde el broker:

```powershell
docker compose exec mosquitto mosquitto_sub -h localhost -p 1883 -t "hidrosmart/devices/+/status" -v
docker compose exec mosquitto mosquitto_sub -h localhost -p 1883 -t "hidrosmart/devices/+/telemetry" -v
```

## Límite de seguridad del perfil local

El Mosquitto del Compose de desarrollo permite conexiones anónimas y usa el puerto sin TLS. Definir `MQTT_USERNAME` y `MQTT_PASSWORD` en el backend no convierte automáticamente ese broker en un broker autenticado, ni configura credenciales del ESP32. No publiques este perfil en Internet. Producción requiere usuario por dispositivo, ACL por topic, TLS y certificados configurados en el broker y el firmware.

El firmware incluye un perfil TLS para Flespi en el puerto `8883`. Consulta la
[guía HU-16](hu-16-alertas-web-mqtt-despliegue.md) y el
[README del firmware](../firmware/README.md) para preparar un token ACL por
placa. La conexión física aún debe validarse con los tokens y el ESP32 reales.
