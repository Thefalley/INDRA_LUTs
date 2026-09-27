# Encargo para implementar Task 8 — Microblaze Software Sorter

Lee este texto completo antes de modificar código. El objetivo es implementar únicamente la lógica interna de Task 8, respetando las reglas del hackathon y el modo de trabajo del equipo.

## Alcance y fuentes de verdad

1. Lee primero `hackathon/2026/material/08_Microblaze_Software_Sorter.pdf` completo y después los documentos generales de `hackathon/2026/material`.
2. Extrae de ellos, sin suposiciones: formato de paquete, semántica exacta de `valid`, `first` y `last`, precisión/arithmetic, tamaño máximo, requisito de latencia y fórmula de recursos.
3. El wrapper real a implementar es `src/tasks/task_8/task_8.sv`. Conserva exactamente el nombre del módulo, parámetros, puertos, anchuras y direcciones. No cambies la interfaz aunque parezca mejorable.
4. No uses como modelo de implementación el `task_1.sv` de este año ni el smoke test: su protocolo y algoritmo son distintos. Los archivos históricos `task_*.sv` de la raíz del repositorio solo sirven para entender el estilo humano del equipo.

## Normas no negociables

- Modifica únicamente el interior de `src/tasks/task_8/task_8.sv`, salvo que se pida explícitamente testbench o documentación.
- Haz cambios pequeños con parche; no borres y reescribas el archivo entero. Antes y después, verifica que la cabecera de entidad coincide byte a byte en nombre, parámetros y puertos.
- Si el PDF de Task 8 prohíbe comentarios dentro del RTL, no añadas comentarios en el `.sv`. La explicación va en Markdown aparte.
- No cambies otros wrappers, scripts de evaluación, constraints ni materiales del hackathon.
- No hagas `commit`, `push`, `merge`, ni borres archivos generados sin una orden explícita.
- No declares el trabajo terminado solo porque compila: debe pasar simulación y medirse en síntesis.

## Estilo que seguimos

Queremos RTL legible y determinista, similar al código histórico del equipo:

1. Una FSM explícita con `typedef enum logic`, registro `state` y `next_state`.
2. Un `always_ff` para el estado y registros/memorias; un `always_comb` con valores por defecto para transición y salidas.
3. Nombres funcionales y claros: contadores, punteros, registros de control, memoria temporal y estados con prefijo `ST_`.
4. Una sola FSM si el flujo lo permite. No separar artificialmente entrada y salida si puede emitirse un resultado de forma causal al recibir el dato que lo determina.
5. Mantén el handshake continuo: cada `o_valid` debe corresponder a un byte de salida definido; `o_last` solo se activa con el último byte del paquete.

## Criterio de optimización

La prioridad es que el diseño sea correcto, tenga baja latencia y utilice pocos recursos. Evita en el camino de datos:

- división, módulo o multiplicación de ancho variable;
- bucles por bit que reconstruyan un paquete completo en lógica combinacional;
- esperar al paquete entero si el resultado puede empezar a salir antes;
- memorias/arrays de tamaño máximo si basta una ventana, contador o buffer circular.

Prefiere contadores, comparaciones, punteros circulares, desplazamientos de cantidad acotada y pipeline sencillo. Si hay una dependencia real del final del paquete, documenta por qué esa latencia es inevitable.

La puntuación de recursos se calcula como:

```text
resource_utilization = CLB_LUTs + CLB_REGs + 10 * DSP
```

Una puntuación menor es mejor. No la compares directamente con la capacidad de LUTs del FPGA, porque también incluye registros y DSPs.

## Flujo de trabajo requerido

1. Resume primero el protocolo y plantea los estados, buffers y latencia esperada antes de codificar.
2. Implementa por parches internos, conservando la interfaz.
3. Compila y ejecuta un testbench en XSim con Vivado `C:\AMDDesignTools\2025.2\Vivado\bin`.
4. Prueba como mínimo: reset, paquete mínimo, paquete máximo o representativo, todos los modos definidos por el PDF, bordes numéricos y back-to-back packets si el protocolo lo admite.
5. Si se solicita trazabilidad, registra en texto plano las transferencias de entrada y salida desde el testbench, no desde el RTL:

```text
cycle=<n> IN  valid=<0|1> first=<0|1> last=<0|1> data=<hex>
cycle=<n> OUT valid=<0|1> last=<0|1> data=<hex>
```

6. Ejecuta síntesis aislada en el part objetivo y reporta LUTs, registros, DSPs y la puntuación. Sin una constraint de reloj no afirmes un Fmax; expresa la latencia en ciclos y tradúcela a tiempo solo para una frecuencia indicada.
7. Crea o actualiza `TASK_CONTEXT.md`/`METHODOLOGY.md` en la carpeta de Task 8 con: problema, protocolo, arquitectura, FSM, decisiones de optimización, vectores de prueba, resultados de XSim, recursos y límites conocidos.

## Entrega esperada

Entrega un resumen corto con:

- archivos modificados;
- interfaz confirmada sin cambios;
- resultado de cada simulación;
- recursos y puntuación;
- latencia por caso relevante;
- riesgos pendientes o supuestos que necesiten validación humana.
