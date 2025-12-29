-- Migración 072: Eliminar todas las referencias a FK_ID_ROL
-- ============================================================
-- Corrige los SPs de login y otros que aún usan FK_ID_ROL
-- Ya no existe el sistema de roles, se usa permisos por membresía
-- ============================================================

-- =====================================================
-- SP: login_usuario (sin FK_ID_ROL)
-- =====================================================
DROP PROCEDURE IF EXISTS login_usuario;
DELIMITER //
CREATE PROCEDURE login_usuario(
    IN p_nombre_usuario VARCHAR(100),
    IN p_contrasenia VARCHAR(255)
)
BEGIN
    DECLARE v_id_usuario INT DEFAULT 0;
    DECLARE v_contrasenia_db VARCHAR(255);
    DECLARE v_estado INT DEFAULT 1;
    DECLARE v_intentos INT DEFAULT 0;
    DECLARE v_fecha_bloqueo DATETIME;

    -- Buscar usuario por correo/nombre_usuario
    SELECT
        PK_ID_USUARIO,
        CONTRASENIA,
        ESTADO,
        COALESCE(INTENTOS_FALLIDOS, 0),
        FECHA_BLOQUEO
    INTO v_id_usuario, v_contrasenia_db, v_estado, v_intentos, v_fecha_bloqueo
    FROM usuario
    WHERE LOWER(NOMBRE_USUARIO) = LOWER(TRIM(p_nombre_usuario))
    LIMIT 1;

    -- Si no existe el usuario (código 98)
    IF v_id_usuario = 0 THEN
        SELECT 98 AS CODIGO_ESTADO, NULL AS CONTRASENIA_HASH, 0 AS PK_ID_USUARIO;

    -- Si la cuenta está inhabilitada (código 97)
    ELSEIF v_estado = 0 THEN
        SELECT 97 AS CODIGO_ESTADO, NULL AS CONTRASENIA_HASH, v_id_usuario AS PK_ID_USUARIO;

    -- Si está bloqueada por intentos fallidos (código 0)
    ELSEIF v_intentos >= 5 AND v_fecha_bloqueo IS NOT NULL AND v_fecha_bloqueo > DATE_SUB(NOW(), INTERVAL 1 HOUR) THEN
        SELECT 0 AS CODIGO_ESTADO, NULL AS CONTRASENIA_HASH, v_id_usuario AS PK_ID_USUARIO;

    ELSE
        -- Retornar datos del usuario (código 1 = OK)
        SELECT
            u.PK_ID_USUARIO,
            u.NOMBRES,
            u.APELLIDOS,
            u.NOMBRE_USUARIO AS CORREO,
            1 AS CODIGO_ESTADO,
            u.ESTADO,
            u.CONTRASENIA AS CONTRASENIA_HASH,
            l.PK_ID_LOCAL AS ID_LOCAL,
            l.NOMBRE_LOCAL AS NOMBRE_LOCAL,
            s.FK_ID_TIPO_MEMBRESIA AS FK_ID_TIPOMEMBRESIA,
            tm.NOMBRE AS NOMBRE_MEMBRESIA,
            CASE WHEN s.PK_ID_SUSCRIPCION IS NOT NULL AND s.ESTADO = 1 THEN 1 ELSE 0 END AS TIENE_MEMBRESIA_ACTIVA
        FROM usuario u
        LEFT JOIN local l ON l.FK_ID_USUARIO = u.PK_ID_USUARIO
        LEFT JOIN suscripcion s ON s.FK_ID_LOCAL = l.PK_ID_LOCAL AND s.ESTADO = 1
        LEFT JOIN tipo_membresia tm ON s.FK_ID_TIPO_MEMBRESIA = tm.PK_ID_TIPO_MEMBRESIA
        WHERE u.PK_ID_USUARIO = v_id_usuario;
    END IF;
END//
DELIMITER ;

-- =====================================================
-- SP: login_usuario_google (sin FK_ID_ROL)
-- =====================================================
DROP PROCEDURE IF EXISTS login_usuario_google;
DELIMITER //
CREATE PROCEDURE login_usuario_google(
    IN p_correo VARCHAR(100)
)
BEGIN
    SELECT
        u.PK_ID_USUARIO,
        u.NOMBRES,
        u.APELLIDOS,
        u.NOMBRE_USUARIO AS CORREO,
        1 AS CODIGO_ESTADO,
        u.ESTADO,
        l.PK_ID_LOCAL AS ID_LOCAL,
        l.NOMBRE_LOCAL AS NOMBRE_LOCAL,
        s.FK_ID_TIPO_MEMBRESIA AS FK_ID_TIPOMEMBRESIA,
        tm.NOMBRE AS NOMBRE_MEMBRESIA,
        CASE WHEN s.PK_ID_SUSCRIPCION IS NOT NULL AND s.ESTADO = 1 THEN 1 ELSE 0 END AS TIENE_MEMBRESIA_ACTIVA
    FROM usuario u
    LEFT JOIN local l ON l.FK_ID_USUARIO = u.PK_ID_USUARIO
    LEFT JOIN suscripcion s ON s.FK_ID_LOCAL = l.PK_ID_LOCAL AND s.ESTADO = 1
    LEFT JOIN tipo_membresia tm ON s.FK_ID_TIPO_MEMBRESIA = tm.PK_ID_TIPO_MEMBRESIA
    WHERE LOWER(u.NOMBRE_USUARIO) = LOWER(TRIM(p_correo))
    LIMIT 1;
