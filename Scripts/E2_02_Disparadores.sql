-- =================================================================================
-- TurismoUQ - Entrega 2 - Entregable 2
-- DISPARADORES
--   PARTE 1) De SENTENCIA: auditoria de cambios de precio sobre TARIFA
--   PARTE 2) De FILA: no solape de reservas en una misma habitacion
--   PARTE 3) De FILA: reglas de negocio del documento que ninguna restriccion puede validar
--              regla 2 - resenas solo de estadias completadas
--              regla 4 - una reserva pertenence a un solo alojamiento
--              regla 5 - los servicios son del alojamiento donde se hospeda
--              regla 7 - capacidad maxima y fechas de la linea dentro de la reserva
--   PARTE 4) Cobertura de UPDATE para el no solape y la regla 4
--   PARTE 5) Regla 8 - temporadas sin solapamiento
--
-- Codigos de error propios (RAISE_APPLICATION_ERROR):
--  - 20010 solape de habitacion
--  - 20011 dos alojamientos en la reserva
--  - 20012 servicio de otro alojamiento
--  - 20013 capacidad excedida
--  - 20014 linea fuera del rango de la reserva
--  - 20015 resena no valida
--  - 20016 no existe el administrador
--  - 20017 temporadas solapadas

-- Orden de ejecucion: DESPUES de E2_01_PaqueteTurismouq.sql 
-- =================================================================================
SET DEFINE OFF
WHENEVER SQLERROR CONTINUE

-- =================================================================================
-- PARTE 1 - AUDITORIA DE TARIFA (disparador a nivel de SENTENCIA)
-- ---------------------------------------------------------------------------------
-- Requisito: registrar quien, cuando, valor anterior y valor nuevo.
--
-- EL PROBLEMA: un disparador de sentencia se ejecuta UNA vez por sentencia y NO tiene
-- acceso a :OLD ni :NEW (esos solo existen en los disparadores de fila). Entonces no
-- puede ver por si solo el precio anterior.
--
-- LA SOLUCION: se guarda una copia del ultimo precio conocido de cada tarifa en la
-- tabla TARIFA_PRECIO_PREVIO. Cuando termina la sentencia sobre TARIFA, el
-- disparador compara los precios actuales contra esa copia; donde difieren, hay un
-- cambio: inserta una fila en AUDITORIA_TARIFA (precio anterior = copia, precio
-- nuevo = TARIFA) y despues pone la copia al dia.
--
-- QUIEN: AUDITORIA_TARIFA.ID_USUARIO es clave foranea a USUARIO_SISTEMA, que son los
-- usuarios de la plataforma, no los usuarios de Oracle. Se busca en USUARIO_SISTEMA
-- un LOGIN igual al usuario de Oracle conectado; si no existe, se asigna al
-- administrador de la plataforma ('admin.turismo'). El usuario real de Oracle queda
-- SIEMPRE escrito en la columna MOTIVO, de modo que nunca se pierde quien hizo el
-- cambio.
-- =================================================================================

-- 1.1 Copia del ultimo precio conocido de cada tarifa (se crea con los precios actuales)
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE tarifa_precio_previo PURGE';
EXCEPTION WHEN OTHERS THEN
  IF SQLCODE != -942 THEN RAISE; END IF; -- -942: la tabla no existia
END;
/

CREATE TABLE tarifa_precio_previo AS
  SELECT id_tarifa, precio_noche FROM tarifa;

ALTER TABLE tarifa_precio_previo
    ADD CONSTRAINT tarifa_precio_previo_pk PRIMARY KEY (id_tarifa);

COMMENT ON TABLE tarifa_precio_previo IS 'Copia del ultimo precio conocido de cada tarifa; el disparador de sentencia la compara con TARIFA para saber el valor anterior.';

-- 1.2 Secuencia para el identificador de AUDITORIA_TARIFA (arranca despues del mayor id existente)
DECLARE
  v_ini NUMBER;
