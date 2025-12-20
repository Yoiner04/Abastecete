-- Migración 031: SP obtener_todas_membresias
-- Fecha: 2025-12-20
-- Descripción: Permite obtener todas las membresías activas para el modal de cambio de plan

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
        ESTADO
    FROM tipo_membresia
    WHERE ESTADO = 1
    ORDER BY NOMBRE;
END //

DELIMITER ;
