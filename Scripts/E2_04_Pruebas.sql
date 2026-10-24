-- =================================================================================
-- TurismoUQ - Entrega 2 - Evidencia de pruebas (paquete y disparadores)
-- Ejecutar con F5 DESPUES de los scripts del paquete y de los disparadores.
-- La evidencia queda en evidencia_entrega2.txt (SPOOL).
-- =================================================================================
SET DEFINE OFF
WHENEVER SQLERROR CONTINUE
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 220
SET VERIFY OFF
COLUMN motivo FORMAT A60
SPOOL evidencia_disparadores.txt

-- ===== PRUEBA 1: fn_valor_estadia =====
-- 1a) Una sola temporada: hab 1, 10 al 13 ago 2026 (3 noches, baja = temporada 20)
SELECT pkg_turismouq.fn_valor_estadia(1, DATE '2026-08-10', DATE '2026-08-13') AS por_funcion,
       3 * (SELECT precio_noche FROM tarifa WHERE id_habitacion = 1 AND id_temporada = 20) AS manual
FROM dual;

-- 1b) CRUZA temporadas: 14 al 18 dic 2026 = 2 noches baja (14,15) + 2 noches alta (16,17)
SELECT pkg_turismouq.fn_valor_estadia(1, DATE '2026-12-14', DATE '2026-12-18') AS por_funcion,
       2 * (SELECT precio_noche FROM tarifa WHERE id_habitacion = 1 AND id_temporada = 20)
     + 2 * (SELECT precio_noche FROM tarifa WHERE id_habitacion = 1 AND id_temporada = 21) AS manual
FROM dual;

-- 1c) Sin temporada definida (2027): debe dar ORA-20006
SELECT pkg_turismouq.fn_valor_estadia(1, DATE '2027-01-10', DATE '2027-01-12') FROM dual;

-- 1d) Validacion global: la funcion recalcula lo que cargó el script de carga (debe dar 0)
SELECT COUNT(*) AS diferencias
FROM (SELECT rh.valor_calculado,
             pkg_turismouq.fn_valor_estadia(rh.id_habitacion, rh.fecha_checkin_linea,
                                            rh.fecha_checkout_linea) AS recalculado
        FROM reserva_habitacion rh
       WHERE ROWNUM <= 1000)
WHERE valor_calculado <> recalculado;

-- 1e) Habitacion inexistente: debe dar ORA-20004
SELECT pkg_turismouq.fn_valor_estadia(999999, DATE '2026-08-10', DATE '2026-08-13') FROM dual;

-- ===== PRUEBA 2: sp_crear_reserva =====
-- 2a) Caso exitoso + intento de solape inmediato
DECLARE
    v_hab habitacion.id_habitacion%TYPE;
    v_id  reserva.id_reserva%TYPE;
    v_id2 reserva.id_reserva%TYPE;
BEGIN
    -- busca una habitacion libre en esas fechas
    SELECT MIN(h.id_habitacion) INTO v_hab
      FROM habitacion h
     WHERE NOT EXISTS (SELECT 1 FROM reserva_habitacion rh
                         JOIN reserva r ON r.id_reserva = rh.id_reserva
                        WHERE rh.id_habitacion = h.id_habitacion
                          AND r.estado <> 'cancelada'
                          AND rh.fecha_checkin_linea < DATE '2026-11-05'
                          AND DATE '2026-11-02' < rh.fecha_checkout_linea);

    pkg_turismouq.sp_crear_reserva(1, v_hab, DATE '2026-11-02', DATE '2026-11-05', 1, v_id);

    -- misma habitacion, fechas que se cruzan: debe fallar con -20002
    BEGIN
        pkg_turismouq.sp_crear_reserva(2, v_hab, DATE '2026-11-03', DATE '2026-11-06', 1, v_id2);
    EXCEPTION
        WHEN pkg_turismouq.e_hab_no_disponible THEN
            DBMS_OUTPUT.PUT_LINE('OK (esperado): ' || SQLERRM);
    END;
    ROLLBACK;  -- no deja basura en la base
END;
/

-- 2b) Checkout igual al checkin -> -20001
DECLARE v_id reserva.id_reserva%TYPE;
BEGIN
    pkg_turismouq.sp_crear_reserva(1, 1, DATE '2026-11-05', DATE '2026-11-05', 1, v_id);
EXCEPTION WHEN pkg_turismouq.e_fechas_invalidas THEN
    DBMS_OUTPUT.PUT_LINE('OK (esperado): ' || SQLERRM);
END;
/

-- 2c) Capacidad excedida -> -20003
DECLARE v_id reserva.id_reserva%TYPE;
BEGIN
    pkg_turismouq.sp_crear_reserva(1, 1, DATE '2026-11-02', DATE '2026-11-05', 99, v_id);
EXCEPTION WHEN pkg_turismouq.e_capacidad_excedida THEN
    DBMS_OUTPUT.PUT_LINE('OK (esperado): ' || SQLERRM);
END;
/

-- 2d) SOLAPE REAL contra datos ya cargados: debe fallar con -20002
DECLARE
    v_hab reserva_habitacion.id_habitacion%TYPE;
    v_ini DATE;
    v_id  reserva.id_reserva%TYPE;
BEGIN
    -- toma una linea futura confirmada que ya existe en la carga
    SELECT id_habitacion, fecha_checkin_linea
    INTO v_hab, v_ini
    FROM (SELECT rh.id_habitacion, rh.fecha_checkin_linea
        FROM reserva_habitacion rh
        JOIN reserva r ON r.id_reserva = rh.id_reserva
        WHERE r.estado = 'confirmada'
               AND rh.fecha_checkin_linea > DATE '2026-10-01'
        ORDER BY rh.id_reserva_hab)
     WHERE ROWNUM = 1;

    DBMS_OUTPUT.PUT_LINE('Habitacion ocupada en la carga: ' || v_hab ||
                         ' desde ' || TO_CHAR(v_ini, 'DD/MM/YYYY'));

    -- pedimos un rango que cruza el inicio de esa reserva
    pkg_turismouq.sp_crear_reserva(1, v_hab, v_ini - 1, v_ini + 1, 1, v_id);
    DBMS_OUTPUT.PUT_LINE('FALLO: debio rechazar el solape');
    ROLLBACK;
