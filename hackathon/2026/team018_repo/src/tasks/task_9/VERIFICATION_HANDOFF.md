# Handoff de verificación - Task 9 Cracovian

## Estado de entrega

La implementación se encuentra en la rama `task9`. El único RTL modificado es
`task_9.sv`; la interfaz pública del módulo se conserva sin cambios.

## Qué hace

1. Lee la configuración `{num_pair, num_rows, num_col_a, num_col_b}` con
   `i_first`.
2. Recibe los sub-Cracovianos de 32 bits que siguen, respetando `i_valid` e
   `i_last`.
3. Guarda el paquete completo, calcula cada bloque resultado 2x2 y normaliza
   sus cuatro mantisas a un exponente compartido.
4. Emite la configuración `{num_pair, num_col_b, 8'd0, num_col_a}` con
   `o_first`, seguida de los resultados; `o_last` se marca únicamente en la
   última palabra.

## FSM y latencia

`ST_WAIT_CONFIG -> ST_RECEIVE -> ST_CALC_INIT -> ST_CALCULATE ->
ST_NORMALIZE -> ST_OUTPUT_CONFIG/ST_OUTPUT_DATA`.

- Primer resultado: `row_blocks + 3` ciclos después del último dato de entrada.
- Resultados posteriores: `row_blocks + 2` ciclos por sub-Cracoviano.
- No existe señal `ready`; por eso el diseño acepta entradas válidas con huecos
  y conserva el paquete para no perder tráfico.

## Verificación ya realizada

Herramienta: Vivado/XSim 2025.2.

Vector mínimo incluido:

| Orden | Entrada | Control |
| --- | --- | --- |
| 1 | `01020202` | `i_first=1` |
| 2 | `00C80010` | |
| 3 | `02019000` | `i_last=1` |

Salida observada:

| Orden | Salida | Control |
| --- | --- | --- |
| 1 | `01020002` | `o_first=1` |
| 2 | `00C80001` | `o_last=1` |

Resultado: `TASK_9_SMOKE_PASS`.

## Comandos reproducibles

Desde la raíz del repositorio, usando `hackathon/2026/team018_repo`:

```powershell
C:\AMDDesignTools\2025.2\Vivado\bin\xvlog.bat -sv `
  hackathon\2026\team018_repo\src\tasks\task_9\task_9.sv tmp_task9_tb.sv
C:\AMDDesignTools\2025.2\Vivado\bin\xelab.bat -debug typical `
  tmp_task9_tb -s task9_smoke
C:\AMDDesignTools\2025.2\Vivado\bin\xsim.bat task9_smoke -runall
```

El testbench `tmp_task9_tb.sv` es local y no forma parte del commit. Para una
revisión completa se recomienda añadir casos de dimensiones mayores, varios
pares, exponentes distintos y máximos configurables.

## Síntesis medida

Parte: `xck26-sfvc784-2LV-c`.

| Recurso | Resultado |
| --- | ---: |
| CLB LUTs | 5786 |
| CLB registers | 340 |
| DSPs | 1 |
| Puntuación | 6136 |

## Puntos de atención para quien verifique

- Confirmar con el modelo oficial la política esperada cuando el exponente
  normalizado excede 4 bits; el PDF no especifica saturación.
- Comprobar paquetes con huecos en `i_valid` y paquetes consecutivos.
- La RAM de entrada se infiere como distribuida por las dos lecturas asíncronas.
  Una optimización posterior debe mantener la tasa de cálculo al migrarla a BRAM.
