# Guía operativa de dispositivos IoT

Última revisión del código: 2026-10-15. Esta guía describe el flujo implementado; no sustituye una prueba física del ESP32.

## Identidades: no confundir

| Identidad             | Para qué sirve                                               | Dónde se configura                                                            |
| --------------------- | ------------------------------------------------------------ | ----------------------------------------------------------------------------- |
| `code` / `deviceCode` | Identifica el registro lógico y forma los topics MQTT.       | En PostgreSQL y en la configuración privada `firmware/provisioning/config.h`. |
| `hardwareId`          | Identifica la placa física; el firmware lo deriva del eFuse. | Lo detecta BLE y el frontend lo reclama para el dispositivo lógico.           |

La base de datos incluye tres códigos lógicos reservados en `BD_HS/02_dml/03_upserts/001_preassigned_esp32_device_codes.sql`. No son los `hardwareId` físicos. Para una placa preasignada, configura en `config.h` el código reservado que le corresponde; no reutilices el mismo en dos placas. Si `HIDROSMART_DEVICE_CODE` queda vacío, el firmware usa como código lógico su propio `hardwareId`, que debe existir en la base antes de intentar vincularlo.

## Flujo de primera vinculación

1. Inicia Docker, aplica las migraciones y confirma que el código lógico del equipo exista en la base.
2. Inicia sesión como titular del hogar, selecciona el hogar y abre **Dispositivos IoT → Vincular dispositivo**. La interfaz actual vincula por `code`, no por `hardwareId`.
3. Escribe el código lógico exacto que usa el firmware. La API valida el hogar y publica `confirm_link` cuando corresponde.
4. Abre **Configurar** en la tarjeta. Con una compilación que soporte BLE, el frontend detecta el `hardwareId` y lo asocia al registro lógico.
5. Envía SSID y contraseña Wi-Fi por BLE. El host y puerto MQTT se toman del entorno del frontend; no se escriben en PostgreSQL ni se solicitan como campos al usuario.
6. El ESP32 se conecta a Wi-Fi y al broker y publica telemetría cada cinco segundos. El backend valida el código/topic y persiste las lecturas en PostgreSQL.

El `hardwareId` y el `deviceCode` pueden ser distintos. Si el firmware publica con un código distinto del que se vinculó, el backend no asociará correctamente el mensaje al dispositivo esperado.

### Límite de Expo Go

Expo Go permite abrir y revisar la aplicación móvil, pero no incluye `react-native-ble-plx`. El aprovisionamiento BLE debe probarse desde Chrome/Edge compatible con Web Bluetooth o con una compilación nativa de desarrollo de HidroSmart. La simulación MQTT no reemplaza esa prueba física.

## Cambiar un dispositivo a otro hogar

Una placa debe trasladarse como una operación explícita:

1. En el hogar actual, el titular pulsa **Desvincular dispositivo**.
2. El backend elimina la relación con ese hogar y publica `unlink`. El firmware conserva Wi-Fi y el código lógico, borra el estado de asociación y vuelve a anunciar BLE.
3. Selecciona el nuevo hogar y vincula el mismo código lógico disponible.
4. Confirma que el estado vuelva a **En línea** y que lleguen lecturas bajo el mismo topic.

No registres un segundo código para la misma placa durante el traslado. Si solo cambia el hogar y la red Wi-Fi sigue siendo la misma, normalmente no es necesario volver a enviar las credenciales.

## Desvincular no es eliminar

- **Desvincular** quita la relación hogar-dispositivo y solicita sincronizar el estado por MQTT. Conserva el registro, código lógico, Wi-Fi guardado e historial.
- **Eliminar** es una operación distinta y destructiva: el backend solo la permite cuando el dispositivo no está vinculado a ningún hogar. La función SQL elimina también el historial asociado.

Primero desvincula de todos los hogares; elimina solo si realmente se quiere retirar el equipo y sus datos históricos.

## Comprobación de telemetría

Desde la raíz del proyecto, observa mensajes del broker local:

```powershell
docker compose exec mosquitto mosquitto_sub -h localhost -p 1883 -t "hidrosmart/devices/+/telemetry" -v
```

Durante una prueba de unos 20 segundos deberían verse varias publicaciones separadas aproximadamente cinco segundos. Verifica que el segmento del topic coincida exactamente con `deviceCode` y que cada lectura use un `mqttMessageId` único; al reintentar el mismo mensaje, se conserva su ID para evitar duplicados.

El contrato completo de topics, telemetría, estado y comandos está en [`../firmware/mqtt/contract.md`](../firmware/mqtt/contract.md). La prueba automatizada contra recursos de prueba se ejecuta con:

Configura primero las variables `SIM_OWNER_LOGIN`, `SIM_OWNER_PASSWORD`, `SIM_HOME_ID` y `SIM_DEVICE_CODE` descritas en [Pruebas y validación](pruebas.md).

```powershell
npm.cmd --prefix BK_HS run simulate:iot
```

No uses esa simulación con un hogar/dispositivo real: modifica asociaciones y genera lecturas.

## Fallos comunes

| Síntoma                             | Revisar                                                                                                                                                 |
| ----------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| No encuentra el código al vincular  | Que la migración de códigos reservados se haya aplicado o que el dispositivo se haya registrado antes. Compara `code` con el publicado por el firmware. |
| BLE no aparece en Expo Go           | Es una limitación de Expo Go; prueba Web Bluetooth compatible o una compilación nativa.                                                                 |
| El ESP32 no resuelve el broker      | Revisa `MQTT_DEVICE_HOST`: debe resolver desde la Wi-Fi del ESP32; `localhost` y `mosquitto` no sirven para una placa física.                           |
| Hay conexión MQTT, pero no lecturas | Comprueba el topic, `deviceCode`, formato del payload, `mqttMessageId`, asociación activa y logs del backend.                                           |
| El traslado no activa la placa      | Confirma que el comando `unlink` llegó o que el ESP32 vuelva a conectarse al broker para sincronizar el estado.                                         |

## Rutas API relacionadas

La sesión autenticada del frontend llama a estas rutas; la autorización efectiva se vuelve a validar en backend y PostgreSQL:

| Acción                                          | Ruta                                              |
| ----------------------------------------------- | ------------------------------------------------- |
| Vincular código existente a un hogar            | `POST /api/v1/devices/link`                       |
| Listar dispositivos visibles                    | `GET /api/v1/devices?homeId=...`                  |
| Consultar por hardware                          | `GET /api/v1/devices/hardware/{hardwareId}`       |
| Asociar hardwareId al registro                  | `POST /api/v1/devices/{deviceId}/claim-hardware`  |
| Actualizar estado BLE/MQTT de aprovisionamiento | `PATCH /api/v1/devices/{deviceId}/provisioning`   |
| Consultar última lectura                        | `GET /api/v1/devices/{deviceId}/telemetry/latest` |
| Desvincular del hogar                           | `DELETE /api/v1/devices/{deviceId}/home/{homeId}` |
| Eliminar después de desvincular                 | `DELETE /api/v1/devices/{deviceId}`               |