END//
DELIMITER ;

-- =====================================================
-- SP: login_google (sin FK_ID_ROL)
-- =====================================================
DROP PROCEDURE IF EXISTS login_google;
DELIMITER //
CREATE PROCEDURE login_google(
    IN p_email VARCHAR(100),
    IN p_nombre VARCHAR(100),
    IN p_apellido VARCHAR(100),
    IN p_google_id VARCHAR(255)
)
BEGIN
    DECLARE v_id_usuario INT DEFAULT 0;
    DECLARE v_estado INT DEFAULT 1;

    SELECT PK_ID_USUARIO, ESTADO
    INTO v_id_usuario, v_estado
    FROM usuario
    WHERE LOWER(NOMBRE_USUARIO) = LOWER(TRIM(p_email))
    LIMIT 1;

    -- Usuario no existe: código 0
    IF v_id_usuario = 0 THEN
        SELECT
            0 AS PK_ID_USUARIO,
            0 AS CODIGO_ESTADO,
            NULL AS NOMBRES,
            NULL AS APELLIDOS,
            NULL AS ID_LOCAL,
            NULL AS NOMBRE_LOCAL;

    -- Usuario inhabilitado: código 97
    ELSEIF v_estado = 0 THEN
        SELECT
            v_id_usuario AS PK_ID_USUARIO,
            97 AS CODIGO_ESTADO,
            NULL AS NOMBRES,
            NULL AS APELLIDOS,
            NULL AS ID_LOCAL,
            NULL AS NOMBRE_LOCAL;

    -- Usuario activo: código 1
    ELSE
        SELECT
            u.PK_ID_USUARIO,
            1 AS CODIGO_ESTADO,
            u.NOMBRES,
            u.APELLIDOS,
            l.PK_ID_LOCAL AS ID_LOCAL,
            l.NOMBRE_LOCAL AS NOMBRE_LOCAL
        FROM usuario u
        LEFT JOIN local l ON l.FK_ID_USUARIO = u.PK_ID_USUARIO
        WHERE u.PK_ID_USUARIO = v_id_usuario;
    END IF;
END//
DELIMITER ;

-- =====================================================
-- SP: consultar_usuario (sin FK_ID_ROL)
-- =====================================================
DROP PROCEDURE IF EXISTS consultar_usuario;
DELIMITER //
CREATE PROCEDURE consultar_usuario(
    IN p_id_usuario INT
)
BEGIN
    IF p_id_usuario > 0 THEN
        SELECT
            PK_ID_USUARIO, NOMBRES, APELLIDOS, TELEFONO, NOMBRE_USUARIO AS CORREO,
            DOCUMENTO_IDENTIDAD, FK_ID_TIPO_DOCUMENTO, ESTADO,
            CODIGO_REFERIDO, CODIGO_REFERIDO_USADO, CORREO_VERIFICADO,
            CLIENTES_REFERIDOS_TOTAL
        FROM usuario
        WHERE PK_ID_USUARIO = p_id_usuario;
    ELSE
        SELECT
            PK_ID_USUARIO, NOMBRES, APELLIDOS, TELEFONO, NOMBRE_USUARIO AS CORREO,
            DOCUMENTO_IDENTIDAD, FK_ID_TIPO_DOCUMENTO, ESTADO,
            CODIGO_REFERIDO, CODIGO_REFERIDO_USADO, CORREO_VERIFICADO,
            CLIENTES_REFERIDOS_TOTAL
        FROM usuario;
    END IF;
END//
DELIMITER ;

-- =====================================================
-- Eliminar SPs obsoletos de roles
-- =====================================================
DROP PROCEDURE IF EXISTS asignar_rol;
DROP PROCEDURE IF EXISTS consultar_roles;
DROP PROCEDURE IF EXISTS crear_rol;
DROP PROCEDURE IF EXISTS editar_rol;
DROP PROCEDURE IF EXISTS eliminar_rol;
DROP PROCEDURE IF EXISTS asignar_permiso_rol;
DROP PROCEDURE IF EXISTS consultar_permiso;

-- =====================================================
-- Eliminar tablas de roles si existen
-- =====================================================
SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS permiso_de_rol;
DROP TABLE IF EXISTS rol;
SET FOREIGN_KEY_CHECKS = 1;

-- =====================================================
-- VERIFICACIÓN
-- =====================================================
SELECT 'MIGRACION 072 COMPLETADA' as info;
SELECT 'SPs de login actualizados para usar CODIGO_ESTADO en lugar de FK_ID_ROL' as detalle;