EXCEPTION
    WHEN pkg_turismouq.e_hab_no_disponible THEN
        DBMS_OUTPUT.PUT_LINE('OK (esperado): ' || SQLERRM);
END;
/

-- 2e) Huespedes invalidos (0): debe dar -20008
DECLARE v_id reserva.id_reserva%TYPE;
BEGIN
    pkg_turismouq.sp_crear_reserva(1, 1, DATE '2026-11-02', DATE '2026-11-05', 0, v_id);
EXCEPTION WHEN pkg_turismouq.e_huespedes_invalidos THEN
    DBMS_OUTPUT.PUT_LINE('OK (esperado): ' || SQLERRM);
END;
/

-- ===== PRUEBA 3: cursor de liquidacion =====
EXEC pkg_turismouq.sp_liquidacion_mensual(2026, 7);

SELECT a.nombre, l.reservas, l.noches_vendidas, l.ingreso_estadias,
       l.ingreso_servicios, l.total_liquidado
FROM liquidacion_mensual l JOIN alojamiento a ON a.id_alojamiento = l.id_alojamiento
WHERE l.anio = 2026 AND l.mes = 7
ORDER BY l.total_liquidado DESC;

-- Control cruzado: ambas cifras deben ser iguales
SELECT SUM(rh.valor_calculado) AS control_estadias
FROM reserva_habitacion rh JOIN reserva r ON r.id_reserva = rh.id_reserva
WHERE r.estado IN ('confirmada','completada')
  AND rh.fecha_checkin_linea >= DATE '2026-07-01' AND rh.fecha_checkin_linea < DATE '2026-08-01';
SELECT SUM(ingreso_estadias) AS en_liquidacion FROM liquidacion_mensual WHERE anio = 2026 AND mes = 7;

-- 3b) Control cruzado de servicios (ambas cifras deben ser iguales)
SELECT SUM(rs.cantidad * rs.precio_unitario) AS control_servicios
FROM reserva_servicio rs
JOIN reserva r ON r.id_reserva = rs.id_reserva
WHERE r.estado IN ('confirmada','completada')
  AND rs.fecha_consumo >= DATE '2026-07-01' AND rs.fecha_consumo < DATE '2026-08-01';
SELECT SUM(ingreso_servicios) AS en_liquidacion
FROM liquidacion_mensual WHERE anio = 2026 AND mes = 7;

-- =================================================================================
-- Todas las pruebas terminan en ROLLBACK: no dejan datos de prueba en la base.
-- A: auditoria de tarifa | B: no solape | C: diagnostico del solape en la carga
-- D: un alojamiento por reserva, capacidad y fechas | E: servicio de otro alojamiento
-- F: resenas de reservas completadas | G: diagnostico de las reglas en la carga
-- H: UPDATE, reactivacion, servicio previo y temporadas solapadas
-- La evidencia queda en evidencia_disparadores.txt (SPOOL).
-- =================================================================================

-- =================================================================================
-- PRUEBA A - AUDITORIA DE TARIFA (disparador de sentencia)
-- Esperado: una sola sentencia UPDATE sobre 3 tarifas deja 3 filas de auditoria con
-- precio anterior, precio nuevo, usuario y fecha. Un UPDATE que no cambia el precio
-- no deja nada. Al final el ROLLBACK deshace todo, auditoria incluida.
-- =================================================================================
PROMPT === A1: precios antes del cambio ===
SELECT id_tarifa, precio_noche FROM tarifa WHERE id_tarifa IN (1,2,3) ORDER BY id_tarifa;

PROMPT === A2: UN solo UPDATE sube 10.000 a tres tarifas ===
UPDATE tarifa SET precio_noche = precio_noche + 10000 WHERE id_tarifa IN (1,2,3);

SELECT id_auditoria, id_tarifa, id_usuario, precio_anterior, precio_nuevo,
       TO_CHAR(fecha_cambio,'DD/MM/YYYY HH24:MI:SS') AS fecha_cambio, motivo
FROM auditoria_tarifa
WHERE id_tarifa IN (1,2,3)
ORDER BY id_auditoria;

PROMPT === A3: UPDATE que NO cambia el precio (solo la fecha): no debe auditar ===
SELECT COUNT(*) AS filas_auditoria_antes FROM auditoria_tarifa;
UPDATE tarifa SET fecha_actualizacion = SYSDATE WHERE id_tarifa IN (1,2,3);
SELECT COUNT(*) AS filas_auditoria_despues FROM auditoria_tarifa;

ROLLBACK;
PROMPT === A4: tras el ROLLBACK la auditoria de prueba desaparece (debe dar 0) ===
SELECT COUNT(*) AS filas_auditoria_tras_rollback FROM auditoria_tarifa WHERE id_tarifa IN (1,2,3);


