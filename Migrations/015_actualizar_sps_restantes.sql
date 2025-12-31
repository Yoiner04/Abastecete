-- =====================================================
-- Migración 015: Actualizar SPs restantes que usaban productoslocal
-- Fecha: 2025-12-31
-- =====================================================

-- 1. SP para actualizar precio de producto
DROP PROCEDURE IF EXISTS sp_actualizar_precio_producto_local;

DELIMITER //
CREATE PROCEDURE sp_actualizar_precio_producto_local(
    IN p_id_local INT,
    IN p_id_producto INT,
    IN p_nuevo_precio INT
)
BEGIN
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

-- 2. SP buscar_productos
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

-- 3. SP consultar_producto_negocio
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

-- 4. SP consultar_producto_negocio_v2
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
        SELECT '' AS NOMBRE_PRODUCTO, 0 AS VALOR_PRODUCTS_LOCAL, '' AS IMAGEN_URL, '' AS NOMBRE_UNIDAD;
    END IF;
END//
DELIMITER ;

-- 5. SP sp_obtener_limites_membresia
DROP PROCEDURE IF EXISTS sp_obtener_limites_membresia;

DELIMITER //
CREATE PROCEDURE sp_obtener_limites_membresia(
    IN p_id_local INT
)
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

-- 6. SP buscar_sugerencias_productos
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
    ORDER BY CASE WHEN p.NOMBRE_PRODUCTO LIKE CONCAT(p_termino, '%') THEN 0 ELSE 1 END, p.NOMBRE_PRODUCTO
    LIMIT p_limite;
END//
DELIMITER ;

-- 7. Eliminar trigger
DROP TRIGGER IF EXISTS asignar_categoria_local;

-- =====================================================
SELECT 'Migración 015 completada' AS Mensaje;
-- =====================================================
