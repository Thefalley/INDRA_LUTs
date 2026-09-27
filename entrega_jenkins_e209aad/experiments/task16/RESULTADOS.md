# Task 16: ensayo de aceptacion simultanea

Fecha: 2026-09-27. Base exacta: `2f379527b8c3c25260ed7d3e07e50ec21976aecf`.
Esta es una prueba local de nuestro RTL, no el test oficial del juez.

## Motivacion y cambio

Referencia de arquitectura y verificacion:
[ZipCPU axispacker](https://github.com/ZipCPU/wb2axip/blob/master/rtl/axispacker.v),
packer AXI-Stream con TKEEP y propiedades de backpressure (Apache-2.0).
No se ha copiado su RTL ni sus assertions. El test y el cambio son propios.

Nuestro buffer tiene 8 bytes. Antes no aceptaba datos si habia 5..8 bytes,
aunque en ese mismo flanco salieran 4. Ahora puede aceptar hasta 4 bytes
si simultaneamente se consume una salida completa. Sigue prohibiendo la
entrada cuando hay un fin de paquete pendiente.

Invariante para la nueva aceptacion: si el contador es mayor que 4, existe
salida completa; al retirar 4 y anadir como maximo 4, el contador sigue <=8.
No se cambia formato, orden, datos, restricciones oficiales ni enablers.

Riesgo: se introduce dependencia combinacional `o_ready -> i_ready` entre
las dos interfaces. Hay que comprobarla en el wrapper integrado y evitar
lazos o cadenas largas de READY. Un skid buffer registrado es otra opcion,
pero tendria coste adicional y NO esta implementado en este ensayo.

## Resultados realmente ejecutados

Vivado/XSim 2025.2, PC local. Semilla fija reiniciada por caso; los dos DUT
reciben los mismos paquetes. Los stalls aleatorios son locales a cada run,
por lo que el tiempo de los casos con backpressure es una observacion del
banco, no una comparacion a identica traza temporal de READY.

| Medida | Base | Candidato |
|---|---:|---:|
| Paquetes completos | 256 PASS | 256 PASS |
| Bytes comparados | 192105 | 192105 |
| Ciclos acumulados del banco | 104763 | 86340 |
| Modo 3 bytes/beat, sin pausas | 22572 | 15095 |
| Modo 1/2/3/4 bytes, sin pausas | 22569 | 16447 |
| Modo aleatorio con pausas | 44474 | 39650 |
| Modo 4 bytes/beat, sin pausas | 15148 | 15148 |
| LUT, implementacion OOC | 104 | 103 |
| FF, implementacion OOC | 69 | 69 |
| BRAM / DSP | 0 / 0 | 0 / 0 |
| WNS OOC a 10 ns | +6.897 ns | +7.070 ns |
| WHS OOC | +0.138 ns | +0.113 ns |
| TNS / THS | 0 / 0 | 0 / 0 |
| synth_design elapsed | 23 s | 23 s |
| place_design elapsed | 72 s | 74 s |

El banco comprueba valores y orden de cada byte valido, longitudes,
exactamente un LAST, KEEP completo salvo al final y estabilidad de
DATA/KEEP/LAST/VALID durante backpressure. Incluye paquetes de 4 a 512 beats,
invalid bytes no nulos y paquetes consecutivos sin reset entre ellos.
No modela metastabilidad ni prueba exhaustivamente todos los estados.

Reduccion de ciclos global observada: 17.59%. En los casos deterministas
de 3 bytes/beat: 33.13%; en mezclas 1/2/3/4: 27.13%; a 4 bytes/beat: 0%.
NO es una promesa de bonus ni de mejora del tiempo de construccion de Jenkins.

## Limites de la implementacion aislada

`ooc.tcl` ejecuta synth/opt/place/route RuntimeOptimized sobre xck26.
Clock 10 ns, input/output delay de diagnostico 1 ns, sin false paths.
No se modifica el XDC oficial. Ambos reportes tienen cero endpoints
internos sin restricciones y cumplen sus restricciones locales.

Vivado advierte de puertos OOC sin HD.PARTPIN_LOCS y de HD.CLK_SRC;
los retardos de conexion al resto del diseno NO estan representados.
En particular, el camino READY->READY tiene conexion exterior sin enrutar.
Por ello los valores de slack no son signoff del sistema completo.
No se genero bitstream ni se evaluo esta variante en placa/Jenkins.

No hay evidencia de ahorro de tiempo de implementacion: placement tarda
aproximadamente igual y las dos pruebas se lanzaron en paralelo en el PC.
Task16 es pequena; el principal objetivo de tiempo global sigue siendo
reducir memorias mal inferidas y congestion en los modulos grandes.

## Reproduccion

Crear una copia limpia de la base en otro worktree y ejecutar:

```powershell
git worktree add --detach ../task16_baseline 2f379527b8c3c25260ed7d3e07e50ec21976aecf
./experiments/task16/run_compare.ps1 -BaselineRoot ../task16_baseline
```

El parametro `-VivadoBin` permite cambiar la ruta de herramientas.
Para OOC, desde un directorio de resultados vacio:

```powershell
& 'C:/AMDDesignTools/2025.2/Vivado/bin/vivado.bat' -mode batch -source /ruta/al/repo/experiments/task16/ooc.tcl -tclargs /ruta/al/repo
```

Los logs comparativos y reportes finales se conservan en `reports/task16/`.
Los productos grandes temporales se excluyen de Git.

## Decision

Integrar en el paquete EXPERIMENTAL para revision y futura prueba integrada.
No sustituir silenciosamente la version puntuada en main. Si el wrapper
penaliza el camino combinacional de READY, conservar la base o ensayar
un buffer registrado; no ocultar la ruta con excepciones de timing.