-- =================================================================================
-- PRUEBA B - NO SOLAPE DE RESERVAS (disparador de fila)
-- B1 usa un caso REAL: una linea que ya existe en los datos de una reserva
--    confirmada; se intenta reservar la misma habitacion en las mismas fechas.
-- B2 a B5 arman un escenario controlado en marzo de 2027 (sin datos previos).
-- Esperado (la columna final de cada linea debe decir OK):
--   B1 RECHAZADA (choca con una reserva real)
--   B2 ACEPTADA  (primera reserva, nadie la ocupa)
--   B3 RECHAZADA (12-16 mar cruza con 10-14 mar)
--   B4 ACEPTADA  (14-16 mar: entra el mismo dia que sale B2; el dia de salida esta libre)
--   B5 ACEPTADA  (reserva cancelada: no ocupa la habitacion)
-- Solo cuenta como RECHAZADA el error propio ORA-20010;
-- =================================================================================
PROMPT === B: no solape de reservas ===
DECLARE
  v_res NUMBER; v_rh NUMBER; v_hab NUMBER; v_ini DATE; v_fin DATE;
  v_antes NUMBER; v_despues NUMBER;
  v_ok NUMBER := 0; v_mal NUMBER := 0;

  PROCEDURE intento(p_desc VARCHAR2, p_estado VARCHAR2, p_hab NUMBER, p_ini DATE, p_fin DATE,
                    p_esperado VARCHAR2) IS
    v_obtenido VARCHAR2(12);
    v_msg      VARCHAR2(300);
  BEGIN
    SELECT MAX(id_reserva) + 1 INTO v_res FROM reserva;
    SELECT MAX(id_reserva_hab) + 1 INTO v_rh FROM reserva_habitacion;
    INSERT INTO reserva (id_reserva, id_cliente, fecha_reserva, checkin, checkout, estado)
    VALUES (v_res, 1, SYSDATE, p_ini, p_fin, p_estado);
    BEGIN
      INSERT INTO reserva_habitacion (id_reserva_hab, id_reserva, id_habitacion,
                                      fecha_checkin_linea, fecha_checkout_linea, num_huespedes, valor_calculado)
      VALUES (v_rh, v_res, p_hab, p_ini, p_fin, 1, NULL);
      v_obtenido := 'ACEPTADA';
    EXCEPTION WHEN OTHERS THEN
      IF SQLCODE = -20010 THEN v_obtenido := 'RECHAZADA'; ELSE v_obtenido := 'ERROR'; END IF;
      v_msg := SUBSTR(SQLERRM, 1, INSTR(SQLERRM || CHR(10), CHR(10)) - 1);
    END;
    IF v_obtenido = p_esperado THEN v_ok := v_ok + 1; ELSE v_mal := v_mal + 1; END IF;
    DBMS_OUTPUT.PUT_LINE(RPAD(p_desc, 62) || ' -> ' || RPAD(v_obtenido, 10) ||
                         CASE WHEN v_obtenido = p_esperado THEN ' OK' ELSE ' FALLA' END ||
                         CASE WHEN v_msg IS NOT NULL THEN CHR(10) || '      ' || v_msg END);
  END;
BEGIN
  SELECT COUNT(*) INTO v_antes FROM reserva_habitacion;

  -- Linea real de una reserva confirmada
  SELECT id_habitacion, fecha_checkin_linea, fecha_checkout_linea
    INTO v_hab, v_ini, v_fin
    FROM (SELECT rh.id_habitacion, rh.fecha_checkin_linea, rh.fecha_checkout_linea
          FROM reserva_habitacion rh
          JOIN reserva r ON r.id_reserva = rh.id_reserva
          WHERE r.estado = 'confirmada'
          ORDER BY rh.id_reserva_hab)
   WHERE ROWNUM = 1;
  DBMS_OUTPUT.PUT_LINE('Habitacion de prueba: ' || v_hab ||
                       ' (ocupada del ' || TO_CHAR(v_ini,'DD/MM/YYYY') ||
                       ' al ' || TO_CHAR(v_fin,'DD/MM/YYYY') || ' en los datos reales)');

  intento('B1 caso real: misma habitacion y mismas fechas, pendiente', 'pendiente',  v_hab, v_ini, v_fin, 'RECHAZADA');
  intento('B2 reserva A confirmada, 10-14 mar 2027',                   'confirmada', v_hab, DATE '2027-03-10', DATE '2027-03-14', 'ACEPTADA');
  intento('B3 reserva B pendiente, 12-16 mar 2027 (cruza con A)',      'pendiente',  v_hab, DATE '2027-03-12', DATE '2027-03-16', 'RECHAZADA');
  intento('B4 reserva C pendiente, 14-16 mar 2027 (entra al salir A)', 'pendiente',  v_hab, DATE '2027-03-14', DATE '2027-03-16', 'ACEPTADA');
  intento('B5 reserva D cancelada, 11-13 mar 2027 (no bloquea)',       'cancelada',  v_hab, DATE '2027-03-11', DATE '2027-03-13', 'ACEPTADA');

  DBMS_OUTPUT.PUT_LINE('Resultado B: ' || v_ok || ' OK, ' || v_mal || ' FALLA (esperado: 5 OK, 0 FALLA)');

  ROLLBACK;
  SELECT COUNT(*) INTO v_despues FROM reserva_habitacion;
  DBMS_OUTPUT.PUT_LINE('Lineas de reserva antes: ' || v_antes || ' / despues del ROLLBACK: ' || v_despues);
END;
/

-- =================================================================================
-- PRUEBA C - DIAGNOSTICO (no es una prueba del disparador)
-- Los disparadores solo vigilan lo que se inserta DESPUES; esto cuenta lo que ya
-- estaba. Debe dar 0: la carga ya respeta la regla de no solape
-- =================================================================================
PROMPT === C: pares de lineas activas que se solapan en los datos cargados (debe ser 0) ===
SELECT COUNT(*) AS pares_en_conflicto
FROM reserva_habitacion a
JOIN reserva ra ON ra.id_reserva = a.id_reserva
JOIN reserva_habitacion b ON b.id_habitacion = a.id_habitacion
  AND b.id_reserva_hab > a.id_reserva_hab
JOIN reserva rb ON rb.id_reserva = b.id_reserva
WHERE ra.estado <> 'cancelada'
  AND rb.estado <> 'cancelada'
  AND a.fecha_checkin_linea  < b.fecha_checkout_linea
  AND a.fecha_checkout_linea > b.fecha_checkin_linea;

