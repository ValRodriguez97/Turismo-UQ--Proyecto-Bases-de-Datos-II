-- =================================================================================
-- TurismoUQ - Entrega 3 - Entregable 3
--
-- Raquel Lopez Aristizabal - Código: 1091884575
-- Valentina Gonzalez Diaz - Código: 1094898396
-- Valentina Rodríguez Castro - Código: 1016833647
-- INDICES: 4 consultas lentas + plan antes/despues + indice compuesto + funcional
--    + caso donde el indice NO ayuda + MEDICION REAL (lecturas logicas / Buffers).
--
-- PARTE 0) Estado inicial: limpieza, estadisticas y que indices tiene la base
-- PARTE 1) Q1 - Chequeo de solape de reserva_habitacion (COMPUESTO de 3 columnas)
-- PARTE 2) Q2 - Cliente por correo en minusculas (FUNCIONAL)
-- PARTE 3) Q3 - Servicios de una reserva (B-tree simple sobre FK)
-- PARTE 4) Q4 - Reservas por estado (indice sobre columna de baja selectividad: NO ayuda)
-- PARTE 5) Resumen de indices al final
--
-- Como se mide:
--   (a) COST estimado: EXPLAIN PLAN + DBMS_XPLAN.DISPLAY
--
-- Orden de ejecución: Después de E3_01 y E3_02.
-- Evidencia en evidencia_entrega3_indices.txt
-- =================================================================================

SET DEFINE OFF
WHENEVER SQLERROR CONTINUE
SET SERVEROUTPUT ON SIZE UNLIMITED 
SET LINESIZE 200
SET PAGESIZE 100
COLUMN table_name FORMAT A20
COLUMN index_name FORMAT A32
COLUMN index_type FORMAT A24
COLUMN uniqueness FORMAT A10
COLUMN column_name FORMAT A20
SPOOL evidencia_entrega3_indices.txt

-- =================================================================================
-- PARTE 0 - ESTADO INICIAL
-- =================================================================================
-- 0.0 Si ya existe alguno de los indices, se borran para partir siempre del mismo estado
-- inicial
BEGIN
      FOR i IN (SELECT index_name FROM user_indexes
            WHERE index_name IN ('IDX_RESERVA_CLIENTE_CHECKIN',
                  'FX_CLIENTE_CORREO_LOWER',
                  'IDX_RES_SERV_RESERVA',
                  'IDX_RESERVA_ESTADO',
                  'IDX_RH_HAB_FECHAS')) LOOP
            EXECUTE IMMEDIATE 'DROP INDEX ' || i.index_name;
      END LOOP;
END;
/

-- 0.1 Estadisticas de TODO el esquema, una sola vez, ANTES de medir nada.
PROMPT === 0.1: estadisticas del esquema ===
BEGIN
      DBMS_STATS.GATHER_SCHEMA_STATS(USER, cascade => TRUE);
END;
/

PROMPT === 0.2: indices que ya existen en las tablas del proyecto ===
SELECT table_name, index_name, index_type, uniqueness
FROM user_indexes
WHERE table_name IN ('RESERVA', 'CLIENTE', 'RESERVA_SERVICIO', 'SERVICIO', 'RESERVA_HABITACION')
ORDER BY table_name, index_name;

PROMPT === 0.3: columnas de cada indice (columna lider primero) ===
SELECT table_name, index_name, column_name, column_position
FROM user_ind_columns
WHERE table_name IN ('RESERVA', 'CLIENTE', 'RESERVA_SERVICIO', 'SERVICIO', 'RESERVA_HABITACION')
ORDER BY table_name, index_name, column_position;

