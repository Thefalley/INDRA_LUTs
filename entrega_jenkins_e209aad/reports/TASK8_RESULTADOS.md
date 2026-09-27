# Task 8: multihistograma experimental

Rama experiment/ref-task8, base a12ead7. No publicada en main.

- Cambio solo en main.c: contar los cuatro histogramas de bytes en una unica
  pasada de entrada; reutilizarlos durante las cuatro pasadas LSD estables.
- Inspiracion algoritmica: https://github.com/eloj/radix-sorting . Implementacion
  propia sobre el sorter existente; no se copia un fichero externo.
- Prueba en VM con GCC 9.2, ASan y UBSan: PASS 10008 vectores contra qsort
  unsigned, incluyendo extremos, duplicados y canarios de memoria.
- Enlace MicroBlaze completo con BSP y linker oficial existentes, -O2:
  text 3780, data 96, bss 9572; total 13448 bytes. Enlaza sin overflow.
- No se modifica hardware, DMA, protocolo, buffers MMIO ni coherencia de cache.
- Aun no se ha medido la velocidad en MicroBlaze real. El coste extra es
  3072 bytes de histogramas, mas el crecimiento de codigo; NO se promete <1 ms.

Codigo local SHA256: 7af611881eead0f542335a44fc0e250e523f68ad2e1d92134bb0aaab76689c2f.
VM: /home/team018/ref_task8/sw. tests/link_vm.sh reproduce enlace de diagnostico.
Jenkins #24 del sorter ANTERIOR tuvo latencia 182135 y cero puntos; no atribuir
ese resultado al candidato nuevo, ni considerar el test CPU un test de DMA.