-- =================================================================================
-- PRUEBA D - REGLAS 4 Y 7 SOBRE LAS LINEAS DE RESERVA
--   regla 4: una reserva pertenece a un solo alojamiento      (ORA-20011)
--   regla 7: capacidad maxima y fechas dentro de la reserva   (ORA-20013 / ORA-20014)
-- Usa los alojamientos 1 y 2 y fechas de 2027 (sin datos previos). Termina en ROLLBACK.
-- Esperado (la columna final de cada linea debe decir OK):
--   D1 ACEPTADA primera linea, alojamiento 1
--   D2 RECHAZADA segunda linea de la MISMA reserva en el alojamiento 2
--   D3 ACEPTADA segunda linea de la misma reserva, otra habitacion del alojamiento 1
--   D4 RECHAZADA huespedes = capacidad + 1
--   D5 ACEPTADA huespedes = capacidad exacta
--   D6 RECHAZADA la linea entra un dia ANTES del check-in de la reserva
--   D7 RECHAZADA la linea sale un dia DESPUES del check-out de la reserva
--   D8 ACEPTADA la linea queda dentro del rango de la reserva
-- =================================================================================
PROMPT === D: dos alojamientos en una reserva, capacidad y fechas de la linea ===
DECLARE
  v_ok NUMBER := 0; v_mal NUMBER := 0;
  v_res NUMBER; v_rh NUMBER; v_cap NUMBER;
  v_h1 NUMBER; v_h1b NUMBER; v_h2 NUMBER;
  v_antes NUMBER; v_despues NUMBER;

  FUNCTION nueva_reserva(p_ini DATE, p_fin DATE) RETURN NUMBER IS
    v_id NUMBER;
  BEGIN
    SELECT MAX(id_reserva) + 1 INTO v_id FROM reserva;
    INSERT INTO reserva (id_reserva, id_cliente, fecha_reserva, checkin, checkout, estado)
    VALUES (v_id, 1, SYSDATE, p_ini, p_fin, 'pendiente');
    RETURN v_id;
  END;

  -- p_codigo = codigo de error esperado (NULL = debe aceptarse)
  PROCEDURE linea(p_desc VARCHAR2, p_res NUMBER, p_hab NUMBER, p_ini DATE, p_fin DATE,
                  p_pax NUMBER, p_codigo NUMBER) IS
    v_obt VARCHAR2(10); v_esp VARCHAR2(10); v_msg VARCHAR2(300);
  BEGIN
    SELECT MAX(id_reserva_hab) + 1 INTO v_rh FROM reserva_habitacion;
    BEGIN
      INSERT INTO reserva_habitacion (id_reserva_hab, id_reserva, id_habitacion,
                                      fecha_checkin_linea, fecha_checkout_linea, num_huespedes, valor_calculado)
      VALUES (v_rh, p_res, p_hab, p_ini, p_fin, p_pax, NULL);
      v_obt := 'ACEPTADA';
    EXCEPTION WHEN OTHERS THEN
      v_msg := SUBSTR(SQLERRM, 1, INSTR(SQLERRM || CHR(10), CHR(10)) - 1);
      IF SQLCODE = p_codigo THEN v_obt := 'RECHAZADA'; ELSE v_obt := 'ERROR'; END IF;
    END;
    v_esp := CASE WHEN p_codigo IS NULL THEN 'ACEPTADA' ELSE 'RECHAZADA' END;
    IF v_obt = v_esp THEN v_ok := v_ok + 1; ELSE v_mal := v_mal + 1; END IF;
    DBMS_OUTPUT.PUT_LINE(RPAD(p_desc, 58) || ' -> ' || RPAD(v_obt, 10) ||
                         CASE WHEN v_obt = v_esp THEN ' OK' ELSE ' FALLA' END ||
                         CASE WHEN v_msg IS NOT NULL THEN CHR(10) || '      ' || v_msg END);
  END;
BEGIN
  SELECT COUNT(*) INTO v_antes FROM reserva_habitacion;

  SELECT MIN(id_habitacion) INTO v_h1  FROM habitacion WHERE id_alojamiento = 1;
  SELECT MAX(id_habitacion) INTO v_h1b FROM habitacion WHERE id_alojamiento = 1;
  SELECT MIN(id_habitacion) INTO v_h2  FROM habitacion WHERE id_alojamiento = 2;
  SELECT capacidad_max INTO v_cap FROM habitacion WHERE id_habitacion = v_h1;
  DBMS_OUTPUT.PUT_LINE('Habitaciones: ' || v_h1 || ' y ' || v_h1b || ' (alojamiento 1), ' ||
                       v_h2 || ' (alojamiento 2). Capacidad de la ' || v_h1 || ': ' || v_cap);

  -- Regla 4: una reserva, un solo alojamiento
  v_res := nueva_reserva(DATE '2027-05-10', DATE '2027-05-14');
  linea('D1 linea 1 en el alojamiento 1',                      v_res, v_h1,  DATE '2027-05-10', DATE '2027-05-14', 1, NULL);
  linea('D2 linea 2 de la MISMA reserva en el alojamiento 2',  v_res, v_h2,  DATE '2027-05-10', DATE '2027-05-14', 1, -20011);
  linea('D3 linea 2 de la misma reserva, mismo alojamiento 1', v_res, v_h1b, DATE '2027-05-10', DATE '2027-05-14', 1, NULL);

  -- Regla 7: capacidad maxima
  v_res := nueva_reserva(DATE '2027-06-10', DATE '2027-06-14');
  linea('D4 huespedes = capacidad + 1',                        v_res, v_h1,  DATE '2027-06-10', DATE '2027-06-14', v_cap + 1, -20013);
  linea('D5 huespedes = capacidad exacta',                     v_res, v_h1,  DATE '2027-06-10', DATE '2027-06-14', v_cap,     NULL);

  -- Regla 7: fechas de la linea dentro del rango de la reserva (10 al 14 de julio)
  v_res := nueva_reserva(DATE '2027-07-10', DATE '2027-07-14');
  linea('D6 linea entra ANTES del check-in de la reserva',     v_res, v_h1,  DATE '2027-07-09', DATE '2027-07-13', 1, -20014);
  linea('D7 linea sale DESPUES del check-out de la reserva',   v_res, v_h1,  DATE '2027-07-12', DATE '2027-07-16', 1, -20014);
  linea('D8 linea dentro del rango de la reserva',             v_res, v_h1,  DATE '2027-07-11', DATE '2027-07-13', 1, NULL);

  DBMS_OUTPUT.PUT_LINE('Resultado D: ' || v_ok || ' OK, ' || v_mal || ' FALLA (esperado: 8 OK, 0 FALLA)');
  ROLLBACK;
  SELECT COUNT(*) INTO v_despues FROM reserva_habitacion;
  DBMS_OUTPUT.PUT_LINE('Lineas de reserva antes: ' || v_antes || ' / despues del ROLLBACK: ' || v_despues);
