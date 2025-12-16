-- =============================================
-- Migración: 003_fix_recuperar_contrasenia.sql
-- Fecha: 2025-12-15
-- Descripción: Corrige problemas en los procedimientos de recuperación de contraseña
--
-- PROBLEMAS CORREGIDOS:
-- 1. El token UUID es muy largo para mostrar al usuario (debería ser código corto)
-- 2. No se invalida el token después de usarlo
-- 3. No hay límite de intentos de recuperación
-- 4. No se retorna confirmación del cambio
-- 5. Falta validación de contraseña mínima
-- 6. El procedimiento validar_token_recuperacion no retorna nada si el token es inválido
-- =============================================

-- Agregar columna para contar intentos de recuperación (si no existe)
SET @column_exists = (
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'usuario'
    AND COLUMN_NAME = 'INTENTOS_RECUPERACION'
);

SET @sql = IF(@column_exists = 0,
    'ALTER TABLE usuario ADD COLUMN INTENTOS_RECUPERACION INT DEFAULT 0',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Agregar columna para fecha del último intento de recuperación (si no existe)
SET @column_exists2 = (
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'usuario'
    AND COLUMN_NAME = 'FECHA_ULTIMO_INTENTO_RECUPERACION'
);

SET @sql2 = IF(@column_exists2 = 0,
    'ALTER TABLE usuario ADD COLUMN FECHA_ULTIMO_INTENTO_RECUPERACION DATETIME NULL',
    'SELECT 1');
PREPARE stmt2 FROM @sql2;
EXECUTE stmt2;
DEALLOCATE PREPARE stmt2;

DELIMITER //

-- =============================================
-- Procedimiento: generar_token_recuperacion
-- Genera un código de 6 dígitos en lugar de UUID completo
-- =============================================
DROP PROCEDURE IF EXISTS `generar_token_recuperacion`//

CREATE PROCEDURE `generar_token_recuperacion`(IN p_fk_id_usuario INT)
BEGIN
    DECLARE v_nuevo_token VARCHAR(6);
    DECLARE v_intentos_hoy INT DEFAULT 0;
    DECLARE v_resultado INT DEFAULT 0;
    DECLARE v_mensaje VARCHAR(255);

    -- Verificar si el usuario existe
    IF NOT EXISTS (SELECT 1 FROM usuario WHERE PK_ID_USUARIO = p_fk_id_usuario) THEN
        SET v_resultado = -1;
        SET v_mensaje = 'Usuario no encontrado.';
    ELSE
        -- Verificar intentos de recuperación en las últimas 24 horas
        SELECT IFNULL(INTENTOS_RECUPERACION, 0) INTO v_intentos_hoy
        FROM usuario
        WHERE PK_ID_USUARIO = p_fk_id_usuario
        AND FECHA_ULTIMO_INTENTO_RECUPERACION > NOW() - INTERVAL 24 HOUR;

        IF v_intentos_hoy >= 5 THEN
            SET v_resultado = -2;
            SET v_mensaje = 'Has excedido el límite de intentos de recuperación. Intenta en 24 horas.';
        ELSE
            -- Generar código de 6 dígitos
            SET v_nuevo_token = LPAD(FLOOR(RAND() * 1000000), 6, '0');

            -- Actualizar el token y la fecha de expiración
            UPDATE usuario
            SET TOKEN_RECUPERACION = v_nuevo_token,
                FECHA_EXPIRACION_TOKEN = NOW() + INTERVAL 5 MINUTE,
                INTENTOS_RECUPERACION = IFNULL(INTENTOS_RECUPERACION, 0) + 1,
                FECHA_ULTIMO_INTENTO_RECUPERACION = NOW()
            WHERE PK_ID_USUARIO = p_fk_id_usuario;

            SET v_resultado = 1;
            SET v_mensaje = 'Token generado exitosamente.';
        END IF;
    END IF;

    SELECT v_resultado AS resultado, v_mensaje AS mensaje;
END//

-- =============================================
-- Procedimiento: obtener_token_recuperacion
-- Retorna el token solo si es válido y no ha expirado
-- =============================================
DROP PROCEDURE IF EXISTS `obtener_token_recuperacion`//

CREATE PROCEDURE `obtener_token_recuperacion`(IN p_fk_id_usuario INT)
BEGIN
    SELECT
        TOKEN_RECUPERACION,
        FECHA_EXPIRACION_TOKEN,
        CASE
            WHEN TOKEN_RECUPERACION IS NULL THEN 0
            WHEN FECHA_EXPIRACION_TOKEN <= NOW() THEN -1
            ELSE 1
        END AS estado_token
    FROM usuario
    WHERE PK_ID_USUARIO = p_fk_id_usuario;
END//

-- =============================================
-- Procedimiento: validar_token_recuperacion
-- Valida el token y retorna el ID del usuario si es válido
-- =============================================
DROP PROCEDURE IF EXISTS `validar_token_recuperacion`//

CREATE PROCEDURE `validar_token_recuperacion`(IN p_token VARCHAR(255))
BEGIN
    DECLARE v_id_usuario INT DEFAULT NULL;
    DECLARE v_fecha_expiracion DATETIME;

    -- Buscar el usuario por token
    SELECT PK_ID_USUARIO, FECHA_EXPIRACION_TOKEN
    INTO v_id_usuario, v_fecha_expiracion
    FROM usuario
    WHERE TOKEN_RECUPERACION = p_token
    LIMIT 1;

    -- Verificar si el token existe y no ha expirado
    IF v_id_usuario IS NULL THEN
        SELECT
            NULL AS PK_ID_USUARIO,
            -1 AS resultado,
            'Token no encontrado.' AS mensaje;
    ELSEIF v_fecha_expiracion <= NOW() THEN
        -- Limpiar token expirado
        UPDATE usuario
        SET TOKEN_RECUPERACION = NULL, FECHA_EXPIRACION_TOKEN = NULL
        WHERE PK_ID_USUARIO = v_id_usuario;

        SELECT
            NULL AS PK_ID_USUARIO,
            -2 AS resultado,
            'El código ha expirado. Solicita uno nuevo.' AS mensaje;
    ELSE
        SELECT
            v_id_usuario AS PK_ID_USUARIO,
            1 AS resultado,
            'Token válido.' AS mensaje;
    END IF;
END//

-- =============================================
-- Procedimiento: recuperar_contrasenia
-- Actualiza la contraseña e invalida el token
-- =============================================
DROP PROCEDURE IF EXISTS `recuperar_contrasenia`//

CREATE PROCEDURE `recuperar_contrasenia`(
    IN `p_id_usuario` INT,
    IN `p_nueva_contrasenia` MEDIUMTEXT
)
BEGIN
    DECLARE v_resultado INT DEFAULT 0;
    DECLARE v_mensaje VARCHAR(255);

    -- Verificar si el usuario existe
    IF NOT EXISTS (SELECT 1 FROM usuario WHERE PK_ID_USUARIO = p_id_usuario) THEN
        SET v_resultado = -1;
        SET v_mensaje = 'Usuario no encontrado.';
    ELSEIF p_nueva_contrasenia IS NULL OR LENGTH(p_nueva_contrasenia) < 8 THEN
        SET v_resultado = -2;
        SET v_mensaje = 'La contraseña debe tener al menos 8 caracteres.';
    ELSE
        -- Actualizar la contraseña e invalidar el token
        UPDATE usuario
        SET CONTRASENIA = p_nueva_contrasenia,
            TOKEN_RECUPERACION = NULL,
            FECHA_EXPIRACION_TOKEN = NULL,
            INTENTOS_RECUPERACION = 0,
            INTENTOS_FALLIDOS = 0,
            ESTADO = 1,
            FECHA_BLOQUEO = NULL
        WHERE PK_ID_USUARIO = p_id_usuario;

        SET v_resultado = 1;
        SET v_mensaje = 'Contraseña actualizada exitosamente.';
    END IF;

    SELECT v_resultado AS resultado, v_mensaje AS mensaje;
END//

DELIMITER ;

-- =============================================
-- EVENTOS (Opcional - ejecutar por separado si se necesitan)
-- Requiere: SET GLOBAL event_scheduler = ON;
-- =============================================

-- Evento para limpiar tokens expirados cada hora
-- DROP EVENT IF EXISTS limpiar_tokens_expirados;
-- CREATE EVENT limpiar_tokens_expirados
-- ON SCHEDULE EVERY 1 HOUR
-- STARTS CURRENT_TIMESTAMP
-- ON COMPLETION PRESERVE ENABLE
-- DO UPDATE usuario SET TOKEN_RECUPERACION = NULL, FECHA_EXPIRACION_TOKEN = NULL
--    WHERE FECHA_EXPIRACION_TOKEN IS NOT NULL AND FECHA_EXPIRACION_TOKEN <= NOW();

-- Evento para resetear intentos de recuperación después de 24 horas
-- DROP EVENT IF EXISTS resetear_intentos_recuperacion;
-- CREATE EVENT resetear_intentos_recuperacion
-- ON SCHEDULE EVERY 6 HOUR
-- STARTS CURRENT_TIMESTAMP
-- ON COMPLETION PRESERVE ENABLE
-- DO UPDATE usuario SET INTENTOS_RECUPERACION = 0
--    WHERE FECHA_ULTIMO_INTENTO_RECUPERACION IS NOT NULL
--    AND FECHA_ULTIMO_INTENTO_RECUPERACION <= NOW() - INTERVAL 24 HOUR;
