# Definición del producto HidroSmart

## Problema

Los hogares no siempre pueden ver cuánto consumen, detectar cambios a tiempo ni relacionar una lectura del medidor con acciones concretas. HidroSmart reúne lecturas de un ESP32, las almacena y presenta consumo, alertas y reportes por hogar.

## Usuarios

- **Titular del hogar (Owner):** crea y administra hogares, vincula dispositivos y define límites de consumo.
- **Invitado (Guest):** consulta la información permitida del hogar compartido; no administra miembros ni configuración.
- **Administrador del sistema (Administrator):** gestiona funciones globales autorizadas y da soporte operativo.

Los permisos efectivos los devuelve el backend y los aplica también la base de datos. La interfaz no es el control de acceso final.

## Alcance funcional

1. Crear cuenta, verificar correo, iniciar sesión y recuperar contraseña.
2. Crear hogares y administrar sus miembros.
3. Vincular y desvincular dispositivos ESP32.
4. Recibir telemetría MQTT, resolver el código del dispositivo y persistir lecturas asociadas a un hogar.
5. Consultar consumo actual e histórico, reportes y metas.
6. Configurar límites diarios y mensuales, reglas adicionales y atender alertas.
7. Recibir notificaciones por correo mediante Brevo y consultar solicitudes de soporte.

## Flujos principales

### Medición

`ESP32 → broker MQTT → subscriber del backend → validación del topic/payload → resolución del dispositivo activo → PostgreSQL → API → dashboard`

Una lectura se acepta solo si su código corresponde a un dispositivo activo vinculado a un hogar activo. QoS 1 permite reentregas; la persistencia debe considerar duplicados antes de prometer exactamente una entrega.

### Reglas y alertas

- Un hogar nuevo recibe límites iniciales diarios y mensuales editables.
- El titular puede cambiar, activar o desactivar los límites y crear reglas adicionales.
- Las reglas se evalúan al guardar lecturas o en el job correspondiente, según su tipo.
- El historial debe permitir marcar alertas como leídas o atendidas.

### Recomendaciones

El dashboard calcula consejos a partir de los totales actuales y de los periodos comparables que devuelve la API. Si faltan lecturas o no existe periodo anterior, informa esa limitación y no inventa una tendencia.

## Criterios de aceptación

- Un hogar nuevo muestra límites iniciales y reglas diarias/mensuales activas.
- El titular puede guardar límites y crear una regla adicional; los valores reaparecen al recargar.
- Una lectura válida de un dispositivo vinculado se consulta desde el hogar correspondiente; un código inexistente no se atribuye a otro hogar.
- Las recomendaciones cambian al cambiar los totales y comparaciones de API.
- Los reportes muestran el hogar y periodo solicitado y manejan el estado sin lecturas.
- Owner, Guest y Administrator solo ven y ejecutan acciones permitidas por sus permisos.
- Los cambios de API, esquema y frontend pasan CI antes de promoción.

## Fuera de alcance de esta definición

No se afirma aquí que el firmware físico, la conectividad MQTT con credenciales reales, la restauración de backups ni el despliegue productivo estén verificados. Esos estados se registran como pruebas operativas separadas.
