# INDRA LUTs

> Archivo de hackathones FPGA, espacio de desarrollo del equipo y guía para
> reproducir el flujo completo: norma → RTL → simulación → entrega.

| Ir directamente a… | Contenido |
| --- | --- |
| [Hackathon 2025](Hackathon_2025) | Guía, 14 ejercicios y proyecto histórico de referencia. |
| [Hackathon 2026](Hackathon_2026) | Entorno, normas oficiales, trabajo del equipo y snapshot de entrega. |
| [Recursos externos](Recursos_Externos) | Plantillas locales, con licencia, de otros hackathones FPGA. |

## Empieza aquí

Si vas a desarrollar una task de la edición actual, sigue este orden:

1. Lee las [normas y el PDF de la task](Hackathon_2026/01_Normas).
2. Prepara las herramientas con la [guía de entorno](Hackathon_2026/00_Entorno/GUIA_SERVIDOR_LOCAL_FPGA.md).
3. Trabaja en [`Hackathon_2026/02_Equipo`](Hackathon_2026/02_Equipo), respetando el wrapper y la interfaz oficial.
4. Contrasta el resultado con la [entrega preparada para Jenkins](Hackathon_2026/03_Entrega_Jenkins/README_ENTREGA.md).

## Mapa del repositorio

```text
INDRA_LUTs/
├── Hackathon_2025/       Material histórico: normas y proyecto de referencia
├── Hackathon_2026/       Edición actual: entorno, reglas, equipo y entrega
└── Recursos_Externos/    Ejemplos reproducibles de otros hackathones FPGA
```

## Qué significa cada zona de 2026

| Zona | Propósito | ¿Se modifica? |
| --- | --- | --- |
| [`00_Entorno`](Hackathon_2026/00_Entorno) | Preparar servidor, Jenkins, Vivado y Kria. | Solo para mantener la infraestructura. |
| [`01_Normas`](Hackathon_2026/01_Normas) | PDFs oficiales y reglas de evaluación. | No: son la referencia. |
| [`02_Equipo`](Hackathon_2026/02_Equipo) | RTL, testbenches, metodología y pruebas durante el desarrollo. | Sí, en los archivos autorizados por cada task. |
| [`03_Entrega_Jenkins`](Hackathon_2026/03_Entrega_Jenkins) | Fotografía de lo preparado para evaluar. | Solo al preparar una entrega controlada. |

## Principios de trabajo

- La especificación de la task manda: no se cambian nombres de módulos, puertos ni wrappers.
- Cada cambio debe poder simularse y, cuando aplique, sintetizarse con el objetivo indicado.
- Los resultados generados no se versionan: `.Xil`, `xsim.dir`, ondas y cachés están ignorados.
- Los recursos de terceros mantienen su licencia, autoría y procedencia; no se mezclan con el RTL de INDRA.

## Infraestructura y aprendizaje

La guía local de servidor está en
[`Hackathon_2026/00_Entorno`](Hackathon_2026/00_Entorno). Para estudiar cómo
otros eventos preparan su plantilla, sus tests, sus placas y su entrega,
consulta [`Recursos_Externos/INFRAESTRUCTURA.md`](Recursos_Externos/INFRAESTRUCTURA.md).

---

Repositorio organizado para que una persona nueva pueda localizar la norma,
reproducir el entorno y distinguir con claridad entre desarrollo y entrega.
