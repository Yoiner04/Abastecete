-- =============================================
-- Migración 030: Corregir sistema de referidos en registro de usuarios
-- Fecha: 2025-12-30
-- Descripción:
--   1. Actualiza SP crear_usuario para recibir y guardar el código de referido usado
--   2. Actualiza SP registrar_referencia para buscar en tabla usuario (no persona)
--   3. Agrega columnas faltantes a tabla usuario si no existen
-- =============================================

-- Asegurar que la tabla usuario tenga las columnas necesarias para referidos
ALTER TABLE usuario
    ADD COLUMN IF NOT EXISTS `CREDITO_REFERIDOS` DECIMAL(10,2) DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS `YA_USO_DESCUENTO_REFERIDO` TINYINT DEFAULT 0;

-- =============================================
-- ACTUALIZAR SP crear_usuario
-- =============================================
DROP PROCEDURE IF EXISTS `crear_usuario`;

DELIMITER //
CREATE PROCEDURE `crear_usuario`(
    IN p_nombres VARCHAR(40),
    IN p_apellidos VARCHAR(40),
    IN p_telefono VARCHAR(40),
    IN p_correo VARCHAR(100),
    IN p_contrasenia TEXT,
    IN p_documento BIGINT,
    IN p_fk_tipo_documento INT,
    IN p_fk_rol INT,
    IN p_codigo_referido_usado VARCHAR(20),
    OUT p_mensaje VARCHAR(255),
    OUT p_id_usuario INT
)
BEGIN
    DECLARE v_codigo_referido VARCHAR(20);
    DECLARE v_codigo_existe INT DEFAULT 1;
    DECLARE v_id_referidor INT DEFAULT NULL;
    DECLARE v_codigo_valido BOOLEAN DEFAULT FALSE;

    SET p_mensaje = '';
    SET p_id_usuario = 0;

    -- Validaciones
    IF EXISTS (SELECT 1 FROM usuario WHERE NOMBRE_USUARIO = LOWER(TRIM(p_correo))) THEN
        SET p_mensaje = 'El correo electrónico ya está registrado.';
    ELSEIF p_documento IS NOT NULL AND p_documento > 0 AND EXISTS (SELECT 1 FROM usuario WHERE DOCUMENTO_IDENTIDAD = p_documento AND FK_ID_TIPO_DOCUMENTO = p_fk_tipo_documento) THEN
        SET p_mensaje = 'El documento de identidad ya está registrado.';
    ELSE
        -- Validar código de referido si fue proporcionado
        IF p_codigo_referido_usado IS NOT NULL AND TRIM(p_codigo_referido_usado) != '' THEN
            SELECT PK_ID_USUARIO INTO v_id_referidor
            FROM usuario
            WHERE CODIGO_REFERIDO = UPPER(TRIM(p_codigo_referido_usado))
            AND ESTADO = 1;

            IF v_id_referidor IS NOT NULL THEN
                SET v_codigo_valido = TRUE;
            END IF;
        END IF;

        -- Generar código de referido único para el nuevo usuario
        WHILE v_codigo_existe > 0 DO
            SET v_codigo_referido = CONCAT('COD', LPAD(FLOOR(RAND() * 1000000), 6, '0'));
            SELECT COUNT(*) INTO v_codigo_existe FROM usuario WHERE CODIGO_REFERIDO = v_codigo_referido;
        END WHILE;

        -- Insertar usuario con código de referido usado
        INSERT INTO usuario (
            NOMBRES, APELLIDOS, TELEFONO, DOCUMENTO_IDENTIDAD, FK_ID_TIPO_DOCUMENTO,
            CODIGO_REFERIDO, CODIGO_REFERIDO_USADO, NOMBRE_USUARIO, CONTRASENIA, FK_ID_ROL, ESTADO,
            CLIENTES_REFERIDOS_TOTAL, CREDITO_REFERIDOS, YA_USO_DESCUENTO_REFERIDO
        ) VALUES (
            p_nombres, p_apellidos, p_telefono,
            CASE WHEN p_documento > 0 THEN p_documento ELSE NULL END,
            COALESCE(p_fk_tipo_documento, 1),
            v_codigo_referido,
            CASE WHEN v_codigo_valido THEN UPPER(TRIM(p_codigo_referido_usado)) ELSE NULL END,
            LOWER(TRIM(p_correo)), p_contrasenia, p_fk_rol, 1,
            0, 0.00, 0
        );

        SET p_id_usuario = LAST_INSERT_ID();

        -- Si el código de referido es válido, registrar la referencia
        IF v_codigo_valido AND v_id_referidor IS NOT NULL THEN
            -- Insertar en tabla de referencias
            INSERT INTO referencias (FK_ID_DUENO_CODIGO, FK_ID_CLIENTE_REFERIDO, MEMBRESIA_COMPRADA, FECHA_REGISTRO)
            VALUES (v_id_referidor, p_id_usuario, FALSE, NOW())
            ON DUPLICATE KEY UPDATE FECHA_REGISTRO = NOW();

            -- Incrementar contador de referidos del dueño del código
            UPDATE usuario
            SET CLIENTES_REFERIDOS_TOTAL = CLIENTES_REFERIDOS_TOTAL + 1
            WHERE PK_ID_USUARIO = v_id_referidor;

            SET p_mensaje = 'Usuario creado exitosamente. Código de referido aplicado.';
        ELSE
            SET p_mensaje = 'Usuario creado exitosamente.';
        END IF;
    END IF;
