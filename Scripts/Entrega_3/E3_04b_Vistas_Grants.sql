-- =================================================================================
-- TurismoUQ - Entrega 3 - Entregable 4 (seguridad) - ARCHIVO B de 4
-- E3_04b: VISTAS POR ROL Y PRIVILEGIOS (GRANT)
--
-- Valentina Gonzalez Diaz
-- Raquel Lopez Aristizabal
-- Valentina Rodriguez Castro
--
-- SE EJECUTA CONECTADO COMO PROYECTO (dueño de las tablas, el paquete y las vistas),
-- DESPUES de E3_04a (los roles ya deben existir). Correrlo completo con F5.
-- Solo el dueño puede crear las vistas y otorgar permisos sobre ellas.
-- =================================================================================
SET DEFINE OFF
SET SERVEROUTPUT ON
WHENEVER SQLERROR CONTINUE

-- =================================================================================
-- 1. VISTA BASE: QUIEN ESTA CONECTADO
-- Una fila si el usuario de Oracle corresponde a un usuario ACTIVO de la plataforma.
-- Conversion de login: 'enc.tipo1' <-> ENC_TIPO1 (igual que en E3_04a).
-- =================================================================================
CREATE OR REPLACE VIEW v_sesion_usuario AS
SELECT id_usuario, login, id_rol, id_alojamiento
FROM usuario_sistema
WHERE estado = 'activo'
  AND UPPER(REPLACE(login, '.', '_')) = SYS_CONTEXT('USERENV', 'SESSION_USER');

COMMENT ON TABLE v_sesion_usuario IS 'Usuario de plataforma activo que corresponde al usuario de Oracle conectado; base de las vistas por alojamiento.';

-- =================================================================================
-- 2. VISTAS DE RECEPCION (solo lectura, filtradas por el alojamiento del usuario)
-- =================================================================================

-- 2.1 Habitaciones del alojamiento
CREATE OR REPLACE VIEW v_recepcion_habitaciones AS
SELECT h.id_habitacion, h.numero_habitacion, h.tipo, h.capacidad_max, h.descripcion
FROM habitacion h
WHERE h.id_alojamiento = (SELECT id_alojamiento FROM v_sesion_usuario);

-- 2.2 Habitaciones con su ocupacion actual (para saber que esta libre hoy)
--     Cuenta como ocupada una linea de reserva ACTIVA que cubre la noche de hoy.
CREATE OR REPLACE VIEW v_recepcion_disponibilidad AS
SELECT h.id_habitacion, h.numero_habitacion, h.tipo, h.capacidad_max,
       CASE WHEN EXISTS (SELECT 1
                  FROM reserva_habitacion rh
                  JOIN reserva r ON r.id_reserva = rh.id_reserva
                  WHERE rh.id_habitacion = h.id_habitacion
                        AND r.estado IN ('pendiente','confirmada','completada')
                        AND TRUNC(SYSDATE) >= rh.fecha_checkin_linea
                        AND TRUNC(SYSDATE) <  rh.fecha_checkout_linea)
            THEN 'OCUPADA' ELSE 'LIBRE' END AS estado_hoy
FROM habitacion h
WHERE h.id_alojamiento = (SELECT id_alojamiento FROM v_sesion_usuario);

-- 2.3 Reservas (una fila por linea) del alojamiento, con el nombre del cliente
CREATE OR REPLACE VIEW v_recepcion_reservas AS
SELECT r.id_reserva, r.estado, r.fecha_reserva, r.checkin, r.checkout,
       c.id_cliente, c.nombre AS cliente,
       h.numero_habitacion, rh.fecha_checkin_linea, rh.fecha_checkout_linea,
       rh.num_huespedes, rh.valor_calculado
FROM reserva r
JOIN cliente c ON c.id_cliente = r.id_cliente
JOIN reserva_habitacion rh ON rh.id_reserva = r.id_reserva
JOIN habitacion h ON h.id_habitacion = rh.id_habitacion
WHERE h.id_alojamiento = (SELECT id_alojamiento FROM v_sesion_usuario);

-- 2.4 Pagos de las reservas del alojamiento
CREATE OR REPLACE VIEW v_recepcion_pagos AS
SELECT p.id_pago, p.id_reserva, p.fecha_pago, p.monto, p.metodo_pago, p.estado_pago
FROM pago p
WHERE p.id_reserva IN (SELECT rh.id_reserva
                  FROM reserva_habitacion rh
                  JOIN habitacion h ON h.id_habitacion = rh.id_habitacion
                  WHERE h.id_alojamiento = (SELECT id_alojamiento FROM v_sesion_usuario));