END;
/


-- =================================================================================
-- PRUEBA E - REGLA 5: SERVICIOS DEL ALOJAMIENTO DONDE SE HOSPEDA (ORA-20012)
-- Esperado:
--   E1 ACEPTADA servicio del mismo alojamiento de la habitacion
--   E2 RECHAZADA servicio de OTRO alojamiento
-- =================================================================================
PROMPT === E: servicio de otro alojamiento ===
DECLARE
  v_ok NUMBER := 0; v_mal NUMBER := 0;
  v_srv_propio NUMBER; v_aloj NUMBER; v_aloj_ajeno NUMBER; v_srv_ajeno NUMBER;
  v_hab NUMBER; v_res NUMBER; v_rh NUMBER; v_antes NUMBER; v_despues NUMBER;

  PROCEDURE prueba_servicio(p_desc VARCHAR2, p_serv NUMBER, p_codigo NUMBER) IS
    v_obt VARCHAR2(10); v_esp VARCHAR2(10); v_msg VARCHAR2(300); v_rs NUMBER; v_prec NUMBER;
  BEGIN
    SELECT MAX(id_reserva_servicio) + 1 INTO v_rs FROM reserva_servicio;
    SELECT precio INTO v_prec FROM servicio WHERE id_servicio = p_serv;
    BEGIN
      INSERT INTO reserva_servicio (id_reserva_servicio, id_reserva, id_servicio, cantidad, precio_unitario, fecha_consumo)
      VALUES (v_rs, v_res, p_serv, 1, v_prec, DATE '2027-08-11');
      v_obt := 'ACEPTADA';
    EXCEPTION WHEN OTHERS THEN
      v_msg := SUBSTR(SQLERRM, 1, INSTR(SQLERRM || CHR(10), CHR(10)) - 1);
      IF SQLCODE = p_codigo THEN v_obt := 'RECHAZADA'; ELSE v_obt := 'ERROR'; END IF;
    END;
    v_esp := CASE WHEN p_codigo IS NULL THEN 'ACEPTADA' ELSE 'RECHAZADA' END;
    IF v_obt = v_esp THEN v_ok := v_ok + 1; ELSE v_mal := v_mal + 1; END IF;
    DBMS_OUTPUT.PUT_LINE(RPAD(p_desc, 58) || ' -> ' || RPAD(v_obt, 10) ||
                         CASE WHEN v_obt = v_esp THEN ' OK' ELSE ' FALLA' END ||
                         CASE WHEN v_msg IS NOT NULL THEN CHR(10) || '      ' || v_msg END);
  END;
BEGIN
  SELECT COUNT(*) INTO v_antes FROM reserva_servicio;

  SELECT id_servicio, id_alojamiento INTO v_srv_propio, v_aloj
    FROM (SELECT id_servicio, id_alojamiento FROM servicio ORDER BY id_servicio)
   WHERE ROWNUM = 1;
  SELECT MIN(id_servicio) INTO v_srv_ajeno FROM servicio WHERE id_alojamiento <> v_aloj;
  SELECT id_alojamiento INTO v_aloj_ajeno FROM servicio WHERE id_servicio = v_srv_ajeno;
  SELECT MIN(id_habitacion) INTO v_hab FROM habitacion WHERE id_alojamiento = v_aloj;
  DBMS_OUTPUT.PUT_LINE('Reserva en el alojamiento ' || v_aloj || ' (habitacion ' || v_hab ||
                       '). Servicio propio: ' || v_srv_propio ||
                       ' / servicio ajeno: ' || v_srv_ajeno || ' (alojamiento ' || v_aloj_ajeno || ')');

  SELECT MAX(id_reserva) + 1 INTO v_res FROM reserva;
  INSERT INTO reserva (id_reserva, id_cliente, fecha_reserva, checkin, checkout, estado)
  VALUES (v_res, 1, SYSDATE, DATE '2027-08-10', DATE '2027-08-14', 'pendiente');
  SELECT MAX(id_reserva_hab) + 1 INTO v_rh FROM reserva_habitacion;
  INSERT INTO reserva_habitacion (id_reserva_hab, id_reserva, id_habitacion,
                                  fecha_checkin_linea, fecha_checkout_linea, num_huespedes, valor_calculado)
  VALUES (v_rh, v_res, v_hab, DATE '2027-08-10', DATE '2027-08-14', 1, NULL);

  prueba_servicio('E1 servicio del MISMO alojamiento de la habitacion', v_srv_propio, NULL);
  prueba_servicio('E2 servicio de OTRO alojamiento',                    v_srv_ajeno,  -20012);

  DBMS_OUTPUT.PUT_LINE('Resultado E: ' || v_ok || ' OK, ' || v_mal || ' FALLA (esperado: 2 OK, 0 FALLA)');
  ROLLBACK;
  SELECT COUNT(*) INTO v_despues FROM reserva_servicio;
  DBMS_OUTPUT.PUT_LINE('Servicios contratados antes: ' || v_antes || ' / despues del ROLLBACK: ' || v_despues);
END;
/

