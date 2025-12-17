-- =============================================
-- Migración: 007_optimize_queries_and_validations.sql
-- Fecha: 2025-12-16
-- Descripción: Optimiza consultas y agrega procedimientos específicos
--              para evitar traer datos innecesarios
-- =============================================

-- =============================================
-- 1. Nuevo SP: consultar_categoria_por_id
--    Evita traer TODAS las categorías cuando solo necesitamos una
-- =============================================
DROP PROCEDURE IF EXISTS `consultar_categoria_por_id`;

DELIMITER //
CREATE PROCEDURE `consultar_categoria_por_id`(
    IN `p_id_categoria` INT,
    OUT `mensaje` VARCHAR(255),
    OUT `resultado` INT
)
BEGIN
    DECLARE categoria_existe INT DEFAULT 0;

    -- Verificar si la categoría existe
    SELECT COUNT(*) INTO categoria_existe
    FROM categoria
    WHERE PK_ID_CATEGORIA = p_id_categoria;

    IF categoria_existe > 0 THEN
        SELECT * FROM categoria WHERE PK_ID_CATEGORIA = p_id_categoria;
        SET mensaje = 'Categoría encontrada';
        SET resultado = 1;
    ELSE
        SET mensaje = 'Categoría no encontrada';
        SET resultado = 0;
        -- Retornar conjunto vacío con la estructura correcta
        SELECT * FROM categoria WHERE 1 = 0;
    END IF;
END//
DELIMITER ;

-- =============================================
-- 2. Nuevo SP: consultar_local_por_persona_seguro
--    Valida que exista el local antes de retornarlo
-- =============================================
DROP PROCEDURE IF EXISTS `consultar_local_por_persona_seguro`;

DELIMITER //
CREATE PROCEDURE `consultar_local_por_persona_seguro`(
    IN `p_id_persona` INT,
    OUT `mensaje` VARCHAR(255),
    OUT `resultado` INT
)
BEGIN
    DECLARE local_existe INT DEFAULT 0;

    -- Verificar si existe un local para esta persona
    SELECT COUNT(*) INTO local_existe
    FROM local
    WHERE FK_ID_PERSONA = p_id_persona;

    IF local_existe > 0 THEN
        SELECT * FROM local WHERE FK_ID_PERSONA = p_id_persona LIMIT 1;
        SET mensaje = 'Local encontrado';
        SET resultado = 1;
    ELSE
        SET mensaje = 'No se encontró local para esta persona';
        SET resultado = 0;
        -- Retornar conjunto vacío con la estructura correcta
        SELECT * FROM local WHERE 1 = 0;
    END IF;
END//
DELIMITER ;

-- =============================================
-- 3. Nuevo SP: consultar_local_por_id_seguro
--    Valida que exista el local antes de retornarlo
-- =============================================
DROP PROCEDURE IF EXISTS `consultar_local_por_id_seguro`;

DELIMITER //
CREATE PROCEDURE `consultar_local_por_id_seguro`(
    IN `p_id_local` INT,
    OUT `mensaje` VARCHAR(255),
    OUT `resultado` INT
)
BEGIN
    DECLARE local_existe INT DEFAULT 0;

    -- Verificar si existe el local
    SELECT COUNT(*) INTO local_existe
    FROM local
    WHERE PK_ID_LOCAL = p_id_local;

    IF local_existe > 0 THEN
        SELECT * FROM local WHERE PK_ID_LOCAL = p_id_local;
        SET mensaje = 'Local encontrado';
        SET resultado = 1;
    ELSE
        SET mensaje = 'Local no encontrado';
        SET resultado = 0;
        -- Retornar conjunto vacío con la estructura correcta
        SELECT * FROM local WHERE 1 = 0;
    END IF;
END//
DELIMITER ;

-- =============================================
-- 4. Nuevo SP: consultar_producto_negocio_seguro
--    Valida que exista el producto antes de retornarlo
-- =============================================
DROP PROCEDURE IF EXISTS `consultar_producto_negocio_seguro`;

DELIMITER //
CREATE PROCEDURE `consultar_producto_negocio_seguro`(
    IN `p_id_producto` INT,
    IN `p_id_local` INT,
    OUT `mensaje` VARCHAR(255),
    OUT `resultado` INT
)
BEGIN
    DECLARE producto_existe INT DEFAULT 0;

    -- Verificar si existe el producto en ese local
    SELECT COUNT(*) INTO producto_existe
    FROM productoslocal pl
    INNER JOIN producto p ON pl.FK_ID_PRODUCTO = p.PK_ID_PRODUCTO
    WHERE pl.FK_ID_PRODUCTO = p_id_producto
      AND pl.FK_ID_LOCAL = p_id_local;

    IF producto_existe > 0 THEN
        SELECT
            p.NOMBRE_PRODUCTO,
            pl.VALOR_PRODUCTS_LOCAL,
            p.IMAGEN_URL,
            u.NOMBRE_UNIDAD
        FROM productoslocal pl
        INNER JOIN producto p ON pl.FK_ID_PRODUCTO = p.PK_ID_PRODUCTO
        INNER JOIN unidad u ON p.FK_ID_UNIDAD = u.PK_ID_UNIDAD
        WHERE pl.FK_ID_PRODUCTO = p_id_producto
          AND pl.FK_ID_LOCAL = p_id_local;
        SET mensaje = 'Producto encontrado';
        SET resultado = 1;
    ELSE
        SET mensaje = 'Producto no encontrado en este local';
        SET resultado = 0;
        -- Retornar conjunto vacío
        SELECT NULL AS NOMBRE_PRODUCTO, NULL AS VALOR_PRODUCTS_LOCAL,
               NULL AS IMAGEN_URL, NULL AS NOMBRE_UNIDAD
        WHERE 1 = 0;
    END IF;
END//
DELIMITER ;

-- =============================================
-- 5. Índices para optimizar las nuevas consultas
-- =============================================
-- Procedimiento auxiliar para crear índices de forma segura
DROP PROCEDURE IF EXISTS crear_indice_seguro_v2;

DELIMITER //
CREATE PROCEDURE crear_indice_seguro_v2(
    IN p_tabla VARCHAR(64),
    IN p_indice VARCHAR(64),
    IN p_columnas VARCHAR(255)
)
BEGIN
    DECLARE CONTINUE HANDLER FOR 1061 BEGIN END; -- Índice ya existe
    DECLARE CONTINUE HANDLER FOR 1091 BEGIN END; -- No se puede eliminar índice inexistente

    SET @sql = CONCAT('CREATE INDEX ', p_indice, ' ON ', p_tabla, '(', p_columnas, ')');
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
END//
DELIMITER ;

-- Índices para mejorar performance
CALL crear_indice_seguro_v2('local', 'idx_local_persona', 'FK_ID_PERSONA');
CALL crear_indice_seguro_v2('local', 'idx_local_membresia', 'FK_ID_TIPOMEMBRESIA');
CALL crear_indice_seguro_v2('localcategoria', 'idx_localcategoria_local', 'FK_ID_LOCAL');
CALL crear_indice_seguro_v2('localcategoria', 'idx_localcategoria_categoria', 'FK_ID_CATEGORIA');
CALL crear_indice_seguro_v2('productoslocal', 'idx_productoslocal_producto', 'FK_ID_PRODUCTO');
CALL crear_indice_seguro_v2('productoslocal', 'idx_productoslocal_local', 'FK_ID_LOCAL');

-- Limpiar procedimiento auxiliar
DROP PROCEDURE IF EXISTS crear_indice_seguro_v2;

SELECT 'Migración 007 completada exitosamente' AS resultado;