-- 2.5 Servicios contratados en las reservas del alojamiento
CREATE OR REPLACE VIEW v_recepcion_servicios AS
SELECT rs.id_reserva, s.nombre AS servicio, rs.cantidad, rs.precio_unitario,
       rs.cantidad * rs.precio_unitario AS subtotal, rs.fecha_consumo
FROM reserva_servicio rs
JOIN servicio s ON s.id_servicio = rs.id_servicio
WHERE s.id_alojamiento = (SELECT id_alojamiento FROM v_sesion_usuario);

-- 2.6 Clientes que se han hospedado (o reservado) en el alojamiento.
--     Vista de UNA tabla (actualizable): recepcion corrige telefono y correo.
CREATE OR REPLACE VIEW v_recepcion_clientes AS
SELECT c.id_cliente, c.cedula, c.nombre, c.correo, c.telefono
FROM cliente c
WHERE c.id_cliente IN (SELECT r.id_cliente
                  FROM reserva r
                  JOIN reserva_habitacion rh ON rh.id_reserva = r.id_reserva
                  JOIN habitacion h ON h.id_habitacion = rh.id_habitacion
                  WHERE h.id_alojamiento = (SELECT id_alojamiento FROM v_sesion_usuario))
WITH CHECK OPTION;

-- =================================================================================
-- 3. VISTAS DEL ADMINISTRADOR DE ALOJAMIENTO (filtradas por SU alojamiento)
-- Las de una sola tabla llevan WITH CHECK OPTION: no se puede insertar ni mover una
-- fila hacia otro alojamiento.
-- =================================================================================

-- 3.1 Habitaciones propias (SELECT, INSERT, UPDATE)
CREATE OR REPLACE VIEW v_admin_habitaciones AS
SELECT id_habitacion, id_alojamiento, numero_habitacion, capacidad_max, tipo, descripcion
FROM habitacion
WHERE id_alojamiento = (SELECT id_alojamiento FROM v_sesion_usuario)
WITH CHECK OPTION;

-- 3.2 Tarifas de sus habitaciones (SELECT y UPDATE de precio; el UPDATE dispara
--     trg_auditoria_tarifa)
CREATE OR REPLACE VIEW v_admin_tarifas AS
SELECT id_tarifa, id_habitacion, id_temporada, precio_noche, fecha_actualizacion
FROM tarifa
WHERE id_habitacion IN (SELECT id_habitacion FROM habitacion
                         WHERE id_alojamiento = (SELECT id_alojamiento FROM v_sesion_usuario))
WITH CHECK OPTION;

-- 3.3 Servicios propios (SELECT, INSERT, UPDATE, DELETE)
CREATE OR REPLACE VIEW v_admin_servicios AS
SELECT id_servicio, id_alojamiento, nombre, descripcion, precio
FROM servicio
WHERE id_alojamiento = (SELECT id_alojamiento FROM v_sesion_usuario)
WITH CHECK OPTION;

-- 3.4 Datos del propio alojamiento (puede actualizar telefono y correo)
CREATE OR REPLACE VIEW v_admin_alojamiento AS
SELECT id_alojamiento, nombre, direccion, calificacion_estrellas, telefono, email
FROM alojamiento
WHERE id_alojamiento = (SELECT id_alojamiento FROM v_sesion_usuario)
WITH CHECK OPTION;

-- 3.5 Reservas del alojamiento (solo lectura)
CREATE OR REPLACE VIEW v_admin_reservas AS
SELECT r.id_reserva, r.estado, r.fecha_reserva, r.checkin, r.checkout,
       r.id_cliente, h.numero_habitacion, rh.fecha_checkin_linea,
       rh.fecha_checkout_linea, rh.num_huespedes, rh.valor_calculado
FROM reserva r
JOIN reserva_habitacion rh ON rh.id_reserva = r.id_reserva
JOIN habitacion h ON h.id_habitacion = rh.id_habitacion
WHERE h.id_alojamiento = (SELECT id_alojamiento FROM v_sesion_usuario);

-- 3.6 Pagos del alojamiento (solo lectura)
CREATE OR REPLACE VIEW v_admin_pagos AS
SELECT p.id_pago, p.id_reserva, p.fecha_pago, p.monto, p.metodo_pago, p.estado_pago
FROM pago p
WHERE p.id_reserva IN (SELECT rh.id_reserva
                  FROM reserva_habitacion rh
                  JOIN habitacion h ON h.id_habitacion = rh.id_habitacion
                  WHERE h.id_alojamiento = (SELECT id_alojamiento FROM v_sesion_usuario));

