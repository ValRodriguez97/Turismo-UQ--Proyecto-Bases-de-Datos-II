-- =================================================================================
-- TurismoUQ - Entrega 1 - Entregable 4
-- SIETE CONSULTAS DE ANALISIS
-- Bases de Datos II - codigo 12338 - periodo 2026-2
-- Oracle XE 21c
--
-- Orden de ejecucion: este script se ejecuta DESPUES de Script.sql (DDL)
-- y de Carga_TurismoUQ.sql (datos).
-- =================================================================================

SET DEFINE ON
WHENEVER SQLERROR CONTINUE

SET LINESIZE 200
SET PAGESIZE 100
SET VERIFY OFF

COLUMN municipio        FORMAT A16
COLUMN alojamiento      FORMAT A28
COLUMN tipo_alojamiento FORMAT A16
COLUMN temporada        FORMAT A22
COLUMN estado           FORMAT A14
COLUMN tendencia        FORMAT A12


-- =================================================================================
-- CONSULTA 1 - OCUPACION POR MUNICIPIO Y MES (PIVOT)
-- =================================================================================
SELECT *
FROM (
     SELECT m.nombre AS municipio,
          TO_CHAR(rh.fecha_checkin_linea, 'YYYY') AS anio,
          TO_CHAR(rh.fecha_checkin_linea, 'MM') AS mes,
          rh.fecha_checkout_linea - rh.fecha_checkin_linea AS noches
     FROM reserva r 
     JOIN reserva_habitacion rh ON rh.id_reserva = r.id_reserva
     JOIN habitacion h ON h.id_habitacion = rh.id_habitacion
     JOIN alojamiento a ON a.id_alojamiento = h.id_alojamiento
     JOIN municipio m ON m.id_municipio = a.id_municipio
     WHERE r.estado IN ('confirmada', 'completada')
)
PIVOT (
     SUM(noches)
     FOR mes IN ('01' AS enero, '02' AS febrero, '03' AS marzo, '04' AS abril,
                 '05' AS mayo, '06' AS junio, '07' AS julio, '08' AS agosto,
                 '09' AS septiembre, '10' AS octubre, '11' AS noviembre, '12' AS diciembre)
)
ORDER BY municipio, anio; 

-- =================================================================================
-- CONSULTA 2 - INGRESOS POR MUNICIPIO, TIPO DE ALOJAMIENTO Y TEMPORADA
--              (ROLLUP + GROUPING)
-- =================================================================================
SELECT CASE WHEN GROUPING(m.nombre) = 1 THEN 'TOTAL GENERAL'
          ELSE m.nombre
     END AS municipio,
     CASE WHEN GROUPING(m.nombre) = 1 THEN 'TOTAL GENERAL'
          WHEN GROUPING(ta.nombre) = 1 THEN 'Subtotal del municipio'
          ELSE ta.nombre
     END AS tipo_alojamiento,
     CASE WHEN GROUPING(m.nombre) = 1 THEN 'TOTAL GENERAL'
          WHEN GROUPING(ta.nombre) = 1 THEN 'Subtotal del municipio'
          WHEN GROUPING(t.nombre) = 1 THEN 'Subtotal del tipo'
          ELSE t.nombre
     END AS temporada,
     SUM(rh.valor_calculado) AS ingreso
FROM reserva_habitacion rh
JOIN reserva r ON r.id_reserva = rh.id_reserva
JOIN habitacion h ON h.id_habitacion = rh.id_habitacion
JOIN alojamiento a ON a.id_alojamiento  = h.id_alojamiento
JOIN tipo_alojamiento ta ON ta.id_tipo_alojamiento = a.id_tipo_alojamiento
JOIN municipio m ON m.id_municipio = a.id_municipio
INNER JOIN temporada t ON rh.fecha_checkin_linea BETWEEN t.fecha_inicio AND t.fecha_fin
WHERE r.estado IN ('confirmada','completada')
GROUP BY ROLLUP (m.nombre, ta.nombre, t.nombre)
ORDER BY GROUPING(m.nombre), m.nombre NULLS LAST,
     GROUPING(ta.nombre),ta.nombre NULLS LAST,
     GROUPING(t.nombre), t.nombre NULLS LAST;


-- =================================================================================
-- CONSULTA 3 - LOS 3 ALOJAMIENTOS DE MAYOR INGRESO DENTRO DE CADA MUNICIPIO
--              (RANK con PARTITION BY)
-- =================================================================================
SELECT municipio, puesto, alojamiento, ingreso
FROM (SELECT m.nombre AS municipio,
          a.nombre AS alojamiento,
          SUM(rh.valor_calculado) AS ingreso,
          RANK() OVER (PARTITION BY m.nombre
                            ORDER BY SUM(rh.valor_calculado) DESC) AS puesto
     FROM reserva_habitacion rh
     JOIN reserva r ON r.id_reserva = rh.id_reserva
     JOIN habitacion h ON h.id_habitacion = rh.id_habitacion
     JOIN alojamiento a ON a.id_alojamiento = h.id_alojamiento
     JOIN municipio m ON m.id_municipio = a.id_municipio
     WHERE r.estado IN ('confirmada','completada')
     GROUP BY m.nombre, a.nombre
)
 WHERE puesto <= 3
 ORDER BY municipio, puesto, alojamiento;


