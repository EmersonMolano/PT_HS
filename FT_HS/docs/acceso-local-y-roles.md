# Acceso local y paneles por rol — Hidro Smart

Última revisión: 2026-09-23.

Este documento explica cómo iniciar el proyecto, entrar al frontend y acceder a
los paneles de `Administrator`, `HomeUser` y `Guest`.

## 1. Iniciar el entorno

Ejecuta los comandos desde la raíz `PT_HS` con Docker Desktop iniciado:

```powershell
docker compose --env-file .env up -d --build
docker compose ps
```

Comprobaciones rápidas:

```powershell
Invoke-WebRequest http://localhost:5173/health
Invoke-WebRequest http://localhost:3000/health/ready
```

URLs locales:

| Servicio | URL |
| --- | --- |
| Frontend web | <http://localhost:5173> |
| Backend API | <http://localhost:3000> |
| Salud del frontend | <http://localhost:5173/health> |
| Salud del backend | <http://localhost:3000/health/ready> |

## 2. Iniciar sesión

1. Abre <http://localhost:5173/login>.
2. Escribe el correo o usuario y la contraseña de una cuenta existente.
3. El frontend inicia sesión en `POST /api/v1/auth/login`.
4. Después consulta `GET /api/v1/users/me` para obtener el perfil, los roles y los permisos.
5. El menú se construye con esos permisos; el rol no se elige desde el frontend.

El navegador conserva el access token y el refresh token únicamente en el almacenamiento
de sesión de la aplicación. Para que un cambio de rol se refleje, cierra sesión y vuelve a
iniciar sesión.

## 3. Rutas por rol

| Rol | Cómo entrar | Pantallas disponibles |
| --- | --- | --- |
| `Administrator` | Iniciar sesión y abrir `/app/admin` | Panel administrativo, `/app/users` y `/app/audit` |
| `HomeUser` | Iniciar sesión y abrir `/app` | Dashboard, hogares, dispositivos, consumo, reportes, recomendaciones, metas y configuración según permisos |
| `Guest` | Iniciar sesión y abrir `/app` | Dashboard y consultas autorizadas de solo lectura, incluidas recomendaciones |

Las rutas de Soporte y Notificaciones no aparecen para `HomeUser` ni `Guest`. Si esos
usuarios intentan abrir `/app/support` o `/app/alerts` manualmente, la vista muestra acceso
denegado. La autorización real también se verifica en el backend y en PostgreSQL/RLS.

## 4. Estado actual de la base local

La infraestructura responde correctamente en el corte vigente. La base está
limpia de hogares y dispositivos porque las pruebas de integración eliminan
sus datos temporales; para abrir el panel y ver datos reales se debe usar una
cuenta activa y registrar un hogar/dispositivo.

Verificado el 2026-09-23:

```text
Administrator: 1
HomeUser:      1
Guest:         1
```

Por eso, con la base actual ningún usuario puede entrar todavía al panel de
Administrador. La pantalla sí está implementada; falta asignar ese rol a una cuenta existente.

## 5. Habilitar el primer Administrator

El primer administrador se asigna una sola vez mediante la función protegida de la base.
No edites directamente `user_account.user_role`.

Primero consulta el UUID de la cuenta que debe ser administrador:

```powershell
docker compose exec -T postgres psql -U hidro_smart_admin -d hidro_smart -c `
  "SELECT user_account_id, email FROM user_account.user_account WHERE deleted_at IS NULL ORDER BY created_at;"
```

Después reemplaza `<USER_ID>` por el UUID elegido:

```powershell
docker compose exec -T postgres psql -U hidro_smart_admin -d hidro_smart -c `
  "SELECT user_account.fn_bootstrap_first_administrator('<USER_ID>');"
```

Luego:

1. Abre <http://localhost:5173/login>.
2. Inicia sesión con esa cuenta.
3. Abre <http://localhost:5173/app/admin>.
4. Comprueba que también aparezcan `/app/users` y `/app/audit`.

La función rechaza el proceso si ya existe un `Administrator` activo.

## 6. Gestionar tickets desde Administrator

Después de tener una sesión de administrador puedes abrir `/app/support/management` desde
el menú administrativo. Allí puedes consultar tickets, abrir el detalle, responder y
actualizar estados. La operación está protegida por el permiso `tickets.manage`; ya no
existe un rol funcional independiente para soporte.

## 7. Qué hacer si aparece acceso denegado

- Comprueba que la cuenta esté activa y no eliminada lógicamente.
- Cierra sesión y vuelve a iniciar sesión para renovar roles y permisos.
- Verifica que `GET /api/v1/users/me` devuelva `Administrator` en `roles` cuando necesites gestionar tickets.
- Confirma que el permiso requerido también esté presente:
  - Administrador: `roles.manage`, `users.manage` o `audit.read`.
  - Administrador para tickets: `tickets.manage`.
- Revisa que el backend responda en <http://localhost:3000/health/ready>.
- Si cambiaste el código del frontend con Docker activo, ejecuta nuevamente:

  ```powershell
  docker compose up -d --build frontend
  ```

## 8. Referencias

- [Rutas e integración API](./rutas-y-api-frontend.md)
- [Arquitectura del frontend](./arquitectura-frontend.md)
- [Pendientes del frontend](./pendientes-frontend.md)
- [Roles y permisos del backend](../../BK_HS/docs/00-roles-y-permisos.md)
- [Endpoints por rol](../../BK_HS/docs/endpoints-por-rol.md)
