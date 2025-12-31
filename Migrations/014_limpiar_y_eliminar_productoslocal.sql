-- =====================================================
-- Migración 014: Limpiar datos y eliminar tabla productoslocal
-- Fecha: 2025-12-31
--
-- ACCIÓN: Eliminar tabla productoslocal (legacy) y limpiar producto_marca
-- RESULTADO: Solo queda producto_marca como tabla de presentaciones
-- =====================================================

-- =====================================================
-- 1. Limpiar todos los registros de producto_marca
-- =====================================================
DELETE FROM producto_marca;

-- Resetear auto_increment
ALTER TABLE producto_marca AUTO_INCREMENT = 1;

-- =====================================================
-- 2. Eliminar tabla productoslocal (ya no se usa)
-- =====================================================
DROP TABLE IF EXISTS productoslocal;

-- =====================================================
-- 3. Actualizar SP agregar_productos_local
--    Ya no inserta en productoslocal
-- =====================================================

DROP PROCEDURE IF EXISTS agregar_productos_local;

DELIMITER //
CREATE PROCEDURE agregar_productos_local(
    IN producto_id INT,
    IN medida INT,
    IN valor INT,
    IN local_id INT,
    IN marca_id INT
)
BEGIN
    DECLARE v_total INT DEFAULT 0;
    DECLARE v_max INT DEFAULT 0;
    DECLARE v_marca INT DEFAULT 1;
    DECLARE v_existe_producto INT DEFAULT 0;

    -- Si no se pasa marca, usar 1 (Sin Marca)
    SET v_marca = COALESCE(NULLIF(marca_id, 0), 1);

    -- Cuenta cuántos productos DISTINTOS ya tiene este local
    SELECT COUNT(DISTINCT FK_ID_PRODUCTO)
    INTO v_total
    FROM producto_marca
    WHERE FK_ID_LOCAL = local_id;

    -- Lee el límite de productos de la membresía
    SELECT COALESCE(tm.CANTIDAD_PRODUCTOS, 0)
    INTO v_max
    FROM `local` l
    LEFT JOIN suscripcion s ON l.FK_ID_SUSCRIPCION_ACTIVA = s.PK_ID_SUSCRIPCION AND s.ESTADO = 1
    LEFT JOIN tipo_membresia tm ON s.FK_ID_TIPO_MEMBRESIA = tm.PK_ID_TIPO_MEMBRESIA
    WHERE l.PK_ID_LOCAL = local_id;

    -- Verificar si ya existe este producto (para no contar como nuevo)
    SELECT COUNT(*) INTO v_existe_producto
    FROM producto_marca
    WHERE FK_ID_LOCAL = local_id AND FK_ID_PRODUCTO = producto_id;

    -- Inserta sólo si no supera el límite (0 = sin límite) o si el producto ya existe
    IF v_max = 0 OR v_total < v_max OR v_existe_producto > 0 THEN
        -- Insertar o actualizar en producto_marca
        INSERT INTO producto_marca (FK_ID_LOCAL, FK_ID_PRODUCTO, FK_ID_MARCA, FK_ID_UNIDAD, PRECIO, STOCK, DISPONIBLE)
        VALUES (local_id, producto_id, v_marca, NULLIF(medida, 0), valor, 0, 1)
        ON DUPLICATE KEY UPDATE
            PRECIO = valor,
            DISPONIBLE = 1,
            FECHA_ACTUALIZACION = CURRENT_TIMESTAMP;

        SELECT 1 AS resultado, 'Producto agregado correctamente' AS mensaje;
    ELSE
        SELECT 0 AS resultado, 'Límite de productos alcanzado' AS mensaje;
    END IF;
END//
DELIMITER ;

-- =====================================================
-- 4. Actualizar SP para consultar productos del local
-- =====================================================

DROP PROCEDURE IF EXISTS sp_productos_local_con_tipo_unidad;

