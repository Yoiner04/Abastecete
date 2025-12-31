-- =====================================================
-- Migración 016: Actualizar SPs restantes que aún usan productoslocal
-- Fecha: 2025-12-31
-- =====================================================

-- 1. buscador_productos
DROP PROCEDURE IF EXISTS buscador_productos;

DELIMITER //
CREATE PROCEDURE buscador_productos(IN busqueda VARCHAR(255))
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

-- 2. buscador_productos_sugerencias
DROP PROCEDURE IF EXISTS buscador_productos_sugerencias;

DELIMITER //
CREATE PROCEDURE buscador_productos_sugerencias(
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
    ORDER BY CASE WHEN p.NOMBRE_PRODUCTO LIKE CONCAT(p_termino, '%') THEN 0 ELSE 1 END, p.NOMBRE_PRODUCTO
    LIMIT p_limite;
END//
DELIMITER ;

-- 3. consultar_producto_negocio_seguro
DROP PROCEDURE IF EXISTS consultar_producto_negocio_seguro;

DELIMITER //
CREATE PROCEDURE consultar_producto_negocio_seguro(
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
        SELECT '' AS NOMBRE_PRODUCTO, 0 AS VALOR_PRODUCTS_LOCAL, '' AS IMAGEN_URL, '' AS NOMBRE_UNIDAD;
    END IF;
END//
DELIMITER ;

-- 4. eliminar_unidad
DROP PROCEDURE IF EXISTS eliminar_unidad;

DELIMITER //
CREATE PROCEDURE eliminar_unidad(
    IN p_id INT,
    OUT mensaje VARCHAR(255),
    OUT resultado INT
)
BEGIN
    DECLARE existe INT DEFAULT 0;
    DECLARE en_uso INT DEFAULT 0;

    SELECT COUNT(*) INTO existe FROM unidad WHERE ID_UNIDAD = p_id;

    IF existe = 0 THEN
        SET mensaje = 'Unidad no encontrada';
        SET resultado = 0;
    ELSE
        -- Verificar si está en uso en producto_marca
        SELECT COUNT(*) INTO en_uso FROM producto_marca WHERE FK_ID_UNIDAD = p_id;

        IF en_uso > 0 THEN
            SET mensaje = 'No se puede eliminar, la unidad está en uso';
            SET resultado = 0;
        ELSE
            DELETE FROM unidad WHERE ID_UNIDAD = p_id;
            SET mensaje = 'Unidad eliminada correctamente';
            SET resultado = 1;
        END IF;
    END IF;
END//
DELIMITER ;

-- 5. obtener_limites_membresia
DROP PROCEDURE IF EXISTS obtener_limites_membresia;

DELIMITER //
CREATE PROCEDURE obtener_limites_membresia(IN p_id_local INT)
BEGIN
    DECLARE v_productos_actuales INT DEFAULT 0;
    DECLARE v_ofertas_activas INT DEFAULT 0;
    DECLARE v_ofertas_usadas_periodo INT DEFAULT 0;

    SELECT COUNT(DISTINCT FK_ID_PRODUCTO) INTO v_productos_actuales
    FROM producto_marca
    WHERE FK_ID_LOCAL = p_id_local AND DISPONIBLE = 1;

    SELECT COUNT(*) INTO v_ofertas_activas
    FROM oferta_flash
    WHERE FK_ID_LOCAL = p_id_local AND ESTADO = 1 AND FECHA_FIN >= NOW();

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

-- 6. sp_consultar_productos_local_con_marcas
DROP PROCEDURE IF EXISTS sp_consultar_productos_local_con_marcas;

DELIMITER //
CREATE PROCEDURE sp_consultar_productos_local_con_marcas(IN p_id_local INT)
BEGIN
    SELECT
        p.PK_ID_PRODUCTO as Id,
        p.NOMBRE_PRODUCTO as Nombre,
        p.DESCRIPCION as Descripcion,
        p.IMAGEN_URL as ImagenUrl,
        p.CLOUDINARY_PUBLIC_ID as CloudinaryPublicId,
        p.SKU as SKU,
        p.FK_ID_SUB_CATEGORIA as IdSubCategoria,
        sc.NOMBRE_SUB_CATEGORIA as NombreSubCategoria,
        c.PK_ID_CATEGORIA as Categoria,
        c.NOMBRE_CATEGORIA as NombreCategoria,
        pm.FK_ID_UNIDAD as IdUnidad,
        u.NOMBRE_UNIDAD as NombreUnidad,
        p.FK_ID_TIPOUNIDAD as IdTipoUnidad,
        tu.NOMBRE_TIPOUNIDAD as NombreTipoUnidad,
        MIN(pm.PRECIO) as PrecioMinimo,
        MAX(pm.PRECIO) as PrecioMaximo,
        COUNT(DISTINCT pm.PK_ID) as CantidadMarcas,
        MIN(pm.PRECIO) as Precio,
        pm.FK_ID_MARCA as IdMarca,
        m.NOMBRE_MARCA as NombreMarca
    FROM producto_marca pm
    INNER JOIN producto p ON pm.FK_ID_PRODUCTO = p.PK_ID_PRODUCTO
    INNER JOIN sub_categoria sc ON p.FK_ID_SUB_CATEGORIA = sc.PK_ID_SUB_CATEGORIA
    INNER JOIN categoria c ON sc.FK_ID_CATEGORIA = c.PK_ID_CATEGORIA
    LEFT JOIN unidad u ON pm.FK_ID_UNIDAD = u.ID_UNIDAD
    LEFT JOIN tipo_unidad tu ON p.FK_ID_TIPOUNIDAD = tu.ID_TIPOUNIDAD
    LEFT JOIN marca m ON pm.FK_ID_MARCA = m.PK_ID_MARCA
    WHERE pm.FK_ID_LOCAL = p_id_local
      AND pm.DISPONIBLE = 1
    GROUP BY p.PK_ID_PRODUCTO, p.NOMBRE_PRODUCTO, p.DESCRIPCION, p.IMAGEN_URL,
             p.CLOUDINARY_PUBLIC_ID, p.SKU, p.FK_ID_SUB_CATEGORIA, sc.NOMBRE_SUB_CATEGORIA,
             c.PK_ID_CATEGORIA, c.NOMBRE_CATEGORIA, pm.FK_ID_UNIDAD, u.NOMBRE_UNIDAD,
             p.FK_ID_TIPOUNIDAD, tu.NOMBRE_TIPOUNIDAD, pm.FK_ID_MARCA, m.NOMBRE_MARCA
    ORDER BY p.NOMBRE_PRODUCTO;
END//
DELIMITER ;

-- =====================================================
SELECT 'Migración 016 completada - SPs actualizados' AS Mensaje;
-- =====================================================