-- =================================================================================
-- PARTE 1 - Q1: CHEQUEO DE SOLAPE EN RESERVA_HABITACION (COMPUESTO DE 3 COLUMNAS)
-- Consulta que ejecutan sp_crear_reserva (E2_01) y el disparador de fila (E2_02) en 
-- CADA reserva nueva: cuenta las líneas activas de una habitación que chocan con un 
-- rango de fecha.
--
-- Cost antes (TABLE ACCESS FULL sobre RESERVA_HABITACION): 69
-- Cost después (INDEZ RANGE SCAN en IDX_RH_HAB_FECHAS): 4
--
-- * Los únicos indices de reserva_habitación son la PK (id_reserva_hab) y 
--   reserva_habitacion_uq (id_reserva, id_habiracion)
-- * Indice COMPUESTO (id_habitacion, fecha_checkin_linea, fecha_checkout_linea9;
--    - id_habitacion -> igualdas, columna lider.
--    - fecha_checkin_linea -> rango (checkin_linea < salida pedida)
--    - fecha_checkout_linea -> segundo rango (checkout_linea) > entrada pedida. 
-- =================================================================================
VARIABLE b_hab NUMBER

-- Habitacion con mas lineas de reserva (el caso mas exigente)
BEGIN
      SELECT id_habitacion INTO :b_hab
      FROM (SELECT id_habitacion
            FROM reserva_habitacion
            GROUP BY id_habitacion
            ORDER BY COUNT(*) DESC, id_habitacion)
      WHERE ROWNUM = 1;
END;
/

-- Ventana de fechas = la de una reserva ACTIVA que ya existe en esa habitacion.
VARIABLE b_in  VARCHAR2(10)
VARIABLE b_out VARCHAR2(10)
BEGIN
      SELECT TO_CHAR(f_in, 'YYYY-MM-DD'), TO_CHAR(f_out, 'YYYY-MM-DD')
      INTO :b_in, :b_out
      FROM (SELECT rh.fecha_checkin_linea AS f_in, rh.fecha_checkout_linea AS f_out
            FROM reserva_habitacion rh
            JOIN reserva r ON r.id_reserva = rh.id_reserva
            WHERE rh.id_habitacion = :b_hab
                  AND r.estado IN ('pendiente', 'confirmada', 'completada')
            ORDER BY rh.fecha_checkin_linea DESC)
      WHERE ROWNUM = 1;
END;
/
SELECT :b_hab AS habitacion_consultada, :b_in AS desde, :b_out AS hasta FROM dual;

PROMPT === Q1 sin indice: plan antes ===
EXPLAIN PLAN FOR
SELECT COUNT(*)
FROM reserva_habitacion rh
JOIN reserva r ON r.id_reserva = rh.id_reserva
WHERE rh.id_habitacion = :b_hab
      AND r.estado IN ('pendiente', 'confirmada', 'completada')
      AND rh.fecha_checkin_linea  < TO_DATE(:b_out, 'YYYY-MM-DD')
      AND rh.fecha_checkout_linea > TO_DATE(:b_in, 'YYYY-MM-DD');
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, NULL, 'BASIC +COST +ROWS +PREDICATE'));

PROMPT === Q1 con indice compuesto ===
CREATE INDEX idx_rh_hab_fechas
      ON reserva_habitacion (id_habitacion, fecha_checkin_linea, fecha_checkout_linea);

EXPLAIN PLAN FOR
SELECT COUNT(*)
FROM reserva_habitacion rh
JOIN reserva r ON r.id_reserva = rh.id_reserva
WHERE rh.id_habitacion = :b_hab
      AND r.estado IN ('pendiente', 'confirmada', 'completada')
      AND rh.fecha_checkin_linea  < TO_DATE(:b_out, 'YYYY-MM-DD')
      AND rh.fecha_checkout_linea > TO_DATE(:b_in, 'YYYY-MM-DD');
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, NULL, 'BASIC +COST +ROWS +PREDICATE'));

PROMPT === Q1 control: mismo resultado con y sin indice ===
SELECT COUNT(*) AS choques
FROM reserva_habitacion rh
JOIN reserva r ON r.id_reserva = rh.id_reserva
WHERE rh.id_habitacion = :b_hab
      AND r.estado IN ('pendiente', 'confirmada', 'completada')
      AND rh.fecha_checkin_linea  < TO_DATE(:b_out, 'YYYY-MM-DD')
      AND rh.fecha_checkout_linea > TO_DATE(:b_in, 'YYYY-MM-DD');

