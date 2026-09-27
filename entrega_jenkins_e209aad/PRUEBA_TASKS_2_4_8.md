# Prueba conjunta tasks 2, 4 y 8

Base: merge del compañero 2d813e7, con fixes a79b5d3 (task2) y 2441be6 (task4). Se conservan esos dos archivos sin modificaciones adicionales.

- FPGA: solo tasks 2 y 8 habilitadas y reales.
- Task4: serial_frame_extender corregido en synopsys/verilog, evaluado por la etapa Synopsys. Su bit task4 del selector FPGA queda 0 porque el flujo oficial lo marca no usado.
- Task15 queda en dummy deshabilitada, conservando su RTL. Las otras tasks FPGA permanecen en dummy.
- Task8: wrapper oficial MicroBlaze y firmware radix probado a nivel de algoritmo (10008 casos nativos). DMA y juez completo pendientes.
- Tcl, XDC, infraestructura, restricciones y estrategia no se modifican. Jenkins sobrescribe la estrategia con Flow_RuntimeOptimized; esta NO es una prueba Congestion_SpreadLogic_medium.
- No se incluye la variante BRAM local de task2: se utiliza la versión corregida y pipelineada del compañero.

Este documento sustituye la selección indicada en PRUEBA_TASK8_SOLO.md, que queda como antecedente de la rama de task8 aislada.

Lanzar cuando Jenkins #19 haya terminado, comprobar su puntuación de task15 y registrar el nuevo número y commit. SUCCESS no garantiza resultados positivos de todas las tasks.
