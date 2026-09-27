# Encargo para implementar Task 5 — Enigma

Lee este documento completo antes de cambiar código. Implementa solo la lógica interna de Task 5 siguiendo el protocolo y las reglas del hackathon.

## Fuentes y alcance

1. Lee `material_hackathon/05_Enigma.pdf`, seguido de `00_Project_Guide.pdf`, `00_Quick_Guide.pdf` y `00_User_Manual.pdf`.
2. Extrae sin suposiciones el formato de paquete, el handshake `valid/first/last`, tamaños, aritmética, latencia máxima y puntuación de recursos.
3. El wrapper es `src/tasks/task_5/task_5.sv`. Conserva exactamente módulo, parámetros y puertos. No modifiques su interfaz.
4. Los `task_*.sv` históricos de la raíz sirven únicamente para comprender el estilo humano del equipo; los wrappers actuales y smoke tests no son ejemplos de arquitectura para otra tarea.

## Normas no negociables

- Modifica únicamente el interior de `src/tasks/task_5/task_5.sv`, excepto si se solicita testbench o documentación.
- Haz parches pequeños: no borres ni reescribas el archivo entero. Comprueba antes y después que la entidad no cambió.
- Si el PDF prohíbe comentarios en RTL, no añadas comentarios al `.sv`; explica las decisiones en Markdown.
- No toques otros wrappers, scripts de evaluación, constraints ni PDFs.
- No hagas `commit`, `push`, `merge` ni borres archivos sin orden explícita.
- Compilar no basta: valida en XSim y mide síntesis.

## Estilo y arquitectura

- FSM explícita con `typedef enum logic`, `state` y `next_state`.
- `always_ff` para estado/registros/memorias y `always_comb` para transiciones/salidas con valores por defecto.
- Estados `ST_*`, contadores y punteros con nombres funcionales.
- Una sola FSM cuando el flujo lo permita; emite resultados de forma causal si ya están determinados.
- Respeta estrictamente el handshake: cada `o_valid` emite un dato definido y `o_last` solo acompaña al último byte.

## Optimización

Prioriza corrección, baja latencia y recursos. Evita división, módulo o multiplicación variable; bucles combinacionales por bits; almacenar el paquete completo sin necesidad; y esperar al final cuando pueda emitirse antes. Prefiere contadores, comparaciones, buffers circulares, pipeline y memorias inferidas correctamente.

```text
resource_utilization = CLB_LUTs + CLB_REGs + 10 * DSP
```

Una puntuación menor es mejor; no la compares directamente con la capacidad de LUTs, porque incluye registros y DSPs.

## Flujo obligatorio

1. Resume protocolo, estados, buffers y latencia prevista antes de implementar.
2. Compila y simula con XSim de `C:\AMDDesignTools\2025.2\Vivado\bin`.
3. Prueba reset, mínimo, representativo/máximo, todos los modos, bordes numéricos y paquetes consecutivos si aplican.
4. Si se piden logs, créalos desde el testbench:

```text
cycle=<n> IN  valid=<0|1> first=<0|1> last=<0|1> data=<hex>
cycle=<n> OUT valid=<0|1> last=<0|1> data=<hex>
```

5. Sintetiza para el part objetivo y reporta LUTs, registros, DSPs, puntuación y latencia en ciclos. Sin XDC no afirmes Fmax.
6. Documenta problema, protocolo, FSM, optimización, tests, recursos y límites en `TASK_CONTEXT.md`/`METHODOLOGY.md`.

## Entrega

Resume archivos modificados, interfaz sin cambios, simulaciones, recursos/puntuación, latencia y riesgos o supuestos pendientes.
