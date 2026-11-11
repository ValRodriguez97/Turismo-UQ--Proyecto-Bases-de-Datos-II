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
| 9 | E3_02_Concurrencia.sql | usuario del proyecto |

Experimento de concurrencia (no se ejecutan con F5): E3_02_SesionA.sql y E3_02_SesionB.sql,
paso a paso con Ctrl + Enter en dos sesiones. Resultado en Documentacion/E3_02_Concurrencia_TurismoUQ.docx

Salida de las pruebas: evidencia_entrega2.txt
Integrantes: Valentina Gonzalez Diaz, Raquel Lopez Aristizabal, Valentina Rodriguez Castro