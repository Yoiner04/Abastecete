-- ============================================================
-- Migración 001: Corregir SP crear_usuario y usuarios existentes
-- ============================================================
-- 1. Corrige el SP crear_usuario (sin OUT params, sin FK_ID_ROL, con código referido)
-- 2. Corrige el SP login_usuario (NOMBRE_LOCAL, FK_ID_TIPOMEMBRESIA)
-- 3. Asigna permisos básicos al usuario existente (ID=2)
-- ============================================================

-- =====================================================
-- PARTE 1: SP crear_usuario corregido
-- =====================================================
DROP PROCEDURE IF EXISTS crear_usuario;
DELIMITER //
CREATE PROCEDURE crear_usuario(
    IN p_nombres VARCHAR(40),
    IN p_apellidos VARCHAR(40),
    IN p_telefono VARCHAR(40),
    IN p_correo VARCHAR(100),
    IN p_contrasenia TEXT,
    IN p_documento BIGINT,
    IN p_fk_tipo_documento INT,
    IN p_fk_rol INT,
    IN p_codigo_referido_usado VARCHAR(50)
)
BEGIN
    DECLARE v_codigo_referido VARCHAR(20);
    DECLARE v_codigo_existe INT DEFAULT 1;
    DECLARE v_id_dueno INT DEFAULT 0;
    DECLARE v_id_usuario INT DEFAULT 0;
    DECLARE v_mensaje VARCHAR(255) DEFAULT '';

    -- Validaciones
    IF EXISTS (SELECT 1 FROM usuario WHERE NOMBRE_USUARIO = LOWER(TRIM(p_correo))) THEN
        SET v_mensaje = 'El correo electrónico ya está registrado.';
        SELECT 0 AS resultado, v_mensaje AS mensaje;
    ELSEIF p_documento IS NOT NULL AND p_documento > 0 AND EXISTS (SELECT 1 FROM usuario WHERE DOCUMENTO_IDENTIDAD = p_documento AND FK_ID_TIPO_DOCUMENTO = p_fk_tipo_documento) THEN
        SET v_mensaje = 'El documento de identidad ya está registrado.';
        SELECT 0 AS resultado, v_mensaje AS mensaje;
    ELSE
        -- Generar código de referido único
        WHILE v_codigo_existe > 0 DO
            SET v_codigo_referido = CONCAT('COD', LPAD(FLOOR(RAND() * 1000000), 6, '0'));
            SELECT COUNT(*) INTO v_codigo_existe FROM usuario WHERE CODIGO_REFERIDO = v_codigo_referido;
        END WHILE;

        -- Insertar usuario (sin FK_ID_ROL - el sistema usa usuario_permiso)
        INSERT INTO usuario (
            NOMBRES, APELLIDOS, TELEFONO, DOCUMENTO_IDENTIDAD, FK_ID_TIPO_DOCUMENTO,
            CODIGO_REFERIDO, CODIGO_REFERIDO_USADO, NOMBRE_USUARIO, CONTRASENIA, ESTADO,
            CREDITO_REFERIDOS, YA_USO_DESCUENTO_REFERIDO
        ) VALUES (
            p_nombres, p_apellidos, p_telefono,
            CASE WHEN p_documento > 0 THEN p_documento ELSE NULL END,
            COALESCE(p_fk_tipo_documento, 1),
            v_codigo_referido,
            CASE WHEN p_codigo_referido_usado IS NOT NULL AND p_codigo_referido_usado != '' THEN p_codigo_referido_usado ELSE NULL END,
            LOWER(TRIM(p_correo)), p_contrasenia, 1, 0, 0
        );

        SET v_id_usuario = LAST_INSERT_ID();

        -- Registrar referencia si hay código usado
        IF p_codigo_referido_usado IS NOT NULL AND p_codigo_referido_usado != '' THEN
            SELECT PK_ID_USUARIO INTO v_id_dueno
            FROM usuario WHERE CODIGO_REFERIDO = p_codigo_referido_usado AND ESTADO = 1
            LIMIT 1;

            IF v_id_dueno > 0 THEN
                INSERT INTO referencias (FK_ID_DUENO_CODIGO, FK_ID_CLIENTE_REFERIDO, MEMBRESIA_COMPRADA)
                VALUES (v_id_dueno, v_id_usuario, 0);

                -- Incrementar contador de referidos del dueño
                UPDATE usuario
                SET CLIENTES_REFERIDOS_TOTAL = COALESCE(CLIENTES_REFERIDOS_TOTAL, 0) + 1
                WHERE PK_ID_USUARIO = v_id_dueno;
            END IF;
        END IF;

        SET v_mensaje = 'Usuario creado exitosamente.';
        SELECT v_id_usuario AS resultado, v_mensaje AS mensaje;
    END IF;
