-- =============================================
-- Migración 031: Sistema completo de referidos y descuentos
-- Fecha: 2025-12-30
-- Descripción:
--   1. Crea tabla configuracion_referidos para administrar descuentos
--   2. Crea todos los SPs necesarios para el sistema de referidos
--   3. Permite configurar % descuento para quien usa el código (referido)
--   4. Permite configurar % crédito para quien comparte el código (dueño)
-- =============================================

-- =============================================
-- TABLA: configuracion_referidos
-- =============================================
CREATE TABLE IF NOT EXISTS `configuracion_referidos` (
    `PK_ID` INT NOT NULL AUTO_INCREMENT,
    `TIPO_DESCUENTO_REFERIDO` ENUM('PORCENTAJE', 'MONTO_FIJO') DEFAULT 'PORCENTAJE' COMMENT 'Tipo de descuento para quien usa el código',
    `VALOR_DESCUENTO_REFERIDO` DECIMAL(10,2) DEFAULT 10.00 COMMENT 'Valor del descuento (% o monto fijo)',
    `TIPO_DESCUENTO_DUENO` ENUM('PORCENTAJE', 'MONTO_FIJO') DEFAULT 'PORCENTAJE' COMMENT 'Tipo de crédito para dueño del código',
    `VALOR_DESCUENTO_DUENO` DECIMAL(10,2) DEFAULT 10.00 COMMENT 'Valor del crédito (% o monto fijo)',
    `DESCUENTO_ACTIVO` TINYINT DEFAULT 1 COMMENT '1=Activo, 0=Inactivo',
    `FECHA_ACTUALIZACION` DATETIME DEFAULT NULL,
    `ACTUALIZADO_POR` INT DEFAULT NULL,
    PRIMARY KEY (`PK_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Insertar configuración por defecto si no existe
INSERT INTO configuracion_referidos (PK_ID, TIPO_DESCUENTO_REFERIDO, VALOR_DESCUENTO_REFERIDO, TIPO_DESCUENTO_DUENO, VALOR_DESCUENTO_DUENO, DESCUENTO_ACTIVO)
SELECT 1, 'PORCENTAJE', 10.00, 'PORCENTAJE', 10.00, 1
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM configuracion_referidos WHERE PK_ID = 1);

-- =============================================
-- SP: obtener_configuracion_referidos
-- =============================================
DROP PROCEDURE IF EXISTS `obtener_configuracion_referidos`;

DELIMITER //
CREATE PROCEDURE `obtener_configuracion_referidos`()
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
    WHERE PK_ID = 1;
END//
DELIMITER ;

-- =============================================
-- SP: actualizar_configuracion_referidos
-- =============================================
DROP PROCEDURE IF EXISTS `actualizar_configuracion_referidos`;

DELIMITER //
CREATE PROCEDURE `actualizar_configuracion_referidos`(
    IN p_tipo_descuento_referido VARCHAR(20),
    IN p_valor_descuento_referido DECIMAL(10,2),
    IN p_tipo_descuento_dueno VARCHAR(20),
    IN p_valor_descuento_dueno DECIMAL(10,2),
    IN p_descuento_activo INT,
    IN p_usuario_id INT
)
BEGIN
    -- Verificar si existe la configuración
    IF EXISTS (SELECT 1 FROM configuracion_referidos WHERE PK_ID = 1) THEN
        UPDATE configuracion_referidos
        SET
            TIPO_DESCUENTO_REFERIDO = p_tipo_descuento_referido,
            VALOR_DESCUENTO_REFERIDO = p_valor_descuento_referido,
            TIPO_DESCUENTO_DUENO = p_tipo_descuento_dueno,
            VALOR_DESCUENTO_DUENO = p_valor_descuento_dueno,
            DESCUENTO_ACTIVO = p_descuento_activo,
            FECHA_ACTUALIZACION = NOW(),
            ACTUALIZADO_POR = p_usuario_id
        WHERE PK_ID = 1;
    ELSE
        INSERT INTO configuracion_referidos (
            TIPO_DESCUENTO_REFERIDO, VALOR_DESCUENTO_REFERIDO,
            TIPO_DESCUENTO_DUENO, VALOR_DESCUENTO_DUENO,
            DESCUENTO_ACTIVO, FECHA_ACTUALIZACION, ACTUALIZADO_POR
        ) VALUES (
            p_tipo_descuento_referido, p_valor_descuento_referido,
            p_tipo_descuento_dueno, p_valor_descuento_dueno,
            p_descuento_activo, NOW(), p_usuario_id
        );
    END IF;

    SELECT ROW_COUNT() AS filas_afectadas;
END//
DELIMITER ;

-- =============================================
-- SP: calcular_descuento_referido
-- Calcula el descuento disponible para un usuario al comprar membresía
-- =============================================
DROP PROCEDURE IF EXISTS `calcular_descuento_referido`;

DELIMITER //
CREATE PROCEDURE `calcular_descuento_referido`(
    IN p_id_usuario INT,
    IN p_monto_base DECIMAL(10,2)
)
BEGIN
    DECLARE v_codigo_usado VARCHAR(20) DEFAULT NULL;
    DECLARE v_ya_uso_descuento INT DEFAULT 0;
    DECLARE v_credito_disponible DECIMAL(10,2) DEFAULT 0;
    DECLARE v_tipo_descuento VARCHAR(20) DEFAULT 'PORCENTAJE';
    DECLARE v_valor_descuento DECIMAL(10,2) DEFAULT 0;
    DECLARE v_descuento_activo INT DEFAULT 0;
    DECLARE v_descuento_calculado DECIMAL(10,2) DEFAULT 0;
    DECLARE v_monto_final DECIMAL(10,2);

    -- Obtener datos del usuario
    SELECT
        CODIGO_REFERIDO_USADO,
        YA_USO_DESCUENTO_REFERIDO,
        CREDITO_REFERIDOS
    INTO v_codigo_usado, v_ya_uso_descuento, v_credito_disponible
    FROM usuario
    WHERE PK_ID_USUARIO = p_id_usuario;

    -- Obtener configuración de descuentos
    SELECT
        TIPO_DESCUENTO_REFERIDO,
        VALOR_DESCUENTO_REFERIDO,
        DESCUENTO_ACTIVO
    INTO v_tipo_descuento, v_valor_descuento, v_descuento_activo
    FROM configuracion_referidos
    WHERE PK_ID = 1;

    -- Calcular descuento solo si:
    -- 1. El sistema de descuentos está activo
    -- 2. El usuario tiene un código de referido usado
    -- 3. El usuario NO ha usado su descuento de primera compra
    IF v_descuento_activo = 1 AND v_codigo_usado IS NOT NULL AND v_codigo_usado != '' AND v_ya_uso_descuento = 0 THEN
        IF v_tipo_descuento = 'PORCENTAJE' THEN
            SET v_descuento_calculado = ROUND(p_monto_base * (v_valor_descuento / 100), 2);
        ELSE
            SET v_descuento_calculado = LEAST(v_valor_descuento, p_monto_base);
        END IF;
    END IF;

    -- Calcular monto final
    SET v_monto_final = GREATEST(p_monto_base - v_descuento_calculado, 0);

    -- Retornar resultado
    SELECT
        v_descuento_calculado AS descuento_referido,
        COALESCE(v_credito_disponible, 0) AS credito_disponible,
        v_ya_uso_descuento AS ya_uso_descuento,
        COALESCE(v_codigo_usado, '') AS codigo_usado,
        v_tipo_descuento AS tipo_descuento,
        v_valor_descuento AS valor_configurado,
        v_monto_final AS monto_final;
END//
DELIMITER ;

-- =============================================
-- SP: aplicar_descuento_referido
-- Se llama después de confirmar el pago para actualizar créditos
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

    -- Obtener código usado por el referido
    SELECT CODIGO_REFERIDO_USADO INTO v_codigo_usado
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
        SET CREDITO_REFERIDOS = CREDITO_REFERIDOS + v_credito_a_dar
        WHERE PK_ID_USUARIO = v_id_dueno;

        -- Actualizar la referencia como "compró membresía"
        UPDATE referencias
        SET MEMBRESIA_COMPRADA = 1
        WHERE FK_ID_DUENO_CODIGO = v_id_dueno
        AND FK_ID_CLIENTE_REFERIDO = p_id_usuario_referido;
    END IF;

    SELECT 'OK' AS resultado, v_credito_a_dar AS credito_dado_a_dueno;
END//
DELIMITER ;

-- =============================================
-- SP: consultar_mis_referidos
-- Lista de usuarios que usaron mi código
-- =============================================
DROP PROCEDURE IF EXISTS `consultar_mis_referidos`;

DELIMITER //
CREATE PROCEDURE `consultar_mis_referidos`(
    IN p_id_usuario INT
)
BEGIN
    SELECT
        r.PK_ID_REFERENCIA,
        r.FK_ID_CLIENTE_REFERIDO AS FK_ID_USUARIO_REFERIDO,
        u.NOMBRES,
        u.APELLIDOS,
        r.FECHA_REGISTRO,
        p.FECHA_PAGO AS FECHA_COMPRA,
        p.MONTO AS MONTO_COMPRA,
        CASE
            WHEN r.MEMBRESIA_COMPRADA = 1 THEN
                ROUND(
                    CASE
                        WHEN c.TIPO_DESCUENTO_DUENO = 'PORCENTAJE' THEN p.MONTO * (c.VALOR_DESCUENTO_DUENO / 100)
                        ELSE c.VALOR_DESCUENTO_DUENO
                    END, 2)
            ELSE 0
        END AS credito_recibido,
        tm.NOMBRE_TIPO_MEMBRESIA AS membresia_comprada,
        r.MEMBRESIA_COMPRADA AS ha_comprado
    FROM referencias r
    INNER JOIN usuario u ON r.FK_ID_CLIENTE_REFERIDO = u.PK_ID_USUARIO
    LEFT JOIN pagos p ON p.FK_ID_USUARIO = r.FK_ID_CLIENTE_REFERIDO AND p.ESTADO_PAGO = 'APROBADO'
    LEFT JOIN tipo_membresia tm ON p.FK_ID_TIPO_MEMBRESIA = tm.PK_ID_TIPO_MEMBRESIA
    CROSS JOIN configuracion_referidos c
    WHERE r.FK_ID_DUENO_CODIGO = p_id_usuario
    ORDER BY r.FECHA_REGISTRO DESC;
END//
DELIMITER ;

-- =============================================
-- SP: obtener_resumen_referidos
-- Resumen del sistema de referidos para un usuario
-- =============================================
DROP PROCEDURE IF EXISTS `obtener_resumen_referidos`;

DELIMITER //
CREATE PROCEDURE `obtener_resumen_referidos`(
    IN p_id_usuario INT
)
BEGIN
    DECLARE v_codigo_referido VARCHAR(20) DEFAULT '';
    DECLARE v_total_referidos INT DEFAULT 0;
    DECLARE v_referidos_compraron INT DEFAULT 0;
    DECLARE v_credito_total DECIMAL(10,2) DEFAULT 0;
    DECLARE v_credito_disponible DECIMAL(10,2) DEFAULT 0;

    -- Obtener código y crédito del usuario
    SELECT
        COALESCE(CODIGO_REFERIDO, ''),
        COALESCE(CREDITO_REFERIDOS, 0)
    INTO v_codigo_referido, v_credito_disponible
    FROM usuario
    WHERE PK_ID_USUARIO = p_id_usuario;

    -- Contar total de referidos
    SELECT COUNT(*) INTO v_total_referidos
    FROM referencias
    WHERE FK_ID_DUENO_CODIGO = p_id_usuario;

    -- Contar referidos que compraron
    SELECT COUNT(*) INTO v_referidos_compraron
    FROM referencias
    WHERE FK_ID_DUENO_CODIGO = p_id_usuario
    AND MEMBRESIA_COMPRADA = 1;

    -- Calcular crédito total ganado históricamente
    SELECT COALESCE(SUM(
        CASE
            WHEN c.TIPO_DESCUENTO_DUENO = 'PORCENTAJE' THEN p.MONTO * (c.VALOR_DESCUENTO_DUENO / 100)
            ELSE c.VALOR_DESCUENTO_DUENO
        END
    ), 0) INTO v_credito_total
    FROM referencias r
    INNER JOIN pagos p ON p.FK_ID_USUARIO = r.FK_ID_CLIENTE_REFERIDO AND p.ESTADO_PAGO = 'APROBADO'
    CROSS JOIN configuracion_referidos c
    WHERE r.FK_ID_DUENO_CODIGO = p_id_usuario
    AND r.MEMBRESIA_COMPRADA = 1;

    SELECT
        v_codigo_referido AS codigo_referido,
        v_total_referidos AS total_referidos,
        v_referidos_compraron AS referidos_compraron,
        ROUND(v_credito_total, 2) AS credito_total_ganado,
        ROUND(v_credito_disponible, 2) AS credito_disponible;
END//
DELIMITER ;

-- =============================================
-- Nota: Las columnas CREDITO_REFERIDOS y YA_USO_DESCUENTO_REFERIDO
-- ya existen en la tabla usuario según bd2.sql
-- Si no existieran, ejecutar manualmente:
-- ALTER TABLE usuario ADD COLUMN CREDITO_REFERIDOS DECIMAL(10,2) DEFAULT 0.00;
-- ALTER TABLE usuario ADD COLUMN YA_USO_DESCUENTO_REFERIDO TINYINT DEFAULT 0;
-- =============================================

-- Mensaje de confirmación
SELECT 'Migracion 031 completada: Sistema completo de referidos y descuentos' AS resultado;
