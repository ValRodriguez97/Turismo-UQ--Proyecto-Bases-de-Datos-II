UNIVERSIDAD DEL QUINDÍO · FACULTAD DE INGENIERÍA

Ingeniería de Sistemas y Computación

## Proyecto integrador · TurismoUQ

Plataforma de reservas turísticas del Quindío

Bases de Datos II · código 12338 · periodo 2026-2 · grupos 01D y 01N · equipos de 3 · docente Carolina Londoño Idárraga

- 1. El encargo

El Quindío vive del turismo y su demanda es estacional: se dispara en Semana Santa, mitad de año, los puentes festivos y diciembre-enero, y cae el resto del tiempo.

TurismoUQ es la base de datos de una plataforma que reúne la oferta de alojamiento de los 12 municipios del departamento — fincas cafeteras, hoteles, glampings, hostales — y gestiona reservas, pagos y servicios complementarios. Ustedes no construyen la interfaz: el entregable es la base de datos — el modelo, la lógica que vive dentro del motor y su administración. Todo sobre Oracle XE 21c instalado localmente.

Lo que sigue describe cómo funciona el negocio. Léanlo con cuidado: varias reglas no están dichas de forma literal,

hay que deducirlas — igual que en un proyecto real, donde nadie les entrega el modelo hecho.

## 1.1 Alojamientos y habitaciones

Cada alojamiento pertenece a un municipio y a un tipo — finca cafetera, hotel, glamping, hostal, u otros que ustedes puedan sustentar. Tiene nombre comercial, dirección, una calificación en estrellas que el mismo alojamiento se autoasigna, y datos de contacto.

Cada alojamiento ofrece varias habitaciones, y cada habitación tiene número, capacidad máxima de huéspedes, tipo (sencilla, doble, suite, cabaña) y descripción. Dos habitaciones del mismo alojamiento no pueden compartir número.

No repitan la misma proporción para todos: una finca cafetera pequeña puede tener 3 habitaciones, un hotel del centro de Armenia puede tener 40. Esa asimetría debe quedar en los datos.

- 1.2 Temporadas y tarifas

El precio de una habitación no es fijo: depende de la temporada. El departamento define temporadas — alta, media, baja — con su rango de fechas: Semana Santa, mitad de año, puentes festivos y diciembre-enero son temporada alta; el resto se reparte entre media y baja. Las temporadas se definen por año: Semana Santa 2025 y Semana Santa 2026 son temporadas distintas, con fechas distintas.

Cada habitación tiene una tarifa por noche para cada temporada — no es un porcentaje fijo sobre un precio base, porque un alojamiento puede decidir no subir tanto el precio en temporada alta si quiere competir por volumen. Primera decisión de diseño que van a defender: una estadía puede empezar en una temporada y terminar en otra. Alguien reserva del 20 al 26 de diciembre y el 24 podría ser el corte entre temporada media y alta. El valor de esa estadía no es un solo precio: hay que calcularlo noche por noche, según la tarifa vigente cada día. Su modelo y su función fn_valor_estadia (Entrega 2) tienen que resolver esto.

## 1.3 Clientes y reservas

Los clientes se registran con nombre, documento de identidad, correo, teléfono y ciudad de origen. Un cliente puede tener muchas reservas a lo largo del tiempo.

Una reserva tiene fecha de check-in, fecha de check-out, un estado (pendiente, confirmada, cancelada, completada) y un cliente asociado. Segunda decisión de diseño que van a defender: una reserva no es necesariamente de una sola


habitación. Un grupo grande puede reservar 3 habitaciones del mismo alojamiento para las mismas fechas dentro de una sola reserva, y en teoría cada línea puede tener fechas ligeramente distintas dentro del rango general (alguien del grupo llega un día después).

Regla que su modelo debe poder validar: una reserva no puede aceptarse si la habitación ya está ocupada en ese

rango de fechas por otra reserva confirmada.

## 1.4 Pagos

