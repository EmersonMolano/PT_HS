# Vinculación del ESP32 por hardwareId

## Flujo actual

El ESP32 genera una identidad física estable desde el eFuse, por ejemplo:

```text
HS-141F47470968
```

Ese valor es el `hardwareId`. El frontend lo guarda en PostgreSQL al registrar
el dispositivo y lo muestra en la tarjeta de **Dispositivos IoT**.

Cuando el ESP32 ya tiene una red Wi-Fi guardada, la pantalla no solicita IP,
host MQTT ni contraseña para vincularlo. El usuario solo debe ingresar el
`hardwareId` que aparece en el monitor serial o que reporta el estado MQTT.

Las operaciones disponibles son:

```http
POST /api/v1/devices
```

```json
{
  "homeId": "uuid-del-hogar",
  "hardwareId": "HS-141F47470968",
  "name": "Medidor principal",
  "type": "YF-S201",
  "alertThreshold": 10
}
```

Si no se envía otro código lógico, el backend usa temporalmente el
`hardwareId` como `deviceCode`. Esto permite que el ESP32 que publica con su
ID inicial sea reconocido inmediatamente por MQTT.

Para un dispositivo lógico que ya existe y solo falta asociar al hogar:

```http
POST /api/v1/devices/link
```

```json
{
  "homeId": "uuid-del-hogar",
  "hardwareId": "HS-141F47470968"
}
```

La base valida que el hardware sea único, que el usuario tenga permiso de
gestión y que sea propietario del hogar. Nunca se almacena la contraseña Wi-Fi
en PostgreSQL.

## IP y broker MQTT

La IP del ESP32 es un dato dinámico. El estado MQTT puede reportarla como
`lastIp`, pero no se debe usar como identidad ni pedirla en el formulario.

El formulario BLE ya no muestra host ni puerto MQTT. Si el payload no incluye
esos campos, el firmware conserva el perfil MQTT guardado en NVS o utiliza el
valor por defecto de `HIDROSMART_MQTT_HOST` y `HIDROSMART_MQTT_PORT`.

Para una instalación estable se recomienda, en este orden:

1. asignar una reserva DHCP al PC que ejecuta Mosquitto y usar un nombre local
   estable, por ejemplo `hidrosmart-broker.local`;
2. si el router no ofrece DNS local, mantener el host por defecto en el
   `config.h` privado del firmware, sin exponerlo en la interfaz;
3. para producción, usar un broker con DNS estable, autenticación y TLS.

Así el usuario solo configura la red Wi-Fi por BLE la primera vez y después
vincula el equipo con el `hardwareId`; la IP se observa automáticamente desde
los mensajes MQTT.
> Actualización 2026-09-26: durante el provisionamiento el frontend envía
> automáticamente `mqttHost` y `mqttPort` tomados de su `.env`; el formulario
> no permite ni requiere introducir una IP. Ver
> [`../mqtt-esp32-red-local.md`](../mqtt-esp32-red-local.md).