-- =================================================================================
-- CONSULTA 4 - VARIACION DE INGRESOS MES CONTRA MES (LAG)
-- =================================================================================
SELECT anio, mes, ingreso,
       LAG(ingreso) OVER (ORDER BY anio, mes) AS ingreso_mes_anterior,
       ingreso - LAG(ingreso) OVER (ORDER BY anio,mes) AS variacion,
       ROUND(100 * (ingreso - LAG(ingreso) OVER (ORDER BY anio, mes))
                 / NULLIF(LAG(ingreso) OVER (ORDER BY anio, mes), 0), 2) AS variacion_pct
FROM (
     SELECT TO_CHAR(rh.fecha_checkin_linea, 'YYYY') AS anio,
          TO_CHAR(rh.fecha_checkin_linea, 'MM') AS mes,
          SUM(rh.valor_calculado) AS ingreso
     FROM reserva_habitacion rh
     JOIN reserva r ON r.id_reserva = rh.id_reserva
     WHERE r.estado IN ('confirmada','completada')
     GROUP BY TO_CHAR(rh.fecha_checkin_linea, 'YYYY'),
               TO_CHAR(rh.fecha_checkin_linea, 'MM')
)
 ORDER BY anio, mes;

-- =================================================================================
-- CONSULTA 5 - CONSULTA PARAMETRIZADA (RANGO DE FECHAS)
-- =================================================================================
-- VARIABLES DE ENLACE (BIND) Ejecutar con f5

VARIABLE b_fecha_ini VARCHAR2(10)
VARIABLE b_fecha_fin VARCHAR2(10)

EXECUTE :b_fecha_ini := '01/01/2026';
EXECUTE :b_fecha_fin := '30/06/2026';

SELECT TO_CHAR(TO_DATE(:b_fecha_ini, 'DD/MM/YYYY'), 'DD/MM/YYYY') AS desde,
        TO_CHAR(TO_DATE(:b_fecha_fin, 'DD/MM/YYYY'), 'DD/MM/YYYY') AS hasta,
        m.nombre AS municipio,
        a.nombre AS alojamiento,
        COUNT(DISTINCT r.id_reserva) AS reservas,
        SUM(rh.fecha_checkout_linea - rh.fecha_checkin_linea) AS noches_vendidas,
        SUM(rh.valor_calculado) AS ingreso
 FROM reserva_habitacion rh
 JOIN reserva r ON r.id_reserva = rh.id_reserva
 JOIN habitacion h ON h.id_habitacion = rh.id_habitacion
 JOIN alojamiento a ON a.id_alojamiento = h.id_alojamiento
 JOIN municipio m ON m.id_municipio = a.id_municipio
 WHERE r.estado IN ('confirmada','completada')
    AND rh.fecha_checkin_linea BETWEEN TO_DATE(:b_fecha_ini,'DD/MM/YYYY')
                                   AND TO_DATE(:b_fecha_fin,'DD/MM/YYYY')
  GROUP BY m.nombre, a.nombre
  ORDER BY ingreso DESC;

-- Consulta parametrizada con &&
-- SELECT TO_CHAR(TO_DATE('&&p_fecha_ini', 'DD/MM/YYYY'), 'DD/MM/YYYY') AS desde,
--       TO_CHAR(TO_DATE('&&p_fecha_fin', 'DD/MM/YYYY'), 'DD/MM/YYYY') AS hasta,
--       m.nombre AS municipio,
--       a.nombre AS alojamiento,
--       COUNT(DISTINCT r.id_reserva) AS reservas,
--       SUM(rh.fecha_checkout_linea - rh.fecha_checkin_linea) AS noches_vendidas,
--       SUM(rh.valor_calculado) AS ingreso
-- FROM reserva_habitacion rh
-- JOIN reserva r ON r.id_reserva = rh.id_reserva
-- JOIN habitacion h ON h.id_habitacion = rh.id_habitacion
-- JOIN alojamiento a ON a.id_alojamiento = h.id_alojamiento
-- JOIN municipio m ON m.id_municipio = a.id_municipio
-- WHERE r.estado IN ('confirmada','completada')
--    AND rh.fecha_checkin_linea BETWEEN TO_DATE('&p_fecha_ini','DD/MM/YYYY')
--                                   AND TO_DATE('&p_fecha_fin','DD/MM/YYYY')
-- GROUP BY m.nombre, a.nombre
-- ORDER BY ingreso DESC;

