# Prueba aislada de task 15

Esta configuracion sustituye a SOLO_TASKS_7_8.md y a las propuestas anteriores.
Base: 41517ed. Solo task15 habilitada en task_enabler_pkg.svh.

- Task15: RTL real copiado de la carpeta compartida, sin modificaciones.
- Task7: restaurado dummy registrado original fa7ec0f.
- Resto FPGA: dummies del commit base, excepto infraestructura oficial task8.
- Task8: deshabilitada para el juez; MicroBlaze, DMA y software se conservan
  para no romper dependencias y asociacion ELF del flujo oficial.
- Task16: se conserva dummy registrado y su jerarquia para report_utilization.
- Tcl, XDC, IP, wrappers, Synopsys (4) y Siemens (6): sin cambios.
  Los flujos 4 y 6 son independientes y pueden seguir ejecutandose en CI.

## Validacion previa

XSim local y XSim en VM: ejemplo publico task15.mem/task15_ref.mem.
117 elementos de H, 52 de G, 16 palabras, 144 ecuaciones de sindrome,
208 bytes almacenados y 208 transmitidos: todos correctos. o_last correcto.
No equivale a aprobar todos los vectores privados ni todos los tamanos.
La implementacion presupone H=[P^T|I]; conserva los limites del RTL actual.

VM: /home/team018/checks_7_8_15_20260927/task15_stage_check/task15_vm.log
Local: tmp/task15_stage_check/stage_check.log en el workspace principal.

La task7 sigue fallando sus 12 angulos publicos. La task8 pasa 10008 pruebas
de algoritmo en CPU, pero Jenkins24 rechaza su latencia de ~1.82 ms.
Ninguna de ellas se habilita en esta prueba.
