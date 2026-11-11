-- =================================================================================
-- TurismoUQ - Entrega 3 - Entregable 2
-- CONCURRENCIA: GUION DE LA SESION A
--
-- NO se ejecuta con F5. Se ejecuta UN paso a la vez con Ctrl + Enter (con el cursor
-- dentro de la instruccion), alternando con E3_02_SesionB.sql en este orden:
--
--   ESCENARIO 1 (antes, sin FOR UPDATE):  A1 A2 | B1 B2 B3 | A3 | B4 | A4 A5
--   ESCENARIO 2 (despues, con FOR UPDATE): A6 A7 | B5 (espera) | A7b | A8 | B6 | A9 A10
--   ESCENARIO 3 (NOWAIT y WAIT):           A11 | B7 B8 B9 B10 | A12
--   ESCENARIO 4 (deadlock):                A13 | B11 | A14 (espera) | B12 | A15 | B13
--
-- Antes de empezar:
--   * E3_01_Transacciones.sql ya ejecutado (crea sp_crear_reserva_segura).
--   * Autocommit apagado: Herramientas > Preferencias > Base de datos > Avanzada.
--   * La sesion B se abre con Ctrl + Shift + N (hoja no compartida = otra sesion).
--   * Para el paso A7b, una sola vez, conectado como SYSTEM:
--       ALTER SESSION SET CONTAINER = FREEPDB1;
--       GRANT SELECT ON v_$session TO proyecto;
--   * Para ver los mensajes: Ver > Salida de DBMS y activarla en las dos sesiones.
--
-- LIMPIEZA POR ID: antes de ejecutar A5 y A10, reemplazar los numeros de reserva de esas
-- instrucciones por los que imprimio DBMS_OUTPUT (A1 y B2 para A5; A6 para A10). Asi
-- solo se borra lo que creo el experimento.
--
-- Las dos sesiones piden la misma habitacion para las mismas fechas: 1 al 4 de
-- diciembre de 2026. Cada bloque busca la primera habitacion libre en esas fechas;
-- como la sesion B no ve lo que A no ha confirmado, las dos encuentran la MISMA.
-- =================================================================================
SET SERVEROUTPUT ON

-- =================================================================================
-- ESCENARIO 1 - ANTES: sp_crear_reserva sin FOR UPDATE
-- =================================================================================

-- A1: la sesion A reserva (cliente 1) y NO hace COMMIT
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

  pkg_turismouq.sp_crear_reserva(1, v_hab, DATE '2026-12-01', DATE '2026-12-04', 1, v_id);
  DBMS_OUTPUT.PUT_LINE('SESION A: habitacion ' || v_hab || ', reserva ' || v_id);
END;
/

-- A2: consulta de control. La sesion A ve SU reserva (1 fila)
SELECT r.id_reserva, r.id_cliente, r.estado, rh.id_habitacion,
       rh.fecha_checkin_linea, rh.fecha_checkout_linea
FROM reserva r
JOIN reserva_habitacion rh ON rh.id_reserva = r.id_reserva
WHERE r.fecha_reserva = TRUNC(SYSDATE)
  AND r.checkin = DATE '2026-12-01' AND r.checkout = DATE '2026-12-04'
  AND r.id_cliente IN (1, 2)
ORDER BY r.id_reserva;

-- >>> Pasar a la sesion B: B1, B2, B3

-- A3: la sesion A confirma
COMMIT;

-- >>> Pasar a la sesion B: B4

-- A4: consulta de control. Ahora hay 2 reservas activas de la MISMA habitacion en
--     las MISMAS fechas: la doble reserva
SELECT r.id_reserva, r.id_cliente, r.estado, rh.id_habitacion,
       rh.fecha_checkin_linea, rh.fecha_checkout_linea
FROM reserva r
JOIN reserva_habitacion rh ON rh.id_reserva = r.id_reserva
WHERE r.fecha_reserva = TRUNC(SYSDATE)
  AND r.checkin = DATE '2026-12-01' AND r.checkout = DATE '2026-12-04'
  AND r.id_cliente IN (1, 2)
ORDER BY r.id_reserva;

-- A5: limpieza del escenario 1. NO saltarse este paso: la doble reserva no puede
--     quedar guardada en la base. REEMPLAZAR 25012 y 25013 por los ids que imprimieron
--     A1 (sesion A) y B2 (sesion B).
DELETE FROM reserva_habitacion WHERE id_reserva IN (25012, 25013);
DELETE FROM reserva WHERE id_reserva IN (25012, 25013);
COMMIT;