-- 3.7 Resenas del alojamiento (solo lectura)
CREATE OR REPLACE VIEW v_admin_resenas AS
SELECT id_resena, id_reserva, calificacion, comentario, fecha_resena
FROM resena
WHERE id_alojamiento = (SELECT id_alojamiento FROM v_sesion_usuario);

-- =================================================================================
-- 4. VISTAS DEL GERENTE (reportes globales, sin datos personales)
-- =================================================================================

-- 4.1 Ingresos por alojamiento (reservas confirmadas y completadas)
CREATE OR REPLACE VIEW v_gerente_ingresos AS
SELECT m.nombre AS municipio, ta.nombre AS tipo_alojamiento, a.nombre AS alojamiento,
       COUNT(DISTINCT r.id_reserva) AS reservas,
       SUM(rh.fecha_checkout_linea - rh.fecha_checkin_linea) AS noches_vendidas,
       SUM(rh.valor_calculado) AS ingreso_estadias
FROM reserva_habitacion rh
JOIN reserva r ON r.id_reserva = rh.id_reserva
JOIN habitacion h ON h.id_habitacion = rh.id_habitacion
JOIN alojamiento a ON a.id_alojamiento = h.id_alojamiento
JOIN municipio m ON m.id_municipio = a.id_municipio
JOIN tipo_alojamiento ta ON ta.id_tipo_alojamiento = a.id_tipo_alojamiento
WHERE r.estado IN ('confirmada','completada')
GROUP BY m.nombre, ta.nombre, a.nombre;

-- 4.2 Ocupacion mensual (sale de la vista materializada)
CREATE OR REPLACE VIEW v_gerente_ocupacion AS
SELECT mu.nombre AS municipio, a.nombre AS alojamiento, v.anio, v.mes,
       v.noches_disponibles, v.noches_ocupadas, v.pct_ocupacion
FROM mv_ocupacion_mensual v
JOIN alojamiento a ON a.id_alojamiento = v.id_alojamiento
JOIN municipio mu ON mu.id_municipio = v.id_municipio;

-- 4.3 Calificacion de cada alojamiento segun sus resenas
CREATE OR REPLACE VIEW v_gerente_calificaciones AS
SELECT m.nombre AS municipio, a.nombre AS alojamiento,
       COUNT(rs.id_resena) AS resenas,
       ROUND(AVG(rs.calificacion), 2) AS promedio
FROM alojamiento a
JOIN municipio m ON m.id_municipio = a.id_municipio
LEFT JOIN resena rs ON rs.id_alojamiento = a.id_alojamiento
GROUP BY m.nombre, a.nombre;

-- 4.4 Liquidacion mensual (resultado de sp_liquidacion_mensual)
CREATE OR REPLACE VIEW v_gerente_liquidacion AS
SELECT l.anio, l.mes, a.nombre AS alojamiento, l.reservas, l.noches_vendidas,
       l.ingreso_estadias, l.ingreso_servicios, l.total_liquidado
FROM liquidacion_mensual l
JOIN alojamiento a ON a.id_alojamiento = l.id_alojamiento;

-- =================================================================================
-- 5. VISTA DEL AUDITOR: usuarios SIN contrasena
-- =================================================================================
CREATE OR REPLACE VIEW v_auditor_usuarios AS
SELECT u.id_usuario, u.login, u.nombre, u.email, r.nombre AS rol, u.id_alojamiento, u.estado
FROM usuario_sistema u
JOIN rol r ON r.id_rol = u.id_rol;

-- =================================================================================
-- 6. GRANT: ROL_RECEPCION  (solo vistas + ejecutar el paquete)
-- ---------------------------------------------------------------------------------
-- pkg_turismouq se ejecuta con los derechos de PROYECTO (definer), por eso recepcion
-- puede crear reservas con sp_crear_reserva sin tener ningun privilegio sobre las
-- tablas. Las validaciones (fechas, capacidad, solape) siguen aplicando.
-- =================================================================================
GRANT SELECT ON v_recepcion_habitaciones TO rol_recepcion;
GRANT SELECT ON v_recepcion_disponibilidad TO rol_recepcion;
GRANT SELECT ON v_recepcion_reservas TO rol_recepcion;
GRANT SELECT ON v_recepcion_pagos TO rol_recepcion;
GRANT SELECT ON v_recepcion_servicios TO rol_recepcion;
GRANT SELECT ON v_recepcion_clientes TO rol_recepcion;
GRANT UPDATE (correo, telefono) ON v_recepcion_clientes TO rol_recepcion;
GRANT EXECUTE ON pkg_turismouq TO rol_recepcion;

