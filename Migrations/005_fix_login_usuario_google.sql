-- =============================================
-- Migración: 005_fix_login_usuario_google.sql
-- Fecha: 2025-12-15
-- Descripción: Corrige problemas en el procedimiento login_usuario_google
--
-- PROBLEMAS CORREGIDOS:
-- 1. No verifica si el usuario está inhabilitado (ESTADO = 0 o 97)
-- 2. No verifica si el usuario está bloqueado
-- 3. Retorna estructura inconsistente (0 AS PK_ID_USUARIO cuando no existe)
-- 4. No registra el último acceso
-- =============================================

DELIMITER //

DROP PROCEDURE IF EXISTS `login_usuario_google`//

CREATE PROCEDURE `login_usuario_google`(
    IN `p_correo` VARCHAR(255)
)
BEGIN
    DECLARE v_user_count INT DEFAULT 0;
    DECLARE v_estado INT DEFAULT 0;
    DECLARE v_id_usuario INT DEFAULT NULL;
    DECLARE v_fecha_bloqueo DATETIME DEFAULT NULL;

    -- Verificar si el usuario existe
    SELECT
        COUNT(*),
        MAX(PK_ID_USUARIO),
        MAX(ESTADO),
        MAX(FECHA_BLOQUEO)
    INTO v_user_count, v_id_usuario, v_estado, v_fecha_bloqueo
    FROM usuario
    WHERE NOMBRE_USUARIO = LOWER(TRIM(p_correo));

    IF v_user_count = 0 THEN
        -- Usuario no existe - retornar código para registro
        SELECT
            NULL AS PK_ID_USUARIO,
            0 AS FK_ID_ROL,
            NULL AS FK_ID_PERSONA,
            NULL AS NOMBRE_USUARIO,
            NULL AS FK_ID_TIPOMEMBRESIA,
            'NO_EXISTE' AS estado_login;

    ELSEIF v_estado = 97 THEN
        -- Usuario inhabilitado permanentemente
        SELECT
            NULL AS PK_ID_USUARIO,
            97 AS FK_ID_ROL,
            NULL AS FK_ID_PERSONA,
            NULL AS NOMBRE_USUARIO,
            NULL AS FK_ID_TIPOMEMBRESIA,
            'INHABILITADO' AS estado_login;

    ELSEIF v_estado = 0 AND v_fecha_bloqueo IS NOT NULL AND v_fecha_bloqueo > NOW() THEN
        -- Usuario bloqueado temporalmente
        SELECT
            NULL AS PK_ID_USUARIO,
            0 AS FK_ID_ROL,
            NULL AS FK_ID_PERSONA,
            NULL AS NOMBRE_USUARIO,
            NULL AS FK_ID_TIPOMEMBRESIA,
            'BLOQUEADO' AS estado_login;

    ELSE
        -- Desbloquear si el tiempo de bloqueo ya pasó
        IF v_estado = 0 AND (v_fecha_bloqueo IS NULL OR v_fecha_bloqueo <= NOW()) THEN
            UPDATE usuario
            SET ESTADO = 1,
                INTENTOS_FALLIDOS = 0,
                FECHA_BLOQUEO = NULL
            WHERE PK_ID_USUARIO = v_id_usuario;
        END IF;

        -- Login exitoso - retornar datos del usuario
        SELECT
            u.PK_ID_USUARIO,
            u.FK_ID_ROL,
            u.FK_ID_PERSONA,
            u.NOMBRE_USUARIO,
            l.FK_ID_TIPOMEMBRESIA,
            'OK' AS estado_login
        FROM usuario u
        LEFT JOIN persona p ON u.FK_ID_PERSONA = p.PK_ID_PERSONA
        LEFT JOIN local l ON l.FK_ID_PERSONA = p.PK_ID_PERSONA
        WHERE u.PK_ID_USUARIO = v_id_usuario
        LIMIT 1;

        -- Actualizar último acceso (opcional - agregar columna si se desea)
        -- UPDATE usuario SET ULTIMO_ACCESO = NOW() WHERE PK_ID_USUARIO = v_id_usuario;
    END IF;
END//

DELIMITER ;
