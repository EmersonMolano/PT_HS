# Integrar una válvula de 12 V con el ESP32

Actualizado: 2026-10-13. Integrado desde el aporte funcional de HU-13.

## Estado actual

La etiqueta visible **DC 12 V** no permite confirmar si el actuador es una
bobina solenoide, una válvula motorizada o un modelo con enclavamiento. Antes
de cablearlo, se debe consultar la ficha técnica completa: tensión, corriente,
tipo de accionamiento, polaridad, ciclo de trabajo y posición sin alimentación
(normalmente abierta o normalmente cerrada).

En el firmware vigente, GPIO 27 está reservado para el caudalímetro YF-S201 y
GPIO 0 para el botón BOOT. Los comandos MQTT actuales cubren provisión y
vinculación (`enable_ble`, `confirm_link`, `unlink` y `disable_ble`); no
accionan una válvula. Conectar un módulo de potencia al ESP32 no hará que la
aplicación pueda abrirla o cerrarla hasta implementar, probar y autorizar ese
control de extremo a extremo.

## Componentes mínimos

- Fuente regulada de 12 V DC, dimensionada para la corriente indicada por el
  fabricante de la válvula.
- Fusible en serie con el positivo de 12 V, adecuado para proteger el cable y
  la carga.
- Etapa de potencia compatible: MOSFET lógico para una bobina DC simple;
  puente H o controlador del fabricante si requiere invertir polaridad; relé
  solo si sus contactos y entrada soportan la carga y una señal de 3.3 V.
- Supresión de transientes para cargas inductivas, integrada en el controlador
  o añadida según su ficha técnica.
- Cables, borneras y caja aptos para la corriente y el entorno húmedo.

Un GPIO del ESP32 es una señal lógica de 3.3 V: no debe alimentar la válvula ni
una bobina de 12 V. Consulta la [ficha técnica oficial del
ESP32-WROOM-32](https://documentation.espressif.com/esp32_wroom-32_datasheet_en.html)
para sus características eléctricas.

## Cableado según el actuador

### Bobina solenoide DC de dos cables

Si la ficha confirma una bobina DC simple, se puede usar un controlador MOSFET
de lado bajo, compatible con 3.3 V y con la corriente de la válvula:

```text
Fuente +12 V ── fusible ──┬── válvula (+)
                          └── cátodo de diodo (lado de la banda)
Válvula (-) ──────────────── drenador MOSFET
Fuente 0 V ───────────────── fuente MOSFET
ESP32 GPIO 25 (candidato) ── entrada del módulo MOSFET
ESP32 GND ────────────────── fuente 0 V (tierra común)
Diodo: ánodo ─────────────── válvula (-) / drenador
```

El diodo debe soportar la corriente de la bobina; su cátodo (lado con banda) va
al positivo de 12 V y el ánodo al lado conmutado. No se añade un diodo externo
si el módulo incorpora una supresión apropiada que su fabricante confirme.
GPIO 25 es solo un candidato: hay que revisar la placa y reservarlo antes de
configurarlo. GPIO 27 permanece exclusivo para el sensor de flujo.

### Válvula motorizada, reversible o con enclavamiento

No se debe usar el circuito MOSFET simple anterior. Se requiere un puente H,
controlador dedicado o el circuito exacto del fabricante. Algunas válvulas
necesitan invertir polaridad para abrir o cerrar; otras solo admiten pulsos
breves y no deben permanecer energizadas. También hay que considerar su
corriente de arranque o bloqueo, que puede ser mayor que la nominal.

### Válvula con tres o más cables

No se deduce la función de cada cable por su color. Debe seguirse el diagrama
del modelo y emplearse un controlador cuyas entradas, salidas y tensión sean
compatibles con esa configuración.

## Reglas de seguridad y prueba

1. No conectes la válvula directamente a GPIO, 3V3, 5 V ni al USB del ESP32.
2. Nunca apliques 12 V a un GPIO. En un MOSFET no aislado, ESP32 y la fuente de
   12 V comparten GND; para un módulo aislado se sigue su diagrama sin eliminar
   el aislamiento.
3. Verifica polaridad, corriente nominal y de arranque, ciclo de trabajo y
   estado de la válvula al perder alimentación. Para cortar agua ante falla se
   suele preferir normalmente cerrada, sujeto al modelo y al requisito
   hidráulico.
4. Prueba primero sobre mesa, con tubería sin presión y una fuente limitada o
   protegida. Confirma apertura, cierre, temperatura y comportamiento al
   reiniciar el ESP32, perder Wi-Fi/MQTT o desconectar la fuente.
5. Protege la electrónica de fugas; instala fusible, aislamiento, alivio de
   tensión y un cierre manual accesible. No manipules conexiones energizadas
   con las manos húmedas.

## Integración pendiente en HidroSmart

La ruta prevista usa el topic MQTT de comandos del dispositivo para que el
ESP32 opere el controlador de potencia y publique resultado y estado. Antes de
habilitarla se debe implementar y verificar:

1. Ruta API con autorización para emitir la orden.
2. Contrato MQTT de comando, confirmación y estado de la válvula.
3. Prevención de reintentos u órdenes repetidas.
4. Estado seguro ante desconexión, reinicio o pérdida de alimentación.
5. Pruebas eléctricas e hidráulicas antes de exponer el control en web o móvil.

Un relé o controlador MQTT externo también podría accionar una válvula, pero
sería un dispositivo independiente con su propia integración y controles de
acceso. Vincular el ESP32 en HidroSmart no configura automáticamente ese relé.
