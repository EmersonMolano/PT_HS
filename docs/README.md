# Documentación integral de HidroSmart

Esta carpeta es el índice de documentación transversal del repositorio. El estado
comprobado a la fecha está en `estado-integral.md`; los documentos específicos
conservan el detalle técnico de cada proyecto.

## Fuente de verdad

- [Estado verificado vigente — 2026-09-26](./estado-verificado-2026-09-26.md)

- [Plan de integracion IoT y claim de hardware](./iot/PLAN_INTEGRACION_IOT_BACKEND_FRONT_BD_HIDROSMART.md)

- [MQTT del ESP32 en la red local](./mqtt-esp32-red-local.md)

- [Guía de integración de una válvula DC de 12 V con el ESP32](./electrovalvula-esp32.md)

- [Vinculacion del ESP32 por hardwareId y broker sin IP manual](./iot/vinculacion-por-hardware-id.md)

- [Integración ESP32, BD, backend y frontend](./integracion-esp32-bd-backend-front.md)

- [Estado integral, evidencias y pendientes](./estado-integral.md)
- [Auditoria vigente del 2026-09-23](./auditoria-estado-2026-09-23.md)
- [Validación reproducible de integración](./validacion-integracion.md)
- [Cambios verificados del 2026-09-14](./cambios-2026-09-14.md)
- [Bitácora anterior del 2026-09-13](./cambios-2026-09-13.md)
- [README de ejecución en Docker](../README.md)
- [Guía para levantar BD, backend, frontend o toda la pila](./guia-ejecucion-local.md)
- [Dependencias e instalación de BD, backend y frontend](./dependencias-bd-bk-ft.md)
- [Documentación de la base de datos](../BD_HS/docs/README.md)
- [Documentación del backend](../BK_HS/docs/README.md)
- [Documentación del frontend](../FT_HS/docs/README.md)
- [Estructura agrupada Web + Mobile](../FT_HS/frontend/README.md)
- [Documentación del firmware](../firmware/README.md)

## Regla de actualización

Cuando un documento conceptual difiera del código o de una verificación reciente,
prevalecen, en este orden:

1. el código y las migraciones aplicadas;
2. los resultados de las verificaciones reproducibles;
3. `estado-integral.md`;
4. los documentos de arquitectura y guías históricas.

Las credenciales reales permanecen únicamente en archivos `.env` locales y no se
copian a esta documentación.