DELIMITER //
CREATE PROCEDURE sp_productos_local_con_tipo_unidad(
    IN p_id_local INT
)
BEGIN
    SELECT
        p_id_local AS PK_ID_LOCAL,
        l.NOMBRE_LOCAL,
        p.PK_ID_PRODUCTO,
        p.NOMBRE_PRODUCTO,
        p.IMAGEN_URL,
        p.FK_ID_SUB_CATEGORIA,
        c.PK_ID_CATEGORIA,
        GROUP_CONCAT(DISTINCT pm.PRECIO ORDER BY pm.PRECIO SEPARATOR ', ') AS PRECIOS,
        GROUP_CONCAT(DISTINCT COALESCE(u.NOMBRE_UNIDAD, 'Unidad') ORDER BY u.NOMBRE_UNIDAD SEPARATOR ', ') AS UNIDADES,
        p.FK_ID_TIPOUNIDAD AS ID_TIPO_UNIDAD
    FROM producto_marca pm
    INNER JOIN `local` l ON l.PK_ID_LOCAL = p_id_local
    INNER JOIN producto p ON pm.FK_ID_PRODUCTO = p.PK_ID_PRODUCTO
    INNER JOIN sub_categoria sc ON p.FK_ID_SUB_CATEGORIA = sc.PK_ID_SUB_CATEGORIA
    INNER JOIN categoria c ON sc.FK_ID_CATEGORIA = c.PK_ID_CATEGORIA
    LEFT JOIN unidad u ON pm.FK_ID_UNIDAD = u.ID_UNIDAD
    WHERE pm.FK_ID_LOCAL = p_id_local
      AND pm.DISPONIBLE = 1
    GROUP BY p.PK_ID_PRODUCTO, p.NOMBRE_PRODUCTO, p.IMAGEN_URL,
             p.FK_ID_SUB_CATEGORIA, c.PK_ID_CATEGORIA, p.FK_ID_TIPOUNIDAD, l.NOMBRE_LOCAL
    ORDER BY p.NOMBRE_PRODUCTO ASC;
END//
DELIMITER ;

-- =====================================================
-- 5. SP para eliminar producto del local
-- =====================================================

DROP PROCEDURE IF EXISTS sp_eliminar_producto_local;

DELIMITER //
CREATE PROCEDURE sp_eliminar_producto_local(
    IN p_id_local INT,
    IN p_id_producto INT
)
BEGIN
    DELETE FROM producto_marca
    WHERE FK_ID_LOCAL = p_id_local AND FK_ID_PRODUCTO = p_id_producto;

    SELECT ROW_COUNT() AS FilasAfectadas, 'Producto eliminado correctamente' AS Mensaje;
END//
DELIMITER ;

-- =====================================================
-- 6. SP para obtener presentaciones de un producto
-- =====================================================

DROP PROCEDURE IF EXISTS sp_obtener_presentaciones_producto;

DELIMITER //
CREATE PROCEDURE sp_obtener_presentaciones_producto(
    IN p_id_local INT,
    IN p_id_producto INT
)
BEGIN
    SELECT
        pm.PK_ID AS Id,
        pm.FK_ID_PRODUCTO AS IdProducto,
        pm.FK_ID_MARCA AS IdMarca,
        m.NOMBRE_MARCA AS NombreMarca,
        m.LOGO_MARCA AS LogoMarca,
        pm.FK_ID_UNIDAD AS IdUnidad,
        u.NOMBRE_UNIDAD AS NombreUnidad,
        pm.PRECIO AS Precio,
        pm.STOCK AS Stock,
        pm.DISPONIBLE AS Disponible
    FROM producto_marca pm
    INNER JOIN marca m ON pm.FK_ID_MARCA = m.PK_ID_MARCA
    LEFT JOIN unidad u ON pm.FK_ID_UNIDAD = u.ID_UNIDAD
    WHERE pm.FK_ID_LOCAL = p_id_local
      AND pm.FK_ID_PRODUCTO = p_id_producto
    ORDER BY m.NOMBRE_MARCA, u.NOMBRE_UNIDAD;
