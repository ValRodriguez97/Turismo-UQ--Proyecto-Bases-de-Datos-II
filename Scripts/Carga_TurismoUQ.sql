-- =============================================================
-- TurismoUQ 
-- =============================================================
SET DEFINE OFF;
WHENEVER SQLERROR EXIT SQL.SQLCODE;
SET SERVEROUTPUT ON;

-- ---------- 1. MUNICIPIO (12) ----------
INSERT ALL
  INTO municipio (id_municipio, nombre) VALUES (1,'Armenia')
  INTO municipio (id_municipio, nombre) VALUES (2,'Calarca')
  INTO municipio (id_municipio, nombre) VALUES (3,'Montenegro')
  INTO municipio (id_municipio, nombre) VALUES (4,'Quimbaya')
  INTO municipio (id_municipio, nombre) VALUES (5,'La Tebaida')
  INTO municipio (id_municipio, nombre) VALUES (6,'Circasia')
  INTO municipio (id_municipio, nombre) VALUES (7,'Salento')
  INTO municipio (id_municipio, nombre) VALUES (8,'Filandia')
  INTO municipio (id_municipio, nombre) VALUES (9,'Pijao')
  INTO municipio (id_municipio, nombre) VALUES (10,'Buenavista')
  INTO municipio (id_municipio, nombre) VALUES (11,'Cordoba')
  INTO municipio (id_municipio, nombre) VALUES (12,'Genova')
SELECT 1 FROM DUAL;
COMMIT;

-- ---------- 2. TIPO_ALOJAMIENTO (4) ----------
INSERT ALL
  INTO tipo_alojamiento (id_tipo_alojamiento, nombre, descripcion) VALUES (1,'finca cafetera','Finca tradicional con cultivo de cafe y alojamiento rural')
  INTO tipo_alojamiento (id_tipo_alojamiento, nombre, descripcion) VALUES (2,'hotel','Hotel urbano o de carretera con servicios completos')
  INTO tipo_alojamiento (id_tipo_alojamiento, nombre, descripcion) VALUES (3,'glamping','Alojamiento de lujo en medio de la naturaleza')
  INTO tipo_alojamiento (id_tipo_alojamiento, nombre, descripcion) VALUES (4,'hostal','Alojamiento economico, ideal mochileros')
SELECT 1 FROM DUAL;
COMMIT;

-- ---------- 3. ROL (4) ----------
INSERT ALL
  INTO rol (id_rol, nombre, descripcion) VALUES (1,'recepcion','Atiende reservas via vistas, sin acceso directo a tablas')
  INTO rol (id_rol, nombre, descripcion) VALUES (2,'admin_alojamiento','Encargado que gestiona su propio alojamiento')
  INTO rol (id_rol, nombre, descripcion) VALUES (3,'gerente','Ve reportes globales de la plataforma')
  INTO rol (id_rol, nombre, descripcion) VALUES (4,'auditor','Solo lectura para control')
SELECT 1 FROM DUAL;
COMMIT;

-- ---------- 4. CIUDAD (38) ----------
INSERT ALL
  INTO ciudad (id_ciudad, nombre, departamento) VALUES (1,'Bogota','Cundinamarca')
  INTO ciudad (id_ciudad, nombre, departamento) VALUES (2,'Medellin','Antioquia')
  INTO ciudad (id_ciudad, nombre, departamento) VALUES (3,'Cali','Valle del Cauca')
  INTO ciudad (id_ciudad, nombre, departamento) VALUES (4,'Barranquilla','Atlantico')
  INTO ciudad (id_ciudad, nombre, departamento) VALUES (5,'Cartagena','Bolivar')
  INTO ciudad (id_ciudad, nombre, departamento) VALUES (6,'Santa Marta','Magdalena')
  INTO ciudad (id_ciudad, nombre, departamento) VALUES (7,'Pereira','Risaralda')
  INTO ciudad (id_ciudad, nombre, departamento) VALUES (8,'Manizales','Caldas')
  INTO ciudad (id_ciudad, nombre, departamento) VALUES (9,'Bucaramanga','Santander')
  INTO ciudad (id_ciudad, nombre, departamento) VALUES (10,'Cucuta','Norte de Santander')
  INTO ciudad (id_ciudad, nombre, departamento) VALUES (11,'Ibague','Tolima')
  INTO ciudad (id_ciudad, nombre, departamento) VALUES (12,'Neiva','Huila')
  INTO ciudad (id_ciudad, nombre, departamento) VALUES (13,'Villavicencio','Meta')
  INTO ciudad (id_ciudad, nombre, departamento) VALUES (14,'Pasto','Narino')
  INTO ciudad (id_ciudad, nombre, departamento) VALUES (15,'Popayan','Cauca')
  INTO ciudad (id_ciudad, nombre, departamento) VALUES (16,'Tunja','Boyaca')
  INTO ciudad (id_ciudad, nombre, departamento) VALUES (17,'Valledupar','Cesar')
  INTO ciudad (id_ciudad, nombre, departamento) VALUES (18,'Monteria','Cordoba')
  INTO ciudad (id_ciudad, nombre, departamento) VALUES (19,'Sincelejo','Sucre')
  INTO ciudad (id_ciudad, nombre, departamento) VALUES (20,'Riohacha','La Guajira')
  INTO ciudad (id_ciudad, nombre, departamento) VALUES (21,'Armenia','Quindio')
  INTO ciudad (id_ciudad, nombre, departamento) VALUES (22,'Calarca','Quindio')
  INTO ciudad (id_ciudad, nombre, departamento) VALUES (23,'Montenegro','Quindio')
  INTO ciudad (id_ciudad, nombre, departamento) VALUES (24,'Salento','Quindio')
  INTO ciudad (id_ciudad, nombre, departamento) VALUES (25,'Filandia','Quindio')
  INTO ciudad (id_ciudad, nombre, departamento) VALUES (26,'Quimbaya','Quindio')
  INTO ciudad (id_ciudad, nombre, departamento) VALUES (27,'Chinchina','Caldas')
  INTO ciudad (id_ciudad, nombre, departamento) VALUES (28,'Dosquebradas','Risaralda')
  INTO ciudad (id_ciudad, nombre, departamento) VALUES (29,'Santa Rosa de Cabal','Risaralda')
  INTO ciudad (id_ciudad, nombre, departamento) VALUES (30,'Girardot','Cundinamarca')
  INTO ciudad (id_ciudad, nombre, departamento) VALUES (31,'Honda','Tolima')
  INTO ciudad (id_ciudad, nombre, departamento) VALUES (32,'La Dorada','Caldas')
  INTO ciudad (id_ciudad, nombre, departamento) VALUES (33,'Tulua','Valle del Cauca')
  INTO ciudad (id_ciudad, nombre, departamento) VALUES (34,'Buga','Valle del Cauca')
  INTO ciudad (id_ciudad, nombre, departamento) VALUES (35,'Palmira','Valle del Cauca')
  INTO ciudad (id_ciudad, nombre, departamento) VALUES (36,'Envigado','Antioquia')
  INTO ciudad (id_ciudad, nombre, departamento) VALUES (37,'Soacha','Cundinamarca')
  INTO ciudad (id_ciudad, nombre, departamento) VALUES (38,'Florencia','Caqueta')
