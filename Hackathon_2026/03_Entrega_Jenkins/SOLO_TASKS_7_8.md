# Configuracion actual: solo7y8 reales y habilitadas

Este archivo sustituye las selecciones historicas de FULL_RUN_CANDIDATA.md y PROXIMA_PRUEBA_5_7_8.md.

TasksFPGA7y8:implementacion real y enable1.
TasksFPGA1,2,3,5,9,10,11,12,13,14,15:dummyoriginal registrado del commit fa7ec0f y enable0.
Task16:dummy registrado compatible con ready/valid, conservado de6e436c8 y enable0 para preservar jerarquia de informes.
No quedan implementaciones reales ocultas porifdef en los archivos principales dummy. Las soluciones anteriores se recuperan deGit (paqueteestable b38d0bb). Auxiliares no instanciados permanecen para no modificar Tcl; no realizan calculos en estos dummies.
MicroBlaze,Tcl,XDC y flujosSynopsys4/Siemens6 no se modifican. Estos dos flujos independientes pueden seguir siendo evaluados porJenkins.

Task7 sigueFAIL en prueba publica integrada; esto es una configuracion diagnostica. Task8softwareO2/LMB pasa10008vectores y generaELF;latenciareal pendiente. Directivaoficial Flow_RuntimeOptimized sin cambios.
