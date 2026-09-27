# Guia para montar un laboratorio FPGA local: Git, Jenkins, Vivado, Vitis y Kria

Fecha: 27 de septiembre de 2026. Proyecto: team018 / INDRA_LUTs.

**Este documento es un plan de instalacion con plantillas, no una instalacion realizada.**
Los comandos propuestos para Linux y el pipeline deben validarse en el servidor elegido.
No se ha instalado Jenkins/GitLab ni se ha programado una placa durante la redaccion.
No incluye contrasenas, claves, licencias privadas ni los tests privados del concurso.

## Indice

1. Objetivo y limites
2. Arquitectura recomendada
3. Hardware, sistema operativo y almacenamiento
4. GitHub frente a GitLab local
5. Instalacion de Jenkins y agente
6. Instalacion de Vivado/Vitis y licencias
7. Repositorio, dependencias y versiones
8. Primera ejecucion manual
9. Pipeline local y contratos de scripts
10. Simulaciones y niveles de verificacion
11. Placa Kria K26 / KV260 / KR260
12. Informes, rendimiento y depuracion
13. Seguridad, copias de seguridad y mantenimiento
14. Hoja de ruta y criterios de aceptacion
15. Referencias oficiales

## 1. Objetivo y limites

Queremos que un commit pueda convertirse, de forma repetible, en:

- Una compilacion del software de MicroBlaze.
- Resultados de simulacion y comparaciones con referencias.
- Sintesis del RTL y mediciones de recursos.
- Implementacion fisica y comprobaciones de timing/DRC.
- Bitstream y archivos auxiliares identificados por version.
- Opcionalmente, una prueba automatizada en una FPGA de casa.

Git guarda las versiones. Jenkins coordina comandos. Vivado construye hardware.
Vitis construye software embebido. El testbench comprueba comportamiento en simulacion.
La placa ejecuta el hardware real. Ninguno de esos elementos, por separado, es el juez.

| Capacidad | Localmente | Dependencia |
|---|---|---|
| Compilar RTL y simular bancos propios | Si | Vivado/XSim y fuentes |
| Sintetizar e implementar | Si | Dispositivo e IP compatibles, licencias |
| Compilar MicroBlaze | Si | Vitis, XSA, BSP y configuracion de aplicacion |
| Ejecutar todos los bancos oficiales | Condicionado | Modelos cifrados, bibliotecas, permisos y herramientas |
| Ejecutar Siemens/Synopsys exactamente | Condicionado | Productos y licencias correspondientes |
| Programar y probar una Kria | Si, con integracion | Placa, arranque, drivers y programa de pruebas |
| Obtener puntuacion oficial | No por defecto | Servicio y juez del organizador |

Una placa local no contiene los vectores privados ni publica puntos en la web.
Un banco local que pasa tampoco demuestra que el juez vaya a dar puntos.

### Referencia real del proyecto

- Version evaluada: GitLab `e209aad5f9cf76072b9b70446943e96c65d937e9`.
- Jenkins oficial #28: SUCCESS, 140 puntos de Evaluation y 61 de Development.
- Development y Evaluation son puntuaciones separadas; no se suman.
- Tasks 7, 8 y 15: cero en ambos modos; task 9: 3 publico y 0 privado.
- La task 15 corregida pasa 48 pruebas locales y un vector oficial local,
  pero sigue fallando en placa. Esta discrepancia es una prueba de que el
  laboratorio debe distinguir simulacion, implementacion y juez.
- No cambiar esta referencia mientras se prepara la infraestructura local.

## 2. Arquitectura recomendada

```text
PC del desarrollador
        | commit / push
        v
GitHub existente O GitLab local
        | polling / webhook
        v
Jenkins controller: interfaz, cola, configuracion, credenciales
        | asigna trabajo al agente linux-fpga
        v
Agente Linux: Git + Java + Vivado/Vitis + licencias
        | checkout -> tests -> Vitis -> Vivado -> informes
        v
Artefactos por commit y ejecucion
        |
        +--> opcional: agente de placa -> JTAG/SSH -> Kria
```

Empezaria con GitHub existente, Jenkins y un agente Linux en el mismo servidor.
El agente usa una cuenta Unix diferente del controlador. Mas adelante se pueden
separar en maquinas o VM distintas sin cambiar el RTL.

No necesitamos Kubernetes para empezar. Tampoco necesitamos meter Vivado en
Docker: una instalacion nativa del agente reduce problemas de licencias y USB.
Docker puede ser util para GitLab o el controlador, pero es una opcion separada.

