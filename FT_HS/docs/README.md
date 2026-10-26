# Frontend y móvil

## Organización

| Ruta | Responsabilidad |
| --- | --- |
| `src/app` | Rutas, layout, proveedores y páginas de aplicación. |
| `src/features` | Pantallas y lógica por dominio funcional. |
| `src/shared` | Cliente HTTP, componentes comunes, i18n, almacenamiento y utilidades. |
| `src/mobile` | Entrada Expo, WebView y puente nativo. |
| `scripts` | Generación del bundle web y ejecución Android. |

## Guías detalladas por capa

- [01_shell-routing: entrada, rutas y proveedores](01_shell-routing.md)
- [02_features: módulos funcionales](02_features.md)
- [03_shared: configuración, HTTP, i18n y UI](03_shared.md)
- [04_mobile: Expo, WebView y BLE](04_mobile.md)
- [05_runtime-styles: web, estilos y despliegue](05_runtime-styles.md)

## Sesión y API

El cliente HTTP usa `credentials: include`, por lo que el navegador recibe las
cookies `HttpOnly` que entrega la API. Para operaciones mutables agrega
automáticamente el token CSRF. El frontend no persiste tokens de sesión en
`sessionStorage`.

En Docker, Nginx envía `/api/v1` al backend. En desarrollo con Vite,
`VITE_API_URL` debe apuntar a `http://localhost:3000/api/v1`.

## Roles

- Owner/HomeUser puede gestionar hogares, miembros y dispositivos según sus
  permisos.
- Guest solo consulta recursos compartidos autorizados.
- Administrator administra usuarios, roles y módulos administrativos.

Los permisos finales se aplican en la API y PostgreSQL; la interfaz no es una
barrera de seguridad.

## Calidad

```powershell
Set-Location FT_HS/frontend
npm.cmd run lint
npm.cmd run typecheck
npm.cmd run build
npm.cmd run mobile:prepare
```

La guía completa de pruebas y Android está en
[../../docs/pruebas.md](../../docs/pruebas.md).
