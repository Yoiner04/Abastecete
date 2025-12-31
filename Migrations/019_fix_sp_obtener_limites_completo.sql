-- =====================================================
-- Migración 019: Corregir SP obtener_limites_membresia con todas las columnas requeridas
-- Fecha: 2025-12-31
-- El código C# espera: DiasRestantes, FechaVencimiento, NombreMembresia,
-- LimiteOfertasSimultaneas, LimiteOfertasTotal, DuracionOfertaHoras,
-- PuedeAgregarProductos, PuedeCrearOferta
-- =====================================================

DROP PROCEDURE IF EXISTS obtener_limites_membresia;

DELIMITER //
CREATE PROCEDURE obtener_limites_membresia(IN p_id_local INT)
BEGIN
    DECLARE v_productos_actuales INT DEFAULT 0;
    DECLARE v_ofertas_activas INT DEFAULT 0;
    DECLARE v_ofertas_usadas_periodo INT DEFAULT 0;

    -- Contar productos actuales del local
    SELECT COUNT(DISTINCT FK_ID_PRODUCTO) INTO v_productos_actuales
    FROM producto_marca
    WHERE FK_ID_LOCAL = p_id_local AND DISPONIBLE = 1;

    -- Contar ofertas flash activas
    SELECT COUNT(*) INTO v_ofertas_activas
    FROM oferta_flash
    WHERE FK_ID_LOCAL = p_id_local
      AND ESTADO_OFERTA_FLASH = 1
      AND TIEMPO_OFERTA_FLASH >= NOW();

    -- Contar ofertas usadas en el periodo (mes actual)
    SELECT COUNT(*) INTO v_ofertas_usadas_periodo
    FROM oferta_flash
    WHERE FK_ID_LOCAL = p_id_local
      AND MONTH(FECHA_OFERTA_FLASH) = MONTH(NOW())
      AND YEAR(FECHA_OFERTA_FLASH) = YEAR(NOW());

    SELECT
        CASE WHEN s.PK_ID_SUSCRIPCION IS NOT NULL AND s.ESTADO = 1 THEN 1 ELSE 0 END as TieneSuscripcionActiva,
        CASE
            WHEN s.FECHA_FIN IS NOT NULL THEN DATEDIFF(s.FECHA_FIN, NOW())
            ELSE 0
        END as DiasRestantes,
        s.FECHA_FIN as FechaVencimiento,
        COALESCE(tm.NOMBRE, '') as NombreMembresia,
        COALESCE(CAST(tm.CANTIDAD_PRODUCTOS AS SIGNED), 0) as LimiteProductos,
        COALESCE(tm.OFERTAS_FLASH_SIMULTANEAS, 0) as LimiteOfertasSimultaneas,
        COALESCE(tm.OFERTAS_FLASH_TOTAL, 0) as LimiteOfertasTotal,
        COALESCE(tm.DURACION_OFERTA, 24) as DuracionOfertaHoras,
        v_productos_actuales as ProductosActuales,
        v_ofertas_activas as OfertasActivas,
        v_ofertas_usadas_periodo as OfertasUsadasPeriodo,
        CASE
            WHEN COALESCE(CAST(tm.CANTIDAD_PRODUCTOS AS SIGNED), 0) = 0 THEN 1
            WHEN v_productos_actuales < COALESCE(CAST(tm.CANTIDAD_PRODUCTOS AS SIGNED), 0) THEN 1
            ELSE 0
        END as PuedeAgregarProductos,
        CASE
            WHEN s.PK_ID_SUSCRIPCION IS NULL OR s.ESTADO != 1 THEN 0
            WHEN v_ofertas_activas >= COALESCE(tm.OFERTAS_FLASH_SIMULTANEAS, 0) THEN 0
            WHEN COALESCE(tm.OFERTAS_FLASH_TOTAL, 0) > 0 AND v_ofertas_usadas_periodo >= tm.OFERTAS_FLASH_TOTAL THEN 0
            ELSE 1
        END as PuedeCrearOferta
    FROM `local` l
    LEFT JOIN suscripcion s ON l.FK_ID_SUSCRIPCION_ACTIVA = s.PK_ID_SUSCRIPCION AND s.ESTADO = 1
    LEFT JOIN tipo_membresia tm ON s.FK_ID_TIPO_MEMBRESIA = tm.PK_ID_TIPO_MEMBRESIA
    WHERE l.PK_ID_LOCAL = p_id_local;
END//
DELIMITER ;

-- =====================================================
SELECT 'Migración 019 completada' AS Mensaje;
-- =====================================================
