-- =================================================================================
-- TurismoUQ - Entrega 3 - Entregable 1
-- TRANSACCIONES: RESERVA + PAGO DE FORMA ATOMICA, CON SAVEPOINT Y ROLLBACK PARCIAL
--   PARTE 1) Secuencia para los ids de PAGO
--   PARTE 2) Procedimiento sp_reservar_y_pagar
--   PARTE 3) Pruebas del procedimiento
--              T1 - exitoso con anticipo: reserva confirmada, queda saldo
--              T2 - exitoso con pago total: reserva confirmada y PAGADA
--              T3 - ROLLBACK PARCIAL: el pago excede el total (ORA-20031)
--              T4 - ROLLBACK PARCIAL: metodo de pago invalido (ORA-20032)
--              T5 - ROLLBACK TOTAL: la reserva falla, no queda nada
--   PARTE 4) Demostracion paso a paso del rollback parcial (SAVEPOINT a mano)
--   PARTE 5) Limpieza de los datos de prueba
--
-- Codigos de error propios (RAISE_APPLICATION_ERROR):
--  - 20030 monto del pago invalido
--  - 20031 el pago excede el total de la reserva
--  - 20032 metodo de pago invalido
--
-- Valentina Gonzalez Diaz
-- Raquel Lopez Aristizabal
-- Valentina Rodriguez Castro
--
-- Orden de ejecucion: DESPUES de los scripts de la Entrega 2 (usa pkg_turismouq).
-- Ejecutar con F5. La evidencia queda en evidencia_entrega3_transacciones.txt (SPOOL).
-- =================================================================================
SET DEFINE OFF
WHENEVER SQLERROR CONTINUE
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
COLUMN estado FORMAT A12
COLUMN situacion FORMAT A12
SPOOL evidencia_entrega3_transacciones.txt

-- =================================================================================
-- PARTE 1 - SECUENCIA PARA LOS IDS DE PAGO
-- ---------------------------------------------------------------------------------
-- La carga numero los pagos a mano (1, 2, 3...). Para registrar pagos nuevos se usa
-- una secuencia que arranca en MAX+1, igual que seq_reserva y seq_reserva_hab.
-- Se borra si ya existe para poder re-ejecutar el script.
--
-- OJO: CREATE y DROP son DDL y hacen COMMIT automatico. Por eso van aqui, al inicio,
-- y nunca en medio de una transaccion.
-- =================================================================================
DECLARE
  v_n NUMBER;
BEGIN
  BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE seq_pago';
  EXCEPTION WHEN OTHERS THEN
    IF SQLCODE != -2289 THEN RAISE; END IF; -- -2289: la secuencia no existia
  END;

  SELECT NVL(MAX(id_pago), 0) + 1 INTO v_n FROM pago;
  EXECUTE IMMEDIATE 'CREATE SEQUENCE seq_pago START WITH ' || v_n || ' INCREMENT BY 1 NOCACHE';
END;
/

