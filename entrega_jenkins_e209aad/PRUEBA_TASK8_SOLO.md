# Prueba aislada de task 8

Base: fe83473, prueba aislada anterior de task 15. Rama: test/task8-only.

- Solo task8 habilitada en task_enabler_pkg.svh.
- Task8 conecta el wrapper MicroBlaze oficial; no es un bypass.
- Las otras tasks FPGA permanecen deshabilitadas y en dummy. Task15 conserva su implementación bajo la misma macro de restauración que las demás; no definir TASK15_TRIAL_RESTORE_REAL_MODULES para esta prueba.
- Firmware: radix_sort_u32 de cuatro pasadas, 256 palabras unsigned, mismo código fuente probado con 10008 casos nativos en la VM en el worktree task8_analysis.
- Tcl, XSA, scripts oficiales, infraestructura e interfaces protegidas sin cambios. Siemens/Synopsys siguen siendo etapas independientes.

Validación previa: compilador MicroBlaze acepta main.c con -fsyntax-only -std=c11 -Wall -Wextra -Werror. Prueba nativa del algoritmo no valida DMA, placa, tiempo real ni puntuación. No se ha construido un ELF nuevo local para esta rama. El bootstrap de la copia VM falló al recuperar el componente app; Jenkins tiene que confirmar que su entorno oficial construye e integra correctamente este firmware.

Direcciones del firmware: BRAM 0xC0000000, scratch a +1024 bytes, DMA 0x41E10000. Revisar contra XSA/BSP si falla. El polling DMA no tiene timeout; un bloqueo requiere diagnosticar registros de estado, no declarar que falla el algoritmo de ordenación.

## Lanzamiento

Esta rama se prepara sin alterar main mientras corre Jenkins #19. El job actualmente toma main: publicar únicamente esta rama NO cambia lo que ejecuta Jenkins.

Cuando #19 haya terminado:
1. Registrar su resultado/commit y comprobar que no hay otra ejecución nueva.
2. Hacer fetch y comprobar si main ha cambiado. No sobrescribir trabajo ajeno ni usar force-push.
3. Promover este commit a main mediante avance rápido si sigue siendo compatible; si ha avanzado, revisar las diferencias.
4. Solicitar una sola ejecución y verificar en su consola el commit descargado y task8 habilitada.
5. Validar compilación del firmware, bitstream y resultados públicos/privados. SUCCESS global no garantiza puntos.

No se ha configurado un lanzamiento automático diferido en este documento.
