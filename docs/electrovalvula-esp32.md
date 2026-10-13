# Integrar una válvula de 12 V con el ESP32

Actualizado: 2026-10-13.

## Estado actual

La etiqueta visible en la fotografía indica **DC 12 V**, pero la imagen no
permite confirmar si el actuador es una bobina solenoide, una válvula
motorizada o un modelo con enclavamiento. Antes de cablearlo, hay que leer el
modelo completo y su ficha técnica: tensión, corriente, tipo de accionamiento,
polaridad, ciclo de trabajo y posición sin alimentación (normalmente abierta o
normalmente cerrada).

En el firmware revisado, GPIO 27 está asignado al caudalímetro YF-S201 y GPIO 0
al botón BOOT. El manejador MQTT existente procesa comandos BLE/vinculación
(`enable_ble`, `confirm_link`, `unlink`, `disable_ble`); todavía no acciona una
válvula. Por tanto, conectar un módulo al ESP32 no hará que la aplicación pueda
abrirla o cerrarla hasta implementar y probar ese control en el firmware y
definir el comando autorizado en el flujo de aplicación.

## Componentes

- Fuente regulada de 12 V DC, dimensionada según la corriente indicada por el
  fabricante de la válvula.
- Fusible en serie con el positivo de 12 V, dimensionado para proteger el cable
  y la carga.
- Etapa de potencia compatible con el tipo de válvula: MOSFET lógico para una
  bobina DC simple; puente H o controlador indicado por el fabricante si la
  válvula necesita invertir polaridad; módulo de relé solo si sus contactos y
  entrada soportan la carga y la señal de 3.3 V.
- Supresión de transientes para la carga inductiva, integrada en el controlador
  o externa según su ficha técnica.
- Cables, borneras y caja adecuados para la corriente y para el entorno húmedo.

El GPIO del ESP32 es una señal lógica de 3.3 V; no debe alimentar la válvula ni
una bobina de 12 V. Consulta la [ficha técnica oficial del ESP32-WROOM-32](https://documentation.espressif.com/esp32_wroom-32_datasheet_en.html)
para las características eléctricas de la placa/módulo.

## Cableado según el actuador

### Si la ficha confirma una bobina solenoide DC de dos cables

Se puede usar un controlador MOSFET de lado bajo, apto para señal lógica de 3.3
V y para la corriente de la válvula:

```text
Fuente +12 V ── fusible ──┬── válvula (+)
                          └── cátodo de diodo (lado de la banda)
Válvula (-) ──────────────── drenador MOSFET
Fuente 0 V ───────────────── fuente MOSFET
ESP32 GPIO 25 (candidato) ── entrada del módulo MOSFET
ESP32 GND ────────────────── fuente 0 V (tierra común)
Diodo: ánodo ─────────────── válvula (-) / drenador
```

El diodo debe ser apto para la corriente de la bobina; su banda/cátodo va al
positivo de 12 V y el ánodo al lado conmutado de la válvula. No hace falta
añadir un diodo externo si el módulo ya incorpora una supresión apropiada y su
fabricante lo confirma. GPIO 25 es solo un candidato de diseño, no está
configurado en el firmware actual; se debe revisar la placa y reservar el pin
antes de usarlo. GPIO 27 debe quedar para el sensor de flujo.

### Si es motorizada, de polaridad reversible o con enclavamiento

No uses el circuito MOSFET simple anterior. Usa un puente H/controlador o el
circuito exacto indicado por el fabricante. Algunas válvulas requieren invertir
la polaridad para abrir/cerrar; otras requieren pulsos breves y no deben quedar
alimentadas continuamente. En estos casos, confirma también la corriente de
arranque o bloqueo del motor, que puede superar la corriente normal.

### Si es de tres o más cables

No deduzcas la función de cada cable por color. Sigue el diagrama del modelo y
usa un controlador con entradas, salidas y tensión compatibles con esa
configuración.

## Reglas de seguridad y prueba

1. No conectes la válvula directamente a GPIO, 3V3, 5 V ni al USB del ESP32.
2. No conectes 12 V al pin GPIO. Para un MOSFET no aislado, comparte GND entre
   ESP32 y la fuente de 12 V; con un módulo aislado, sigue su diagrama y no
   elimines el aislamiento.
3. Verifica polaridad, corriente nominal, corriente de arranque, ciclo de
   trabajo y estado de la válvula al perder alimentación. Para cortar agua ante
   una falla suele preferirse normalmente cerrada, pero hay que confirmarlo con
   el modelo y con el requisito hidráulico.
4. Prueba primero sobre una mesa, con la tubería sin presión y una fuente
   limitada/protegida. Comprueba apertura, cierre, temperatura y comportamiento
   al reiniciar el ESP32, perder Wi-Fi/MQTT o desconectar la fuente.
5. Mantén la electrónica protegida de fugas; instala fusible, aislamiento,
   alivio de tensión y un cierre manual accesible. No manipules conexiones
   energizadas con las manos húmedas.

## Vinculación con HidroSmart

La ruta prevista no necesita un segundo microcontrolador: la integración puede
usar el topic MQTT de comandos del dispositivo y hacer que el ESP32 accione el
controlador de potencia y publique un estado/resultado. Hay que definir o
verificar el soporte de extremo a extremo: API autorizada, formato de orden,
confirmación, estado seguro ante desconexión y protección contra órdenes
repetidas. Actualmente el firmware no implementa el control físico.

Un relé/controlador MQTT externo también podría accionar una válvula, pero sería
un dispositivo separado y requiere su propia integración y controles de acceso;
vincular el ESP32 en la interfaz no lo configura automáticamente.
