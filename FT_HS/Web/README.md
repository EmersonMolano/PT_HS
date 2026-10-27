# HidroSmart Web

Frontend React/Vite con arquitectura Feature-First.

## Ejecución local

Integrado con Docker desde la raíz:

```powershell
docker compose --env-file .env up -d --build
```

Abre `http://localhost:5173`.

Sin Docker:

```powershell
npm ci
npm run dev
```

En ejecución directa, `VITE_API_URL` debe apuntar a `http://localhost:3000/api/v1`. En Docker el build usa `/api/v1` y Nginx hace el proxy al servicio `backend`.

## Validación

```powershell
npm run test
npm run build
npx playwright install chromium
npm run test:e2e
```

Las pruebas de navegador simulan la API y no reemplazan las pruebas de integración con backend y base de datos reales.

Documentación centralizada: [`../../docs/README.md`](../../docs/README.md), con guías de [producto](../../docs/producto.md), [despliegue](../../docs/despliegue.md) y [pruebas](../../docs/pruebas-y-reproducibilidad.md).
