# MQTT del ESP32 en la red local

## Propósito

El frontend no debe pedir una IP al usuario. El host MQTT queda una sola vez en
los archivos `.env` del proyecto y se envía automáticamente al ESP32 por BLE.
Puede ser la IPv4 LAN actual del PC o, como mejora futura, un nombre DNS estable
como `hidrosmart-broker.local`.

Hay dos hosts distintos y no se pueden intercambiar:

| Variable | Consumidor | Valor local |
|---|---|---|
| `MQTT_BROKER_URL` | Backend dentro de Docker | `mqtt://mosquitto:1883` |
| `MQTT_DEVICE_HOST` | ESP32 conectado al Wi-Fi | `192.168.1.10` o un DNS LAN |

`mosquitto` es el nombre del contenedor Docker. El ESP32 está fuera de Docker,
así que nunca puede usarlo como host MQTT.

## Configuración local inmediata

Para desarrollo local usa la IPv4 LAN del PC en ambos archivos:

```dotenv
# .env, Compose integrado
MQTT_DEVICE_HOST=192.168.1.10
MQTT_DEVICE_PORT=1883

# FT_HS/frontend/.env, Vite directo
VITE_MQTT_DEVICE_HOST=192.168.1.10
VITE_MQTT_DEVICE_PORT=1883
```

No se muestra ni se pide esa IP al usuario: al guardar la Wi-Fi, el frontend la
incluye en el payload BLE y el ESP32 la conserva en NVS. Si la red asigna otra
IP al PC, solo se actualizan esos dos valores y se reenvía la configuración una
vez por Bluetooth.

## Configuración estable del router (opcional)

1. Reserva por DHCP la dirección del PC o servidor que ejecuta HidroSmart.
2. Crea en el DNS local del router el registro `hidrosmart-broker.local` hacia
   esa reserva. Si tu router ofrece otro nombre local, úsalo en su lugar.
3. Asegura que el puerto TCP `1883` esté permitido desde la misma red Wi-Fi.
4. Sustituye la IP de los dos `.env` por ese mismo nombre:

   ```dotenv
   # .env, para el Compose integrado
   MQTT_DEVICE_HOST=hidrosmart-broker.local
   MQTT_DEVICE_PORT=1883

   # FT_HS/frontend/.env, para Vite ejecutado directamente
   VITE_MQTT_DEVICE_HOST=hidrosmart-broker.local
   VITE_MQTT_DEVICE_PORT=1883
   ```

5. Reconstruye el frontend y vuelve a enviar la red Wi-Fi por Bluetooth. El
   frontend transmite el host y puerto de forma automática; no se muestran ni
   se solicitan al usuario.

   ```powershell
   docker compose --env-file .env up -d --build frontend
   ```

El ESP32 guarda el host con su perfil Wi-Fi en NVS. Si falta la variable
`VITE_MQTT_DEVICE_HOST`, el frontend bloquea el envío en vez de guardar un host
anterior de forma silenciosa.

## Verificación

Desde el PC, antes de aprovisionar, confirma que el broker está publicado:

```powershell
docker compose --env-file .env ps mosquitto
Test-NetConnection localhost -Port 1883
```

Después de configurar DNS en el router, un móvil conectado a la misma Wi-Fi y
el ESP32 deben poder resolver `hidrosmart-broker.local`. Cuando el dispositivo
publique, el backend debe mostrar `MQTT_CONNECTED` y crear lecturas en
`sensor_reading`.

## Producción

Usa un dominio DNS real, MQTT sobre TLS, credenciales únicas por dispositivo y
ACL por topic. No expongas el puerto 1883 anónimo a Internet.
