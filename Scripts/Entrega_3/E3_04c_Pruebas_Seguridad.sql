-- =================================================================================
-- TurismoUQ - Entrega 3 - Entregable 4 (seguridad) - ARCHIVO C de 4
-- E3_04c: PRUEBAS DE SEGURIDAD POR ROL Y DEL PERFIL  ->  genera evidencia_seguridad.txt
--
-- Valentina Gonzalez Diaz
-- Raquel Lopez Aristizabal
-- Valentina Rodriguez Castro
--
-- COMO EJECUTARLO: despues de E3_04a y E3_04b.
-- Pide DOS claves (no quedan escritas en el repo):
--   clave = la misma que se dio en E3_04a para los usuarios de la plataforma
--   clave_system = la clave de SYSTEM (solo para la seccion 5)
-- Usuarios que se usan (salen de USUARIO_SISTEMA; '.' del login se vuelve '_'):
--   recep.hotel -> RECEP_HOTEL (ROL_RECEPCION)
--   enc.tipo1 -> ENC_TIPO1 (ROL_ADMIN_ALOJAMIENTO)
--   admin.turismo -> ADMIN_TURISMO (ROL_GERENTE)
--   auditor.ext -> AUDITOR_EXT (ROL_AUDITOR)
-- Todas las pruebas que modifican datos terminan en ROLLBACK: no dejan cambios.
-- =================================================================================
SET DEFINE ON
SET ECHO ON
SET SERVEROUTPUT ON
SET LINESIZE 150
SET PAGESIZE 60
WHENEVER SQLERROR CONTINUE
ACCEPT clave CHAR PROMPT 'Clave de los usuarios de la plataforma: ' HIDE
ACCEPT clave_system CHAR PROMPT 'Clave de SYSTEM: ' HIDE
DEFINE conexion = localhost:1521/FREEPDB1

COLUMN usuario FORMAT A16
COLUMN role FORMAT A24
COLUMN estado_hoy FORMAT A10

SPOOL evidencia_seguridad.txt

-- =================================================================================
-- 1. ROL_RECEPCION (RECEP_HOTEL): solo vistas de su alojamiento + paquete
-- =================================================================================
CONNECT recep_hotel/"&clave"@&conexion
SET SERVEROUTPUT ON

PROMPT === 1a: usuario y rol ===
SELECT SYS_CONTEXT('USERENV','SESSION_USER') AS usuario FROM dual;
SELECT role FROM session_roles WHERE role LIKE 'ROL\_%' ESCAPE '\';

PROMPT === 1b: acceso directo a las tablas -> debe dar ORA-00942 (las 3) ===
SELECT COUNT(*) FROM proyecto.reserva;
SELECT COUNT(*) FROM proyecto.cliente;
SELECT COUNT(*) FROM proyecto.tarifa;

PROMPT === 1c: por la vista solo ve su alojamiento (habitaciones y reservas propias) ===
SELECT COUNT(*) AS habitaciones FROM proyecto.v_recepcion_habitaciones;
SELECT COUNT(*) AS reservas_en_vista, COUNT(DISTINCT id_reserva) AS reservas_distintas
FROM proyecto.v_recepcion_reservas;

PROMPT === 1d: estado de las habitaciones hoy ===
SELECT estado_hoy, COUNT(*) AS habitaciones
FROM proyecto.v_recepcion_disponibilidad GROUP BY estado_hoy;

PROMPT === 1e: no puede modificar reservas ni pagos -> ORA-41900 / ORA-01031 ===
UPDATE proyecto.v_recepcion_reservas SET estado = 'cancelada' WHERE id_reserva = 1;
DELETE FROM proyecto.v_recepcion_pagos;

PROMPT === 1f: SI puede corregir telefono de un cliente de su alojamiento ===
UPDATE proyecto.v_recepcion_clientes SET telefono = '3000000000'
WHERE id_cliente = (SELECT MIN(id_cliente) FROM proyecto.v_recepcion_clientes);
ROLLBACK;

PROMPT === 1g: crea una reserva con el paquete sin tener acceso a las tablas ===
-- Recepcion solo ve SU alojamiento; el bloque prueba ventanas de 2 noches hasta
-- encontrar una libre (las fallidas se deshacen con ROLLBACK TO SAVEPOINT).
VARIABLE nueva_reserva NUMBER
DECLARE
  v_cli NUMBER;
  v_res NUMBER;
  v_ok  BOOLEAN := FALSE;
