-- =================================================================================
-- TurismoUQ - Entrega 2 - Entregable 3
-- TABLESPACE DEL HISTORICO Y VISTA MATERIALIZADA DE OCUPACION MENSUAL
--   PARTE A) En SYSTEM: crear el tablespace TS_HISTORICO y dar permisos
--   PARTE B) Justificacion del tablespace
--   PARTE C) Tabla RESERVA_HISTORICO particionada por RANGE en TS_HISTORICO
--   PARTE D) Vista materializada MV_OCUPACION_MENSUAL
--   PARTE E) Politica de refresco: justificacion y job programado
--
-- Valentina Gonzalez Diaz
-- Raquel Lopez Aristizabal
-- Valentina Rodriguez Castro
--
-- Orden de ejecucion: DESPUES de E2_02_Disparadores.sql y ANTES de E2_04_Pruebas.sql
-- Los permisos se ejecuta UNA vez en la conexion SYSTEM, ejecutar antes E2_00_system.sql
-- =================================================================================


SET DEFINE OFF
SET SERVEROUTPUT ON
WHENEVER SQLERROR CONTINUE

WHENEVER SQLERROR EXIT FAILURE ROLLBACK
DECLARE
  v_ok NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_ok
  FROM user_ts_quotas
  WHERE tablespace_name = 'TS_HISTORICO' AND (max_bytes = -1 OR max_bytes > 0);

  IF v_ok = 0 THEN
    RAISE_APPLICATION_ERROR(-20999,
      'Falta TS_HISTORICO o la cuota del usuario: ejecutar primero E2_00_system.sql como SYSTEM.');
  END IF;
END;
/
WHENEVER SQLERROR CONTINUE

-- =================================================================================
-- PARTE A - POR QUE SEPARAR EL HISTORICO DE RESERVAS EN SU PROPIO TABLESPACE
-- ---------------------------------------------------------------------------------
-- Las reservas de anios cerrados (2024 y 2025) y las del anio en curso se usan de
-- forma muy distinta:
--   * Las del anio en curso cambian todo el tiempo: se crean, se confirman, se
--     cancelan y reciben pagos. Las consultan recepcion y los encargados.
--   * Las de anios cerrados ya no cambian: solo se leen para los reportes de
--     gerencia (tendencias, comparacion entre anios). Y cada anio son mas.
--
-- Guardarlas en TS_HISTORICO, con su propio datafile, permite:
--   1. Control del espacio: el historico crece con su propio tope (MAXSIZE 100M) y
--      no le quita espacio a USERS, donde viven las tablas operativas.
--   2. Respaldo independiente: el historico se respalda una vez, despues del cierre
--      del anio, y no en cada respaldo diario.
--   3. Solo lectura: despues de cerrar el anio se puede poner
--      ALTER TABLESPACE ts_historico READ ONLY; y nadie lo modifica por error.
--   4. Disco separado: en un servidor real el datafile puede ir en otro disco, sin
--      competir con el disco donde se hacen las transacciones del dia.
--
-- Verificacion: el usuario debe tener cuota en TS_HISTORICO (PARTE A ejecutada)
SELECT tablespace_name, ROUND(bytes / 1024) AS kb_usados, max_bytes
FROM user_ts_quotas
WHERE tablespace_name = 'TS_HISTORICO';


-- =================================================================================
-- PARTE B - TABLA RESERVA_HISTORICO PARTICIONADA POR RANGE
-- ---------------------------------------------------------------------------------
-- Fragmentacion horizontal: las reservas se parten por filas segun el anio del
-- check-in, y cada anio cerrado va en su propio cajon (particion) dentro de
-- TS_HISTORICO:
--   p_2024 -> check-in antes del 01/01/2025
--   p_2025 -> check-in antes del 01/01/2026
--
-- Ventaja de particionar: si una consulta filtra por fecha, Oracle solo abre el
-- cajon de ese anio (poda de particiones). Se comprueba con EXPLAIN PLAN en
-- E2_04_Pruebas.sql.
--
-- La tabla COPIA las reservas, no las borra de RESERVA: las consultas de la
-- Entrega 1 y la vista materializada usan 2024-2026 completo, y PAGO, RESENA,
-- RESERVA_HABITACION y RESERVA_SERVICIO tienen claves foraneas hacia RESERVA.
--
-- Cierre de cada anio (ejemplo para 2026, se ejecuta en enero de 2027):
--   ALTER TABLE reserva_historico ADD PARTITION p_2026
--     VALUES LESS THAN (DATE '2027-01-01') TABLESPACE ts_historico;
--   INSERT INTO reserva_historico
--     SELECT id_reserva, id_cliente, fecha_reserva, checkin, checkout, estado
--     FROM reserva
--     WHERE checkin >= DATE '2026-01-01' AND checkin < DATE '2027-01-01';
-- =================================================================================

