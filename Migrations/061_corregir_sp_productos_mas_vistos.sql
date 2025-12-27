-- Migración 061: Corregir SP obtener_productos_mas_vistos
-- El SP usaba p.NOMBRE (no existe) en lugar de p.NOMBRE_PRODUCTO
-- También corrige p.FK_ID_LOCAL que debe ser rpv.FK_ID_LOCAL

DROP PROCEDURE IF EXISTS obtener_productos_mas_vistos;

DELIMITER //
CREATE PROCEDURE obtener_productos_mas_vistos(
    IN p_id_local INT,
    IN p_fecha_inicio DATE,
    IN p_fecha_fin DATE,
    IN p_limite INT
)
BEGIN
    SELECT
        p.PK_ID_PRODUCTO as id_producto,
        p.NOMBRE_PRODUCTO as nombre_producto,
        p.IMAGEN_URL as imagen_url,
        COALESCE(SUM(rpv.VISTAS), 0) as total_vistas
    FROM producto p
    INNER JOIN resumen_producto_vistas rpv ON p.PK_ID_PRODUCTO = rpv.FK_ID_PRODUCTO
        AND rpv.FECHA BETWEEN p_fecha_inicio AND p_fecha_fin
    WHERE rpv.FK_ID_LOCAL = p_id_local
    GROUP BY p.PK_ID_PRODUCTO, p.NOMBRE_PRODUCTO, p.IMAGEN_URL
    HAVING total_vistas > 0
    ORDER BY total_vistas DESC
    LIMIT p_limite;
END//
DELIMITER ;