-- =================================================================================
-- PRUEBA F - REGLA 2: RESENAS SOLO DE ESTADIAS COMPLETADAS (ORA-20015)
-- Se usan reservas REALES de la carga: una completada sin resena y una cancelada.
-- Esperado:
--   F1 ACEPTADA resena de una reserva completada, del cliente y alojamiento correctos
--   F2 RECHAZADA resena de una reserva CANCELADA (nunca se hospedo)
--   F3 RECHAZADA reserva completada pero de OTRO cliente
--   F4 RECHAZADA reserva completada pero de OTRO alojamiento
-- =================================================================================
PROMPT === F: resenas de reservas completadas ===
DECLARE
  v_ok NUMBER := 0; v_mal NUMBER := 0;
  v_res_c NUMBER; v_cli_c NUMBER; v_aloj_c NUMBER;   -- completada
  v_res_x NUMBER; v_cli_x NUMBER; v_aloj_x NUMBER;   -- cancelada
  v_antes NUMBER; v_despues NUMBER;

  PROCEDURE resena_prueba(p_desc VARCHAR2, p_res NUMBER, p_cli NUMBER, p_aloj NUMBER, p_codigo NUMBER) IS
    v_obt VARCHAR2(10); v_esp VARCHAR2(10); v_msg VARCHAR2(300); v_id NUMBER;
  BEGIN
    SELECT MAX(id_resena) + 1 INTO v_id FROM resena;
    BEGIN
      INSERT INTO resena (id_resena, id_reserva, id_alojamiento, id_cliente, calificacion, comentario, fecha_resena)
      VALUES (v_id, p_res, p_aloj, p_cli, 5, 'Resena de prueba', SYSDATE);
      v_obt := 'ACEPTADA';
    EXCEPTION WHEN OTHERS THEN
      v_msg := SUBSTR(SQLERRM, 1, INSTR(SQLERRM || CHR(10), CHR(10)) - 1);
      IF SQLCODE = p_codigo THEN v_obt := 'RECHAZADA'; ELSE v_obt := 'ERROR'; END IF;
    END;
    v_esp := CASE WHEN p_codigo IS NULL THEN 'ACEPTADA' ELSE 'RECHAZADA' END;
    IF v_obt = v_esp THEN v_ok := v_ok + 1; ELSE v_mal := v_mal + 1; END IF;
    DBMS_OUTPUT.PUT_LINE(RPAD(p_desc, 58) || ' -> ' || RPAD(v_obt, 10) ||
                         CASE WHEN v_obt = v_esp THEN ' OK' ELSE ' FALLA' END ||
                         CASE WHEN v_msg IS NOT NULL THEN CHR(10) || '      ' || v_msg END);
  END;
BEGIN
  SELECT COUNT(*) INTO v_antes FROM resena;

  SELECT id_reserva, id_cliente, id_alojamiento INTO v_res_c, v_cli_c, v_aloj_c
    FROM (SELECT r.id_reserva, r.id_cliente, MIN(h.id_alojamiento) AS id_alojamiento
            FROM reserva r
            JOIN reserva_habitacion rh ON rh.id_reserva   = r.id_reserva
            JOIN habitacion h  ON h.id_habitacion = rh.id_habitacion
           WHERE r.estado = 'completada'
             AND NOT EXISTS (SELECT 1 FROM resena x WHERE x.id_reserva = r.id_reserva)
           GROUP BY r.id_reserva, r.id_cliente
           ORDER BY r.id_reserva)
   WHERE ROWNUM = 1;

  SELECT id_reserva, id_cliente, id_alojamiento INTO v_res_x, v_cli_x, v_aloj_x
    FROM (SELECT r.id_reserva, r.id_cliente, MIN(h.id_alojamiento) AS id_alojamiento
            FROM reserva r
            JOIN reserva_habitacion rh ON rh.id_reserva   = r.id_reserva
            JOIN habitacion h  ON h.id_habitacion = rh.id_habitacion
           WHERE r.estado = 'cancelada'
           GROUP BY r.id_reserva, r.id_cliente
           ORDER BY r.id_reserva)
   WHERE ROWNUM = 1;
  DBMS_OUTPUT.PUT_LINE('Reserva completada: ' || v_res_c || ' (cliente ' || v_cli_c || ', alojamiento ' || v_aloj_c ||
                       ') / reserva cancelada: ' || v_res_x);

  resena_prueba('F1 reserva completada, cliente y alojamiento correctos', v_res_c, v_cli_c, v_aloj_c, NULL);
  resena_prueba('F2 reserva CANCELADA (nunca se hospedo)',                v_res_x, v_cli_x, v_aloj_x, -20015);
  resena_prueba('F3 reserva completada, pero de OTRO cliente',            v_res_c,
                CASE WHEN v_cli_c = 1 THEN 2 ELSE 1 END, v_aloj_c, -20015);
  resena_prueba('F4 reserva completada, pero de OTRO alojamiento',        v_res_c, v_cli_c,
                CASE WHEN v_aloj_c = 1 THEN 2 ELSE 1 END, -20015);

  DBMS_OUTPUT.PUT_LINE('Resultado F: ' || v_ok || ' OK, ' || v_mal || ' FALLA (esperado: 4 OK, 0 FALLA)');
  ROLLBACK;
  SELECT COUNT(*) INTO v_despues FROM resena;
  DBMS_OUTPUT.PUT_LINE('Resenas antes: ' || v_antes || ' / despues del ROLLBACK: ' || v_despues);
END;
/

-- =================================================================================
-- PRUEBA G - DIAGNOSTICO DE LOS DATOS YA CARGADOS (no es una prueba de disparador)
-- Los disparadores solo vigilan lo que se inserta DESPUES. Estas consultas comprueban
-- que los datos de la carga ya cumplen las mismas reglas. Las cinco deben dar 0.
-- =================================================================================
PROMPT === G1: reservas con habitaciones de mas de un alojamiento (regla 4) ===
SELECT COUNT(*) AS reservas_en_varios_alojamientos
  FROM (SELECT rh.id_reserva
      FROM reserva_habitacion rh
      JOIN habitacion h ON h.id_habitacion = rh.id_habitacion
      GROUP BY rh.id_reserva
      HAVING COUNT(DISTINCT h.id_alojamiento) > 1);

PROMPT === G2: servicios contratados que son de otro alojamiento (regla 5) ===
SELECT COUNT(*) AS servicios_de_otro_alojamiento
  FROM reserva_servicio rs
  JOIN servicio s ON s.id_servicio = rs.id_servicio
 WHERE EXISTS (SELECT 1
              FROM reserva_habitacion rh
              JOIN habitacion h ON h.id_habitacion = rh.id_habitacion
              WHERE rh.id_reserva = rs.id_reserva
                AND h.id_alojamiento <> s.id_alojamiento);

PROMPT === G3: lineas con mas huespedes que la capacidad de la habitacion (regla 7) ===
SELECT COUNT(*) AS lineas_sobre_capacidad
  FROM reserva_habitacion rh
  JOIN habitacion h ON h.id_habitacion = rh.id_habitacion
 WHERE rh.num_huespedes > h.capacidad_max;

