-- =============================================================
-- TurismoUQ 
-- Base de datos para la gestión de reservas de alokamientos
-- turísticos en el Quindío.
-- =============================================================

-- 1. MUNICIPIO
-- Catálogo de municipios del Quindío donde se ubican os alojameientos.
-- El nombre del municipio es único para evitar duplicados.
--
CREATE TABLE municipio
    (
     id_municipio INTEGER NOT NULL,
     nombre VARCHAR2(40) NOT NULL UNIQUE
    );

ALTER TABLE municipio
    ADD CONSTRAINT municipio_pk PRIMARY KEY (id_municipio);

-- 2. TIPO_ALOJAMIENTO
-- Catálogo que clasifica los alojamientos: finca cafetera, hotel, glamping,
-- hostal, etc. Permite agregar nuevos tipos sin modificar la estructura de la 
-- tabla alojamiento. El nombre del tipo de alojamiento es único para evitar duplicados.
--
CREATE TABLE tipo_alojamiento
    (
     id_tipo_alojamiento INTEGER NOT NULL,
     nombre VARCHAR2(30) NOT NULL UNIQUE,
     descripcion VARCHAR2(200)
    );

ALTER TABLE tipo_alojamiento
    ADD CONSTRAINT tipo_alojamiento_pk PRIMARY KEY (id_tipo_alojamiento);

-- 3. ALOJAMIENTO
-- Tabla principal que guarda los datos de contacto, la calificación oficial en estrellas, 
-- la fecha que que se registro el alojamiento en el sistema, el municipio donde está ubicado y de 
-- qué tipo es. La calificación en estrellas debe estar entre 1 y 5.
--
CREATE TABLE alojamiento
    (
     id_alojamiento INTEGER NOT NULL,
     nombre VARCHAR2(80) NOT NULL,
     direccion VARCHAR2(120),
     calificacion_estrellas INTEGER NOT NULL CHECK (calificacion_estrellas BETWEEN 1 AND 5),
     telefono VARCHAR2(20),
     email VARCHAR2(100),
     fecha_registro DATE DEFAULT SYSDATE NOT NULL,
     id_municipio INTEGER NOT NULL,
     id_tipo_alojamiento INTEGER NOT NULL
    );

ALTER TABLE alojamiento
    ADD CONSTRAINT alojamiento_pk PRIMARY KEY (id_alojamiento);

-- 4. HABITACION
-- Unidades reservables de cada alojamiento. Define el tipo y la capacidad máxima de huéspedes.
-- El número de habitación no se puede repetir dentro del mismo alojamiento.
--
CREATE TABLE habitacion
    (
     id_habitacion INTEGER NOT NULL,
     id_alojamiento INTEGER NOT NULL,
     numero_habitacion VARCHAR2(10) NOT NULL,
     capacidad_max INTEGER NOT NULL,
     tipo VARCHAR2(15) NOT NULL,
     descripcion VARCHAR2(200),
     CONSTRAINT habitacion_tipo_ck CHECK (tipo IN ('sencilla','doble','suite','cabana')),
     CONSTRAINT habitacion_capacidad_ck CHECK (capacidad_max > 0),
     CONSTRAINT habitacion_uq UNIQUE (id_alojamiento, numero_habitacion)
    );

ALTER TABLE habitacion
    ADD CONSTRAINT habitacion_pk PRIMARY KEY (id_habitacion);

-- 5. TEMPORADA
-- Periodos del año clasificados como alta, media o baja, con su rango de fechas. Sirven para definir
-- precios distintos según la temporada. La fecha final debe ser posterior a la inicial.
--
CREATE TABLE temporada
    (
     id_temporada INTEGER NOT NULL,
     nombre VARCHAR2(10) NOT NULL,
     anio INTEGER NOT NULL,
     fecha_inicio DATE NOT NULL,
     fecha_fin DATE NOT NULL,
     CONSTRAINT temporada_nombre_ck CHECK (nombre IN ('alta','media','baja')),
     CONSTRAINT temporada_fechas_ck CHECK (fecha_fin > fecha_inicio)
    );

ALTER TABLE temporada
    ADD CONSTRAINT temporada_pk PRIMARY KEY (id_temporada);

-- 6. TARIFA
-- Precio por noche de una habitación en una temporada específica. Es una tabla intermedia entre habitación
-- y teporada: cada habitación puede tener varias tarifas según la temporada, y cada temporada puede tener 
-- tarifas distintas para cada habitación. El precio debe ser mayor a cero.
--
CREATE TABLE tarifa
    (
     id_tarifa INTEGER NOT NULL,
     precio_noche NUMBER(12,2) NOT NULL,
     id_habitacion INTEGER NOT NULL,
     id_temporada INTEGER NOT NULL,
     fecha_actualizacion DATE,
     CONSTRAINT tarifa_precio_ck CHECK (precio_noche > 0),
     CONSTRAINT tarifa_uq UNIQUE (id_habitacion, id_temporada)
    );

