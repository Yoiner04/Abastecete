-- =============================================
-- Migración 036: SP para validar límite de productos
-- Descripción: Valida si un local puede agregar más productos según su membresía
-- =============================================

DELIMITER //

-- =============================================
-- SP: Validar si puede agregar productos
-- =============================================
DROP PROCEDURE IF EXISTS `validar_limite_productos`//

CREATE PROCEDURE `validar_limite_productos`(
    IN p_id_local INT,
    OUT p_puede_agregar TINYINT,
    OUT p_productos_actuales INT,
    OUT p_limite_maximo INT,
    OUT p_mensaje VARCHAR(200)
)
BEGIN
    DECLARE v_tiene_suscripcion TINYINT DEFAULT 0;
    DECLARE v_suscripcion_activa TINYINT DEFAULT 0;

    -- Verificar si tiene suscripción activa
    SELECT
        COUNT(*) > 0,
        COALESCE(tm.CANTIDAD_PRODUCTOS, 0),
        (SELECT COUNT(*) FROM producto WHERE FK_ID_LOCAL = p_id_local AND ESTADO = 1)
    INTO v_tiene_suscripcion, p_limite_maximo, p_productos_actuales
    FROM local l
    LEFT JOIN suscripcion s ON l.FK_ID_SUSCRIPCION_ACTIVA = s.PK_ID_SUSCRIPCION
    LEFT JOIN tipo_membresia tm ON s.FK_ID_TIPO_MEMBRESIA = tm.PK_ID_TIPO_MEMBRESIA
    WHERE l.PK_ID_LOCAL = p_id_local
      AND s.ESTADO = 1
      AND s.FECHA_FIN > NOW();

    -- Si no tiene suscripción activa
    IF NOT v_tiene_suscripcion THEN
        SET p_puede_agregar = 0;
        SET p_mensaje = 'No tienes una membresía activa. Activa o renueva tu plan para agregar productos.';
    -- Si el límite es 0, es ilimitado
    ELSEIF p_limite_maximo = 0 THEN
        SET p_puede_agregar = 1;
        SET p_mensaje = 'OK - Sin límite de productos';
    -- Si ya alcanzó el límite
    ELSEIF p_productos_actuales >= p_limite_maximo THEN
        SET p_puede_agregar = 0;
        SET p_mensaje = CONCAT('Has alcanzado el límite de ', p_limite_maximo, ' productos de tu plan. Mejora tu membresía para agregar más.');
    -- Puede agregar
    ELSE
        SET p_puede_agregar = 1;
        SET p_mensaje = CONCAT('Puedes agregar productos. Usados: ', p_productos_actuales, '/', p_limite_maximo);
    END IF;
END//

-- =============================================
-- SP: Obtener info de límites de membresía para un local
-- (Para usar en la UI y mostrar estado de límites)
-- =============================================
DROP PROCEDURE IF EXISTS `obtener_limites_membresia`//

CREATE PROCEDURE `obtener_limites_membresia`(
    IN p_id_local INT
)
BEGIN
    DECLARE v_productos_actuales INT DEFAULT 0;
    DECLARE v_ofertas_activas INT DEFAULT 0;
    DECLARE v_ofertas_usadas_periodo INT DEFAULT 0;

    -- Contar productos activos
    SELECT COUNT(*) INTO v_productos_actuales
    FROM producto WHERE FK_ID_LOCAL = p_id_local AND ESTADO = 1;

    -- Contar ofertas flash activas
    SELECT COUNT(*) INTO v_ofertas_activas
    FROM oferta_flash
    WHERE FK_ID_LOCAL = p_id_local
      AND ESTADO = 1
      AND FECHA_EXPIRACION > NOW();

    -- Contar ofertas usadas en el período de suscripción
    SELECT COUNT(*) INTO v_ofertas_usadas_periodo
    FROM oferta_flash ofl
    INNER JOIN local l ON ofl.FK_ID_LOCAL = l.PK_ID_LOCAL
    LEFT JOIN suscripcion s ON l.FK_ID_SUSCRIPCION_ACTIVA = s.PK_ID_SUSCRIPCION
    WHERE ofl.FK_ID_LOCAL = p_id_local
      AND ofl.FECHA_CREACION >= COALESCE(s.FECHA_INICIO, '1900-01-01');

    -- Obtener límites y estado
    SELECT
        -- Info de suscripción
        CASE WHEN s.PK_ID_SUSCRIPCION IS NOT NULL AND s.ESTADO = 1 AND s.FECHA_FIN > NOW()
             THEN 1 ELSE 0 END AS TieneSuscripcionActiva,
        COALESCE(DATEDIFF(s.FECHA_FIN, NOW()), 0) AS DiasRestantes,
        s.FECHA_FIN AS FechaVencimiento,

        -- Info de membresía
        tm.NOMBRE AS NombreMembresia,
        COALESCE(tm.CANTIDAD_PRODUCTOS, 0) AS LimiteProductos,
        COALESCE(tm.OFERTAS_FLASH_SIMULTANEAS, 1) AS LimiteOfertasSimultaneas,
        COALESCE(tm.OFERTAS_FLASH_TOTAL, 0) AS LimiteOfertasTotal,
        COALESCE(tm.DURACION_OFERTA, 24) AS DuracionOfertaHoras,

        -- Uso actual
        v_productos_actuales AS ProductosActuales,
        v_ofertas_activas AS OfertasActivas,
        v_ofertas_usadas_periodo AS OfertasUsadasPeriodo,

        -- Puede agregar?
        CASE
            WHEN s.PK_ID_SUSCRIPCION IS NULL OR s.ESTADO != 1 OR s.FECHA_FIN <= NOW() THEN 0
            WHEN COALESCE(tm.CANTIDAD_PRODUCTOS, 0) = 0 THEN 1
            WHEN v_productos_actuales < COALESCE(tm.CANTIDAD_PRODUCTOS, 0) THEN 1
            ELSE 0
        END AS PuedeAgregarProductos,

        CASE
            WHEN s.PK_ID_SUSCRIPCION IS NULL OR s.ESTADO != 1 OR s.FECHA_FIN <= NOW() THEN 0
            WHEN v_ofertas_activas >= COALESCE(tm.OFERTAS_FLASH_SIMULTANEAS, 1) THEN 0
            WHEN COALESCE(tm.OFERTAS_FLASH_TOTAL, 0) > 0 AND v_ofertas_usadas_periodo >= tm.OFERTAS_FLASH_TOTAL THEN 0
            ELSE 1
        END AS PuedeCrearOferta

    FROM local l
    LEFT JOIN suscripcion s ON l.FK_ID_SUSCRIPCION_ACTIVA = s.PK_ID_SUSCRIPCION
    LEFT JOIN tipo_membresia tm ON s.FK_ID_TIPO_MEMBRESIA = tm.PK_ID_TIPO_MEMBRESIA
    WHERE l.PK_ID_LOCAL = p_id_local;
END//

DELIMITER ;
