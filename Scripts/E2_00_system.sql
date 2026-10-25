-- =================================================================================
-- TurismoUQ - Entrega 2 - SCRIPT 0: preparacion en SYSTEM
-- Se ejecuta UNA vez, conectada como SYSTEM, ANTES del DDL.
-- Cambiar el nombre del usuario en la linea DEFINE si no se llama PROYECTO.
-- =================================================================================SET DEFINE ON
SET SERVEROUTPUT ON
DEFINE usuario = PROYECTO

ALTER SESSION SET CONTAINER = FREEPDB1;

-- 1. Privilegios que usan E2_01 a E2_03
GRANT CREATE SESSION, CREATE TABLE, CREATE SEQUENCE, CREATE TRIGGER,
      CREATE VIEW, CREATE PROCEDURE, CREATE MATERIALIZED VIEW, CREATE JOB
   TO &usuario;
ALTER USER &usuario QUOTA UNLIMITED ON users;

-- 2. Tablespace del historico (idempotente: si ya existe, no lo vuelve a crear)
DECLARE
  v_existe NUMBER;
  v_ruta   VARCHAR2(500);
BEGIN
  SELECT COUNT(*) INTO v_existe
  FROM dba_tablespaces WHERE tablespace_name = 'TS_HISTORICO';

  IF v_existe = 0 THEN
    -- Misma carpeta del datafile de USERS, asi no se escribe la ruta a mano
    SELECT SUBSTR(file_name, 1, GREATEST(INSTR(file_name, '\', -1), INSTR(file_name, '/', -1)))
    INTO v_ruta
    FROM dba_data_files
    WHERE tablespace_name = 'USERS' AND ROWNUM = 1;

    EXECUTE IMMEDIATE 'CREATE TABLESPACE ts_historico DATAFILE ''' || v_ruta ||
      'ts_historico01.dbf'' SIZE 20M AUTOEXTEND ON NEXT 5M MAXSIZE 100M';
    DBMS_OUTPUT.PUT_LINE('Tablespace TS_HISTORICO creado.');
  ELSE
    DBMS_OUTPUT.PUT_LINE('TS_HISTORICO ya existia: no se toca.');
  END IF;
END;
/

-- 3. Cuota del usuario en el nuevo tablespace
ALTER USER &usuario QUOTA UNLIMITED ON ts_historico;

-- 4. Comprobacion
SELECT tablespace_name, file_name, ROUND(bytes/1024/1024) AS mb
FROM dba_data_files WHERE tablespace_name = 'TS_HISTORICO';