SELECT 1 FROM DUAL;
COMMIT;

-- ---------- 5. TEMPORADA (21) ----------
INSERT ALL
  INTO temporada (id_temporada, nombre, anio, fecha_inicio, fecha_fin) VALUES (1,'alta',2024,DATE '2024-01-01',DATE '2024-01-15')
  INTO temporada (id_temporada, nombre, anio, fecha_inicio, fecha_fin) VALUES (2,'baja',2024,DATE '2024-01-16',DATE '2024-03-21')
  INTO temporada (id_temporada, nombre, anio, fecha_inicio, fecha_fin) VALUES (3,'alta',2024,DATE '2024-03-22',DATE '2024-04-01')
  INTO temporada (id_temporada, nombre, anio, fecha_inicio, fecha_fin) VALUES (4,'media',2024,DATE '2024-04-02',DATE '2024-06-10')
  INTO temporada (id_temporada, nombre, anio, fecha_inicio, fecha_fin) VALUES (5,'alta',2024,DATE '2024-06-11',DATE '2024-07-15')
  INTO temporada (id_temporada, nombre, anio, fecha_inicio, fecha_fin) VALUES (6,'baja',2024,DATE '2024-07-16',DATE '2024-12-15')
  INTO temporada (id_temporada, nombre, anio, fecha_inicio, fecha_fin) VALUES (7,'alta',2024,DATE '2024-12-16',DATE '2024-12-31')
  INTO temporada (id_temporada, nombre, anio, fecha_inicio, fecha_fin) VALUES (8,'alta',2025,DATE '2025-01-01',DATE '2025-01-15')
  INTO temporada (id_temporada, nombre, anio, fecha_inicio, fecha_fin) VALUES (9,'baja',2025,DATE '2025-01-16',DATE '2025-04-10')
  INTO temporada (id_temporada, nombre, anio, fecha_inicio, fecha_fin) VALUES (10,'alta',2025,DATE '2025-04-11',DATE '2025-04-22')
  INTO temporada (id_temporada, nombre, anio, fecha_inicio, fecha_fin) VALUES (11,'media',2025,DATE '2025-04-23',DATE '2025-06-10')
  INTO temporada (id_temporada, nombre, anio, fecha_inicio, fecha_fin) VALUES (12,'alta',2025,DATE '2025-06-11',DATE '2025-07-15')
  INTO temporada (id_temporada, nombre, anio, fecha_inicio, fecha_fin) VALUES (13,'baja',2025,DATE '2025-07-16',DATE '2025-12-15')
  INTO temporada (id_temporada, nombre, anio, fecha_inicio, fecha_fin) VALUES (14,'alta',2025,DATE '2025-12-16',DATE '2025-12-31')
  INTO temporada (id_temporada, nombre, anio, fecha_inicio, fecha_fin) VALUES (15,'alta',2026,DATE '2026-01-01',DATE '2026-01-15')
  INTO temporada (id_temporada, nombre, anio, fecha_inicio, fecha_fin) VALUES (16,'baja',2026,DATE '2026-01-16',DATE '2026-03-26')
  INTO temporada (id_temporada, nombre, anio, fecha_inicio, fecha_fin) VALUES (17,'alta',2026,DATE '2026-03-27',DATE '2026-04-07')
  INTO temporada (id_temporada, nombre, anio, fecha_inicio, fecha_fin) VALUES (18,'media',2026,DATE '2026-04-08',DATE '2026-06-10')
  INTO temporada (id_temporada, nombre, anio, fecha_inicio, fecha_fin) VALUES (19,'alta',2026,DATE '2026-06-11',DATE '2026-07-15')
  INTO temporada (id_temporada, nombre, anio, fecha_inicio, fecha_fin) VALUES (20,'baja',2026,DATE '2026-07-16',DATE '2026-12-15')
  INTO temporada (id_temporada, nombre, anio, fecha_inicio, fecha_fin) VALUES (21,'alta',2026,DATE '2026-12-16',DATE '2026-12-31')
SELECT 1 FROM DUAL;
COMMIT;

