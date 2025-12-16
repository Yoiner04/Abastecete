-- =============================================
-- Migración: 004_fix_crear_usuario_google.sql
-- Fecha: 2025-12-15
-- Descripción: Corrige problemas en el procedimiento crear_usuario_google
--
-- PROBLEMAS CORREGIDOS:
-- 1. Genera teléfono y documento secuenciales (problema de privacidad y unicidad)
-- 2. No hay transacción explícita con START TRANSACTION
-- 3. Contraseña por defecto hardcodeada (inseguro)
-- 4. No valida si el correo ya existe
-- 5. No retorna resultado al cliente
-- 6. El apellido "N/A" no es apropiado
-- =============================================

DELIMITER //

DROP PROCEDURE IF EXISTS `crear_usuario_google`//

CREATE PROCEDURE `crear_usuario_google`(
    IN `p_full_name` VARCHAR(255),
    IN `p_correo` VARCHAR(255),
    IN `p_fk_id_metodo_autenticacion` INT,
    IN `p_fk_id_rol` INT
)
BEGIN
    DECLARE v_first_name VARCHAR(100);
    DECLARE v_last_name VARCHAR(100);
    DECLARE v_persona_id INT;
    DECLARE v_usuario_id INT;
    DECLARE v_resultado INT DEFAULT 0;
    DECLARE v_mensaje VARCHAR(255);
    DECLARE v_codigo_referido VARCHAR(20);
    DECLARE v_codigo_existe INT DEFAULT 1;
    DECLARE v_intentos INT DEFAULT 0;

    -- Handler para errores
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET v_resultado = -99;
        SET v_mensaje = 'Error interno al crear el usuario.';
        SELECT v_resultado AS resultado, v_mensaje AS mensaje, NULL AS id_usuario;
    END;

    -- Iniciar transacción
    START TRANSACTION;

    -- Validar correo
    IF p_correo IS NULL OR TRIM(p_correo) = '' THEN
        SET v_resultado = -1;
        SET v_mensaje = 'El correo es requerido.';
    ELSEIF p_correo NOT REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN
        SET v_resultado = -2;
        SET v_mensaje = 'El correo no es válido.';
    ELSEIF EXISTS (SELECT 1 FROM usuario WHERE NOMBRE_USUARIO = LOWER(TRIM(p_correo))) THEN
        SET v_resultado = -3;
        SET v_mensaje = 'Ya existe un usuario con este correo.';
    ELSEIF EXISTS (SELECT 1 FROM persona WHERE CORREO = LOWER(TRIM(p_correo))) THEN
        SET v_resultado = -4;
        SET v_mensaje = 'Este correo ya está registrado.';
    ELSE
        -- Separar nombre y apellido
        IF p_full_name IS NULL OR TRIM(p_full_name) = '' THEN
            SET v_first_name = 'Usuario';
            SET v_last_name = 'Google';
        ELSE
            SET v_first_name = TRIM(SUBSTRING_INDEX(p_full_name, ' ', 1));
            SET v_last_name = TRIM(SUBSTRING(p_full_name, LOCATE(' ', p_full_name) + 1));

            IF v_last_name = '' OR v_last_name = v_first_name THEN
                SET v_last_name = 'Usuario';
            END IF;
        END IF;

        -- Generar código de referido único
        WHILE v_codigo_existe = 1 AND v_intentos < 10 DO
            SET v_codigo_referido = CONCAT('GOO', LPAD(FLOOR(RAND() * 10000000), 7, '0'));
            SET v_codigo_existe = (SELECT COUNT(*) FROM persona WHERE CODIGO_REFERIDO = v_codigo_referido);
            SET v_intentos = v_intentos + 1;
        END WHILE;

        IF v_codigo_existe = 1 THEN
            SET v_resultado = -5;
            SET v_mensaje = 'Error al generar código de referido.';
        ELSE
            -- Insertar persona (sin teléfono ni documento - se completará después)
            INSERT INTO persona (
                NOMBRES,
                APELLIDOS,
                TELEFONO,
                CORREO,
                DOCUMENTO_IDENTIDAD,
                ESTADO,
                FK_ID_TIPO_DOCUMENTO,
                CODIGO_REFERIDO,
                CODIGO_REFERIDO_USUARIO
            ) VALUES (
                v_first_name,
                v_last_name,
                NULL,  -- Teléfono pendiente de completar
                LOWER(TRIM(p_correo)),
                NULL,  -- Documento pendiente de completar
                1,
                1,     -- Tipo documento por defecto
                v_codigo_referido,
                NULL
            );

            SET v_persona_id = LAST_INSERT_ID();

            -- Insertar usuario (sin contraseña para usuarios de Google)
            INSERT INTO usuario (
                FK_ID_PERSONA,
                NOMBRE_USUARIO,
                CONTRASENIA,
                TIPO_AUTENTICACION,
                FK_ID_ROL,
                ESTADO,
                INTENTOS_FALLIDOS
            ) VALUES (
                v_persona_id,
                LOWER(TRIM(p_correo)),
                NULL,  -- Sin contraseña para auth con Google
                p_fk_id_metodo_autenticacion,
                IFNULL(p_fk_id_rol, 3),  -- Rol 3 por defecto
                1,
                0
            );

            SET v_usuario_id = LAST_INSERT_ID();

            COMMIT;

            SET v_resultado = 1;
            SET v_mensaje = 'Usuario creado exitosamente.';
        END IF;
    END IF;

    -- Si hubo error, hacer rollback
    IF v_resultado < 0 THEN
        ROLLBACK;
    END IF;

    SELECT v_resultado AS resultado, v_mensaje AS mensaje, v_usuario_id AS id_usuario;
END//

DELIMITER ;

-- Hacer que DOCUMENTO_IDENTIDAD sea nullable (para usuarios de Google que no lo proporcionan)
ALTER TABLE persona MODIFY COLUMN DOCUMENTO_IDENTIDAD INT NULL;

-- Hacer que TELEFONO sea nullable
ALTER TABLE persona MODIFY COLUMN TELEFONO VARCHAR(40) NULL;
