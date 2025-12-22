-- =============================================
-- Migración 041: Corregir SP obtener_limites_membresia
-- Fecha: 2025-12-21
-- Problema: CANTIDAD_PRODUCTOS es VARCHAR, no INT
--           Necesita CAST para comparaciones numéricas
-- =============================================

DROP PROCEDURE IF EXISTS `obtener_limites_membresia`;

DELIMITER //

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
        COALESCE(tm.NOMBRE, 'Sin membresía') AS NombreMembresia,
        CAST(COALESCE(tm.CANTIDAD_PRODUCTOS, '0') AS UNSIGNED) AS LimiteProductos,
        COALESCE(tm.OFERTAS_FLASH_SIMULTANEAS, 1) AS LimiteOfertasSimultaneas,
        COALESCE(tm.OFERTAS_FLASH_TOTAL, 0) AS LimiteOfertasTotal,
        COALESCE(tm.DURACION_OFERTA, 24) AS DuracionOfertaHoras,

        -- Uso actual
        v_productos_actuales AS ProductosActuales,
        v_ofertas_activas AS OfertasActivas,
        v_ofertas_usadas_periodo AS OfertasUsadasPeriodo,

        -- Puede agregar productos?
        CASE
            WHEN s.PK_ID_SUSCRIPCION IS NULL OR s.ESTADO != 1 OR s.FECHA_FIN <= NOW() THEN 0
            WHEN CAST(COALESCE(tm.CANTIDAD_PRODUCTOS, '0') AS UNSIGNED) = 0 THEN 1
            WHEN v_productos_actuales < CAST(COALESCE(tm.CANTIDAD_PRODUCTOS, '0') AS UNSIGNED) THEN 1
            ELSE 0
        END AS PuedeAgregarProductos,

        -- Puede crear oferta?
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