-- ---------- 6. ALOJAMIENTO (60) ----------
DECLARE
  TYPE t_arr IS VARRAY(70) OF VARCHAR2(40);
  v_mun  t_arr := t_arr(1,1,1,1,1,1,1,1,1,1,1,1,1,1, 
                        2,2,2,2,2,2,2, 
                        3,3,3,3,3,3,3, 
                        4,4,4,4,4,4, 
                        5,5,5,5, 
                        6,6,6,6, 
                        7,7,7,7,7,7, 
                        8,8,8,8,8, 
                        9,9,9, 10, 11,11, 12);
  v_nom  t_arr := t_arr('El Cafetal','La Casona','Mirador del Valle',
  'Samanes','El Recuerdo','La Esperanza','Villa Lucia','El Portal','Los Naranjos',
  'Casa Blanca','El Paraiso','La Montana','El Descanso','Villa del Rio','La Pradera',
  'El Encuentro','Los Almendros','San Jose','El Mirador','La Finca Real','Villa Cafe',
  'El Roble','La Colina','El Jardin','Las Palmas','El Bosque','La Aurora','Villa Hermosa',
  'El Camino','Santa Fe','La Rivera','El Lago','Los Pinos','El Carmen','San Pedro','La Union',
  'El Progreso','Villa Nueva','La Palma','El Tesoro','Los Andes','El Valle','La Cumbre','El Parador',
  'Villa Ana','Don Pedro','La Estrella','El Faro','Las Flores','El Diamante','La Perla','El Condor',
  'San Martin','La Victoria','El Triunfo','Villa Sofia');
  v_tipo NUMBER; v_municipio NUMBER; v_estrellas NUMBER; v_r2 NUMBER; v_anom VARCHAR2(40);
BEGIN
  DBMS_RANDOM.SEED(20260930);
  FOR i IN 1..60 LOOP
    v_municipio := v_mun(TRUNC(DBMS_RANDOM.VALUE(1, v_mun.COUNT+1)));
    v_r2 := DBMS_RANDOM.VALUE;
    IF v_r2 < 0.45 THEN v_tipo := 1;
    ELSIF v_r2 < 0.65 THEN v_tipo := 2;
    ELSIF v_r2 < 0.80 THEN v_tipo := 3;
    ELSE v_tipo := 4; END IF;
    v_estrellas := CASE v_tipo WHEN 1 THEN TRUNC(DBMS_RANDOM.VALUE(3,5)) WHEN 2 THEN TRUNC(DBMS_RANDOM.VALUE(3,6)) WHEN 3 THEN TRUNC(DBMS_RANDOM.VALUE(4,6)) ELSE TRUNC(DBMS_RANDOM.VALUE(2,4)) END;
    v_anom := v_nom(TRUNC(DBMS_RANDOM.VALUE(1, v_nom.COUNT+1)));
    INSERT INTO alojamiento (id_alojamiento, nombre, direccion, calificacion_estrellas, telefono, email, fecha_registro, id_municipio, id_tipo_alojamiento)
    VALUES (i, v_anom || ' ' || i,
      'Calle ' || TRUNC(DBMS_RANDOM.VALUE(1,60)) || ' # ' || TRUNC(DBMS_RANDOM.VALUE(1,40)) || '-' || TRUNC(DBMS_RANDOM.VALUE(1,99)),
      v_estrellas, '6067' || LPAD(TRUNC(DBMS_RANDOM.VALUE(0,100000)),5,'0'),
      'contacto' || i || '@turismouq.com', DATE '2023-01-01' + TRUNC(DBMS_RANDOM.VALUE(0,900)),
      v_municipio, v_tipo);
    IF MOD(i,20)=0 THEN COMMIT; END IF;
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('alojamiento OK');
END;
/

-- ---------- 7. HABITACION (~420) ----------
DECLARE
  v_n NUMBER; v_tipo_h VARCHAR2(15); v_cap NUMBER; v_r NUMBER; v_id NUMBER := 0;
BEGIN
  FOR a IN (SELECT id_alojamiento, id_tipo_alojamiento FROM alojamiento) LOOP
    v_n := CASE a.id_tipo_alojamiento WHEN 1 THEN TRUNC(DBMS_RANDOM.VALUE(3,6)) WHEN 2 THEN TRUNC(DBMS_RANDOM.VALUE(10,19)) WHEN 3 THEN TRUNC(DBMS_RANDOM.VALUE(4,9)) ELSE TRUNC(DBMS_RANDOM.VALUE(5,11)) END;
    FOR h IN 1..v_n LOOP
      v_r := DBMS_RANDOM.VALUE;
      IF v_r < 0.35 THEN v_tipo_h := 'sencilla'; v_cap := TRUNC(DBMS_RANDOM.VALUE(1,3));
      ELSIF v_r < 0.70 THEN v_tipo_h := 'doble'; v_cap := TRUNC(DBMS_RANDOM.VALUE(2,5));
      ELSIF v_r < 0.88 THEN v_tipo_h := 'suite'; v_cap := TRUNC(DBMS_RANDOM.VALUE(2,6));
      ELSE v_tipo_h := 'cabana'; v_cap := TRUNC(DBMS_RANDOM.VALUE(4,9)); END IF;
      v_id := v_id + 1;
      INSERT INTO habitacion (id_habitacion, id_alojamiento, numero_habitacion, capacidad_max, tipo, descripcion)
      VALUES (v_id, a.id_alojamiento, TO_CHAR(100+h), v_cap, v_tipo_h, 'Habitacion ' || v_tipo_h || ' con vista cafetera');
    END LOOP;
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('habitacion OK');
END;
/

-- ---------- 8. TARIFA ----------
DECLARE
  v_id NUMBER := 0;
  v_base NUMBER; v_mult NUMBER;
