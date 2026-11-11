-- =================================================================================
-- TurismoUQ - Entrega 3 - Entregable 2
-- CONCURRENCIA: GUION DE LA SESION A
--
-- NO se ejecuta con F5. Se ejecuta UN paso a la vez con Ctrl + Enter (con el cursor
-- dentro de la instruccion), alternando con E3_02_SesionB.sql en este orden:
--
--   ESCENARIO 1 (antes, sin FOR UPDATE):  A1 A2 | B1 B2 B3 | A3 | B4 | A4 A5
--   ESCENARIO 2 (despues, con FOR UPDATE): A6 A7 | B5 (espera) | A8 | B6 | A9 A10
--   ESCENARIO 3 (NOWAIT y WAIT):           A11 | B7 B8 B9 | A12
--
-- Antes de empezar:
--   * E3_02_Concurrencia.sql ya ejecutado (crea sp_crear_reserva_segura).
--   * Autocommit apagado: Herramientas > Preferencias > Base de datos > Avanzada.
--   * La sesion B se abre con Ctrl + Shift + N (hoja no compartida = otra sesion).
--   * Para ver los mensajes: Ver > Salida de DBMS y activarla en las dos sesiones.
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

-- A5: limpieza del escenario 1 (las tres instrucciones). NO saltarse este paso: la
--     doble reserva no puede quedar guardada en la base.
DELETE FROM reserva_habitacion
WHERE id_reserva IN (SELECT id_reserva FROM reserva
                     WHERE fecha_reserva = TRUNC(SYSDATE)
                       AND checkin = DATE '2026-12-01' AND checkout = DATE '2026-12-04'
                       AND id_cliente IN (1, 2));

DELETE FROM reserva
WHERE fecha_reserva = TRUNC(SYSDATE)
  AND checkin = DATE '2026-12-01' AND checkout = DATE '2026-12-04'
  AND id_cliente IN (1, 2);

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

-- A10: limpieza del escenario 2 (las tres instrucciones)
DELETE FROM reserva_habitacion
WHERE id_reserva IN (SELECT id_reserva FROM reserva
                     WHERE fecha_reserva = TRUNC(SYSDATE)
                       AND checkin = DATE '2026-12-01' AND checkout = DATE '2026-12-04'
                       AND id_cliente IN (1, 2));

DELETE FROM reserva
WHERE fecha_reserva = TRUNC(SYSDATE)
  AND checkin = DATE '2026-12-01' AND checkout = DATE '2026-12-04'
  AND id_cliente IN (1, 2);

COMMIT;

-- =================================================================================
-- ESCENARIO 3 - NOWAIT Y WAIT: decidir cuanto esperar
-- =================================================================================

-- A11: la sesion A aparta la habitacion 1 y no termina la transaccion
SELECT id_habitacion, numero_habitacion, capacidad_max
FROM habitacion
WHERE id_habitacion = 1
FOR UPDATE;

-- >>> Pasar a la sesion B: B7, B8, B9

-- A12: la sesion A suelta el candado
ROLLBACK;