-- =================================================================================
-- PARTE 2 - PROCEDIMIENTO sp_reservar_y_pagar
-- ---------------------------------------------------------------------------------
-- Registra una reserva y su primer pago (anticipo o pago total) como UNA sola
-- transaccion. En Oracle la transaccion empieza sola con el primer INSERT y la
-- termina el procedimiento con COMMIT o con ROLLBACK.
--
-- La transaccion tiene dos pasos y un punto de guardado entre ellos:
--
--   PASO 1: crear la reserva (encabezado + linea) con pkg_turismouq.sp_crear_reserva,
--           que valida fechas, cliente, capacidad y disponibilidad. Queda 'pendiente'.
--
--   SAVEPOINT reserva_creada
--
--   PASO 2: el pago, en este orden:
--     2a. validar el monto (> 0) y el metodo de pago
--     2b. registrar el pago como 'exitoso'
--     2c. verificar que la suma de pagos exitosos no exceda el total de la reserva
--     2d. SOLO si todo lo anterior salio bien, confirmar la reserva
--
-- REGLAS DE NEGOCIO QUE APLICA:
--   * Total de la reserva = suma del valor de TODAS sus lineas (habitaciones) mas
--     sus servicios (cantidad x precio unitario).
--   * La reserva se CONFIRMA con el primer pago exitoso, aunque sea un anticipo
--     (seccion 1.4: "un anticipo al reservar y el saldo al llegar"). Asi estan
--     tambien los datos cargados: las reservas confirmadas tienen un anticipo.
--   * La reserva se considera PAGADA solo cuando la suma de sus pagos exitosos cubre
--     el total. No es un estado de la tabla: se calcula, y el procedimiento lo informa.
--
-- QUE PASA SI ALGO FALLA:
--   * Falla el PASO 1 (habitacion ocupada, fechas invalidas, capacidad excedida...):
--     no hay reserva, entonces no hay nada que pagar. ROLLBACK total y se relanza el
--     error (ROLLBACK + RAISE).
--   * Falla el PASO 2 por un error PROPIO del pago (-20030, -20031 o -20032):
--     ROLLBACK TO reserva_creada. Se deshace SOLO el paso 2 (por ejemplo, el pago
--     que ya se habia insertado en 2b y resulto excesivo en 2c). La reserva se
--     conserva en estado 'pendiente' y se confirma con COMMIT.
--   * Falla el PASO 2 por cualquier OTRO error (uno que no esperabamos): no se
--     atrapa como error de pago. Llega al EXCEPTION general: ROLLBACK total + RAISE.
--
-- Por que rollback parcial y no total cuando falla el pago:
--   El cliente ya eligio habitacion y fechas. Si el pago no entra (se equivoco de
--   metodo, digito mal el monto) no debe perder la habitacion: la reserva queda
--   'pendiente', sigue bloqueando la habitacion y el pago se puede intentar despues.
--
-- Como sabe el que llama lo que paso:
--   p_id_reserva y p_id_pago con valor     -> todo quedo guardado
--   p_id_reserva con valor, p_id_pago NULL -> rollback parcial: reserva sin pago
--   el procedimiento lanza un error        -> rollback total: no quedo nada
--
-- IMPORTANTE: el COMMIT y el ROLLBACK del procedimiento tambien afectan lo que el
-- que llama tuviera pendiente. Hay que llamarlo sin cambios pendientes en la sesion.
-- =================================================================================
CREATE OR REPLACE PROCEDURE sp_reservar_y_pagar (
  p_id_cliente    IN  cliente.id_cliente%TYPE,
  p_id_habitacion IN  habitacion.id_habitacion%TYPE,
  p_checkin       IN  DATE,
  p_checkout      IN  DATE,
  p_num_huespedes IN  NUMBER,
  p_monto         IN  pago.monto%TYPE,
  p_metodo        IN  pago.metodo_pago%TYPE,
  p_id_reserva    OUT reserva.id_reserva%TYPE,
  p_id_pago       OUT pago.id_pago%TYPE
) IS
  -- Excepciones propias del pago (mismo estilo de pkg_turismouq)
  e_monto_invalido  EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_monto_invalido, -20030);
  e_pago_excede     EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_pago_excede, -20031);
  e_metodo_invalido EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_metodo_invalido, -20032);

  v_estadia   NUMBER;  -- suma del valor de todas las lineas
  v_servicios NUMBER;  -- suma de los servicios contratados
  v_total     NUMBER;  -- estadia + servicios
  v_pagado    NUMBER;  -- suma de los pagos exitosos