-- B.1 Borrar la tabla si existe, para poder re-ejecutar el script
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE reserva_historico PURGE';
EXCEPTION WHEN OTHERS THEN
  IF SQLCODE != -942 THEN RAISE; END IF; -- -942: la tabla no existia
END;
/

-- B.2 Crear la tabla particionada y llenarla con las reservas de los anios cerrados
CREATE TABLE reserva_historico
TABLESPACE ts_historico
PARTITION BY RANGE (checkin) (
  PARTITION p_2024 VALUES LESS THAN (DATE '2025-01-01') TABLESPACE ts_historico,
  PARTITION p_2025 VALUES LESS THAN (DATE '2026-01-01') TABLESPACE ts_historico
)
AS
SELECT id_reserva, id_cliente, fecha_reserva, checkin, checkout, estado
FROM reserva
WHERE checkin < DATE '2026-01-01';

-- B.3 Llave primaria (su indice tambien va en TS_HISTORICO) y restricciones
ALTER TABLE reserva_historico
    ADD CONSTRAINT reserva_historico_pk PRIMARY KEY (id_reserva)
    USING INDEX TABLESPACE ts_historico;

ALTER TABLE reserva_historico
    ADD CONSTRAINT reserva_hist_estado_ck CHECK (estado IN ('pendiente','confirmada','cancelada','completada'));

ALTER TABLE reserva_historico
    ADD CONSTRAINT reserva_hist_fechas_ck CHECK (checkout > checkin);

COMMENT ON TABLE reserva_historico IS 'Historico de reservas de los anios cerrados, particionado por anio de check-in; vive en el tablespace TS_HISTORICO.';

-- B.4 Como quedaron las particiones: limite, tablespace y filas de cada cajon
SELECT partition_position, partition_name, tablespace_name, high_value
FROM user_tab_partitions
WHERE table_name = 'RESERVA_HISTORICO'
ORDER BY partition_position;

SELECT 'p_2024' AS particion, COUNT(*) AS reservas FROM reserva_historico PARTITION (p_2024)
UNION ALL
SELECT 'p_2025', COUNT(*) FROM reserva_historico PARTITION (p_2025);

-- B.5 Procedimiento que alimenta el historico al cerrar un anio
-- Crea la particion del anio si no existe y copia las reservas de ese anio que aun no
-- estan. Es idempotente: ejecutarlo dos veces no duplica filas. Solo para anios
-- posteriores a la ultima particion o ya existentes; los anios abiertos se rechazan.
CREATE OR REPLACE PROCEDURE sp_archivar_anio (p_anio IN NUMBER) IS
  v_existe NUMBER;
  v_filas  NUMBER;
  v_ini    DATE;
  v_fin    DATE;