ALTER TABLE tarifa
    ADD CONSTRAINT tarifa_pk PRIMARY KEY (id_tarifa);


-- 7. CLIENTE
-- Turistas que realizan reservas. La información de su cédula y correo son únicos (no pueden
-- haber dos clientes con los mismos datos). Guarda ciudad de origen.
--
CREATE TABLE cliente
    (
     id_cliente INTEGER NOT NULL,
     cedula VARCHAR2(15) NOT NULL,
     nombre VARCHAR2(80) NOT NULL,
     correo VARCHAR2(80) NOT NULL,
     telefono VARCHAR2(20),
     id_ciudad_origen INTEGER NOT NULL,
     CONSTRAINT cliente_cedula_uq UNIQUE (cedula),
     CONSTRAINT cliente_correo_uq UNIQUE (correo)
    );

ALTER TABLE cliente
    ADD CONSTRAINT cliente_pk PRIMARY KEY (id_cliente) ;

-- 8. RESERVA
-- Guarda la información de quién hizo la reserva, cuándo la hizo, las fechas generales de 
-- checkin y checkouy y el estado.
--
CREATE TABLE reserva
    (
     id_reserva INTEGER NOT NULL,
     id_cliente INTEGER NOT NULL,
     fecha_reserva DATE NOT NULL,
     checkin DATE NOT NULL,
     checkout DATE NOT NULL,
     estado VARCHAR2(12) NOT NULL ,
     CONSTRAINT reserva_estado_ck CHECK (estado IN ('pendiente','confirmada','cancelada','completada')),
     CONSTRAINT reserva_fechas_ck CHECK (checkout > checkin)
    );

ALTER TABLE reserva
    ADD CONSTRAINT reserva_pk PRIMARY KEY (id_reserva);

-- 9. RESERVA_HABITACION
-- Detalle de las habitaciones reservadas con fechas propias por línea, número de huéspedes y 
-- el valor valculado. Es una tabla intermedia entre reserva y habitación. El número de huéspedes 
-- debe ser mayor a cero y una misma habitación no puede reservarse dos veces en la misma reserva.
--
CREATE TABLE reserva_habitacion
    (
     id_reserva_hab INTEGER NOT NULL,
     id_reserva INTEGER NOT NULL,
     id_habitacion INTEGER NOT NULL,
     fecha_checkin_linea DATE NOT NULL,
     fecha_checkout_linea DATE NOT NULL,
     num_huespedes INTEGER NOT NULL,
     valor_calculado NUMBER (12,2),
     CONSTRAINT rh_huespedes_ck CHECK (num_huespedes > 0),
     CONSTRAINT rh_fechas_ck CHECK (fecha_checkout_linea > fecha_checkin_linea),
     CONSTRAINT reserva_habitacion_uq UNIQUE (id_reserva, id_habitacion)
    );

ALTER TABLE reserva_habitacion
    ADD CONSTRAINT reserva_habitacion_pk PRIMARY KEY (id_reserva_hab);

-- 10. PAGO
-- Pagos asociados a una reserva (una reserva puede tener varios, por ejemplo abonos). Se registra la fecha, el monto,
-- el método de pago y el estado del mismo. El monto debe ser mayor a cero, el método de pago debe ser uno de los
-- definidos y el estado del pago debe ser uno de los permitidos.
--
CREATE TABLE pago
    (
     id_pago INTEGER NOT NULL,
     fecha_pago DATE NOT NULL,
     monto NUMBER(12,2) NOT NULL,
     metodo_pago VARCHAR2(20) NOT NULL,
     estado_pago VARCHAR2(12) NOT NULL,
     id_reserva INTEGER NOT NULL,
     CONSTRAINT pago_monto_ck CHECK (monto > 0),
     CONSTRAINT pago_metodo_ck CHECK (metodo_pago IN ('tarjeta_credito','tarjeta_debito','PSE','transferencia','efectivo')),
     CONSTRAINT pago_estado_ck CHECK (estado_pago IN ('exitoso','fallido','pendiente','reembolsado'))
    );

ALTER TABLE pago
    ADD CONSTRAINT pago_pk PRIMARY KEY (id_pago);

-- 11. SERVICIO
-- Servicios adicionales que ofrece cada alojamiento con su precio. El precio debe ser mayor
-- o igual a cero.
--
CREATE TABLE servicio
    (
     id_servicio INTEGER NOT NULL,
     id_alojamiento INTEGER NOT NULL,
     nombre VARCHAR2(60 ) NOT NULL,
     descripcion VARCHAR2(200 ),
     precio NUMBER(10,2) NOT NULL,
     CONSTRAINT servicio_precio_ck CHECK (precio >= 0)
    );

