-- =============================================
-- Migración: 052_actualizar_sps_producto_marca_local.sql
-- Fecha: 2025-12-22
-- Descripción: Actualizar stored procedures para incluir FK_ID_LOCAL
-- =============================================

DELIMITER //

-- =============================================
-- SP: Agregar marca a producto de un local
-- =============================================
DROP PROCEDURE IF EXISTS sp_agregar_marca_producto //
CREATE PROCEDURE sp_agregar_marca_producto(
    IN p_id_local INT,
    IN p_id_producto INT,
    IN p_id_marca INT,
    IN p_precio DECIMAL(12,2),
    IN p_stock INT,
    IN p_disponible TINYINT
)
BEGIN
    INSERT INTO producto_marca (FK_ID_LOCAL, FK_ID_PRODUCTO, FK_ID_MARCA, PRECIO, STOCK, DISPONIBLE)
    VALUES (p_id_local, p_id_producto, p_id_marca, p_precio, COALESCE(p_stock, 0), COALESCE(p_disponible, 1))
    ON DUPLICATE KEY UPDATE
        PRECIO = p_precio,
        STOCK = COALESCE(p_stock, STOCK),
        DISPONIBLE = COALESCE(p_disponible, DISPONIBLE),
        FECHA_ACTUALIZACION = CURRENT_TIMESTAMP;

    SELECT LAST_INSERT_ID() as Id;
END //

-- =============================================
-- SP: Actualizar marca de producto (sin cambios, usa PK_ID)
-- =============================================
DROP PROCEDURE IF EXISTS sp_actualizar_marca_producto //
CREATE PROCEDURE sp_actualizar_marca_producto(
    IN p_id INT,
    IN p_precio DECIMAL(12,2),
    IN p_stock INT,
    IN p_disponible TINYINT
)
BEGIN
    UPDATE producto_marca
    SET PRECIO = p_precio,
        STOCK = COALESCE(p_stock, STOCK),
        DISPONIBLE = COALESCE(p_disponible, DISPONIBLE),
        FECHA_ACTUALIZACION = CURRENT_TIMESTAMP
    WHERE PK_ID = p_id;

    SELECT ROW_COUNT() as FilasAfectadas;
END //

-- =============================================
-- SP: Eliminar marca de producto (sin cambios, usa PK_ID)
-- =============================================
DROP PROCEDURE IF EXISTS sp_eliminar_marca_producto //
CREATE PROCEDURE sp_eliminar_marca_producto(
    IN p_id INT
)
BEGIN
    DELETE FROM producto_marca WHERE PK_ID = p_id;
    SELECT ROW_COUNT() as FilasAfectadas;
END //

-- =============================================
-- SP: Listar marcas de un producto en un local específico
-- =============================================
DROP PROCEDURE IF EXISTS sp_listar_marcas_producto //
CREATE PROCEDURE sp_listar_marcas_producto(
    IN p_id_local INT,
    IN p_id_producto INT
)
BEGIN
    SELECT
        pm.PK_ID as Id,
        pm.FK_ID_LOCAL as IdLocal,
        pm.FK_ID_PRODUCTO as IdProducto,
        pm.FK_ID_MARCA as IdMarca,
        m.NOMBRE as NombreMarca,
        m.LOGO_URL as LogoMarca,
        pm.PRECIO as Precio,
        pm.STOCK as Stock,
        pm.DISPONIBLE as Disponible,
        pm.FECHA_REGISTRO as FechaRegistro,
        pm.FECHA_ACTUALIZACION as FechaActualizacion
    FROM producto_marca pm
    INNER JOIN marca m ON pm.FK_ID_MARCA = m.PK_ID_MARCA
    WHERE pm.FK_ID_LOCAL = p_id_local
      AND pm.FK_ID_PRODUCTO = p_id_producto
    ORDER BY pm.PRECIO ASC;
END //