END//
DELIMITER ;

-- =============================================
-- ACTUALIZAR SP registrar_referencia (corregir para usar tabla usuario)
-- =============================================
DROP PROCEDURE IF EXISTS `registrar_referencia`;

DELIMITER //
CREATE PROCEDURE `registrar_referencia`(
    IN p_cliente_id INT,                  -- ID del cliente que usa el código
    IN p_codigo_referido VARCHAR(20),     -- Código de recomendación ingresado
    IN p_membresia_comprada BOOLEAN,      -- Si el cliente compró una membresía
    OUT mensaje VARCHAR(500),             -- Mensaje de resultado
    OUT resultado INT                     -- Resultado (0 = fallo, 1 = éxito)
)
BEGIN
    DECLARE v_dueno_codigo_id INT;
    DECLARE v_clientes_total INT;
    DECLARE v_ya_referido INT DEFAULT 0;

    -- Inicializar el resultado
    SET resultado = 0;
    SET mensaje = '';

    -- Obtener el dueño del código de recomendación (buscar en tabla usuario)
    SELECT PK_ID_USUARIO INTO v_dueno_codigo_id
    FROM usuario
    WHERE CODIGO_REFERIDO = UPPER(TRIM(p_codigo_referido))
    AND ESTADO = 1;

    -- Validar si el código existe
    IF v_dueno_codigo_id IS NULL THEN
        SET mensaje = 'El código de recomendación no es válido.';
    -- Validar que no se auto-refiera
    ELSEIF v_dueno_codigo_id = p_cliente_id THEN
        SET mensaje = 'No puedes usar tu propio código de referido.';
    ELSE
        -- Verificar si ya existe esta referencia
        SELECT COUNT(*) INTO v_ya_referido
        FROM referencias
        WHERE FK_ID_DUENO_CODIGO = v_dueno_codigo_id
        AND FK_ID_CLIENTE_REFERIDO = p_cliente_id;

        IF v_ya_referido > 0 THEN
            -- Actualizar referencia existente si compró membresía
            IF p_membresia_comprada THEN
                UPDATE referencias
                SET MEMBRESIA_COMPRADA = TRUE
                WHERE FK_ID_DUENO_CODIGO = v_dueno_codigo_id
                AND FK_ID_CLIENTE_REFERIDO = p_cliente_id;

                SET mensaje = 'Referencia actualizada. Membresía registrada.';
            ELSE
                SET mensaje = 'La referencia ya estaba registrada.';
            END IF;
            SET resultado = 1;
        ELSE
            -- Insertar nueva referencia
            INSERT INTO referencias (FK_ID_DUENO_CODIGO, FK_ID_CLIENTE_REFERIDO, MEMBRESIA_COMPRADA, FECHA_REGISTRO)
            VALUES (v_dueno_codigo_id, p_cliente_id, p_membresia_comprada, NOW());

            -- Actualizar el código usado en el usuario referido
            UPDATE usuario
            SET CODIGO_REFERIDO_USADO = UPPER(TRIM(p_codigo_referido))
            WHERE PK_ID_USUARIO = p_cliente_id
            AND (CODIGO_REFERIDO_USADO IS NULL OR CODIGO_REFERIDO_USADO = '');

            -- Incrementar contador de clientes referidos
            UPDATE usuario
            SET CLIENTES_REFERIDOS_TOTAL = CLIENTES_REFERIDOS_TOTAL + 1
            WHERE PK_ID_USUARIO = v_dueno_codigo_id;

            -- Obtener total actual para mensaje
            SELECT CLIENTES_REFERIDOS_TOTAL INTO v_clientes_total
            FROM usuario
            WHERE PK_ID_USUARIO = v_dueno_codigo_id;

            SET resultado = 1;

            IF p_membresia_comprada THEN
                SET mensaje = 'Referencia registrada con membresía comprada.';
            ELSE
                SET mensaje = CONCAT('Referencia registrada. Total referidos: ', v_clientes_total);
            END IF;
        END IF;
    END IF;
