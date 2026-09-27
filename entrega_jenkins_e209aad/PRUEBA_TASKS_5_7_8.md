# Prueba conjunta 5, 7 y 8

Base: a1b610c. FPGA habilitadas exclusivamente 5, 7 y 8.
Task 5: RTL de ea446c5, con 5 puntos publicos y 15 gold en Jenkins 17.
Task 7: RTL real del worktree work/task7-analysis, con control CORDIC corregido.
NO validada: ultima simulacion 12 angulos discrepantes; phi2/3/4 provisionales y phi1 requiere geometria y conversion de unidades.
Task 8: sin cambios respecto a main; Jenkins 21 dio cero por latencia (~342000 ciclos).
Task 2 conserva su codigo pero queda deshabilitada. Resto conserva la base, incluidos dummies registrados, MicroBlaze, wrappers y Synopsys/Siemens.

No se cambian XDC, restricciones, scripts oficiales ni incremental.
Jenkins fuerza Flow_RuntimeOptimized: este commit NO es una prueba SpreadLogic_medium.
El ensayo medium requiere un flujo local/VM separado o autorizacion y cambio efectivo del CI.
Objetivo: diagnostico conjunto, no declarar aprobadas 7/8 ni confundir SUCCESS con puntuacion.
