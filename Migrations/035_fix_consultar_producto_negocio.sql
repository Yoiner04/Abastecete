-- =============================================
-- Migración 035: Fix SP consultar_producto_negocio_seguro
-- Fecha: 2025-12-21
-- Descripción: Corrige el JOIN de unidad para usar productoslocal.FK_ID_UNIDAD
--              en lugar de producto.FK_ID_UNIDAD (la unidad está en productoslocal)
--              También usa LEFT JOIN para que funcione si no hay unidad
-- =============================================

DROP PROCEDURE IF EXISTS `consultar_producto_negocio_seguro`;

DELIMITER //
CREATE PROCEDURE `consultar_producto_negocio_seguro`(
    IN `p_id_producto` INT,
    IN `p_id_local` INT,
    OUT `mensaje` VARCHAR(255),
    OUT `resultado` INT
)
BEGIN
    DECLARE producto_existe INT DEFAULT 0;

    -- Verificar si existe el producto en ese local
    SELECT COUNT(*) INTO producto_existe
    FROM productoslocal pl
    INNER JOIN producto p ON pl.FK_ID_PRODUCTO = p.PK_ID_PRODUCTO
    WHERE pl.FK_ID_PRODUCTO = p_id_producto
      AND pl.FK_ID_LOCAL = p_id_local;

    IF producto_existe > 0 THEN
        SELECT
            p.NOMBRE_PRODUCTO,
            pl.VALOR_PRODUCTS_LOCAL,
            p.IMAGEN_URL,
            COALESCE(u.NOMBRE_UNIDAD, '') AS NOMBRE_UNIDAD
        FROM productoslocal pl
        INNER JOIN producto p ON pl.FK_ID_PRODUCTO = p.PK_ID_PRODUCTO
        LEFT JOIN unidad u ON pl.FK_ID_UNIDAD = u.ID_UNIDAD
        WHERE pl.FK_ID_PRODUCTO = p_id_producto
          AND pl.FK_ID_LOCAL = p_id_local
        LIMIT 1;
        SET mensaje = 'Producto encontrado';
        SET resultado = 1;
    ELSE
        SET mensaje = 'Producto no encontrado en este local';
        SET resultado = 0;
        -- Retornar conjunto vacío
        SELECT NULL AS NOMBRE_PRODUCTO, NULL AS VALOR_PRODUCTS_LOCAL,
               NULL AS IMAGEN_URL, NULL AS NOMBRE_UNIDAD
        WHERE 1 = 0;
    END IF;
END//
DELIMITER ;

SELECT 'Migración 035 completada: SP consultar_producto_negocio_seguro corregido' AS resultado;
