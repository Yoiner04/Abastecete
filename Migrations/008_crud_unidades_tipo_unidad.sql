-- =============================================
-- Migración: 008_crud_unidades_tipo_unidad.sql
-- Fecha: 2025-12-17
-- Descripción: Agrega procedimientos almacenados para CRUD completo
--              de Unidades y Tipos de Unidad
-- =============================================

-- =============================================
-- PARTE 1: CRUD PARA TIPO_UNIDAD
-- =============================================

-- 1.1 Consultar todos los tipos de unidad
DROP PROCEDURE IF EXISTS `consultar_tipos_unidad`;
DELIMITER //
CREATE PROCEDURE `consultar_tipos_unidad`()
BEGIN
    SELECT
        ID_TIPOUNIDAD,
        NOMBRE_TIPOUNIDAD
    FROM tipo_unidad
    ORDER BY NOMBRE_TIPOUNIDAD;
END//
DELIMITER ;

-- 1.2 Consultar tipo de unidad por ID
DROP PROCEDURE IF EXISTS `consultar_tipo_unidad_por_id`;
DELIMITER //
CREATE PROCEDURE `consultar_tipo_unidad_por_id`(
    IN `p_id` INT
)
BEGIN
    SELECT
        ID_TIPOUNIDAD,
        NOMBRE_TIPOUNIDAD
    FROM tipo_unidad
    WHERE ID_TIPOUNIDAD = p_id;
END//
DELIMITER ;

-- 1.3 Crear tipo de unidad
DROP PROCEDURE IF EXISTS `crear_tipo_unidad`;
DELIMITER //
CREATE PROCEDURE `crear_tipo_unidad`(
    IN `p_nombre` VARCHAR(50),
    OUT `mensaje` VARCHAR(255),
    OUT `resultado` INT
)
BEGIN
    DECLARE existe INT DEFAULT 0;

    -- Verificar si ya existe
    SELECT COUNT(*) INTO existe
    FROM tipo_unidad
    WHERE LOWER(NOMBRE_TIPOUNIDAD) = LOWER(p_nombre);

    IF existe > 0 THEN
        SET mensaje = 'Ya existe un tipo de unidad con ese nombre';
        SET resultado = 0;
    ELSE
        INSERT INTO tipo_unidad (NOMBRE_TIPOUNIDAD)
        VALUES (p_nombre);

        SET mensaje = 'Tipo de unidad creado exitosamente';
        SET resultado = LAST_INSERT_ID();
    END IF;
END//
DELIMITER ;

-- 1.4 Editar tipo de unidad
DROP PROCEDURE IF EXISTS `editar_tipo_unidad`;
DELIMITER //
CREATE PROCEDURE `editar_tipo_unidad`(
    IN `p_id` INT,
    IN `p_nombre` VARCHAR(50),
    OUT `mensaje` VARCHAR(255),
    OUT `resultado` INT
)
BEGIN
    DECLARE existe INT DEFAULT 0;
    DECLARE duplicado INT DEFAULT 0;

    -- Verificar si existe el tipo
    SELECT COUNT(*) INTO existe
    FROM tipo_unidad
    WHERE ID_TIPOUNIDAD = p_id;

    IF existe = 0 THEN
        SET mensaje = 'Tipo de unidad no encontrado';
        SET resultado = 0;
    ELSE
        -- Verificar nombre duplicado (excluyendo el actual)
        SELECT COUNT(*) INTO duplicado
        FROM tipo_unidad
        WHERE LOWER(NOMBRE_TIPOUNIDAD) = LOWER(p_nombre)
        AND ID_TIPOUNIDAD != p_id;

        IF duplicado > 0 THEN
            SET mensaje = 'Ya existe otro tipo de unidad con ese nombre';
            SET resultado = 0;
        ELSE
            UPDATE tipo_unidad
            SET NOMBRE_TIPOUNIDAD = p_nombre
            WHERE ID_TIPOUNIDAD = p_id;

            SET mensaje = 'Tipo de unidad actualizado exitosamente';
            SET resultado = 1;
        END IF;
    END IF;
END//
DELIMITER ;

-- 1.5 Eliminar tipo de unidad
DROP PROCEDURE IF EXISTS `eliminar_tipo_unidad`;
DELIMITER //
CREATE PROCEDURE `eliminar_tipo_unidad`(
    IN `p_id` INT,
    OUT `mensaje` VARCHAR(255),
    OUT `resultado` INT
)
BEGIN
    DECLARE existe INT DEFAULT 0;
    DECLARE tiene_unidades INT DEFAULT 0;

    -- Verificar si existe
    SELECT COUNT(*) INTO existe
    FROM tipo_unidad
    WHERE ID_TIPOUNIDAD = p_id;

    IF existe = 0 THEN
        SET mensaje = 'Tipo de unidad no encontrado';
        SET resultado = 0;
    ELSE
        -- Verificar si tiene unidades asociadas
        SELECT COUNT(*) INTO tiene_unidades
        FROM unidad
        WHERE FK_ID_TIPOUNIDAD = p_id;

        IF tiene_unidades > 0 THEN
            SET mensaje = CONCAT('No se puede eliminar. Tiene ', tiene_unidades, ' unidades asociadas');
            SET resultado = 0;
        ELSE
            DELETE FROM tipo_unidad WHERE ID_TIPOUNIDAD = p_id;
            SET mensaje = 'Tipo de unidad eliminado exitosamente';
            SET resultado = 1;
        END IF;
    END IF;
