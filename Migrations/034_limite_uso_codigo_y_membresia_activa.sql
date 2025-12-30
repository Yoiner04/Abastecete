-- =============================================
-- Migración 034: Límite de uso de código y validación de membresía activa
-- Fecha: 2025-12-30
-- Descripción:
--   1. Agrega campo configurable para límite de usos por código
--   2. Valida que el dueño del código tenga membresía activa
-- =============================================

-- =============================================
-- Agregar campo LIMITE_USOS_CODIGO a configuracion_referidos
-- =============================================
-- Nota: Si la columna ya existe, este ALTER dará error pero se puede ignorar
ALTER TABLE configuracion_referidos
    ADD COLUMN `LIMITE_USOS_CODIGO` INT DEFAULT 0 COMMENT '0 = Ilimitado, >0 = Maximo de usos por codigo';

-- Actualizar valor por defecto
UPDATE configuracion_referidos SET LIMITE_USOS_CODIGO = 0 WHERE PK_ID = 1 AND LIMITE_USOS_CODIGO IS NULL;

-- =============================================
-- ACTUALIZAR SP validar_codigo_referido
-- Ahora valida: membresía activa + límite de usos
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
    DECLARE v_tiene_membresia_activa INT DEFAULT 0;
    DECLARE v_usos_actuales INT DEFAULT 0;
    DECLARE v_limite_usos INT DEFAULT 0;

    -- Obtener límite de usos de la configuración
    SELECT COALESCE(LIMITE_USOS_CODIGO, 0) INTO v_limite_usos
    FROM configuracion_referidos
    WHERE PK_ID = 1;

    -- Buscar el dueño del código
    SELECT
        u.PK_ID_USUARIO,
        CONCAT(u.NOMBRES, ' ', u.APELLIDOS)
    INTO v_id_dueno, v_nombre_dueno
    FROM usuario u
    WHERE u.CODIGO_REFERIDO = UPPER(TRIM(p_codigo))
    AND u.CODIGO_REFERIDO IS NOT NULL
    AND u.CODIGO_REFERIDO != ''
    AND u.ESTADO = 1;

    IF v_id_dueno IS NULL THEN
        SET v_valido = 0;
        SET v_mensaje = 'El código de referido no existe o no es válido.';
    ELSEIF p_id_usuario_actual IS NOT NULL AND v_id_dueno = p_id_usuario_actual THEN
        SET v_valido = 0;
        SET v_mensaje = 'No puedes usar tu propio código de referido.';
    ELSE
        -- Verificar si el dueño tiene membresía activa
        SELECT COUNT(*) INTO v_tiene_membresia_activa
        FROM pagos p
        INNER JOIN historial_membresia hm ON hm.FK_ID_USUARIO = p.FK_ID_USUARIO
        WHERE p.FK_ID_USUARIO = v_id_dueno
        AND p.ESTADO_PAGO = 'APROBADO'
        AND hm.FECHA_FIN >= CURDATE()
        AND hm.ESTADO = 1;

        IF v_tiene_membresia_activa = 0 THEN
            SET v_valido = 0;
            SET v_mensaje = 'El código no está disponible en este momento.';
        ELSE
            -- Verificar límite de usos (si aplica)
            IF v_limite_usos > 0 THEN
                SELECT COUNT(*) INTO v_usos_actuales
                FROM referencias
                WHERE FK_ID_DUENO_CODIGO = v_id_dueno;

                IF v_usos_actuales >= v_limite_usos THEN
                    SET v_valido = 0;
                    SET v_mensaje = 'Este código ha alcanzado el límite de usos.';
                ELSE
                    SET v_valido = 1;
                    SET v_mensaje = 'Código válido.';
                END IF;
            ELSE
                -- Sin límite de usos
                SET v_valido = 1;
                SET v_mensaje = 'Código válido.';
            END IF;
        END IF;
    END IF;

    SELECT
        v_valido AS valido,
        v_mensaje AS mensaje,
        COALESCE(v_id_dueno, 0) AS id_dueno,
        COALESCE(v_nombre_dueno, '') AS nombre_dueno;
END//
DELIMITER ;

-- =============================================
-- ACTUALIZAR SP obtener_configuracion_referidos
-- Incluir el nuevo campo
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
        COALESCE(LIMITE_USOS_CODIGO, 0) AS LIMITE_USOS_CODIGO,
        FECHA_ACTUALIZACION,
        ACTUALIZADO_POR
    FROM configuracion_referidos
    WHERE PK_ID = 1;
END//
DELIMITER ;

-- =============================================
-- ACTUALIZAR SP actualizar_configuracion_referidos
-- Incluir el nuevo campo
-- =============================================
DROP PROCEDURE IF EXISTS `actualizar_configuracion_referidos`;

DELIMITER //
CREATE PROCEDURE `actualizar_configuracion_referidos`(
    IN p_tipo_descuento_referido VARCHAR(20),
    IN p_valor_descuento_referido DECIMAL(10,2),
    IN p_tipo_descuento_dueno VARCHAR(20),
    IN p_valor_descuento_dueno DECIMAL(10,2),
    IN p_descuento_activo INT,
    IN p_limite_usos_codigo INT,
    IN p_usuario_id INT
)
BEGIN
    IF EXISTS (SELECT 1 FROM configuracion_referidos WHERE PK_ID = 1) THEN
        UPDATE configuracion_referidos
        SET
            TIPO_DESCUENTO_REFERIDO = p_tipo_descuento_referido,
            VALOR_DESCUENTO_REFERIDO = p_valor_descuento_referido,
            TIPO_DESCUENTO_DUENO = p_tipo_descuento_dueno,
            VALOR_DESCUENTO_DUENO = p_valor_descuento_dueno,
            DESCUENTO_ACTIVO = p_descuento_activo,
            LIMITE_USOS_CODIGO = COALESCE(p_limite_usos_codigo, 0),
            FECHA_ACTUALIZACION = NOW(),
            ACTUALIZADO_POR = p_usuario_id
        WHERE PK_ID = 1;
    ELSE
        INSERT INTO configuracion_referidos (
            TIPO_DESCUENTO_REFERIDO, VALOR_DESCUENTO_REFERIDO,
            TIPO_DESCUENTO_DUENO, VALOR_DESCUENTO_DUENO,
            DESCUENTO_ACTIVO, LIMITE_USOS_CODIGO, FECHA_ACTUALIZACION, ACTUALIZADO_POR
        ) VALUES (
            p_tipo_descuento_referido, p_valor_descuento_referido,
            p_tipo_descuento_dueno, p_valor_descuento_dueno,
            p_descuento_activo, COALESCE(p_limite_usos_codigo, 0), NOW(), p_usuario_id
        );
    END IF;

    SELECT ROW_COUNT() AS filas_afectadas;
END//
DELIMITER ;

-- Mensaje de confirmación
SELECT 'Migracion 034 completada: Límite de usos y validación de membresía activa' AS resultado;
