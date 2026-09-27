# Task 15: diagnostico tras Jenkins #25

Rama experiment/ref-task15. El RTL coincide con a12ead7; no se ha integrado
ninguna optimizacion nueva ni se considera solucionada.

El test local por etapas comprueba el vector incluido en tb/: 117 bits de H,
52 bits de G, 16 palabras, 144 sindromes, 208 bytes de memoria y salida.
Este vector local PASA. No es suficiente: Jenkins #25 evalua datos distintos
y da 0 puntos publicos (latencia 466) y 0 privados (3970), aunque el build sea SUCCESS.
El log publico lista diferencias hasta posicion 223: no asumir que el vector
de 208 bytes local sea la totalidad de pruebas oficiales actuales.

Riesgos concretos:

1. RTL asume H=[P^T|I]. No calcula el nucleo general de H. Validar si la matriz
   recibida en el juez tiene el bloque identidad antes de atribuirlo al empaquetado.
2. pyldpc calcula bases mediante eliminacion GF(2); su variante sistematica puede
   permutar columnas. Copiarla directamente puede romper el orden byte a byte.
3. Emitir cada codeword directamente ahorraria memoria de salida y espera,
   pero NO arregla una G incorrecta. Optimizar despues de reproducir #25.

Referencia: https://github.com/hichamjanati/pyldpc/blob/master/pyldpc/code.py .
No se incorpora codigo de terceros en el RTL.

Reproducir test local desde raiz del worktree:
`xvlog -sv src/tasks/task_15/task_15.sv experiments/tb_stages.sv`
`xelab tb_stages -s task15_stages`
`xsim task15_stages -runall`

Exigir STAGE_CHECK_PASS en log; exit code de XSim no demuestra PASS.
