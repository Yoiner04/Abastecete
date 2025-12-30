-- =============================================
-- Migración 033: Código de referido solo al comprar membresía de pago
-- Fecha: 2025-12-30
-- Descripción:
--   El código de referido NO se genera al registrarse.
--   Solo se genera cuando el usuario compra una membresía de pago.
-- =============================================

-- =============================================
-- ACTUALIZAR SP crear_usuario - SIN generar código de referido
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

        -- Insertar usuario SIN código de referido (se genera al comprar membresía)
        INSERT INTO usuario (
            NOMBRES, APELLIDOS, TELEFONO, DOCUMENTO_IDENTIDAD, FK_ID_TIPO_DOCUMENTO,
            CODIGO_REFERIDO, CODIGO_REFERIDO_USADO, NOMBRE_USUARIO, CONTRASENIA, FK_ID_ROL, ESTADO,
            CLIENTES_REFERIDOS_TOTAL, CREDITO_REFERIDOS, YA_USO_DESCUENTO_REFERIDO
        ) VALUES (
            p_nombres, p_apellidos, p_telefono,
            CASE WHEN p_documento > 0 THEN p_documento ELSE NULL END,
            COALESCE(p_fk_tipo_documento, 1),
            NULL,  -- NO se genera código al registrarse
            CASE WHEN v_codigo_valido THEN UPPER(TRIM(p_codigo_referido_usado)) ELSE NULL END,
            LOWER(TRIM(p_correo)), p_contrasenia, p_fk_rol, 1,
            0, 0.00, 0
        );

        SET p_id_usuario = LAST_INSERT_ID();

        -- Si el código de referido es válido, registrar la referencia
        IF v_codigo_valido AND v_id_referidor IS NOT NULL THEN
            INSERT INTO referencias (FK_ID_DUENO_CODIGO, FK_ID_CLIENTE_REFERIDO, MEMBRESIA_COMPRADA, FECHA_REGISTRO)
            VALUES (v_id_referidor, p_id_usuario, FALSE, NOW())
            ON DUPLICATE KEY UPDATE FECHA_REGISTRO = NOW();

            SET p_mensaje = 'Usuario creado exitosamente. Código de referido guardado.';
        ELSE
            SET p_mensaje = 'Usuario creado exitosamente.';
        END IF;
    END IF;
END//
DELIMITER ;

-- =============================================
-- SP: generar_codigo_referido
-- Se llama cuando el usuario compra una membresía de pago
-- =============================================
DROP PROCEDURE IF EXISTS `generar_codigo_referido`;

DELIMITER //
CREATE PROCEDURE `generar_codigo_referido`(
    IN p_id_usuario INT,
    OUT p_codigo VARCHAR(20),
    OUT p_mensaje VARCHAR(255)
)
BEGIN
    DECLARE v_codigo_existe INT DEFAULT 1;
    DECLARE v_codigo_actual VARCHAR(20);
    DECLARE v_intentos INT DEFAULT 0;

    SET p_codigo = NULL;
    SET p_mensaje = '';

    -- Verificar si ya tiene código
    SELECT CODIGO_REFERIDO INTO v_codigo_actual
    FROM usuario
    WHERE PK_ID_USUARIO = p_id_usuario;

    IF v_codigo_actual IS NOT NULL AND v_codigo_actual != '' THEN
        SET p_codigo = v_codigo_actual;
        SET p_mensaje = 'El usuario ya tiene un código de referido.';
    ELSE
        -- Generar código único
        WHILE v_codigo_existe > 0 AND v_intentos < 10 DO
            SET p_codigo = CONCAT('REF', LPAD(FLOOR(RAND() * 1000000), 6, '0'));
            SELECT COUNT(*) INTO v_codigo_existe FROM usuario WHERE CODIGO_REFERIDO = p_codigo;
            SET v_intentos = v_intentos + 1;
        END WHILE;

        IF v_codigo_existe = 0 THEN
            -- Asignar código al usuario
            UPDATE usuario
            SET CODIGO_REFERIDO = p_codigo
            WHERE PK_ID_USUARIO = p_id_usuario;

            SET p_mensaje = 'Código de referido generado exitosamente.';
        ELSE
            SET p_codigo = NULL;
            SET p_mensaje = 'Error al generar código único.';
        END IF;
    END IF;

    SELECT p_codigo AS codigo, p_mensaje AS mensaje;
END//
DELIMITER ;

-- =============================================
-- ACTUALIZAR SP aplicar_descuento_referido
-- Ahora también genera el código del comprador si no lo tiene
-- =============================================
DROP PROCEDURE IF EXISTS `aplicar_descuento_referido`;

