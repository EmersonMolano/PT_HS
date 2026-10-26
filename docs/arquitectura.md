# Arquitectura

```text
ESP32 ──BLE──> navegador ──HTTPS/API──> frontend React
  │                                     │
  └──Wi-Fi/MQTT──> Mosquitto ──> backend Express ──> PostgreSQL
                                  │
                                  └──> reportes, alertas y auditoría
```

## Capas y responsabilidades

| Capa | Responsabilidad principal |
| --- | --- |
| ESP32 | Lee pulsos, calcula caudal/consumo, conserva Wi-Fi en NVS, anuncia BLE cuando no está vinculado y publica MQTT. |
| MQTT | Transporta telemetría, estados de conexión y comandos de vinculación/desvinculación. |
| Backend | Autentica, verifica permisos, procesa MQTT, coordina hogares y dispositivos, genera reportes. |
| PostgreSQL | Guarda datos operativos; las migraciones Liquibase, funciones y RLS son la fuente de verdad de persistencia. |
| Frontend | Presenta datos y realiza llamadas a la API. La configuración BLE se ejecuta desde el navegador compatible. |
| Móvil | Empaqueta la experiencia web en un cliente Expo/React Native y añade el puente BLE nativo. |

## Flujos principales

1. El usuario inicia sesión; la API coloca cookies `HttpOnly` de sesión y una
   cookie CSRF. El frontend no almacena JWT en `sessionStorage`.
2. Un propietario vincula un código lógico preasignado a su hogar. El ESP32
   informa su `hardwareId` y el backend confirma la asociación por MQTT.
3. Mientras no hay hogar asociado, el ESP32 ofrece BLE para recibir Wi-Fi y el
   host MQTT. Tras `confirm_link`, conserva la red, detiene BLE y publica cada
   cinco segundos.
4. El backend normaliza cada mensaje MQTT, deduplica por `mqttMessageId` y lo
   inserta mediante la ruta de ingesta autorizada.
5. Dashboard, consumo, alertas y reportes consultan la API; el backend aplica
   permisos y el contexto de usuario llega a PostgreSQL para RLS.
6. Al desvincular, el backend publica `unlink`; el ESP32 vuelve a habilitar BLE
   sin olvidar la red Wi-Fi guardada.

## Decisiones vigentes

- No se solicita IP manual al usuario final: el firmware recibe un host MQTT
  de red estable durante el aprovisionamiento.
- `hardwareId` identifica físicamente la placa; `deviceCode` identifica el
  dispositivo lógico y es el que se vincula a un hogar.
- Docker se usa para la pila local. PostgreSQL y la API se exponen solo en
  `localhost`; el frontend consume la API por Nginx.
- Web y móvil comparten el código de la aplicación; el móvil requiere una
  compilación de desarrollo para funciones nativas como BLE.