BEGIN
  -- PASO 1: la reserva. Si falla, el error sale al EXCEPTION general (rollback total)
  pkg_turismouq.sp_crear_reserva(p_id_cliente, p_id_habitacion, p_checkin, p_checkout,
                                 p_num_huespedes, p_id_reserva);

  -- Total de la reserva: TODAS las lineas mas los servicios
  SELECT NVL(SUM(valor_calculado), 0) INTO v_estadia
  FROM reserva_habitacion
  WHERE id_reserva = p_id_reserva;

  SELECT NVL(SUM(cantidad * precio_unitario), 0) INTO v_servicios
  FROM reserva_servicio
  WHERE id_reserva = p_id_reserva;

  v_total := v_estadia + v_servicios;

  -- Punto de guardado: hasta aqui la reserva esta completa y es valida
  SAVEPOINT reserva_creada;

  -- PASO 2: el pago
  BEGIN
    -- 2a. Validar los datos del pago
    IF p_monto IS NULL OR p_monto <= 0 THEN
      RAISE_APPLICATION_ERROR(-20030,
        'Monto invalido: el pago debe ser mayor que cero');
    END IF;

    IF p_metodo IS NULL OR p_metodo NOT IN ('tarjeta_credito', 'tarjeta_debito', 'PSE',
                                            'transferencia', 'efectivo') THEN
      RAISE_APPLICATION_ERROR(-20032,
        'Metodo de pago invalido: ' || NVL(p_metodo, '(vacio)'));
    END IF;

    -- 2b. Registrar el pago
    p_id_pago := seq_pago.NEXTVAL;
    INSERT INTO pago (id_pago, fecha_pago, monto, metodo_pago, estado_pago, id_reserva)
    VALUES (p_id_pago, SYSDATE, p_monto, p_metodo, 'exitoso', p_id_reserva);

    -- 2c. La suma de pagos exitosos no puede exceder el total de la reserva
    SELECT NVL(SUM(monto), 0) INTO v_pagado
    FROM pago
    WHERE id_reserva = p_id_reserva
      AND estado_pago = 'exitoso';

    IF v_pagado > v_total THEN
      RAISE_APPLICATION_ERROR(-20031,
        'El pago excede el total de la reserva: pagado ' || v_pagado || ', total ' || v_total);
    END IF;

    -- 2d. El pago quedo bien: ahora si se confirma la reserva
    UPDATE reserva SET estado = 'confirmada' WHERE id_reserva = p_id_reserva;

    DBMS_OUTPUT.PUT_LINE('Pago ' || p_id_pago || ' registrado por ' || p_monto ||
                         '. Reserva ' || p_id_reserva || ' confirmada.');
    IF v_pagado >= v_total THEN
      DBMS_OUTPUT.PUT_LINE('Reserva PAGADA: los pagos exitosos (' || v_pagado ||
                           ') cubren el total (' || v_total || ').');
    ELSE
      DBMS_OUTPUT.PUT_LINE('Anticipo recibido: pagado ' || v_pagado || ' de ' || v_total ||
                           '. Saldo pendiente: ' || (v_total - v_pagado) || '.');
    END IF;
  EXCEPTION
    -- Solo los errores PROPIOS del pago producen rollback parcial
    WHEN e_monto_invalido OR e_metodo_invalido OR e_pago_excede THEN
      ROLLBACK TO reserva_creada;
      p_id_pago := NULL;
      DBMS_OUTPUT.PUT_LINE('El pago no se registro: ' || SQLERRM);
      DBMS_OUTPUT.PUT_LINE('ROLLBACK TO reserva_creada: la reserva ' || p_id_reserva ||
                           ' se conserva en estado pendiente.');
  END;

  -- Fin de la transaccion: se confirma lo que quedo en pie
  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    -- ROLLBACK TOTAL: deshacer todo y avisar al que llamo
    ROLLBACK;
    RAISE;
END sp_reservar_y_pagar;
/
SHOW ERRORS PROCEDURE sp_reservar_y_pagar

-- =================================================================================
-- PARTE 3 - PRUEBAS DEL PROCEDIMIENTO
-- ---------------------------------------------------------------------------------
-- Las variables de enlace guardan la habitacion y los ids de las reservas de prueba,
-- para consultarlas entre una prueba y otra y borrarlas al final (PARTE 5).
--
-- Fechas de prueba (diciembre de 2026) sobre una misma habitacion libre, 2 noches
-- cada una:  T1: 1 al 3 | T2: 3 al 5 | T3: 5 al 7 | T4: 7 al 9 | PARTE 4: 9 al 11
-- El dia de salida queda libre para el siguiente ingreso, por eso no se cruzan.
-- =================================================================================
VARIABLE b_hab NUMBER
VARIABLE b_res1 NUMBER
VARIABLE b_res2 NUMBER
VARIABLE b_res3 NUMBER
VARIABLE b_res4 NUMBER
VARIABLE b_res5 NUMBER