Una reserva puede pagarse de una sola vez o en varios abonos — por ejemplo, un anticipo al reservar y el saldo al llegar. Cada pago registra fecha, monto, método (tarjeta de crédito, tarjeta débito, PSE, transferencia, efectivo) y estado (exitoso, fallido, pendiente, reembolsado).

Una reserva se considera pagada solo cuando la suma de sus pagos exitosos cubre el valor total calculado de la estadía más los servicios.

Regla de cancelación: con más de 5 días de anticipación al check-in, el cliente tiene derecho a reembolso del 80 %; con menos de 5 días, no hay reembolso. Es una regla implícita — no está en ningún lado con esas palabras, pero se deduce de cómo opera el negocio.

## 1.5 Servicios complementarios

Los alojamientos ofrecen servicios adicionales — desayuno, tour guiado, transporte al aeropuerto, alquiler de bicicletas, spa, u otros que el grupo considere. Cada servicio tiene nombre, descripción, precio, y pertenece a un alojamiento específico: el desayuno del Hotel X no es el mismo servicio que el desayuno del Hotel Y, aunque se llamen igual.

Una reserva puede incluir varios servicios, y de cada uno se puede pedir más de una unidad (2 tours guiados para 2 personas del mismo grupo, por ejemplo). El valor de los servicios se suma al de la estadía para el total de la reserva.

## 1.6 Reseñas

Después de una estadía completada, el cliente puede dejar una reseña del alojamiento: calificación de 1 a 5 estrellas y comentario opcional. Un cliente solo puede reseñar un alojamiento si tuvo al menos una reserva completada allí — no se aceptan reseñas de reservas canceladas o que nunca se llegaron a hospedar.

## 1.7 El equipo detrás de la plataforma

TurismoUQ tiene usuarios internos: administradores de la plataforma y encargados de cada alojamiento, que gestionan sus propias habitaciones, tarifas y reservas. Cada usuario del sistema tiene un rol, y solo debería poder hacer lo que ese rol permite — esto se conecta directamente con la Entrega 3.

- 1.8 Lo que la gerencia necesita ver

La gerencia quiere responder, sin pegar tablas de Excel a mano: cuál es la ocupación de cada municipio mes a mes, cuánto ingresa cada alojamiento y cada tipo de alojamiento por temporada, cuáles son los alojamientos más rentables dentro de cada municipio, cómo varían los ingresos de un mes a otro, y qué tan bien calificados están los alojamientos según sus reseñas. Esto es exactamente lo que van a construir en la Entrega 1.

## 2. Modelo de datos

## 2.1 Modelo mínimo (14 entidades)

MUNICIPIO · TIPO_ALOJAMIENTO · ALOJAMIENTO · HABITACION · TEMPORADA · TARIFA · CLIENTE · RESERVA · RESERVA_HABITACION · PAGO · SERVICIO · RESERVA_SERVICIO · RESENA · USUARIO_SISTEMA

Pueden agregar las que necesiten, no quitar.


Dos decisiones de diseño que van a tener que defender: cómo modelan que una reserva tome varias habitaciones (sección 1.3), y cómo modelan que una estadía atraviese dos temporadas con tarifas distintas (sección 1.2).

## 2.2 Lo que deben documentar

Antes de escribir el DDL, entreguen dentro del PDF de la Entrega 1:

- Diagrama entidad-relación (MER) con cardinalidad y participación de cada relación, incluidas las entidades que hayan agregado.

- Mínimo 6 reglas de negocio derivadas de la sección 1 que no estén dichas de forma literal — por ejemplo, la regla de reembolso o la de reseñas.

- Media página explicando cómo resolvieron las dos decisiones de diseño de la sección 2.1.

El diagrama puede hacerse en Oracle Data Modeler, draw.io, Lucidchart o similar. Debe ser legible y con nombres claros.

## 2.3 Modelo físico

Implementen el modelo en Oracle con un script DDL que incluya PK, FK, CHECK, NOT NULL y UNIQUE donde corresponda, con comentarios explicando cada tabla.

