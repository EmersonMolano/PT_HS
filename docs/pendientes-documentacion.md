# Documentación pendiente y evidencias

Este listado separa las guías existentes de la evidencia que todavía no se ha
obtenido. No marques una prueba como completada solo porque pasó un comando
local o una simulación. Fecha de revisión: 18 de octubre de 2026.

## Prioridad alta: antes de aprobar el despliegue

1. **Despliegue Cloudflare Pages + Render.** Crear una guía con rama y commit
   desplegados, directorio raíz y comando de build, `VITE_API_URL`, `CORS_ORIGIN`,
   `FRONTEND_URL`, `TRUST_PROXY_HOPS`, atributos de cookies y ruta de proxy/API.
   No copiar valores secretos. Añadir una prueba en Chrome y otro navegador de
   login → recarga → refresh → logout, con capturas de cabeceras redactadas.
   Criterio de cierre: las cookies llegan y vuelven en las solicitudes; CSRF
   funciona sin desactivarlo. Si los dominios distintos bloquean cookies de
   terceros, documentar y verificar un proxy o dominios bajo el mismo sitio.
2. **E2E por rol.** Ampliar [pruebas.md](pruebas.md) con casos reproducibles para
   Owner, Guest y Administrator: permisos, hogar, vínculo/desvínculo, consumo,
   PDF/Excel, alertas, soporte y cierre de sesión. Registrar entorno, datos
   ficticios, resultado y evidencia; no usar cuentas reales.
3. **Recuperación PostgreSQL.** [respaldo-postgresql.md](respaldo-postgresql.md)
   explica el procedimiento. Falta adjuntar un registro de una restauración
   ejecutada en una base aislada: fecha, versiones, comando sin contraseñas,
   tiempo, conteos/consultas de validación y resultado. No subir el respaldo.
4. **Matriz de variables de despliegue y secretos.** Documentar por entorno
   quién configura cada variable de Render/Cloudflare/MQTT/Neon/Brevo, cuál es
   obligatoria y cómo se verifica sin imprimir su valor. Incluir rotación de
   claves filtradas y revocación de sesiones expuestas. No publicar `.env` real.

## Prioridad media: calidad y mantenimiento

5. **Contrato OpenAPI completo.** [openapi.yaml](../BK_HS/docs/openapi.yaml)
   inventaría rutas, pero la mayoría todavía usa una respuesta genérica.
   Añadir esquemas de request/response, parámetros, errores 400, 401, 403,
   409 y 429, ejemplos redactados y permisos, empezando por autenticación,
   dispositivos y hogares. Comparar cada ejemplo con controladores y pruebas.
6. **Carga real y observabilidad.** La simulación de 300 clientes de
   [pruebas.md](pruebas.md) no crea usuarios ni usa la base de datos. Diseñar
   un ensayo en entorno aislado con cuentas ficticias, duración, concurrencia,
   límites aceptables (p95, errores, CPU, memoria, pool PostgreSQL) y plan de
   limpieza. Registrar resultados y versión del código.
7. **Móvil y ESP32 físicos.** Completar [04_mobile.md](../FT_HS/docs/04_mobile.md)
   e [iot.md](iot.md) con una matriz de teléfonos/Android/Expo Go probados y
   una prueba nativa BLE separada: emparejamiento, Wi-Fi, MQTT, telemetría cada
   cinco segundos, pérdida de red, desvinculación y retorno de BLE. Anotar
   versión de firmware y calibración del caudalímetro.
8. **Registro de riesgo de dependencias.** Mantener por paquete/advisory los 15
   hallazgos altos del frontend, su alcance (build, móvil o web), versión
   instalada, corrección compatible con SDK 57, decisión y fecha de revisión.
   No afirmar que `npm audit fix --force` es una solución validada.
9. **Correo transaccional.** Crear un procedimiento breve para verificar Brevo
   sin exponer claves: remitente autorizado, variables requeridas, prueba de
   envío con destinatario de prueba, consulta de logs de proveedor y respuesta
   ante fallo. Distinguir aceptación HTTP del envío de entrega en bandeja.

## Regla de cierre

Cada evidencia debe indicar fecha, rama/commit, entorno, comando o pasos,
resultado esperado y real, y ubicación de logs o capturas redactados. Una
prueba pendiente se documenta como pendiente, no como aprobada. Cuando se
cierre un punto, actualizar también [estado-actual.md](estado-actual.md) y el
documento del componente correspondiente.
