# Material externo: hackathones FPGA

Esta carpeta contiene paquetes locales que se pueden abrir al empezar a estudiar un hackathon. No son parte de la entrega INDRA ni sustituyen sus normas. Se conservan el `LICENSE`, el `README` y la estructura de cada origen.

| Paquete local | Tipo | Para estudiar | Infraestructura principal |
| --- | --- | --- | --- |
| [`01_HeiChips_2025_Template`](01_HeiChips_2025_Template) | Hackathon con eFPGA y tapeout | Plantilla completa, RTL, testbench y emulacion FPGA | Nix, cocotb, Icarus/Verilator, Yosys/nextpnr y placa soportada |
| [`02_Verilog_Meetup_2025_Template`](02_Verilog_Meetup_2025_Template) | Hackathon FPGA con extension a ASIC | Top level, perifericos y flujo de validacion | Git, simulador RTL y placa FPGA; el flujo ASIC es opcional |

## Procedencia y licencia

Los paquetes son instantaneas reproducibles descargadas de los repositorios originales el 2026-09-28. Se incluyen porque ambos publican licencia Apache-2.0. No se ha modificado su RTL, sus licencias ni sus instrucciones originales.

La base binaria `xc7a35tcpg236.bin` de HeiChips no se versiona: ocupa 92 MB y es un artefacto de herramientas, no material de partida. El flujo Nix incluido documenta como obtener o generar sus dependencias.

| Paquete | Origen | Revision copiada | Licencia |
| --- | --- | --- | --- |
| HeiChips 2025 | <https://github.com/HeiChips/heichips25-template> | `30a1f05bc55cab61112e7cefb7415611383f768b` | Apache-2.0 |
| Verilog Meetup 2025 | <https://github.com/verilog-meetup/ttsky-verilog-template-for-verilog-meetup> | `0bc4163fde4ab24704f9b7c5ba49012124bfbf6f` | Apache-2.0 |

## Como estudiarlos como si comenzara el hackathon

1. Lee primero el `README.md` del paquete y su `LICENSE`.
2. Identifica el modulo superior, las restricciones de placa y el comando de simulacion antes de editar ningun RTL.
3. Ejecuta el testbench original sin cambios. Es la linea base de que el entorno esta bien montado.
4. Crea tu rama y conserva el interfaz del modulo superior. Cambia solo el RTL que el reto permita modificar.
5. Guarda resultados de simulacion, utilizacion y timing en una carpeta propia que no se confunda con el material de partida.

## Que aprender de la infraestructura

El valor de estos paquetes no es solo el RTL: muestran la cadena completa que un hackathon necesita para ser reproducible. La ficha [`INFRAESTRUCTURA.md`](INFRAESTRUCTURA.md) resume los componentes que conviene preparar antes del dia del evento y compara ambos ejemplos.

## Material que no se ha copiado

Hay repositorios publicos de participantes sin archivo `LICENSE`, como las soluciones parciales de Nokia FPGA Hackathon 2023. Se pueden consultar en su origen, pero no se redistribuyen aqui hasta disponer de permiso o licencia explicita. Tambien se excluyen retos de RTL/ASIC que no sean hackathones FPGA propiamente dichos.