BEGIN
  SELECT NVL(MAX(id_auditoria),0) + 1 INTO v_ini FROM auditoria_tarifa;
  BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE seq_auditoria_tarifa';
  EXCEPTION WHEN OTHERS THEN
    IF SQLCODE != -2289 THEN RAISE; END IF; -- -2289: la secuencia no existia
  END;
  EXECUTE IMMEDIATE 'CREATE SEQUENCE seq_auditoria_tarifa START WITH ' || v_ini || ' NOCACHE';
END;
/

-- 1.3 Disparador de sentencia (sin FOR EACH ROW)
CREATE OR REPLACE TRIGGER trg_auditoria_tarifa
AFTER INSERT OR UPDATE OR DELETE ON tarifa
DECLARE
  v_usuario NUMBER;
BEGIN
  -- Usuario de la plataforma: el que coincide con el usuario de Oracle, o el administrador
  SELECT NVL(MIN(CASE WHEN login = LOWER(USER) THEN id_usuario END),
             MIN(CASE WHEN login = 'admin.turismo' THEN id_usuario END))
    INTO v_usuario
    FROM usuario_sistema;

  -- ID_USUARIO es NOT NULL
  IF v_usuario IS NULL THEN
    RAISE_APPLICATION_ERROR(-20016,
      'No existe el usuario ''admin.turismo'' en USUARIO_SISTEMA: no se puede auditar el cambio de tarifa.');
  END IF;

  -- (a) Auditar: toda tarifa cuyo precio actual difiere del ultimo precio conocido
  INSERT INTO auditoria_tarifa
    (id_auditoria, id_tarifa, id_usuario, precio_anterior, precio_nuevo, fecha_cambio, motivo)
  SELECT seq_auditoria_tarifa.NEXTVAL,
    t.id_tarifa,
    v_usuario,
    p.precio_noche,
    t.precio_noche,
    SYSDATE,
    'Cambio de precio hecho por el usuario de BD ' || USER
  FROM tarifa t
  JOIN tarifa_precio_previo p ON p.id_tarifa = t.id_tarifa
  WHERE t.precio_noche <> p.precio_noche;

  -- (b) Poner la copia al dia: precios modificados
  UPDATE tarifa_precio_previo p
  SET p.precio_noche = (SELECT t.precio_noche FROM tarifa t WHERE t.id_tarifa = p.id_tarifa)
  WHERE p.precio_noche <> (SELECT t.precio_noche FROM tarifa t WHERE t.id_tarifa = p.id_tarifa);

  -- (c) Tarifas borradas: salen de la copia
  DELETE FROM tarifa_precio_previo
  WHERE id_tarifa NOT IN (SELECT id_tarifa FROM tarifa);

  -- (d) Tarifas nuevas: entran a la copia con su precio inicial (no es un cambio de precio)
  INSERT INTO tarifa_precio_previo (id_tarifa, precio_noche)
  SELECT id_tarifa, precio_noche
  FROM tarifa
  WHERE id_tarifa NOT IN (SELECT id_tarifa FROM tarifa_precio_previo);
END;
/


-- =================================================================================
-- PARTE 2 - NO SOLAPE DE RESERVAS (disparador a nivel de FILA)
-- ---------------------------------------------------------------------------------
-- Regla (seccion 1.3): una habitacion no puede aceptarse en una reserva si ya esta
-- ocupada en ese rango de fechas por otra reserva.
--
-- La habitacion y las fechas estan en RESERVA_HABITACION (la linea) y el estado en
-- RESERVA.
--
-- Criterios:
--   * Bloquean la habitacion las reservas ACTIVAS: pendiente, confirmada y
--     completada. Las canceladas no ocupan nada y no bloquean.
--   * Si la reserva nueva esta cancelada, no hay nada que validar.
--   * Dos rangos se solapan si: nueva.checkin < existente.checkout
--                                Y nueva.checkout > existente.checkin
--
-- LIMITE TECNICO (restriccion de tabla mutante): un disparador de fila no puede leer
-- la tabla que lo disparo mientras se modifica (ORA-04091). La excepcion es el
-- INSERT de una sola fila con VALUES, que es como se registran las lineas de reserva,
-- por eso el disparador es BEFORE INSERT. Un INSERT ... SELECT de varias filas o un
-- UPDATE de fechas sobre esta tabla no pasan por esta validacion.
-- =================================================================================
CREATE OR REPLACE TRIGGER trg_no_solape_reserva
BEFORE INSERT ON reserva_habitacion
FOR EACH ROW
DECLARE
  v_estado reserva.estado%TYPE;
  v_choques NUMBER;
