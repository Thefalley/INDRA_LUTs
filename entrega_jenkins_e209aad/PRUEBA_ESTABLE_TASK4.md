# Paquete estable + Synopsys task 4

Preparado el 27-09-2026. Padre: a12ead7 (prueba de task 15).

Actualizacion: main 2f37952 usa el archivo posterior `serial_frame_extender (1).sv`,
SHA256 90D8AAEE06568C3A89BDCDA7C31A333B81139A5595F2B971DA699F2A48A495B0.
Tambien paso 2123 tramas oficiales y 2000 locales. El hash y las correcciones
descritas abajo documentan la primera revision, 576077c.
Esta rama de candidatos modifica ademas RTL experimental: ver
PAQUETE_NUEVOS_CANDIDATOS.md; no confundirla con el paquete estable de main.

## Contenido exacto

- src/, siemens/ y vivado/: mismos contenidos que b38d0bb, evaluado en Jenkins #23.
- FPGA activadas: 1, 2, 3, 5, 10, 11, 12, 13, 14 y 16.
- Siemens task 6 mantiene su flujo independiente.
- Synopsys task 4 usa serial_frame_extender.sv procedente de cuarentena, corregido.
- FPGA 7, 8, 9 y 15 desactivadas. No se incluyen sus experimentos nuevos.
- No se cambian Tcl, XDC, wrappers, IP, scripts oficiales ni comparadores.

Task 4 no tiene enable FPGA: la ejecuta el flujo Synopsys.

## Correcciones de task 4

1. Dos tokens invalidos `1 me` sustituidos por `1'b0`.
2. El toggle del receptor identifica el PROXIMO banco de escritura. El transmisor
   debe leer `~wr_sync_2`, tanto al seleccionar el banco como al enviar su primer bit.
3. Se conserva indice binario normal MSB-first, como aparece en las paginas visibles
   del enunciado. No se usa el texto antiguo oculto extraido que dice inversion.

SHA256 del RTL validado (bytes locales):
`5D261D46E7B54429F5BA34AAAE2B1DBFED3F00FE304DA3B1B456B25F262E3FAA`.

## Validacion antes de publicar

- VCS X-2025.06-SP2-3 en la VM: `synopsys/runbatch` oficial, sin cambios logicos
  de scripts ni testbench. Solo conversion CRLF a LF en la copia Linux.
- Resultado: `[PASS] Checked 2123 frames successfully.`
- Latencia oficial informada: 128 ciclos de entrada.
- Cobertura del test oficial: 2000 tramas aleatorias, extremos 0/119 y barrido
  de las 120 posiciones. Log: ../ref_task4/official_synopsys.log (local).
- XSim 2025.2 en este PC: 2000 tramas continuas, todas las posiciones,
  datos/indice/reloj/latencia sin discrepancias. Test propio, no sustituto del oficial.
- Comparacion de src/, siemens/, vivado/ frente a b38d0bb: identicos.

La FPGA conjunta no se ha vuelto a implementar localmente para este commit:
se reutiliza exactamente el RTL/configuracion que puntuo en #23. La proxima
ejecucion de Jenkins comprobara de nuevo la integracion.

## Exclusiones deliberadas

- #25 termino SUCCESS pero task 15 obtuvo 0 publico y 0 privado. No se incluye.
- Task 9 nueva pasa 46 casos locales y OOC, pero aun no juez privado.
- Task 8 multi-histograma pasa 10008 vectores y enlaza en MicroBlaze;
  no se conoce su latencia en placa.
- Task 7 sigue pendiente de reconciliar matematicas/marcos y referencia publica.

El SUCCESS de Jenkins no basta: comprobar puntuaciones individuales y PASS Synopsys.