-- Habitacion libre del 1 al 11 de diciembre de 2026
BEGIN
  SELECT MIN(h.id_habitacion) INTO :b_hab
  FROM habitacion h
  WHERE NOT EXISTS (SELECT 1 FROM reserva_habitacion rh
                      JOIN reserva r ON r.id_reserva = rh.id_reserva
                     WHERE rh.id_habitacion = h.id_habitacion
                       AND r.estado <> 'cancelada'
                       AND rh.fecha_checkin_linea  < DATE '2026-12-11'
                       AND rh.fecha_checkout_linea > DATE '2026-12-01');
  DBMS_OUTPUT.PUT_LINE('Habitacion de prueba: ' || :b_hab);
END;
/

PROMPT === T0: filas ANTES de las pruebas ===
SELECT (SELECT COUNT(*) FROM reserva) AS reservas,
       (SELECT COUNT(*) FROM reserva_habitacion) AS lineas,
       (SELECT COUNT(*) FROM pago) AS pagos
FROM dual;

-- =================================================================================
-- T1 - EXITOSO CON ANTICIPO
-- Reserva del 1 al 3 de diciembre con un anticipo del 30 % en efectivo.
-- Esperado: reserva 'confirmada', 1 pago, y el mensaje "Anticipo recibido" con saldo.
-- =================================================================================
PROMPT === T1: exitoso con anticipo del 30 % ===
DECLARE
  v_monto NUMBER;
  v_pago  pago.id_pago%TYPE;
BEGIN
  v_monto := ROUND(pkg_turismouq.fn_valor_estadia(:b_hab, DATE '2026-12-01', DATE '2026-12-03') * 0.30, -2);

  sp_reservar_y_pagar(1, :b_hab, DATE '2026-12-01', DATE '2026-12-03', 1,
                      v_monto, 'efectivo', :b_res1, v_pago);

  DBMS_OUTPUT.PUT_LINE('T1 -> reserva ' || :b_res1 || ', pago ' || v_pago ||
                       CASE WHEN :b_res1 IS NOT NULL AND v_pago IS NOT NULL
                            THEN ' OK' ELSE ' FALLA' END);
END;
/

-- =================================================================================
-- T2 - EXITOSO CON PAGO TOTAL
-- Reserva del 3 al 5 de diciembre pagando el valor completo con PSE.
-- Esperado: reserva 'confirmada', 1 pago, y el mensaje "Reserva PAGADA".
-- =================================================================================
PROMPT === T2: exitoso con pago total ===
DECLARE
  v_monto NUMBER;
  v_pago  pago.id_pago%TYPE;
BEGIN
  v_monto := pkg_turismouq.fn_valor_estadia(:b_hab, DATE '2026-12-03', DATE '2026-12-05');

  sp_reservar_y_pagar(1, :b_hab, DATE '2026-12-03', DATE '2026-12-05', 1,
                      v_monto, 'PSE', :b_res2, v_pago);

  DBMS_OUTPUT.PUT_LINE('T2 -> reserva ' || :b_res2 || ', pago ' || v_pago ||
                       CASE WHEN :b_res2 IS NOT NULL AND v_pago IS NOT NULL
                            THEN ' OK' ELSE ' FALLA' END);
END;
/

-- =================================================================================
-- T3 - ROLLBACK PARCIAL: EL PAGO EXCEDE EL TOTAL (ORA-20031)
-- Reserva del 5 al 7 de diciembre; el cajero digita un cero de mas (10 veces el valor).
-- El pago alcanza a insertarse (2b), la verificacion lo rechaza (2c) y el
-- ROLLBACK TO lo deshace.
-- Esperado: la reserva EXISTE, esta 'pendiente' y tiene 0 pagos.
-- =================================================================================
PROMPT === T3: rollback parcial (el pago excede el total) ===
DECLARE
  v_monto NUMBER;
  v_pago  pago.id_pago%TYPE;
BEGIN
  v_monto := pkg_turismouq.fn_valor_estadia(:b_hab, DATE '2026-12-05', DATE '2026-12-07') * 10;

  sp_reservar_y_pagar(2, :b_hab, DATE '2026-12-05', DATE '2026-12-07', 1,
                      v_monto, 'efectivo', :b_res3, v_pago);

  DBMS_OUTPUT.PUT_LINE('T3 -> reserva ' || :b_res3 || ', pago ' || NVL(TO_CHAR(v_pago), 'NULL') ||
                       CASE WHEN :b_res3 IS NOT NULL AND v_pago IS NULL
                            THEN ' OK' ELSE ' FALLA' END);
