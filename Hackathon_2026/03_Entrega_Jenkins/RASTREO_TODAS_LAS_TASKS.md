# Rastreo publico: todas las tasks y ediciones anteriores

Fecha: 27 de septiembre de 2026. Base local estable inspeccionada: `2f37952`.

## Conclusion verificable

Se localizaron soluciones parciales de ediciones anteriores y bloques
publicos aplicables. NO se ha encontrado una solucion exacta de los 16
ejercicios actuales que este verificada contra el juez de 2026.
No encontrarla en estas fuentes no demuestra que no exista.

La coincidencia mas directa de FUNCION es `axispacker` para task16.
Para task4 se localizaron patrones de CDC y doble buffer, pero no el
`serial_frame_extender` exacto. La version local de task4 ya tiene un
PASS oficial de 2123 frames; no tiene sentido sustituirla por un UART
generico o por la task4 de otro ano.

## Metodo y limites

- Busquedas por nombre exacto, modulo RTL, frase del enunciado y algoritmo.
- Busquedas 2021/2022/2023/2024/2025/2026 y Nokia/Krakow, no solo FPGA.
- Busqueda en nombres y README mediante la API publica de GitHub.
  La consulta `"FPGA Hackathon" in:readme` devolvio 45 repositorios;
  se filtraron candidatos relevantes y se inspeccionaron arboles/fuentes.
  No se han leido completos los 45 proyectos.