-- UNDEFINE p_fecha_ini
-- UNDEFINE p_fecha_fin


-- =================================================================================
-- CONSULTA 6 - DISTRIBUCION DE RESERVAS POR ESTADO Y MUNICIPIO (UNPIVOT)
-- =================================================================================
SELECT municipio, estado, cantidad
FROM (
     SELECT m.nombre AS municipio,
     COUNT(DISTINCT CASE WHEN r.estado = 'pendiente' THEN r.id_reserva END) AS pendiente,
          COUNT(DISTINCT CASE WHEN r.estado = 'confirmada' THEN r.id_reserva END) AS confirmada,
          COUNT(DISTINCT CASE WHEN r.estado = 'completada' THEN r.id_reserva END) AS completada,
          COUNT(DISTINCT CASE WHEN r.estado = 'cancelada'  THEN r.id_reserva END) AS cancelada,
          COUNT(DISTINCT r.id_reserva) AS total_municipio
     FROM reserva r
     JOIN reserva_habitacion rh ON rh.id_reserva = r.id_reserva
     JOIN habitacion h ON h.id_habitacion = rh.id_habitacion
     JOIN alojamiento a ON a.id_alojamiento = h.id_alojamiento
     JOIN municipio m ON m.id_municipio = a.id_municipio
     GROUP BY m.nombre
)
UNPIVOT (
     cantidad 
     FOR estado IN (
          pendiente  AS 'pendiente',
          confirmada AS 'confirmada',
          completada AS 'completada',
          cancelada  AS 'cancelada')
)
 ORDER BY municipio, estado;


-- =================================================================================
-- CONSULTA 7 - CONSULTA LIBRE
-- CARTERA POR COBRAR EN RESERVAS ACTIVAS, POR MUNICIPIO
-- Aplica la regla de negocio: "Reserva pagada": una reserva está pagada solo si la suma 
-- de sus pagos 'exitoso' >= valor_calculado + servicios.
-- Los pagos fallidos, pendientes y reembolsados NO cuentan.
-- =================================================================================
WITH estadia AS (
     -- Valor de la estadia y municipio de cada reserva activa (no cancelada).
     SELECT r.id_reserva,
          MIN(m.nombre) AS municipio,
          SUM(rh.valor_calculado) AS valor_estadia
     FROM reserva r
     JOIN reserva_habitacion rh ON rh.id_reserva = r.id_reserva
     JOIN habitacion h ON h.id_habitacion = rh.id_habitacion
     JOIN alojamiento a ON a.id_alojamiento = h.id_alojamiento
     JOIN municipio m ON m.id_municipio = a.id_municipio
     WHERE r.estado IN ('pendiente', 'confirmada', 'completada')
     GROUP BY r.id_reserva, m.nombre
),
servicios AS (
     -- Valor de los servicios contratados en cada reserva.
     SELECT id_reserva,
          SUM(cantidad * precio_unitario) AS valor_servicios
     FROM reserva_servicio
     GROUP BY id_reserva
),
pagos AS (
     -- Solo los pagos EXITOSOS cuentan como abono.
     SELECT id_reserva,
          SUM(monto) AS pagado
     FROM pago
     WHERE estado_pago = 'exitoso'
     GROUP BY id_reserva
),
reservas AS (
     SELECT e.id_reserva,
          e.municipio,
          e.valor_estadia + NVL(s.valor_servicios,0) AS valor_total,
          NVL(p.pagado,0) AS pagado
     FROM estadia e
     LEFT JOIN servicios s ON s.id_reserva = e.id_reserva
     LEFT JOIN pagos p ON p.id_reserva = e.id_reserva
)
SELECT municipio,
     COUNT(*) AS reservas_activas,
     SUM(CASE WHEN valor_total > 0 AND pagado >= valor_total THEN 1 ELSE 0 END) AS pagadas,
     SUM(CASE WHEN pagado < valor_total THEN 1 ELSE 0 END) AS con_saldo,
     SUM(valor_total) AS valor_comprometido,
     SUM(pagado) AS ya_recaudado,
     SUM(CASE WHEN pagado < valor_total THEN valor_total - pagado ELSE 0 END) AS cartera_por_cobrar,
       ROUND(100 * SUM(CASE WHEN pagado < valor_total THEN valor_total - pagado ELSE 0 END)
               / NULLIF(SUM(SUM(CASE WHEN pagado < valor_total THEN valor_total - pagado ELSE 0 END)) OVER (),0), 2) AS pct_cartera_municipio
FROM reservas
GROUP BY municipio
ORDER BY cartera_por_cobrar DESC;