-- =================================================================================
-- PARTE 2 - Q2: CLIENTE POR CORREO SIN IMPORTAR MAYUSCULAS (FUNCIONAL)
-- ---------------------------------------------------------------------------------
-- Cost antes (TABLE ACCESS FULL sobre CLIENTE): 11, 30 filas estimadas
-- Cost despues (FX_CLIENTE_CORREO_LOWER): 2, 1 fila estimada
--
--  * El usuario puede escribir un correo con mayusculas mezcladas y la consulta compara 
--    LOWER(correo) = LOWER(:b_correo).
--  * cliente.correo ya tiene un indice unico, pero guarda el correo tal cual está escrito
--    por lo que Oracle ya no puede usar ese indice. Ya que solo guarda "correo", no 
--    "LOWER(correo)".
--  * Con el indice funcional se guarda el valor ya en minusculas.
-- =================================================================================
VARIABLE b_correo VARCHAR2(80)

-- Correo del cliente 1500 con mayusculas mezcladas
BEGIN
      SELECT INITCAP(correo) INTO :b_correo FROM cliente WHERE id_cliente = 1500;
END;
/
SELECT :b_correo AS correo_buscado FROM dual;

PROMPT === Q2 sin indice funcional: plan antes ===
EXPLAIN PLAN FOR
SELECT id_cliente, nombre, correo
FROM cliente
WHERE LOWER(correo) = LOWER(:b_correo);
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, NULL, 'BASIC +COST +ROWS +PREDICATE'));

PROMPT === Q2 con indice funcional ===
CREATE INDEX fx_cliente_correo_lower
      ON cliente (LOWER(correo));

BEGIN
      DBMS_STATS.GATHER_TABLE_STATS(USER, 'CLIENTE', cascade => TRUE);
END;
/

EXPLAIN PLAN FOR
SELECT id_cliente, nombre, correo
FROM cliente
WHERE LOWER(correo) = LOWER(:b_correo);
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, NULL, 'BASIC +COST +ROWS +PREDICATE'));

PROMPT === Q2 control: mismo resultado, con y sin indice ===
SELECT COUNT(*) AS filas_devueltas
FROM cliente
WHERE LOWER(correo) = LOWER(:b_correo);

-- =================================================================================
-- PARTE 3 - Q3: SERVICIOS DE UNA RESERVA (B-TREE SIMPLE SOBRE FK)
-- ---------------------------------------------------------------------------------
-- Cost antes (TABLE ACCESS FULL sobre RESERVA_SERVICIO): 71
-- Cost despues (IDX_RES_SERV_RESERVA): 9
--
--  * reserva_servicio.id_reserva es una FK sin indice. Para listar los servicios de 
--    UNA reserva Oracle tendría que leer aproximadamente 40.000 lineas de la tabla.
--  * Una reserva tiene pocas lineas de servicio frente a 40.000.
--  * Con un indice, Oracle va directo a las lineas de esa reserva y despues une SERVICIO
--    para traer el nombre.
-- =================================================================================
VARIABLE b_res_serv NUMBER

BEGIN
      SELECT id_reserva INTO :b_res_serv
      FROM (SELECT id_reserva
            FROM reserva_servicio
            GROUP BY id_reserva
            ORDER BY COUNT(*) DESC, id_reserva)
      WHERE ROWNUM = 1;
END;
/
SELECT :b_res_serv AS reserva_con_servicios FROM dual;

PROMPT === Q3 sin indice: plan antes ===
EXPLAIN PLAN FOR
SELECT rs.id_reserva_servicio, rs.cantidad, rs.precio_unitario, s.nombre
FROM reserva_servicio rs
JOIN servicio s ON s.id_servicio = rs.id_servicio
WHERE rs.id_reserva = :b_res_serv;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, NULL, 'BASIC +COST +ROWS +PREDICATE'));