BEGIN
  FOR h IN (SELECT id_habitacion, tipo FROM habitacion) LOOP
    v_base := CASE h.tipo WHEN 'sencilla' THEN DBMS_RANDOM.VALUE(90000,140000) WHEN 'doble' THEN DBMS_RANDOM.VALUE(140000,230000) WHEN 'suite' THEN DBMS_RANDOM.VALUE(240000,420000) ELSE DBMS_RANDOM.VALUE(280000,550000) END;
    FOR t IN (SELECT id_temporada, nombre FROM temporada) LOOP
      v_mult := CASE t.nombre WHEN 'alta' THEN DBMS_RANDOM.VALUE(1.35,1.75) WHEN 'media' THEN DBMS_RANDOM.VALUE(1.10,1.25) ELSE 1.0 END;
      v_id := v_id + 1;
      INSERT INTO tarifa (id_tarifa, precio_noche, id_habitacion, id_temporada, fecha_actualizacion)
      VALUES (v_id, ROUND(v_base * v_mult, -3), h.id_habitacion, t.id_temporada, DATE '2024-01-05');
    END LOOP;
    IF MOD(h.id_habitacion, 100) = 0 THEN COMMIT; END IF;
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('tarifa OK');
END;
/

-- ---------- 9. CLIENTE (3000) ----------
DECLARE
  TYPE t_arr IS VARRAY(40) OF VARCHAR2(20);
  v_nom t_arr := t_arr('Carlos','Maria','Jose','Ana','Luis','Carmen','Juan','Rosa','Pedro','Lucia','Miguel','Elena','Jorge','Sofia',
  'Andres','Valentina','Felipe','Camila','Santiago','Isabella','Mateo','Juliana','Nicolas','Paula','Daniel','Carolina','Alejandro',
  'Fernanda','Ricardo','Tatiana','Oscar','Diana','Raul','Monica','Ernesto','Liliana','Pablo','Adriana','Gabriel','Natalia');
  v_ape t_arr := t_arr('Garcia','Rodriguez','Martinez','Lopez','Gonzalez','Perez','Sanchez','Ramirez','Cruz','Flores','Gomez','Diaz',
  'Torres','Ruiz','Alvarez','Moreno','Castillo','Vargas','Castro','Rojas','Mendoza','Aguilar','Herrera','Medina','Contreras','Guzman',
  'Ortiz','Chavez','Romero','Salazar','Paredes','Jimenez','Rios','Mora','Soto','Vega','Campos','Correa','Pinto','Zapata');
  v_dom t_arr := t_arr('gmail.com','gmail.com','hotmail.com','outlook.com','yahoo.com');
  v_n VARCHAR2(20); v_a VARCHAR2(20); v_r NUMBER; v_ciu NUMBER; v_mail VARCHAR2(90);
BEGIN
  DBMS_RANDOM.SEED(20260931);
  FOR i IN 1..3000 LOOP
    v_n := v_nom(TRUNC(DBMS_RANDOM.VALUE(1,41)));
    v_a := v_ape(TRUNC(DBMS_RANDOM.VALUE(1,41)));
    v_r := DBMS_RANDOM.VALUE(0,100);
    IF v_r < 12 THEN v_ciu := 1; ELSIF v_r < 22 THEN v_ciu := 2; ELSIF v_r < 30 THEN v_ciu := 3;
    ELSIF v_r < 36 THEN v_ciu := 7; ELSIF v_r < 42 THEN v_ciu := 8; ELSIF v_r < 47 THEN v_ciu := 9;
    ELSIF v_r < 52 THEN v_ciu := 5; ELSIF v_r < 56 THEN v_ciu := 4; ELSIF v_r < 60 THEN v_ciu := 6;
    ELSIF v_r < 64 THEN v_ciu := 11; ELSIF v_r < 68 THEN v_ciu := 13; ELSIF v_r < 71 THEN v_ciu := 10;
    ELSIF v_r < 74 THEN v_ciu := 12; ELSIF v_r < 77 THEN v_ciu := 14; ELSIF v_r < 80 THEN v_ciu := 15;
    ELSIF v_r < 82 THEN v_ciu := 21; ELSIF v_r < 84 THEN v_ciu := 7; ELSIF v_r < 86 THEN v_ciu := 28;
    ELSIF v_r < 88 THEN v_ciu := 29; ELSE v_ciu := TRUNC(DBMS_RANDOM.VALUE(16,39)); END IF;
    v_mail := LOWER(v_n) || '.' || LOWER(v_a) || i || '@' || v_dom(TRUNC(DBMS_RANDOM.VALUE(1,6)));
    INSERT INTO cliente (id_cliente, cedula, nombre, correo, telefono, id_ciudad_origen)
    VALUES (i, TO_CHAR(10000000 + i*13 + TRUNC(DBMS_RANDOM.VALUE(0,9))),
      v_n || ' ' || v_a, v_mail,
      '3' || LPAD(TRUNC(DBMS_RANDOM.VALUE(0,1000000000)),9,'0'), v_ciu);
    IF MOD(i,800)=0 THEN COMMIT; END IF;
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('cliente OK');
END;
/

-- ---------- 10. SERVICIO (30 repartidos entre alojamientos) ----------
DECLARE
  TYPE t_arr IS VARRAY(8) OF VARCHAR2(30);
  v_srv t_arr := t_arr('Desayuno','Tour cafetero','Transporte aeropuerto','Alquiler bicicletas','Spa',
  'Cena tipica','Cabalgata','Avistamiento aves');
  v_id NUMBER := 0; v_k NUMBER; v_p NUMBER; v_sn VARCHAR2(30);
