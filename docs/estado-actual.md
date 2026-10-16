# Estado actual

## Capacidades disponibles

- Gestión de usuarios, hogares, miembros, dispositivos, consumo, alertas,
  metas, vacaciones, soporte, auditoría, privacidad y reportes PDF/Excel.
- Autenticación mediante cookies `HttpOnly`, protección CSRF y autorización por
  permisos con RLS en PostgreSQL.
- Vinculación de ESP32 por código lógico y `hardwareId`, aprovisionamiento
  Wi-Fi/MQTT por BLE y telemetría MQTT cada cinco segundos.
- Desvinculación que reactiva BLE sin borrar la red Wi-Fi guardada.
- Web React/Vite y adaptador móvil Expo/React Native en el mismo proyecto.
- Docker local para PostgreSQL, migraciones Liquibase, Mosquitto, backend y
  frontend.

## Verificación local (15 de octubre de 2026)

- Backend: 180 pruebas unitarias aprobadas, revisión sintáctica de 217 archivos
  y `npm audit --omit=dev` sin vulnerabilidades.
- Frontend web: lint, typecheck y build aprobados.
- Móvil: dependencias alineadas con Expo SDK 57; `expo install --check` y
  exportación Android con Metro aprobadas. No se instaló en un teléfono ni se
  ejecutó una compilación nativa en esta verificación.
- Expo Doctor: 20/21 comprobaciones. La advertencia restante corresponde a
  `@expo/config-plugins`, requerido por el plugin de configuración BLE.
- Frontend: `npm test` termina correctamente, pero todavía no descubre pruebas.
  El audit muestra 15 hallazgos altos que se agrupan en `braces` y `node-forge`;
  al día de esta revisión sus avisos públicos no declaran versiones corregidas.
- La restauración PostgreSQL y `docker compose config` constan como verificadas
  en la revisión anterior; no se repitieron en esta ejecución.

## Pendiente antes de producción

1. Completar pruebas E2E de navegador con Owner, Guest y Administrator:
   permisos, hogares, vincular/desvincular, consumo, reportes, alertas y soporte.
   La integración del backend en CI no sustituye esta validación visual.
2. Ampliar las pruebas del frontend: hoy `npm test` no ejecuta ningún caso.
3. Ejecutar una prueba de carga reproducible con varios usuarios y telemetría
   simultánea, midiendo latencia, errores, conexiones y consumo de recursos.
4. Completar la prueba física del ESP32: aprovisionamiento, MQTT seguro,
   lecturas cada cinco segundos, actualización del dashboard y desvinculación.
   Calibrar el caudalímetro y confirmar que BLE vuelve a anunciarse al final.
5. Preparar despliegue a Internet: DNS, HTTPS, reverse proxy, firewall y
   variables de producción; no publicar PostgreSQL ni el backend directamente.
   Configurar MQTT con TLS, ACL y credenciales individuales por dispositivo.
6. Probar la experiencia Expo SDK 57 en teléfono físico. Expo Go no incluye BLE;
   el aprovisionamiento BLE completo requiere una compilación nativa compatible.
7. Mantener seguimiento de `braces` y `node-forge`. No forzar un downgrade de
   Expo para limpiar el audit; reevaluar cuando existan parches o cuando se
   decida migrar a un SDK compatible con la versión de Expo Go disponible.
