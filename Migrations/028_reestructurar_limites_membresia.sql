-- =============================================
-- Migración 028: Reestructurar límites de membresía
-- Descripción: Agregar campos de límites configurables y eliminar DESCRIPCION
-- =============================================

-- Agregar nuevos campos de límites
ALTER TABLE tipo_membresia
    ADD COLUMN OFERTAS_FLASH_SIMULTANEAS INT NOT NULL DEFAULT 1 COMMENT 'Cantidad de ofertas flash activas al mismo tiempo',
    ADD COLUMN OFERTAS_FLASH_TOTAL INT NOT NULL DEFAULT 0 COMMENT 'Total de ofertas flash permitidas en la suscripción (0=ilimitado)';

-- Configurar valores por defecto según el tipo de plan
-- Básicos: 1 simultánea, 5 totales por mes
UPDATE tipo_membresia SET OFERTAS_FLASH_SIMULTANEAS = 1, OFERTAS_FLASH_TOTAL = 5
WHERE NOMBRE LIKE '%Básico%';

-- Pro: 3 simultáneas, 15 totales por mes
UPDATE tipo_membresia SET OFERTAS_FLASH_SIMULTANEAS = 3, OFERTAS_FLASH_TOTAL = 15
WHERE NOMBRE LIKE '%Pro%';

-- Premium: 10 simultáneas, ilimitado (0)
UPDATE tipo_membresia SET OFERTAS_FLASH_SIMULTANEAS = 10, OFERTAS_FLASH_TOTAL = 0
WHERE NOMBRE LIKE '%Premium%';

-- Eliminar columna DESCRIPCION (ya no se usa)
ALTER TABLE tipo_membresia DROP COLUMN DESCRIPCION;

-- =============================================
-- Actualizar SP editar_tipo_membresia
-- =============================================
DELIMITER //

DROP PROCEDURE IF EXISTS `editar_tipo_membresia`//

CREATE PROCEDURE `editar_tipo_membresia`(
    IN p_id_tipo_membresia INT,
    IN p_nombre VARCHAR(50),
    IN p_costo INT,
    IN p_estado TINYINT,
    IN p_duracion INT,
    IN p_cantidad INT,
    IN p_ofertas_flash_simultaneas INT,
    IN p_ofertas_flash_total INT,
    IN p_costo_trimestral INT,
    IN p_costo_semestral INT,
    IN p_costo_anual INT
)
BEGIN
    UPDATE tipo_membresia SET
        NOMBRE = p_nombre,
        COSTO = p_costo,
        ESTADO = p_estado,
        DURACION_OFERTA = p_duracion,
        CANTIDAD_PRODUCTOS = p_cantidad,
        OFERTAS_FLASH_SIMULTANEAS = p_ofertas_flash_simultaneas,
        OFERTAS_FLASH_TOTAL = p_ofertas_flash_total,
        COSTO_TRIMESTRAL = p_costo_trimestral,
        COSTO_SEMESTRAL = p_costo_semestral,
        COSTO_ANUAL = p_costo_anual
    WHERE PK_ID_TIPO_MEMBRESIA = p_id_tipo_membresia;
END//

-- =============================================
-- SP para validar si puede crear oferta flash
-- =============================================
DROP PROCEDURE IF EXISTS `validar_limite_ofertas_flash`//

CREATE PROCEDURE `validar_limite_ofertas_flash`(
    IN p_id_local INT,
    OUT p_puede_crear TINYINT,
    OUT p_mensaje VARCHAR(200)
)
BEGIN
    DECLARE v_max_simultaneas INT DEFAULT 1;
    DECLARE v_max_total INT DEFAULT 0;
    DECLARE v_activas_ahora INT DEFAULT 0;
    DECLARE v_usadas_suscripcion INT DEFAULT 0;
    DECLARE v_id_suscripcion INT DEFAULT 0;
    DECLARE v_fecha_inicio_suscripcion DATETIME;

    -- Obtener límites de la membresía activa
    SELECT
        COALESCE(tm.OFERTAS_FLASH_SIMULTANEAS, 1),
        COALESCE(tm.OFERTAS_FLASH_TOTAL, 0),
        s.PK_ID_SUSCRIPCION,
        s.FECHA_INICIO
    INTO v_max_simultaneas, v_max_total, v_id_suscripcion, v_fecha_inicio_suscripcion
    FROM local l
    LEFT JOIN suscripcion s ON l.FK_ID_SUSCRIPCION_ACTIVA = s.PK_ID_SUSCRIPCION AND s.ESTADO = 1
    LEFT JOIN tipo_membresia tm ON s.FK_ID_TIPO_MEMBRESIA = tm.PK_ID_TIPO_MEMBRESIA
    WHERE l.PK_ID_LOCAL = p_id_local;

    -- Contar ofertas activas ahora
    SELECT COUNT(*) INTO v_activas_ahora
    FROM oferta_flash
    WHERE FK_ID_LOCAL = p_id_local
      AND ESTADO = 1
      AND FECHA_EXPIRACION > NOW();

    -- Verificar límite de simultáneas
    IF v_activas_ahora >= v_max_simultaneas THEN
        SET p_puede_crear = 0;
        SET p_mensaje = CONCAT('Ya tienes ', v_activas_ahora, ' ofertas activas. Tu plan permite máximo ', v_max_simultaneas);
    -- Verificar límite total (si aplica)
    ELSEIF v_max_total > 0 THEN
        -- Contar ofertas creadas desde inicio de suscripción
        SELECT COUNT(*) INTO v_usadas_suscripcion
        FROM oferta_flash
        WHERE FK_ID_LOCAL = p_id_local
          AND FECHA_CREACION >= v_fecha_inicio_suscripcion;

        IF v_usadas_suscripcion >= v_max_total THEN
            SET p_puede_crear = 0;
            SET p_mensaje = CONCAT('Has usado ', v_usadas_suscripcion, ' de ', v_max_total, ' ofertas permitidas en tu suscripción');
        ELSE
            SET p_puede_crear = 1;
            SET p_mensaje = CONCAT('Puedes crear oferta. Usadas: ', v_usadas_suscripcion, '/', v_max_total);
        END IF;
    ELSE
        SET p_puede_crear = 1;
        SET p_mensaje = 'OK';
    END IF;
END//

DELIMITER ;