BEGIN
  FOR a IN 1..60 LOOP
    EXIT WHEN v_id >= 30;
    IF DBMS_RANDOM.VALUE < 0.62 THEN
      FOR rep IN 1..2 LOOP
        EXIT WHEN v_id >= 30;
        IF rep = 2 AND DBMS_RANDOM.VALUE > 0.25 THEN EXIT; END IF;
        v_k := TRUNC(DBMS_RANDOM.VALUE(1,9));
        v_p := CASE v_k WHEN 1 THEN DBMS_RANDOM.VALUE(15000,25000) WHEN 2 THEN DBMS_RANDOM.VALUE(40000,70000) WHEN 3 THEN DBMS_RANDOM.VALUE(60000,90000) WHEN 4 THEN DBMS_RANDOM.VALUE(20000,35000) WHEN 5 THEN DBMS_RANDOM.VALUE(80000,150000) WHEN 6 THEN DBMS_RANDOM.VALUE(35000,60000) WHEN 7 THEN DBMS_RANDOM.VALUE(50000,80000) ELSE DBMS_RANDOM.VALUE(30000,50000) END;
        v_id := v_id + 1;
        v_sn := v_srv(v_k);
        INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio)
        VALUES (v_id, a, v_sn, 'Servicio de ' || LOWER(v_sn) || ' del alojamiento', ROUND(v_p,-2));
      END LOOP;
    END IF;
  END LOOP;
  WHILE v_id < 30 LOOP 
    v_k := TRUNC(DBMS_RANDOM.VALUE(1,9));
    v_p := 20000 + DBMS_RANDOM.VALUE(0,60000);
    v_id := v_id + 1;
    v_sn := v_srv(v_k);
    INSERT INTO servicio (id_servicio, id_alojamiento, nombre, descripcion, precio)
    VALUES (v_id, TRUNC(DBMS_RANDOM.VALUE(1,61)), v_sn, 'Servicio de ' || LOWER(v_sn) || ' del alojamiento', ROUND(v_p,-2));
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('servicio OK: ' || v_id);
END;
/

-- ---------- 11. USUARIO_SISTEMA (10: 1 gerente y 1 auditor sin alojamiento, 1 encargado por tipo, 3 extra, 1 recepcion) ----------
DECLARE
  v_id NUMBER := 0;
  PROCEDURE add_usu(p_login VARCHAR2, p_nom VARCHAR2, p_rol NUMBER, p_aloj NUMBER) IS
  BEGIN
    v_id := v_id + 1;
    INSERT INTO usuario_sistema (id_usuario, login, nombre, email, contrasena, id_rol, id_alojamiento, estado)
    VALUES (v_id, p_login, p_nom, p_login || '@turismouq.com', 'Temporal123*', p_rol, p_aloj, 'activo');
  END;
BEGIN
  add_usu('admin.turismo','Admin Plataforma',3,NULL);
  add_usu('auditor.ext','Auditor Externo',4,NULL);
  FOR t IN (SELECT id_tipo_alojamiento tid, MIN(id_alojamiento) a FROM alojamiento GROUP BY id_tipo_alojamiento ORDER BY 1) LOOP
    add_usu('enc.tipo' || t.tid, 'Encargado tipo ' || t.tid, 2, t.a);
  END LOOP;
  add_usu('enc.extra1','Encargado Extra Uno',2,3);
  add_usu('enc.extra2','Encargado Extra Dos',2,15);
  add_usu('enc.extra3','Encargado Extra Tres',2,30);
  add_usu('recep.hotel','Recepcion Hotel',1,7);
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('usuario OK: ' || v_id);
END;
/

-- ---------- 12. RESERVA + RESERVA_HABITACION (25000, estacional, con control de solape) ----------
DECLARE
  c_hoy CONSTANT DATE := DATE '2026-09-30';
  TYPE t_num IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
  TYPE t_dat IS TABLE OF DATE INDEX BY PLS_INTEGER;
  TYPE t_chr IS TABLE OF VARCHAR2(12) INDEX BY PLS_INTEGER;
  v_hid t_num; v_haloj t_num; v_hcap t_num; v_nhab NUMBER;
  v_tid t_num; v_tnom t_chr; v_tini t_dat; v_tfin t_dat;
  TYPE t_rng IS RECORD (ini DATE, fin DATE, est VARCHAR2(12));
  TYPE t_lst IS TABLE OF t_rng INDEX BY PLS_INTEGER;
  TYPE t_map IS TABLE OF t_lst INDEX BY PLS_INTEGER;
  v_ocup t_map; v_tmp t_lst;
  v_rh NUMBER := 0; v_mes NUMBER; v_anio NUMBER; v_r NUMBER;
  v_in DATE; v_out DATE; v_noches NUMBER; v_fres DATE; v_est VARCHAR2(12);
  v_aloj NUMBER; v_nlin NUMBER; v_hab NUMBER; v_cap NUMBER;
  v_lin DATE; v_lout DATE; v_pax NUMBER; v_val NUMBER; v_d DATE;
  v_choca BOOLEAN; v_try NUMBER; v_idx NUMBER; v_prec NUMBER; v_ok BOOLEAN; v_j NUMBER; v_used t_num;
