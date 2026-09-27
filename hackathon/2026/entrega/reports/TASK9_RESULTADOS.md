# Task 9: pipeline continuo entre bloques

Rama experiment/ref-task9, base a12ead7. No publicada en main.

## Cambios

Se parte conceptualmente del candidato de tmp/task9_investigation, conservando
dos bancos BRAM par/impar y dos bloques-fila por solicitud. Ahora las etiquetas
first/last/final viajan por lectura, producto, suma parcial y acumulador. Se
eliminan las burbujas de FSM entre resultados. Multiplicacion explicitamente
7x7 -> 14 bits, extension de signo antes de desplazar. Acumulacion ampliada
a 50 bits para representar el extremo positivo 64*4096*2^30 = 2^48.

## Simulacion XSim local

46 casos; cero discrepancias de datos, first, last, cantidad y orden.
Modelo independiente de productos de columnas con enteros de 64 bits.

| Caso | Candidato previo | Nuevo (ciclos desde ultima entrada) |
|---|---:|---:|
| 64x64 por 64x64, 1 par | 21506 | 16390 |
| 6x6 por 6x10, 5 pares | 527 | 156 |
| 2x2 por 2x2, 255 pares | 1532 | 261 |
| 2x64 por 2x64, 32 pares | 196610 | 32774 |

Ultimo caso: 327.74 us a 100 MHz DESDE ULTIMA ENTRADA. No confundir con
tiempo desde inicio de paquete: con pausas del test, 35643 ciclos.
No se garantiza bonus ni latencia integrada del juez con este dato.

## Implementacion aislada en VM

Vivado 2025.2, xck26-sfvc784-2LV-c, RuntimeOptimized, reloj 10 ns.
4580 LUT, 1453 FF, 4 BRAM36, 1 DSP.
Informe final: WNS +2.687 ns; WHS +0.071 ns; TNS/THS 0.
Sintesis 78 s, placement 88 s, routing 34 s en la VM.
Sin errores/critical warnings de implementacion. Existen advertencias OOC:
HD.CLK_SRC ausente, entradas/salidas sin delays/ubicacion y comprobaciones DRC
de conectividad no aplicables. NO es signoff integrado.

## Riesgos pendientes

Normalizacion por magnitud heredada: representacion de -64 y resultados que
exigen exponente >15 siguen sin criterio explicito confirmado del juez. Los
46 casos usan exponentes/resultados representables; no cubren todo overflow.
Todavia no se ha reejecutado el vector publico oficial contra ESTE pipeline.
No anunciar puntos privados ni task completamente resuelta.

Reproducir: xvlog -sv src/tasks/task_9/task_9.sv experiments/tb_task9_extended.sv;
xelab tb_task9_extended -s task9_adapted; xsim task9_adapted -runall.
OOC: vivado -mode batch -source experiments/implement_ooc.tcl -tclargs 9.