BEGIN
  -- Estado de la reserva a la que pertenece la linea nueva
  BEGIN
    SELECT estado INTO v_estado FROM reserva WHERE id_reserva = :NEW.id_reserva;
  EXCEPTION WHEN NO_DATA_FOUND THEN
    RETURN;
  END;

  -- Una reserva cancelada no ocupa la habitacion
  IF v_estado = 'cancelada' THEN
    RETURN;
  END IF;

  -- Lineas de reservas activas, en la misma habitacion, con noches en comun
  SELECT COUNT(*)
  INTO v_choques
  FROM reserva_habitacion rh
  JOIN reserva r ON r.id_reserva = rh.id_reserva
  WHERE rh.id_habitacion = :NEW.id_habitacion
    AND r.estado IN ('pendiente','confirmada','completada')
    AND :NEW.fecha_checkin_linea  < rh.fecha_checkout_linea
    AND :NEW.fecha_checkout_linea > rh.fecha_checkin_linea;

  IF v_choques > 0 THEN
    RAISE_APPLICATION_ERROR(-20010,
      'La habitacion ' || :NEW.id_habitacion || ' ya esta ocupada entre el ' ||
      TO_CHAR(:NEW.fecha_checkin_linea,'DD/MM/YYYY') || ' y el ' ||
      TO_CHAR(:NEW.fecha_checkout_linea,'DD/MM/YYYY') ||
      ' por otra reserva activa.');
  END IF;
END;
/

-- =================================================================================
-- PARTE 3 - REGLAS DE NEGOCIO ADICIONALES (disparadores a nivel de FILA)
-- ---------------------------------------------------------------------------------
-- Son reglas del documento de diseno que ni CHECK, ni UNIQUE, ni una clave foranea
-- pueden validar porque comparan datos de tablas distintas o de varias filas.
-- Todas son BEFORE: se valida ANTES de guardar y, si falla, la fila no entra.
-- =================================================================================

-- ---------------------------------------------------------------------------------
-- REGLA 4 - Una reserva pertenece a un solo alojamiento
-- Al entrar una linea nueva se compara el alojamiento de su habitacion con el de las 
-- lineas y los servicios que la reserva ya tiene.
-- ---------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_reserva_un_alojamiento
BEFORE INSERT ON reserva_habitacion
FOR EACH ROW
DECLARE
  v_aloj_nueva habitacion.id_alojamiento%TYPE;
  v_otros NUMBER;
  v_servicios NUMBER;
