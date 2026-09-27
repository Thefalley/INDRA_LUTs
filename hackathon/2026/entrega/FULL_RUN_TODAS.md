# Full run experimental: todas las implementaciones disponibles

Solicitud expresa del usuario: probar todas juntas, incluidas7/8/9/15.
Base del paquete:6e5d18c. Ultima main estable previa:2f37952.

FPGA habilitadas:1,2,3,5,7,8,9,10,11,12,13,14,15,16.
Tasks4 y6: flujos independientes Synopsys y Siemens; sus bits no se activan.
No se modifican Tcl, XDC, wrappers, directivas ni infraestructura MicroBlaze.

Incluye task4 corregida, task8 multihistograma, task9 pipeline continuo,
task16 aceptacion simultanea y el RTL real disponible de7 y15.

LIMITES CONOCIDOS:7 sigue con errores funcionales;15 obtuvo cero puntos
en una evaluacion anterior.8 tiene pruebas CPU y ELF enlazado, no PASS
de esta version en placa.9 y16 tienen pruebas locales e implementacion
aislada, no signoff del conjunto. Esta run busca resultados y logs;
no se presenta como version certificada ni garantiza recursos o timing.

Los estados de PAQUETE_NUEVOS_CANDIDATOS.md describen el paquete anterior
con7/8/9/15 deshabilitadas. Para ESTA run manda task_enabler_pkg.svh y
la lista de habilitacion de este documento.

La referencia remota archive/stable-before-full-all conserva2f37952.
No sobrescribir ese punto ni recuperar mediante force-push: si hay que
volver a la version estable, hacerlo mediante un commit de restauracion.
