-- =================================================================================
-- TurismoUQ - Entrega 3 - Entregable 4 (seguridad) - ARCHIVO A de 4
-- E3_04a: PERFIL, ROLES Y USUARIOS DE ORACLE
--
-- Valentina Gonzalez Diaz
-- Raquel Lopez Aristizabal
-- Valentina Rodriguez Castro
--
-- ORDEN DE EJECUCION DEL ENTREGABLE 4:
--   1) E3_04a_Roles_Perfil_Usuarios.sql -> conectado como SYSTEM   (este archivo)
--   2) E3_04b_Vistas_Grants.sql -> conectado como PROYECTO
--   3) E3_04c_Pruebas_Seguridad.sql -> varios usuarios (usa CONNECT); genera evidencia_seguridad.txt
--   4) E3_04d_Prueba_Perfil.sql -> pasos manuales (bloqueo de cuenta y limite de sesiones)
-- Requisitos previos: DDL, carga de datos y scripts E2_00 a E2_03 ya ejecutados.
-- Correrlo completo con F5 (Script Runner). Pide UNA clave por ventana: la clave
-- inicial que tendran los usuarios de la plataforma.
-- =================================================================================

-- =================================================================================
-- PERFIL, ROLES Y USUARIOS (se ejecuta como SYSTEM)
-- =================================================================================
SET DEFINE ON
SET VERIFY OFF
SET SERVEROUTPUT ON
WHENEVER SQLERROR CONTINUE
DEFINE esquema = PROYECTO
ACCEPT clave CHAR PROMPT 'Clave inicial para los usuarios de la plataforma: ' HIDE

ALTER SESSION SET CONTAINER = FREEPDB1;

-- =================================================================================
-- 1. PERFIL CON LIMITES DE SESION
-- ---------------------------------------------------------------------------------
-- Limites de recursos (SESSIONS_PER_USER, CONNECT_TIME, IDLE_TIME, etc.) solo se
-- aplican si RESOURCE_LIMIT = TRUE (ya viene en TRUE por defecto; se fija igual).
--   SESSIONS_PER_USER 2 una persona no abre decenas de conexiones
--   CONNECT_TIME 480 maximo 8 horas por sesion (un turno)
--   IDLE_TIME 15 sesion inactiva 15 min se cierra (recepcion deja el PC solo)
--   CPU_PER_CALL 6000 una sentencia no consume mas de 60 s de CPU
--   LOGICAL_READS_PER_CALL corta consultas descontroladas
--   FAILED_LOGIN_ATTEMPTS 3 3 claves malas bloquean la cuenta
--   PASSWORD_LOCK_TIME 1/24 el bloqueo dura 1 hora
--   PASSWORD_LIFE_TIME 90 la clave se cambia cada 90 dias
--   PASSWORD_REUSE_TIME 180 no se repite una clave en 180 dias
-- =================================================================================
ALTER SYSTEM SET resource_limit = TRUE;

BEGIN
  EXECUTE IMMEDIATE 'DROP PROFILE perfil_turismouq CASCADE';
EXCEPTION WHEN OTHERS THEN
  IF SQLCODE != -2380 THEN RAISE; END IF; -- -2380: el perfil no existia
END;
/

CREATE PROFILE perfil_turismouq LIMIT
  SESSIONS_PER_USER 2
  CONNECT_TIME 480
  IDLE_TIME 15
  CPU_PER_CALL 6000
  LOGICAL_READS_PER_CALL 100000
  FAILED_LOGIN_ATTEMPTS 3
  PASSWORD_LOCK_TIME 1/24
  PASSWORD_LIFE_TIME 90
  PASSWORD_REUSE_TIME 180
  PASSWORD_REUSE_MAX UNLIMITED;