BEGIN
  BEGIN
    SELECT id_alojamiento INTO v_aloj_nueva
    FROM habitacion WHERE id_habitacion = :NEW.id_habitacion;
  EXCEPTION WHEN NO_DATA_FOUND THEN
    RETURN; 
  END;

  -- Lineas que la reserva ya tiene en un alojamiento distinto
  SELECT COUNT(*)
  INTO v_otros
  FROM reserva_habitacion rh
  JOIN habitacion h ON h.id_habitacion = rh.id_habitacion
  WHERE rh.id_reserva = :NEW.id_reserva
     AND h.id_alojamiento <> v_aloj_nueva;

  IF v_otros > 0 THEN
    RAISE_APPLICATION_ERROR(-20011,
      'La reserva ' || :NEW.id_reserva || ' ya tiene habitaciones de otro alojamiento; ' ||
      'la habitacion ' || :NEW.id_habitacion || ' es del alojamiento ' || v_aloj_nueva ||
      '. Una reserva solo puede tener habitaciones de un alojamiento.');
  END IF;

  -- Servicios ya contratados en la reserva que son de un alojamiento distinto
  SELECT COUNT(*)
  INTO v_servicios
  FROM reserva_servicio rs
  JOIN servicio s ON s.id_servicio = rs.id_servicio
  WHERE rs.id_reserva = :NEW.id_reserva
    AND s.id_alojamiento <> v_aloj_nueva;

  IF v_servicios > 0 THEN
    RAISE_APPLICATION_ERROR(-20011,
      'La reserva ' || :NEW.id_reserva || ' ya tiene servicios de otro alojamiento; ' ||
      'la habitacion ' || :NEW.id_habitacion || ' es del alojamiento ' || v_aloj_nueva || '.');
  END IF;
END;
/

-- ---------------------------------------------------------------------------------
-- REGLA 5 - Servicios del alojamiento donde se hospeda
-- Se compara el alojamiento del servicio con el de cada habitacion de la reserva. Lee
-- SERVICIO y RESERVA_HABITACION.
-- ---------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_servicio_del_alojamiento
BEFORE INSERT OR UPDATE OF id_reserva, id_servicio ON reserva_servicio
FOR EACH ROW
DECLARE
  v_aloj_servicio servicio.id_alojamiento%TYPE;
  v_ajenas NUMBER;
BEGIN
  BEGIN
    SELECT id_alojamiento INTO v_aloj_servicio
      FROM servicio WHERE id_servicio = :NEW.id_servicio;
  EXCEPTION WHEN NO_DATA_FOUND THEN
    RETURN; 
  END;

  -- Habitaciones de la reserva que son de un alojamiento distinto al del servicio
  SELECT COUNT(*)
  INTO v_ajenas
  FROM reserva_habitacion rh
  JOIN habitacion h ON h.id_habitacion = rh.id_habitacion
  WHERE rh.id_reserva = :NEW.id_reserva
    AND h.id_alojamiento <> v_aloj_servicio;

  IF v_ajenas > 0 THEN
    RAISE_APPLICATION_ERROR(-20012,
      'El servicio ' || :NEW.id_servicio || ' es del alojamiento ' || v_aloj_servicio ||
      ' y la reserva ' || :NEW.id_reserva || ' se hospeda en otro alojamiento.');
  END IF;
END;
/

-- ---------------------------------------------------------------------------------
-- REGLA 7 - Capacidad maxima y fechas de la linea
-- Lee HABITACION y RESERVA
-- ---------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_linea_capacidad_fechas
BEFORE INSERT OR UPDATE ON reserva_habitacion
FOR EACH ROW
DECLARE
  v_capacidad habitacion.capacidad_max%TYPE;
  v_checkin reserva.checkin%TYPE;
  v_checkout reserva.checkout%TYPE;
BEGIN
  BEGIN
    SELECT capacidad_max INTO v_capacidad
      FROM habitacion WHERE id_habitacion = :NEW.id_habitacion;
    SELECT checkin, checkout INTO v_checkin, v_checkout
      FROM reserva WHERE id_reserva = :NEW.id_reserva;
  EXCEPTION WHEN NO_DATA_FOUND THEN
    RETURN; 
  END;

  IF :NEW.num_huespedes > v_capacidad THEN
    RAISE_APPLICATION_ERROR(-20013,
      'Capacidad excedida: la habitacion ' || :NEW.id_habitacion || ' admite maximo ' ||
      v_capacidad || ' huespedes y la linea trae ' || :NEW.num_huespedes || '.');
  END IF;

  IF :NEW.fecha_checkin_linea < v_checkin OR :NEW.fecha_checkout_linea > v_checkout THEN
    RAISE_APPLICATION_ERROR(-20014,
      'Las fechas de la linea (' || TO_CHAR(:NEW.fecha_checkin_linea,'DD/MM/YYYY') || ' a ' ||
      TO_CHAR(:NEW.fecha_checkout_linea,'DD/MM/YYYY') || ') deben quedar dentro del rango de la reserva (' ||
      TO_CHAR(v_checkin,'DD/MM/YYYY') || ' a ' || TO_CHAR(v_checkout,'DD/MM/YYYY') || ').');
  END IF;
