-- =================================================================================
-- TurismoUQ - Entrega 3 - Entregable 4 (seguridad) - ARCHIVO D de 4
-- E3_04d: PRUEBA REAL DEL PERFIL PERFIL_TURISMOUQ (pasos manuales con capturas)
--
-- Valentina Gonzalez Diaz
-- Raquel Lopez Aristizabal
-- Valentina Rodriguez Castro
--
-- Despues de E3_04a, E3_04b y E3_04c. No ejecutar de corrido.
-- =================================================================================

-- =================================================================================
-- PARTE 1. FAILED_LOGIN_ATTEMPTS = 3  (3 claves malas bloquean la cuenta)
-- Usuario de prueba: ENC_EXTRA3. Conexion de trabajo: SYSTEM.
-- =================================================================================

-- 1.1 (SYSTEM) Dejar la cuenta limpia y ver su estado inicial: debe ser OPEN.
ALTER USER enc_extra3 ACCOUNT UNLOCK;
SELECT username, account_status, lock_date FROM dba_users WHERE username = 'ENC_EXTRA3';

-- 1.2 Intentar conectar como ENC_EXTRA3 con una clave INCORRECTA, TRES veces.
--     SQL Developer: crear una conexion enc_extra3 (localhost:1521, servicio FREEPDB1)
--     con una clave mala y pulsar "Conectar" 3 veces.
--     Cada intento debe dar:  ORA-01017: invalid credential or not authorized

-- 1.3 Un 4.o intento, ahora con la clave CORRECTA, debe fallar igual por el bloqueo:
--         ORA-28000: the account is locked

-- 1.4 (SYSTEM) La cuenta debe aparecer bloqueada: LOCKED(TIMED) (el bloqueo dura 1 hora,
--     PASSWORD_LOCK_TIME = 1/24).
SELECT username, account_status, lock_date FROM dba_users WHERE username = 'ENC_EXTRA3';

-- 1.5 (SYSTEM) Desbloquear para dejar todo como estaba.
ALTER USER enc_extra3 ACCOUNT UNLOCK;
SELECT username, account_status FROM dba_users WHERE username = 'ENC_EXTRA3';

-- =================================================================================
-- PARTE 2. SESSIONS_PER_USER = 2  (maximo 2 sesiones simultaneas por usuario)
-- Usuario de prueba: ENC_TIPO1.
-- =================================================================================

-- 2.1 Abrir tres sesiones, pueden ser tipo1_A, tipo1_B y tipo1_C con ENC_TIPO1 y en las dos primera sesiones ingresar normalmente:
-- esas dos primeras sesiones deben ingresar sin problema.

-- Ejecutar en tipo1_A, debe aparecer como USER -> ENC_TIPO1
SELECT USER FROM dual;

-- Cuando se intenta ingresar a la tercera sesión esta falla y da ORA-02391: exceeded simultaneous SESSION_PER_USER limit

-- 2.2 (SYSTEM, con las sesiones 1 y 2 aun abiertas) Debe dar 2 sesiones.
SELECT username, COUNT(*) AS sesiones FROM v$session
WHERE username = 'ENC_TIPO1' GROUP BY username;

-- 2.3 Cerrar las terminales.