- Se revisaron arboles de 14 candidatos concretos, ademas de bibliotecas.
- Se siguio la pagina del ganador 2025, MalaGana, hasta su GitHub:
  [la organizacion no mostraba repositorios publicos](https://github.com/malagana-io).
- La API tuvo un limite temporal 403; consultas posteriores funcionaron.
  grep.app devolvio 429, por tanto NO se presenta como una busqueda de
  codigo completada. No se han accedido repositorios privados ajenos.
- Los resultados del buscador que correspondian a otros hackathons,
  perfiles, audio/VGA, ML, IoT o RISC-V distintos se descartaron.
- Publico no equivale a licencia de reutilizacion. No se copiaron ni
  ejecutaron scripts de los repositorios encontrados.

## Repositorios de otros anos: que contienen de verdad

| Repositorio / revision inspeccionada | Resultado |
|---|---|
| [mennovf/FPGAHackathon2023](https://github.com/mennovf/FPGAHackathon2023/tree/41ea0620084a474fc3e37d0fa1039a5fea0e4ec5) | Soluciones parciales reales: RGB->gray, line buffer, octantes, butterfly, reciprocal sqrt y demodulacion. No son los ejercicios actuales. Su README explica simplificar matematicas antes de anadir hardware. |
| [highvoltagecontrol/fpga_hackathon_task8](https://github.com/highvoltagecontrol/fpga_hackathon_task8/tree/92287e7159b44ea86f2fa900989f879443f57c5a) | Infraestructura Quartus y problemas 2023. La task8 es butterfly, no nuestro sorter MicroBlaze. No se han validado sus soluciones. |
| [SuperChamp234/fpgahackathon2025](https://github.com/SuperChamp234/fpgahackathon2025/tree/79e03c870c14b60a15dd6d9ef615ea3fba91f2c5) | Archivo de enunciados/plantillas. Los 14 archivos de task revisados contienen marcadores dummy. La task12 inspeccionada es paso entrada-salida, no un compresor resuelto. Su README no concede derechos sobre material ajeno. |
| [jigglestrudel/nokia-hackathon-2025](https://github.com/jigglestrudel/nokia-hackathon-2025/tree/2977545cc6e035bae8c1832a7928335972f4b9cc) | Soluciones parciales; el autor declara puesto17. Hay cambios de implementacion en 1/3/5/6/7/8/11; otras siguen plantilla. Se inspecciono el producto escalar de la7. Las4/12/14 inspeccionadas son dummy. No inferir que todas pasan. |
| [MUDAL/Personal_FPGA_Reference_Designs](https://github.com/MUDAL/Personal_FPGA_Reference_Designs/tree/6ee0871c19221edac27979769a12ed5877b4918e) | Soluciones y tests de Maximum Finder y Matrix Traverse 2025, mas ejercicios academicos. Codigo MIT. Util para organizacion de memoria y tests, no para calibracion Hitachi ni serial frame extender. |
| [JuliaBraglewicz/FPGA-Hackathon-2026](https://github.com/JuliaBraglewicz/FPGA-Hackathon-2026/tree/0b1006d371aab89f1d568fef2a5454337e4fa99f) | Solo README en la revision consultada. No hay RTL que integrar. |
| [khaled1113/Nokia-Hackathon](https://github.com/khaled1113/Nokia-Hackathon/tree/ca24143c8313ad0ece877b4bd1c3ea5bc46f6243) | Guia de preparacion en README, no soluciones RTL. |
| [kuznia-rdzeni/coreblocks](https://github.com/kuznia-rdzeni/coreblocks/tree/7dbcf4a943b94cc79d513456b2b8d90804510577) | Proyecto de CPU RISC-V, no entrega de estos ejercicios. No reemplaza la ISA propia de task14. |

Otros arboles inspeccionados y descartados por tema/contenido:
`Chetan2003/FPGAHackathon` (LSTM/packet sniffer),
`goelraghav002/FPGA_hackathon` (web/material),
`Dor-Snapiri/FPGA-Hackathon` (DNA),
`Plinsboorg/FPGA_hackathon` (README),
`AnjelikaBab/fpga-challenge-hackathon` (video/SDI),
`Meghadri25/FPGA_Hackathon` (red neuronal).

### Correspondencia 2025 -> 2026

El numero de task NO identifica el algoritmo entre ediciones:

- 2025/4 Sorting Algorithm: potencial referencia de ordenar, no 2026/4.
- 2025/7 Optimal Dot Product: idea de datapath para 2026/9, no brazo robotico.
- 2025/11 Hamming Correction: codigo corrector distinto de LDPC2026/15.
- 2025/12 MoonCompress: NO equivale al packer TKEEP2026/16.
- 2025/14 LIR: NO equivale automaticamente a la MCU2026/14.

## Inventario de las 16 tasks

En ninguna fila se afirma haber encontrado la entrega exacta del concurso.
"Idea" significa propuesta nuestra a partir de la referencia, no mejora medida.

| Task | Referencia publica util | Idea y diferencia que hay que respetar | Prioridad |
|---|---|---|---|
| 1 Shifter | [Bit Shifter Pipelined](https://fpgacpu.ca/fpga/Bit_Shifter_Pipelined.html) | Ventana de dos bytes y desplazamiento de 0..7 bits, direccionamiento del paquete aparte. No instanciar un barrel shifter de todo el paquete. Longitud maxima, wrap/zero-fill y valid/last deben conservarse. | Alta para recursos; comparar con version ya puntuada. |
| 2 Hitachi | [NumPy least squares](https://numpy.org/doc/stable/reference/generated/numpy.linalg.lstsq.html) | Referencia de ajuste, NO modelo del sensor del concurso. Investigar distorsion con datos publicos y validacion separada; no ajustar a salidas privadas. Un filtro generico no recupera por si solo la funcion desconocida. | Alta potencial puntuacion, incertidumbre alta. |
| 3 Morse | [fpga-morse-uart](https://github.com/barrettotte/fpga-morse-uart) | Tabla compacta de simbolos y temporizador/FSM; nuestro problema tambien DECODIFICA y usa muestras digitales, no UART/LED humano. BRAM para paquete, no miles de FF. | Alta para recursos si aun hay registros masivos. |
| 4 Synopsys | [CDC Word Synchronizer](https://fpgacpu.ca/fpga/CDC_Word_Synchronizer.html), [CDC MCP](https://www.verilogpro.com/clock-domain-crossing-part-2/) | Doble buffer, toggle de trama completada, sincronizacion de control. No cambiar index0..119, trama128->136 ni relacion de relojes. No se encontro el ejercicio exacto. | Conservar PASS; endurecer verificaciones CDC/reloj. |
| 5 Enigma | [ENIGMA historica](https://github.com/ElectronicsClub-IITK/ENIGMA) como contraste, NO sustituto | Nuestro cifrado usa XOR/+1 modulo128 y avance decimal, no rotores historicos de26letras. Rechazo temprano y busqueda de equivalencias de claves deben respetar todo el prefijo. No descargar una Enigma clasica y asumir equivalencia. | Media: estable ya puntuada; no introducir ambiguedades. |
| 6 Siemens | [ZipCPU dspfilters](https://github.com/ZipCPU/dspfilters), [DSP Guide cap16](https://www.dspguide.com/ch16.htm) | FIR reutilizado/pipeline y acumulador de ancho demostrado. Nuestro trabajo incluye parser/coefs/canales y su flujo Siemens independiente; cambiar un FIR generico no demuestra mejorar ese ejercicio. | Baja mientras siga puntuando. |
| 7 Brazo | [UR analytic IK](https://github.com/Victorlouisdg/ur-analytic-ik), [ROS ur_kinematics](https://github.com/ros-industrial/universal_robot/blob/noetic-devel/ur_kinematics/src/ur_kin.cpp) | IK analitica con geometria UR10e, pero ajustar herramienta, ejes, r33 y rama. CORDIC preciso no sustituye ecuaciones IK completas. | Alta correccion; convenciones aun pendientes. |
| 8 Sorter | [radix-sorting](https://github.com/eloj/radix-sorting), [AXI DMA polling oficial](https://github.com/Xilinx/embeddedsw/blob/master/XilinxProcessorIPLib/drivers/axidma/examples/xaxidma_example_simple_poll.c) | Cuatro histogramas en un recorrido; considerar saltar bytes constantes. Mantener DMA/software y limite LMB. Rendimiento x86 no predice MicroBlaze. | Alta; adaptacion previa ya testeada en C, pendiente placa. |
| 9 Cracovian | [Producto escalar2025](https://github.com/jigglestrudel/nokia-hackathon-2025/blob/2977545cc6e035bae8c1832a7928335972f4b9cc/task_7/task_7.sv) | MAC y empaquetado aritmetico como idea, no copiar: nuestros exponentes, signos y acumuladores son distintos. La revision local pipelined es mas cercana al problema que una matriz generica web. | Alta; candidato separado ya existe. |
| 10 MMIO | [verilog-axi](https://github.com/alexforencich/verilog-axi) | Decode explicito, escrituras habilitadas y mux de lecturas. El protocolo de16comandos y direccion oculta NO es AXI-Lite; no meter un interconnect completo. | Baja/Media, comprobar area real primero. |
| 11 Artifacts | [magic-square](https://github.com/jasampler/magic-square), [SymPy linsolve](https://docs.sympy.org/latest/modules/solvers/solveset.html#sympy.solvers.solveset.linsolve) | Reutilizar IDEA de sumas/huecos y completar filas con una incognita. No exigir diagonales ni numeros distintos: aqui se repiten. Oracle de ecuaciones para distinguir solucion unica/ambigua. | Media/Alta, despues de memorias grandes. |
| 12 Abacus | [Stack calculator](https://github.com/davidsiaw/tt02-davidsiaw-stackcalc), [Simple dual port RAM](https://fpgacpu.ca/fpga/RAM_Simple_Dual_Port.html) | Elementos superiores en registros, resto en BRAM con accesos compatibles. La referencia calculadora4bit NO interpreta Romanos/PN del concurso. Mantener overflow intermedio y orden de resta. | Muy alta: problema de inferencia de pila demostrado en run17. |
| 13 NCO | [ZipCPU cordic/sine generators](https://github.com/ZipCPU/cordic) | ROM sincrona y valid/last retardados; nuestra base YA usa cuarto de seno. No vender de nuevo esa optimizacion. No copiar muestras centradas medio paso: cambia valores de referencia. | Media, medir LUT de la tabla combinacional. |
| 14 MCU | [PicoRV32](https://github.com/YosysHQ/picorv32), [RAM SDP](https://fpgacpu.ca/fpga/RAM_Simple_Dual_Port.html) | Solo arquitectura: memoria sincrona, fetch/decode/execute y un escritor por registro. ISA propia2registros y carry, NO RISC-V; cambiar latencia puede afectar bonus. | Alta para BRAM si mapas actuales son grandes. |
| 15 LDPC | [pyldpc/code.py](https://github.com/hichamjanati/pyldpc/blob/master/pyldpc/code.py), [Neal encoding](https://radfordneal.github.io/LDPC-codes/encoding.html) | Eliminacion GF(2), sistematizacion, orden de columnas. La salida debe coincidir byte a byte, no solo cumplir H*c^T=0. No usar codec5G de matriz fija. | Alta correccion, no optimizar un resultado aun incorrecto. |
| 16 Packer | [ZipCPU axispacker](https://github.com/ZipCPU/wb2axip/blob/master/rtl/axispacker.v) | Misma clase de funcion: eliminar null bytes TKEEP y conservar TLAST/backpressure. Nuestros KEEP permitidos son1/3/7/F; se puede especializar. Ensayo propio completado, ver abajo. | Cambio pequeno, medible y aislable. |

## Task4: estudio especifico

La revision visual de las primeras paginas de
`../01_Normas/04_Frame_Extender_Synopsys.pdf` confirma:

- Entrada: cabecera8bits `0x4e`, payload120bits con exactamente un1.
- Indice del primer bit del payload=0; ultimo=119.
- Salida: conservar trama128bits, anadir indice8bits MSB-first.
- Entrada continua8Mbit/s; salida continua136bits por cada128entrantes.
- La relacion nominal correspondiente es8.5MHz de salida para8MHz entrada.
- Limite de latencia indicado:256ciclos de entrada.

Hallazgos web aplicables: cruzar un evento estable y seleccionar el banco
completado, no sincronizar cada bit del bus por separado. El estado actual
ya usa esa arquitectura; el error de banco se habia corregido antes de esta
busqueda. No es una mejora nueva ni hay razon para reintroducir el viejo banco.

No se ha encontrado en libros/repos el mismo header/payload/index/protocolo.
Un serializador o UART puede orientar la FSM, pero no es una entrega equivalente.
Los libros/papers de CDC explican las piezas, no la solucion del juez.

Version a conservar: task4 de `2f37952`, SHA256 del fichero
`90D8AAEE06568C3A89BDCDA7C31A333B81139A5595F2B971DA699F2A48A495B0`.
Evidencia anterior: VCS oficial2123framesPASS y test local2000framesPASS.
Pendiente para cualquier variante: repetir VCS, barrer desfases de relojes,
reset y continuidad de salida. Simulacion logica no demuestra inmunidad
a metastabilidad. No se cambiaron reglas, comparadores ni scripts oficiales.

## Mejora nueva ejecutada e integrable en paquete experimental

Task16: permitir aceptar entrada cuando se libera espacio en el mismo ciclo.
No se importo el core de ZipCPU: se aplico un cambio pequeno a nuestro control
y se creo un banco independiente de verificacion completa de los bytes.

Resultados:256paquetes/192105bytes, cero errores en base y candidata;
104763->86340ciclos acumulados en ese banco (17.59% menos).
Recursos OOC:104->103LUT,69FF en ambos,0BRAM/0DSP.
Timing OOC a10ns positivo en ambos. Ver
[RESULTADOS.md](experiments/task16/RESULTADOS.md) para escenarios,
tradeoff READY, advertencias OOC y comandos reproducibles.

No se acredita reduccion del tiempo de construccion de Jenkins: synth23s
en ambos, placement72/74s en esta medicion paralela. No mezclar ciclos del
hardware con segundos del implementador. No hay bonus oficial nuevo medido.

## Integracion y prioridades

1. Conservar main estable mientras se evalua. No juntar codigo bajado sin tests.
2. Integrar este informe/tests y candidato16 en una rama EXPERIMENTAL.
3. Priorizar12 BRAM,3 buffer,14 memorias y13 ROM para area/congestion,
   pero comparar primero con el RTL actual para no duplicar mejoras previas.
4. 7/8/9/15 siguen en candidatos propios; tener repos de referencia no los
   convierte en aprobados. Referencias anteriores y sus resultados estan
   en `package/new-task-candidates`.
5. Cada cambio: oracle + tests legales/limites + sintesis aislada + A/B
   integrado con mismos enablers/restricciones + juez oficial.

La presente rama no modifica task4, Tcl oficial, wrappers, XDC, MicroBlaze,
enablers, comparadores ni puntuaciones. No lanza una segunda ejecucion Jenkins.

## Licencias y atribucion

- `axispacker.v`: Apache-2.0 declarado en la cabecera consultada. Referencia
  solamente, ningun fragmento del core se copio a nuestro RTL.
- MUDAL: MIT comprobado en LICENSE y memory_controller.sv. No importado.
- ZipCPU cordic: software GPLv3, RTL generado LGPLv3 segun README.
- ZipCPU dspfilters: LGPLv3 segun README. No importado.
- jasampler/magic-square: GPL-3.0 segun pagina del proyecto. Solo idea de
  bookkeeping de sumas; no se traslado codigo.
- Resto: revisar licencia por fichero y las reglas vigentes antes de copiar;
  no asumir permiso por ser publicos ni por decir "educational".

La busqueda y estas propuestas no acreditan autorizacion del organizador
para importar IP o modificar infraestructura. Se mantienen las restricciones
del proyecto y no se usa conocimiento de vectores privados.
