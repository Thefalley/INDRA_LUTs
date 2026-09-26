# Task 9 - Cracovian

## Protocolo

La primera palabra del paquete de entrada, marcada con `i_first`, es
`{num_pair, num_rows, num_col_a, num_col_b}`. Las muestras siguientes son
sub-Cracovianos 2x2 en orden de bloque de columnas y, dentro de este, orden de
bloque de filas. Cada muestra es
`{mantissa[1][1], mantissa[1][0], mantissa[0][1], mantissa[0][0], exponent}`;
las mantisas son valores con signo de 7 bits y el exponente es de 4 bits.

La salida comienza con `o_first` y la configuración
`{num_pair, num_col_b, 8'd0, num_col_a}`. Después se emite un sub-Cracoviano
por palabra válida; `o_last` coincide exclusivamente con el último resultado.

## Arquitectura

La FSM usa los estados `ST_WAIT_CONFIG`, `ST_RECEIVE`, `ST_CALC_INIT`,
`ST_CALCULATE`, `ST_NORMALIZE`, `ST_OUTPUT_CONFIG` y `ST_OUTPUT_DATA`.

La entrada completa se guarda porque la interfaz no ofrece `ready` para parar
un paquete mientras se calcula. Para cada bloque de salida, la etapa de cálculo
consume un bloque de filas por ciclo y acumula los cuatro resultados a la vez.
Cada ciclo contiene los ocho productos requeridos por las dos filas del par de
sub-Cracovianos. Los acumuladores son de 56 bits, por lo que preservan los
productos de mantisa y la suma de exponentes antes de normalizar.

La normalización busca el desplazamiento mínimo que deja las cuatro mantisas
en el intervalo firmado de 7 bits y emite un exponente común. La búsqueda está
acotada a 56 bits y es sintetizable.

## Verificación

XSim 2025.2 compiló, elaboró y ejecutó el vector incluido en `tb/task09.mem`:

- Entrada: `01020202`, `00C80010`, `02019000`.
- Salida esperada y observada: `01020002`, `00C80001`.
- Resultado: `TASK_9_SMOKE_PASS`.

La latencia desde el último dato de entrada hasta el primer resultado es
`row_blocks + 2` ciclos, más un ciclo de configuración de salida. Cada bloque
de salida posterior requiere `row_blocks + 2` ciclos.

## Síntesis aislada

Objetivo: `xck26-sfvc784-2LV-c`, Vivado 2025.2.

- CLB LUTs: 5786
- CLB registers: 340
- DSPs: 1
- Puntuación: `5786 + 340 + 10 * 1 = 6136`

La memoria de entrada de 2048x32 se infirió como RAM distribuida debido a las
dos lecturas asíncronas que sostienen un bloque de cálculo por ciclo. Es la
principal oportunidad para reducir recursos con una RAM síncrona canalizada.

## Resumen de implementación y decisiones

1. Se preservó exactamente la interfaz entregada de `task_9`.
2. Se implementó el formato de configuración de entrada/salida y el orden
   columnar de los bloques 2x2 indicado por el enunciado.
3. Se implementó la multiplicación Cracoviana como cuatro acumulaciones en
   paralelo por bloque de salida y normalización de exponente común.
4. Se corrigió el cálculo del número de muestras para que no trunque las
   configuraciones grandes.
5. Se verificó el vector oficial mínimo con XSim y se sintetizó para KV260.

### Revisión de recursos

Se evaluó una alternativa con lectura síncrona y atributo de BRAM. En esta
topología, Vivado no infirió BRAM y el resultado empeoró a 9088 LUT y 426
registros. Se descartó, se restauró la versión asíncrona y se mantiene la
medición de 5786 LUT, 340 registros y 1 DSP.

Para reducir el coste de memoria de verdad sería necesario rediseñar el
calendario de acceso con una RAM de doble puerto y una tubería explícita de
lectura, manteniendo una muestra calculada por ciclo. Es una optimización
posterior de riesgo moderado; no se ha aplicado para no alterar el resultado
funcional ya verificado.

## Límites conocidos

La codificación de salida reserva cuatro bits para el exponente, como especifica
el formato. Los vectores deben mantenerse dentro de ese rango tras la
normalización; el enunciado no define una política de saturación para un
exponente de resultado superior a 15.
