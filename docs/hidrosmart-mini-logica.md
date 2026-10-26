# Lógica de HidroSmart mini

Esta es la lógica funcional usada para hogares, consumo estimado, costos y presupuesto.

## Datos que se persisten

- El ESP32 conserva el dato original en litros (`consumption_liters`).
- PostgreSQL deriva los metros cúbicos (`consumption_m3`) y el costo estimado.
- Nunca se guarda la contraseña de Wi-Fi.
- El hogar guarda `people_count` entre 1 y 50; el valor inicial es 3.
- El costo mostrado es estimado y no representa la factura final del prestador.

## Referencias iniciales

`1 m³ = 1.000 litros`.

Para residencial se usa inicialmente `123 L/persona/día`. Por eso un hogar con `N` personas parte de:

```text
referencia diaria = 123 × N
referencia semanal = referencia diaria × 7
referencia mensual = referencia diaria × días reales del mes
```

Las referencias de tarifa inicial por m³ son valores técnicos de desarrollo y se pueden cambiar por hogar:

| Categoría | COP/m³ |
| --- | ---: |
| Residencial E1 | 1.025 |
| Residencial E2 | 2.050 |
| Residencial E3 | 3.100 |
| Residencial E4 | 3.415 |
| Residencial E5 | 5.175 |
| Residencial E6 | 5.515 |
| Comercial | 5.200 |
| Industrial | 4.750 |

No son una tarifa nacional única. El costo variable se calcula así:

```text
m³ = litros / 1.000
costo estimado = m³ × tarifa vigente del hogar
```

## Historial propio

Durante los primeros días se usa la referencia inicial. Cuando existen al menos 60 días distintos de lecturas previas, el sistema compara el hogar contra su promedio diario real. El mes actual no se usa para construir esa referencia.

El resultado indica si la fuente es `NATIONAL_REFERENCE` o `HOME_HISTORY`.

## Presupuesto y alertas

El presupuesto mensual se configura en la meta mensual del hogar; no está quemado. PostgreSQL calcula con los días reales del mes:

```text
presupuesto diario = presupuesto mensual / días del mes
presupuesto esperado a hoy = presupuesto diario × día del mes
litros restantes = presupuesto restante / tarifa × 1.000
```

Los estados independientes de consumo y presupuesto son:

- Menos de 80%: `NORMAL`.
- 80% a 100%: `CAUTION`.
- Más de 100% hasta 120%: `HIGH`.
- Más de 120%: `CRITICAL`.

El exceso de consumo, el exceso de presupuesto y una posible fuga son señales distintas. Una fuga no depende de que el presupuesto esté agotado.

## Endpoint del backend

```http
GET /api/v1/consumption/budget-status?homeId=<uuid>
```

Opcionalmente se puede enviar `asOfDate=YYYY-MM-DD` para consultar una fecha pasada. La respuesta incluye referencias diarias/semanales/mensuales, lecturas reales, costo estimado, tarifa vigente, avance del presupuesto, estado y litros restantes.

## Alta de un hogar

El formulario envía `peopleCount` junto con nombre, dirección, ciudad, tipo de uso, estrato residencial y altitud opcional. El backend valida la cantidad y la persiste mediante la función de PostgreSQL de ocho argumentos. Los hogares comerciales e industriales no usan estrato, pero sí conservan una cantidad de personas para mantener una referencia coherente si se requiere.
