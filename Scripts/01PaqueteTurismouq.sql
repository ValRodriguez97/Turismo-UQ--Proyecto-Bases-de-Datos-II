-- =======================================================
-- TurismoUQ - Entrega 2 - Capa PL/SQL
-- SCRIPT 1: FUNCION, PROCEDIMIENTO, CURSOR Y PAQUETE
-- 
-- Valentina Gonzalez Diaz
-- Raquel Lopez Aristizabal
-- Valentina Rodriguez Castro
--
-- Orden de ejecución: despues del DDL y de la carga de datos
-- =======================================================

-- Permisos ejecutados en System
-- GRANT CREATE TABLE, CREATE SEQUENCE, CREATE TRIGGER, CREATE VIEW, CREATE PROCEDURE, CREATE MATERIALIZED VIEW TO #nombreconexion;
-- ALTER USER #usuario QUOTA UNLIMITED ON users;

-- =======================================================
-- 0. OBJETOS DE APOYO
-- =======================================================
SET SERVEROUTPUT ON
WHENEVER SQLERROR CONTINUE

-- 0.1 Secuencias para los ids de RESERVA y RESERVA_HABITACION
-- Arrancan en MAX+1
-- Se borran si ya existen para poder re-ejecutar el script.
DECLARE 
      v_n NUMBER;
BEGIN
      BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_reserva';
      EXCEPTION WHEN OTHERS THEN IF SQLCODE != -2289 THEN RAISE; END IF; END;
      BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_reserva_hab';
      EXCEPTION WHEN OTHERS THEN IF SQLCODE != -2289 THEN RAISE; END IF; END;

      SELECT NVL(MAX(id_reserva), 0) + 1 INTO v_n FROM reserva;
      EXECUTE IMMEDIATE 'CREATE SEQUENCE seq_reserva START WITH ' || v_n || ' INCREMENT BY 1 NOCACHE';

      SELECT NVL(MAX(id_reserva_hab), 0) + 1 INTO v_n FROM reserva_habitacion;
      EXECUTE IMMEDIATE 'CREATE SEQUENCE seq_reserva_hab START WITH ' || v_n || ' INCREMENT BY 1 NOCACHE';
END;
/

-- 0.2 Tabla donde el cursor de liquidación guarda su resultado
BEGIN 
      EXECUTE IMMEDIATE 'DROP TABLE liquidacion_mensual PURGE';
EXCEPTION WHEN OTHERS THEN IF SQLCODE != -942 THEN RAISE; END IF;
END;
/

-- Liquidación mensual por alojamiento: una fila por alojamiento, año y mes.
-- UNIQUE (anio, mes, id_alojamiento) permite recalcular un mes sin duplicar filas
CREATE TABLE TABLE liquidacion_mensual (
      id_liquidacion INTEGER GENERATED ALWAYS AS IDENTITY,
      anio INTEGER NOT NULL,
      mes INTEGER NOT NULL,
      id_alojamiento INTEGER NOT NULL,
      reservas INTEGER NOT NULL,
      noches_vendidas INTEGER NOT NULL,
      ingreso_estadias NUMBER(14,2) NOT NULL,
      ingreso_servicios NUMBER(14,2) NOT NULL,
      total_liquidado NUMBER(14,2) NOT NULL,
      fecha_proceso DATE DEFAULT SYSDATE NOT NULL,
      CONSTRAINT liq_mes_ck CHECK (mes BETWEEN 1 AND 12),
      CONSTRAINT liq_uq UNIQUE (anio, mes, id_alojamiento)
);
ALTER TABLE liquidacion_mensual ADD CONSTRAINT liquidacion_mensual_pk PRIMARY KEY (id_liquidacion);
ALTER TABLE liquidacion_mensual ADD CONSTRAINT liq_alojamiento_fk
      FOREIGN KEY (id_alojamiento) REFERENCES alojamiento (id_alojamiento);