ALTER TABLE servicio
    ADD CONSTRAINT servicio_pk PRIMARY KEY (id_servicio);

-- 12. RESERVA_SERVICIO
-- Servicios consumidos o contratados dentro de una reserva. Guarda la cantidad y el precio unitario al momento del consumo
-- y la fecha de consumo. Registra la relación entre reserva y servicio. La cantidad debe ser mayor a cero y el precio unitario
-- debe ser mayor o igual a cero.
--
CREATE TABLE reserva_servicio
    (
     id_reserva_servicio INTEGER NOT NULL,
     id_reserva INTEGER NOT NULL,
     id_servicio INTEGER NOT NULL,
     cantidad INTEGER NOT NULL,
     precio_unitario NUMBER (10,2) NOT NULL,
     fecha_consumo DATE,
     CONSTRAINT rs_cantidad_ck CHECK (cantidad > 0),
     CONSTRAINT rs_precio_ck CHECK (precio_unitario >= 0)
    );

ALTER TABLE reserva_servicio
    ADD CONSTRAINT reserva_servicio_pk PRIMARY KEY (id_reserva_servicio);

-- 13. RESENA
-- Opiniones de los clientes sobre un alojamiento tras su estadía con una calificación de 1 a 5 y comentario opcional.
-- Solo puede haber una reseña por reserva y alojamiento.
-- 
CREATE TABLE resena
    (
     id_resena INTEGER NOT NULL,
     id_reserva INTEGER NOT NULL,
     id_alojamiento INTEGER NOT NULL,
     id_cliente INTEGER NOT NULL,
     calificacion INTEGER NOT NULL,
     comentario VARCHAR2(500),
     fecha_resena DATE NOT NULL,
     CONSTRAINT resena_calif_ck CHECK (calificacion BETWEEN 1 AND 5),
     CONSTRAINT resena_reserva_alojamiento UNIQUE (id_reserva, id_alojamiento)
    );

ALTER TABLE resena
    ADD CONSTRAINT resena_pk PRIMARY KEY (id_resena) ;

-- 14. USUARIO_SISTEMA
-- Usuarios internos que operan la plataforma. Tiene login y correo únicos, un rol y opcionalmente un alojamiento asignado.
-- Su estado puede ser activo o inactivo. La contraseña se almacena cifrada.
--
CREATE TABLE usuario_sistema
    (
     id_usuario INTEGER NOT NULL,
     login VARCHAR2(30) NOT NULL,
     nombre VARCHAR2(150) NOT NULL,
     email VARCHAR2(100) NOT NULL,
     contrasena VARCHAR2(255),
     id_rol INTEGER NOT NULL,
     id_alojamiento INTEGER,
     estado VARCHAR2(10) DEFAULT 'activo' NOT NULL,
     CONSTRAINT usuario_login_uq UNIQUE (login),
     CONSTRAINT usuario_email_uq UNIQUE (email),
     CONSTRAINT usuario_estado_ck CHECK (estado IN ('activo','inactivo'))
    );

ALTER TABLE usuario_sistema
    ADD CONSTRAINT usuario_sistema_pk PRIMARY KEY (id_usuario);

-- 15. ROL
-- Catálogo de roles de los usuarios del sistema que definen sus permisos. 
--
CREATE TABLE rol
    (
     id_rol INTEGER NOT NULL,
     nombre VARCHAR2(25) NOT NULL,
     descripcion VARCHAR2(200),
     CONSTRAINT rol_nombre_uq UNIQUE (nombre)
    );

ALTER TABLE rol
    ADD CONSTRAINT rol_pk PRIMARY KEY (id_rol);

-- 16. CIUDAD
-- Catálogo de ciudades de origen de los clientes con su departamento. Se usa para analizar de dónde 
-- vienen los turistas.
-- 
CREATE TABLE ciudad
    (
     id_ciudad INTEGER NOT NULL,
     nombre VARCHAR2 (40) NOT NULL,
     departamento VARCHAR2 (40)
    )
;

ALTER TABLE ciudad
    ADD CONSTRAINT ciudad_pk PRIMARY KEY (id_ciudad);


-- 17. AUDITORIA_TARIFA
-- Bitácora de cambios en las tarifas. Cada vez que se modifica una tarifa se guarda quién lo hizo, el precio
-- anterior y el nuevo precio, la fecha y el motivo para dar trazabilidad.
CREATE TABLE auditoria_tarifa
    (
     id_auditoria INTEGER NOT NULL,
     id_tarifa INTEGER NOT NULL,
     id_usuario INTEGER NOT NULL,
     precio_anterior NUMBER (12,2) NOT NULL,
     precio_nuevo NUMBER (12,2) NOT NULL,
     fecha_cambio DATE DEFAULT SYSDATE NOT NULL,
     motivo VARCHAR2 (200)
    );

