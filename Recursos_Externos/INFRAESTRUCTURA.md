# Como esta pensada la infraestructura de un hackathon FPGA

Un hackathon reproducible empieza antes del reto: cada participante debe poder clonar una plantilla, ejecutar una prueba conocida y programar o emular el mismo diseno sin inventar el entorno. Los dos paquetes de esta carpeta son ejemplos reales de ese enfoque.

| Capa | Que debe entregar la organizacion | HeiChips 2025 | Verilog Meetup 2025 |
| --- | --- | --- | --- |
| Punto de partida | Repositorio plantilla, licencia y reglas | Plantilla de proyecto y `LICENSE` Apache-2.0 | Plantilla de entrega y `LICENSE` Apache-2.0 |
| RTL | Modulo superior y limites de lo modificable | Prefijo obligatorio para el top-level de cada equipo | `lab_top.sv` como modulo de usuario |
| Verificacion | Testbench y comando de simulacion | cocotb con Icarus Verilog o Verilator; `make sim` | Simulacion incluida en la plantilla y pruebas del flujo |
| Herramientas | Versiones o instalacion reproducible | `nix-shell` agrupa LibreLane, simuladores y herramientas FPGA | Herramientas de la plantilla y flujo de depuracion FPGA previo al ASIC |
| Hardware | Placa, restricciones y programacion | Soporta varias placas: iCEBreaker, ULX3S, Tang Nano 9K, Basys 3 y otras | Plataforma FPGA de apoyo para validar antes de la entrega ASIC |
| Entrega | Formato, identificacion y validaciones | Proyecto integrable con otros disenos y eFPGA | Repositorio creado desde plantilla, con interfaz fija |

## Infraestructura minima para nuestro propio hackathon

1. **Repositorio inicial.** Una plantilla por equipo con `README`, `LICENSE`, `.gitignore`, RTL de partida, testbench y un script unico para simular.
2. **Herramientas fijadas.** Indicar versiones de Vivado/Verilator/Python y proporcionar contenedor, Nix o instrucciones de instalacion comprobadas.
3. **Contrato de interfaz.** El wrapper, los nombres de modulo y puertos deben ser inmutables. La task especifica con precision que archivos se pueden editar.
4. **Verificacion automatica.** Tests autocontenidos que devuelvan codigo de error, generen ondas al pedirlo y comprueben funcionalidad, recursos y timing.
5. **Objetivo de FPGA.** Part, constraints, frecuencia objetivo, bitstream y forma de programar la placa deben estar disponibles desde el inicio.
6. **Entrega aislada.** Jenkins o GitLab CI debe ejecutar la misma receta que los equipos usan localmente y publicar los informes sin incluir caches ni ficheros generados.

## Receta de arranque para participantes

```text
clonar plantilla -> leer reglas -> ejecutar test original -> crear rama
-> implementar RTL permitido -> simular -> sintetizar -> revisar timing
-> programar/emular placa -> entregar commit limpio
```

En INDRA, la guia local de servidor, Jenkins, Vivado y Kria esta en [`../Hackathon_2026/00_Entorno/GUIA_SERVIDOR_LOCAL_FPGA.md`](../Hackathon_2026/00_Entorno/GUIA_SERVIDOR_LOCAL_FPGA.md). Usala como complemento para montar la infraestructura propia; no altera los requisitos de los hackathones externos.

## Limites de compatibilidad

No se debe intentar abrir directamente estos paquetes en el proyecto INDRA ni copiar su RTL sobre una task. Usan placas, herramientas e interfaces distintas. Sirven para estudiar como se disena una experiencia de inicio y de entrega reproducible.
