# 08 Pruebas del frontend

## Estado actual

El script `npm test` ejecuta `node --test`. Al 18 de octubre de 2026 pasan
22 pruebas distribuidas entre `apiClient.test.mjs`, `frontendRules.test.mjs` y
`deviceProvisioning.test.mjs`. Cubren cookies/CSRF, renovación y concurrencia
de sesión, errores HTTP, descargas PDF/Excel, contratos de vinculación IoT,
roles y permisos, validaciones, fechas y el puente BLE nativo simulado. No
prueban la interfaz visual ni un ESP32 físico. La CI ejecuta lint, typecheck,
test, build y preparación del bundle móvil.

## Comandos locales

Desde la raíz del repositorio:

```powershell
npm.cmd --prefix FT_HS/frontend run lint
npm.cmd --prefix FT_HS/frontend run typecheck
npm.cmd --prefix FT_HS/frontend test
npm.cmd --prefix FT_HS/frontend run build
npm.cmd --prefix FT_HS/frontend run mobile:doctor
npm.cmd --prefix FT_HS/frontend run mobile:prepare
```

## Cobertura que debe incorporarse

1. **Lógica pura:** ampliar a rangos de fechas, cálculos y formato de consumo.
2. **Componentes:** estados de carga/vacío/error, validaciones y acciones
   visibles para cada permiso.
3. **Integración de API:** login/restauración de sesión en componentes y
   descargas mediante navegador, no solo respuestas simuladas del cliente HTTP.
4. **Rutas:** sesión restaurada, sesión expirada, deep link protegido y regreso
   después del login.
5. **Responsive:** navegación inferior móvil, formularios y gráficos en los
   tres tramos de viewport descritos en `07_componentes-y-responsive.md`.
6. **E2E de navegador:** flujos Owner, Guest y Administrator con datos de prueba
   aislados; no usar cuentas ni hogares reales.

## Criterios para agregar una prueba

- Colocarla junto al módulo probado, bajo `frontend/tests` o en una carpeta
  `__tests__` del módulo.
- Probar comportamiento observable, no detalles internos de implementación.
- No guardar tokens reales ni depender de servicios externos en una prueba
  unitaria.
- Los casos de permisos deben comprobar tanto acciones permitidas como
  denegadas. Ocultar un botón no reemplaza la comprobación HTTP del backend.
- Cada nueva dependencia de pruebas debe ser compatible con Expo/Vite y quedar
  fijada en `package.json` y `package-lock.json`.

## Definición de terminado

Una pantalla se considera validada cuando pasa typecheck y build, tiene pruebas
de sus reglas críticas, y se comprueba al menos en viewport móvil y escritorio.
Los flujos protegidos requieren además pruebas de autorización del backend.
