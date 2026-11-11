-- =================================================================================
-- TurismoUQ - Entrega 3 - Entregable 2
-- CONCURRENCIA: PREPARACION DEL EXPERIMENTO CON DOS SESIONES
--   PARTE 1) El problema: por que dos sesiones pueden reservar la misma habitacion
--   PARTE 2) Procedimiento sp_crear_reserva_segura (con SELECT ... FOR UPDATE)
--
-- Este script solo crea el procedimiento. El experimento se hace despues, paso a
-- paso, con los guiones E3_02_SesionA.sql y E3_02_SesionB.sql (uno en cada sesion).
-- El resultado, con capturas, esta en el documento de concurrencia.
--
-- Valentina Gonzalez Diaz
-- Raquel Lopez Aristizabal
-- Valentina Rodriguez Castro
--
-- Orden de ejecucion: DESPUES de E3_01_Transacciones.sql. Ejecutar con F5.
-- =================================================================================
SET DEFINE OFF
WHENEVER SQLERROR CONTINUE
SET SERVEROUTPUT ON

-- =================================================================================
-- PARTE 1 - EL PROBLEMA
-- ---------------------------------------------------------------------------------
-- pkg_turismouq.sp_crear_reserva y el disparador trg_no_solape_reserva validan la
-- disponibilidad con un SELECT COUNT(*) sobre las reservas que ya existen.
--
-- En Oracle nadie ve lo que otra sesion no ha confirmado (aislamiento). Entonces, si
-- dos sesiones piden la misma habitacion casi al tiempo:
--   1. La sesion A valida (0 choques) e inserta su reserva, pero aun no hace COMMIT.
--   2. La sesion B valida: NO ve la reserva de A, cuenta 0 choques e inserta la suya.
--   3. Las dos hacen COMMIT.
-- Resultado: dos reservas activas de la misma habitacion en las mismas fechas.
-- Ninguna sesion espero a la otra, porque cada una inserto filas DISTINTAS: el
-- candado de Oracle es por fila y aqui no hay ninguna fila en comun.
-- =================================================================================

-- =================================================================================
-- PARTE 2 - LA SOLUCION: sp_crear_reserva_segura
-- ---------------------------------------------------------------------------------
-- Antes de validar, se aparta la fila de la HABITACION con SELECT ... FOR UPDATE.
-- Esa fila si es comun a las dos sesiones (como la silla del cine):
--   * La primera sesion que llega toma el candado de la habitacion y sigue.
--   * La segunda se queda esperando en el FOR UPDATE hasta que la primera termine
--     su transaccion (COMMIT o ROLLBACK).
--   * Cuando la segunda por fin entra, su validacion YA ve la reserva confirmada de
--     la primera y falla con ORA-20002 (habitacion no disponible). Si la primera
--     hizo ROLLBACK, la habitacion sigue libre y la segunda reserva sin problema.
--
-- El resto del trabajo (validaciones, calculo del valor e INSERT) lo sigue haciendo
-- pkg_turismouq.sp_crear_reserva: aqui solo se agrega el candado antes de llamarlo.
--
-- No hace COMMIT, igual que sp_crear_reserva: el candado se suelta cuando el que
-- llama termina la transaccion.
-- =================================================================================
CREATE OR REPLACE PROCEDURE sp_crear_reserva_segura (
  p_id_cliente    IN  cliente.id_cliente%TYPE,
  p_id_habitacion IN  habitacion.id_habitacion%TYPE,
  p_checkin       IN  DATE,
  p_checkout      IN  DATE,
  p_num_huespedes IN  NUMBER,
  p_id_reserva    OUT reserva.id_reserva%TYPE
) IS
  v_hab habitacion.id_habitacion%TYPE;
BEGIN
  -- 1. Apartar la habitacion: si otra sesion la tiene apartada, aqui se espera
  BEGIN
    SELECT id_habitacion INTO v_hab
    FROM habitacion
    WHERE id_habitacion = p_id_habitacion
    FOR UPDATE;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20004,
        'La habitacion ' || p_id_habitacion || ' no existe');
  END;

  -- 2. Con la habitacion apartada, validar e insertar como siempre
  pkg_turismouq.sp_crear_reserva(p_id_cliente, p_id_habitacion, p_checkin, p_checkout,
                                 p_num_huespedes, p_id_reserva);
END sp_crear_reserva_segura;
/
SHOW ERRORS PROCEDURE sp_crear_reserva_segura