BEGIN
  SELECT id_habitacion, id_alojamiento, capacidad_max BULK COLLECT INTO v_hid, v_haloj, v_hcap FROM habitacion ORDER BY id_habitacion;
  v_nhab := v_hid.COUNT;
  SELECT id_temporada, nombre, fecha_inicio, fecha_fin BULK COLLECT INTO v_tid, v_tnom, v_tini, v_tfin FROM temporada ORDER BY id_temporada;
  FOR r IN 1..25000 LOOP
    v_r := DBMS_RANDOM.VALUE(0,26.5);
    IF v_r < 3 THEN v_mes := 1; ELSIF v_r < 4 THEN v_mes := 2; ELSIF v_r < 6 THEN v_mes := 3;
    ELSIF v_r < 9 THEN v_mes := 4; ELSIF v_r < 10.5 THEN v_mes := 5; ELSIF v_r < 13.5 THEN v_mes := 6;
    ELSIF v_r < 16.5 THEN v_mes := 7; ELSIF v_r < 18 THEN v_mes := 8; ELSIF v_r < 19 THEN v_mes := 9;
    ELSIF v_r < 21 THEN v_mes := 10; ELSIF v_r < 23 THEN v_mes := 11; ELSE v_mes := 12; END IF;
    v_r := DBMS_RANDOM.VALUE;
    IF v_r < 0.20 THEN v_anio := 2024; ELSIF v_r < 0.55 THEN v_anio := 2025; ELSE v_anio := 2026; END IF;
    v_in := TO_DATE('01/' || LPAD(v_mes,2,'0') || '/' || v_anio, 'DD/MM/YYYY') + TRUNC(DBMS_RANDOM.VALUE(0,28));
    v_r := DBMS_RANDOM.VALUE;
    IF v_r < 0.50 THEN v_noches := TRUNC(DBMS_RANDOM.VALUE(1,4)); ELSIF v_r < 0.85 THEN v_noches := TRUNC(DBMS_RANDOM.VALUE(4,8)); ELSE v_noches := TRUNC(DBMS_RANDOM.VALUE(8,15)); END IF;
    v_out := v_in + v_noches;
    IF v_out > DATE '2026-12-31' THEN v_out := DATE '2026-12-31'; v_in := v_out - v_noches; END IF;
    v_fres := v_in - TRUNC(DBMS_RANDOM.VALUE(1,91));
    IF v_out <= c_hoy THEN v_est := CASE WHEN DBMS_RANDOM.VALUE < 0.13 THEN 'cancelada' ELSE 'completada' END;
    ELSIF v_in > c_hoy THEN v_est := CASE WHEN DBMS_RANDOM.VALUE < 0.55 THEN 'pendiente' ELSE 'confirmada' END;
    ELSE v_est := 'confirmada'; END IF;
    v_aloj := TRUNC(DBMS_RANDOM.VALUE(1,61));
    v_used.DELETE; -- habitaciones ya usadas por esta reserva (respeta la UQ)
    INSERT INTO reserva (id_reserva, id_cliente, fecha_reserva, checkin, checkout, estado)
    VALUES (r, TRUNC(DBMS_RANDOM.VALUE(1,3001)), v_fres, v_in, v_out, v_est);
    v_r := DBMS_RANDOM.VALUE;
    IF v_r < 0.85 THEN v_nlin := 1; ELSIF v_r < 0.97 THEN v_nlin := 2; ELSE v_nlin := 3; END IF;
    FOR l IN 1..v_nlin LOOP
      v_try := 0; v_ok := FALSE;
      WHILE NOT v_ok AND v_try < 6 LOOP
        v_try := v_try + 1;
        v_idx := TRUNC(DBMS_RANDOM.VALUE(1, v_nhab+1));
        IF v_haloj(v_idx) != v_aloj THEN CONTINUE; END IF;
        IF v_used.EXISTS(v_hid(v_idx)) THEN CONTINUE; END IF; -- ya usada en esta reserva
        v_hab := v_hid(v_idx); v_cap := v_hcap(v_idx);
        v_lin := v_in + CASE WHEN v_noches > 2 AND DBMS_RANDOM.VALUE < 0.3 THEN 1 ELSE 0 END;
        v_lout := v_out - CASE WHEN v_noches > 3 AND DBMS_RANDOM.VALUE < 0.25 THEN 1 ELSE 0 END;
        IF v_lout <= v_lin THEN v_lin := v_in; v_lout := v_out; END IF;
        v_choca := FALSE;
        IF v_est IN ('confirmada','completada') AND v_ocup.EXISTS(v_hab) THEN
          FOR k IN 1..v_ocup(v_hab).COUNT LOOP
            IF v_ocup(v_hab)(k).est IN ('confirmada','completada')
               AND NOT (v_lout <= v_ocup(v_hab)(k).ini OR v_lin >= v_ocup(v_hab)(k).fin) THEN
              v_choca := TRUE; EXIT;
            END IF;
          END LOOP;
        END IF;
        IF NOT v_choca THEN v_ok := TRUE; END IF;
      END LOOP;
      IF NOT v_ok THEN -- fallback: primera habitación LIBRE del alojamiento
        FOR v_j IN 1..v_nhab LOOP
          IF v_haloj(v_j) = v_aloj AND NOT v_used.EXISTS(v_hid(v_j)) THEN
            v_hab := v_hid(v_j); v_cap := v_hcap(v_j); v_ok := TRUE; EXIT;
          END IF;
        END LOOP;
        v_lin := v_in; v_lout := v_out;
      END IF;
      IF NOT v_ok THEN CONTINUE; END IF; -- sin habitaciones libres: se omite la línea
      v_used(v_hab) := 1;
      v_pax := TRUNC(DBMS_RANDOM.VALUE(1, v_cap+1));
      v_val := 0; v_d := v_lin;
      WHILE v_d < v_lout LOOP
        BEGIN
          SELECT t.precio_noche INTO v_prec FROM tarifa t WHERE t.id_habitacion = v_hab
            AND t.id_temporada = (SELECT s.id_temporada FROM temporada s WHERE v_d BETWEEN s.fecha_inicio AND s.fecha_fin AND ROWNUM = 1)
            AND ROWNUM = 1;
          v_val := v_val + v_prec;
        EXCEPTION WHEN NO_DATA_FOUND THEN v_val := v_val + 150000;
        END;
        v_d := v_d + 1;
      END LOOP;
      v_rh := v_rh + 1;
      INSERT INTO reserva_habitacion (id_reserva_hab, id_reserva, id_habitacion, fecha_checkin_linea, fecha_checkout_linea, num_huespedes, valor_calculado)
      VALUES (v_rh, r, v_hab, v_lin, v_lout, v_pax, v_val);
      v_tmp(1).ini := v_lin; v_tmp(1).fin := v_lout; v_tmp(1).est := v_est;
      IF v_ocup.EXISTS(v_hab) THEN v_ocup(v_hab)(v_ocup(v_hab).COUNT+1) := v_tmp(1);
      ELSE v_ocup(v_hab) := v_tmp; END IF;
    END LOOP;
    IF MOD(r,1000)=0 THEN COMMIT; END IF;
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('reserva OK, lineas: ' || v_rh);
END;
/