-- =============================================
-- SP: Obtener precio mínimo y máximo de un producto en un local
-- =============================================
DROP PROCEDURE IF EXISTS sp_obtener_rango_precios_producto //
CREATE PROCEDURE sp_obtener_rango_precios_producto(
    IN p_id_local INT,
    IN p_id_producto INT
)
BEGIN
    SELECT
        MIN(PRECIO) as PrecioMinimo,
        MAX(PRECIO) as PrecioMaximo,
        COUNT(*) as CantidadMarcas
    FROM producto_marca
    WHERE FK_ID_LOCAL = p_id_local
      AND FK_ID_PRODUCTO = p_id_producto
      AND DISPONIBLE = 1;
END //

-- =============================================
-- SP: Consultar productos de un local con sus marcas y precios
-- =============================================
DROP PROCEDURE IF EXISTS sp_consultar_productos_local_con_marcas //
CREATE PROCEDURE sp_consultar_productos_local_con_marcas(
    IN p_id_local INT
)
BEGIN
    SELECT
        p.PK_ID_PRODUCTO as Id,
        p.NOMBRE as Nombre,
        p.DESCRIPCION as Descripcion,
        p.IMAGEN as ImagenUrl,
        p.CLOUDINARY_PUBLIC_ID as CloudinaryPublicId,
        p.SKU as SKU,
        p.FK_ID_SUB_CATEGORIA as IdSubCategoria,
        sc.NOMBRE as NombreSubCategoria,
        sc.FK_ID_CATEGORIA as Categoria,
        c.NOMBRE as NombreCategoria,
        u.PK_ID_UNIDAD as IdUnidad,
        u.NOMBRE as NombreUnidad,
        tu.PK_ID_TIPO_UNIDAD as IdTipoUnidad,
        tu.NOMBRE as NombreTipoUnidad,
        -- Datos de marcas del local específico
        (SELECT MIN(pm.PRECIO) FROM producto_marca pm WHERE pm.FK_ID_LOCAL = p_id_local AND pm.FK_ID_PRODUCTO = p.PK_ID_PRODUCTO AND pm.DISPONIBLE = 1) as PrecioMinimo,
        (SELECT MAX(pm.PRECIO) FROM producto_marca pm WHERE pm.FK_ID_LOCAL = p_id_local AND pm.FK_ID_PRODUCTO = p.PK_ID_PRODUCTO AND pm.DISPONIBLE = 1) as PrecioMaximo,
        (SELECT COUNT(*) FROM producto_marca pm WHERE pm.FK_ID_LOCAL = p_id_local AND pm.FK_ID_PRODUCTO = p.PK_ID_PRODUCTO AND pm.DISPONIBLE = 1) as CantidadMarcas,
        -- Para compatibilidad: mantener el precio original
        pl.VALOR_PRODUCTS_LOCAL as Precio,
        p.FK_ID_MARCA as IdMarca,
        m.NOMBRE as NombreMarca
    FROM productoslocal pl
    INNER JOIN producto p ON pl.FK_ID_PRODUCTO = p.PK_ID_PRODUCTO
    INNER JOIN sub_categoria sc ON p.FK_ID_SUB_CATEGORIA = sc.PK_ID_SUB_CATEGORIA
    INNER JOIN categoria c ON sc.FK_ID_CATEGORIA = c.PK_ID_CATEGORIA
    LEFT JOIN unidad u ON p.FK_ID_UNIDAD = u.PK_ID_UNIDAD
    LEFT JOIN tipo_unidad tu ON u.FK_ID_TIPO_UNIDAD = tu.PK_ID_TIPO_UNIDAD
    LEFT JOIN marca m ON p.FK_ID_MARCA = m.PK_ID_MARCA
    WHERE pl.FK_ID_LOCAL = p_id_local
    ORDER BY p.NOMBRE;
END //