END//
DELIMITER ;

-- =====================================================
-- PARTE 2: SP login_usuario corregido
-- =====================================================
DROP PROCEDURE IF EXISTS login_usuario;
DELIMITER //
CREATE PROCEDURE login_usuario(
    IN p_nombre_usuario VARCHAR(100),
    IN p_contrasenia TEXT
)
BEGIN
    DECLARE v_id_usuario INT DEFAULT 0;
    DECLARE v_estado INT DEFAULT 0;
    DECLARE v_fecha_bloqueo DATETIME DEFAULT NULL;
    DECLARE v_contrasenia_hash TEXT DEFAULT NULL;
    DECLARE v_intentos INT DEFAULT 0;

    -- Buscar usuario
    SELECT PK_ID_USUARIO, ESTADO, FECHA_BLOQUEO, CONTRASENIA, INTENTOS_FALLIDOS
    INTO v_id_usuario, v_estado, v_fecha_bloqueo, v_contrasenia_hash, v_intentos
    FROM usuario
    WHERE NOMBRE_USUARIO = LOWER(TRIM(p_nombre_usuario))
    LIMIT 1;

    -- Usuario no existe
    IF v_id_usuario = 0 OR v_id_usuario IS NULL THEN
        SELECT 98 AS CODIGO_ESTADO, NULL AS CONTRASENIA_HASH, 0 AS PK_ID_USUARIO;
    -- Usuario inhabilitado
    ELSEIF v_estado = 0 THEN
        SELECT 97 AS CODIGO_ESTADO, NULL AS CONTRASENIA_HASH, v_id_usuario AS PK_ID_USUARIO;
    -- Usuario bloqueado temporalmente
    ELSEIF v_fecha_bloqueo IS NOT NULL AND v_fecha_bloqueo > NOW() THEN
        SELECT 0 AS CODIGO_ESTADO, NULL AS CONTRASENIA_HASH, v_id_usuario AS PK_ID_USUARIO;
    -- Usuario válido - retornar datos para verificación
    ELSE
        SELECT
            1 AS CODIGO_ESTADO,
            u.CONTRASENIA AS CONTRASENIA_HASH,
            u.PK_ID_USUARIO,
            u.NOMBRES,
            u.APELLIDOS,
            u.NOMBRE_USUARIO AS CORREO,
            u.TELEFONO,
            u.DOCUMENTO_IDENTIDAD,
            u.FK_ID_TIPO_DOCUMENTO,
            u.ESTADO,
            u.INTENTOS_FALLIDOS,
            u.FECHA_BLOQUEO,
            u.CODIGO_REFERIDO,
            u.CREDITO_REFERIDOS,
            l.PK_ID_LOCAL AS ID_LOCAL,
            l.NOMBRE_LOCAL AS NOMBRE_LOCAL,
            COALESCE(s.FK_ID_TIPO_MEMBRESIA, 0) AS FK_ID_TIPOMEMBRESIA
        FROM usuario u
        LEFT JOIN local l ON l.FK_ID_USUARIO = u.PK_ID_USUARIO
        LEFT JOIN suscripcion s ON s.PK_ID_SUSCRIPCION = l.FK_ID_SUSCRIPCION_ACTIVA
        WHERE u.PK_ID_USUARIO = v_id_usuario;
    END IF;
END//
DELIMITER ;

-- =====================================================
-- PARTE 3: Corregir usuario existente (ID=2)
-- =====================================================

-- Asegurar que tenga código de referido
UPDATE usuario
SET CODIGO_REFERIDO = CONCAT('COD', LPAD(PK_ID_USUARIO * 1000 + FLOOR(RAND() * 999), 6, '0'))
WHERE PK_ID_USUARIO = 2 AND (CODIGO_REFERIDO IS NULL OR CODIGO_REFERIDO = '');

-- Asegurar campos de referidos
UPDATE usuario
SET CREDITO_REFERIDOS = COALESCE(CREDITO_REFERIDOS, 0),
    YA_USO_DESCUENTO_REFERIDO = COALESCE(YA_USO_DESCUENTO_REFERIDO, 0)
WHERE PK_ID_USUARIO = 2;

-- =====================================================
-- VERIFICACIÓN
-- =====================================================
SELECT 'Usuario 2 corregido:' as info;
SELECT PK_ID_USUARIO, NOMBRES, NOMBRE_USUARIO, CODIGO_REFERIDO, CREDITO_REFERIDOS, ESTADO
FROM usuario WHERE PK_ID_USUARIO = 2;

SELECT 'MIGRACIÓN 001 COMPLETADA - SPs y usuario corregidos' as info;