-- ---------- 13. RESERVA_SERVICIO (40000, solo servicios del alojamiento donde se hospeda) ----------
DECLARE
  TYPE t_num IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
  TYPE t_dat IS TABLE OF DATE INDEX BY PLS_INTEGER;
  TYPE t_chr IS TABLE OF VARCHAR2(12) INDEX BY PLS_INTEGER;
  v_rid t_num; v_rest t_chr; v_raloj t_num; v_rin t_dat;
  v_sid t_num; v_saloj t_num; v_sprec t_num;
  v_rs NUMBER := 0; v_i NUMBER; v_k NUMBER; v_try NUMBER; v_cant NUMBER; v_rr NUMBER; v_ss NUMBER; v_sp NUMBER; v_cf DATE;
BEGIN
  SELECT r.id_reserva, r.estado, MIN(h.id_alojamiento), MIN(r.checkin)
    BULK COLLECT INTO v_rid, v_rest, v_raloj, v_rin
    FROM reserva r JOIN reserva_habitacion rh ON rh.id_reserva = r.id_reserva
    JOIN habitacion h ON h.id_habitacion = rh.id_habitacion
   GROUP BY r.id_reserva, r.estado ORDER BY r.id_reserva;
  SELECT id_servicio, id_alojamiento, precio BULK COLLECT INTO v_sid, v_saloj, v_sprec FROM servicio ORDER BY id_servicio;
  WHILE v_rs < 40000 LOOP
    v_i := TRUNC(DBMS_RANDOM.VALUE(1, v_rid.COUNT+1));
    IF v_rest(v_i) = 'cancelada' THEN CONTINUE; END IF;
    v_try := 0; v_k := 0;
    WHILE v_try < 10 AND v_k = 0 LOOP
      v_try := v_try + 1;
      v_k := TRUNC(DBMS_RANDOM.VALUE(1, v_sid.COUNT+1));
      IF v_saloj(v_k) != v_raloj(v_i) THEN v_k := 0; END IF;
    END LOOP;
    IF v_k = 0 THEN CONTINUE; END IF;
    v_rr := v_rid(v_i); v_ss := v_sid(v_k); v_sp := v_sprec(v_k); v_cf := v_rin(v_i);
    v_rs := v_rs + 1;
    v_cant := CASE WHEN DBMS_RANDOM.VALUE < 0.55 THEN 1 WHEN DBMS_RANDOM.VALUE < 0.85 THEN 2 ELSE TRUNC(DBMS_RANDOM.VALUE(3,6)) END;
    INSERT INTO reserva_servicio (id_reserva_servicio, id_reserva, id_servicio, cantidad, precio_unitario, fecha_consumo)
    VALUES (v_rs, v_rr, v_ss, v_cant, v_sp, v_cf + TRUNC(DBMS_RANDOM.VALUE(0,3)));
    IF MOD(v_rs,5000)=0 THEN COMMIT; END IF;
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('reserva_servicio OK: ' || v_rs);
END;
/

-- ---------- 14. PAGO (completadas pagan el total; canceladas se reembolsan 80% del anticipo) ----------
DECLARE
  TYPE t_num IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
  TYPE t_chr IS TABLE OF VARCHAR2(20) INDEX BY PLS_INTEGER;
  TYPE t_dat IS TABLE OF DATE INDEX BY PLS_INTEGER;
  v_rid t_num; v_rest t_chr; v_rfres t_dat; v_rin t_dat;
  v_met t_chr; v_pago NUMBER := 0; v_tot NUMBER; v_r NUMBER; v_ant NUMBER; v_cid NUMBER; v_cfr DATE; v_cin DATE; v_mtd VARCHAR2(20);