Jenkins permite agentes en equipos fisicos, VM y contenedores. Configurar
**cero ejecutores en el controlador** y **uno en el agente FPGA al inicio**.
Esto evita que la compilacion se ejecute en el proceso/usuario del controlador.
Fuentes: [agentes](https://www.jenkins.io/doc/book/using/using-agents/) y
[aislamiento del controlador](https://www.jenkins.io/doc/book/security/controller-isolation/).

## 3. Hardware, sistema operativo y almacenamiento

Las siguientes cifras son orientaciones de dimensionamiento, NO minimos oficiales
ni una promesa de tiempo de compilacion. Medir primero en el equipo disponible.

| Componente | Punto de partida orientativo |
|---|---|
| CPU | x86-64 moderna; 8 nucleos utiles como referencia para un laboratorio |
| RAM | 32 GB para empezar de forma prudente; 64 GB da mas margen |
| Almacenamiento | SSD/NVMe; reservar varios cientos de GB para herramientas y runs |
| Espacio adicional | Tener margen para instalador, actualizaciones y copias de seguridad |
| Red | Ethernet para servidor/placa; salida a repositorios y servidores de licencia si aplica |
| Electricidad | Evitar suspension automatica; SAI si se necesita continuidad |

No reservar todo el ordenador a Vivado. GitLab, Jenkins, SO y otras aplicaciones
tambien usan memoria. Un swap grande no sustituye la RAM: una implementacion
que empieza a paginar puede multiplicar su tiempo.

### Sistema operativo

Usar una distribucion y revision soportadas por **Vivado y Vitis 2025.2**, no
simplemente la ultima Ubuntu. La compatibilidad de Jenkins no implica la de AMD.
Consultar [matriz de SO de AMD 2025.2](https://docs.amd.com/r/2025.2-English/ug973-vivado-release-notes-install-license/Supported-Operating-Systems).

Windows tambien sirve para muchas pruebas; los scripts Linux del concurso
necesitarian adaptacion. No presentar WSL como equivalente certificado sin
comprobar soporte, licencias, bibliotecas y acceso a USB/JTAG.

### Directorios propuestos

```text
/opt/amd/2025.2/           herramientas, escritura solo para administracion
/srv/fpga-agent/          directorio raiz del agente
/srv/fpga-artifacts/      resultados que se quieran conservar fuera de Jenkins
/srv/gitlab/              solo si se instala GitLab local
/var/lib/jenkins/         datos del controlador instalado como servicio
```

Cada job trabaja en su workspace. No compilar directamente en la carpeta de
trabajo habitual del desarrollador ni compartir un `.xpr` abierto entre procesos.
Dos ejecuciones deben tener directorios de salida distintos.

## 4. GitHub frente a GitLab local

### Opcion A: GitHub existente, recomendada para empezar

Usar `https://github.com/Thefalley/INDRA_LUTs.git`. Jenkins descarga el repositorio
con una credencial de solo lectura. No requiere instalar un servidor Git local.

**Estado al redactar:** la entrega se conserva en
`Hackathon_2026/03_Entrega_Jenkins`. Esta guía describe una infraestructura
propuesta; no presupone que el servidor local esté instalado.

### Opcion B: GitLab en casa

Instalar GitLab CE mediante un metodo oficial, preferiblemente paquete Linux
o contenedor con version fijada. No usar una etiqueta flotante para un servidor
que deba ser reproducible. Elegir la version y el procedimiento de upgrade
con su documentacion, no copiar una version antigua de un tutorial.

Pasos:

1. Reservar nombre DNS interno y direccion del servidor.
2. Preparar almacenamiento persistente para configuracion, datos y logs.
3. Instalar siguiendo la [guia oficial de Docker](https://docs.gitlab.com/install/docker/installation/)
   o el [metodo Linux](https://docs.gitlab.com/install/install_methods/).
4. Definir URL externa real y acceso HTTPS antes de entregar credenciales.
5. Crear administrador y usuario normal; restringir altas no deseadas.
6. Crear el proyecto privado e importar/pushear el codigo del equipo.
7. Crear credencial de lectura para Jenkins.
8. Probar backup y restauracion antes de depender del servidor.

GitLab tiene su propio consumo: la documentacion contempla instalaciones
ajustadas con al menos 8 GB de memoria. Eso NO incluye el consumo de Vivado.
[Requisitos oficiales](https://docs.gitlab.com/install/requirements/).

GitLab Runner no es obligatorio si se usa Jenkins. GitLab CI con Runner es
una alternativa; no hace falta mantener dos motores CI para el mismo cometido.

## 5. Instalacion de Jenkins y agente

### 5.1 Controlador

Usar Jenkins LTS y una version Java compatible. La documentacion consultada
usa Java 21; verificar la compatibilidad al fijar la version concreta.
Seguir el repositorio de paquetes oficial para la distribucion elegida.
[Instalacion Linux](https://www.jenkins.io/doc/book/installing/linux/).

En Debian/Ubuntu, antes del paquete Jenkins:

```bash
sudo apt update
sudo apt install fontconfig openjdk-21-jre git curl openssh-server
java -version
```

Agregar la clave y el repositorio LTS siguiendo la pagina oficial vigente;
despues instalar Jenkins y activar su servicio. Comprobar con:

```bash
sudo systemctl status jenkins
sudo journalctl -u jenkins -n 80 --no-pager
```

Completar el asistente desde la red de confianza, crear administrador propio
y no publicar la clave de desbloqueo. Instalar solo los plugins necesarios.

### 5.2 Plugins y configuracion

Minimos funcionales para la plantilla de esta guia: Pipeline y Git, con sus
dependencias. Para agente por SSH, instalar SSH Build Agents. Para credenciales
de claves, SSH Credentials. Para `timestamps()`, instalar Timestamper.

Opcionales: JUnit para XML de pruebas, Lockable Resources para la placa,
integracion especifica de GitHub/GitLab para webhooks o estados de commits.
Fijar una lista de plugins/versiones y actualizar con backup, no a ciegas.

En Manage Jenkins:

- Configurar URL del servidor y autenticacion.
- Desactivar acceso anonimo a ejecucion/configuracion.
- Establecer cero ejecutores en Built-In Node.
- Crear credenciales de Git y del agente con permisos minimos.
- No habilitar aprobaciones globales de scripts solo para ocultar errores.

### 5.3 Agente de construccion

Crear una cuenta dedicada, por ejemplo `fpga-ci`, sin permisos de administrador.
Instalar Java compatible tambien en el agente. Darle escritura en su workspace,
lectura/ejecucion en AMD y acceso legal al servicio/archivo de licencia.

Crear nodo permanente en Jenkins:

| Campo | Ejemplo |
|---|---|
| Nombre | fpga-local-01 |
| Label | linux-fpga |
| Remote root | /srv/fpga-agent |
| Ejecutores | 1 |
| Lanzamiento | SSH con credencial especifica y host key verificada |

No desactivar la verificacion de host SSH. Un agente inbound/WebSocket es otra
opcion si no se desea SSH entrante; configurar el metodo oficial y proteger
su secreto. No copiar secretos a un Jenkinsfile.

Primera prueba del agente: imprimir `whoami`, `pwd`, `git --version` y
`java -version`. Debe ejecutar como usuario del agente, no como root.

## 6. Instalacion de Vivado/Vitis y licencias

1. Descargar el instalador AMD de la version usada en el proyecto: 2025.2.
2. Seleccionar Vivado, Vitis Embedded y soporte del dispositivo Kria K26.
3. Instalar dependencias del SO indicadas por AMD; el listado de paquetes
   generales de Jenkins no sustituye las dependencias de las herramientas.
4. Instalar board files compatibles. Nuestro Tcl exige
   `xilinx.com:kv260_som:part0:1.4`; comprobar que aparece en `get_board_parts`.
5. Preparar drivers de cable si se usara JTAG; no conceder root al job.
6. Configurar licencias validas para las herramientas/IP que lo requieran.

No asumir que una licencia del concurso pueda usarse desde casa. No copiar
licencias ajenas. Comprobar edicion, dispositivo, IP y derechos de uso con AMD
y el proveedor; Siemens y Synopsys tienen requisitos independientes.

Las rutas siguientes son **ejemplos**: sustituirlas por las del instalador.

```bash
source /opt/amd/2025.2/Vivado/settings64.sh
source /opt/amd/2025.2/Vitis/settings64.sh
command -v vivado
command -v vitis
command -v xvlog
vivado -version
```

Hacer estas comprobaciones bajo la cuenta del agente. Que funcionen desde
el escritorio del administrador no demuestra que funcionen desde Jenkins.
El `sh` de Jenkins no tiene por que cargar `.bashrc` ni ser Bash: invocar
explicitamente `bash ci_local/script.sh` cuando se usa `source` o `pipefail`.

Vitis usa su propio entorno/API: `bootstrap.py` importa `vitis` y se ejecuta
mediante `vitis -s`, no con el Python cualquiera del sistema.

## 7. Repositorio, dependencias y versiones

Mantener el proyecto y sus scripts CI juntos, pero sin caches ni secretos:

```text
raiz-del-proyecto/
  src/                    RTL, wrappers, software
  vivado/hackathon.tcl     generacion del proyecto
  tb/                     bancos y vectores oficiales disponibles
  experiments/            bancos adicionales y pruebas aisladas
  siemens/                task 6
  synopsys/               task 4
  ci_local/               NUEVO: automatizacion propia, no scripts oficiales
  Jenkinsfile.local       NUEVO: pipeline local
```

En el GitHub actual esta estructura corresponde a
`Hackathon_2026/03_Entrega_Jenkins`.
El parametro `PROJECT_DIR` de la plantilla debe apuntar a esa carpeta.
En un clone directo de GitLab, `PROJECT_DIR` seria `.`.

### common_scripts

GitLab registra el submodulo `siemens/scripts` con commit
`501cc5c96c7511115f1c2479bf3143f499d40225` y URL del organizador en `.gitmodules`.

- En un clone GitLab real, inicializar submodulos con credenciales autorizadas.
- En la entrega copiada dentro de GitHub, el `.gitmodules` anidado NO registra
  automaticamente ese gitlink en el padre. Registrar correctamente el
  submodulo o clonar la dependencia autorizada en la ruta esperada.
- Si no hay permisos, marcar la etapa como no disponible; no inventar un PASS.
- Revisar permisos de redistribucion antes de copiar scripts oficiales a GitHub.

Fijar siempre SHA de fuente, submodulos, herramientas, board files e IP.
No descargar el ultimo main de una dependencia a mitad de una ejecucion.

## 8. Primera ejecucion manual

No empezar depurando Jenkins, Vitis y RTL a la vez. Primero demostrar los
comandos manuales bajo el usuario del agente, en un checkout desechable.

### 8.1 Simulacion pequena de task 15

Ejemplo Bash adaptado de los bancos ya probados en Windows. Este port a Linux
debe probarse en el servidor; no confundirlo con un resultado ya ejecutado alli.
Desde la raiz del proyecto, con XSim en PATH:

```bash
set -euo pipefail
project_root="$PWD"
run_dir=$(mktemp -d "$project_root/task15-ci.XXXXXX")
mkdir -p "$run_dir/tb"
cp tb/task15.mem tb/task15_ref.mem "$run_dir/tb/"
cd "$run_dir"
xvlog -sv "$project_root/src/tasks/task_15/task_15.sv" \
  "$project_root/experiments/task15/tb_stages.sv" \
  "$project_root/experiments/task15/tb_general.sv"
for bench in tb_stages tb_general; do
  xelab "$bench" -s "$bench"
  xsim "$bench" -runall -log "$bench.log"
  if grep -Eq 'Fatal:|Error:|TIMEOUT' "$bench.log"; then exit 1; fi
done
grep -q 'STAGE_CHECK_PASS' tb_stages.log
grep -q 'GENERAL_PASS' tb_general.log
```

Conservar esa carpeta para diagnostico; excluir `task15-ci.*/` de Git.
Un `$fatal` de XSim puede coexistir con codigo de salida cero: exigir marcador
PASS y ausencia de errores. No basta con que la herramienta haya arrancado.

### 8.2 Software de task 8

Desde `src/tasks/task_8/sw`:

```bash
vitis -s bootstrap.py
vitis -s build.py
test -s workspace/app/build/app.elf
```

`bootstrap.py` crea la plataforma desde `microblaze_system_wrapper.xsa` y usa
la configuracion de aplicacion versionada en `workspace/app`. No borrar todo
`workspace`: contiene fuentes y metadatos necesarios, no solo temporales.
Probar el bootstrap en un checkout limpio; no asumir que sea idempotente en
un workspace previamente inicializado. Archivar hash del ELF generado y
demostrar que Vivado usa ESE fichero, no un ELF antiguo conservado en Git.

### 8.3 Creacion de proyecto Vivado

Desde `vivado`, en el checkout dedicado a ese run:

```bash
vivado -mode batch -source hackathon.tcl -log create_project.log
```

El Tcl inspeccionado crea `hackathon/hackathon.xpr` y selecciona
`xck26-sfvc784-2LV-c`. Tambien selecciona `kv260_som:part0:1.4`.
No abrir simultaneamente ese proyecto en GUI y batch para modificarlo.

### 8.4 Sintesis e implementacion

Crear un Tcl LOCAL separado; no editar scripts protegidos del concurso.
El siguiente fragmento es una plantilla para un proyecto recien generado:

```tcl
open_project ./hackathon/hackathon.xpr
launch_runs synth_1 -jobs 4
wait_on_run synth_1
puts "SYNTH_STATUS=[get_property STATUS [get_runs synth_1]]"
if {![string match "*Complete*" [get_property STATUS [get_runs synth_1]]]} {
    error "Synthesis did not complete"
}
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
puts "IMPL_STATUS=[get_property STATUS [get_runs impl_1]]"
if {![string match "*Complete*" [get_property STATUS [get_runs impl_1]]]} {
    error "Implementation did not complete"
}
open_run impl_1
file mkdir reports
report_utilization -hierarchical -file reports/utilization.rpt
report_timing_summary -report_unconstrained -file reports/timing.rpt
report_drc -file reports/drc.rpt
```

Validar los estados exactos de run en la version instalada. Completar esta
plantilla con controles de timing, DRC y presencia del bitstream. **Por si sola
no reproduce las comprobaciones del concurso ni certifica signoff.**
Si se parametriza una celda jerarquica para un informe, comprobar que existe
antes de reportarla. Una celda ausente debe quedar indicada; no ocultar fallos.

## 9. Pipeline local y contratos de scripts

Crear primero los scripts manuales; despues versionar un `Jenkinsfile.local`.
Esta plantilla describe la orquestacion. **Los scripts `ci_local/*.sh` de abajo
todavia no estan creados por esta guia**: implementarlos segun sus contratos.
No pegarla y asumir que ya reproduce el entorno oficial.

```groovy
pipeline {
  agent { label 'linux-fpga' }
  options {
    skipDefaultCheckout(true)
    disableConcurrentBuilds()
    timestamps()
    timeout(time: 120, unit: 'MINUTES')
    buildDiscarder(logRotator(numToKeepStr: '15', artifactNumToKeepStr: '5'))
  }
  parameters {
    booleanParam(name: 'FULL_BUILD', defaultValue: false,
                 description: 'Ejecutar tambien Vitis e implementacion')
  }
  environment { PROJECT_DIR = 'Hackathon_2026/03_Entrega_Jenkins' }
  stages {
    stage('Checkout') { steps { checkout scm } }
    stage('Preflight') {
      steps { dir(env.PROJECT_DIR) { sh 'bash ci_local/preflight.sh' } }
    }
    stage('Simulaciones') {
      steps { dir(env.PROJECT_DIR) { sh 'bash ci_local/simulate.sh' } }
    }
    stage('Vitis') {
      when { expression { params.FULL_BUILD } }
      steps { dir(env.PROJECT_DIR) { sh 'bash ci_local/build_vitis.sh' } }
    }
    stage('Vivado') {
      when { expression { params.FULL_BUILD } }
      steps { dir(env.PROJECT_DIR) { sh 'bash ci_local/build_vivado.sh' } }
    }
    stage('Validar resultados') {
      steps { dir(env.PROJECT_DIR) { sh 'bash ci_local/check_results.sh' } }
    }
  }
  post {
    always {
      archiveArtifacts artifacts: '**/ci_results/**',
                       allowEmptyArchive: true, fingerprint: true
    }
  }
}
```

`disableConcurrentBuilds()` encola, no usa `abortPrevious: true`. Es deliberado:
en el servicio oficial #28 sustituyo #27 y desperdicio trabajo en curso.
El timeout de 120 minutos es una politica local de arranque, no el del concurso.
Revisar sintaxis con el validador de Pipeline antes de ponerla en produccion.
[Referencia de Pipeline](https://www.jenkins.io/doc/book/pipeline/syntax/).

### Contratos a implementar

| Script | Debe hacer |
|---|---|
| preflight.sh | Cargar entorno, verificar versiones/rutas/licencia, SHA/enables y espacio; crear ci_results/metadata |
| simulate.sh | Ejecutar suite seleccionada, comprobar PASS/errores/timeout, escribir resumen por test |
| build_vitis.sh | Construir ELF en entorno limpio y registrar su SHA256 y version de herramientas |
| build_vivado.sh | Crear proyecto, implementar, copiar informes y bitstream; propagar errores |
| check_results.sh | Rechazar etapas requeridas ausentes, tests fallidos, DRC fatal, timing fuera de criterio y artefactos vacios |

Todos deben tener `set -euo pipefail`, rutas entre comillas y codigos de salida
utiles. Si usan `tee`, conservar el error del comando real. No usar `|| true`
para tapar fallos. No convertir una suite no ejecutada en una suite aprobada.

`allowEmptyArchive: true` permite conservar diagnostico aunque falle preflight;
NO significa aceptar que una construccion exitosa no genere resultados.
El script de validacion tiene que exigir los archivos requeridos.

### Alta del job

Crear Pipeline from SCM, seleccionar Git, URL, credencial de lectura, rama y
ruta al Jenkinsfile. Probar primero manualmente con Build Now. Activar polling
o webhook solo cuando los fallos se propaguen correctamente.
GitHub publico no puede alcanzar una IP privada de casa por si solo: usar
polling al principio, o un endpoint HTTPS autenticado y limitado. No abrir
puertos del router sin disenar el acceso y sus riesgos.

## 10. Simulaciones y niveles de verificacion

| Nivel | Objetivo | Lo que NO demuestra |
|---|---|---|
| Compilacion RTL | Sintaxis, referencias y elaboracion | Funcionamiento |
| Banco aislado | Algoritmo e interfaz del modulo | Wrapper, DMA o placa |
| tb_lite/tb_top | Integracion y conversiones de ancho | Todos los efectos fisicos |
| Simulacion de netlist | Contrastar RTL con resultado sintetizado | Cierre completo en placa |
| Implementacion/STA | Recursos, restricciones, setup y hold | Exactitud matematica |
| Prueba en placa | Datos reales y latencia del sistema | Vectores privados del organizador |

Para task 15, el siguiente diagnostico importante es comparar la misma entrada
en RTL aislado, wrapper, netlist y placa; falla desde el primer byte en el juez
aunque pase el banco aislado. No cambiar tolerancias ni declarar que el juez
esta equivocado sin capturar entradas/salidas y demostrarlo.

`tb/Makefile` tiene rutas Linux concretas de Questa y bibliotecas AMD. Revisarlas
para el servidor. `tb_lite` no significa que el banco sea independiente de IP.
Generar/exportar las bibliotecas que necesita el simulador y usar versiones
compatibles con el cifrado. Mantener el banco oficial sin modificaciones.

Synopsys: inspeccionar `synopsys/runbatch` antes de ejecutarlo. Limpia archivos
de su directorio de trabajo; usar solo un checkout dedicado. Requiere VCS y
licencia. Siemens: su pipeline depende de `common_scripts` y las herramientas
indicadas por el flujo. Si faltan, etiquetar la etapa como no disponible.

Los tests CPU de task 8 comprueban el algoritmo de ordenacion, pero no caches,
DMA, buffers, coherencia, reloj ni latencia real en MicroBlaze.

## 11. Placa Kria K26 / KV260 / KR260

### Que significa K26

K26 es el modulo SOM. No es necesariamente una placa de desarrollo completa.
KV260 es un kit que integra K26, portadora y solucion termica. KR260 tambien
usa K26, pero su portadora y sus interfaces no son identicas.
[Kit KV260](https://docs.amd.com/r/en-US/ug1089-kv260-starter-kit/What-s-in-the-Box),
[KR260](https://docs.amd.com/r/en-US/ds988-kr260-starter-kit/Product-Details).

Nuestro `vivado/hackathon.tcl` usa:

```text
part:       xck26-sfvc784-2LV-c
board_part: xilinx.com:kv260_som:part0:1.4
```

**Una KV260 completa es una candidata razonable para reproducir el hardware**,
pero hay que validar revision, configuracion de PS, pines, relojes y software.
No prometer que un bitstream funciona en cualquier portadora por usar K26.
Un SOM suelto necesita portadora compatible, alimentacion, refrigeracion y
acceso de arranque/programacion. Confirmar tambien fuente, cable y SD necesarios.

### Dos ordenadores distintos dentro del sistema

- El PC x86-64 ejecuta Jenkins/Vivado/Vitis: fabrica los archivos.
- El procesador ARM del K26 puede ejecutar Linux o bare-metal: controla el sistema.
- El MicroBlaze de task 8 es un procesador implementado en la logica FPGA y
  ejecuta su ELF; no es el mismo procesador ARM.

### Que instalar en cada sitio: no basta con fpgautil

Si por "FPGA util" nos referimos a `fpgautil`, es una herramienta de carga
mediante FPGA Manager, no un simulador, compilador ni juez. El kernel/firmware
de la placa debe soportar ese flujo y tener la configuracion de hardware
correcta. Puede requerir un device-tree overlay asociado al bitstream.
[Flujo oficial ZynqMP PL Programming](https://xilinx-wiki.atlassian.net/wiki/spaces/A/pages/18841847/Solution%2BZynqMP%2B).

| Donde | Instalar/preparar | Para que |
|---|---|---|
| PC/servidor x86-64 | Git, Java y agente Jenkins | Descargar codigo y automatizar |
| PC/servidor x86-64 | Vivado 2025.2 con soporte K26 y board files | Simular y construir hardware |
| PC/servidor x86-64 | Vitis 2025.2 | Compilar el ELF de MicroBlaze |
| Controlador Jenkins | Jenkins, plugins, autenticacion y almacenamiento | Interfaz, jobs y resultados |
| Kria: arranque | Firmware/bootloader compatibles y medio de arranque | Inicializar el sistema |
| Kria: si usamos Linux | Imagen compatible, kernel y device tree | Manejar CPU, memoria y perifericos |
| Kria: carga PL | fpgautil/FPGA Manager O flujo xmutil compatible | Cargar la aplicacion de hardware |
| Kria: acceso al diseño | Drivers y configuracion de DMA/registros segun la arquitectura | Comunicar software y FPGA |
| Kria o PC anfitrion | Programa de pruebas y referencias | Enviar datos, recoger respuestas y compararlas |
| MicroBlaze dentro de PL | app.elf asociado a las memorias del diseño | Ejecutar task 8 |

No se instala Vivado o Jenkins dentro de la logica FPGA. La placa puede
ejecutar un pequeño servicio de pruebas; el trabajo pesado se hace en el PC.

En entornos Kria que lo incluyan, `xmutil` gestiona aplicaciones empaquetadas.
No es sinonimo de poder cargar cualquier `.bit` arbitrario: el paquete debe
ser compatible con la plataforma y su configuracion.
[Utilidades Kria](https://xilinx-wiki.atlassian.net/wiki/spaces/A/pages/1641152513/Kria%2BSOMs%2BStarter%2BKits).

La carga puede usar `.bit`, un binario convertido, un paquete con overlay u
otro formato segun el mecanismo. No renombrar `.bit` a `.bin`: una extension
distinta no convierte el archivo. Generar el formato exigido por el flujo.
Todos los artefactos relacionados deben salir de la misma construccion.

Antes de dar comandos concretos de programacion hay que conocer:

1. Modelo de kit y revision de portadora.
2. Sistema operativo/imagen y version de arranque actuales.
3. Metodo elegido: JTAG, FPGA Manager o aplicaciones Kria empaquetadas.
4. Configuracion PS/PL y mapa de direcciones del diseño.
5. Drivers y forma de comunicacion que usara el programa de prueba.

No mezclar indiscriminadamente PYNQ, XRT, xmutil y fpgautil: son opciones o
componentes de flujos distintos. Elegir uno compatible con el diseño y
documentar sus dependencias. No todos son necesarios para nuestro proyecto.

### Para enviar pruebas reales

Necesitamos conocer mapa AXI, formato y orden de bytes, registros, DMA,
longitudes y protocolo de fin de paquete. Desarrollar un host de pruebas que:

1. Identifique la placa y version del diseño.
2. Cargue artefactos de la MISMA construccion.
3. Aplique reset de forma controlada.
4. Envie un vector conocido.
5. Recoja datos, longitudes, LAST y latencia.
6. Compare con un modelo independiente y guarde evidencia.

Programar solo la PL por JTAG no garantiza que el PS haya inicializado DDR,
relojes, interconexiones ni servicios. Segun el flujo pueden hacer falta XSA,
ELF, archivos de handoff, bootloader, device tree, drivers e imagen de arranque.
No se exige PetaLinux en todos los casos: depende del software anfitrion elegido.

Empezar con una imagen/flujo compatible del fabricante. Guardar copia del
arranque existente. No flashear QSPI ni modificar firmware a ciegas.
Una vez validado manualmente, conectar un agente de hardware a Jenkins y usar
un bloqueo exclusivo de la placa; dos jobs no deben programarla simultaneamente.

## 12. Informes, rendimiento y depuracion

Archivar por ejecucion:

```text
ci_results/
  metadata/       SHA, enables, tool versions, estrategia, restricciones
  simulations/    logs, contadores, casos, referencias y resumen
  vitis/          log, hash del ELF, mapa/tamano si disponible
  synthesis/      recursos globales y jerarquicos
  implementation/ timing final, DRC, congestion, tiempos
  bitstream/      bitstream y artefactos asociados
  board/          entradas/salidas y veredictos locales, si se ejecuta
```

No subir todos los `.wdb`, caches, proyectos generados y DCP a Git.
Conservar ondas de casos fallidos y checkpoints seleccionados como artefactos
con politica de retencion. Los ELF/XSA versionados necesarios son excepciones
explicitas; no excluirlos accidentalmente al copiar este proyecto.

### Como ahorrar tiempo sin ocultar fallos

1. Ejecutar primero la suite barata y no implementar si ya falla.
2. Medir dependencias IP, synth, opt, place y route por separado.
3. Reutilizar cache de IP solo con claves de version, dispositivo y fuentes.
4. Estudiar incremental despues de tener una reconstruccion limpia fiable.
5. Limitar concurrencia para no competir por memoria.
6. Reducir muxes grandes, puertos de memoria y congestion cuando los informes
   señalen un modulo; un atributo BRAM por si solo no cambia una arquitectura incompatible.
7. Comparar directivas una a una con mismo RTL/restricciones y registrar timing.

No confundir `-jobs` (runs paralelos) con hilos internos de herramientas.
Mas hilos no garantizan menos tiempo. El PC de casa puede tardar mas que CI.
No existe una directiva que permita perder precision matematica legalmente:
la precision depende del RTL y la especificacion. Reducir esfuerzo fisico
puede perjudicar timing o routability y debe medirse.

| Sintoma | Comprobar primero |
|---|---|
| Herramienta no encontrada | Entorno del agente, rutas y shell |
| Licencia falla solo en CI | Cuenta, permisos y conectividad de licencia |
| Board part no encontrado | Board files y version 1.4 requerida |
| ELF viejo | Logs de Vitis, fecha/hash y archivo asociado en Vivado |
| Modulo auxiliar ausente | Lista de fuentes y orden de compilacion |
| MDRV-1 | Multiples drivers sobre la misma señal |
| UTLZ-1 | Recursos que no caben; no ocultar el DRC |
| Timing negativo | Camino real, relojes/restricciones y arquitectura |
| Simulacion PASS, placa FAIL | Wrapper, reset, orden de bytes, memoria, DMA y netlist |
| Build verde sin pruebas | Marcadores y etapas obligatorias mal definidos |
| Espacio lleno | Retencion de workspaces/artefactos y logs; no borrar el repositorio |

## 13. Seguridad, backups y mantenimiento

Jenkins ejecuta codigo del repositorio: un Jenkinsfile malicioso puede leer
archivos accesibles al agente. No ejecutar contribuciones no confiables con
credenciales de produccion ni acceso a la placa sin aislamiento.

- Credenciales en Jenkins Credentials, no en Git, comandos impresos o informes.
- Separar token de lectura Git, clave del agente y acceso a la placa.
- No usar `set -x` alrededor de secretos. El enmascarado de logs no es una
  barrera suficiente frente a codigo malicioso.
- No dar acceso al socket Docker al agente sin entender que equivale a
  privilegios muy elevados sobre el host.
- No abrir Jenkins, SSH, licencias o JTAG directamente a Internet; preferir
  red privada/VPN, HTTPS y autenticacion.
- Rotar las credenciales compartidas previamente en chats; no reutilizarlas
  para el laboratorio de casa.

[Gestion de credenciales Jenkins](https://www.jenkins.io/doc/book/using/using-credentials/).

Respaldar Git, configuracion Jenkins y claves de cifrado de sus credenciales
mediante un backup protegido, ademas de configuracion/datos/secretos de GitLab
segun su procedimiento oficial. Un backup incompleto de Jenkins puede impedir
recuperar credenciales. Mantener copia fuera del disco principal y probar restore.
No confundir un volumen Docker persistente con una copia de seguridad.

Actualizar por etapas: backup, prueba en entorno secundario, validacion de
pipeline y despues produccion. No actualizar herramientas AMD a mitad de un
experimento A/B; puede cambiar resultados y tiempos.

## 14. Hoja de ruta y criterios de aceptacion

### Fase 1: laboratorio manual

- Elegir SO soportado e instalar herramientas.
- Clonar una version fija sin modificar el trabajo del equipo.
- Pasar simulacion aislada de task 15 y comprobar que un fallo provoca exit no cero.
- Construir ELF de task 8 y generar el proyecto.

### Fase 2: Jenkins minimo

- Controlador seguro, agente con un ejecutor.
- Checkout y preflight reproducibles.
- Simulaciones con resultados archivados.
- Probar deliberadamente un test fallido EN UNA RAMA DE PRUEBA y confirmar
  que el job queda rojo; no modificar referencias oficiales para obtener verde.

### Fase 3: compilacion completa

- Implementacion y bitstream con gates de timing/DRC.
- Registrar duraciones, recursos y artefactos.
- Comparar reconstruccion limpia con cache/incremental si interesa.

### Fase 4: placa

- Confirmar modelo exacto de Kria y arranque.
- Prueba manual host/FPGA con un vector conocido.
- Automatizar reserva exclusiva, programacion y captura de datos.

### Fase 5: mantenimiento

- Backup restaurado de prueba.
- Documentacion de instalacion y versiones fijadas.
- Retencion de resultados y alertas de disco/servicios.

El laboratorio esta listo cuando otro compañero puede seguir la guia, ejecutar
un commit conocido, obtener evidencia y distinguir PASS, FAIL y NO EJECUTADO.
No hace falta que reproduzca el juez secreto para ser util, pero tiene que
declarar sus limites de forma clara.

## 15. Referencias oficiales

- [Jenkins en Linux](https://www.jenkins.io/doc/book/installing/linux/).
- [Agentes Jenkins](https://www.jenkins.io/doc/book/using/using-agents/).
- [Pipeline declarativo](https://www.jenkins.io/doc/book/pipeline/syntax/).
- [Aislamiento del controlador](https://www.jenkins.io/doc/book/security/controller-isolation/).
- [Credenciales](https://www.jenkins.io/doc/book/using/using-credentials/).
- [Instalacion GitLab](https://docs.gitlab.com/install/install_methods/).
- [GitLab Docker](https://docs.gitlab.com/install/docker/installation/).
- [Requisitos GitLab](https://docs.gitlab.com/install/requirements/).
- [Sistemas soportados AMD 2025.2](https://docs.amd.com/r/2025.2-English/ug973-vivado-release-notes-install-license/Supported-Operating-Systems).
- [Informacion de instaladores AMD](https://www.amd.com/en/support/adaptive-socs-and-fpgas/installer-info-general.html).
- [K26 SOM](https://www.amd.com/en/products/system-on-modules/kria/k26.html).
- [Contenido del kit KV260](https://docs.amd.com/r/en-US/ug1089-kv260-starter-kit/What-s-in-the-Box).
- [Detalles KR260](https://docs.amd.com/r/en-US/ds988-kr260-starter-kit/Product-Details).

Fuentes del proyecto inspeccionadas: `vivado/hackathon.tcl`,
`src/tasks/task_8/sw/bootstrap.py`, `build.py`, `tb/Makefile`,
`synopsys/runbatch`, `.gitmodules` y bancos de `experiments/`, version e209aad.