END//
DELIMITER ;

-- =============================================
-- PARTE 2: CRUD PARA UNIDAD
-- =============================================

-- 2.1 Consultar todas las unidades (con tipo)
DROP PROCEDURE IF EXISTS `consultar_todas_unidades`;
DELIMITER //
CREATE PROCEDURE `consultar_todas_unidades`()
BEGIN
    SELECT
        u.ID_UNIDAD,
        u.NOMBRE_UNIDAD,
        u.ESTADO_UNIDAD,
        u.FK_ID_TIPOUNIDAD,
        tu.NOMBRE_TIPOUNIDAD
    FROM unidad u
    LEFT JOIN tipo_unidad tu ON u.FK_ID_TIPOUNIDAD = tu.ID_TIPOUNIDAD
    ORDER BY tu.NOMBRE_TIPOUNIDAD, u.NOMBRE_UNIDAD;
END//
DELIMITER ;

-- 2.2 Consultar unidad por ID
DROP PROCEDURE IF EXISTS `consultar_unidad_por_id`;
DELIMITER //
CREATE PROCEDURE `consultar_unidad_por_id`(
    IN `p_id` INT
)
BEGIN
    SELECT
        u.ID_UNIDAD,
        u.NOMBRE_UNIDAD,
        u.ESTADO_UNIDAD,
        u.FK_ID_TIPOUNIDAD,
        tu.NOMBRE_TIPOUNIDAD
    FROM unidad u
    LEFT JOIN tipo_unidad tu ON u.FK_ID_TIPOUNIDAD = tu.ID_TIPOUNIDAD
    WHERE u.ID_UNIDAD = p_id;
END//
DELIMITER ;

-- 2.3 Crear unidad
DROP PROCEDURE IF EXISTS `crear_unidad`;
DELIMITER //
CREATE PROCEDURE `crear_unidad`(
    IN `p_nombre` VARCHAR(50),
    IN `p_estado` TINYINT,
    IN `p_tipo_unidad_id` INT,
    OUT `mensaje` VARCHAR(255),
    OUT `resultado` INT
)
BEGIN
    DECLARE existe INT DEFAULT 0;
    DECLARE tipo_existe INT DEFAULT 1;

    -- Verificar si existe el tipo de unidad (solo si se especificó uno)
    IF p_tipo_unidad_id IS NOT NULL THEN
        SELECT COUNT(*) INTO tipo_existe
        FROM tipo_unidad
        WHERE ID_TIPOUNIDAD = p_tipo_unidad_id;
    END IF;

    IF tipo_existe = 0 THEN
        SET mensaje = 'El tipo de unidad especificado no existe';
        SET resultado = 0;
    ELSE
        -- Verificar si ya existe una unidad con ese nombre en el mismo tipo
        SELECT COUNT(*) INTO existe
        FROM unidad
        WHERE LOWER(NOMBRE_UNIDAD) = LOWER(p_nombre)
        AND (FK_ID_TIPOUNIDAD = p_tipo_unidad_id OR (FK_ID_TIPOUNIDAD IS NULL AND p_tipo_unidad_id IS NULL));

        IF existe > 0 THEN
            SET mensaje = 'Ya existe una unidad con ese nombre en este tipo';
            SET resultado = 0;
        ELSE
            INSERT INTO unidad (NOMBRE_UNIDAD, ESTADO_UNIDAD, FK_ID_TIPOUNIDAD)
            VALUES (p_nombre, p_estado, p_tipo_unidad_id);

            SET mensaje = 'Unidad creada exitosamente';
            SET resultado = LAST_INSERT_ID();
        END IF;
    END IF;
END//
DELIMITER ;

