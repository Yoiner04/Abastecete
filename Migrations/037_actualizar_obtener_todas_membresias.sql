-- Migración 037: Actualizar SP obtener_todas_membresias
-- Fecha: 2025-12-21
-- Descripción: Agregar campos de límites al SP para mostrar correctamente en MiMembresia

DELIMITER //

DROP PROCEDURE IF EXISTS `obtener_todas_membresias`//

CREATE PROCEDURE `obtener_todas_membresias`()
BEGIN
    SELECT
        PK_ID_TIPO_MEMBRESIA,
        NOMBRE,
        COSTO AS COSTO_MES,
        COSTO_TRIMESTRAL AS COSTO_TRIMESTRE,
        COSTO_SEMESTRAL AS COSTO_SEMESTRE,
        COSTO_ANUAL AS COSTO_ANIO,
        ESTADO,
        -- Campos de límites
        CANTIDAD_PRODUCTOS,
        DURACION_OFERTA,
        OFERTAS_FLASH_SIMULTANEAS,
        OFERTAS_FLASH_TOTAL
    FROM tipo_membresia
    WHERE ESTADO = 1
    ORDER BY NOMBRE;
END //

DELIMITER ;
