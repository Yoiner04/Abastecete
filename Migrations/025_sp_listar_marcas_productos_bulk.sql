-- Migración 025: SP para listar marcas de múltiples productos en una sola consulta
-- Optimización para evitar consultas N+1

DELIMITER //

DROP PROCEDURE IF EXISTS sp_listar_marcas_productos_bulk//

CREATE PROCEDURE sp_listar_marcas_productos_bulk(
    IN p_id_local INT,
    IN p_ids_productos TEXT
)
BEGIN
    SELECT
        pm.PK_ID AS Id,
        pm.FK_ID_LOCAL AS IdLocal,
        pm.FK_ID_PRODUCTO AS IdProducto,
        pm.FK_ID_MARCA AS IdMarca,
        m.NOMBRE AS NombreMarca,
        m.LOGO_URL AS LogoMarca,
        pm.FK_ID_UNIDAD AS IdUnidad,
        u.NOMBRE AS NombreUnidad,
        pm.PRECIO AS Precio,
        pm.STOCK AS Stock,
        pm.DISPONIBLE AS Disponible,
        pm.FECHA_REGISTRO AS FechaRegistro,
        pm.FECHA_ACTUALIZACION AS FechaActualizacion
    FROM producto_marca pm
    INNER JOIN marca m ON pm.FK_ID_MARCA = m.PK_ID_MARCA
    LEFT JOIN unidad u ON pm.FK_ID_UNIDAD = u.PK_ID_UNIDAD
    WHERE pm.FK_ID_LOCAL = p_id_local
      AND FIND_IN_SET(pm.FK_ID_PRODUCTO, p_ids_productos) > 0
    ORDER BY pm.FK_ID_PRODUCTO, pm.PRECIO ASC;
END//

DELIMITER ;
