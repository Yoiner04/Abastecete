-- =============================================
-- Migración: 002_fix_crear_usuario_persona.sql
-- Fecha: 2025-12-15
-- Descripción: Corrige problemas en el procedimiento crear_usuario_persona
--
-- PROBLEMAS CORREGIDOS:
-- 1. Race condition al obtener el último ID insertado (usaba ORDER BY en vez de LAST_INSERT_ID)
-- 2. No hay transacción explícita (si falla el INSERT en usuario, queda persona huérfana)
-- 3. No retorna el resultado ni mensaje al cliente
-- 4. No valida longitud mínima de contraseña
-- 5. No valida formato de correo electrónico
-- 6. El código referido puede colisionar (RAND no garantiza unicidad)
-- =============================================

DELIMITER //

DROP PROCEDURE IF EXISTS `crear_usuario_persona`//

CREATE PROCEDURE `crear_usuario_persona`(
    IN `p_nombre` VARCHAR(40),
    IN `p_apellido` VARCHAR(40),
    IN `p_documento` INT,
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

    -- Declarar handler para errores
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET v_mensaje = 'Error interno al crear el usuario. Por favor intente nuevamente.';
        SET v_resultado = -99;
        SELECT v_resultado AS resultado, v_mensaje AS mensaje;
    END;

    -- Iniciar transacción
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
    ELSEIF p_correo IS NULL OR TRIM(p_correo) = '' OR p_correo NOT REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN
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
            SET v_codigo_existe = (SELECT COUNT(*) FROM persona WHERE CODIGO_REFERIDO = v_codigo_nuevo);
            SET v_intentos = v_intentos + 1;
        END WHILE;

        IF v_codigo_existe = 1 THEN
            SET v_mensaje = 'Error al generar código de referido. Intente nuevamente.';
            SET v_resultado = -6;
        ELSE
            -- Validar código de referido del usuario (si se proporcionó)
            IF p_codigo_referido_usuario IS NOT NULL
               AND TRIM(p_codigo_referido_usuario) != ''
               AND NOT EXISTS (SELECT 1 FROM persona WHERE CODIGO_REFERIDO = p_codigo_referido_usuario) THEN
                -- El código de referido no existe, lo ignoramos pero continuamos
                SET p_codigo_referido_usuario = NULL;
            END IF;

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

            -- Obtener el ID de persona recién insertado (CORRECTO: usar LAST_INSERT_ID)
            SET v_idpersona = LAST_INSERT_ID();

            -- Insertar usuario
            INSERT INTO usuario (
                FK_ID_PERSONA,
                FK_ID_ROL,
                NOMBRE_USUARIO,
                CONTRASENIA,
                INTENTOS_FALLIDOS,
                TIPO_AUTENTICACION,
                ESTADO
            ) VALUES (
                v_idpersona,
                3, -- Rol por defecto (usuario normal)
                LOWER(TRIM(p_correo)),
                p_contrasenia,
                0,
                p_fk_id_metodo_autenticacion,
                1
            );

            SET v_idusuario = LAST_INSERT_ID();

            -- Registrar referencia si se usó código válido
            IF p_codigo_referido_usuario IS NOT NULL THEN
                INSERT INTO referencias (FK_ID_DUENO_CODIGO, FK_ID_CLIENTE_REFERIDO, MEMBRESIA_COMPRADA, FECHA_REFERENCIA)
                SELECT
                    u.PK_ID_USUARIO,
                    v_idusuario,
                    0,
                    NOW()
                FROM persona p
                INNER JOIN usuario u ON u.FK_ID_PERSONA = p.PK_ID_PERSONA
                WHERE p.CODIGO_REFERIDO = p_codigo_referido_usuario
                LIMIT 1;
            END IF;

            COMMIT;

            SET v_resultado = 1;
            SET v_mensaje = 'Usuario creado exitosamente.';
        END IF;
    END IF;

    -- Si hubo error, hacer rollback
    IF v_resultado < 0 THEN
        ROLLBACK;
    END IF;

    -- Retornar resultado
    SELECT v_resultado AS resultado, v_mensaje AS mensaje, v_idusuario AS id_usuario;
END//

DELIMITER ;
