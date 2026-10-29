# Pruebas y reproducibilidad

## Entorno

- Node.js 22 para backend y frontend.
- Docker Desktop con motor Linux activo para PostgreSQL, Mosquitto y pruebas de integración local.
- Las instalaciones limpias usan `npm ci` y los lockfiles versionados.

## Clon limpio

```powershell
git clone https://github.com/joseale879/PT_HS.git
Set-Location PT_HS
Copy-Item .env.example .env
```

Completa los secretos locales y luego ejecuta:

```powershell
Set-Location BK_HS
npm ci
npm run check
npm test

Set-Location ..\FT_HS\Web
npm ci
npm run test
npm run build
npx playwright install chromium
npm run test:e2e
```

Para una pila completa, sigue [Despliegue y operación](despliegue.md) y ejecuta Liquibase antes de arrancar los servicios de aplicación.

## Cobertura

- Backend: `npm test` ejecuta las pruebas unitarias; `npm run check` verifica sintaxis.
- Frontend: `npm run test` prueba funciones puras; `npm run test:e2e` recorre la web en Chromium.
- La E2E de alertas simula las respuestas HTTP y comprueba que la web envíe los límites y reglas esperados. La E2E de recomendaciones verifica que los textos cambien según las lecturas devueltas por API.
- PostgreSQL y políticas RLS requieren una base de integración aislada; no ejecutes estas pruebas contra Neon de producción.
- MQTT real requiere Flespi accesible y token ACL de prueba. La prueba autenticada no se ejecuta desde CI ni publica mensajes.

## CI

`.github/workflows/ci.yml` corre instalación limpia, checks y pruebas unitarias del backend, build y unit/E2E del frontend en push y pull request. Las pruebas E2E usan API simulada; no certifican conectividad real con PostgreSQL, Flespi, Brevo ni el ESP32.

## Estado de las pruebas de entorno

Un build local correcto no equivale a un despliegue correcto. Para cerrar un flujo de producción también deben comprobarse en el proveedor la configuración del ambiente, el estado del servicio y una operación de punta a punta con cuentas/datos de prueba.