END;
/

-- =================================================================================
-- T4 - ROLLBACK PARCIAL: METODO DE PAGO INVALIDO (ORA-20032)
-- Reserva del 7 al 9 de diciembre pagada con un metodo que no existe ('bitcoin').
-- Esperado: la reserva EXISTE, esta 'pendiente' y tiene 0 pagos.
-- =================================================================================
PROMPT === T4: rollback parcial (metodo de pago invalido) ===
DECLARE
  v_pago pago.id_pago%TYPE;
BEGIN
  sp_reservar_y_pagar(2, :b_hab, DATE '2026-12-07', DATE '2026-12-09', 1,
                      10000, 'bitcoin', :b_res4, v_pago);

  DBMS_OUTPUT.PUT_LINE('T4 -> reserva ' || :b_res4 || ', pago ' || NVL(TO_CHAR(v_pago), 'NULL') ||
                       CASE WHEN :b_res4 IS NOT NULL AND v_pago IS NULL
                            THEN ' OK' ELSE ' FALLA' END);
END;
/

-- =================================================================================
-- RESUMEN DE T1 A T4
-- Primero un ROLLBACK: no debe deshacer nada, porque el procedimiento ya hizo COMMIT
-- en cada llamada. Despues, el estado de las cuatro reservas:
--   T1 confirmada | 1 pago  | pagado < total | CON SALDO
--   T2 confirmada | 1 pago  | pagado = total | PAGADA
--   T3 pendiente  | 0 pagos | pagado = 0     | CON SALDO
--   T4 pendiente  | 0 pagos | pagado = 0     | CON SALDO
-- "PAGADA" se calcula: la suma de pagos exitosos cubre el total (lineas + servicios).
-- =================================================================================
PROMPT === Resumen T1 a T4 (despues de un ROLLBACK que no deshace nada) ===
ROLLBACK;

SELECT id_reserva, estado, total, pagos, pagado,
       CASE WHEN pagado >= total THEN 'PAGADA' ELSE 'CON SALDO' END AS situacion
FROM (SELECT r.id_reserva, r.estado,
             (SELECT NVL(SUM(rh.valor_calculado), 0) FROM reserva_habitacion rh
               WHERE rh.id_reserva = r.id_reserva)
           + (SELECT NVL(SUM(rs.cantidad * rs.precio_unitario), 0) FROM reserva_servicio rs
               WHERE rs.id_reserva = r.id_reserva) AS total,
             (SELECT COUNT(*) FROM pago p WHERE p.id_reserva = r.id_reserva) AS pagos,
             (SELECT NVL(SUM(p.monto), 0) FROM pago p
               WHERE p.id_reserva = r.id_reserva AND p.estado_pago = 'exitoso') AS pagado
      FROM reserva r
      WHERE r.id_reserva IN (:b_res1, :b_res2, :b_res3, :b_res4))
ORDER BY id_reserva;

-- =================================================================================
-- T5 - ROLLBACK TOTAL
-- Se pide la MISMA habitacion en fechas que cruzan con la reserva de T1 (2 al 4 de
-- diciembre). Falla el paso 1 con ORA-20002: ROLLBACK total + RAISE.
-- Esperado: el error llega al que llama y no queda ni reserva ni pago nuevos
-- (el conteo sube solo por T1 a T4: +4 reservas, +4 lineas, +2 pagos frente a T0).
-- =================================================================================
PROMPT === T5: rollback total (la reserva falla, no queda nada) ===
DECLARE
  v_res  reserva.id_reserva%TYPE;
  v_pago pago.id_pago%TYPE;
BEGIN
  sp_reservar_y_pagar(3, :b_hab, DATE '2026-12-02', DATE '2026-12-04', 1,
                      100000, 'efectivo', v_res, v_pago);
  DBMS_OUTPUT.PUT_LINE('T5 -> FALLA: debio rechazar la habitacion ocupada');
EXCEPTION
  WHEN pkg_turismouq.e_hab_no_disponible THEN
    DBMS_OUTPUT.PUT_LINE('T5 -> OK (esperado): ' || SQLERRM);
END;
/

SELECT (SELECT COUNT(*) FROM reserva) AS reservas,
       (SELECT COUNT(*) FROM reserva_habitacion) AS lineas,
       (SELECT COUNT(*) FROM pago) AS pagos
