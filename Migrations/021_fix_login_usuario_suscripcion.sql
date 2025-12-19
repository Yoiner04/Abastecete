-- =============================================
-- Migración 021: Actualizar login_usuario para nueva estructura de suscripciones
-- Descripción: El SP login_usuario usaba FK_ID_TIPOMEMBRESIA de la tabla local,
--              pero esa columna fue eliminada en la migración 020.
--              Ahora debe obtener el tipo de membresía desde la tabla suscripcion.
-- =============================================

DELIMITER //

DROP PROCEDURE IF EXISTS `login_usuario`//

CREATE PROCEDURE `login_usuario`(
    IN `p_nombre_usuario` VARCHAR(50),
    IN `p_contrasenia` MEDIUMTEXT
)
BEGIN
    DECLARE id_usuario INT DEFAULT NULL;
    DECLARE estado_usuario INT DEFAULT NULL;
    DECLARE fecha_bloqueo DATETIME DEFAULT NULL;
    DECLARE intentos_actuales INT DEFAULT 0;
    DECLARE contrasenia_correcta BOOLEAN DEFAULT FALSE;
    DECLARE id_tipo_membresia INT DEFAULT NULL;
    DECLARE usuario_inhabilitado INT DEFAULT 0;

    -- Iniciar una transacción
    START TRANSACTION;

    -- Obtener datos del usuario y bloquear la fila para evitar modificaciones simultáneas
    SELECT
        PK_ID_USUARIO,
        ESTADO,
        FECHA_BLOQUEO,
        IFNULL(INTENTOS_FALLIDOS, 0),
        (CONTRASENIA = p_contrasenia) AS contrasenia_correcta
    INTO id_usuario, estado_usuario, fecha_bloqueo, intentos_actuales, contrasenia_correcta
    FROM usuario
    WHERE NOMBRE_USUARIO = p_nombre_usuario
    FOR UPDATE;

    -- Si el usuario no existe, cancelar transacción y devolver código de error
    IF id_usuario IS NULL THEN
        ROLLBACK;
        SELECT 98 AS FK_ID_ROL, NULL AS FK_ID_PERSONA, NULL AS PK_ID_USUARIO, NULL AS FK_ID_TIPOMEMBRESIA, NULL AS NOMBRE_USUARIO;

    -- Verificar si el usuario está inhabilitado permanentemente (estado = 97)
    ELSEIF estado_usuario = 97 THEN
        ROLLBACK;
        SELECT 97 AS FK_ID_ROL, NULL AS FK_ID_PERSONA, NULL AS PK_ID_USUARIO, NULL AS FK_ID_TIPOMEMBRESIA, NULL AS NOMBRE_USUARIO;

    -- Verificar si el usuario está bloqueado temporalmente
    ELSEIF estado_usuario = 0 AND fecha_bloqueo IS NOT NULL AND fecha_bloqueo > NOW() THEN
        ROLLBACK;
        SELECT 0 AS FK_ID_ROL, NULL AS FK_ID_PERSONA, NULL AS PK_ID_USUARIO, NULL AS FK_ID_TIPOMEMBRESIA, NULL AS NOMBRE_USUARIO;

    ELSE
        -- Si la fecha de bloqueo ya pasó, desbloquear usuario
        IF estado_usuario = 0 AND (fecha_bloqueo IS NULL OR fecha_bloqueo <= NOW()) THEN
            UPDATE usuario
            SET ESTADO = 1, INTENTOS_FALLIDOS = 0, FECHA_BLOQUEO = NULL
            WHERE PK_ID_USUARIO = id_usuario;
            SET estado_usuario = 1;
            SET intentos_actuales = 0;
        END IF;

        -- Si el usuario está activo
        IF estado_usuario = 1 THEN
            IF contrasenia_correcta THEN
                -- Si la contraseña es correcta, reiniciar intentos fallidos
                UPDATE usuario
                SET INTENTOS_FALLIDOS = 0
                WHERE PK_ID_USUARIO = id_usuario;

                -- Obtener el tipo de membresía desde la nueva estructura de suscripciones
                -- Usa la tabla suscripcion en lugar de la columna eliminada FK_ID_TIPOMEMBRESIA
                SELECT s.FK_ID_TIPO_MEMBRESIA
                INTO id_tipo_membresia
                FROM usuario u
                INNER JOIN persona p ON u.FK_ID_PERSONA = p.PK_ID_PERSONA
                LEFT JOIN local l ON l.FK_ID_PERSONA = p.PK_ID_PERSONA
                LEFT JOIN suscripcion s ON l.FK_ID_SUSCRIPCION_ACTIVA = s.PK_ID_SUSCRIPCION AND s.ESTADO = 1
                WHERE u.PK_ID_USUARIO = id_usuario
                LIMIT 1;

                COMMIT;

                -- Retornar datos del usuario
                SELECT
                    u.NOMBRE_USUARIO,
                    u.FK_ID_ROL,
                    u.FK_ID_PERSONA,
                    u.PK_ID_USUARIO,
                    IFNULL(id_tipo_membresia, 0) AS FK_ID_TIPOMEMBRESIA
                FROM usuario u
                WHERE u.PK_ID_USUARIO = id_usuario;

            ELSE
                -- Incrementar intentos fallidos
                SET intentos_actuales = intentos_actuales + 1;

                UPDATE usuario
                SET INTENTOS_FALLIDOS = intentos_actuales
                WHERE PK_ID_USUARIO = id_usuario;

                -- Si alcanza 5 intentos, bloquear usuario por 1 hora
                IF intentos_actuales >= 5 THEN
                    UPDATE usuario
                    SET ESTADO = 0, FECHA_BLOQUEO = NOW() + INTERVAL 1 HOUR
                    WHERE PK_ID_USUARIO = id_usuario;

                    COMMIT;
                    SELECT 0 AS FK_ID_ROL, NULL AS FK_ID_PERSONA, NULL AS PK_ID_USUARIO, NULL AS FK_ID_TIPOMEMBRESIA, NULL AS NOMBRE_USUARIO;
                ELSE
                    COMMIT;
                    SELECT 99 AS FK_ID_ROL, NULL AS FK_ID_PERSONA, NULL AS PK_ID_USUARIO, NULL AS FK_ID_TIPOMEMBRESIA, NULL AS NOMBRE_USUARIO;
                END IF;
            END IF;
        ELSE
            -- Estado desconocido - retornar error genérico
            ROLLBACK;
            SELECT 98 AS FK_ID_ROL, NULL AS FK_ID_PERSONA, NULL AS PK_ID_USUARIO, NULL AS FK_ID_TIPOMEMBRESIA, NULL AS NOMBRE_USUARIO;
        END IF;
    END IF;
END//

DELIMITER ;
