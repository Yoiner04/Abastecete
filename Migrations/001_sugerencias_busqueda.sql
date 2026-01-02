-- =====================================================
-- MIGRACIÓN 001: Procedimientos para "Quizás quisiste decir"
-- Fecha: 2026-01-02
-- Descripción: Procedimientos para sugerencias ortográficas del buscador
-- =====================================================

-- PASO 1: Eliminar si existen
DROP PROCEDURE IF EXISTS `obtener_nombres_productos_busqueda`;
DROP PROCEDURE IF EXISTS `obtener_nombres_negocios_busqueda`;

-- PASO 2: Crear obtener_nombres_productos_busqueda
-- En HeidiSQL: Clic derecho en "Procedimientos" > Crear nuevo > Procedimiento
-- Nombre: obtener_nombres_productos_busqueda (sin parámetros)
DELIMITER //
CREATE PROCEDURE `obtener_nombres_productos_busqueda`()
BEGIN
    SELECT DISTINCT
        p.NOMBRE_PRODUCTO AS nombre
    FROM producto p
    INNER JOIN producto_marca pm ON pm.FK_ID_PRODUCTO = p.PK_ID_PRODUCTO
    INNER JOIN `local` l ON pm.FK_ID_LOCAL = l.PK_ID_LOCAL
    WHERE l.FK_ID_ESTADO_LOCAL = 1
      AND pm.DISPONIBLE = 1
    ORDER BY p.NOMBRE_PRODUCTO;
END//
DELIMITER ;

-- PASO 3: Crear obtener_nombres_negocios_busqueda
-- Nombre: obtener_nombres_negocios_busqueda (sin parámetros)
DELIMITER //
CREATE PROCEDURE `obtener_nombres_negocios_busqueda`()
BEGIN
    SELECT DISTINCT
        l.NOMBRE_LOCAL AS nombre
    FROM `local` l
    WHERE l.FK_ID_ESTADO_LOCAL = 1
    ORDER BY l.NOMBRE_LOCAL;
END//
DELIMITER ;
