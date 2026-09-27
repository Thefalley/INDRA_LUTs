# Entrega del proyecto team018

## Version y alcance

Snapshot de GitLab `main`, commit `e209aad5f9cf76072b9b70446943e96c65d937e9`,
preparado el 27/09/2026. Es la version cargada por Jenkins #28.
Incluye la correccion de task 15 del commit `71032ef`.
No afirmar que ha puntuado: al preparar esta entrega falta el resultado del juez.

Se han copiado y comparado por SHA256 los **235 archivos normales versionados**
del commit: cero diferencias antes de agregar esta documentacion.
No se copian `.git`, claves, contrasenas ni directorios temporales de Vivado.
El ELF y XSA de task 8 SI se incluyen: son productos versionados requeridos
por la infraestructura oficial, no caches prescindibles.

Esta carpeta es una entrega autocontenida del codigo disponible, NO un merge
con `../team018_repo`. Aquel directorio contiene trabajo local de companeros
que se ha preservado sin sobrescribirlo. Tampoco contiene el historial GitLab:
para consultar commits anteriores hay que acceder al repositorio de origen.
Los PDF oficiales de esta edicion estan en `../material` del repositorio GitHub.

## Directorios

| Ruta | Contenido |
|---|---|
| `src/tasks` | Implementaciones FPGA y software de task 8 |
| `src/task_enabler_pkg.svh` | Selector de tasks FPGA para el juez |
| `src/task_wrappers` | Adaptacion oficial; parte del codigo esta cifrada |
| `vivado/hackathon.tcl` | Generacion del proyecto Vivado y registro de fuentes |
| `tb` | tb_lite, tb_top, control_wrapper_tb, vectores y referencias oficiales locales |
| `synopsys` | Flujo independiente de task 4 |
| `siemens` | Flujo independiente de task 6 |
| `experiments` | Bancos y scripts adicionales, NO sustituyen al juez |
| `reports` | Informes historicos; comprobar siempre el commit que describen |

Las FPGA activadas son 1,2,3,5,7,8,9,10,11,12,13,14,15,16.
4 y 6 se evaluan por flujos independientes y no necesitan un enable FPGA.
La configuracion es experimental con todas las candidatas, no una version
certificada. La task 7 conserva fallos funcionales conocidos.

## Estado de pruebas al preparar la entrega

| Task | Evidencia disponible / limite |
|---|---|
| 15 corregida | Vector oficial local 208/208 bytes; 48 casos ampliados PASS; sintesis OOC sin errores. Falta juez |
| 16 mejorada | 256 paquetes y 192105 bytes comprobados; OOC correcto. Falta resultado integrado de esta variante |
| 9 | 46 pruebas locales PASS; no equivalen a puntuacion oficial |
| 8 | Pruebas de algoritmo en CPU y enlace de ELF; no garantizan DMA ni latencia en placa |
| 7 | Fallos conocidos; incluida por peticion expresa para evaluar |
| Resto | Consultar REGISTRO_PRUEBAS.md e informes por version; no asumir PASS nuevo |

El archivo de task 11 recibido en cuarentena NO se integra: tenia un error
de sintaxis y reducia el soporte de 64x64 a 8x8. Se conserva la version previa.

## Prueba reproducible de task 15 en Windows

Requiere Vivado 2025.2 instalado. Desde ESTA carpeta:

```powershell
./experiments/task15/run_check.ps1 -VivadoBin 'C:/AMDDesignTools/2025.2/Vivado/bin'
```

Debe terminar sin error y mostrar `STAGE_CHECK_PASS` y `GENERAL_PASS`.
El script comprueba los marcadores: un exit code cero de XSim por si solo
no garantiza que no haya ocurrido un `$fatal`.
Resultados y limitaciones en `experiments/task15/RESULTADOS.md`.

## Otros bancos

| Banco | Uso / limite |
|---|---|
| `tb/tb_lite.sv` | Entorno oficial reducido. Necesita fuentes/IP/bibliotecas del proyecto; no es RTL aislado |
| `tb/tb_top.sv` | Entorno de integracion completo, mas pesado |
| `tb/Makefile` | Flujo Questa; seleccion TB=tb_lite o TB=tb_top. Ajustar rutas de herramientas y generar IP primero |
| `experiments/task9/tb_task9_extended.sv` | Banco RTL adicional de 46 casos |
| `experiments/task16/run_compare.ps1` | A/B; necesita baseline GitLab 2f37952 en otro worktree, pasado con -BaselineRoot |
| `experiments/task4/tb_frame_local.sv` | Banco local adicional, no el juez Synopsys |
| `src/tasks/task_8/sw/tests/test_sort.c` | Prueba CPU contra referencia; no simula MicroBlaze/DMA |
| `experiments/task7/reference.py` | Modelo matematico; no es prueba integrada del RTL |

Consultar [ENTORNO_JENKINS.md](ENTORNO_JENKINS.md) para el flujo completo.

## Nota de empaquetado original

Esta carpeta se preparo dentro de `Thefalley/INDRA_LUTs`. Las indicaciones
siguientes describen el empaquetado original del snapshot; la estructura
actual del repositorio la conserva en `hackathon/2026/entrega`.
No hacer `git add .`, reset, clean ni force-push: mezclarian o perderian trabajo.
Preparar un commit que incluya SOLO esta entrega y reconciliar el avance
remoto antes del push. El ignore heredado excluye algunos ficheros de task 8
que ya estaban versionados en GitLab; preservar todos los del manifiesto.

## Dependencia externa no incluida

`siemens/scripts` es un submodulo, no un archivo normal. Se requiere
`common_scripts` en el commit `501cc5c96c7511115f1c2479bf3143f499d40225`.
La URL esta en `.gitmodules`. La copia anidada no registra automaticamente
un submodulo en el GitHub padre: no basta ejecutar submodule update alli.
Un usuario autorizado debe clonarlo en `siemens/scripts` y seleccionar ese
commit, o registrar correctamente el submodulo en la raiz del repositorio padre.
No se han copiado credenciales ni se garantiza acceso a ese repositorio.
