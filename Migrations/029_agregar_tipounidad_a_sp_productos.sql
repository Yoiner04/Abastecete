-- =============================================
-- Migracion: 029_agregar_tipounidad_a_sp_productos.sql
-- Fecha: 2025-12-20
-- Descripcion: Agregar FK_ID_TIPOUNIDAD a los stored procedures de productos
-- =============================================

-- Eliminar SPs para recrearlos
DROP PROCEDURE IF EXISTS `crear_producto`;
DROP PROCEDURE IF EXISTS `editar_producto`;
DROP PROCEDURE IF EXISTS `consultar_producto`;
DROP PROCEDURE IF EXISTS `consultar_productos_todos`;
DROP PROCEDURE IF EXISTS `consultar_producto_por_id`;
DROP PROCEDURE IF EXISTS `consultar_productos_subcategoria`;
DROP PROCEDURE IF EXISTS `buscar_productos`;

DELIMITER //

-- =============================================
-- SP: consultar_producto (con tipo unidad)
-- =============================================
CREATE PROCEDURE `consultar_producto`()
BEGIN
    SELECT
        p.PK_ID_PRODUCTO,
        p.FK_ID_SUB_CATEGORIA,
        p.NOMBRE_PRODUCTO,
        p.IMAGEN_URL,
        p.FK_ID_MARCA,
        p.DESCRIPCION,
        p.SKU,
        p.CLOUDINARY_PUBLIC_ID,
        p.FK_ID_TIPOUNIDAD,
        m.NOMBRE AS NOMBRE_MARCA,
        tu.NOMBRE_TIPOUNIDAD
    FROM producto p
    LEFT JOIN marca m ON p.FK_ID_MARCA = m.PK_ID_MARCA
    LEFT JOIN tipo_unidad tu ON p.FK_ID_TIPOUNIDAD = tu.ID_TIPOUNIDAD;
END//

-- =============================================
-- SP: consultar_productos_todos (con tipo unidad)
-- =============================================
CREATE PROCEDURE `consultar_productos_todos`()
BEGIN
    SELECT
        p.PK_ID_PRODUCTO,
        p.FK_ID_SUB_CATEGORIA,
        p.NOMBRE_PRODUCTO,
        p.IMAGEN_URL,
        p.FK_ID_MARCA,
        p.DESCRIPCION,
        p.SKU,
        p.CLOUDINARY_PUBLIC_ID,
        p.FK_ID_TIPOUNIDAD,
        m.NOMBRE AS NOMBRE_MARCA,
        tu.NOMBRE_TIPOUNIDAD,
        sc.NOMBRE_SUB_CATEGORIA,
        c.PK_ID_CATEGORIA,
        c.NOMBRE_CATEGORIA
    FROM producto p
    LEFT JOIN marca m ON p.FK_ID_MARCA = m.PK_ID_MARCA
    LEFT JOIN tipo_unidad tu ON p.FK_ID_TIPOUNIDAD = tu.ID_TIPOUNIDAD
    LEFT JOIN sub_categoria sc ON p.FK_ID_SUB_CATEGORIA = sc.PK_ID_SUB_CATEGORIA
    LEFT JOIN categoria c ON sc.FK_ID_CATEGORIA = c.PK_ID_CATEGORIA
    ORDER BY c.NOMBRE_CATEGORIA, sc.NOMBRE_SUB_CATEGORIA, p.NOMBRE_PRODUCTO;
END//

-- =============================================
-- SP: consultar_producto_por_id (con tipo unidad)
-- =============================================
CREATE PROCEDURE `consultar_producto_por_id`(
    IN `p_id` INT
)
BEGIN
    SELECT
        p.PK_ID_PRODUCTO,
        p.FK_ID_SUB_CATEGORIA,
        p.NOMBRE_PRODUCTO,
        p.IMAGEN_URL,
        p.FK_ID_MARCA,
        p.DESCRIPCION,
        p.SKU,
        p.CLOUDINARY_PUBLIC_ID,
        p.FK_ID_TIPOUNIDAD,
        m.NOMBRE AS NOMBRE_MARCA,
        tu.NOMBRE_TIPOUNIDAD,
        sc.NOMBRE_SUB_CATEGORIA,
        c.PK_ID_CATEGORIA,
        c.NOMBRE_CATEGORIA
    FROM producto p
    LEFT JOIN marca m ON p.FK_ID_MARCA = m.PK_ID_MARCA
    LEFT JOIN tipo_unidad tu ON p.FK_ID_TIPOUNIDAD = tu.ID_TIPOUNIDAD
    LEFT JOIN sub_categoria sc ON p.FK_ID_SUB_CATEGORIA = sc.PK_ID_SUB_CATEGORIA
    LEFT JOIN categoria c ON sc.FK_ID_CATEGORIA = c.PK_ID_CATEGORIA
    WHERE p.PK_ID_PRODUCTO = p_id;