PROMPT === Q3 con indice ===
CREATE INDEX idx_res_serv_reserva
      ON reserva_servicio(id_reserva);

EXPLAIN PLAN FOR
SELECT rs.id_reserva_servicio, rs.cantidad, rs.precio_unitario, s.nombre
FROM reserva_servicio rs
JOIN servicio s ON s.id_servicio = rs.id_servicio
WHERE rs.id_reserva = :b_res_serv;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, NULL, 'BASIC +COST +ROWS +PREDICATE'));

-- =================================================================================
-- PARTE 4 - Q4: RESERVAS POR ESTADO (INDICE SOBRE COLUMNA DE BAJA SELECTIVIDAD)
-- ---------------------------------------------------------------------------------
-- La consulta pide columnas que NO estan en el indice, así que si Oracle usara el indice
-- tendría que ir a la tabla por cada fila (ROWID).
--
-- Cost sin indice: 68
-- Cost con indice sobre estado: 68
--
--  * estado solo tiene 4 valores distintos y 'completada' es la gran mayoria de las reservas.
--  * Un indice por una condicion que devuelve gran parte de la tabla obliga a saltar del indice 
--    a la tabla fila por fila. Eso tiene mas costo que leer la tabla completa de una vez.
--  * Por eso el optimizador mantiene TABLE ACCESS FULL y el indice no baja el Cost, solo ocupa
--    espacio y hace mas lentos los INSERT/UPDATE de reserva.
--  * Un indice BITMAP es una buena opcion para pocos valores distintos pero como RESERVA es una tabla 
--    transaccional con muchos INSERT/UPDATE concurrentes el bitmap bloquea grupos de filas.
-- =================================================================================
PROMPT === Q4 sin indice: plan antes ===
EXPLAIN PLAN FOR
SELECT id_reserva, id_cliente, fecha_reserva, checkin, checkout
FROM reserva
WHERE estado = 'completada';
SELECT * FROM TABLE (DBMS_XPLAN.DISPLAY(NULL, NULL, 'BASIC +COST +ROWS +PREDICATE'));

PROMPT === Q4 con indice B-tree sobre estado: plan despues ===
CREATE INDEX idx_reserva_estado ON reserva (estado);

EXPLAIN PLAN FOR
SELECT id_reserva, id_cliente, fecha_reserva, checkin, checkout
FROM reserva
WHERE estado = 'completada';
SELECT * FROM TABLE (DBMS_XPLAN.DISPLAY(NULL, NULL, 'BASIC +COST +ROWS +PREDICATE'));

PROMPT === Q4 control: filas con estado completada ===
SELECT COUNT(*) AS completadas FROM reserva WHERE estado = 'completada';

PROMPT === Q4: por que no ayuda - cardinalidad real de estado ===
SELECT estado, COUNT(*) AS filas,
       ROUND(100 * COUNT(*) / (SELECT COUNT(*) FROM reserva), 2) AS pct
FROM reserva
GROUP BY estado
ORDER BY filas DESC;

-- =================================================================================
-- PARTE 5 - RESUMEN Y LIMPIEZA DEL INDICE INUTIL
-- =================================================================================
PROMPT === 5.1: indices finales (los utiles + idx_reserva_estado de Q4) ===
SELECT table_name, index_name, index_type, uniqueness
FROM user_indexes
WHERE table_name IN ('RESERVA','CLIENTE', 'RESERVA_SERVICIO', 'SERVICIO', 'RESERVA_HABITACION')
ORDER BY table_name, index_name;

PROMPT === 5.2: se borra el indice de Q4, que no mejoro el plan ===
DROP INDEX idx_reserva_estado;

PROMPT === 5.3: quedan solo los indices que si sirven ===
SELECT table_name, index_name, index_type, uniqueness
FROM user_indexes
WHERE table_name IN ('RESERVA','CLIENTE', 'RESERVA_SERVICIO', 'SERVICIO', 'RESERVA_HABITACION')
ORDER BY table_name, index_name;

SPOOL OFF