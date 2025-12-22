-- =============================================
-- Migración 044: Cambiar DOCUMENTO_IDENTIDAD de INT a BIGINT
-- Fecha: 2025-12-21
-- Problema: Documentos largos como 10051241478 exceden el límite
--           de INT (max 2,147,483,647)
-- =============================================

-- 1. Modificar la columna en la tabla persona
ALTER TABLE `persona`
MODIFY COLUMN `DOCUMENTO_IDENTIDAD` BIGINT DEFAULT NULL;

-- 2. Recrear el SP crear_usuario_persona con BIGINT
DROP PROCEDURE IF EXISTS `crear_usuario_persona`;

DELIMITER //

CREATE PROCEDURE `crear_usuario_persona`(
    IN `p_nombre` VARCHAR(40),
    IN `p_apellido` VARCHAR(40),
    IN `p_documento` BIGINT,
    IN `p_fk_tipo_documento` INT,
    IN `p_telefono` VARCHAR(40),
    IN `p_correo` VARCHAR(50),
    IN `p_contrasenia` MEDIUMTEXT,
    IN `p_codigo_referido_usuario` VARCHAR(20),
    IN `p_fk_id_metodo_autenticacion` INT
)
BEGIN
    DECLARE v_mensaje VARCHAR(500);
    DECLARE v_resultado INT DEFAULT 0;
    DECLARE v_idpersona INT;
    DECLARE v_idusuario INT;
    DECLARE v_codigo_nuevo VARCHAR(20);
    DECLARE v_intentos INT DEFAULT 0;
    DECLARE v_codigo_existe INT DEFAULT 1;

    START TRANSACTION;

    -- Validar campos requeridos
    IF p_nombre IS NULL OR TRIM(p_nombre) = '' THEN
        SET v_mensaje = 'El nombre es requerido.';
        SET v_resultado = -1;
    ELSEIF p_apellido IS NULL OR TRIM(p_apellido) = '' THEN
        SET v_mensaje = 'El apellido es requerido.';
        SET v_resultado = -1;
    ELSEIF p_documento IS NULL OR p_documento <= 0 THEN
        SET v_mensaje = 'El documento de identidad no es válido.';
        SET v_resultado = -1;
    ELSEIF p_correo IS NULL OR TRIM(p_correo) = '' OR p_correo NOT REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$' THEN
        SET v_mensaje = 'El correo electrónico no es válido.';
        SET v_resultado = -1;
    ELSEIF p_contrasenia IS NULL OR LENGTH(p_contrasenia) < 8 THEN
        SET v_mensaje = 'La contraseña debe tener al menos 8 caracteres.';
        SET v_resultado = -1;
    ELSEIF EXISTS (SELECT 1 FROM persona WHERE DOCUMENTO_IDENTIDAD = p_documento AND FK_ID_TIPO_DOCUMENTO = p_fk_tipo_documento) THEN
        SET v_mensaje = 'El documento de identidad ya está registrado con otra persona.';
        SET v_resultado = -2;
    ELSEIF EXISTS (SELECT 1 FROM persona WHERE CORREO = p_correo) THEN
        SET v_mensaje = 'El correo electrónico ya está registrado con otra persona.';
        SET v_resultado = -3;
    ELSEIF EXISTS (SELECT 1 FROM usuario WHERE NOMBRE_USUARIO = p_correo) THEN
        SET v_mensaje = 'Ya existe un usuario con este correo electrónico.';
        SET v_resultado = -4;
    ELSEIF NOT EXISTS (SELECT 1 FROM metodo_autenticacion WHERE PK_ID_METODO_AUTENTICACION = p_fk_id_metodo_autenticacion) THEN
        SET v_mensaje = 'El método de autenticación especificado no existe.';
        SET v_resultado = -5;
    ELSE
        -- Generar código de referido único (con reintentos para evitar colisiones)
        WHILE v_codigo_existe = 1 AND v_intentos < 10 DO
            SET v_codigo_nuevo = CONCAT('COD', LPAD(FLOOR(RAND() * 10000000), 7, '0'));

            SELECT COUNT(*) INTO v_codigo_existe
            FROM persona
            WHERE CODIGO_REFERIDO = v_codigo_nuevo;

            SET v_intentos = v_intentos + 1;
        END WHILE;

        IF v_codigo_existe = 1 THEN
            SET v_mensaje = 'No se pudo generar un código de referido único. Intente nuevamente.';
            SET v_resultado = -6;
        ELSE
            -- Insertar persona
            INSERT INTO persona (
                NOMBRES,
                APELLIDOS,
                TELEFONO,
                DOCUMENTO_IDENTIDAD,
                FK_ID_TIPO_DOCUMENTO,
                CORREO,
                ESTADO,
                CODIGO_REFERIDO,
                CODIGO_REFERIDO_USUARIO
            ) VALUES (
                TRIM(p_nombre),
                TRIM(p_apellido),
                p_telefono,
                p_documento,
                p_fk_tipo_documento,
                LOWER(TRIM(p_correo)),
                1,
                v_codigo_nuevo,
                p_codigo_referido_usuario
            );

            SET v_idpersona = LAST_INSERT_ID();

            -- Insertar usuario
            INSERT INTO usuario (
                FK_ID_PERSONA,
                FK_ID_ROL,
                NOMBRE_USUARIO,
                CONTRASENIA,
                ESTADO,
                TIPO_AUTENTICACION
            ) VALUES (
                v_idpersona,
                3,
                LOWER(TRIM(p_correo)),
                p_contrasenia,
                1,
                p_fk_id_metodo_autenticacion
            );

            SET v_idusuario = LAST_INSERT_ID();

            -- Si se usó un código de referido válido, registrar en historial_referidos
            IF p_codigo_referido_usuario IS NOT NULL AND TRIM(p_codigo_referido_usuario) != '' THEN
                INSERT INTO historial_referidos (
                    FK_ID_PERSONA_REFERIDO,
                    CODIGO_USADO,
                    FECHA_USO
                ) VALUES (
                    v_idpersona,
                    p_codigo_referido_usuario,
                    NOW()
                );
            END IF;

            SET v_mensaje = 'Usuario creado exitosamente.';
            SET v_resultado = v_idusuario;

            COMMIT;
        END IF;
    END IF;

    IF v_resultado <= 0 THEN
        ROLLBACK;
    END IF;

    SELECT v_mensaje AS mensaje, v_resultado AS resultado;
END//

DELIMITER ;