## 3. Volumen mínimo de datos

| Tabla | Mínimo | Nota |
| --- | --- | --- |
| MUNICIPIO | 12 | Los 12 municipios reales del Quindío. |
| TIPO_ALOJAMIENTO | 4 | Finca cafetera, hotel, glamping, hostal (pueden agregar más). |
| ALOJAMIENTO | 60 | Repartidos de forma desigual entre municipios. |
| HABITACION | 400 | Asimétrico: hoteles grandes con 30–40, fincas pequeñas con 3–5. |
| TEMPORADA | 6 | Alta, media y baja para al menos 2 años (2025 y 2026). |
| TARIFA |   | según cruce Una por cada combinación habitación × temporada vigente. Se deriva del cruce, no se digita suelta. |
| CLIENTE | 3.000 | Ciudades de origen variadas, no solo del Quindío. |
| RESERVA | 25.000 | Repartidas en 2024–2026, con estacionalidad real. |
| RESERVA_HABITACION | ≥ 25.000 | Algunas reservas con más de una habitación. |
| PAGO | ≥ 25.000 | Algunas reservas con más de un pago (anticipo + saldo). |
| SERVICIO | 30 | Repartidos entre los 60 alojamientos. |
| RESERVA_SERVICIO | 40.000 | Líneas de servicios contratados. |
| RESENA | ≥ 40 % | De las reservas completadas, con calificaciones variadas. |
| USUARIO_SISTEMA | 10 | Al menos un administrador y un encargado por tipo de alojamiento. |

Esto no es capricho. Con 50 filas un índice no se nota y el plan de ejecución no dice nada: la Entrega 3 sería imposible de sustentar. Los datos deben ser asimétricos: si todos los municipios, alojamientos y meses tienen el mismo número de reservas, ROLLUP, CUBE, PIVOT y RANK no muestran ninguna diferencia real. Generen los datos con PL/SQL y DBMS_RANDOM, o con Mockaroo.

## 4. Entregas


| Hito | 01D | 01N | Peso |
| --- | --- | --- | --- |
| Entrega 1 · Modelo y consultas de análisis | 30/09 | 30/09 | 30 % |
| Entrega 2 · Capa PL/SQL | vie 23/10 | jue 22/10 | 30 % |
| Entrega 3 · Transacciones, índices y seguridad | vie 13/11 | jue 12/11 | 25 % |
| Sustentación |   | mar 17 y vie 20/11 mar 17 y jue 19/11 | 15 % |
| Habilitación | mar 24/11 | mar 24/11 | — |

El proyecto integrador es una nota de seguimiento del curso, no un parcial ni el examen final: el 100 % de la tabla anterior equivale a una sola nota sobre 5.0. Los pesos (30 %/30 %/25 %/15 %) son la distribución interna de esa nota; no se suman a ninguna otra escala.

El plazo de Entrega 1 se extendió al miércoles 30 de septiembre de 2026, 11:59 p.m., para ambos grupos (01D y 01N). Es fecha límite de entrega por Moodle; no depende de la sesión de clase de la semana 8.

## Entrega 1 · Modelo y consultas de análisis — 30 %

- Script DDL completo con PK, FK, CHECK, NOT NULL y UNIQUE.

- Script de carga con el volumen mínimo.

- Siete consultas de análisis, de las cuales son obligatorias:

- 1. Ocupación por municipio y mes, con PIVOT.

- 2. Ingresos por municipio, tipo de alojamiento y temporada con ROLLUP o CUBE, usando GROUPING para distinguir los subtotales.

- 3. Los 3 alojamientos de mayor ingreso dentro de cada municipio (RANK con PARTITION BY).

- 4. Variación de ingresos mes contra mes (LAG).

- 5. Una consulta parametrizada con variables de enlace para el rango de fechas.

- 6. Un UNPIVOT.

- 7. Una consulta libre que responda una pregunta de negocio que ustedes propongan.

## Cómo se reparte el 30 %

