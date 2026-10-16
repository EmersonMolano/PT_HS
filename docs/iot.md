# Dispositivos IoT y ESP32

Para el ciclo detallado de vincular, cambiar de hogar, desvincular y verificar
un equipo, consulta la [guía operativa de dispositivos](dispositivos-iot.md).
La configuración del host que el frontend envía por BLE está en
[MQTT del ESP32 en la red local](mqtt-esp32-red-local.md).

> El firmware actual mide y publica telemetría; aún no controla una válvula.
> Antes de añadir esa función, sigue la [guía de integración segura de una
> válvula de 12 V](electrovalvula-esp32.md).

## Identidades

Cada placa conserva un `hardwareId` inmutable derivado del eFuse, con formato
`HS-XXXXXXXXXXXX`. El código lógico (`deviceCode`) identifica el registro que
se vincula a un hogar y se usa en los topics MQTT. No se deben reutilizar
códigos entre placas.

Códigos preasignados para pruebas:

```text
HS-7A3F91C8D2E4
HS-B6E04D79A153
HS-2C8A5F01E7B9
```

## Flujo de vinculación

1. El propietario escribe el código lógico en **Vincular dispositivo**.
2. Si el ESP32 no pertenece a un hogar, anuncia BLE aunque tenga Wi-Fi guardado.
3. El navegador se conecta por BLE y envía SSID, contraseña Wi-Fi, host/puerto
   MQTT y, cuando corresponde, el código lógico.
4. El ESP32 guarda la configuración en NVS, se conecta a Wi-Fi y comunica su
   estado por BLE y MQTT.
5. El backend asocia el `hardwareId`, vincula el dispositivo al hogar y publica
   `confirm_link`.
6. El ESP32 conserva Wi-Fi, detiene BLE y empieza a publicar telemetría cada
   cinco segundos.

Si se desvincula, el backend publica `unlink`. La placa elimina solo el estado
de asociación, vuelve a anunciar BLE y conserva las redes guardadas.

## Aprovisionamiento BLE

| Elemento | Valor |
| --- | --- |
| Servicio | `4fafc201-1fb5-459e-8fcc-c5c9c331914b` |
| Característica de configuración | `beb5483e-36e1-4688-b7f5-ea07361b26a8` |
| Característica de estado | `beb5483e-36e1-4688-b7f5-ea07361b26a9` |
| Nombre anunciado | `HidroSmart-XXXXXX` |

Ejemplo de configuración que recibe el ESP32:

```json
{
  "ssid": "RED_WIFI",
  "password": "CLAVE_WIFI",
  "mqttHost": "hidrosmart-broker.local",
  "mqttPort": 1883,
  "deviceCode": "HS-7A3F91C8D2E4"
}
```

El host debe ser un nombre DNS/mDNS estable o una reserva DHCP administrada;
no se pide una IP manual al usuario. `localhost` y `mosquitto` no sirven para
una placa física fuera de Docker.

## MQTT

Topics principales:

```text
hidrosmart/devices/{deviceCode}/telemetry
hidrosmart/devices/{deviceCode}/status
hidrosmart/devices/{deviceCode}/commands
```

La telemetría incluye `mqttMessageId`, `hardwareId`, `timestamp`,
`flowRateLpm`, `consumptionLiters`, `totalLiters`, `pulses` y calidad Wi-Fi.
`mqttMessageId` debe mantenerse en un reintento para que el backend no duplique
la lectura. El contrato completo está en
[firmware/mqtt/contract.md](../firmware/mqtt/contract.md).

## Prueba física de cinco segundos

1. Compila y carga el firmware con `pio run -t upload --upload-port COMx`.
2. Vincula uno de los códigos preasignados desde la web.
3. Configura Wi-Fi por BLE y confirma que MQTT se conecta.
4. Espera tres publicaciones (aproximadamente 15 segundos) y revisa dashboard,
   telemetría reciente y consumo.
5. Desvincula desde la web y confirma que BLE vuelve a anunciarse.

El script `npm.cmd --prefix BK_HS run simulate:iot` automatiza el flujo contra
recursos de prueba; consulta [pruebas.md](pruebas.md) antes de ejecutarlo.