PROMPT === G4: lineas con fechas fuera del rango de su reserva (regla 7) ===
SELECT COUNT(*) AS lineas_fuera_de_rango
  FROM reserva_habitacion rh
  JOIN reserva r ON r.id_reserva = rh.id_reserva
 WHERE rh.fecha_checkin_linea < r.checkin
    OR rh.fecha_checkout_linea > r.checkout;

PROMPT === G5: pares de temporadas que se solapan (regla 8) ===
SELECT COUNT(*) AS temporadas_solapadas
  FROM temporada a
  JOIN temporada b ON b.id_temporada > a.id_temporada
                  AND a.fecha_inicio <= b.fecha_fin
                  AND b.fecha_inicio <= a.fecha_fin;

-- =================================================================================
-- PRUEBA H - UPDATE, REACTIVACION, SERVICIO PREVIO Y TEMPORADAS SOLAPADAS
-- Esperado (la columna final de cada linea debe decir OK):
--   H1 RECHAZADA (-20013) UPDATE que supera la capacidad
--   H2 RECHAZADA (-20014) UPDATE que saca la linea del rango de la reserva
--   H3 RECHAZADA (-20010) UPDATE de fechas que crea un solape
--   H4 RECHAZADA (-20011) UPDATE de habitacion a otro alojamiento
--   H5 RECHAZADA (-20010) reactivar una reserva cancelada cuya habitacion ya se ocupo
--   H6 RECHAZADA (-20011) linea de otro alojamiento en una reserva que ya tiene un servicio
--   H7 RECHAZADA (-20017) temporada que solapa con una existente
--   H8 ACEPTADA           temporada nueva sin solape (control)
-- =================================================================================
PROMPT === H: UPDATE, reactivacion, servicio previo y temporadas ===
DECLARE
  v_ok NUMBER := 0; v_mal NUMBER := 0;
  v_antes NUMBER; v_despues NUMBER;
  v_h1 NUMBER; v_h1b NUMBER; v_h2 NUMBER; v_cap NUMBER;
  v_r1 NUMBER; v_r2 NUMBER; v_l1 NUMBER; v_l2 NUMBER;
  v_srv NUMBER; v_aloj NUMBER; v_haj NUMBER; v_rs NUMBER;

  FUNCTION nueva_reserva(p_ini DATE, p_fin DATE, p_estado VARCHAR2) RETURN NUMBER IS
    v_id NUMBER;
  BEGIN
    SELECT MAX(id_reserva) + 1 INTO v_id FROM reserva;
    INSERT INTO reserva (id_reserva, id_cliente, fecha_reserva, checkin, checkout, estado)
    VALUES (v_id, 1, SYSDATE, p_ini, p_fin, p_estado);
    RETURN v_id;
  END;

  FUNCTION nueva_linea(p_res NUMBER, p_hab NUMBER, p_ini DATE, p_fin DATE) RETURN NUMBER IS
    v_id NUMBER;
  BEGIN
    SELECT MAX(id_reserva_hab) + 1 INTO v_id FROM reserva_habitacion;
    INSERT INTO reserva_habitacion (id_reserva_hab, id_reserva, id_habitacion,
                                    fecha_checkin_linea, fecha_checkout_linea, num_huespedes, valor_calculado)
    VALUES (v_id, p_res, p_hab, p_ini, p_fin, 1, NULL);
    RETURN v_id;
  END;

  -- p_codigo = codigo esperado (NULL = debe aceptarse); p_sqlcode = lo que paso (0 = sin error)
  PROCEDURE resultado(p_desc VARCHAR2, p_codigo NUMBER, p_sqlcode NUMBER, p_msg VARCHAR2) IS
    v_bien BOOLEAN;
  BEGIN
    v_bien := (p_codigo IS NULL AND p_sqlcode = 0) OR (p_codigo IS NOT NULL AND p_sqlcode = p_codigo);
    IF v_bien THEN v_ok := v_ok + 1; ELSE v_mal := v_mal + 1; END IF;
    DBMS_OUTPUT.PUT_LINE(RPAD(p_desc, 62) || ' -> ' ||
                         RPAD(CASE WHEN p_sqlcode = 0 THEN 'ACEPTADA' ELSE 'RECHAZADA' END, 10) ||
                         CASE WHEN v_bien THEN ' OK' ELSE ' FALLA' END ||
                         CASE WHEN p_msg IS NOT NULL THEN CHR(10) || '      ' ||
                              SUBSTR(p_msg, 1, INSTR(p_msg || CHR(10), CHR(10)) - 1) END);
  END;
