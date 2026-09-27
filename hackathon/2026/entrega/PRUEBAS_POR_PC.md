# Un grupo por PC, usando commits distintos de main

Las configuraciones NO se acumulan: cada commit tiene la base `fa7ec0f`
(segundo commit del 25/09/2026) y solo las implementaciones de su grupo.
El resto conserva las plantillas originales, incluida la task 8 con MicroBlaze.
No son bypass nuevos y no se han eliminado componentes oficiales.

| PC / grupo | Commit exacto del historial de main | Tasks reales activadas |
|---|---|---|
| A | `5c44f7e9e747b9805e2731879134d02686aa49be` | 1, 10, 13, 16 |
| B | `deaf8d8d2d4df24af1cd3a814115c8807e7a820c` | 3, 12, 14 |
| C | `825d0304a6423d316e1ae2ce0e1723a47054a675` | 5, 9, 11 |

`main` contiene ahora una nueva tanda: **1, 5, 9, 11 y 13**.
Combina el grupo C con task 1 y task 13 corregidas en `b298a96`.
La rama `test/tasks-1-5-9-11-13` conserva esta configuracion.
Los tres grupos siguen accesibles por los commits fijos de la tabla;
la punta de main puede cambiar entre pruebas. Las ramas siguen publicadas.
No hacer `git pull` sobre
un checkout de prueba: cambiaria la version que se pretende comparar.

## 1. Descargar una copia limpia

En cada PC, usar una carpeta nueva. Ejemplo PowerShell para el grupo A:

```powershell
git clone https://gitlab.dev.fpgahackathon.com/hackathonfpga_2026_team_repos/team018.git team018_pcA
cd team018_pcA
# Guardar el ejecutor FUERA del repo antes de cambiar a un commit antiguo.
Copy-Item tools/verify_snapshot.tcl ../verify_snapshot.tcl
Copy-Item PRUEBAS_POR_PC.md ../PRUEBAS_POR_PC.md
git switch --detach 5c44f7e9e747b9805e2731879134d02686aa49be
git rev-parse HEAD
git status --porcelain
```

Para B/C, cambiar el nombre de carpeta y el hash por el de la tabla.
El estado inicial debe estar vacio. `detached HEAD` es intencional: fija el
commit sin modificar ramas ni subir cambios. Los otros ordenadores no cambian.

Requisitos: Git, Vivado 2025.2 con soporte del dispositivo
`xck26-sfvc784-2LV-c` y licencia disponible. La ruta de Vivado depende del PC.
La task 8 se conserva aunque no se evalua; sus IP pueden tardar en generarse.

## 2. Ejecutar simulacion funcional oficial

Desde la carpeta clonada:

```powershell
$vivado = 'C:/AMDDesignTools/2025.2/Vivado/bin/vivado.bat'
$repo = (Get-Location).Path
& $vivado -mode batch -source ../verify_snapshot.tcl -log ../sim_pcA.log -journal ../sim_pcA.jou -tclargs $repo
$LASTEXITCODE
```

Cambiar `pcA` en los logs por `pcB`/`pcC` si se comparte el directorio padre.
En Linux, desde el clone:

```sh
/opt/tools/Xilinx/2025.2/Vivado/bin/vivado -mode batch -source ../verify_snapshot.tcl -log ../sim_pcA.log -journal ../sim_pcA.jou -tclargs "$PWD"
```

El ejecutor lee las tasks activadas en `src/task_enabler_pkg.svh`, crea un
proyecto nuevo fuera del clone y corre `tb_lite` por cada task. Solo cambia
el selector `TASK_N` en copias del banco; no cambia RTL, vectores `.mem`,
comparadores ni tolerancias. No es un smoke test.

Resultados en `../local_results/<carpeta>_<fecha>_<pid>/`:

- `manifest.txt`: commit y estado inicial.
- `task_N/status.txt`: PASS, FAIL, ERROR o INCOMPLETE.
- `task_N/simulate.log`: salida del banco cuando la simulacion pudo ejecutarse.
- Consola general: `sim_pcA.log`, incluido cualquier error de preparacion.

**PASS** requiere `TEST PASSED!` y `Testbench finished`. Un exit code 0 del
ejecutor indica que pasaron todas las tasks seleccionadas. INCOMPLETE significa
que no termino en 5 ms de tiempo simulado; no es PASS ni demuestra por si solo
un fallo funcional. Esos 5 ms no son cinco milisegundos de espera real.

Vivado puede regenerar metadatos de los BD en la copia local. No subirlos sin
revisar el diff. No modificar el RTL durante una medicion.

## 3. Sintesis e implementacion del grupo completo (opcional)

Esta prueba es distinta de la simulacion. En una sesion de Vivado Tcl iniciada
desde `vivado/` dentro del clone limpio, ejecutar:

```tcl
source hackathon.tcl
set_param general.maxThreads 2
launch_runs synth_1 -jobs 2
wait_on_run synth_1
puts "SYNTH_STATUS=[get_property STATUS [get_runs synth_1]]"
launch_runs impl_1 -to_step route_design -jobs 2
wait_on_run impl_1
puts "IMPL_STATUS=[get_property STATUS [get_runs impl_1]]"
open_run impl_1
report_utilization -hierarchical -file utilization_hierarchical.rpt
report_timing_summary -report_unconstrained -file timing_summary.rpt
report_drc -file drc.rpt
```

No seguir si una orden falla. Usar una carpeta de proyecto nueva: si ya existe
`vivado/hackathon`, reutilizar conscientemente ese proyecto o crear otro clone;
no borrar trabajo ajeno ni forzar sobrescrituras. Esta secuencia no programa
la placa, no genera puntuacion y no sustituye el pipeline oficial de Jenkins.

## 4. Comparar resultados

Enviar por cada PC: hash completo, version de Vivado, task/grupo, PASS/FAIL,
duracion de `synth_design`, `opt_design`, `place_design` y `route_design`,
LUT/FF/BRAM/DSP y timing. Las duraciones se encuentran en los `runme.log` de
`vivado/hackathon/hackathon.runs/synth_1` e `impl_1` para la prueba del apartado 3.

No atribuir el tiempo de todo el grupo a una task concreta. Para un ranking por
task se necesita sintesis/implementacion aislada, con misma FPGA, reloj e hilos.
Los tiempos de PCs distintos, con otras cargas en marcha, no son comparaciones
estrictas. Sintesis correcta no implica test funcional aprobado ni timing final.

## Recuperar otra version

Guardar primero cualquier trabajo propio y hacer otro clone si se necesita
conservar el proyecto generado. Nunca usar `reset --hard` para cambiar de grupo.
Cada commit de la tabla y cada rama conserva su configuracion independiente.
