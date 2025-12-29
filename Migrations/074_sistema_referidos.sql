-- Migración 074: Sistema de Referidos Completo
-- ============================================================
-- Implementa sistema de códigos de referido con descuentos
-- configurables para referido y dueño del código
-- ============================================================
-- NOTA: Usa los nombres de columnas existentes en tabla referencias:
--   FK_ID_DUENO_CODIGO = dueño del código
--   FK_ID_CLIENTE_REFERIDO = usuario que usó el código
-- ============================================================

-- =====================================================
-- TABLA: configuracion_referidos
-- Almacena la configuración global de descuentos
-- =====================================================
CREATE TABLE IF NOT EXISTS configuracion_referidos (
    PK_ID INT AUTO_INCREMENT PRIMARY KEY,
    TIPO_DESCUENTO_REFERIDO ENUM('PORCENTAJE', 'MONTO_FIJO') NOT NULL DEFAULT 'PORCENTAJE',
    VALOR_DESCUENTO_REFERIDO DECIMAL(10,2) NOT NULL DEFAULT 10.00,
    TIPO_DESCUENTO_DUENO ENUM('PORCENTAJE', 'MONTO_FIJO') NOT NULL DEFAULT 'PORCENTAJE',
    VALOR_DESCUENTO_DUENO DECIMAL(10,2) NOT NULL DEFAULT 10.00,
    DESCUENTO_ACTIVO TINYINT(1) NOT NULL DEFAULT 1,
    FECHA_CREACION DATETIME DEFAULT CURRENT_TIMESTAMP,
    FECHA_ACTUALIZACION DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    ACTUALIZADO_POR INT NULL
);

-- Insertar configuración por defecto si no existe
INSERT INTO configuracion_referidos (
    TIPO_DESCUENTO_REFERIDO, VALOR_DESCUENTO_REFERIDO,
    TIPO_DESCUENTO_DUENO, VALOR_DESCUENTO_DUENO,
    DESCUENTO_ACTIVO
) SELECT 'PORCENTAJE', 10.00, 'PORCENTAJE', 10.00, 1
WHERE NOT EXISTS (SELECT 1 FROM configuracion_referidos LIMIT 1);

-- =====================================================
-- MODIFICAR TABLA: usuario
-- Agregar campos para descuento de referido
-- =====================================================
-- Campo para crédito acumulado del dueño del código
SET @col_exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
                   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'usuario' AND COLUMN_NAME = 'CREDITO_REFERIDOS');
SET @sql = IF(@col_exists = 0, 'ALTER TABLE usuario ADD COLUMN CREDITO_REFERIDOS DECIMAL(10,2) DEFAULT 0', 'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Campo para saber si ya usó su descuento como referido
SET @col_exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
                   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'usuario' AND COLUMN_NAME = 'YA_USO_DESCUENTO_REFERIDO');
SET @sql = IF(@col_exists = 0, 'ALTER TABLE usuario ADD COLUMN YA_USO_DESCUENTO_REFERIDO TINYINT(1) DEFAULT 0', 'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- =====================================================
-- MODIFICAR TABLA: referencias
-- Agregar campos adicionales para tracking de descuentos
-- La tabla ya existe con FK_ID_DUENO_CODIGO y FK_ID_CLIENTE_REFERIDO
-- =====================================================
SET @col_exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
                   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'referencias' AND COLUMN_NAME = 'DESCUENTO_APLICADO_REFERIDO');
SET @sql = IF(@col_exists = 0, 'ALTER TABLE referencias ADD COLUMN DESCUENTO_APLICADO_REFERIDO DECIMAL(10,2) DEFAULT NULL', 'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @col_exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
                   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'referencias' AND COLUMN_NAME = 'DESCUENTO_APLICADO_DUENO');
SET @sql = IF(@col_exists = 0, 'ALTER TABLE referencias ADD COLUMN DESCUENTO_APLICADO_DUENO DECIMAL(10,2) DEFAULT NULL', 'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @col_exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
                   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'referencias' AND COLUMN_NAME = 'FK_ID_TIPO_MEMBRESIA_COMPRADA');
