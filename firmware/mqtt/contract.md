# Contrato MQTT del ESP32

## Grupo logico de una placa

El ESP32 de este grupo publica cada muestra en los cuatro IDs
`HS-7A3F91C8D2E4`, `HS-B6E04D79A153`, `HS-2C8A5F01E7B9` y
`HS-141F47470968`. El ID principal conserva el consumo en litros; los tres
alias guardan caudal y estado con consumo cero para que el total del hogar no
se cuente cuatro veces. Una vinculacion o desvinculacion actua sobre los
cuatro registros.

La ACL Flespi del ESP32 debe permitir publicar estado y telemetria para los
cuatro IDs y suscribirse a comandos para los cuatro. Solo el estado del ID
principal queda retenido para conservar el LWT; los estados de los alias son
en vivo. El backend conserva un token separado.

## Topics

```text
hidrosmart/devices/{deviceCode}/telemetry
hidrosmart/devices/{deviceCode}/status
hidrosmart/devices/{deviceCode}/commands
```

`deviceCode` es el código lógico de la placa. `hardwareId` continúa siendo la
identidad física inmutable y viaja en cada estado y lectura.

## Telemetría

Publicada cada cinco segundos por defecto en `telemetry`:

```json
{
  "mqttMessageId": "HS-7A3F91C8D2E4-123456-42",
  "deviceId": "HS-7A3F91C8D2E4",
  "hardwareId": "HS-141F47470968",
  "timestamp": "2026-10-11T12:00:00Z",
  "flowRateLpm": 2.4,
  "consumptionLiters": 0.2,
  "totalLiters": 3.4,
  "pulses": 18,
  "sampleIntervalSeconds": 5,
  "wifiRssiDbm": -56,
  "signalQuality": -56
}
```

No cambies `mqttMessageId` al reintentar exactamente la misma lectura. El
backend lo usa para evitar duplicados.

El cálculo predeterminado del YF-S201 es:

```text
flowRateLpm = (pulsos / segundos) / 7.5
consumptionLiters = flowRateLpm × segundos / 60
```

## Estado

El estado MQTT es retenido y contiene, entre otros, `deviceId`, `hardwareId`,
`status`, `provisioningState`, `timestamp`, `firmwareVersion`, `lastIp`,
`linkedToHome`, `bleLocked`, `ssid` y `wifiRssiDbm`.

El campo `status` utiliza `ONLINE` u `OFFLINE`. `provisioningState` expresa
`PENDING`, `BLE_READY`, `WIFI_CONNECTED`, `MQTT_CONNECTED` o `COMPLETE`.

## Comandos

El backend publica JSON en `commands`:

```json
{ "command": "confirm_link" }
```

| Comando | Efecto |
| --- | --- |
| `confirm_link` | Marca hogar asociado y detiene BLE. |
| `unlink` | Elimina asociación, conserva Wi-Fi y vuelve a anunciar BLE. |
| `enable_ble` | Habilita BLE para configuración. |
| `disable_ble` | Solo se acepta si la placa ya está asociada. |

## BLE

El servicio BLE usa `4fafc201-1fb5-459e-8fcc-c5c9c331914b`; la característica
de escritura de configuración es `beb5483e-36e1-4688-b7f5-ea07361b26a8` y la
de lectura/notificación de estado es `beb5483e-36e1-4688-b7f5-ea07361b26a9`.

Si MQTT no está disponible, el firmware conserva las redes guardadas y mantiene
BLE disponible mientras el dispositivo no esté asociado. `confirm_link` guarda
el bloqueo de BLE, cierra las conexiones GATT activas y detiene el anuncio;
`unlink` elimina la asociación y vuelve a anunciar BLE. Mantener BOOT durante
cinco segundos habilita la recuperación física local. El servicio BLE no usa
pairing ni PIN.

La configuración BLE admite `ssid`, `password`, `mqttHost`, `mqttPort` y
`deviceCode`. No incluye ni publica contraseñas MQTT; esas se compilan en
`config.h` cuando el broker las requiere.

Al cambiar solo el `deviceCode`, la app puede enviar `password` vacía porque
el firmware no devuelve la contraseña Wi-Fi por BLE. Si el SSID ya está
guardado, el ESP32 reutiliza la contraseña almacenada y mantiene la conexión
Wi-Fi existente cuando ya está conectado a esa red.

Para Flespi, el ESP32 usa MQTT sobre TLS en `mqtt.flespi.io:8883`, valida el
certificado con el CA público incluido en `provisioning/flespi_root_ca.h` y
autentica con un token ACL exclusivo para la placa. La contraseña MQTT puede
quedar vacía cuando el token se envía como usuario. Asigna ACL del dispositivo
solo a sus topics: publicar telemetría/estado propios y suscribirse a comandos
propios. El backend usa otro token con permisos de suscripción y publicación
limitados a sus funciones.