BEGIN
  SELECT MIN(id_cliente) INTO v_cli FROM proyecto.v_recepcion_clientes;
  <<buscar>>
  FOR h IN (SELECT id_habitacion FROM proyecto.v_recepcion_habitaciones ORDER BY id_habitacion) LOOP
    FOR d IN 0..60 LOOP
      SAVEPOINT intento;
      BEGIN
        proyecto.pkg_turismouq.sp_crear_reserva(v_cli, h.id_habitacion,
              TRUNC(SYSDATE) + 30 + d*3, TRUNC(SYSDATE) + 32 + d*3, 1, v_res);
        DBMS_OUTPUT.PUT_LINE('Reserva creada con el paquete: ' || v_res ||
              ' (habitacion ' || h.id_habitacion || ', entrada en +' || (30 + d*3) || ' dias)');
        v_ok := TRUE;
        :nueva_reserva := v_res;
        EXIT buscar;
      EXCEPTION WHEN OTHERS THEN
        ROLLBACK TO intento;
      END;
    END LOOP;
  END LOOP;
  IF NOT v_ok THEN
    DBMS_OUTPUT.PUT_LINE('No se encontro ventana libre: revisar fechas o tarifas.');
  END IF;
END;
/
PRINT nueva_reserva
SELECT id_reserva, estado, checkin, checkout, numero_habitacion
FROM proyecto.v_recepcion_reservas WHERE id_reserva = :nueva_reserva;
ROLLBACK;

-- =================================================================================
-- 2. ROL_ADMIN_ALOJAMIENTO (ENC_TIPO1): solo SU alojamiento, WITH CHECK OPTION
-- =================================================================================
CONNECT enc_tipo1/"&clave"@&conexion

PROMPT === 2a: usuario y rol ===
SELECT SYS_CONTEXT('USERENV','SESSION_USER') AS usuario FROM dual;
SELECT role FROM session_roles WHERE role LIKE 'ROL\_%' ESCAPE '\';

PROMPT === 2b: solo ve SU alojamiento (debe dar 1 alojamiento distinto) ===
SELECT COUNT(DISTINCT id_alojamiento) AS alojamientos FROM proyecto.v_admin_habitaciones;

PROMPT === 2c: acceso directo a tablas -> ORA-00942 ===
SELECT COUNT(*) FROM proyecto.habitacion;
SELECT COUNT(*) FROM proyecto.cliente;

PROMPT === 2d: cambia el precio de una tarifa propia (dispara trg_auditoria_tarifa) ===
SELECT id_tarifa, precio_noche FROM proyecto.v_admin_tarifas WHERE ROWNUM <= 2;
UPDATE proyecto.v_admin_tarifas SET precio_noche = precio_noche + 5000
WHERE id_tarifa = (SELECT MIN(id_tarifa) FROM proyecto.v_admin_tarifas);
SELECT id_tarifa, precio_noche AS precio_nuevo FROM proyecto.v_admin_tarifas
WHERE id_tarifa = (SELECT MIN(id_tarifa) FROM proyecto.v_admin_tarifas);
ROLLBACK;

PROMPT === 2e: insertar una habitacion en OTRO alojamiento -> ORA-01402 (WITH CHECK OPTION) ===
INSERT INTO proyecto.v_admin_habitaciones
  (id_habitacion, id_alojamiento, numero_habitacion, capacidad_max, tipo, descripcion)
SELECT 999998, id_alojamiento + 1, 'T-99', 2, 'doble', 'prueba otro alojamiento'
FROM proyecto.v_admin_alojamiento;

PROMPT === 2f: insertar una habitacion en SU alojamiento -> debe aceptarse ===
INSERT INTO proyecto.v_admin_habitaciones
  (id_habitacion, id_alojamiento, numero_habitacion, capacidad_max, tipo, descripcion)
SELECT 999999, id_alojamiento, 'T-98', 2, 'doble', 'prueba mi alojamiento'
FROM proyecto.v_admin_alojamiento;
ROLLBACK;

