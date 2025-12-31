-- =====================================================
-- Migración 017: Corregir nombres de columnas en oferta_flash
-- Fecha: 2025-12-31
-- Columnas correctas: ESTADO_OFERTA_FLASH, TIEMPO_OFERTA_FLASH, FECHA_OFERTA_FLASH
-- =====================================================

-- 1. obtener_limites_membresia
DROP PROCEDURE IF EXISTS obtener_limites_membresia;

DELIMITER //
CREATE PROCEDURE obtener_limites_membresia(IN p_id_local INT)
BEGIN
    DECLARE v_productos_actuales INT DEFAULT 0;
    DECLARE v_ofertas_activas INT DEFAULT 0;
    DECLARE v_ofertas_usadas_periodo INT DEFAULT 0;

    SELECT COUNT(DISTINCT FK_ID_PRODUCTO) INTO v_productos_actuales
    FROM producto_marca
    WHERE FK_ID_LOCAL = p_id_local AND DISPONIBLE = 1;

    SELECT COUNT(*) INTO v_ofertas_activas
    FROM oferta_flash
    WHERE FK_ID_LOCAL = p_id_local
      AND ESTADO_OFERTA_FLASH = 1
      AND TIEMPO_OFERTA_FLASH >= NOW();

    SELECT COUNT(*) INTO v_ofertas_usadas_periodo
    FROM oferta_flash
    WHERE FK_ID_LOCAL = p_id_local
      AND MONTH(FECHA_OFERTA_FLASH) = MONTH(NOW())
      AND YEAR(FECHA_OFERTA_FLASH) = YEAR(NOW());

    SELECT
        COALESCE(tm.CANTIDAD_PRODUCTOS, 0) as LimiteProductos,
        COALESCE(tm.CANTIDAD_OFERTAS, 0) as LimiteOfertasActivas,
        COALESCE(tm.OFERTAS_POR_MES, 0) as LimiteOfertasMes,
        v_productos_actuales as ProductosActuales,
        v_ofertas_activas as OfertasActivas,
        v_ofertas_usadas_periodo as OfertasUsadasPeriodo,
        CASE WHEN s.PK_ID_SUSCRIPCION IS NOT NULL AND s.ESTADO = 1 THEN 1 ELSE 0 END as TieneSuscripcionActiva,
        CASE WHEN COALESCE(tm.CANTIDAD_PRODUCTOS, 0) = 0 THEN 1 ELSE 0 END as ProductosIlimitados
    FROM `local` l
    LEFT JOIN suscripcion s ON l.FK_ID_SUSCRIPCION_ACTIVA = s.PK_ID_SUSCRIPCION AND s.ESTADO = 1
    LEFT JOIN tipo_membresia tm ON s.FK_ID_TIPO_MEMBRESIA = tm.PK_ID_TIPO_MEMBRESIA
    WHERE l.PK_ID_LOCAL = p_id_local;
END//
DELIMITER ;

-- 2. sp_obtener_limites_membresia
DROP PROCEDURE IF EXISTS sp_obtener_limites_membresia;

DELIMITER //
CREATE PROCEDURE sp_obtener_limites_membresia(IN p_id_local INT)
BEGIN
    DECLARE v_productos_actuales INT DEFAULT 0;
    DECLARE v_ofertas_activas INT DEFAULT 0;
    DECLARE v_ofertas_usadas_periodo INT DEFAULT 0;

    SELECT COUNT(DISTINCT FK_ID_PRODUCTO) INTO v_productos_actuales
    FROM producto_marca
    WHERE FK_ID_LOCAL = p_id_local AND DISPONIBLE = 1;

    SELECT COUNT(*) INTO v_ofertas_activas
    FROM oferta_flash
    WHERE FK_ID_LOCAL = p_id_local
      AND ESTADO_OFERTA_FLASH = 1
      AND TIEMPO_OFERTA_FLASH >= NOW();

    SELECT COUNT(*) INTO v_ofertas_usadas_periodo
    FROM oferta_flash
    WHERE FK_ID_LOCAL = p_id_local
      AND MONTH(FECHA_OFERTA_FLASH) = MONTH(NOW())
      AND YEAR(FECHA_OFERTA_FLASH) = YEAR(NOW());

    SELECT
        COALESCE(tm.CANTIDAD_PRODUCTOS, 0) as LimiteProductos,
        COALESCE(tm.CANTIDAD_OFERTAS, 0) as LimiteOfertasActivas,
        COALESCE(tm.OFERTAS_POR_MES, 0) as LimiteOfertasMes,
        v_productos_actuales as ProductosActuales,
        v_ofertas_activas as OfertasActivas,
        v_ofertas_usadas_periodo as OfertasUsadasPeriodo,
        CASE WHEN s.PK_ID_SUSCRIPCION IS NOT NULL AND s.ESTADO = 1 THEN 1 ELSE 0 END as TieneSuscripcionActiva,
        CASE WHEN COALESCE(tm.CANTIDAD_PRODUCTOS, 0) = 0 THEN 1 ELSE 0 END as ProductosIlimitados
    FROM `local` l
    LEFT JOIN suscripcion s ON l.FK_ID_SUSCRIPCION_ACTIVA = s.PK_ID_SUSCRIPCION AND s.ESTADO = 1
    LEFT JOIN tipo_membresia tm ON s.FK_ID_TIPO_MEMBRESIA = tm.PK_ID_TIPO_MEMBRESIA
    WHERE l.PK_ID_LOCAL = p_id_local;
END//
DELIMITER ;

-- =====================================================
SELECT 'Migración 017 completada' AS Mensaje;
-- =====================================================
