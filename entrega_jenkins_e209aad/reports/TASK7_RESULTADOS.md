# Task 7: diagnostico, NO version resuelta

Rama experiment/ref-task7. Se conserva el RTL real probado en #24, en lugar
del dummy de a12ead7, para continuar el diagnostico sin tocar main.
No se ha introducido otra correccion RTL nueva en esta rama.

- CORDIC aislado anterior: 4112 casos, error maximo 0.000128503 grados.
- RTL integrado: carga correctamente entradas, pero sus calculos phi2/3/4
  no implementan una cinematica inversa completa.
- La referencia Python implementa las ecuaciones VISIBLES del PDF y enumera
  soluciones de hombro/orientacion/codo. No usa ajustes a vectores del juez.
- El forward aplicado a angulos publicos no reconstruye las posiciones publicas
  con esas convenciones. Pendientes marcos de referencia, r33 y eleccion de rama.
- Referencias consultadas: ROS-Industrial ur_kinematics y
  https://github.com/Victorlouisdg/ur-analytic-ik . No se copia su RTL ni se
  afirma que un inversor UR10e generico resuelva la convencion del concurso.

`python experiments/reference.py --check-golden` debe informar discrepancia:
se conserva como diagnostico, no como un PASS ni codigo listo para Jenkins.