DELIMITER //
CREATE PROCEDURE `aplicar_descuento_referido`(
    IN p_id_usuario_referido INT,
    IN p_id_tipo_membresia INT,
    IN p_monto_compra DECIMAL(10,2),
    IN p_descuento_aplicado DECIMAL(10,2),
    IN p_usar_credito DECIMAL(10,2)
)
BEGIN
    DECLARE v_codigo_usado VARCHAR(20) DEFAULT NULL;
    DECLARE v_id_dueno INT DEFAULT NULL;
    DECLARE v_tipo_credito VARCHAR(20) DEFAULT 'PORCENTAJE';
    DECLARE v_valor_credito DECIMAL(10,2) DEFAULT 0;
    DECLARE v_credito_a_dar DECIMAL(10,2) DEFAULT 0;
    DECLARE v_descuento_activo INT DEFAULT 0;
    DECLARE v_codigo_nuevo VARCHAR(20);
    DECLARE v_codigo_existe INT DEFAULT 1;
    DECLARE v_intentos INT DEFAULT 0;
    DECLARE v_codigo_actual VARCHAR(20);

    -- Obtener código usado por el referido
    SELECT CODIGO_REFERIDO_USADO, CODIGO_REFERIDO INTO v_codigo_usado, v_codigo_actual
    FROM usuario
    WHERE PK_ID_USUARIO = p_id_usuario_referido;

    -- Si usó un código, obtener el dueño
    IF v_codigo_usado IS NOT NULL AND v_codigo_usado != '' THEN
        SELECT PK_ID_USUARIO INTO v_id_dueno
        FROM usuario
        WHERE CODIGO_REFERIDO = v_codigo_usado;
    END IF;

    -- Obtener configuración
    SELECT
        TIPO_DESCUENTO_DUENO,
        VALOR_DESCUENTO_DUENO,
        DESCUENTO_ACTIVO
    INTO v_tipo_credito, v_valor_credito, v_descuento_activo
    FROM configuracion_referidos
    WHERE PK_ID = 1;

    -- Marcar que el referido ya usó su descuento (si aplicó alguno)
    IF p_descuento_aplicado > 0 THEN
        UPDATE usuario
        SET YA_USO_DESCUENTO_REFERIDO = 1
        WHERE PK_ID_USUARIO = p_id_usuario_referido;
    END IF;

    -- Descontar crédito usado (si lo usó)
    IF p_usar_credito > 0 THEN
        UPDATE usuario
        SET CREDITO_REFERIDOS = GREATEST(CREDITO_REFERIDOS - p_usar_credito, 0)
        WHERE PK_ID_USUARIO = p_id_usuario_referido;
    END IF;

    -- Dar crédito al dueño del código (si el sistema está activo)
    IF v_descuento_activo = 1 AND v_id_dueno IS NOT NULL THEN
        -- Calcular crédito a dar
        IF v_tipo_credito = 'PORCENTAJE' THEN
            SET v_credito_a_dar = ROUND(p_monto_compra * (v_valor_credito / 100), 2);
        ELSE
            SET v_credito_a_dar = v_valor_credito;
        END IF;

        -- Actualizar crédito del dueño
        UPDATE usuario
        SET CREDITO_REFERIDOS = CREDITO_REFERIDOS + v_credito_a_dar,
            CLIENTES_REFERIDOS_TOTAL = CLIENTES_REFERIDOS_TOTAL + 1
        WHERE PK_ID_USUARIO = v_id_dueno;

        -- Actualizar la referencia como "compró membresía"
        UPDATE referencias
        SET MEMBRESIA_COMPRADA = 1
        WHERE FK_ID_DUENO_CODIGO = v_id_dueno
        AND FK_ID_CLIENTE_REFERIDO = p_id_usuario_referido;
    END IF;

    -- GENERAR CÓDIGO DE REFERIDO PARA EL COMPRADOR (si no tiene)
    IF v_codigo_actual IS NULL OR v_codigo_actual = '' THEN
        WHILE v_codigo_existe > 0 AND v_intentos < 10 DO
            SET v_codigo_nuevo = CONCAT('REF', LPAD(FLOOR(RAND() * 1000000), 6, '0'));
            SELECT COUNT(*) INTO v_codigo_existe FROM usuario WHERE CODIGO_REFERIDO = v_codigo_nuevo;
            SET v_intentos = v_intentos + 1;
        END WHILE;

        IF v_codigo_existe = 0 THEN
            UPDATE usuario
            SET CODIGO_REFERIDO = v_codigo_nuevo
            WHERE PK_ID_USUARIO = p_id_usuario_referido;
        END IF;
    END IF;

    SELECT 'OK' AS resultado, v_credito_a_dar AS credito_dado_a_dueno;
END//
DELIMITER ;

-- =============================================
-- ACTUALIZAR SP validar_codigo_referido
-- Validar que el dueño del código tenga membresía activa
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
    DECLARE v_tiene_membresia INT DEFAULT 0;

    -- Buscar el dueño del código en la tabla usuario
    -- Solo usuarios que TIENEN código (es decir, compraron membresía)
    SELECT
        PK_ID_USUARIO,
        CONCAT(NOMBRES, ' ', APELLIDOS)
    INTO v_id_dueno, v_nombre_dueno
    FROM usuario
    WHERE CODIGO_REFERIDO = UPPER(TRIM(p_codigo))
    AND CODIGO_REFERIDO IS NOT NULL
    AND CODIGO_REFERIDO != ''
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

-- Mensaje de confirmación
SELECT 'Migracion 033 completada: Código referido solo se genera al comprar membresía' AS resultado;