END;
/

-- ---------------------------------------------------------------------------------
-- REGLA 2 - Resenas solo de estadias completadas
-- La resena es valida solo si existe una reserva que: sea la que la resena senala,
-- este COMPLETAD, sea del mismo cliente y tenga habitaciones en ese alojamiento.
-- ---------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_resena_completada
BEFORE INSERT OR UPDATE OF id_reserva, id_cliente, id_alojamiento ON resena
FOR EACH ROW
DECLARE
  v_validas NUMBER;
BEGIN
  SELECT COUNT(*)
  INTO v_validas
  FROM reserva r
  JOIN reserva_habitacion rh ON rh.id_reserva = r.id_reserva
  JOIN habitacion h ON h.id_habitacion = rh.id_habitacion
  WHERE r.id_reserva = :NEW.id_reserva
     AND r.id_cliente = :NEW.id_cliente
     AND r.estado = 'completada'
     AND h.id_alojamiento = :NEW.id_alojamiento;

  IF v_validas = 0 THEN
    RAISE_APPLICATION_ERROR(-20015,
      'Resena no valida: la reserva ' || :NEW.id_reserva || ' debe estar completada, ' ||
      'ser del cliente ' || :NEW.id_cliente || ' y tener habitaciones en el alojamiento ' ||
      :NEW.id_alojamiento || '.');
  END IF;
END;
/

-- =================================================================================
-- PARTE 4 - COBERTURA DE UPDATE (disparadores compuestos)
-- ---------------------------------------------------------------------------------
-- Un disparador de fila no puede leer su propia tabla (ORA-04091). La solución es crear 
-- un disparador compuesto: la seccion BEFORE EACH ROW solo anota que lineas cambiaron, y
-- la seccion AFTER STATEMENT, donde la tabla ya no esta mutando, las valida.
-- =================================================================================

-- 4.1 UPDATE de una linea: revalida no solape (-20010) y regla 4 (-20011)
CREATE OR REPLACE TRIGGER trg_lineas_validar_upd
AFTER UPDATE OF id_reserva, id_habitacion, fecha_checkin_linea, fecha_checkout_linea
ON reserva_habitacion
DECLARE
  v_choques NUMBER;
  v_mezcla  NUMBER;
BEGIN
  -- No solape: pares de lineas de reservas activas con noches en comun
  SELECT COUNT(*)
  INTO v_choques
  FROM reserva_habitacion a
  JOIN reserva ra ON ra.id_reserva = a.id_reserva
  JOIN reserva_habitacion b ON b.id_habitacion = a.id_habitacion
    AND b.id_reserva_hab > a.id_reserva_hab
  JOIN reserva rb ON rb.id_reserva = b.id_reserva
  WHERE ra.estado <> 'cancelada'
    AND rb.estado <> 'cancelada'
    AND a.fecha_checkin_linea  < b.fecha_checkout_linea
    AND a.fecha_checkout_linea > b.fecha_checkin_linea;

  IF v_choques > 0 THEN
    RAISE_APPLICATION_ERROR(-20010,
      'El cambio deja ' || v_choques || ' par(es) de lineas solapadas en una habitacion.');
  END IF;

  -- Regla 4: reservas con habitaciones o servicios de mas de un alojamiento
  SELECT COUNT(*)
    INTO v_mezcla
    FROM (SELECT rh.id_reserva
        FROM reserva_habitacion rh
        JOIN habitacion h ON h.id_habitacion = rh.id_habitacion
        GROUP BY rh.id_reserva
        HAVING COUNT(DISTINCT h.id_alojamiento) > 1
        UNION
        SELECT rs.id_reserva
        FROM reserva_servicio rs
        JOIN servicio s ON s.id_servicio = rs.id_servicio
        JOIN reserva_habitacion rh ON rh.id_reserva = rs.id_reserva
        JOIN habitacion h ON h.id_habitacion = rh.id_habitacion
        WHERE s.id_alojamiento <> h.id_alojamiento);

  IF v_mezcla > 0 THEN
    RAISE_APPLICATION_ERROR(-20011,
      'El cambio deja ' || v_mezcla || ' reserva(s) con habitaciones o servicios de mas de un alojamiento.');
  END IF;
