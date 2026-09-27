# Prueba conjunta de las versiones que ya puntuaron

Objetivo: medir en un solo Jenkins las tasks con resultado positivo tanto publico como TV/gold. No garantiza recursos, timing ni puntuacion conjunta.

| Tasks | Version de procedencia | Jenkins previo |
|---|---|---|
| 1, 5, 11, 13 | Conservadas desde main 4c92c3e; mismas implementaciones de 0791f35 | 16 |
| 3, 12, 14 | 085fb74 | 15 |
| 10, 16 y auxiliares | 5c44f7e | 14 |
| 6 Siemens | Parser restaurado en 4c92c3e desde 30fb769 | 12 |

FPGA activadas: 1, 3, 5, 10, 11, 12, 13, 14, 16.
Task 6 se ejecuta en el flujo independiente Siemens: su bit FPGA permanece a 0, como en la infraestructura oficial.
Desactivadas: 2, 4, 7, 8, 9, 15. Task 4 tiene un flujo independiente Synopsys que Jenkins puede ejecutar igualmente; no se elimina ni se cambia.
Task 9 se conserva en disco, desactivada porque dio 3 publico y 0 gold.

No se cambian wrappers, MicroBlaze ni hardware oficial. Unica ampliacion del Tcl: registrar los tres auxiliares de task 16, junto a los de task 13 ya presentes.
No se incorporan versiones locales experimentales, incluida la mejora parcial de task 5 ni la task 7 en estudio.

Referencia historica de este conjunto: 46 puntos publicos y 130 TV/gold, sumados por separado entre distintas ejecuciones. No es una promesa ni un total oficial de ranking.
