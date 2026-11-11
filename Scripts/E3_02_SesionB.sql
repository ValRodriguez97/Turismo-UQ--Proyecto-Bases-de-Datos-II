-- =================================================================================
-- TurismoUQ - Entrega 3 - Entregable 2
-- CONCURRENCIA: GUION DE LA SESION B
--
-- NO se ejecuta con F5. Se ejecuta UN paso a la vez con Ctrl + Enter, en una hoja
-- NO compartida (Ctrl + Shift + N), alternando con E3_02_SesionA.sql en este orden:
--
--   ESCENARIO 1 (antes, sin FOR UPDATE):  A1 A2 | B1 B2 B3 | A3 | B4 | A4 A5
--   ESCENARIO 2 (despues, con FOR UPDATE): A6 A7 | B5 (espera) | A8 | B6 | A9 A10
--   ESCENARIO 3 (NOWAIT y WAIT):           A11 | B7 B8 B9 | A12
-- =================================================================================
SET SERVEROUTPUT ON

-- =================================================================================
-- ESCENARIO 1 - ANTES: sp_crear_reserva sin FOR UPDATE
-- =================================================================================

-- B1: consulta de control. La sesion B NO ve la reserva de A (0 filas), porque A no
--     ha hecho COMMIT
SELECT r.id_reserva, r.id_cliente, r.estado, rh.id_habitacion,
       rh.fecha_checkin_linea, rh.fecha_checkout_linea
FROM reserva r
JOIN reserva_habitacion rh ON rh.id_reserva = r.id_reserva
WHERE r.fecha_reserva = TRUNC(SYSDATE)
  AND r.checkin = DATE '2026-12-01' AND r.checkout = DATE '2026-12-04'
  AND r.id_cliente IN (1, 2)
ORDER BY r.id_reserva;

-- B2: la sesion B reserva (cliente 2) la misma habitacion y las mismas fechas.
--     NO espera y NO falla: encuentra la misma habitacion "libre" que A
DECLARE
  v_hab NUMBER;
  v_id  reserva.id_reserva%TYPE;
BEGIN
  SELECT MIN(h.id_habitacion) INTO v_hab
  FROM habitacion h
  WHERE NOT EXISTS (SELECT 1 FROM reserva_habitacion rh
                      JOIN reserva r ON r.id_reserva = rh.id_reserva
                     WHERE rh.id_habitacion = h.id_habitacion
                       AND r.estado <> 'cancelada'
                       AND rh.fecha_checkin_linea  < DATE '2026-12-04'
                       AND rh.fecha_checkout_linea > DATE '2026-12-01');

  pkg_turismouq.sp_crear_reserva(2, v_hab, DATE '2026-12-01', DATE '2026-12-04', 1, v_id);
  DBMS_OUTPUT.PUT_LINE('SESION B: habitacion ' || v_hab || ', reserva ' || v_id);
END;
/

-- B3: consulta de control. La sesion B solo ve SU reserva (1 fila)
SELECT r.id_reserva, r.id_cliente, r.estado, rh.id_habitacion,
       rh.fecha_checkin_linea, rh.fecha_checkout_linea
FROM reserva r
JOIN reserva_habitacion rh ON rh.id_reserva = r.id_reserva
WHERE r.fecha_reserva = TRUNC(SYSDATE)
  AND r.checkin = DATE '2026-12-01' AND r.checkout = DATE '2026-12-04'
  AND r.id_cliente IN (1, 2)
ORDER BY r.id_reserva;

-- >>> Pasar a la sesion A: A3

-- B4: la sesion B tambien confirma
COMMIT;

-- >>> Pasar a la sesion A: A4, A5

-- =================================================================================
-- ESCENARIO 2 - DESPUES: sp_crear_reserva_segura con SELECT ... FOR UPDATE
-- =================================================================================

-- B5: la sesion B intenta reservar la misma habitacion con el procedimiento seguro.
--     Se queda ESPERANDO en el FOR UPDATE: la sesion A tiene apartada la habitacion.
--     (Tomar la captura mientras espera.) Cuando A hace COMMIT (A8), B se libera y
--     recibe ORA-20002: Habitacion no disponible.
DECLARE
  v_hab NUMBER;
  v_id  reserva.id_reserva%TYPE;
BEGIN
  SELECT MIN(h.id_habitacion) INTO v_hab
  FROM habitacion h
  WHERE NOT EXISTS (SELECT 1 FROM reserva_habitacion rh
                      JOIN reserva r ON r.id_reserva = rh.id_reserva
                     WHERE rh.id_habitacion = h.id_habitacion
                       AND r.estado <> 'cancelada'
                       AND rh.fecha_checkin_linea  < DATE '2026-12-04'
                       AND rh.fecha_checkout_linea > DATE '2026-12-01');

  sp_crear_reserva_segura(2, v_hab, DATE '2026-12-01', DATE '2026-12-04', 1, v_id);
  DBMS_OUTPUT.PUT_LINE('SESION B: habitacion ' || v_hab || ', reserva ' || v_id);
END;
/

-- >>> Pasar a la sesion A: A8 (COMMIT). Volver aqui a ver el error de B5

-- B6: la sesion B termina su transaccion: suelta el candado que recibio al liberarse
ROLLBACK;

-- >>> Pasar a la sesion A: A9, A10

-- =================================================================================
-- ESCENARIO 3 - NOWAIT Y WAIT: decidir cuanto esperar
-- =================================================================================

-- B7: NOWAIT pregunta si la habitacion esta libre y, si no, se va: ORA-00054 de inmediato
SELECT id_habitacion, numero_habitacion, capacidad_max
FROM habitacion
WHERE id_habitacion = 1
FOR UPDATE NOWAIT;

-- B8: WAIT 5 espera 5 segundos y despues se rinde: ORA-30006 (en Oracle 23 Free el
--     mismo caso se informa como ORA-00054, pero a los 5 segundos y no de inmediato)
SELECT id_habitacion, numero_habitacion, capacidad_max
FROM habitacion
WHERE id_habitacion = 1
FOR UPDATE WAIT 5;

-- B9: un SELECT normal NO espera: los que leen no esperan
SELECT id_habitacion, numero_habitacion, capacidad_max
FROM habitacion
WHERE id_habitacion = 1;

-- >>> Pasar a la sesion A: A12
