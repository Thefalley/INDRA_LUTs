# Proxima prueba diagnostica: 5, 7 y 8

Preparada, no lanzada ni promovida a main. Esta seleccion sustituye la de FULL_RUN_CANDIDATA.md, conservado como historial.

FPGA habilitadas exclusivamente5,7,8. Resto de src recuperado de6dcfc72: dummies registrados y dependencias oficiales conservadas. Siemens/Synopsys siguen flujos independientes.

## Versiones

-5:RTL puntuado15gold en #22, sin cambios.
-7:CORDIC conXYQ32,anguloQ30,24iteraciones, salida explicita gradosQ12 y radioQ12. Se integra en el mismo task_7.sv; no requiere editar Tcl para auxiliares. Es diagnostico: prueba directa con vectores oficiales sigue0/12angulos; geometria/ecuaciones no resueltas. No presentarla como aprobada.
-8:software -O2 y buffers/histograma privados en LMB, con copia desde/hacia bufferDMA.10008vectores qsort+sanitizers PASS. ELF completo generado en VM con Vitis2025.2:3516text+96data+6500bss=10112bytes segun size (incluye reservas segun linker). Falta prueba real MicroBlaze/DMA y latencia. No se cambia hardware.

## Directiva rapida

El flujo oficial observado en Jenkins configura:
```tcl
set_property strategy Flow_RuntimeOptimized [get_runs synth_1]
set_property strategy Flow_RuntimeOptimized [get_runs impl_1]
```
Esta es la configuracion rapida prevista. NO se promete ahorro frente a #22: alli ya estaba activa. No se modifica CI, XDC ni incremental. No se usa SpreadLogic_medium, que no demostro mejora en el ensayo aislado task1.
Confirmar comandos efectivos en el log de la proxima ejecucion. No editar hackathon.tcl para aparentar un cambio que CI sobrescribe.

## Antes de lanzar

1.Comprobar estado/colaJenkins y preservar mainestable b38d0bb; esta rama no debe interrumpir ese build.
2.Si se autoriza promover, push sin fuerza y comprobando divergencias.
3.Jenkins debe reconstruir ELF y asociarlo a MicroBlaze; no subir binarios generados.
4.Revisar puntuacion/latencia por task; SUCCESS no es PASS de7/8.
5.No incorporar esta rama completa a la fullrun como si todas sus tasks estuviesen validadas. Integrar solo cambios comprobados.
