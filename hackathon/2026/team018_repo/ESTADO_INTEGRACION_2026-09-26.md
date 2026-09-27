# Integración de correcciones verificadas

Base GitHub: a550eb9. Referencia GitLab: 527a4d2.

Se integran las correcciones locales comprobadas para tasks 9, 11, 12, 13, 14 y 16.
Los commits del equipo 6a986a5, 9dc996f y a550eb9 permanecen en el historial.
En 11, wave_generator de 13 y 14 se conserva la implementación verificada de GitLab:
las alternativas nuevas no incorporaban la restauración funcional de 11, reintroducían truncamientos de 13
y perdían LDRM/SETC/volcado completo en 14 (además del literal inválido 5 meb10011).

Resultados locales de estas versiones:

- Básicos PASS: 1,3,5,9,10,11,12,13,14,16.
- Task 9: 4 paquetes ampliados PASS.
- Task 12: 9 expresiones PASS.
- Task 13: 15 paquetes de ondas PASS.
- Task 14: 3 programas PASS; síntesis, opt_design y DRC MDRV-1 aislados PASS.
- Task 16: 32 paquetes con pausas, 1312 bytes PASS.

No equivale a validación oficial, timing cerrado ni cobertura exhaustiva.

## Trabajo pendiente del equipo: Task 7

La versión CORDIC del commit a550eb9 se conserva intacta en este repositorio.
No se copia a GitLab como corrección validada: contiene 1 meb0, entrega el ángulo CORDIC
en radianes y mantiene fórmulas incompletas para phi2/phi3/phi4. También requiere revisar
el protocolo start/done para no consumir un resultado anterior.
La versión anterior en GitLab compila, pero falla los 12 ángulos del vector básico.
No se declara ninguna de las dos validada.

## Jenkins y compilación completa

Jenkins #8 falló con el commit antiguo 7bb0696 por múltiples drivers de rx_val de Task 14.
El problema específico ya no aparece en la prueba aislada corregida.
Jenkins #9 se lanzó después de publicar 527a4d2; comprobar siempre su checkout antes de atribuir resultados.
El bitstream local se está generando en una carpeta independiente del commit 527a4d2.

Siemens y Synopsys tienen fallos funcionales independientes pendientes; sus etapas completadas
no significan que los tests pasen. No se han modificado sus ficheros protegidos.
