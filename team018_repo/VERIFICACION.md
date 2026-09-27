# Guía de verificación

Esta guía explica cómo comprobar las tareas HDL antes de compartirlas. Hay dos
flujos distintos en este repositorio:

1. **Diseño principal (`src/`, `tb/`, `vivado/`)**: simulación con Questa/qrun
   y los testbenches `tb_lite` o `tb_top`.
2. **Ejercicio Siemens (`siemens/`)**: lint y testbenches propios, con
   puntuación generada por sus scripts.

> Los ficheros de simulación (`qrun.out/`, `xsim.dir/`, `*.wdb`, `*.log`,
> `vivado.jou`) son resultados locales. No deben formar parte del cambio de
> RTL que se va a revisar o subir.

## 1. Preparar el entorno

Sitúate en la copia de trabajo:

```powershell
cd C:\project\hackthon\INDRA_LUTs\INDRA_LUTs\team018_repo
git status --short
```

Antes de verificar, anota qué archivos de diseño has cambiado y deja fuera
los artefactos generados. Para ejecutar el flujo completo hacen falta:

- QuestaSim/qrun, compatible con los ficheros SystemVerilog y VHDL;
- Vivado 2025.2 y los IP generados para las pruebas de integración;
- GNU Make y una shell compatible con los scripts del repositorio (Git Bash,
  WSL o la VM del hackathon).

El `Makefile` de `tb/` contiene una ruta Linux por defecto para qrun. En otro
entorno se puede sobrescribir sin editarlo:

```bash
make batch TB=tb_lite QRUN=/ruta/a/qrun
```

En Windows, usa la ruta que corresponda a la instalación de Questa, o ejecuta
el comando desde la VM del hackathon, donde Vivado y Questa ya estén
configurados.

## 2. Verificación rápida de una tarea

La forma más rápida de comprobar una implementación es compilar y simular la
tarea con un testbench pequeño y aislado. Por ejemplo, para `task_1` ya existe
`tb/task_1_smoke_tb.sv`:

```powershell
cd C:\project\hackthon\INDRA_LUTs\INDRA_LUTs\team018_repo
qrun -batch -sv -top task_1_smoke_tb `
  .\src\tasks\task_1\task_1.sv `
  .\tb\task_1_smoke_tb.sv
```

Un resultado correcto debe terminar sin `Errors` y el testbench debe imprimir
su condición de `PASS`. Si falla, conserva el log y revisa primero el mensaje
inicial de compilación: normalmente señala el fichero y la línea exacta.

Para otras tareas, el patrón es el mismo:

1. identificar o crear un testbench mínimo en `tb/`;
2. compilar solo la tarea y sus dependencias directas;
3. comprobar casos normales, bordes y reset;
4. guardar el comando usado junto al testbench para que otra persona pueda
   repetirlo.

## 3. Prueba de integración del diseño principal

El archivo `tb/Makefile` ofrece dos niveles de prueba:

```bash
cd team018_repo/tb

# Diseño de control con modelo de memoria AXI: el punto de partida recomendado
make batch TB=tb_lite

# Diseño completo design_1 con Zynq PS VIP: más lento y con más dependencias
make batch TB=tb_top
```

También se puede separar el flujo para aislar el problema:

```bash
make compile TB=tb_lite
make optimize TB=tb_lite
make simulate TB=tb_lite
```

`tb_lite` es la primera prueba que se debe ejecutar tras cambiar una tarea.
Cuando pase, ejecuta `tb_top` para validar la integración completa. Si aparece
un error de un IP, de un fichero `.mem` o de una biblioteca Xilinx, primero
abre/regenera el proyecto Vivado correspondiente; no modifiques el RTL para
ocultar ese tipo de error de entorno.

Para abrir una simulación de forma interactiva:

```bash
make gui TB=tb_lite
```

Usa la GUI para mirar señales y ondas; la verificación repetible debe seguir
haciéndose con `make batch`.

## 4. Flujo Siemens: lint, simulación y puntuación

El material de `siemens/` es un ejercicio independiente. Sus scripts están en
un submódulo; inicialízalo una vez después de clonar:

```bash
cd team018_repo
git submodule update --init --recursive
cd siemens
```

Después, ejecuta todas las comprobaciones:

```bash
bash scripts/run_all.sh
```

O por fases mientras se desarrolla:

```bash
bash scripts/run_lint.sh
bash scripts/run_parser_tb.sh
bash scripts/run_fir_tb.sh
python3 scripts/score.py
```

Los resultados quedan en `siemens/results/`:

| Archivo | Contenido |
| --- | --- |
| `lint.rpt` | errores y avisos de lint |
| `parser_sim.log` | resultados de los 14 casos del parser |
| `fir_sim.log` | resultados de los vectores del FIR |
| `score.txt` / `score.json` | puntuación y estado final |

La línea que resume el resultado es `SCORE_STATUS: PASS` o `SCORE_STATUS:
FAIL`; `FINAL_SCORE` muestra la puntuación alcanzada.

## 5. GitLab, Jenkins y GitHub

El GitLab del equipo es:

```text
git@gitlab.dev.fpgahackathon.com:hackathonfpga_2026_team_repos/team018.git
```

Actualmente no existe un `.gitlab-ci.yml`, por lo que la página **Build →
Pipelines** de GitLab no mostrará verificaciones. El fichero
`siemens/Jenkinsfile` describe un Jenkins externo: cuando la organización lo
tenga conectado, un *push* al repositorio de GitLab ejecutará `scripts/run_all.sh`
y archivará `results/**`.

El repositorio de GitHub es una copia de trabajo/entrega distinta. Subir cambios
a GitHub no lanza la verificación del GitLab. Antes de hacer *push* al GitLab,
verifica localmente y confirma que se está en el repositorio y rama correctos:

```bash
git remote -v
git branch --show-current
git status --short
```

## 6. Checklist antes de compartir una tarea

- [ ] El RTL compila sin errores.
- [ ] El testbench mínimo de la tarea pasa.
- [ ] `make batch TB=tb_lite` pasa, si la tarea afecta al diseño principal.
- [ ] `make batch TB=tb_top` pasa antes de una integración importante.
- [ ] Se han revisado reset, límites, datos inválidos y `valid/ready`.
- [ ] No se añaden logs, ondas, directorios de simulación ni ficheros Vivado
  generados al commit.
- [ ] Se guarda en el mensaje de commit qué prueba se ejecutó y su resultado.

Plantilla breve para una revisión:

```text
Tarea: task_N
Cambio: <qué se ha implementado>
Prueba rápida: PASS/FAIL — <comando>
tb_lite: PASS/FAIL/no ejecutada — <motivo>
tb_top: PASS/FAIL/no ejecutada — <motivo>
Pendiente o riesgo conocido: <si existe>
```
