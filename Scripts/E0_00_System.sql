-- =================================================================================
-- TurismoUQ : Preparación de los permisos en SYSTEM
--
-- Raquel Lopez Aristizabal - Código: 1091884575
-- Valentina Gonzalez Diaz - Código: 1094898396
-- Valentina Rodríguez Castro - Código: 1016833647
--
-- Se ejecuta en una conexión System. Preferiblemente antes del DDL
-- 1) Privilegios de sistema y cuotas
-- 2) Tablespace del historico TS_HISTORICO
-- 3) Permisos de consulta del diccionario
--
-- Cambiar el nombre del usuario en DEFINE
-- =================================================================================

SET DEFINE ON
SET SERVEROUTPUT ON
DEFINE usuario = PROYECTO

ALTER SESSION SET CONTAINER = FREEPDB1;

-- ---------------------------------------------------------------------------------
-- 0. Crear el usuario del proyecto si no existe. Si ya existe, no se toca.
-- ---------------------------------------------------------------------------------
ACCEPT clave_proyecto CHAR PROMPT 'Clave para el usuario &usuario: ' HIDE

DECLARE
  v_n NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_n FROM dba_users WHERE username = UPPER('&usuario');
  IF v_n = 0 THEN
    EXECUTE IMMEDIATE 'CREATE USER &usuario IDENTIFIED BY "&clave_proyecto" DEFAULT TABLESPACE users';
    DBMS_OUTPUT.PUT_LINE('Usuario &usuario creado.');
  ELSE
    DBMS_OUTPUT.PUT_LINE('El usuario &usuario ya existia: no se toca.');
  END IF;
END;
/

-- ---------------------------------------------------------------------------------
-- 1. Privilegios de sistema y cuota (los usan el DDL y E2_01 a E2_03)
-- ---------------------------------------------------------------------------------
GRANT CREATE SESSION, CREATE TABLE, CREATE SEQUENCE, CREATE TRIGGER,
      CREATE VIEW, CREATE PROCEDURE, CREATE MATERIALIZED VIEW, CREATE JOB
   TO &usuario;
ALTER USER &usuario QUOTA UNLIMITED ON users;

-- ---------------------------------------------------------------------------------
-- 2. Tablespace del historico (idempotente: si ya existe, no lo vuelve a crear)
-- ---------------------------------------------------------------------------------
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

-- Cuota del usuario en el nuevo tablespace
ALTER USER &usuario QUOTA UNLIMITED ON ts_historico;

-- ---------------------------------------------------------------------------------
-- 3. Permisos de lectura del diccionario (Entrega 3)
--    * SELECT_CATALOG_ROLE: DBMS_XPLAN.DISPLAY_CURSOR en E3_03_Indices.sql (columna
--      Buffers = lecturas logicas reales).
--    * SELECT sobre V_$SESSION: paso A7b de E3_02_SesionA.sql (ver quien espera a quien).
--      Se da directo sobre el objeto porque un rol no sirve dentro de PL/SQL.
-- ---------------------------------------------------------------------------------
GRANT SELECT_CATALOG_ROLE TO &usuario;

-- ---------------------------------------------------------------------------------
-- 4. Comprobacion
-- ---------------------------------------------------------------------------------
SELECT tablespace_name, file_name, ROUND(bytes/1024/1024) AS mb
FROM dba_data_files WHERE tablespace_name = 'TS_HISTORICO';

SELECT grantee, privilege
FROM dba_sys_privs WHERE grantee = '&usuario' ORDER BY privilege;

SELECT grantee, granted_role
FROM dba_role_privs WHERE grantee = '&usuario';