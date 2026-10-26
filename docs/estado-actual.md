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

## Verificado recientemente

- Pruebas unitarias del backend, validaciones estáticas, typecheck y build web.
- Restauración PostgreSQL mediante el script de verificación.
- Build e instalación Android en emulador con Expo SDK 54.
- Configuración Docker local validada mediante `docker compose config`.

## Pendiente antes de producción

1. Ejecutar E2E visual completo con cuentas de Owner, Guest y Administrator.
2. Ejecutar la prueba física continua del ESP32 con caudalímetro calibrado.
3. Definir infraestructura de Internet: DNS, HTTPS, MQTT con TLS, ACL y
   credenciales por dispositivo.
4. Resolver los avisos transitivos del árbol Expo/React Native mediante una
   actualización mayor planificada, no mediante `npm audit fix --force`.
5. Estabilizar la experiencia móvil en dispositivo físico después de validar la
   web y el flujo físico IoT.