| Componente | Peso | Qué se evalúa |
| --- | --- | --- |
| Modelo de datos (MER + decisiones de diseño) | 20 % | MER completo y coherente con el contexto; las dos decisiones de diseño bien resueltas y explicadas. |
| Script DDL y carga de datos | 20 % | Restricciones completas; datos con el volumen mínimo y asimétricos. |
| 7 consultas de análisis | 60 % | Cada consulta corre sin error y responde exactamente lo pedido; uso correcto de PIVOT, UNPIVOT, ROLLUP/CUBE, GROUPING, RANK/PARTITION BY, LAG y parametrizadas. |

## Qué deben subir

| # | Entregable | Formato |
| --- | --- | --- |
| 1 | Documento con MER, reglas de negocio (mín. 6) y explicación de las 2 decisiones de diseño | Word o PDF |
| 2 | Script DDL (tablas + restricciones) | .sql |
| 3 | Script de carga de datos (volumen mínimo) | .sql |


| # | Entregable | Formato |
| --- | --- | --- |
| 4 | Script con las 7 consultas de análisis, numeradas y comentadas | .sql |

## Entrega 2 · Capa PL/SQL — 30 %

- fn_valor_estadia(id_habitacion, fecha_in, fecha_out): calcula el valor aplicando la tarifa de cada temporada que atraviese la estadía. Es la función más difícil del proyecto.

- sp_crear_reserva: con excepciones propias vía RAISE_APPLICATION_ERROR para habitación no disponible, checkout anterior o igual al checkin, y capacidad excedida.

- Un cursor explícito con parámetros para un proceso masivo: la liquidación mensual por alojamiento.

- Todo agrupado en un paquete.

- Disparador a nivel de sentencia: auditoría de cambios sobre TARIFA (quién, cuándo, valor anterior y nuevo).

- Disparador a nivel de fila: impedir que se registre una reserva que se solape con otra de la misma habitación.

- Un tablespace propio para el histórico de reservas, con la justificación de por qué separarlo.

- Una vista materializada de ocupación mensual, con su política de refresco justificada.

## Cómo se reparte el 30 %

| Componente | Peso | Qué se evalúa |
| --- | --- | --- |
| fn_valor_estadia | 20 % | Calcula correctamente el valor cruzando temporadas distintas dentro de la misma estadía. |
| sp_crear_reserva | 15 % | Valida disponibilidad, fechas y capacidad; excepciones propias con RAISE_APPLICATION_ERROR. |
| Cursor liquidación mensual | 15 % | Recorre correctamente con parámetros y genera el resultado esperado. |
| Paquete | 10 % | Agrupa correctamente las funciones y procedimientos. |
| Disparador de sentencia (auditoría TARIFA) | 10 % | Registra quién, cuándo, valor anterior y nuevo. |
| Disparador de fila (solape de reservas) | 10 % | Impide efectivamente el solape, probado con un caso real. |
| Tablespace | 5 % | Creado y justificado. |
| Vista materializada | 15 % | Precalcula la ocupación mensual correctamente; política de refresco justificada. |

## Qué deben subir

| # | Entregable | Formato |
| --- | --- | --- |
| 1 | Script con función, procedimiento, cursor y paquete completos | .sql |
| 2 | Script con los dos disparadores | .sql |
| 3 | Script del tablespace y la vista materializada | .sql |
| 4 | Evidencia de prueba de cada uno (script de prueba con resultados o capturas) | .sql o PDF |


- Transacciones: procedimiento que registre reserva y pago de forma atómica, con SAVEPOINT y demostración de un rollback parcial.

- Concurrencia: experimento documentado con dos sesiones intentando reservar la misma habitación al tiempo. Muestren el bloqueo, apliquen SELECT ... FOR UPDATE y comparen el comportamiento antes y después.

- Índices: identifiquen 3 consultas lentas, capturen el plan de ejecución antes y después, creen los índices (al menos uno compuesto y uno basado en función) y midan. Incluyan además un caso donde el índice no ayude y expliquen por qué. Ese punto vale tanto como los otros tres.