BEGIN
  SELECT COUNT(*) INTO v_antes FROM reserva_habitacion;

  SELECT MIN(id_habitacion) INTO v_h1  FROM habitacion WHERE id_alojamiento = 1;
  SELECT MAX(id_habitacion) INTO v_h1b FROM habitacion WHERE id_alojamiento = 1;
  SELECT MIN(id_habitacion) INTO v_h2  FROM habitacion WHERE id_alojamiento = 2;
  SELECT capacidad_max INTO v_cap FROM habitacion WHERE id_habitacion = v_h1;

  -- H1 y H2: UPDATE sobre una linea valida (septiembre 2027)
  v_r1 := nueva_reserva(DATE '2027-09-10', DATE '2027-09-14', 'pendiente');
  v_l1 := nueva_linea(v_r1, v_h1, DATE '2027-09-10', DATE '2027-09-14');
  BEGIN
    UPDATE reserva_habitacion SET num_huespedes = v_cap + 1 WHERE id_reserva_hab = v_l1;
    resultado('H1 UPDATE: huespedes = capacidad + 1', -20013, 0, NULL);
  EXCEPTION WHEN OTHERS THEN
    resultado('H1 UPDATE: huespedes = capacidad + 1', -20013, SQLCODE, SQLERRM);
  END;
  BEGIN
    UPDATE reserva_habitacion SET fecha_checkout_linea = DATE '2027-09-20' WHERE id_reserva_hab = v_l1;
    resultado('H2 UPDATE: la linea sale del rango de la reserva', -20014, 0, NULL);
  EXCEPTION WHEN OTHERS THEN
    resultado('H2 UPDATE: la linea sale del rango de la reserva', -20014, SQLCODE, SQLERRM);
  END;

  -- H3: UPDATE de fechas que crea un solape (marzo 2027)
  v_r1 := nueva_reserva(DATE '2027-03-10', DATE '2027-03-14', 'confirmada');
  v_l1 := nueva_linea(v_r1, v_h1, DATE '2027-03-10', DATE '2027-03-14');
  v_r2 := nueva_reserva(DATE '2027-03-12', DATE '2027-03-16', 'pendiente');
  v_l2 := nueva_linea(v_r2, v_h1, DATE '2027-03-14', DATE '2027-03-16');
  BEGIN
    UPDATE reserva_habitacion SET fecha_checkin_linea = DATE '2027-03-12' WHERE id_reserva_hab = v_l2;
    resultado('H3 UPDATE: el cambio de fechas crea un solape', -20010, 0, NULL);
  EXCEPTION WHEN OTHERS THEN
    resultado('H3 UPDATE: el cambio de fechas crea un solape', -20010, SQLCODE, SQLERRM);
  END;

  -- H4: UPDATE de habitacion hacia otro alojamiento (octubre 2027)
  v_r1 := nueva_reserva(DATE '2027-10-10', DATE '2027-10-14', 'pendiente');
  v_l1 := nueva_linea(v_r1, v_h1,  DATE '2027-10-10', DATE '2027-10-14');
  v_l2 := nueva_linea(v_r1, v_h1b, DATE '2027-10-10', DATE '2027-10-14');
  BEGIN
    UPDATE reserva_habitacion SET id_habitacion = v_h2 WHERE id_reserva_hab = v_l2;
    resultado('H4 UPDATE: la habitacion pasa a otro alojamiento', -20011, 0, NULL);
  EXCEPTION WHEN OTHERS THEN
    resultado('H4 UPDATE: la habitacion pasa a otro alojamiento', -20011, SQLCODE, SQLERRM);
  END;

  -- H5: reactivar una reserva cancelada cuya habitacion ya fue ocupada (noviembre 2027)
  v_r1 := nueva_reserva(DATE '2027-11-10', DATE '2027-11-14', 'confirmada');
  v_l1 := nueva_linea(v_r1, v_h1, DATE '2027-11-10', DATE '2027-11-14');
  v_r2 := nueva_reserva(DATE '2027-11-10', DATE '2027-11-14', 'cancelada');
  v_l2 := nueva_linea(v_r2, v_h1, DATE '2027-11-10', DATE '2027-11-14');
  BEGIN
    UPDATE reserva SET estado = 'pendiente' WHERE id_reserva = v_r2;
    resultado('H5 reactivar reserva cancelada con la habitacion ocupada', -20010, 0, NULL);
  EXCEPTION WHEN OTHERS THEN
    resultado('H5 reactivar reserva cancelada con la habitacion ocupada', -20010, SQLCODE, SQLERRM);
  END;

  -- H6: reserva sin lineas con un servicio; luego una linea de OTRO alojamiento (dic 2027)
  SELECT id_servicio, id_alojamiento INTO v_srv, v_aloj
    FROM (SELECT id_servicio, id_alojamiento FROM servicio ORDER BY id_servicio)
   WHERE ROWNUM = 1;
  SELECT MIN(id_habitacion) INTO v_haj FROM habitacion WHERE id_alojamiento <> v_aloj;
  v_r1 := nueva_reserva(DATE '2027-12-10', DATE '2027-12-14', 'pendiente');
  SELECT MAX(id_reserva_servicio) + 1 INTO v_rs FROM reserva_servicio;
  INSERT INTO reserva_servicio (id_reserva_servicio, id_reserva, id_servicio, cantidad, precio_unitario, fecha_consumo)
  VALUES (v_rs, v_r1, v_srv, 1, 1000, DATE '2027-12-11');
  BEGIN
    v_l1 := nueva_linea(v_r1, v_haj, DATE '2027-12-10', DATE '2027-12-14');
    resultado('H6 linea de otro alojamiento en reserva con servicio previo', -20011, 0, NULL);
  EXCEPTION WHEN OTHERS THEN
    resultado('H6 linea de otro alojamiento en reserva con servicio previo', -20011, SQLCODE, SQLERRM);
  END;

  -- H7 y H8: temporadas
  BEGIN
    INSERT INTO temporada (id_temporada, nombre, anio, fecha_inicio, fecha_fin)
    VALUES ((SELECT MAX(id_temporada) + 1 FROM temporada), 'alta', 2026, DATE '2026-07-01', DATE '2026-07-05');
    resultado('H7 temporada que solapa con una existente', -20017, 0, NULL);
  EXCEPTION WHEN OTHERS THEN
    resultado('H7 temporada que solapa con una existente', -20017, SQLCODE, SQLERRM);
  END;
  BEGIN
    INSERT INTO temporada (id_temporada, nombre, anio, fecha_inicio, fecha_fin)
    VALUES ((SELECT MAX(id_temporada) + 1 FROM temporada), 'alta', 2027, DATE '2027-01-01', DATE '2027-01-15');
    resultado('H8 temporada nueva sin solape (control)', NULL, 0, NULL);
  EXCEPTION WHEN OTHERS THEN
    resultado('H8 temporada nueva sin solape (control)', NULL, SQLCODE, SQLERRM);
  END;

  DBMS_OUTPUT.PUT_LINE('Resultado H: ' || v_ok || ' OK, ' || v_mal || ' FALLA (esperado: 8 OK, 0 FALLA)');
  ROLLBACK;
  SELECT COUNT(*) INTO v_despues FROM reserva_habitacion;
  DBMS_OUTPUT.PUT_LINE('Lineas de reserva antes: ' || v_antes || ' / despues del ROLLBACK: ' || v_despues);
END;
/

ROLLBACK;
SPOOL OFF