BEGIN
  SELECT id_reserva, estado, fecha_reserva, checkin BULK COLLECT INTO v_rid, v_rest, v_rfres, v_rin FROM reserva ORDER BY id_reserva;
  DECLARE TYPE m IS TABLE OF NUMBER INDEX BY PLS_INTEGER; v_e m; v_s m;
  BEGIN
    FOR rec IN (SELECT id_reserva idd, SUM(valor_calculado) s FROM reserva_habitacion GROUP BY id_reserva) LOOP v_e(rec.idd) := rec.s; END LOOP;
    FOR rec IN (SELECT id_reserva idd, SUM(cantidad*precio_unitario) s FROM reserva_servicio GROUP BY id_reserva) LOOP v_s(rec.idd) := rec.s; END LOOP;
    v_met(1) := 'tarjeta_credito'; v_met(2) := 'tarjeta_debito'; v_met(3) := 'PSE'; v_met(4) := 'transferencia'; v_met(5) := 'efectivo';
    FOR i IN 1..v_rid.COUNT LOOP
      v_cid := v_rid(i); v_cfr := v_rfres(i); v_cin := v_rin(i); v_mtd := v_met(TRUNC(DBMS_RANDOM.VALUE(1,6)));
      IF v_e.EXISTS(v_cid) THEN v_tot := v_e(v_cid); ELSE v_tot := 0; END IF;
      IF v_s.EXISTS(v_cid) THEN v_tot := v_tot + v_s(v_cid); END IF;
      v_r := DBMS_RANDOM.VALUE;
      IF v_rest(i) = 'completada' THEN
        IF v_r < 0.60 THEN
          v_pago := v_pago + 1;
          INSERT INTO pago (id_pago, fecha_pago, monto, metodo_pago, estado_pago, id_reserva)
          VALUES (v_pago, v_cfr + TRUNC(DBMS_RANDOM.VALUE(0,4)), v_tot, v_mtd, 'exitoso', v_cid);
        ELSE
          v_ant := ROUND(v_tot * 0.30, -2);
          v_pago := v_pago + 1;
          INSERT INTO pago (id_pago, fecha_pago, monto, metodo_pago, estado_pago, id_reserva)
          VALUES (v_pago, v_cfr + TRUNC(DBMS_RANDOM.VALUE(0,4)), v_ant, v_mtd, 'exitoso', v_cid);
          v_pago := v_pago + 1;
          INSERT INTO pago (id_pago, fecha_pago, monto, metodo_pago, estado_pago, id_reserva)
          VALUES (v_pago, v_cin - 1 + TRUNC(DBMS_RANDOM.VALUE(0,3)), v_tot - v_ant, v_mtd, 'exitoso', v_cid);
        END IF;
      ELSIF v_rest(i) = 'confirmada' THEN
        v_pago := v_pago + 1;
        INSERT INTO pago (id_pago, fecha_pago, monto, metodo_pago, estado_pago, id_reserva)
        VALUES (v_pago, v_cfr + TRUNC(DBMS_RANDOM.VALUE(0,4)), ROUND(v_tot * 0.30, -2), v_mtd, 'exitoso', v_cid);
      ELSIF v_rest(i) = 'pendiente' THEN
        IF v_r < 0.50 THEN
          v_pago := v_pago + 1;
          INSERT INTO pago (id_pago, fecha_pago, monto, metodo_pago, estado_pago, id_reserva)
          VALUES (v_pago, v_cfr, v_tot, v_mtd, 'pendiente', v_cid);
        ELSIF v_r < 0.80 THEN
          v_pago := v_pago + 1;
          INSERT INTO pago (id_pago, fecha_pago, monto, metodo_pago, estado_pago, id_reserva)
          VALUES (v_pago, v_cfr, ROUND(v_tot * 0.30, -2), v_mtd, 'exitoso', v_cid);
        END IF;
      ELSE -- cancelada: anticipo exitoso + reembolso del 80% de lo pagado 
        IF v_r < 0.80 THEN
          v_ant := ROUND(v_tot * 0.40, -2);
          v_pago := v_pago + 1;
          INSERT INTO pago (id_pago, fecha_pago, monto, metodo_pago, estado_pago, id_reserva)
          VALUES (v_pago, v_cfr + TRUNC(DBMS_RANDOM.VALUE(0,4)), v_ant, v_mtd, 'exitoso', v_cid);
          v_pago := v_pago + 1;
          INSERT INTO pago (id_pago, fecha_pago, monto, metodo_pago, estado_pago, id_reserva)
          VALUES (v_pago, v_cfr + 6, ROUND(v_ant * 0.80, -2), v_mtd, 'reembolsado', v_cid);
        ELSE
          v_pago := v_pago + 1;
          INSERT INTO pago (id_pago, fecha_pago, monto, metodo_pago, estado_pago, id_reserva)
          VALUES (v_pago, v_cfr, v_tot, v_mtd, 'fallido', v_cid);
        END IF;
      END IF;
      IF MOD(i,5000)=0 THEN COMMIT; END IF;
    END LOOP;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('pago OK: ' || v_pago);
  END;
END;
/

-- ---------- 15. RESENA (42% de las completadas, calificacion sesgada a 4-5) ----------
DECLARE
  TYPE t_arr IS VARRAY(10) OF VARCHAR2(60);
  v_com t_arr := t_arr('Excelente atencion y paisajes unicos','Muy buen servicio, recomendado','La comida podria mejorar','Lugar magico, volveremos','Buena relacion calidad precio','El tour cafetero es imperdible','Habitacion comoda y limpia',
  'Atencion regular en recepcion','Perfecto para descansar','El transporte fallo un dia');
  v_id NUMBER := 0; v_r NUMBER; v_cal NUMBER; v_f DATE; v_cc VARCHAR2(60);
BEGIN
  FOR rec IN (SELECT r.id_reserva idd, r.id_cliente cli, MIN(r.checkout) cout, MIN(h.id_alojamiento) aloj
                FROM reserva r JOIN reserva_habitacion rh ON rh.id_reserva = r.id_reserva
                JOIN habitacion h ON h.id_habitacion = rh.id_habitacion
               WHERE r.estado = 'completada' GROUP BY r.id_reserva, r.id_cliente) LOOP
    IF DBMS_RANDOM.VALUE < 0.42 THEN
      v_r := DBMS_RANDOM.VALUE;
      IF v_r < 0.40 THEN v_cal := 5; ELSIF v_r < 0.70 THEN v_cal := 4; ELSIF v_r < 0.85 THEN v_cal := 3; ELSIF v_r < 0.93 THEN v_cal := 2; ELSE v_cal := 1; END IF;
      v_f := LEAST(rec.cout + TRUNC(DBMS_RANDOM.VALUE(1,16)), DATE '2026-09-30');
      IF DBMS_RANDOM.VALUE < 0.30 THEN v_cc := NULL; ELSE v_cc := v_com(TRUNC(DBMS_RANDOM.VALUE(1,11))); END IF;
      v_id := v_id + 1;
      INSERT INTO resena (id_resena, id_reserva, id_alojamiento, id_cliente, calificacion, comentario, fecha_resena)
      VALUES (v_id, rec.idd, rec.aloj, rec.cli, v_cal, v_cc, v_f);
    END IF;
    IF MOD(rec.idd,5000)=0 THEN COMMIT; END IF;
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('resena OK: ' || v_id);
END;
/

-- ---------- 16. Verificación de volúmenes ----------
DECLARE
  PROCEDURE cnt(p_tab VARCHAR2) IS v NUMBER;
  BEGIN EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || p_tab INTO v; DBMS_OUTPUT.PUT_LINE(RPAD(p_tab,22) || v); END;
BEGIN
  cnt('MUNICIPIO'); cnt('TIPO_ALOJAMIENTO'); cnt('TEMPORADA'); cnt('ROL'); cnt('CIUDAD');
  cnt('ALOJAMIENTO'); cnt('HABITACION'); cnt('TARIFA'); cnt('CLIENTE'); cnt('SERVICIO');
  cnt('USUARIO_SISTEMA'); cnt('RESERVA'); cnt('RESERVA_HABITACION'); cnt('RESERVA_SERVICIO');
  cnt('PAGO'); cnt('RESENA');
END;
/