BEGIN
  IF p_anio IS NULL OR p_anio >= EXTRACT(YEAR FROM SYSDATE) THEN
    RAISE_APPLICATION_ERROR(-20021,
      'Solo se archivan anios cerrados; el anio ' || p_anio || ' no esta cerrado.');
  END IF;

  v_ini := TO_DATE(p_anio || '-01-01', 'YYYY-MM-DD');
  v_fin := ADD_MONTHS(v_ini, 12);

  SELECT COUNT(*) INTO v_existe
  FROM user_tab_partitions
  WHERE table_name = 'RESERVA_HISTORICO' AND partition_name = 'P_' || p_anio;

  IF v_existe = 0 THEN
    EXECUTE IMMEDIATE 'ALTER TABLE reserva_historico ADD PARTITION p_' || p_anio ||
      ' VALUES LESS THAN (DATE ''' || TO_CHAR(v_fin, 'YYYY-MM-DD') ||
      ''') TABLESPACE ts_historico';
  END IF;

  INSERT INTO reserva_historico (id_reserva, id_cliente, fecha_reserva, checkin, checkout, estado)
  SELECT r.id_reserva, r.id_cliente, r.fecha_reserva, r.checkin, r.checkout, r.estado
  FROM reserva r
  WHERE r.checkin >= v_ini AND r.checkin < v_fin
    AND NOT EXISTS (SELECT 1 FROM reserva_historico h WHERE h.id_reserva = r.id_reserva);

  v_filas := SQL%ROWCOUNT;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Anio ' || p_anio || ' archivado: ' || v_filas || ' reserva(s) nuevas.');
END sp_archivar_anio;
/
SHOW ERRORS PROCEDURE sp_archivar_anio


-- =================================================================================
-- PARTE C - VISTA MATERIALIZADA MV_OCUPACION_MENSUAL
-- ---------------------------------------------------------------------------------
-- Una vista normal guarda solo la consulta; una vista materializada guarda tambien
-- el RESULTADO, y por eso hay que refrescarla cuando cambian los datos (PARTE E).
--
-- Una fila por alojamiento y mes, incluidos los meses en que el alojamiento no tuvo
-- ninguna reserva (ocupacion 0 %), para todo el rango de meses con datos:
--   noches_disponibles = habitaciones del alojamiento x dias del mes
--   noches_ocupadas = noches vendidas que CAEN en ese mes
--   pct_ocupacion = noches_ocupadas / noches_disponibles x 100
--
-- Una estadia que cruza dos meses (28 de enero al 3 de febrero) reparte sus noches:
-- 4 en enero (28, 29, 30, 31) y 2 en febrero (1, 2). La noche del check-out no se
-- cuenta, igual que en fn_valor_estadia. Para cada linea y mes:
--   LEAST(checkout, inicio del mes siguiente) - GREATEST(checkin, inicio del mes)
--
-- Cuentan como ocupacion las reservas confirmadas y completadas, el mismo criterio
-- de la consulta 1 de la Entrega 1 y de la liquidacion mensual.
--
-- id_municipio e id_tipo_alojamiento quedan en la vista para poder agrupar la
-- ocupacion por municipio o por tipo sin volver a las tablas base.
-- =================================================================================

-- C.1 Borrar la vista si existe, para poder re-ejecutar el script
BEGIN
  EXECUTE IMMEDIATE 'DROP MATERIALIZED VIEW mv_ocupacion_mensual';
EXCEPTION WHEN OTHERS THEN
  IF SQLCODE != -12003 THEN RAISE; END IF; -- -12003: la vista materializada no existia
END;
/

-- C.2 Crear la vista materializada (BUILD IMMEDIATE: se llena al crearse)
CREATE MATERIALIZED VIEW mv_ocupacion_mensual
  BUILD IMMEDIATE
  REFRESH COMPLETE ON DEMAND
AS
WITH meses AS (
  -- calendario de meses: desde el primer check-in hasta el mes de la ultima noche
  SELECT ADD_MONTHS(m.primero, LEVEL - 1) AS mes_inicio
  FROM (SELECT TRUNC(MIN(fecha_checkin_linea), 'MM') AS primero,
               TRUNC(MAX(fecha_checkout_linea) - 1, 'MM') AS ultimo
        FROM reserva_habitacion) m
  CONNECT BY LEVEL <= MONTHS_BETWEEN(m.ultimo, m.primero) + 1
),
capacidad AS (
  SELECT id_alojamiento, COUNT(*) AS habitaciones
  FROM habitacion
  GROUP BY id_alojamiento
),
ocupacion AS (
  -- cada linea aporta a cada mes que toca solo las noches que caen en ese mes
  SELECT h.id_alojamiento,
         me.mes_inicio,
         SUM(LEAST(rh.fecha_checkout_linea, ADD_MONTHS(me.mes_inicio, 1))
             - GREATEST(rh.fecha_checkin_linea, me.mes_inicio)) AS noches_ocupadas,
         COUNT(DISTINCT rh.id_reserva) AS reservas
  FROM reserva_habitacion rh
  JOIN reserva r ON r.id_reserva = rh.id_reserva
  JOIN habitacion h ON h.id_habitacion = rh.id_habitacion
  JOIN meses me ON rh.fecha_checkin_linea < ADD_MONTHS(me.mes_inicio, 1)
               AND rh.fecha_checkout_linea > me.mes_inicio
  WHERE r.estado IN ('confirmada', 'completada')
  GROUP BY h.id_alojamiento, me.mes_inicio
)
SELECT EXTRACT(YEAR FROM me.mes_inicio) AS anio,
       EXTRACT(MONTH FROM me.mes_inicio) AS mes,
       me.mes_inicio,
       a.id_alojamiento,
       a.id_municipio,
       a.id_tipo_alojamiento,
       c.habitaciones,
       ADD_MONTHS(me.mes_inicio, 1) - me.mes_inicio AS dias_mes,
       c.habitaciones * (ADD_MONTHS(me.mes_inicio, 1) - me.mes_inicio) AS noches_disponibles,
       NVL(o.noches_ocupadas, 0) AS noches_ocupadas,
       NVL(o.reservas, 0) AS reservas,
       ROUND(100 * NVL(o.noches_ocupadas, 0)
             / (c.habitaciones * (ADD_MONTHS(me.mes_inicio, 1) - me.mes_inicio)), 2) AS pct_ocupacion
FROM alojamiento a
JOIN capacidad c ON c.id_alojamiento = a.id_alojamiento
CROSS JOIN meses me
LEFT JOIN ocupacion o ON o.id_alojamiento = a.id_alojamiento
                     AND o.mes_inicio = me.mes_inicio;

COMMENT ON MATERIALIZED VIEW mv_ocupacion_mensual IS 'Ocupacion mensual precalculada por alojamiento: noches ocupadas vs disponibles. Refresco COMPLETE ON DEMAND, programado cada noche a las 2:00 a.m.';

-- C.3 Indices sobre la vista: busqueda por alojamiento y mes, y reportes por municipio
CREATE UNIQUE INDEX mv_ocupacion_uq ON mv_ocupacion_mensual (id_alojamiento, mes_inicio);
CREATE INDEX mv_ocupacion_municipio_ix ON mv_ocupacion_mensual (id_municipio, anio, mes);

-- C.4 Que guarda Oracle de la vista materializada
SELECT mview_name, refresh_mode, refresh_method, build_mode, last_refresh_date
FROM user_mviews
WHERE mview_name = 'MV_OCUPACION_MENSUAL';


-- =================================================================================
-- PARTE D - POLITICA DE REFRESCO
-- ---------------------------------------------------------------------------------
-- Politica elegida: COMPLETE + ON DEMAND, refrescada por un job todas las noches a
-- las 2:00 a.m., y a mano (DBMS_MVIEW.REFRESH) despues de una carga masiva.
--
-- 1. Por que COMPLETE y no FAST:
--    El refresco FAST (incremental) exige logs de vista materializada en cada tabla
--    base y una consulta sencilla. Esta vista no cumple esas condiciones: usa
--    CONNECT BY para el calendario de meses, un CROSS JOIN con LEFT JOIN para
--    incluir los meses sin ocupacion, COUNT(DISTINCT) y una division. Ademas, una
--    sola reserva nueva puede cambiar varios meses (si cruza de un mes a otro), y
--    una habitacion nueva cambia el denominador de todos los meses del alojamiento.
--    Recalcular todo es lo correcto, y con el volumen del proyecto toma segundos.
--
-- 2. Por que ON DEMAND y no ON COMMIT:
--    ON COMMIT recalcularia la vista dentro de CADA transaccion que toque las tablas
--    base: cada sp_crear_reserva o cada cambio de estado esperaria a que se
--    recalcule la ocupacion de todos los alojamientos y meses. Eso pone el costo de
--    un reporte de gerencia sobre las operaciones de recepcion, que deben ser rapidas.
--
-- 3. Por que una vez al dia, en la madrugada:
--    La ocupacion mensual es un reporte de gerencia para ver tendencias por mes y
--    por municipio, no un dato para decidir si una habitacion esta libre (eso lo
--    valida sp_crear_reserva contra las tablas). Que el reporte tenga hasta un dia
--    de atraso no cambia ninguna decision. A las 2:00 a.m. casi nadie usa la
--    plataforma.
--
-- 4. atomic_refresh => FALSE:
--    El refresco completo trunca la vista y la vuelve a llenar, en lugar de borrar
--    fila por fila dentro de una transaccion. Es mas rapido. A cambio, la vista
--    queda vacia unos segundos mientras se refresca, lo que no importa a las 2 a.m.
-- =================================================================================

-- D.1 Borrar el job si existe, para poder re-ejecutar el script
BEGIN
  DBMS_SCHEDULER.DROP_JOB('JOB_REFRESCO_MV_OCUPACION', force => TRUE);
EXCEPTION WHEN OTHERS THEN
  IF SQLCODE != -27475 THEN RAISE; END IF; -- -27475: el job no existia
END;
/

-- D.2 Job de refresco diario (requiere GRANT CREATE JOB, PARTE A)
BEGIN
  DBMS_SCHEDULER.CREATE_JOB(
    job_name => 'JOB_REFRESCO_MV_OCUPACION',
    job_type => 'PLSQL_BLOCK',
    job_action => 'BEGIN DBMS_MVIEW.REFRESH(''MV_OCUPACION_MENSUAL'', ''C'', atomic_refresh => FALSE); END;',
    start_date => SYSTIMESTAMP,
    repeat_interval => 'FREQ=DAILY;BYHOUR=2;BYMINUTE=0;BYSECOND=0',
    enabled => TRUE,
    comments => 'Refresco completo diario de la ocupacion mensual (2:00 a.m.)');
  DBMS_OUTPUT.PUT_LINE('Job JOB_REFRESCO_MV_OCUPACION creado: todos los dias a las 2:00 a.m.');
EXCEPTION WHEN OTHERS THEN
  IF SQLCODE IN (-27486, -1031) THEN -- privilegios insuficientes
    DBMS_OUTPUT.PUT_LINE('No se creo el job: falta GRANT CREATE JOB (PARTE A). ' ||
                         'La vista se puede refrescar a mano con DBMS_MVIEW.REFRESH.');
  ELSE
    RAISE;
  END IF;
END;
/

-- D.3 Refresco manual (el mismo que hace el job), para usar despues de una carga masiva:
-- EXEC DBMS_MVIEW.REFRESH('MV_OCUPACION_MENSUAL', 'C', atomic_refresh => FALSE);
