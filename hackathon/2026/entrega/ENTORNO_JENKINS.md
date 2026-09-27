# Entorno de compilacion y evaluacion

## Repositorios y responsabilidades

- GitHub Thefalley/INDRA_LUTs: colaboracion, documentacion y esta entrega.
- GitLab hackathonfpga_2026_team_repos/team018: fuente que descarga el job oficial.
- Jenkins team018_check_code: coordina herramientas, compilacion y juez.
- El servidor de CI mantiene scripts oficiales externos a nuestro codigo.
  Copiar el proyecto a GitHub no copia ni instala Jenkins y no activa el juez.
- La VM del equipo y el PC sirven para pruebas locales; sus resultados no
  escriben automaticamente puntos en la base de datos de la competicion.

Job: https://jenkins.dev.fpgahackathon.com/job/team018_check_code/
Validacion de esta entrega: build 28, commit e209aad.
El job sustituyo automaticamente #27 al arrancar #28. Antes de lanzar otra
ejecucion hay que comprobar esta politica; no suponer que esperara en cola.

## Etapas observadas

| Etapa | Que hace | Que demuestra |
|---|---|---|
| Checkout / Init / Download | Descarga infraestructura y repositorio del equipo | Que version se prueba; leer el SHA del team_repo, no el de CI |
| Quality check | Comprueba fuentes y condiciones del flujo | No demuestra correccion funcional |
| Siemens simulation | Pruebas de task 6 | Resultado independiente de los bits FPGA |
| Synopsys simulation | Pruebas de task 4 | Buscar PASS y puntos, no solo estado global |
| Code Synthesis | Vitis, proyecto Vivado, IP, sintesis, implementacion, bitstream e informes | No es solo synth_design |
| Reserve board, Program and Judge Bitfile | Reserva/programa FPGA y ejecuta vectores del juez | Comparacion real del diseno integrado |
| Obtain results | Publica logs/puntuaciones | Evidencia final por task |

`SUCCESS` no garantiza que todas las tasks puntuen: algunas pueden obtener
cero sin hacer fallar el pipeline. Si falla implementacion, la etapa de placa
puede omitirse y no hay veredicto funcional de esas tasks.

## Herramientas y construccion

Vivado/Vitis 2025.2, dispositivo xck26-sfvc784-2LV-c. La task 8 incluye
MicroBlaze, DMA, memorias y software. Desactivar su enable no elimina
necesariamente sus IP de la construccion.

Desde `src/tasks/task_8/sw`, con Vitis configurado:

```text
vitis -s bootstrap.py
vitis -s build.py
```

Luego el flujo usa `vivado/hackathon.tcl` para crear el proyecto. El comando
batch se ejecuta desde `vivado` con las rutas esperadas por ese Tcl.
Los pasos oficiales posteriores los controla `run_vivado_comp.sh` y otros
scripts de CI externos: no estan todos en esta entrega.

Sintesis traduce RTL a primitivas; opt_design optimiza, place_design coloca,
route_design conecta fisicamente y write_bitstream genera la configuracion.
DRC comprueba reglas del diseno; timing verifica setup/hold contra restricciones.
No quitar restricciones ni ignorar errores para conseguir un PASS aparente.

Esta entrega NO modifica directivas, XDC ni Tcl oficial respecto a su base.
No atribuirle una estrategia nueva: comprobar en cada consola lo que CI
aplica realmente, porque puede sobrescribir propiedades del proyecto.

## Logs y diagnostico

Consola: `/job/team018_check_code/<numero>/console` o `consoleText`.
Metadatos: `/job/team018_check_code/<numero>/api/json`.
Etapas: `/job/team018_check_code/<numero>/wfapi/describe`.
Requieren autenticacion segun la configuracion del servicio; no guardar claves.

Los logs observados copian resultados a `/workdir/team018/run-<numero>-<sha>/`:
reports, bitstream y logs/public. Son rutas internas del servidor, no enlaces
de descarga garantizados. Consultar el mecanismo de acceso del organizador.

Para comparar ejecuciones registrar: SHA, enables, puntuacion por task,
tiempos elapsed, LUT/FF/BRAM/DSP, WNS/TNS/WHS/THS y etapa exacta del fallo.
No sumar tiempos de fases anidadas o runs paralelos. Placement y routing son
globales: no se puede repartir su tiempo por task solo con la consola.

## Limites de la entrega

No contiene credenciales, licencias, servicio de reserva de placas, base de
datos del juez, tests privados ni todos los scripts oficiales de CI.
Parte de los wrappers/testbenches oficiales esta cifrada y necesita las
herramientas compatibles. Los modelos Python y bancos locales no sustituyen
esos tests. `common_scripts` sigue siendo una dependencia externa autorizada.