ALTER TABLE auditoria_tarifa
    ADD CONSTRAINT auditoria_tarifa_pk PRIMARY KEY (id_auditoria);

-- =============================================================
-- Claves foraneas
-- Definen las relaciones entre tablas y garantizan la integridad referencial.
-- =============================================================

-- Alojamiento pertenece a un municipio
ALTER TABLE alojamiento
    ADD CONSTRAINT alojamiento_municipio_fk FOREIGN KEY (id_municipio)
    REFERENCES municipio (id_municipio);

-- Alojamiento pertenece a un tipo de alojamiento
ALTER TABLE alojamiento
    ADD CONSTRAINT alojamiento_tipo_fk FOREIGN KEY (id_tipo_alojamiento)
    REFERENCES tipo_alojamiento (id_tipo_alojamiento);

-- Habitacion pertenece a un alojamiento
ALTER TABLE habitacion
    ADD CONSTRAINT habitacion_alojamiento_fk FOREIGN KEY (id_alojamiento)
    REFERENCES alojamiento (id_alojamiento);

-- Tarifa: precio de una habitación en una temporada.
ALTER TABLE tarifa
    ADD CONSTRAINT tarifa_habitacion_fk FOREIGN KEY (id_habitacion)
    REFERENCES habitacion (id_habitacion);

ALTER TABLE tarifa
    ADD CONSTRAINT tarifa_temporada_fk FOREIGN KEY (id_temporada)
    REFERENCES temporada (id_temporada);

-- Cliente proviene de una ciudad
ALTER TABLE cliente
    ADD CONSTRAINT cliente_ciudad_fk FOREIGN KEY (id_ciudad_origen)
    REFERENCES ciudad (id_ciudad);

-- Reserva la realiza un cliente
ALTER TABLE reserva
    ADD CONSTRAINT cliente_reserva_fk FOREIGN KEY (id_cliente)
    REFERENCES cliente (id_cliente);

-- Reserva_Habitacion: detalle de habitaciones reservadas
ALTER TABLE reserva_habitacion
    ADD CONSTRAINT reserva_habitacion_fk FOREIGN KEY(id_habitacion)
    REFERENCES habitacion (id_habitacion);

ALTER TABLE reserva_habitacion
    ADD CONSTRAINT reservahabitacion_reserva_fk FOREIGN KEY(id_reserva)
    REFERENCES reserva (id_reserva);

-- Pago pertenece a una reserva
ALTER TABLE pago
    ADD CONSTRAINT pago_reserva_fk FOREIGN KEY (id_reserva)
    REFERENCES reserva (id_reserva);

-- Servicio es ofrecido por un alojamiento
ALTER TABLE servicio
    ADD CONSTRAINT servicio_alojamiento_fk FOREIGN KEY (id_alojamiento)
    REFERENCES alojamiento (id_alojamiento);

-- Servicios consumidos en una reserva
ALTER TABLE reserva_servicio
    ADD CONSTRAINT reservaservicio_reserva_fk FOREIGN KEY (id_reserva)
    REFERENCES reserva (id_reserva);

ALTER TABLE reserva_servicio
    ADD CONSTRAINT reservaservicio_servicio_fk FOREIGN KEY (id_servicio)
    REFERENCES servicio (id_servicio);

-- Reseña sobre un alojamiento hecha por un cliente tras una reserva.
ALTER TABLE resena
    ADD CONSTRAINT resena_alojamiento_fk FOREIGN KEY (id_alojamiento)
    REFERENCES alojamiento (id_alojamiento);

ALTER TABLE resena
    ADD CONSTRAINT resena_cliente_fk FOREIGN KEY (id_cliente)
    REFERENCES cliente (id_cliente);

ALTER TABLE resena
    ADD CONSTRAINT resena_fk FOREIGN KEY (id_reserva)
    REFERENCES reserva (id_reserva);

-- Usuario del sistema con rol
ALTER TABLE usuario_sistema
    ADD CONSTRAINT usuariosistema_alojamiento_fk FOREIGN KEY (id_alojamiento)
    REFERENCES alojamiento (id_alojamiento);

ALTER TABLE usuario_sistema
    ADD CONSTRAINT rol_usuario_fk FOREIGN KEY (id_rol)
    REFERENCES rol (id_rol);

-- Auditoría de cambios en tarifas
ALTER TABLE auditoria_tarifa
    ADD CONSTRAINT auditoria_tarifa_fk FOREIGN KEY (id_tarifa)
    REFERENCES tarifa (id_tarifa);

ALTER TABLE auditoria_tarifa
    ADD CONSTRAINT auditoriatarifa_usuario_fk FOREIGN KEY (id_usuario)
    REFERENCES usuario_sistema (id_usuario);
