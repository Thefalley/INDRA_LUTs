# Task 15: correccion funcional de la matriz generadora

Base: 23adbf1. Rama local: fix/task15-validation. Fecha: 2026-09-27.
No incluida en el Jenkins #27, que construye la base anterior.

## Fallo reproducido

El RTL anterior presupone H=[P^T|I] y copia P sin reducir H.
Pasa el vector oficial local, pero falla al aplicar operaciones invertibles
de filas que preservan EXACTAMENTE el conjunto de palabras validas.
En seis pruebas: dos pasan, cuatro fallan; 696 bytes incorrectos.
Esto demuestra un defecto, no demuestra que sea la unica causa del cero
de Jenkins: no tenemos el vector exacto de aquella evaluacion.

## Correccion

- Gauss-Jordan sobre GF(2), con XOR, intercambio de filas y pivotes de
  derecha a izquierda; no permuta las columnas de salida.
- Construye la base del nucleo usando las columnas libres en orden creciente.
- Enumera mensajes MSB primero y conserva un byte 00/01 por bit de salida.
- Construye un vector generador por ciclo; evita una gran red combinacional.
- Matrices dimensionadas con margen para los limites documentados: 16x32
  para H, 12x32 para G. Con rango completo, entrada <=198 bytes y salida
  <=3592 bytes implican dimensiones que caben en estos limites.
- Mantiene interfaz, reset, LAST y memoria de salida; no cambia Tcl/XDC
  oficiales, wrappers, tolerancias ni criterios del juez.

## Pruebas ejecutadas con XSim 2025.2

| Prueba | Resultado |
|---|---|
| Vector oficial tb/task15.mem y task15_ref.mem | 208/208 bytes, cero errores |
| Etapas del vector oficial | H:117 bits, G:52 bits, 16 palabras, 144 sindromes nulos |
| Seis casos iniciales tras correccion | 6/6 PASS |
| Barrido ampliado | 48/48 PASS, cero errores |
| Paquetes consecutivos de dimensiones distintas sin reset entre ellos | Incluidos en barrido |
| Pausas de entrada, LAST, longitud, datos | Comprobados |

El barrido contiene los seis casos iniciales y 42 pares (m,n) compatibles
con los limites numericos del PDF. Usa una matriz generada por par, con
operaciones de filas y permutacion de columnas. No es una prueba exhaustiva
de TODAS las matrices. El oraculo enumera todos los vectores n-bit y retiene
solo aquellos con H*c^T=0; es independiente del algoritmo RTL.
El orden lexicografico coincide con el ejemplo oficial, pero falta comprobar
la convencion del juez para matrices no sistematicas.

## Sintesis aislada

Dispositivo xck26-sfvc784-2LV-c, Vivado 2025.2:

| Recurso | Resultado |
|---|---:|
| LUT | 3508 |
| FF | 1245 |
| BRAM36 | 1 |
| DSP | 1 |
| synth_design elapsed | 32 s |

Cero errores y cero avisos criticos. Avisos de registros no usados y
floorplanning; informe temporal OOC avisa de HD.CLK_SRC no definido.
WNS estimado post-sintesis +5.782 ns a 10 ns. NO es cierre de timing:
no hay placement/routing integrado ni restricciones de entrada/salida.

Latencia medida desde terminar la entrada hasta terminar la salida:
361..7497 ciclos en el barrido (3.61..74.97 us a 100 MHz).
Algunos casos superan el umbral de bonus de 21 us del PDF. Esta version
prioriza correccion; no acredita puntuacion ni bonus en placa.

## Reproduccion

Desde PowerShell: `./experiments/task15/run_check.ps1`.
Para sintesis, ejecutar Vivado batch con `experiments/task15/synth_check.tcl`
desde un directorio de resultados separado.
Los logs e informes resumidos se conservan en `evidence/`.

Fuente revisada: material_hackathon/15_LDPC_Encoder.pdf, las cuatro paginas:
H*c^T=0, c=u*G, orden del ejemplo, entrada m/n y H por filas,
salida un byte por bit, comparacion byte a byte y limite de bonus.

Pendiente: validacion integrada y juez oficial antes de declarar resuelta
la task o sustituir la version evaluada.