SET @sql = IF(@col_exists = 0, 'ALTER TABLE referencias ADD COLUMN FK_ID_TIPO_MEMBRESIA_COMPRADA INT DEFAULT NULL', 'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @col_exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
                   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'referencias' AND COLUMN_NAME = 'MONTO_COMPRA');
SET @sql = IF(@col_exists = 0, 'ALTER TABLE referencias ADD COLUMN MONTO_COMPRA DECIMAL(10,2) DEFAULT NULL', 'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @col_exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
                   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'referencias' AND COLUMN_NAME = 'FECHA_COMPRA');
SET @sql = IF(@col_exists = 0, 'ALTER TABLE referencias ADD COLUMN FECHA_COMPRA DATETIME DEFAULT NULL', 'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- =====================================================
-- SP: obtener_configuracion_referidos
-- =====================================================
DROP PROCEDURE IF EXISTS obtener_configuracion_referidos;
DELIMITER //
CREATE PROCEDURE obtener_configuracion_referidos()
BEGIN
    SELECT
        PK_ID,
        TIPO_DESCUENTO_REFERIDO,
        VALOR_DESCUENTO_REFERIDO,
        TIPO_DESCUENTO_DUENO,
        VALOR_DESCUENTO_DUENO,
        DESCUENTO_ACTIVO,
        FECHA_ACTUALIZACION,
        ACTUALIZADO_POR
    FROM configuracion_referidos
    LIMIT 1;
END//
DELIMITER ;

-- =====================================================
-- SP: actualizar_configuracion_referidos
-- =====================================================
DROP PROCEDURE IF EXISTS actualizar_configuracion_referidos;
DELIMITER //
CREATE PROCEDURE actualizar_configuracion_referidos(
    IN p_tipo_descuento_referido VARCHAR(20),
    IN p_valor_descuento_referido DECIMAL(10,2),
    IN p_tipo_descuento_dueno VARCHAR(20),
    IN p_valor_descuento_dueno DECIMAL(10,2),
    IN p_descuento_activo TINYINT,
    IN p_usuario_id INT
)
BEGIN
    UPDATE configuracion_referidos
    SET
        TIPO_DESCUENTO_REFERIDO = p_tipo_descuento_referido,
        VALOR_DESCUENTO_REFERIDO = p_valor_descuento_referido,
        TIPO_DESCUENTO_DUENO = p_tipo_descuento_dueno,
        VALOR_DESCUENTO_DUENO = p_valor_descuento_dueno,
        DESCUENTO_ACTIVO = p_descuento_activo,
        ACTUALIZADO_POR = p_usuario_id
    WHERE PK_ID = 1;

    SELECT ROW_COUNT() as filas_afectadas;
END//
DELIMITER ;

-- =====================================================
-- SP: validar_codigo_referido
-- Valida si un código es válido para ser usado
-- =====================================================
DROP PROCEDURE IF EXISTS validar_codigo_referido;
DELIMITER //
CREATE PROCEDURE validar_codigo_referido(
    IN p_codigo VARCHAR(50),
    IN p_id_usuario_actual INT
)
BEGIN
    DECLARE v_id_dueno INT DEFAULT 0;
    DECLARE v_nombre_dueno VARCHAR(200);
    DECLARE v_codigo_valido TINYINT DEFAULT 0;
    DECLARE v_mensaje VARCHAR(200);
    DECLARE v_descuento_activo TINYINT DEFAULT 0;

    -- Verificar si el sistema de descuentos está activo
    SELECT DESCUENTO_ACTIVO INTO v_descuento_activo
    FROM configuracion_referidos LIMIT 1;

    IF v_descuento_activo = 0 THEN
        SELECT 0 AS valido, 'El sistema de referidos no está activo' AS mensaje,
               0 AS id_dueno, NULL AS nombre_dueno;
    ELSE
        -- Buscar el dueño del código
        SELECT PK_ID_USUARIO, CONCAT(NOMBRES, ' ', APELLIDOS)
        INTO v_id_dueno, v_nombre_dueno
        FROM usuario
        WHERE CODIGO_REFERIDO = p_codigo AND ESTADO = 1
        LIMIT 1;

        IF v_id_dueno = 0 OR v_id_dueno IS NULL THEN
            SELECT 0 AS valido, 'Código de referido no válido' AS mensaje,
                   0 AS id_dueno, NULL AS nombre_dueno;
        ELSEIF v_id_dueno = p_id_usuario_actual THEN
            SELECT 0 AS valido, 'No puedes usar tu propio código' AS mensaje,
                   0 AS id_dueno, NULL AS nombre_dueno;
        ELSE
            SELECT 1 AS valido, 'Código válido' AS mensaje,
                   v_id_dueno AS id_dueno, v_nombre_dueno AS nombre_dueno;
        END IF;
    END IF;
END//
DELIMITER ;

-- =====================================================
-- SP: calcular_descuento_referido
-- Calcula el descuento que aplicaría a un usuario
-- =====================================================
DROP PROCEDURE IF EXISTS calcular_descuento_referido;
DELIMITER //
CREATE PROCEDURE calcular_descuento_referido(
    IN p_id_usuario INT,
    IN p_monto_base DECIMAL(10,2)
)
BEGIN
    DECLARE v_ya_uso_descuento TINYINT DEFAULT 0;
    DECLARE v_tiene_codigo_usado VARCHAR(50);
    DECLARE v_tipo_descuento VARCHAR(20);
    DECLARE v_valor_descuento DECIMAL(10,2);
    DECLARE v_descuento_activo TINYINT DEFAULT 0;
    DECLARE v_descuento_calculado DECIMAL(10,2) DEFAULT 0;
    DECLARE v_credito_disponible DECIMAL(10,2) DEFAULT 0;

    -- Obtener configuración
    SELECT TIPO_DESCUENTO_REFERIDO, VALOR_DESCUENTO_REFERIDO, DESCUENTO_ACTIVO
    INTO v_tipo_descuento, v_valor_descuento, v_descuento_activo
    FROM configuracion_referidos LIMIT 1;

    -- Obtener datos del usuario
    SELECT YA_USO_DESCUENTO_REFERIDO, CODIGO_REFERIDO_USADO, COALESCE(CREDITO_REFERIDOS, 0)
    INTO v_ya_uso_descuento, v_tiene_codigo_usado, v_credito_disponible
    FROM usuario WHERE PK_ID_USUARIO = p_id_usuario;

    -- Si el sistema está activo, no ha usado descuento y tiene código usado
    IF v_descuento_activo = 1 AND v_ya_uso_descuento = 0 AND v_tiene_codigo_usado IS NOT NULL AND v_tiene_codigo_usado != '' THEN
        IF v_tipo_descuento = 'PORCENTAJE' THEN
            SET v_descuento_calculado = p_monto_base * (v_valor_descuento / 100);
        ELSE
            SET v_descuento_calculado = v_valor_descuento;
        END IF;

        -- No puede ser mayor al monto base
        IF v_descuento_calculado > p_monto_base THEN
            SET v_descuento_calculado = p_monto_base;
        END IF;
    END IF;

    SELECT
        v_descuento_calculado AS descuento_referido,
        v_credito_disponible AS credito_disponible,
        v_ya_uso_descuento AS ya_uso_descuento,
        v_tiene_codigo_usado AS codigo_usado,
        v_tipo_descuento AS tipo_descuento,
        v_valor_descuento AS valor_configurado,
        p_monto_base - v_descuento_calculado AS monto_final;
END//
DELIMITER ;

-- =====================================================
-- SP: aplicar_descuento_referido
-- Se llama después de confirmar el pago
-- Usa FK_ID_DUENO_CODIGO y FK_ID_CLIENTE_REFERIDO (nombres existentes)
-- =====================================================
DROP PROCEDURE IF EXISTS aplicar_descuento_referido;
DELIMITER //
CREATE PROCEDURE aplicar_descuento_referido(
    IN p_id_usuario_referido INT,
    IN p_id_tipo_membresia INT,
    IN p_monto_compra DECIMAL(10,2),
    IN p_descuento_aplicado DECIMAL(10,2),
    IN p_usar_credito DECIMAL(10,2)
)
BEGIN
    DECLARE v_codigo_usado VARCHAR(50);
    DECLARE v_id_dueno INT DEFAULT 0;
    DECLARE v_tipo_descuento_dueno VARCHAR(20);
    DECLARE v_valor_descuento_dueno DECIMAL(10,2);
    DECLARE v_credito_para_dueno DECIMAL(10,2) DEFAULT 0;
    DECLARE v_credito_actual DECIMAL(10,2) DEFAULT 0;

    -- Obtener código usado por el referido
    SELECT CODIGO_REFERIDO_USADO, COALESCE(CREDITO_REFERIDOS, 0)
    INTO v_codigo_usado, v_credito_actual
    FROM usuario WHERE PK_ID_USUARIO = p_id_usuario_referido;

    -- Si usó crédito, descontarlo
    IF p_usar_credito > 0 THEN
        UPDATE usuario
        SET CREDITO_REFERIDOS = GREATEST(0, COALESCE(CREDITO_REFERIDOS, 0) - p_usar_credito)
        WHERE PK_ID_USUARIO = p_id_usuario_referido;
    END IF;

    -- Si tiene código usado y aplicó descuento de referido
    IF v_codigo_usado IS NOT NULL AND v_codigo_usado != '' AND p_descuento_aplicado > 0 THEN
        -- Marcar que ya usó su descuento
        UPDATE usuario SET YA_USO_DESCUENTO_REFERIDO = 1
        WHERE PK_ID_USUARIO = p_id_usuario_referido;

        -- Buscar al dueño del código
        SELECT PK_ID_USUARIO INTO v_id_dueno
        FROM usuario WHERE CODIGO_REFERIDO = v_codigo_usado LIMIT 1;

        IF v_id_dueno > 0 THEN
            -- Calcular crédito para el dueño
            SELECT TIPO_DESCUENTO_DUENO, VALOR_DESCUENTO_DUENO
            INTO v_tipo_descuento_dueno, v_valor_descuento_dueno
            FROM configuracion_referidos LIMIT 1;

            IF v_tipo_descuento_dueno = 'PORCENTAJE' THEN
                SET v_credito_para_dueno = p_monto_compra * (v_valor_descuento_dueno / 100);
            ELSE
                SET v_credito_para_dueno = v_valor_descuento_dueno;
            END IF;

            -- Acreditar al dueño
            UPDATE usuario
            SET CREDITO_REFERIDOS = COALESCE(CREDITO_REFERIDOS, 0) + v_credito_para_dueno
            WHERE PK_ID_USUARIO = v_id_dueno;

            -- Actualizar registro de referencia existente
            UPDATE referencias
            SET DESCUENTO_APLICADO_REFERIDO = p_descuento_aplicado,
                DESCUENTO_APLICADO_DUENO = v_credito_para_dueno,
                FK_ID_TIPO_MEMBRESIA_COMPRADA = p_id_tipo_membresia,
                MONTO_COMPRA = p_monto_compra,
                FECHA_COMPRA = NOW(),
                MEMBRESIA_COMPRADA = 1
            WHERE FK_ID_CLIENTE_REFERIDO = p_id_usuario_referido
              AND FK_ID_DUENO_CODIGO = v_id_dueno;

            -- Si no existía el registro, insertarlo
            IF ROW_COUNT() = 0 THEN
                INSERT INTO referencias (
                    FK_ID_DUENO_CODIGO, FK_ID_CLIENTE_REFERIDO,
                    DESCUENTO_APLICADO_REFERIDO, DESCUENTO_APLICADO_DUENO,
                    FK_ID_TIPO_MEMBRESIA_COMPRADA, MONTO_COMPRA, FECHA_COMPRA,
                    MEMBRESIA_COMPRADA
                ) VALUES (
                    v_id_dueno, p_id_usuario_referido,
                    p_descuento_aplicado, v_credito_para_dueno,
                    p_id_tipo_membresia, p_monto_compra, NOW(), 1
                );
            END IF;
        END IF;
    END IF;

    SELECT 'OK' as resultado, v_credito_para_dueno as credito_otorgado_dueno;
END//
DELIMITER ;

-- =====================================================
-- SP: registrar_referencia
-- Se llama cuando un usuario se registra con código
-- =====================================================
DROP PROCEDURE IF EXISTS registrar_referencia;
DELIMITER //
CREATE PROCEDURE registrar_referencia(
    IN p_id_usuario_referido INT,
    IN p_codigo_referido VARCHAR(50)
)
BEGIN
    DECLARE v_id_dueno INT DEFAULT 0;

    -- Buscar dueño del código
    SELECT PK_ID_USUARIO INTO v_id_dueno
    FROM usuario WHERE CODIGO_REFERIDO = p_codigo_referido AND ESTADO = 1
    LIMIT 1;

    IF v_id_dueno > 0 AND v_id_dueno != p_id_usuario_referido THEN
        -- Verificar que no exista ya
        IF NOT EXISTS (
            SELECT 1 FROM referencias
            WHERE FK_ID_CLIENTE_REFERIDO = p_id_usuario_referido
        ) THEN
            INSERT INTO referencias (FK_ID_DUENO_CODIGO, FK_ID_CLIENTE_REFERIDO, MEMBRESIA_COMPRADA)
            VALUES (v_id_dueno, p_id_usuario_referido, 0);

            -- Incrementar contador de referidos del dueño
            UPDATE usuario
            SET CLIENTES_REFERIDOS_TOTAL = COALESCE(CLIENTES_REFERIDOS_TOTAL, 0) + 1
            WHERE PK_ID_USUARIO = v_id_dueno;
        END IF;
    END IF;

    SELECT v_id_dueno as id_dueno;
END//
DELIMITER ;

-- =====================================================
-- SP: consultar_mis_referidos
-- Lista los referidos de un usuario
-- Usa FK_ID_DUENO_CODIGO y FK_ID_CLIENTE_REFERIDO
-- =====================================================
DROP PROCEDURE IF EXISTS consultar_mis_referidos;
DELIMITER //
CREATE PROCEDURE consultar_mis_referidos(
    IN p_id_usuario INT
)
BEGIN
    SELECT
        r.PK_ID_REFERENCIA,
        r.FK_ID_CLIENTE_REFERIDO AS FK_ID_USUARIO_REFERIDO,
        u.NOMBRES,
        u.APELLIDOS,
        r.FECHA_REFERENCIA AS FECHA_REGISTRO,
        r.FECHA_COMPRA,
        r.MONTO_COMPRA,
        r.DESCUENTO_APLICADO_DUENO AS credito_recibido,
        tm.NOMBRE AS membresia_comprada,
        CASE WHEN r.MEMBRESIA_COMPRADA = 1 OR r.FECHA_COMPRA IS NOT NULL THEN 1 ELSE 0 END AS ha_comprado
    FROM referencias r
    INNER JOIN usuario u ON r.FK_ID_CLIENTE_REFERIDO = u.PK_ID_USUARIO
    LEFT JOIN tipo_membresia tm ON r.FK_ID_TIPO_MEMBRESIA_COMPRADA = tm.PK_ID_TIPO_MEMBRESIA
    WHERE r.FK_ID_DUENO_CODIGO = p_id_usuario
    ORDER BY r.FECHA_REFERENCIA DESC;
END//
DELIMITER ;

-- =====================================================
-- SP: obtener_resumen_referidos
-- Resumen con totales para el panel
-- =====================================================
DROP PROCEDURE IF EXISTS obtener_resumen_referidos;
DELIMITER //
CREATE PROCEDURE obtener_resumen_referidos(
    IN p_id_usuario INT
)
BEGIN
    DECLARE v_total_referidos INT DEFAULT 0;
    DECLARE v_referidos_compraron INT DEFAULT 0;
    DECLARE v_credito_total_ganado DECIMAL(10,2) DEFAULT 0;
    DECLARE v_credito_disponible DECIMAL(10,2) DEFAULT 0;
    DECLARE v_codigo_referido VARCHAR(50);

    -- Obtener código y crédito del usuario
    SELECT CODIGO_REFERIDO, COALESCE(CREDITO_REFERIDOS, 0)
    INTO v_codigo_referido, v_credito_disponible
    FROM usuario WHERE PK_ID_USUARIO = p_id_usuario;

    -- Contar referidos totales
    SELECT COUNT(*) INTO v_total_referidos
    FROM referencias WHERE FK_ID_DUENO_CODIGO = p_id_usuario;

    -- Contar referidos que compraron
    SELECT COUNT(*) INTO v_referidos_compraron
    FROM referencias
    WHERE FK_ID_DUENO_CODIGO = p_id_usuario AND (MEMBRESIA_COMPRADA = 1 OR FECHA_COMPRA IS NOT NULL);

    -- Calcular crédito total ganado histórico
    SELECT COALESCE(SUM(DESCUENTO_APLICADO_DUENO), 0) INTO v_credito_total_ganado
    FROM referencias
    WHERE FK_ID_DUENO_CODIGO = p_id_usuario AND DESCUENTO_APLICADO_DUENO IS NOT NULL;

    SELECT
        v_codigo_referido AS codigo_referido,
        v_total_referidos AS total_referidos,
        v_referidos_compraron AS referidos_compraron,
        v_credito_total_ganado AS credito_total_ganado,
        v_credito_disponible AS credito_disponible;
END//
DELIMITER ;

-- =====================================================
-- SP: crear_usuario (ACTUALIZADO con código referido)
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
    IN p_codigo_referido_usado VARCHAR(50),
    OUT p_mensaje VARCHAR(255),
    OUT p_id_usuario INT
)
BEGIN
    DECLARE v_codigo_referido VARCHAR(20);
    DECLARE v_codigo_existe INT DEFAULT 1;
    DECLARE v_id_dueno INT DEFAULT 0;

    SET p_mensaje = '';
    SET p_id_usuario = 0;

    -- Validaciones
    IF EXISTS (SELECT 1 FROM usuario WHERE NOMBRE_USUARIO = LOWER(TRIM(p_correo))) THEN
        SET p_mensaje = 'El correo electrónico ya está registrado.';
    ELSEIF p_documento IS NOT NULL AND p_documento > 0 AND EXISTS (SELECT 1 FROM usuario WHERE DOCUMENTO_IDENTIDAD = p_documento AND FK_ID_TIPO_DOCUMENTO = p_fk_tipo_documento) THEN
        SET p_mensaje = 'El documento de identidad ya está registrado.';
    ELSE
        -- Generar código de referido único
        WHILE v_codigo_existe > 0 DO
            SET v_codigo_referido = CONCAT('COD', LPAD(FLOOR(RAND() * 1000000), 6, '0'));
            SELECT COUNT(*) INTO v_codigo_existe FROM usuario WHERE CODIGO_REFERIDO = v_codigo_referido;
        END WHILE;

        -- Insertar usuario
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

        SET p_id_usuario = LAST_INSERT_ID();

        -- Registrar referencia si hay código usado
        IF p_codigo_referido_usado IS NOT NULL AND p_codigo_referido_usado != '' THEN
            SELECT PK_ID_USUARIO INTO v_id_dueno
            FROM usuario WHERE CODIGO_REFERIDO = p_codigo_referido_usado AND ESTADO = 1
            LIMIT 1;

            IF v_id_dueno > 0 THEN
                INSERT INTO referencias (FK_ID_DUENO_CODIGO, FK_ID_CLIENTE_REFERIDO, MEMBRESIA_COMPRADA)
                VALUES (v_id_dueno, p_id_usuario, 0);

                -- Incrementar contador de referidos del dueño
                UPDATE usuario
                SET CLIENTES_REFERIDOS_TOTAL = COALESCE(CLIENTES_REFERIDOS_TOTAL, 0) + 1
                WHERE PK_ID_USUARIO = v_id_dueno;
            END IF;
        END IF;

        SET p_mensaje = 'Usuario creado exitosamente.';
    END IF;
END//
DELIMITER ;

-- =====================================================
-- VERIFICACIÓN
-- =====================================================
SELECT 'MIGRACIÓN 074 - SISTEMA DE REFERIDOS COMPLETADA' as info;
SELECT 'Tablas creadas/modificadas: configuracion_referidos, referencias, usuario' as detalle;
SHOW PROCEDURE STATUS WHERE Db = DATABASE() AND Name LIKE '%referid%';