COMMENT ON TABLE liquidacion_mensual IS 'Resultado del cursos de liquidacion mensual: ingresos por estadias y servicios de cada alojamiento en un mes.';

-- =======================================================
-- 1. PAQUETE pkg_turismouq - ESPECIFICACION
-- =======================================================
CREATE OR REPLACE PACKAGE pkg_turismouq AS

      -- Excepciones propias
      e_fechas_invalidas EXCEPTION;
      PRAGMA EXCEPTION_INIT(e_fechas_invalidas, -20001);
      e_hab_no_disponible EXCEPTION;
      PRAGMA EXCEPTION_INIT(e_hab_no_disponible, -20002);
      e_capacidad_excedida EXCEPTION;
      PRAGMA EXCEPTION_INIT(e_capacidad_excedida, -20003);
      e_hab_inexistente EXCEPTION; 
      PRAGMA EXCEPTION_INIT(e_hab_inexistente, -20004);
      e_cliente_inexist EXCEPTION;
      PRAGMA EXCEPTION_INIT(e_cliente_inexist, -20005);
      e_sin_tarifa EXCEPTION; 
      PRAGMA EXCEPTION_INIT(e_sin_tarifa, -20006);
      e_temporadas_solapadas EXCEPTION; 
      PRAGMA EXCEPTION_INIT(e_temporadas_solapadas, -20007);
      e_huespedes_invalidos EXCEPTION; 
      PRAGMA EXCEPTION_INIT(e_huespedes_invalidos, -20008);
      e_periodo_invalido EXCEPTION; 
      PRAGMA EXCEPTION_INIT(e_periodo_invalido, -20020);


      -- Valor de una estadia noche por noche según la temporada de cada noche
      FUNCTION fn_valor_estadia (
            p_id_habitacion IN habitacion.id_habitacion%TYPE,
            p_fecha_in IN DATE,
            p_fecha_out IN DATE
      ) RETURN NUMBER;

      -- Crea una reserva validando todo
      PROCEDURE sp_crear_reserva (
            p_id_cliente IN cliente.id_cliente%TYPE,
            p_id_habitacion IN habitacion.id_habitacion%TYPE,
            p_checkin IN DATE,
            p_checkout IN DATE,
            p_num_huespedes IN NUMBER,
            p_id_reserva OUT reserva.id_reserva%TYPE
      );

      -- Liquidación mensual por alojamiento
      PROCEDURE sp_liquidacion_mensual (
            p_anio IN NUMBER,
            p_mes IN NUMBER
      );
END pkg_turismouq;
/

