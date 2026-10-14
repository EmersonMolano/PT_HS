# Documentación de HidroSmart

Esta carpeta contiene únicamente la documentación operativa vigente. Los
documentos históricos, auditorías con fecha y bitácoras antiguas se retiraron
para evitar que compitan con el código actual; el historial permanece en Git.

## Guías generales

| Documento | Uso |
| --- | --- |
| [Arquitectura](arquitectura.md) | Componentes, límites y flujos de datos. |
| [Operación local](operacion-local.md) | Levantar, detener y diagnosticar la pila Docker. |
| [IoT](iot.md) | Vinculación, BLE, Wi-Fi, MQTT y pruebas físicas del ESP32. |
| [Válvula de 12 V](electrovalvula-esp32.md) | Integración eléctrica segura y límites actuales del control físico. |
| [Seguridad](seguridad.md) | Sesión, CSRF, secretos y límites del entorno local. |
| [Pruebas](pruebas.md) | Calidad, integración, roles, simulación IoT y móvil. |
| [Respaldo PostgreSQL](respaldo-postgresql.md) | Backup, restauración y verificación. |
| [Estado actual](estado-actual.md) | Capacidades verificadas y trabajo pendiente. |

## Documentación por componente

- [Base de datos](../BD_HS/docs/README.md)
- [Backend](../BK_HS/docs/README.md)
- [Frontend y móvil](../FT_HS/docs/README.md)
- [Firmware ESP32](../firmware/README.md)

## Regla de mantenimiento

Si una guía contradice el proyecto, prevalece en este orden: migraciones y
código, pruebas ejecutables, archivos `.env.example` y, por último, esta
documentación. Toda modificación funcional debe ajustar el documento de su
componente y eliminar instrucciones que dejen de aplicar.