-- =================================================================================
-- ESCENARIO 2 - DESPUES: sp_crear_reserva_segura con SELECT ... FOR UPDATE
-- =================================================================================

-- A6: la sesion A reserva con el procedimiento que aparta la habitacion. Sin COMMIT
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

  sp_crear_reserva_segura(1, v_hab, DATE '2026-12-01', DATE '2026-12-04', 1, v_id);
  DBMS_OUTPUT.PUT_LINE('SESION A: habitacion ' || v_hab || ', reserva ' || v_id);
END;
/

-- A7: consulta de control. La sesion A ve su reserva (1 fila)
SELECT r.id_reserva, r.id_cliente, r.estado, rh.id_habitacion,
       rh.fecha_checkin_linea, rh.fecha_checkout_linea
FROM reserva r
JOIN reserva_habitacion rh ON rh.id_reserva = r.id_reserva
WHERE r.fecha_reserva = TRUNC(SYSDATE)
  AND r.checkin = DATE '2026-12-01' AND r.checkout = DATE '2026-12-04'
  AND r.id_cliente IN (1, 2)
ORDER BY r.id_reserva;

-- >>> Pasar a la sesion B: B5. La sesion B se queda ESPERANDO (tomar la captura)

-- >>> Volver a esta sesion A (esta libre) y ejecutar A7b ANTES de A8

-- A7b: mientras B esta esperando, A consulta quien bloquea a quien. Debe aparecer la
--      sesion B con blocking_session = sid de la sesion A y el evento
--      "enq: TX - row lock contention". (Tomar la captura aqui, antes de A8.)
SELECT sid, username, status, event, seconds_in_wait, blocking_session
FROM v$session
WHERE blocking_session IS NOT NULL
  AND username = USER;

-- A8: la sesion A confirma. En ese momento la sesion B se libera y recibe ORA-20002
COMMIT;

-- >>> Pasar a la sesion B: ver el error y ejecutar B6

-- A9: consulta de control. Solo existe la reserva de A (1 fila): no hay doble reserva
SELECT r.id_reserva, r.id_cliente, r.estado, rh.id_habitacion,
       rh.fecha_checkin_linea, rh.fecha_checkout_linea
FROM reserva r
JOIN reserva_habitacion rh ON rh.id_reserva = r.id_reserva
WHERE r.fecha_reserva = TRUNC(SYSDATE)
  AND r.checkin = DATE '2026-12-01' AND r.checkout = DATE '2026-12-04'
  AND r.id_cliente IN (1, 2)
ORDER BY r.id_reserva;

-- A10: limpieza del escenario 2. REEMPLAZAR 25014 por el id que imprimio A6
--      (en este escenario la sesion B no creo ninguna reserva).
DELETE FROM reserva_habitacion WHERE id_reserva = 25014;
DELETE FROM reserva WHERE id_reserva = 25014;
COMMIT;

-- =================================================================================
-- ESCENARIO 3 - NOWAIT Y WAIT: decidir cuanto esperar
-- =================================================================================

-- A11: la sesion A aparta la habitacion 1 y no termina la transaccion
SELECT id_habitacion, numero_habitacion, capacidad_max
FROM habitacion
WHERE id_habitacion = 1
FOR UPDATE;

-- >>> Pasar a la sesion B: B7, B8, B9, B10

-- A12: la sesion A suelta el candado
ROLLBACK;

-- =================================================================================
-- ESCENARIO 4 - DEADLOCK: dos sesiones, dos habitaciones, en orden contrario
-- Orden: A13 | B11 | A14 (espera) | B12 (ORA-00060) | A15 y B13
-- =================================================================================

-- A13: A aparta la habitacion 1
SELECT id_habitacion FROM habitacion WHERE id_habitacion = 1 FOR UPDATE;

-- >>> Pasar a la sesion B: B11

-- A14: A pide la habitacion 2, que B tiene apartada: se queda ESPERANDO
SELECT id_habitacion FROM habitacion WHERE id_habitacion = 2 FOR UPDATE;

-- >>> Pasar a la sesion B: B12 (aqui se produce el deadlock). Volver a A y ejecutar A15.

-- A15: soltar el candado. Oracle cancela solo UNA instruccion (normalmente B12). Si el
--      ORA-00060 aparecio aqui, en A14, B12 sigue esperando hasta este ROLLBACK.
ROLLBACK;

-- >>> Pasar a la sesion B: B13