-- =================================================================================
-- 7. GRANT: ROL_ADMIN_ALOJAMIENTO
-- =================================================================================
GRANT SELECT, INSERT, UPDATE ON v_admin_habitaciones TO rol_admin_alojamiento;
GRANT SELECT ON v_admin_tarifas TO rol_admin_alojamiento;
GRANT UPDATE (precio_noche, fecha_actualizacion) ON v_admin_tarifas TO rol_admin_alojamiento;
GRANT SELECT, INSERT, UPDATE, DELETE ON v_admin_servicios TO rol_admin_alojamiento;
GRANT SELECT ON v_admin_alojamiento TO rol_admin_alojamiento;
GRANT UPDATE (telefono, email) ON v_admin_alojamiento TO rol_admin_alojamiento;
GRANT SELECT ON v_admin_reservas TO rol_admin_alojamiento;
GRANT SELECT ON v_admin_pagos TO rol_admin_alojamiento;
GRANT SELECT ON v_admin_resenas TO rol_admin_alojamiento;

-- =================================================================================
-- 8. GRANT: ROL_GERENTE (solo lectura de reportes)
-- =================================================================================
GRANT SELECT ON v_gerente_ingresos TO rol_gerente;
GRANT SELECT ON v_gerente_ocupacion TO rol_gerente;
GRANT SELECT ON v_gerente_calificaciones TO rol_gerente;
GRANT SELECT ON v_gerente_liquidacion TO rol_gerente;

-- =================================================================================
-- 9. GRANT: ROL_AUDITOR (solo lectura, sin USUARIO_SISTEMA)
-- USUARIO_SISTEMA guarda la contrasena, asi que el auditor la ve por la vista
-- V_AUDITOR_USUARIOS. Los GRANT se generan recorriendo las tablas del esquema.
-- =================================================================================
BEGIN
  FOR t IN (SELECT table_name FROM user_tables
             WHERE table_name <> 'USUARIO_SISTEMA'
               AND table_name NOT LIKE 'MV_%'     -- la vista materializada se otorga abajo
               AND table_name NOT LIKE 'DR$%') LOOP
    EXECUTE IMMEDIATE 'GRANT SELECT ON ' || t.table_name || ' TO rol_auditor';
  END LOOP;
END;
/
GRANT SELECT ON mv_ocupacion_mensual TO rol_auditor;
GRANT SELECT ON v_auditor_usuarios TO rol_auditor;

-- =================================================================================
-- 10. VERIFICACION
-- =================================================================================
COLUMN grantee FORMAT A24
COLUMN table_name FORMAT A30
COLUMN privilege FORMAT A10
COLUMN column_name FORMAT A18

PROMPT === Privilegios sobre objetos por rol (recepcion: NINGUNA tabla) ===
SELECT grantee, table_name, LISTAGG(privilege, ', ') WITHIN GROUP (ORDER BY privilege) AS privilegios
FROM user_tab_privs_made
WHERE grantee IN ('ROL_RECEPCION','ROL_ADMIN_ALOJAMIENTO','ROL_GERENTE')
GROUP BY grantee, table_name
ORDER BY grantee, table_name;

PROMPT === Recepcion: objetos que NO son vistas ni el paquete (debe dar 0 filas) ===
SELECT p.table_name
FROM user_tab_privs_made p
WHERE p.grantee = 'ROL_RECEPCION'
  AND p.table_name NOT IN (SELECT view_name FROM user_views)
  AND p.table_name <> 'PKG_TURISMOUQ';

PROMPT === Auditor: privilegios distintos de SELECT (debe dar 0 filas) ===
SELECT table_name, privilege FROM user_tab_privs_made
WHERE grantee = 'ROL_AUDITOR' AND privilege <> 'SELECT';

PROMPT === Auditor: no tiene acceso a USUARIO_SISTEMA (debe dar 0 filas) ===
SELECT table_name FROM user_tab_privs_made
WHERE grantee = 'ROL_AUDITOR' AND table_name = 'USUARIO_SISTEMA';

SELECT object_name, status FROM user_objects
WHERE object_type = 'VIEW'
  AND (object_name LIKE 'V\_RECEPCION%' ESCAPE '\' OR object_name LIKE 'V\_ADMIN%' ESCAPE '\'
       OR object_name LIKE 'V\_GERENTE%' ESCAPE '\' OR object_name LIKE 'V\_AUDITOR%' ESCAPE '\'
       OR object_name = 'V_SESION_USUARIO')
ORDER BY object_name;

-- =================================================================================
-- FIN DEL ARCHIVO B. Siguiente paso: E3_04c_Pruebas_Seguridad.sql
-- =================================================================================