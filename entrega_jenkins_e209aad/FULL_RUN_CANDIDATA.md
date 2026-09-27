# Full run estable: selección aprobada para Jenkins

Selección solicitada: 1, 2, 3, 5, 6, 8, 9, 10, 11, 12, 13, 14 y 16.

Preparación FPGA actual: 1, 2, 3, 5, 10, 11, 12, 13, 14, 16 habilitadas.
Task 6 conserva su flujo Siemens independiente; no necesita enable FPGA.
Task 8 conserva implementación real e infraestructura MicroBlaze pero enable=0 hasta revisar Jenkins 22.
Task 9 queda deshabilitada y pendiente del trabajo fix/task9-investigation: no habilitar su dummy como si fuese solución.
Tasks 7 y 15 no se incluyen en esta selección. La 4 mantiene Synopsys, independiente del enable.

Base: 6dcfc72 (5/7/8). Se recuperan las implementaciones previamente puntuadas del paquete e0e14fd para 1,3,5,10,11,12,13,14,16; task7 vuelve al estado deshabilitado de ese paquete. Se conserva task2 corregida de main, con puntuación parcial histórica de 10 gold. Auxiliares y Tcl oficiales preservados.

Actualización: #22 terminó SUCCESS. Task5 obtuvo 5 público / 15 gold, task6 6/6; task7 y task8 cero. El usuario autoriza publicar y lanzar el conjunto estable con task2. No activar 8/9 para esta ejecución. La compilación SV del conjunto pasó; la validación integrada queda a cargo de esta nueva ejecución, no se da por superada.

La directiva de la entrega sigue siendo la oficial RuntimeOptimized. No se incorpora SpreadLogic_medium: Jenkins la sobrescribiría al configurar sus runs y el ensayo local task1 no demostró ahorro. No se modifican scripts oficiales ni restricciones. Las variantes BRAM/directivas se investigan en worktrees locales separados.

## Puertas de validación

1. Compilar fuentes, auxiliares y firmware; simular tests oficiales disponibles.
2. Revisar #22 por task, no solo SUCCESS; habilitar 8 únicamente con evidencia o decisión explícita de ensayo diagnóstico.
3. Integrar 9 solo tras revisar pista, implementación y tests; documentar resultados parciales si los hay.
4. Variantes BRAM 3/12 se comparan en rama separada; esta rama conserva baseline puntuado.
5. Comprobar recursos, DRC y timing integrados. No extrapolar OOC al conjunto.
6. Directivas oficiales sin modificar. Comparación local: RuntimeOptimized frente a SpreadLogic_medium; ensayo previo task1 no fue más rápido con medium.

Este archivo sustituye la selección descrita en PRUEBA_TASKS_5_7_8.md, que queda como registro del commit anterior, no configuración actual.
