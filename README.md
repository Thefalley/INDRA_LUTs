# INDRA LUTs — entrega y material de trabajo

Este repositorio conserva separadas las tres fuentes de trabajo del hackathon:

| Ruta | Estado | Uso |
| --- | --- | --- |
| [`entrega_jenkins_e209aad`](entrega_jenkins_e209aad) | **Entrega real** | Snapshot autocontenido preparado para Jenkins, basado en el commit GitLab `e209aad`. Es el punto de partida para reproducir o auditar lo entregado. |
| [`team018_repo`](team018_repo) | **Trabajo intermedio** | Árbol de desarrollo local del equipo. Puede contener experimentos y cambios que no pertenecen a la entrega congelada. |
| [`material_hackathon`](material_hackathon) | **Material de referencia** | Enunciados PDF oficiales y el proyecto histórico de 2024. |

## Empezar por la entrega

La documentación y el estado de verificación de la entrega están en
[`entrega_jenkins_e209aad/README_ENTREGA.md`](entrega_jenkins_e209aad/README_ENTREGA.md).
Ese documento delimita las pruebas realizadas y sus límites; no debe interpretarse
como una puntuación oficial de Jenkins.

Para una comprobación local de la task 15 con Vivado 2025.2:

```powershell
cd entrega_jenkins_e209aad
./experiments/task15/run_check.ps1 -VivadoBin 'C:/AMDDesignTools/2025.2/Vivado/bin'
```

## Criterio de organización

Los directorios de XSim/Vivado, ondas, logs y resultados regenerables se excluyen
del control de versiones. Los informes y artefactos que forman parte de la entrega
están ya dentro de `entrega_jenkins_e209aad` y se conservan allí.
