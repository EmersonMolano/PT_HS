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

## Verificación local (18 de octubre de 2026)

- Backend: 204 pruebas unitarias aprobadas y revisión sintáctica de 217 archivos.
  `npm audit` reportó 0 vulnerabilidades en esta revisión.
- Frontend web: 22 pruebas aprobadas; lint, typecheck y build aprobados. Cubren
  el cliente HTTP, CSRF/refresh, rutas de vinculación y reportes, permisos,
  validaciones y el puente BLE simulado; no cubren la UI en navegador real.
- Móvil: Expo SDK 57 (`expo 57.0.30`, React Native `0.86.3`). Expo Doctor
  aprobó 21/21 comprobaciones después de retirar la dependencia directa
  innecesaria `@expo/config-plugins`. No se instaló ni probó en un teléfono en
  esta revisión; Expo Go no permite probar el módulo BLE nativo.
- Simulación HTTP aislada: 300 clientes virtuales, 100 concurrentes y 900
  solicitudes previstas, sin errores. No crea cuentas ni consulta PostgreSQL;
  **no equivale** a una prueba de carga con 300 usuarios reales.
- `docker compose config --quiet` aprobó, pero el motor de Docker Desktop no
  estaba disponible. No se repitieron pruebas integradas con PostgreSQL,
  Mosquitto, navegador ni restauración de respaldo.
- `npm audit --omit=dev` del frontend reportó 15 hallazgos altos en la cadena
  Expo/Metro/React Native. No se aplicó `npm audit fix --force` ni se cambió de
  SDK; se mantiene la decisión de usar SDK 57.

## Pendiente antes de producción

1. Completar pruebas E2E de navegador con Owner, Guest y Administrator:
   permisos, hogares, vincular/desvincular, consumo, reportes, alertas y soporte.
   La integración del backend en CI no sustituye esta validación visual.
2. Ampliar las pruebas del frontend a componentes, rutas, formularios y estados
   de error visibles; las validaciones puras ya tienen pruebas unitarias.
3. Ejecutar una prueba de carga reproducible con cuentas de prueba y telemetría
   simultánea, midiendo latencia, errores, conexiones y consumo de recursos.
4. Completar la prueba física del ESP32: aprovisionamiento, MQTT seguro,
   lecturas cada cinco segundos, actualización del dashboard y desvinculación.
   Calibrar el caudalímetro y confirmar que BLE vuelve a anunciarse al final.
5. Verificar login, refresh, CSRF y logout en un navegador con Cloudflare Pages
   y Render. Esos dominios son sitios distintos; el navegador puede bloquear
   las cookies de terceros. Si ocurre, usar una API bajo el mismo sitio del
   frontend sin desactivar CSRF.
6. Preparar despliegue a Internet: DNS, HTTPS, reverse proxy, firewall y
   variables de producción; no publicar PostgreSQL directamente. Configurar
   MQTT con TLS, ACL y credenciales individuales por dispositivo.
7. Probar la experiencia Expo SDK 57 en teléfono físico. Expo Go no incluye BLE;
   el aprovisionamiento BLE completo requiere una compilación nativa compatible.
8. Revisar los 15 hallazgos altos del frontend por paquete y exposición real.
   No forzar cambios mayores incompatibles con Expo Go; reevaluar parches
   compatibles con SDK 57 o una migración planificada de SDK.

Las tareas documentales y las evidencias faltantes se detallan en
[pendientes-documentacion.md](pendientes-documentacion.md).
