-- =====================================================
-- Migración: SPs para presentaciones de productos
-- Fecha: 2025-12-30
-- =====================================================

-- =====================================================
-- 1. SP productos_local con tipo de unidad
-- Descripción: Igual que productos_local pero incluye
--              el ID_TIPO_UNIDAD para filtrar unidades
-- =====================================================

DROP PROCEDURE IF EXISTS sp_productos_local_con_tipo_unidad;

DELIMITER //
CREATE PROCEDURE sp_productos_local_con_tipo_unidad(
    IN p_id_local INT
)
BEGIN
    SELECT
        l.PK_ID_LOCAL,
        l.NOMBRE_LOCAL,
        p.PK_ID_PRODUCTO,
        p.NOMBRE_PRODUCTO,
        p.IMAGEN_URL,
        p.FK_ID_SUB_CATEGORIA,
        c.PK_ID_CATEGORIA,
        GROUP_CONCAT(pl.VALOR_PRODUCTS_LOCAL SEPARATOR ', ') AS PRECIOS,
        GROUP_CONCAT(u.NOMBRE_UNIDAD SEPARATOR ', ') AS UNIDADES,
        p.FK_ID_TIPOUNIDAD AS ID_TIPO_UNIDAD
    FROM `local` l
    INNER JOIN productoslocal pl ON pl.FK_ID_LOCAL = l.PK_ID_LOCAL
    INNER JOIN producto p ON pl.FK_ID_PRODUCTO = p.PK_ID_PRODUCTO
    INNER JOIN unidad u ON pl.FK_ID_UNIDAD = u.ID_UNIDAD
    INNER JOIN sub_categoria sc ON p.FK_ID_SUB_CATEGORIA = sc.PK_ID_SUB_CATEGORIA
    INNER JOIN categoria c ON sc.FK_ID_CATEGORIA = c.PK_ID_CATEGORIA
    WHERE l.PK_ID_LOCAL = p_id_local
    GROUP BY l.PK_ID_LOCAL, l.NOMBRE_LOCAL, p.PK_ID_PRODUCTO, p.NOMBRE_PRODUCTO,
             p.IMAGEN_URL, p.FK_ID_SUB_CATEGORIA, c.PK_ID_CATEGORIA, p.FK_ID_TIPOUNIDAD
    ORDER BY p.NOMBRE_PRODUCTO ASC;
END//
DELIMITER ;

-- =====================================================
-- 2. SP actualizar precio de producto local
-- Descripción: Actualiza el precio base en productoslocal
-- =====================================================

DROP PROCEDURE IF EXISTS sp_actualizar_precio_producto_local;

DELIMITER //
CREATE PROCEDURE sp_actualizar_precio_producto_local(
    IN p_id_local INT,
    IN p_id_producto INT,
    IN p_nuevo_precio INT
)
BEGIN
    DECLARE v_pl_id INT DEFAULT 0;

    SELECT PK_ID_PRODUCTS_LOCAL INTO v_pl_id
    FROM productoslocal
    WHERE FK_ID_LOCAL = p_id_local
      AND FK_ID_PRODUCTO = p_id_producto
    LIMIT 1;

    IF v_pl_id > 0 THEN
        UPDATE productoslocal
        SET VALOR_PRODUCTS_LOCAL = p_nuevo_precio
        WHERE PK_ID_PRODUCTS_LOCAL = v_pl_id;

        SELECT v_pl_id as Id, 'Precio actualizado correctamente' as Mensaje, 1 as Exito;
    ELSE
        SELECT 0 as Id, 'Producto no encontrado en este local' as Mensaje, 0 as Exito;
    END IF;
END//
DELIMITER ;

-- =====================================================
SELECT 'Migracion completada: SPs creados' as Mensaje;
-- =====================================================
