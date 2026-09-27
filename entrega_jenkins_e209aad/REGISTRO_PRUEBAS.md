# Registro de pruebas

Actualizado: 27/09/2026, hora local Europe/Warsaw.
Un SUCCESS de Jenkins no implica que todas las tasks hayan pasado.
Conservar resultados por commit: no extrapolarlos a otras versiones.

## Jenkins 14: grupo A

- Commit: `5c44f7e9e747b9805e2731879134d02686aa49be`.
- Run: `run-14-5c44f7e`. Estado del pipeline: SUCCESS.
- [Consola original](https://jenkins.dev.fpgahackathon.com/job/team018_check_code/14/console).
- Sintesis, implementacion, bitstream y evaluacion en placa completados.

| Task | tb_lite local, mismo commit | Evaluacion publica en placa | Reporte posterior tv gold | Conclusion |
|---|---|---|---|---|
| 1 | PASS | Tres intentos sin respuesta; VERIFIED 0, score 0 | VERIFIED 0, score 0 | No validada en placa; investigar protocolo/handshake |
| 10 | PASS | VERIFIED 1, score 5 | VERIFIED 1, score 15 | Puntua en ambas evaluaciones |
| 13 | PASS | VERIFIED 1, score 0; muestra 0 esperada 0, recibida 32767 | VERIFIED 1, score 8 | Resultado mixto; NO marcar totalmente aprobada |
| 16 | PASS | PASS, 1904 bytes verificados; score 4 | VERIFIED 1, score 12 | Puntua en ambas evaluaciones |
| 4 | No evaluada en esta tanda local | Synopsys sin veredicto PASS; insercion de 0 puntos | Insercion de 0 puntos | No aprobada en esta version base |
| 6 | No evaluada en esta tanda local | Siemens status FAIL, 0.5/10; convertido a 0 puntos | Insercion de 0 puntos | No aprobada en esta version base |

Los scores publicos y tv gold son salidas distintas del pipeline: no sumarlos
entre si ni presentarlos como clasificacion oficial acumulada. VERIFIED 1
indica evaluacion realizada, no necesariamente correccion (ver task 13).
El timeout de task 1 y la discrepancia de task 13 son observaciones; su causa
raiz todavia no esta demostrada.

## Grupo B: tasks 3, 12 y 14

Configuracion original de referencia: `deaf8d8d2d4df24af1cd3a814115c8807e7a820c`.
El nuevo commit de main recupera exactamente su codigo e infraestructura,
conservando esta documentacion y el ejecutor local. No acumula grupos A/C.

| Task | Simulacion local del grupo B | Jenkins siguiente |
|---|---|---|
| 3 | PASS observado en official.log | Pendiente de resultado |
| 12 | En curso al registrar | Pendiente de resultado |
| 14 | Sin resultado aun al registrar | Pendiente de resultado |

Evidencias locales: `tmp/clean_verify_5c44f7e/official.log` (A) y
`tmp/sep25_tasks_3_12_14/official.log` (B), en el PC que ejecuta las pruebas.
Los logs locales no se incluyen en Git. No hay nueva aprobacion funcional
por el mero hecho de volver a publicar el grupo B.

## Como actualizar el registro

### Recuperacion de task 6 (Siemens)

Jenkins #12, commit `30fb769b158f0ff06ee613fd106dba0b617e0ec9`, registro:
`Read total=6.0 / total_max=10.0 (status=PASS) -> points=6 (of 10)`.
La insercion de resultados confirma task_id=6, points=6 en ambas bases.
Fuente: https://jenkins.dev.fpgahackathon.com/job/team018_check_code/12/console

Los resultados FAIL/0 de #14 y #15 corresponden a la plantilla recuperada
del 25 de septiembre, NO al parser de #12. Por ello no se debe clasificar
la implementacion de #12 como fallida ni confundir PASS con 10/10 puntos.

Se restaura exactamente `siemens/rtl/packet_parser.sv` de #12; el resto de
Siemens ya coincide con ese commit. Se mantienen sin cambios las tasks FPGA
1/5/9/11/13 y su configuracion. task6 permanece a 0 en task_enabler_pkg porque
la evaluacion Siemens es independiente, no es una task FPGA de ese wrapper.
La restauracion no modifica el checkout ya usado por Jenkins #16.
Verificacion local adicional del parser restaurado: banco `tb_packet_parser`
sin cambios, 105 PASSED / 0 FAILED en XSim 2025.2. Se indico timescale 1ns/1ps
al elaborador, sin editar fuentes. Esto no sustituye al flujo completo Siemens.

Nueva tanda preparada: **1, 5, 9, 11 y 13**, rama `test/tasks-1-5-9-11-13`.
Tasks 5/9/11 proceden de `1a9e2b4`; task 1 y auxiliares de task 13, de
`b298a96`. El Tcl anade los tres auxiliares de task 13. Las demas tasks
conservan la plantilla inicial (incluido el MicroBlaze original).
Las correcciones tienen regresiones independientes: task 1, 1253/1253;
task 13, 30/30. Eso no certifica todavia la nueva combinacion en placa.
No se ha lanzado Jenkins para esta tanda como parte de su publicacion.

Anotar numero de Jenkins, hash realmente descargado, tasks activadas,
resultado funcional por task, scores publicos y tv gold por separado,
errores exactos y enlace a consola. Una ejecucion en curso queda pendiente.
Para repetir en otro PC, seguir PRUEBAS_POR_PC.md con un commit fijo.