END//
DELIMITER ;

-- =============================================
-- ACTUALIZAR SP validar_codigo_referido (asegurar que busque en usuario)
-- =============================================
DROP PROCEDURE IF EXISTS `validar_codigo_referido`;

DELIMITER //
CREATE PROCEDURE `validar_codigo_referido`(
    IN p_codigo VARCHAR(20),
    IN p_id_usuario_actual INT
)
BEGIN
    DECLARE v_id_dueno INT DEFAULT NULL;
    DECLARE v_nombre_dueno VARCHAR(100) DEFAULT '';
    DECLARE v_valido INT DEFAULT 0;
    DECLARE v_mensaje VARCHAR(255) DEFAULT '';

    -- Buscar el dueño del código en la tabla usuario
    SELECT
        PK_ID_USUARIO,
        CONCAT(NOMBRES, ' ', APELLIDOS)
    INTO v_id_dueno, v_nombre_dueno
    FROM usuario
    WHERE CODIGO_REFERIDO = UPPER(TRIM(p_codigo))
    AND ESTADO = 1;

    IF v_id_dueno IS NULL THEN
        SET v_valido = 0;
        SET v_mensaje = 'El código de referido no existe o no es válido.';
    ELSEIF p_id_usuario_actual IS NOT NULL AND v_id_dueno = p_id_usuario_actual THEN
        SET v_valido = 0;
        SET v_mensaje = 'No puedes usar tu propio código de referido.';
    ELSE
        SET v_valido = 1;
        SET v_mensaje = 'Código válido.';
    END IF;

    SELECT
        v_valido AS valido,
        v_mensaje AS mensaje,
        COALESCE(v_id_dueno, 0) AS id_dueno,
        COALESCE(v_nombre_dueno, '') AS nombre_dueno;
END//
DELIMITER ;

-- Verificar/crear tabla referencias si no existe
CREATE TABLE IF NOT EXISTS `referencias` (
    `PK_ID_REFERENCIA` INT NOT NULL AUTO_INCREMENT,
    `FK_ID_DUENO_CODIGO` INT NOT NULL,
    `FK_ID_CLIENTE_REFERIDO` INT NOT NULL,
    `MEMBRESIA_COMPRADA` TINYINT DEFAULT 0,
    `FECHA_REGISTRO` DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`PK_ID_REFERENCIA`),
    UNIQUE KEY `UK_referencia` (`FK_ID_DUENO_CODIGO`, `FK_ID_CLIENTE_REFERIDO`),
    KEY `idx_dueno_codigo` (`FK_ID_DUENO_CODIGO`),
    KEY `idx_cliente_referido` (`FK_ID_CLIENTE_REFERIDO`),
    CONSTRAINT `FK_ref_dueno` FOREIGN KEY (`FK_ID_DUENO_CODIGO`) REFERENCES `usuario` (`PK_ID_USUARIO`) ON DELETE CASCADE,
    CONSTRAINT `FK_ref_cliente` FOREIGN KEY (`FK_ID_CLIENTE_REFERIDO`) REFERENCES `usuario` (`PK_ID_USUARIO`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Mensaje de confirmación
SELECT 'Migración 030 completada: Sistema de referidos corregido' AS resultado;