- Seguridad:

- 8. Cuatro roles: recepción, administrador de alojamiento, gerente y auditor, con privilegios diferenciados.

- 9. Recepción accede solo a través de vistas, nunca a las tablas.

- 10. Un perfil con límites de sesión.

## Cómo se reparte el 25 %

| Componente | Peso | Qué se evalúa |
| --- | --- | --- |
| Transacción atómica (reserva + pago) con SAVEPOINT | 20 % | Demuestra rollback parcial real. |
| Concurrencia (2 sesiones) | 15 % | Documentado con capturas, bloqueo real, SELECT ... FOR UPDATE. |
| Índices (3 consultas + plan de ejecución) | 25 % | Mejora medible; incluye uno compuesto y uno basado en función. |
| Caso donde el índice no ayuda | 15 % | Explicación técnica correcta. |
| Seguridad (4 roles + vistas + perfil) | 25 % | Privilegios diferenciados correctos; recepción no accede a tablas directamente. |

## Qué deben subir

| # | Entregable | Formato |
| --- | --- | --- |
| 1 | Script de transacciones con SAVEPOINT / ROLLBACK | .sql |
| 2 | Documento del escenario de concurrencia (con capturas) | Word o PDF |
| 3 | Script de índices + capturas de EXPLAIN PLAN antes/después | .sql + PDF |
| 4 | Script de roles, usuarios, GRANT y vistas | .sql |

## Sustentación — 15 %

20 minutos por equipo. Cualquier integrante responde por cualquier parte, y les pediré ejecutar en vivo dos consultas que yo escoja. La nota individual es la del equipo multiplicada por un factor de 0 a 1,2 según su desempeño.

## 5. Reglas

- Equipos de 3 integrantes, definidos en la semana 6 y ya no se cambian.

- Entrega por Moodle: repositorio Git con los scripts numerados en orden de ejecución, más un PDF con el modelo y las decisiones de diseño.

- Un script que no corre de arriba abajo en una base limpia no se califica.

- Dos proyectos con el mismo modelo y los mismos datos se anulan los dos.


- Cada script debe estar comentado explicando qué hace cada sección.

- Se evalúa tanto el funcionamiento como la comprensión: un script que funciona pero que nadie del equipo sabe explicar no obtiene la nota completa.

- Se permite consultar documentación oficial de Oracle, libros y material del curso. No se permite copiar de otros grupos.

- Entregas tardías tienen penalización según el reglamento de la universidad.

## 6. Temas del curso

|   | Sem Sesión 1 · martes | Sesión 2 · viernes (01D) / jueves (01N) |
| --- | --- | --- |
| 5 | Socialización del plan de clase | Taller de repaso de Bases de Datos I |
| 6 | Funciones avanzadas del GROUP BY: ROLLUP, CUBE, GROUPING SETS | Funciones analíticas de ventana: OVER, PARTITION BY |
| 7 | Referencias cruzadas: PIVOT y UNPIVOT · consultas parametrizadas | Vistas materializadas y fragmentación: tablespaces y datafiles |
| 8 | PL/SQL: fundamentación — variables, tipos, estructuras de control | Entrega 1 · parcial 1 |
| 9 | PL/SQL: cursores | PL/SQL: procedimientos almacenados |
| 10 | PL/SQL: funciones | PL/SQL: excepciones |
| 11 | Disparadores a nivel de sentencia | Disparadores a nivel de fila |
| 12 | Transacciones: estados y especificación | Entrega 2 · parcial 2 |
|   | 13 Manejo de transacciones y administración de la concurrencia | Índices: introducción y tipos |
| 14 | Creación y administración de índices | Usuarios y privilegios de objetos y del sistema |
| 15 | Roles, perfiles y administración del esquema | Entrega 3 · parcial 3 |
| 16 | Sustentación del proyecto final | Sustentación del proyecto final |
| 17 | Habilitación | — |