END//

-- =============================================
-- SP: consultar_productos_subcategoria (con tipo unidad)
-- =============================================
CREATE PROCEDURE `consultar_productos_subcategoria`(
    IN `id_subcategoria` INT
)
BEGIN
    SELECT
        p.PK_ID_PRODUCTO,
        p.FK_ID_SUB_CATEGORIA,
        p.NOMBRE_PRODUCTO,
        p.IMAGEN_URL,
        p.FK_ID_MARCA,
        p.DESCRIPCION,
        p.SKU,
        p.CLOUDINARY_PUBLIC_ID,
        p.FK_ID_TIPOUNIDAD,
        m.NOMBRE AS NOMBRE_MARCA,
        tu.NOMBRE_TIPOUNIDAD
    FROM producto p
    LEFT JOIN marca m ON p.FK_ID_MARCA = m.PK_ID_MARCA
    LEFT JOIN tipo_unidad tu ON p.FK_ID_TIPOUNIDAD = tu.ID_TIPOUNIDAD
    WHERE p.FK_ID_SUB_CATEGORIA = id_subcategoria;
END//

-- =============================================
-- SP: crear_producto (con tipo unidad)
-- =============================================
CREATE PROCEDURE `crear_producto`(
    IN `p_fk_id_sub_categoria` INT,
    IN `p_nombre_producto` VARCHAR(100),
    IN `p_imagen_url` VARCHAR(500),
    IN `p_fk_id_marca` INT,
    IN `p_descripcion` TEXT,
    IN `p_sku` VARCHAR(50),
    IN `p_cloudinary_public_id` VARCHAR(255),
    IN `p_fk_id_tipounidad` INT
)
BEGIN
    DECLARE sub_categoria_existe INT;
    DECLARE marca_id INT;

    -- Verificar si la subcategoria existe
    SELECT COUNT(*) INTO sub_categoria_existe
    FROM sub_categoria
    WHERE PK_ID_SUB_CATEGORIA = p_fk_id_sub_categoria;

    -- Si no se proporciona marca, usar la marca por defecto (Sin Marca)
    SET marca_id = IFNULL(p_fk_id_marca, 1);

    IF sub_categoria_existe > 0 THEN
        -- Insertar el nuevo producto
        INSERT INTO producto (
            FK_ID_SUB_CATEGORIA,
            NOMBRE_PRODUCTO,
            IMAGEN_URL,
            FK_ID_MARCA,
            DESCRIPCION,
            SKU,
            CLOUDINARY_PUBLIC_ID,
            FK_ID_TIPOUNIDAD
        )
        VALUES (
            p_fk_id_sub_categoria,
            p_nombre_producto,
            p_imagen_url,
            marca_id,
            p_descripcion,
            NULLIF(p_sku, ''),
            p_cloudinary_public_id,
            NULLIF(p_fk_id_tipounidad, 0)
        );

        SELECT LAST_INSERT_ID() AS id_producto, 'Producto creado exitosamente' AS mensaje;
    ELSE
        SELECT 0 AS id_producto, 'Subcategoria no encontrada' AS mensaje;
    END IF;
END//

