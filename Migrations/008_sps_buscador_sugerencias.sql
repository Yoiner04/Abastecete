-- =============================================================================
-- Migración 008: SPs para autocompletado/sugerencias del buscador
-- Fecha: 2025-12-29
-- Descripción: Stored procedures optimizados para sugerencias en tiempo real
-- =============================================================================

-- Eliminar SPs si existen
DROP PROCEDURE IF EXISTS buscador_locales_sugerencias;
DROP PROCEDURE IF EXISTS buscador_productos_sugerencias;
DROP PROCEDURE IF EXISTS buscador_ofertas_sugerencias;

-- =============================================================================
-- SP: buscador_locales_sugerencias
-- Retorna locales para autocompletado (optimizado, campos mínimos)
-- =============================================================================
DELIMITER //
CREATE PROCEDURE `buscador_locales_sugerencias`(
    IN p_busqueda VARCHAR(100),
    IN p_limite INT
)
BEGIN
    SELECT
        l.PK_ID_LOCAL AS id,
        l.NOMBRE_LOCAL AS nombre,
        l.DIRECCION_LOCAL AS direccion,
        l.FOTOS_LOCAL AS imagen
    FROM `local` l
    WHERE l.FK_ID_ESTADO_LOCAL = 1
    AND (
        l.NOMBRE_LOCAL LIKE CONCAT('%', p_busqueda, '%')
        OR l.DESCRIPCION_LOCAL LIKE CONCAT('%', p_busqueda, '%')
    )
    ORDER BY
        CASE
            WHEN l.NOMBRE_LOCAL LIKE CONCAT(p_busqueda, '%') THEN 1
            WHEN l.NOMBRE_LOCAL LIKE CONCAT('%', p_busqueda, '%') THEN 2
            ELSE 3
        END,
        l.NOMBRE_LOCAL ASC
    LIMIT p_limite;
END//
DELIMITER ;

-- =============================================================================
-- SP: buscador_productos_sugerencias
-- Retorna productos para autocompletado (optimizado, campos mínimos)
-- =============================================================================
DELIMITER //
CREATE PROCEDURE `buscador_productos_sugerencias`(
    IN p_busqueda VARCHAR(100),
    IN p_limite INT
)
BEGIN
    SELECT
        p.PK_ID_PRODUCTO AS id,
        p.NOMBRE_PRODUCTO AS nombre,
        pl.VALOR_PRODUCTS_LOCAL AS precio,
        p.IMAGEN_URL AS imagen,
        l.PK_ID_LOCAL AS idLocal,
        l.NOMBRE_LOCAL AS nombreLocal,
        l.FOTOS_LOCAL AS imagenLocal
    FROM producto p
    INNER JOIN productoslocal pl ON pl.FK_ID_PRODUCTO = p.PK_ID_PRODUCTO
    INNER JOIN `local` l ON pl.FK_ID_LOCAL = l.PK_ID_LOCAL
    WHERE l.FK_ID_ESTADO_LOCAL = 1
    AND p.NOMBRE_PRODUCTO LIKE CONCAT('%', p_busqueda, '%')
    ORDER BY
        CASE
            WHEN p.NOMBRE_PRODUCTO LIKE CONCAT(p_busqueda, '%') THEN 1
            WHEN p.NOMBRE_PRODUCTO LIKE CONCAT('%', p_busqueda, '%') THEN 2
            ELSE 3
        END,
        p.NOMBRE_PRODUCTO ASC
    LIMIT p_limite;
END//
DELIMITER ;

-- =============================================================================
-- SP: buscador_ofertas_sugerencias
-- Retorna ofertas flash para autocompletado (optimizado, campos mínimos)
-- =============================================================================
DELIMITER //
CREATE PROCEDURE `buscador_ofertas_sugerencias`(
    IN p_busqueda VARCHAR(100),
    IN p_limite INT
)
BEGIN
    SELECT
        o.ID_OFERTAFLASH AS id,
        o.TITULO_OFERTA_FLASH AS titulo,
        o.PRODUCTO_OFERTA_FLASH AS producto,
        o.IMAGEN_PRODUCTO_OFERTA_FLASH AS imagen,
        o.TIEMPO_OFERTA_FLASH AS tiempoExpira,
        l.PK_ID_LOCAL AS idLocal,
        l.NOMBRE_LOCAL AS nombreLocal,
        l.FOTOS_LOCAL AS imagenLocal
    FROM oferta_flash o
    INNER JOIN `local` l ON o.FK_ID_LOCAL = l.PK_ID_LOCAL
    WHERE o.ESTADO_OFERTA_FLASH = 1
    AND l.FK_ID_ESTADO_LOCAL = 1
    AND o.TIEMPO_OFERTA_FLASH > NOW()
    AND (
        o.TITULO_OFERTA_FLASH LIKE CONCAT('%', p_busqueda, '%')
        OR o.PRODUCTO_OFERTA_FLASH LIKE CONCAT('%', p_busqueda, '%')
    )
    ORDER BY o.TIEMPO_OFERTA_FLASH ASC
    LIMIT p_limite;
END//
DELIMITER ;

-- =============================================================================
-- Verificación
-- =============================================================================
SELECT 'SPs de sugerencias del buscador creados correctamente' AS Mensaje;