PROMPT === 2g: no puede borrar reservas ni pagos -> ORA-41900 / ORA-01031 ===
DELETE FROM proyecto.v_admin_reservas;
DELETE FROM proyecto.v_admin_pagos;

-- =================================================================================
-- 3. ROL_GERENTE (ADMIN_TURISMO): solo reportes de lectura
-- =================================================================================
CONNECT admin_turismo/"&clave"@&conexion

PROMPT === 3a: usuario y rol ===
SELECT SYS_CONTEXT('USERENV','SESSION_USER') AS usuario FROM dual;
SELECT role FROM session_roles WHERE role LIKE 'ROL\_%' ESCAPE '\';

PROMPT === 3b: reportes globales (top 5 por ingreso) ===
SELECT * FROM (SELECT alojamiento, municipio, ingreso_estadias
            FROM proyecto.v_gerente_ingresos
            ORDER BY ingreso_estadias DESC)
WHERE ROWNUM <= 5;

PROMPT === 3c: calificaciones (mejores 5) ===
SELECT * FROM (SELECT alojamiento, resenas, promedio
            FROM proyecto.v_gerente_calificaciones
            ORDER BY promedio DESC NULLS LAST)
WHERE ROWNUM <= 5;

PROMPT === 3d: sin acceso a tablas ni a datos de clientes -> ORA-00942 ===
SELECT COUNT(*) FROM proyecto.cliente;
SELECT COUNT(*) FROM proyecto.reserva;

PROMPT === 3e: no puede modificar nada -> ORA-41900 / ORA-01031 ===
UPDATE proyecto.v_gerente_ingresos SET reservas = 0;

-- =================================================================================
-- 4. ROL_AUDITOR (AUDITOR_EXT): lee todo, no modifica y no ve contrasenas
-- =================================================================================
CONNECT auditor_ext/"&clave"@&conexion

PROMPT === 4a: usuario y rol ===
SELECT SYS_CONTEXT('USERENV','SESSION_USER') AS usuario FROM dual;
SELECT role FROM session_roles WHERE role LIKE 'ROL\_%' ESCAPE '\';

PROMPT === 4b: lee las tablas ===
SELECT COUNT(*) AS reservas FROM proyecto.reserva;
SELECT COUNT(*) AS pagos FROM proyecto.pago;

PROMPT === 4c: no puede modificar -> ORA-41900 / ORA-01031 (las 3) ===
UPDATE proyecto.tarifa SET precio_noche = 1 WHERE id_tarifa = 1;
DELETE FROM proyecto.pago WHERE id_pago = 1;
INSERT INTO proyecto.municipio (id_municipio, nombre) VALUES (9999, 'PRUEBA');

PROMPT === 4d: no ve contrasenas: tabla -> ORA-00942; vista -> sin columna contrasena ===
SELECT contrasena FROM proyecto.usuario_sistema;
SELECT login, rol, estado FROM proyecto.v_auditor_usuarios;

-- =================================================================================
-- 5. PERFIL (como SYSTEM): limites definidos y a quien se aplican
-- =================================================================================
CONNECT system/"&clave_system"@&conexion

COLUMN resource_name FORMAT A26
COLUMN limit FORMAT A14
COLUMN username FORMAT A16
COLUMN profile FORMAT A18
COLUMN account_status FORMAT A16

PROMPT === 5a: limites del perfil (deben ser 10) ===
SELECT resource_name, limit FROM dba_profiles
WHERE profile = 'PERFIL_TURISMOUQ' AND limit <> 'DEFAULT'
ORDER BY resource_type, resource_name;

PROMPT === 5b: usuarios con el perfil ===
SELECT username, profile, account_status FROM dba_users
WHERE profile = 'PERFIL_TURISMOUQ' ORDER BY username;

PROMPT === 5c: RESOURCE_LIMIT debe estar en TRUE para que apliquen los limites ===
SELECT name, value FROM v$parameter WHERE name = 'resource_limit';

-- =================================================================================
-- La prueba real del perfil (bloqueo por intentos fallidos y limite de sesiones)
-- necesita conexiones que fallan y ventanas abiertas a la vez, asi que se hace paso
-- a paso en E3_04d_Prueba_Perfil.sql.
-- =================================================================================

SPOOL OFF