-- =======================================================
-- 2. PAQUETE pkg_turismouq - CUERPO (implementacioó)
-- =======================================================
CREATE OR REPLACE PACKAGE BODY pkg_turismouq AS
      -- 2.1 FUNCION fn_valor_estadia
      -- Genera una fila por cada noche con CONNECT BY, ubica la temporada
      -- de cada noche y toma el precio_noche de TARIFA para esa habitación 
      -- y esa temporada. 
      FUNCTION fn_valor_estadia (
            p_id_habitacion IN habitacion.id_habitacion%TYPE,
            p_fecha_in IN DATE,
            p_fecha_out IN DATE
      ) RETURN NUMBER IS 
            v_in DATE := TRUNC(p_fecha_in);
            v_out DATE := TRUNC(p_fecha_out);
            v_noches NUMBER; -- noches que tiene la estadia
            v_filas NUMBER; -- filas noche+temporada+tarifa encontradas
            v_distintas NUMBER; -- noches distintas cubiertas
            v_valor NUMBER;
            v_existe NUMBER;
      BEGIN
            IF p_id_habitacion IS NULL OR v_in IS NULL OR v_out IS NULL OR v_out <= v_in THEN
                  RAISE_APPLICATION_ERROR(-20001,
                        'Fechas invalidas: el check-out debe ser posterior al check-in');
            END IF;

            SELECT COUNT(*) INTO v_existe FROM habitacion WHERE id_habitacion = p_id_habitacion;
            IF v_existe = 0 THEN
                  RAISE_APPLICATION_ERROR(-20004,
                  'La habitacion ' || p_id_habitacion || ' no existe');
            END IF;

            v_noches := v_out - v_in;

            SELECT COUNT(*), COUNT(DISTINCT n.noche), NVL(SUM(tf.precio_noche), 0)
            INTO v_filas, v_distintas, v_valor
            FROM (SELECT v_in + LEVEL - 1 AS noche
                  FROM dual
                  CONNECT BY LEVEL <= v_noches) n
            JOIN temporada t ON n.noche BETWEEN t.fecha_inicio AND t.fecha_fin
            JOIN tarifa tf ON tf.id_temporada = t.id_temporada
                          AND tf.id_habitacion = p_id_habitacion;

            -- Una noche con dos temporadas se contaria dos veces
            IF v_filas > v_distintas THEN
                  RAISE_APPLICATION_ERROR(-20007,
                        'Temporadas solapadas: hay noches con mas de una temporada/tarifa');
            END IF;

            -- Regla 8: sin temporada o tarifa vigente no se puede reservar
            IF v_distintas < v_noches THEN
                  RAISE_APPLICATION_ERROR(-20006,
                        'Hay ' || (v_noches - v_distintas) || ' noche(s) sin temporada o tarifa ' ||
                  'vigente para la habitacion ' || p_id_habitacion);
            END IF;

            RETURN v_valor;
      END fn_valor_estadia;

      -- 2.2 PROCEDIMIENTO sp_crear_reserva
      -- Orden de validaciones: fechas -> cliente -> habitacion/capacidad -> disponibilidad
      -- -> calculo del valor -> insercion
      -- Una habitacion esta ocupada si tiene una reserva ACTIVA que cruce el rango
      -- No hace COMMIT: el llamador decide. Si falla un INSERT, se deshace con
      -- ROLLBACK TO SAVEPOINT para no dejar el encabezado sin su linea.
      PROCEDURE sp_crear_reserva (
            p_id_cliente IN  cliente.id_cliente%TYPE,
            p_id_habitacion IN habitacion.id_habitacion%TYPE,
            p_checkin IN DATE,
            p_checkout IN DATE,
            p_num_huespedes IN NUMBER,
            p_id_reserva OUT reserva.id_reserva%TYPE
      ) IS
            v_in DATE := TRUNC(p_checkin);
            v_out DATE := TRUNC(p_checkout);
            v_capacidad habitacion.capacidad_max%TYPE;
            v_existe NUMBER;
            v_choques NUMBER;
            v_valor NUMBER;
      BEGIN
            -- 1. Fechas
            IF v_in IS NULL OR v_out IS NULL OR v_out <= v_in THEN
                  RAISE_APPLICATION_ERROR(-20001,
                  'Fechas invalidas: el check-out debe ser posterior al check-in');
            END IF;

            -- 2. El cliente existe
            SELECT COUNT(*) INTO v_existe FROM cliente WHERE id_cliente = p_id_cliente;
            IF v_existe = 0 THEN
                  RAISE_APPLICATION_ERROR(-20005,
                  'El cliente ' || p_id_cliente || ' no existe');
            END IF;

            -- 3. La habitacion existe
            BEGIN
                  SELECT capacidad_max INTO v_capacidad
                  FROM habitacion WHERE id_habitacion = p_id_habitacion;
            EXCEPTION
                  WHEN NO_DATA_FOUND THEN
                  RAISE_APPLICATION_ERROR(-20004,
                        'La habitacion ' || p_id_habitacion || ' no existe');
            END;

            -- 3b. Huespedes: dato valido y dentro de la capacidad 
            IF p_num_huespedes IS NULL OR p_num_huespedes < 1 THEN
                  RAISE_APPLICATION_ERROR(-20008,
                  'Numero de huespedes invalido: debe ser al menos 1');
            END IF;
            IF p_num_huespedes > v_capacidad THEN
                  RAISE_APPLICATION_ERROR(-20003,
                  'Capacidad excedida: la habitacion admite maximo ' || v_capacidad ||
                  ' huespedes y se pidieron ' || p_num_huespedes);
            END IF;

            --  4. Disponibilidad: ninguna linea NO cancelada puede cruzar [checkin, checkout]
            -- el dia de salida queda libre para el siguiente ingreso
            SELECT COUNT(*) INTO v_choques
            FROM reserva_habitacion rh
            JOIN reserva r ON r.id_reserva = rh.id_reserva
            WHERE rh.id_habitacion = p_id_habitacion
            AND r.estado IN ('pendiente', 'confirmada', 'completada')
            AND rh.fecha_checkin_linea  < v_out
            AND rh.fecha_checkout_linea > v_in;

            IF v_choques > 0 THEN
                  RAISE_APPLICATION_ERROR(-20002,
                  'Habitacion no disponible: esta ocupada entre ' ||
                  TO_CHAR(v_in, 'DD/MM/YYYY') || ' y ' || TO_CHAR(v_out, 'DD/MM/YYYY'));
            END IF;

            -- 5. Valor de la estadia (cruza temporadas noche por noche)
            v_valor := fn_valor_estadia(p_id_habitacion, v_in, v_out);

            -- 6. Insertar encabezado y linea
            SAVEPOINT antes_de_insertar;
            BEGIN
                  p_id_reserva := seq_reserva.NEXTVAL;

                  INSERT INTO reserva (id_reserva, id_cliente, fecha_reserva, checkin, checkout, estado)
                  VALUES (p_id_reserva, p_id_cliente, TRUNC(SYSDATE), v_in, v_out, 'pendiente');

                  INSERT INTO reserva_habitacion
                  (id_reserva_hab, id_reserva, id_habitacion, fecha_checkin_linea,
                  fecha_checkout_linea, num_huespedes, valor_calculado)
                  VALUES
                  (seq_reserva_hab.NEXTVAL, p_id_reserva, p_id_habitacion, v_in, v_out,
                  p_num_huespedes, v_valor);
            EXCEPTION
                  WHEN OTHERS THEN
                  ROLLBACK TO antes_de_insertar;
                  p_id_reserva := NULL;
                  RAISE;
            END;
            DBMS_OUTPUT.PUT_LINE('Reserva ' || p_id_reserva || ' creada. Valor estadia: ' || v_valor);
      END sp_crear_reserva;

      -- 2.3 PROCEDIMINETO sp_liquidacion_mensual 
      -- por cada alojamiento suma lo generado en el mes

      PROCEDURE sp_liquidacion_mensual (
            p_anio IN NUMBER,
            p_mes IN NUMBER
      ) IS 
            v_ini DATE;
            v_fin DATE;
            v_total NUMBER;
            v_gran NUMBER := 0;
            v_filas NUMBER := 0;

            -- Cursor explicito
            CURSOR c_liq (cp_ini DATE, cp_fin DATE) IS
                  SELECT a.id_alojamiento, a.nombre, 
                        NVL(e.reservas, 0) AS reservas,
                        NVL(e.noches, 0) AS noches,
                        NVL(e.ingreso_estadia, 0) AS ingreso_estadia,
                        NVL(s.ingreso_servicios, 0) AS ingreso_servicios
                  FROM alojamiento a
                  LEFT JOIN (SELECT h.id_alojamiento,
                                    COUNT(DISTINCT r.id_reserva) AS reservas,
                                    SUM(rh.fecha_checkout_linea -  rh.fecha_checkin_linea) AS noches,
                                    SUM(rh.valor_calculado) AS ingreso_estadia
                              FROM reserva_habitacion rh
                              JOIN reserva r ON r.id_reserva = rh.id_reserva
                              JOIN habitacion h ON h.id_habitacion = rh.id_habitacion
                              WHERE r.estado IN ('confirmada', 'completada')
                                    AND rh.fecha_checkin_linea >= cp_ini
                                    AND rh.fecha_checkin_linea < cp_fin
                              GROUP BY h.id_alojamiento) e 
                        ON e.id_alojamiento = a.id_alojamiento
                  LEFT JOIN (SELECT sv.id_alojamiento, SUM(rs.cantidad * rs.precio_unitario) AS ingreso_servicios
                              FROM reserva_servicio rs
                              JOIN servicio sv ON sv.id_servicio = rs.id_servicio
                              JOIN reserva r ON r.id_reserva = rs.id_reserva
                              WHERE r.estado IN ('confirmada', 'completada')
                                    AND rs.fecha_consumo >= cp_ini
                                    AND rs.fecha_consumo < cp_fin
                              GROUP BY sv.id_alojamiento) s
                        ON s.id_alojamiento = a.id_alojamiento
                  ORDER BY a.id_alojamiento;
            v_reg c_liq%ROWTYPE;
      BEGIN
            IF p_anio IS NULL OR p_mes IS NULL OR p_mes NOT BETWEEN 1 AND 12 THEN
                  RAISE_APPLICATION_ERROR(-20020, 
                        'Periodo invalido: mes entre 1 y 12 y anio obligatorio');
            END IF;

            v_ini := TO_DATE(LPAD(p_mes,2,'0') || '/' || p_anio, 'MM/YYYY');
            v_fin := ADD_MONTHS(v_ini, 1);
                              
            -- Recalcular un mes: borrar lo anterior de ese periodo
            DELETE FROM liquidacion_mensual WHERE anio = p_anio AND mes = p_mes;

            DBMS_OUTPUT.PUT_LINE('LIQUIDACION ' || LPAD(p_mes,2,'0') || '/' || p_anio);

            OPEN c_liq(v_ini, v_fin);
            LOOP
                  FETCH c_liq INTO v_reg;
                  EXIT WHEN c_liq%NOTFOUND;

                  -- Solo se liquidan los alojamientos con movimiento en el mes
                  IF v_reg.reservas > 0 OR v_reg.ingreso_servicios > 0 THEN
                  v_total := v_reg.ingreso_estadia + v_reg.ingreso_servicios;

                  INSERT INTO liquidacion_mensual
                        (anio, mes, id_alojamiento, reservas, noches_vendidas,
                        ingreso_estadias, ingreso_servicios, total_liquidado)
                  VALUES
                        (p_anio, p_mes, v_reg.id_alojamiento, v_reg.reservas, v_reg.noches,
                        v_reg.ingreso_estadia, v_reg.ingreso_servicios, v_total);

                  v_gran  := v_gran + v_total;
                  v_filas := v_filas + 1;
                  DBMS_OUTPUT.PUT_LINE(RPAD(v_reg.nombre, 32) || ' reservas: ' ||
                        LPAD(v_reg.reservas, 3) || ' | total: ' ||
                        TO_CHAR(v_total, 'FM999,999,999,990'));
                  END IF;
            END LOOP;
            DBMS_OUTPUT.PUT_LINE('Alojamientos liquidados: ' || v_filas ||
                  ' de ' || c_liq%ROWCOUNT || ' recorridos');
            CLOSE c_liq;

            DBMS_OUTPUT.PUT_LINE('TOTAL GENERAL: ' || TO_CHAR(v_gran, 'FM999,999,999,990'));
            COMMIT;   
      EXCEPTION
            WHEN OTHERS THEN
                  IF c_liq%ISOPEN THEN CLOSE c_liq; END IF;
                  ROLLBACK;
                  RAISE;
      END sp_liquidacion_mensual;

END pkg_turismouq;
/
SHOW ERRORS PACKAGE BODY pkg_turismouq