FROM dual;

-- =================================================================================
-- PARTE 4 - DEMOSTRACION PASO A PASO DEL ROLLBACK PARCIAL
-- ---------------------------------------------------------------------------------
-- Lo mismo que hace el procedimiento por dentro, pero instruccion por instruccion,
-- consultando el estado en cada momento para VER que deshace cada ROLLBACK.
--
--   D1 crear la reserva (9 al 11 de diciembre)      -> pendiente, 0 pagos
--   D2 SAVEPOINT reserva_creada
--   D3 registrar un pago con un cero de mas (error del cajero) y confirmar
--                                                   -> confirmada, 1 pago
--   D4 ROLLBACK TO reserva_creada                   -> pendiente, 0 pagos
--      (se deshizo D3; la reserva de D1 sigue ahi)
--   D5 ROLLBACK                                     -> la reserva ya no existe
-- =================================================================================
PROMPT === D1: crear la reserva (queda pendiente, sin COMMIT) ===
EXECUTE pkg_turismouq.sp_crear_reserva(1, :b_hab, DATE '2026-12-09', DATE '2026-12-11', 1, :b_res5);

SELECT r.id_reserva, r.estado,
       (SELECT COUNT(*) FROM pago p WHERE p.id_reserva = r.id_reserva) AS pagos
FROM reserva r
WHERE r.id_reserva = :b_res5;

PROMPT === D2: punto de guardado ===
SAVEPOINT reserva_creada;

PROMPT === D3: registrar un pago equivocado (un cero de mas) y confirmar la reserva ===
INSERT INTO pago (id_pago, fecha_pago, monto, metodo_pago, estado_pago, id_reserva)
VALUES (seq_pago.NEXTVAL, SYSDATE, 5000000, 'efectivo', 'exitoso', :b_res5);

UPDATE reserva SET estado = 'confirmada' WHERE id_reserva = :b_res5;

SELECT r.id_reserva, r.estado,
       (SELECT COUNT(*) FROM pago p WHERE p.id_reserva = r.id_reserva) AS pagos,
       (SELECT SUM(p.monto) FROM pago p WHERE p.id_reserva = r.id_reserva) AS total_pagado
FROM reserva r
WHERE r.id_reserva = :b_res5;

PROMPT === D4: ROLLBACK TO reserva_creada (rollback parcial) ===
ROLLBACK TO reserva_creada;

SELECT r.id_reserva, r.estado,
       (SELECT COUNT(*) FROM pago p WHERE p.id_reserva = r.id_reserva) AS pagos
FROM reserva r
WHERE r.id_reserva = :b_res5;

PROMPT === D5: ROLLBACK (rollback total): la reserva de la demostracion desaparece (0) ===
ROLLBACK;

SELECT COUNT(*) AS reserva_demo_existe FROM reserva WHERE id_reserva = :b_res5;

-- =================================================================================
-- PARTE 5 - LIMPIEZA
-- ---------------------------------------------------------------------------------
-- T1 a T4 quedaron guardadas con COMMIT. Se borran para dejar la base como estaba:
-- primero los hijos (pago, linea) y despues la reserva, por las claves foraneas.
-- El conteo final debe ser igual al de T0.
-- Los numeros que ya entregaron las secuencias no se devuelven: quedan huecos en
-- los ids, lo cual es normal (una secuencia no hace parte de la transaccion).
-- =================================================================================
PROMPT === Limpieza: borrar las reservas de prueba ===
DELETE FROM pago WHERE id_reserva IN (:b_res1, :b_res2, :b_res3, :b_res4);
DELETE FROM reserva_habitacion WHERE id_reserva IN (:b_res1, :b_res2, :b_res3, :b_res4);
DELETE FROM reserva WHERE id_reserva IN (:b_res1, :b_res2, :b_res3, :b_res4);
COMMIT;

PROMPT === Filas DESPUES de la limpieza (igual a T0) ===
SELECT (SELECT COUNT(*) FROM reserva) AS reservas,
       (SELECT COUNT(*) FROM reserva_habitacion) AS lineas,
       (SELECT COUNT(*) FROM pago) AS pagos
FROM dual;

SPOOL OFF