-- 2.4 Editar unidad
DROP PROCEDURE IF EXISTS `editar_unidad`;
DELIMITER //
CREATE PROCEDURE `editar_unidad`(
    IN `p_id` INT,
    IN `p_nombre` VARCHAR(50),
    IN `p_estado` TINYINT,
    IN `p_tipo_unidad_id` INT,
    OUT `mensaje` VARCHAR(255),
    OUT `resultado` INT
)
BEGIN
    DECLARE existe INT DEFAULT 0;
    DECLARE duplicado INT DEFAULT 0;

    -- Verificar si existe la unidad
    SELECT COUNT(*) INTO existe
    FROM unidad
    WHERE ID_UNIDAD = p_id;

    IF existe = 0 THEN
        SET mensaje = 'Unidad no encontrada';
        SET resultado = 0;
    ELSE
        -- Verificar nombre duplicado (excluyendo la actual)
        SELECT COUNT(*) INTO duplicado
        FROM unidad
        WHERE LOWER(NOMBRE_UNIDAD) = LOWER(p_nombre)
        AND ID_UNIDAD != p_id
        AND (FK_ID_TIPOUNIDAD = p_tipo_unidad_id OR (FK_ID_TIPOUNIDAD IS NULL AND p_tipo_unidad_id IS NULL));

        IF duplicado > 0 THEN
            SET mensaje = 'Ya existe otra unidad con ese nombre en este tipo';
            SET resultado = 0;
        ELSE
            UPDATE unidad
            SET NOMBRE_UNIDAD = p_nombre,
                ESTADO_UNIDAD = p_estado,
                FK_ID_TIPOUNIDAD = p_tipo_unidad_id
            WHERE ID_UNIDAD = p_id;

            SET mensaje = 'Unidad actualizada exitosamente';
            SET resultado = 1;
        END IF;
    END IF;
END//
DELIMITER ;

-- 2.5 Eliminar unidad
DROP PROCEDURE IF EXISTS `eliminar_unidad`;
DELIMITER //
CREATE PROCEDURE `eliminar_unidad`(
    IN `p_id` INT,
    OUT `mensaje` VARCHAR(255),
    OUT `resultado` INT
)
BEGIN
    DECLARE existe INT DEFAULT 0;
    DECLARE en_uso INT DEFAULT 0;

    -- Verificar si existe
    SELECT COUNT(*) INTO existe
    FROM unidad
    WHERE ID_UNIDAD = p_id;

    IF existe = 0 THEN
        SET mensaje = 'Unidad no encontrada';
        SET resultado = 0;
    ELSE
        -- Verificar si está en uso en productoslocal
        SELECT COUNT(*) INTO en_uso
        FROM productoslocal
        WHERE FK_ID_UNIDAD = p_id;

        IF en_uso > 0 THEN
            SET mensaje = CONCAT('No se puede eliminar. La unidad está siendo usada en ', en_uso, ' productos');
            SET resultado = 0;
        ELSE
            DELETE FROM unidad WHERE ID_UNIDAD = p_id;
            SET mensaje = 'Unidad eliminada exitosamente';
            SET resultado = 1;
        END IF;
    END IF;
END//
DELIMITER ;

-- 2.6 Consultar unidades por tipo (útil para filtros)
DROP PROCEDURE IF EXISTS `consultar_unidades_por_tipo`;
DELIMITER //
CREATE PROCEDURE `consultar_unidades_por_tipo`(
    IN `p_tipo_unidad_id` INT
)
BEGIN
    SELECT
        u.ID_UNIDAD,
        u.NOMBRE_UNIDAD,
        u.ESTADO_UNIDAD,
        u.FK_ID_TIPOUNIDAD,
        tu.NOMBRE_TIPOUNIDAD
    FROM unidad u
    LEFT JOIN tipo_unidad tu ON u.FK_ID_TIPOUNIDAD = tu.ID_TIPOUNIDAD
    WHERE u.FK_ID_TIPOUNIDAD = p_tipo_unidad_id
    AND u.ESTADO_UNIDAD = 1
    ORDER BY u.NOMBRE_UNIDAD;
END//
DELIMITER ;

-- =============================================
-- PARTE 3: ÍNDICES ADICIONALES
-- =============================================

-- Procedimiento auxiliar para crear índices de forma segura
DROP PROCEDURE IF EXISTS crear_indice_seguro_v3;
DELIMITER //
CREATE PROCEDURE crear_indice_seguro_v3(
    IN p_tabla VARCHAR(64),
    IN p_indice VARCHAR(64),
    IN p_columnas VARCHAR(255)
)
BEGIN
    DECLARE CONTINUE HANDLER FOR 1061 BEGIN END;
    DECLARE CONTINUE HANDLER FOR 1091 BEGIN END;

    SET @sql = CONCAT('CREATE INDEX ', p_indice, ' ON ', p_tabla, '(', p_columnas, ')');
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
END//
DELIMITER ;

-- Índices para mejorar consultas de unidades
CALL crear_indice_seguro_v3('unidad', 'idx_unidad_tipo', 'FK_ID_TIPOUNIDAD');
CALL crear_indice_seguro_v3('unidad', 'idx_unidad_estado', 'ESTADO_UNIDAD');
CALL crear_indice_seguro_v3('unidad', 'idx_unidad_nombre', 'NOMBRE_UNIDAD');

-- Limpiar procedimiento auxiliar
DROP PROCEDURE IF EXISTS crear_indice_seguro_v3;

SELECT 'Migración 008 completada exitosamente - CRUD Unidades y Tipos de Unidad' AS resultado;