-- =================================================================================
-- 2. ROLES (uno por cada fila de la tabla ROL)
-- ---------------------------------------------------------------------------------
-- Aqui solo se crean y se les da CREATE SESSION. Los permisos sobre objetos del
-- esquema los otorga el dueño (PROYECTO) en E3_04b, porque solo el dueño de las
-- vistas puede darlas.
-- =================================================================================
BEGIN
  FOR r IN (SELECT column_value AS nombre FROM TABLE(sys.odcivarchar2list(
              'ROL_RECEPCION','ROL_ADMIN_ALOJAMIENTO','ROL_GERENTE','ROL_AUDITOR'))) LOOP
    BEGIN
      EXECUTE IMMEDIATE 'DROP ROLE ' || r.nombre;
    EXCEPTION WHEN OTHERS THEN
      IF SQLCODE != -1919 THEN RAISE; END IF; -- -1919: el rol no existia
    END;
    EXECUTE IMMEDIATE 'CREATE ROLE ' || r.nombre;
    EXECUTE IMMEDIATE 'GRANT CREATE SESSION TO ' || r.nombre;
  END LOOP;
END;
/

-- =================================================================================
-- 3. USUARIOS DE ORACLE A PARTIR DE USUARIO_SISTEMA
-- ---------------------------------------------------------------------------------
-- Un login de la plataforma como 'enc.tipo1' no es un nombre valido de usuario Oracle
-- (el punto), asi que el usuario Oracle es el login en mayusculas con '.' -> '_':
--     enc.tipo1 -> ENC_TIPO1 recep.hotel -> RECEP_HOTEL
-- Las vistas de E3_04b hacen la misma conversion para saber quien esta conectado y a
-- que alojamiento pertenece.
--   id_rol 1 -> ROL_RECEPCION  id_rol 3 -> ROL_GERENTE
--   id_rol 2 -> ROL_ADMIN_ALOJAMIENTO id_rol 4 -> ROL_AUDITOR
-- Regla 9: un usuario que no esta 'activo' queda con la cuenta BLOQUEADA.
-- =================================================================================
DECLARE
  v_usr   VARCHAR2(30);
  v_rol   VARCHAR2(30);
  v_n     NUMBER;
BEGIN
  FOR u IN (SELECT login, id_rol, estado FROM &esquema..usuario_sistema ORDER BY id_usuario) LOOP
    v_usr := UPPER(REPLACE(u.login, '.', '_'));
    v_rol := CASE u.id_rol WHEN 1 THEN 'ROL_RECEPCION'
                           WHEN 2 THEN 'ROL_ADMIN_ALOJAMIENTO'
                           WHEN 3 THEN 'ROL_GERENTE'
                           WHEN 4 THEN 'ROL_AUDITOR' END;

    SELECT COUNT(*) INTO v_n FROM dba_users WHERE username = v_usr;
    IF v_n > 0 THEN
      EXECUTE IMMEDIATE 'DROP USER ' || v_usr || ' CASCADE';
    END IF;

    EXECUTE IMMEDIATE 'CREATE USER ' || v_usr || ' IDENTIFIED BY "&clave" ' ||
                      'DEFAULT TABLESPACE users PROFILE perfil_turismouq';
    EXECUTE IMMEDIATE 'GRANT ' || v_rol || ' TO ' || v_usr;
    IF u.estado <> 'activo' THEN
      EXECUTE IMMEDIATE 'ALTER USER ' || v_usr || ' ACCOUNT LOCK';
    END IF;
    DBMS_OUTPUT.PUT_LINE('Usuario ' || RPAD(v_usr, 14) || ' -> ' || v_rol ||
                         CASE WHEN u.estado <> 'activo' THEN ' (BLOQUEADO)' END);
  END LOOP;
END;
/

-- =================================================================================
-- 4. COMPROBACION
-- =================================================================================
COLUMN username FORMAT A16
COLUMN profile FORMAT A18
COLUMN granted_role FORMAT A24
COLUMN account_status FORMAT A12
COLUMN resource_name FORMAT A26
COLUMN limit FORMAT A12

SELECT u.username, u.profile, u.account_status, r.granted_role
FROM dba_users u JOIN dba_role_privs r ON r.grantee = u.username
WHERE r.granted_role IN ('ROL_RECEPCION','ROL_ADMIN_ALOJAMIENTO','ROL_GERENTE','ROL_AUDITOR')
  AND u.profile = 'PERFIL_TURISMOUQ'
ORDER BY r.granted_role, u.username;

SELECT resource_name, limit
FROM dba_profiles WHERE profile = 'PERFIL_TURISMOUQ'
ORDER BY resource_type, resource_name;

-- =================================================================================
-- FIN DEL ARCHIVO A. Siguiente paso: abrir E3_04b_Vistas_Grants.sql 
-- =================================================================================