-- =============================================
-- SP: Verificar si un producto en un local tiene múltiples marcas
-- =============================================
DROP PROCEDURE IF EXISTS sp_producto_tiene_multiples_marcas //
CREATE PROCEDURE sp_producto_tiene_multiples_marcas(
    IN p_id_local INT,
    IN p_id_producto INT
)
BEGIN
    SELECT
        COUNT(*) as CantidadMarcas,
        (COUNT(*) > 1) as TieneMultiplesMarcas
    FROM producto_marca
    WHERE FK_ID_LOCAL = p_id_local
      AND FK_ID_PRODUCTO = p_id_producto;
END //

-- =============================================
-- SP: Obtener detalle de producto con todas sus marcas en un local
-- =============================================
DROP PROCEDURE IF EXISTS sp_obtener_producto_detalle_marcas //
CREATE PROCEDURE sp_obtener_producto_detalle_marcas(
    IN p_id_local INT,
    IN p_id_producto INT
)
BEGIN
    -- Primero los datos del producto
    SELECT
        p.PK_ID_PRODUCTO as Id,
        p.NOMBRE as Nombre,
        p.DESCRIPCION as Descripcion,
        p.IMAGEN as ImagenUrl,
        p.CLOUDINARY_PUBLIC_ID as CloudinaryPublicId,
        p.SKU as SKU,
        p.FK_ID_SUB_CATEGORIA as IdSubCategoria,
        sc.NOMBRE as NombreSubCategoria,
        sc.FK_ID_CATEGORIA as Categoria,
        c.NOMBRE as NombreCategoria,
        u.PK_ID_UNIDAD as IdUnidad,
        u.NOMBRE as NombreUnidad,
        tu.PK_ID_TIPO_UNIDAD as IdTipoUnidad,
        tu.NOMBRE as NombreTipoUnidad,
        p_id_local as IdLocal
    FROM producto p
    INNER JOIN sub_categoria sc ON p.FK_ID_SUB_CATEGORIA = sc.PK_ID_SUB_CATEGORIA
    INNER JOIN categoria c ON sc.FK_ID_CATEGORIA = c.PK_ID_CATEGORIA
    LEFT JOIN unidad u ON p.FK_ID_UNIDAD = u.PK_ID_UNIDAD
    LEFT JOIN tipo_unidad tu ON u.FK_ID_TIPO_UNIDAD = tu.PK_ID_TIPO_UNIDAD
    WHERE p.PK_ID_PRODUCTO = p_id_producto;

    -- Luego las marcas disponibles en este local
    SELECT
        pm.PK_ID as Id,
        pm.FK_ID_MARCA as IdMarca,
        m.NOMBRE as NombreMarca,
        m.LOGO_URL as LogoMarca,
        pm.PRECIO as Precio,
        pm.STOCK as Stock,
        pm.DISPONIBLE as Disponible
    FROM producto_marca pm
    INNER JOIN marca m ON pm.FK_ID_MARCA = m.PK_ID_MARCA
    WHERE pm.FK_ID_LOCAL = p_id_local
      AND pm.FK_ID_PRODUCTO = p_id_producto
    ORDER BY pm.PRECIO ASC;
END //

-- =============================================
-- SP: Listar todas las marcas disponibles (para selector)
-- =============================================
DROP PROCEDURE IF EXISTS sp_listar_todas_marcas //
CREATE PROCEDURE sp_listar_todas_marcas()
BEGIN
    SELECT
        PK_ID_MARCA as Id,
        NOMBRE as Nombre,
        DESCRIPCION as Descripcion,
        LOGO_URL as LogoUrl,
        CLOUDINARY_PUBLIC_ID as CloudinaryPublicId,
        ACTIVA as Activa
    FROM marca
    WHERE ACTIVA = 1
    ORDER BY NOMBRE;
END //

DELIMITER ;

SELECT 'Migración 052 completada - SPs actualizados con FK_ID_LOCAL' AS resultado;
