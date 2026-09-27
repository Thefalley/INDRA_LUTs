# Paquete de candidatos, separado de Jenkins #26

Base: 2f379527b8c3c25260ed7d3e07e50ec21976aecf. Rama package/new-task-candidates.
Jenkins #26 esta construyendo esa base de main; este paquete NO la sustituye.

| Task | Procedencia | Estado |
|---|---|---|
| 4 | 8da2c39, archivo serial_frame_extender (1).sv | Oficial Synopsys: PASS 2123 tramas; local: PASS 2000 |
| 7 | 876d549 | RTL real preservado y referencia matematica; sigue fallando, no correccion nueva |
| 8 | 8a79458 | Multihistograma, PASS 10008 vectores CPU, ELF enlazado; falta medir placa |
| 9 | c3832b2 | Pipeline continuo, PASS 46 casos, OOC WNS +2.687 ns; falta juez privado |
| 15 | 08d7107 | RTL y test de diagnostico; #25 dio 0 puntos, no resuelta |

Las otras tasks conservan el paquete estable. No se cambian scripts oficiales,
Tcl, XDC, wrappers ni enablers. 7, 8, 9 y 15 siguen deshabilitadas en el selector;
esto NO garantiza que Vivado elimine su hardware real. No lanzar este paquete
entero como si fuese una version certificada ni prometer que cabe/tiene timing.
Para evaluar candidatos, preparar una configuracion explicita separada.

Los informes de cada rama estan en reports/. Sus rutas de tests se refieren
al worktree individual; aqui los tests estan agrupados en experiments/taskN/.
Ejecutar referencia 7 con `python experiments/task7/reference.py --tb tb`.

## Referencias revisadas en Internet (27-09-2026)

### Task 7: prioridad correccion geometrica

[ur-analytic-ik](https://github.com/Victorlouisdg/ur-analytic-ik) aporta FK/IK
analitica, todas las ramas y una transformacion TCP explicita. Usarla como
oraculo independiente, fijando el marco de base, herramienta y convenciones.
No identifica automaticamente el significado de r33 del concurso ni la rama
que compara su juez. No atribuir el fallo actual solo a iteraciones CORDIC.

[ROS-Industrial UR](https://github.com/ros-industrial/universal_robot/blob/noetic-devel/ur_kinematics/src/ur_kin.cpp)
permite contrastar parametros UR10e y cambios de marco de su entrada/salida.
Comparar FK de cada solucion contra la pose solicitada antes de convertir a RTL.

### Task 8: prioridad latencia medida

[radix-sorting](https://github.com/eloj/radix-sorting) explica histograma multiple,
omision de pasadas de bytes constantes y reduccion del tamano de contadores.
La primera idea esta adaptada y probada. Las dos siguientes son propuestas:
si se omite un numero impar de pasadas, el resultado queda en el otro buffer;
debe devolverse ese puntero o copiarlo correctamente antes del DMA.
Contadores de 16 bits admiten 256 elementos y ahorrarian 2048 bytes respecto
al histograma 32-bit actual; el efecto en ciclos MicroBlaze hay que medirlo.
No extrapolar cifras de x86, SIMD, GPU ni cambiar los datos para aparentar mejora.

### Task 15: prioridad reproducir el fallo de #25

[pyldpc/code.py](https://github.com/hichamjanati/pyldpc/blob/master/pyldpc/code.py)
usa eliminacion GF(2) para generar una base del nucleo. Su forma sistematica
puede permutar columnas de H: no copiar sin restaurar orden de bits y mensajes.
El RTL actual asume H=[P^T|I], condicion que hay que verificar contra datos del
juez. Una base matematica valida no garantiza el orden byte a byte requerido.

### Task 9: mejora propia, no solucion externa encontrada

Las busquedas Cracovian/Verilog/FPGA no dieron una implementacion compatible
verificada del ejercicio. Se conserva nuestra multiplicacion de columnas con
signo/exponentes. Proxima prioridad: normalizacion y overflow contra referencia
oficial, despues de reducir las burbujas del pipeline.

No se han incorporado repositorios completos ni codigo externo de licencia
desconocida. No se anuncian como verificadas mejoras que solo son propuestas.

## Ampliacion de busqueda: referencias adicionales

- [IK-Geo](https://github.com/rpiRobotics/ik-geo): descompone la cinematica en
  subproblemas geometricos y contempla ramas multiples/singularidades.
  Aporta MATLAB/C++/Rust/Python; usarlo para contrastar soluciones de la 7,
  no importar codigo de CPU directamente en RTL. Licencia declarada BSD-3-Clause.
- [Robotics Toolbox de RPI](https://github.com/rpiRobotics/rpi_general_robotics_toolbox_py):
  incluye ur_invkin, fwdkin y transformaciones. Segunda referencia independiente
  para comprobar ida/vuelta pose-angulos-pose y convenciones.
- [LDPC-codes](https://github.com/radfordneal/LDPC-codes/blob/master/make-gen.c)
  y su [explicacion del codificador](https://radfordneal.github.io/LDPC-codes/encoding.html):
  separan paridad y mensaje y resuelven el sistema GF(2), guardando el orden de
  columnas. Para NUESTRA notacion H=[A|B], c=[u|p], si B es invertible se obtiene
  p=B^-1*A*u. La simplificacion actual solo vale cuando B=I. Esto explica un
  riesgo concreto, no demuestra todavia la causa de #25. Si B es singular,
  escoger otras columnas tambien cambia la convencion de enumeracion.
- [EASTL sort.h](https://github.com/electronicarts/EASTL/blob/master/include/EASTL/sort.h):
  otra implementacion para estudiar omision de pasadas radix; sigue pendiente
  medir su adaptacion en MicroBlaze y conservar el buffer de resultado correcto.

Busquedas adicionales de Cracovian + Verilog/FPGA no localizaron una solucion
exacta comprobada. Los multiplicadores de matrices genericos no implementan
automaticamente nuestro empaquetado de cuatro mantisas de 7 bits/exponente.
No se sustituyo el candidato propio por una arquitectura ajena sin validacion.

### Orden de trabajo recomendado

1. Task 9: ya mejoro latencia; comprobar normalizacion y vectores oficiales en placa.
2. Task 8: medir multihistograma en placa; despues A/B de contadores y pasadas triviales.
3. Task 15: reproducir datos de #25 y verificar H/G/orden, antes de optimizar latencia.
4. Task 7: resolver marcos y ramas antes de otro cambio de precision CORDIC.

Confirmacion Jenkins #26 durante el estudio: Synopsys mostro
`[PASS] Checked 2123 frames successfully.`; Code Synthesis seguia IN_PROGRESS.
Esto no es aun una puntuacion final del paquete completo.