END;
/

-- 4.2 Reactivar una reserva cancelada: revalida el no solape
CREATE OR REPLACE TRIGGER trg_no_solape_reactivar
AFTER UPDATE OF estado ON reserva
DECLARE
  v_choques NUMBER;
BEGIN
  SELECT COUNT(*)
  INTO v_choques
  FROM reserva_habitacion a
  JOIN reserva ra ON ra.id_reserva = a.id_reserva
  JOIN reserva_habitacion b ON b.id_habitacion = a.id_habitacion
    AND b.id_reserva_hab > a.id_reserva_hab
  JOIN reserva rb ON rb.id_reserva = b.id_reserva
  WHERE ra.estado <> 'cancelada'
    AND rb.estado <> 'cancelada'
    AND a.fecha_checkin_linea < b.fecha_checkout_linea
    AND a.fecha_checkout_linea > b.fecha_checkin_linea;

  IF v_choques > 0 THEN
    RAISE_APPLICATION_ERROR(-20010,
      'El cambio de estado deja ' || v_choques || ' par(es) de reservas activas solapadas.');
  END IF;
END;
/

-- =================================================================================
-- PARTE 5 - REGLA 8: TEMPORADAS SIN SOLAPAMIENTO
-- ---------------------------------------------------------------------------------
-- "Para cada noche reservable existe exactamente una temporada." Si dos temporadas
-- cubrieran la misma noche, esa noche tendria dos precios
-- =================================================================================
CREATE OR REPLACE TRIGGER trg_temporada_sin_solape
AFTER INSERT OR UPDATE ON temporada
DECLARE
  v_solapes NUMBER;
BEGIN
  SELECT COUNT(*)
  INTO v_solapes
  FROM temporada a
  JOIN temporada b ON b.id_temporada > a.id_temporada
    AND a.fecha_inicio <= b.fecha_fin
    AND b.fecha_inicio <= a.fecha_fin;

  IF v_solapes > 0 THEN
    RAISE_APPLICATION_ERROR(-20017,
      'Temporadas solapadas: hay ' || v_solapes ||
      ' par(es) de temporadas que cubren las mismas fechas.');
  END IF;
END;
/
-- Verificacion: los seis disparadores deben aparecer ENABLED
SELECT trigger_name, trigger_type, triggering_event, table_name, status
FROM user_triggers
WHERE trigger_name IN ('TRG_AUDITORIA_TARIFA','TRG_NO_SOLAPE_RESERVA','TRG_RESERVA_UN_ALOJAMIENTO',
                        'TRG_SERVICIO_DEL_ALOJAMIENTO','TRG_LINEA_CAPACIDAD_FECHAS','TRG_RESENA_COMPLETADA',
                        'TRG_LINEAS_VALIDAR_UPD','TRG_NO_SOLAPE_REACTIVAR','TRG_TEMPORADA_SIN_SOLAPE')
ORDER BY trigger_name;

SELECT name, line, text
FROM user_errors
WHERE type = 'TRIGGER'
ORDER BY name, sequence;
