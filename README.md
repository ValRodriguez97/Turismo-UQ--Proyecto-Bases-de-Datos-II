# TurismoUQ - Bases de Datos II (2026-2) 

## Orden de ejecucion (una base limpia, de arriba abajo)

| # | Script | Conexion |
|---|--------|----------|
| 0 | E2_00_system.sql | SYSTEM (una sola vez) |
| 1 | ScriptDDL-TurismoUQ.sql | usuario del proyecto |
| 2 | Carga_TurismoUQ.sql | usuario del proyecto |
| 3 | Consultas_Analisis_TurismoUQ.sql | usuario del proyecto |
| 4 | E2_01_PaqueteTurismouq.sql | usuario del proyecto |
| 5 | E2_02_Disparadores.sql | usuario del proyecto |
| 6 | E2_03_Tablespace_VistaMaterializada.sql | usuario del proyecto |
| 7 | E2_04_Pruebas.sql | usuario del proyecto |
| 8 | E3_01_Transacciones.sql | usuario del proyecto |
| 9 | E3_02_SesionA.sql | usuario del proyecto |
| 10 | E3_02_SesionB.sql | usuario del proyecto |
| 11 | E3_03_Indices.sql | usuario del proyecto |
| 12 | E3_04_Roles_Usuarios_Grant_Vistas.sql | conectado como SYSTEM | 


Salida de las pruebas: 
- evidencia_entrega2.txt
- evidencia_entrega3_indices.txt
- evidencia_entrega3_transacciones.txt
- evidencia_seguridad.txt

Integrantes:
- Valentina Gonzalez Diaz - Código: 1094898396
- Raquel Lopez Aristizabal - Código: 1091884575
- Valentina Rodriguez Castro - Código: 1016833647