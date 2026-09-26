# Metodología de diseño — Task 1: Shifter

## Objetivo

Implementar el desplazamiento o la rotación de un paquete de bytes MSB-first respetando el protocolo `valid/first/last`. La entidad, los parámetros y los puertos del wrapper se conservan sin cambios.

## Criterios de arquitectura

1. Se usa una única máquina de estados. El flujo de entrada, la emisión inmediata cuando es causal y el vaciado final forman parte de la misma FSM.
2. Los dos primeros bytes se capturan como control; el resto se interpreta como paquete de datos.
3. El desplazamiento lógico a la derecha se emite mientras llegan los datos: no espera al paquete completo.
4. El desplazamiento y la rotación a la izquierda conservan únicamente la ventana inicial necesaria. Los bytes de salida se emiten al llegar el byte que completa esa ventana; al final se vacía la cola pendiente.
5. La rotación a la derecha necesita conocer el final del paquete para escoger el primer byte de salida, por lo que se almacena el paquete y se emite después de `last`.
6. Para paquetes menores que la ventana requerida, se usa una ruta corta almacenada, sin modificar el protocolo externo.

## Optimización aplicada

El primer planteamiento de referencia reconstruía bytes mediante un recorrido por bits y cálculos genéricos de división y módulo. Esta iteración los elimina del camino de datos:

- Los desplazamientos se expresan con índices de byte, desplazamientos de 0 a 7 bits y una concatenación de dos bytes adyacentes.
- Las rotaciones reducen el desplazamiento con restas sucesivas del tamaño real del paquete y recorren la memoria con dos punteros circulares.
- Los punteros se actualizan con comparaciones y suma/resta; no se sintetizan operadores `%` o `/` de ancho variable.

Esta elección prioriza LUTs y una ruta combinacional más corta frente a una formulación compacta pero costosa.

## Estados de la FSM

| Estado | Función |
| --- | --- |
| `ST_WAIT` | Espera el primer byte de control. |
| `ST_CTRL_0` | Captura el segundo byte de control. |
| `ST_STREAM` | Recibe datos y emite de forma directa los casos causales. |
| `ST_LEFT_FLUSH` | Emite los bytes pendientes del final para operaciones a la izquierda. |
| `ST_SHORT_SHIFT_OUT` | Emite un desplazamiento de un paquete más corto que la ventana. |
| `ST_SHORT_ROT_PREP` / `ST_SHORT_ROT_OUT` | Reduce y emite una rotación izquierda corta. |
| `ST_ROT_RIGHT_PREP` / `ST_ROT_RIGHT_PRIME` / `ST_ROT_RIGHT_OUT` | Reduce, precarga BRAM y emite una rotación derecha. |

## Verificación

Se ejecuta XSim con:

```powershell
Set-Location team018_repo\tb
& 'C:\AMDDesignTools\2025.2\Vivado\bin\xvlog.bat' -sv '..\src\tasks\task_1\task_1.sv' 'task_1_smoke_tb.sv'
& 'C:\AMDDesignTools\2025.2\Vivado\bin\xelab.bat' task_1_smoke_tb -s task_1_smoke
& 'C:\AMDDesignTools\2025.2\Vivado\bin\xsim.bat' task_1_smoke -runall
```

El smoke test registra cada transferencia aceptada en `tb/logs/task_1_input_handshake.txt` y cada salida válida en `tb/logs/task_1_output_handshake.txt`. Además del vector del smoke test, se validan desplazamiento y rotación, izquierda y derecha, junto con paquetes de un byte y desplazamientos no alineados.

## Medición de recursos y latencia

La utilización se obtiene con síntesis para `xck26-sfvc784-2LV-c`. La puntuación pedida se calcula como `CLB_LUTs + CLB_REGs + 10*DSP`.

La latencia se expresa en ciclos entre la transferencia de cada byte de entrada y su byte correspondiente de salida. Para una frecuencia concreta, `latencia_tiempo = latencia_ciclos / frecuencia_reloj`. El proyecto no impone aquí una restricción de reloj, por lo que el margen temporal final debe confirmarse dentro del proyecto Vivado con su XDC definitivo.

## Resultado de esta iteración

Síntesis aislada con Vivado 2025.2 para `xck26-sfvc784-2LV-c`:

| Métrica | Resultado |
| --- | ---: |
| CLB LUTs | 5.901 |
| CLB Registers | 4.328 |
| DSPs | 0 |
| `LUTs + Registers + 10*DSPs` | **10.229** |
| Block RAM Tile | 2 |

La formulación inicial usaba 122.267 LUTs y excedía la capacidad de 117.120 LUTs del dispositivo. La primera optimización la redujo a una puntuación de 108.422, pero aún conservaba el paquete de 4.096 bytes como registros y multiplexores asíncronos. La versión final usa dos BRAM36 síncronas para la rotación derecha y RAM distribuida para las ventanas de streaming: reduce la puntuación a 10.229 y deja el uso de LUTs en 5,04%.

XSim ha completado sin errores el smoke test, los cuatro modos principales (shift y rotate, izquierda y derecha) y los paquetes cortos de un byte con desplazamientos no alineados.