END//
DELIMITER ;

-- =====================================================
-- 7. Actualizar SP productos_local (usado por ofertas flash)
-- =====================================================

DROP PROCEDURE IF EXISTS productos_local;

DELIMITER //
CREATE PROCEDURE productos_local(
    IN localid INT
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
        GROUP_CONCAT(DISTINCT pm.PRECIO ORDER BY pm.PRECIO SEPARATOR ', ') AS PRECIOS,
        GROUP_CONCAT(DISTINCT COALESCE(u.NOMBRE_UNIDAD, 'Unidad') ORDER BY u.NOMBRE_UNIDAD SEPARATOR ', ') AS UNIDADES
    FROM producto_marca pm
    INNER JOIN `local` l ON l.PK_ID_LOCAL = localid
    INNER JOIN producto p ON pm.FK_ID_PRODUCTO = p.PK_ID_PRODUCTO
    INNER JOIN sub_categoria sc ON p.FK_ID_SUB_CATEGORIA = sc.PK_ID_SUB_CATEGORIA
    INNER JOIN categoria c ON sc.FK_ID_CATEGORIA = c.PK_ID_CATEGORIA
    LEFT JOIN unidad u ON pm.FK_ID_UNIDAD = u.ID_UNIDAD
    WHERE pm.FK_ID_LOCAL = localid
      AND pm.DISPONIBLE = 1
    GROUP BY l.PK_ID_LOCAL, l.NOMBRE_LOCAL, p.PK_ID_PRODUCTO, p.NOMBRE_PRODUCTO,
             p.IMAGEN_URL, p.FK_ID_SUB_CATEGORIA, c.PK_ID_CATEGORIA
    ORDER BY p.NOMBRE_PRODUCTO ASC;
END//
DELIMITER ;

-- =====================================================
-- 8. Actualizar SP obtener_limite_productos_local
-- =====================================================

DROP PROCEDURE IF EXISTS obtener_limite_productos_local;

DELIMITER //
CREATE PROCEDURE obtener_limite_productos_local(
    IN p_id_local INT
)
BEGIN
    DECLARE limite_base INT DEFAULT 0;
    DECLARE addons_extra INT DEFAULT 0;
    DECLARE productos_actuales INT DEFAULT 0;

    -- Límite base de la membresía activa
    SELECT COALESCE(CAST(tm.CANTIDAD_PRODUCTOS AS UNSIGNED), 0) INTO limite_base
    FROM suscripcion s
    INNER JOIN tipo_membresia tm ON s.FK_ID_TIPO_MEMBRESIA = tm.PK_ID_TIPO_MEMBRESIA
    WHERE s.FK_ID_LOCAL = p_id_local AND s.ESTADO = 1
    ORDER BY s.FECHA_INICIO DESC
    LIMIT 1;

    -- Addons comprados (tipo PRODUCTOS)
    SELECT COALESCE(SUM(at.CANTIDAD * al.CANTIDAD_COMPRADA), 0) INTO addons_extra
    FROM addon_local al
    INNER JOIN addon_tipo at ON al.FK_ID_ADDON = at.PK_ID_ADDON
    WHERE al.FK_ID_LOCAL = p_id_local
        AND at.TIPO_LIMITE = 'PRODUCTOS'
        AND al.ESTADO = 1
        AND (al.FECHA_EXPIRACION IS NULL OR al.FECHA_EXPIRACION > NOW());

    -- Contar productos actuales desde producto_marca
    SELECT COUNT(DISTINCT FK_ID_PRODUCTO) INTO productos_actuales
    FROM producto_marca
    WHERE FK_ID_LOCAL = p_id_local;

    -- Si límite base es 0, es ilimitado
    IF limite_base = 0 THEN
        SELECT 0 as limite_base, 0 as addons_extra, 0 as limite_total, 1 as es_ilimitado, productos_actuales;
    ELSE
        SELECT limite_base, addons_extra, (limite_base + addons_extra) as limite_total, 0 as es_ilimitado, productos_actuales;
    END IF;
END//
DELIMITER ;

-- =====================================================
-- 9. SP para actualizar precio de producto
-- =====================================================

DROP PROCEDURE IF EXISTS sp_actualizar_precio_producto_local;

DELIMITER //
CREATE PROCEDURE sp_actualizar_precio_producto_local(
    IN p_id_local INT,
    IN p_id_producto INT,
    IN p_nuevo_precio INT
)
BEGIN
    -- Actualizar todos los precios de las presentaciones de este producto
    UPDATE producto_marca
    SET PRECIO = p_nuevo_precio,
        FECHA_ACTUALIZACION = CURRENT_TIMESTAMP
    WHERE FK_ID_LOCAL = p_id_local
      AND FK_ID_PRODUCTO = p_id_producto;

    IF ROW_COUNT() > 0 THEN
        SELECT p_id_producto as Id, 'Precio actualizado correctamente' as Mensaje, 1 as Exito;
    ELSE
        SELECT 0 as Id, 'Producto no encontrado' as Mensaje, 0 as Exito;
    END IF;
END//
DELIMITER ;

-- =====================================================
-- 10. SP buscar_productos (buscador)
-- =====================================================

DROP PROCEDURE IF EXISTS buscar_productos;

DELIMITER //
CREATE PROCEDURE buscar_productos(
    IN busqueda VARCHAR(255)
)
BEGIN
    SELECT DISTINCT
        p.*,
        pm.PRECIO,
        l.PK_ID_LOCAL,
        l.NOMBRE_LOCAL
    FROM producto p
    INNER JOIN producto_marca pm ON pm.FK_ID_PRODUCTO = p.PK_ID_PRODUCTO
    INNER JOIN `local` l ON pm.FK_ID_LOCAL = l.PK_ID_LOCAL
    WHERE p.NOMBRE_PRODUCTO LIKE CONCAT('%', busqueda, '%')
      AND pm.DISPONIBLE = 1;
END//
DELIMITER ;

-- =====================================================
-- 11. SP consultar_producto_negocio
-- =====================================================

DROP PROCEDURE IF EXISTS consultar_producto_negocio;

DELIMITER //
CREATE PROCEDURE consultar_producto_negocio(
    IN idproducto INT,
    IN idlocal INT
)
BEGIN
    SELECT
        p.NOMBRE_PRODUCTO,
        pm.PRECIO AS VALOR_PRODUCTS_LOCAL,
        p.IMAGEN_URL,
        COALESCE(u.NOMBRE_UNIDAD, 'Unidad') AS NOMBRE_UNIDAD
    FROM producto p
    INNER JOIN producto_marca pm ON pm.FK_ID_PRODUCTO = p.PK_ID_PRODUCTO
    LEFT JOIN unidad u ON pm.FK_ID_UNIDAD = u.ID_UNIDAD
    WHERE pm.FK_ID_PRODUCTO = idproducto
      AND pm.FK_ID_LOCAL = idlocal
    LIMIT 1;
END//
DELIMITER ;

-- =====================================================
-- 12. SP consultar_producto_negocio_v2
-- =====================================================

DROP PROCEDURE IF EXISTS consultar_producto_negocio_v2;

DELIMITER //
CREATE PROCEDURE consultar_producto_negocio_v2(
    IN p_id_producto INT,
    IN p_id_local INT
)
BEGIN
    DECLARE producto_existe INT DEFAULT 0;

    SELECT COUNT(*) INTO producto_existe
    FROM producto_marca pm
    WHERE pm.FK_ID_PRODUCTO = p_id_producto
      AND pm.FK_ID_LOCAL = p_id_local;

    IF producto_existe > 0 THEN
        SELECT
            p.NOMBRE_PRODUCTO,
            pm.PRECIO AS VALOR_PRODUCTS_LOCAL,
            p.IMAGEN_URL,
            COALESCE(u.NOMBRE_UNIDAD, '') AS NOMBRE_UNIDAD
        FROM producto_marca pm
        INNER JOIN producto p ON pm.FK_ID_PRODUCTO = p.PK_ID_PRODUCTO
        LEFT JOIN unidad u ON pm.FK_ID_UNIDAD = u.ID_UNIDAD
        WHERE pm.FK_ID_PRODUCTO = p_id_producto
          AND pm.FK_ID_LOCAL = p_id_local
        LIMIT 1;
    ELSE
        SELECT
            '' AS NOMBRE_PRODUCTO,
            0 AS VALOR_PRODUCTS_LOCAL,
            '' AS IMAGEN_URL,
            '' AS NOMBRE_UNIDAD;
    END IF;
END//
DELIMITER ;

-- =====================================================
-- 13. SP sp_obtener_limites_membresia
-- =====================================================

DROP PROCEDURE IF EXISTS sp_obtener_limites_membresia;

DELIMITER //
CREATE PROCEDURE sp_obtener_limites_membresia(
    IN p_id_local INT
)
BEGIN
    DECLARE v_productos_actuales INT DEFAULT 0;
    DECLARE v_ofertas_activas INT DEFAULT 0;
    DECLARE v_ofertas_usadas_periodo INT DEFAULT 0;

    -- Contar productos activos del local desde producto_marca
    SELECT COUNT(DISTINCT FK_ID_PRODUCTO) INTO v_productos_actuales
    FROM producto_marca
    WHERE FK_ID_LOCAL = p_id_local AND DISPONIBLE = 1;

    -- Contar ofertas flash activas
    SELECT COUNT(*) INTO v_ofertas_activas
    FROM oferta_flash
    WHERE FK_ID_LOCAL = p_id_local
      AND ESTADO = 1
      AND FECHA_FIN >= NOW();

    -- Contar ofertas creadas en el periodo actual (mes)
    SELECT COUNT(*) INTO v_ofertas_usadas_periodo
    FROM oferta_flash
    WHERE FK_ID_LOCAL = p_id_local
      AND MONTH(FECHA_CREACION) = MONTH(NOW())
      AND YEAR(FECHA_CREACION) = YEAR(NOW());

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
-- 14. SP buscar_sugerencias_productos
-- =====================================================

DROP PROCEDURE IF EXISTS buscar_sugerencias_productos;

DELIMITER //
CREATE PROCEDURE buscar_sugerencias_productos(
    IN p_termino VARCHAR(100),
    IN p_limite INT
)
BEGIN
    SELECT DISTINCT
        p.PK_ID_PRODUCTO AS id,
        p.NOMBRE_PRODUCTO AS nombre,
        p.IMAGEN_URL AS imagen,
        l.PK_ID_LOCAL AS idLocal,
        l.NOMBRE_LOCAL AS nombreLocal,
        l.FOTOS_LOCAL AS imagenLocal
    FROM producto p
    INNER JOIN producto_marca pm ON pm.FK_ID_PRODUCTO = p.PK_ID_PRODUCTO
    INNER JOIN `local` l ON pm.FK_ID_LOCAL = l.PK_ID_LOCAL
    WHERE l.FK_ID_ESTADO_LOCAL = 1
      AND pm.DISPONIBLE = 1
      AND p.NOMBRE_PRODUCTO LIKE CONCAT('%', p_termino, '%')
    ORDER BY
        CASE WHEN p.NOMBRE_PRODUCTO LIKE CONCAT(p_termino, '%') THEN 0 ELSE 1 END,
        p.NOMBRE_PRODUCTO
    LIMIT p_limite;
END//
DELIMITER ;

-- =====================================================
-- 15. Eliminar trigger de productoslocal (ya no existe la tabla)
-- =====================================================

DROP TRIGGER IF EXISTS asignar_categoria_local;

-- =====================================================
SELECT 'Migración completada: productoslocal eliminada, producto_marca limpia' AS Mensaje;
-- =====================================================
