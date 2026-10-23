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