-- =============================================
-- SP: editar_producto (con tipo unidad)
-- =============================================
CREATE PROCEDURE `editar_producto`(
    IN `p_id_producto` INT,
    IN `p_fk_id_sub_categoria` INT,
    IN `p_nombre_producto` VARCHAR(100),
    IN `p_imagen_url` VARCHAR(500),
    IN `p_fk_id_marca` INT,
    IN `p_descripcion` TEXT,
    IN `p_sku` VARCHAR(50),
    IN `p_cloudinary_public_id` VARCHAR(255),
    IN `p_fk_id_tipounidad` INT
)
BEGIN
    DECLARE sub_categoria_existe INT;
    DECLARE marca_id INT;

    -- Verificar si el producto existe
    IF EXISTS (SELECT 1 FROM producto WHERE PK_ID_PRODUCTO = p_id_producto) THEN
        -- Verificar si la subcategoria existe
        SELECT COUNT(*) INTO sub_categoria_existe
        FROM sub_categoria
        WHERE PK_ID_SUB_CATEGORIA = p_fk_id_sub_categoria;

        -- Si no se proporciona marca, usar la marca por defecto (Sin Marca)
        SET marca_id = IFNULL(p_fk_id_marca, 1);

        IF sub_categoria_existe > 0 THEN
            -- Actualizar el producto
            UPDATE producto
            SET FK_ID_SUB_CATEGORIA = p_fk_id_sub_categoria,
                NOMBRE_PRODUCTO = p_nombre_producto,
                IMAGEN_URL = p_imagen_url,
                FK_ID_MARCA = marca_id,
                DESCRIPCION = p_descripcion,
                SKU = NULLIF(p_sku, ''),
                CLOUDINARY_PUBLIC_ID = p_cloudinary_public_id,
                FK_ID_TIPOUNIDAD = NULLIF(p_fk_id_tipounidad, 0)
            WHERE PK_ID_PRODUCTO = p_id_producto;

            SELECT 1 AS resultado, 'Producto actualizado exitosamente' AS mensaje;
        ELSE
            SELECT 0 AS resultado, 'Subcategoria no encontrada' AS mensaje;
        END IF;
    ELSE
        SELECT 0 AS resultado, 'Producto no encontrado' AS mensaje;
    END IF;
END//

-- =============================================
-- SP: buscar_productos (con tipo unidad)
-- =============================================
CREATE PROCEDURE `buscar_productos`(
    IN `p_termino` VARCHAR(100),
    IN `p_id_categoria` INT,
    IN `p_id_subcategoria` INT,
    IN `p_id_marca` INT
)
BEGIN
    SELECT
        p.PK_ID_PRODUCTO,
        p.FK_ID_SUB_CATEGORIA,
        p.NOMBRE_PRODUCTO,
        p.IMAGEN_URL,
        p.FK_ID_MARCA,
        p.DESCRIPCION,
        p.SKU,
        p.CLOUDINARY_PUBLIC_ID,
        p.FK_ID_TIPOUNIDAD,
        m.NOMBRE AS NOMBRE_MARCA,
        tu.NOMBRE_TIPOUNIDAD,
        sc.NOMBRE_SUB_CATEGORIA,
        c.PK_ID_CATEGORIA,
        c.NOMBRE_CATEGORIA
    FROM producto p
    LEFT JOIN marca m ON p.FK_ID_MARCA = m.PK_ID_MARCA
    LEFT JOIN tipo_unidad tu ON p.FK_ID_TIPOUNIDAD = tu.ID_TIPOUNIDAD
    LEFT JOIN sub_categoria sc ON p.FK_ID_SUB_CATEGORIA = sc.PK_ID_SUB_CATEGORIA
    LEFT JOIN categoria c ON sc.FK_ID_CATEGORIA = c.PK_ID_CATEGORIA
    WHERE
        (p_termino IS NULL OR p_termino = '' OR
         p.NOMBRE_PRODUCTO LIKE CONCAT('%', p_termino, '%') OR
         p.SKU LIKE CONCAT('%', p_termino, '%'))
        AND (p_id_categoria IS NULL OR p_id_categoria = 0 OR c.PK_ID_CATEGORIA = p_id_categoria)
        AND (p_id_subcategoria IS NULL OR p_id_subcategoria = 0 OR p.FK_ID_SUB_CATEGORIA = p_id_subcategoria)
        AND (p_id_marca IS NULL OR p_id_marca = 0 OR p.FK_ID_MARCA = p_id_marca)
    ORDER BY p.NOMBRE_PRODUCTO;
END//

DELIMITER ;

SELECT 'Migracion 029 completada - SPs de producto actualizados con FK_ID_TIPOUNIDAD' AS resultado;
