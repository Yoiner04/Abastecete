-- =============================================
-- Migración: 011_stored_procedures_banners.sql
-- Fecha: 2025-12-18
-- Descripción: Stored procedures para CRUD de banners
-- =============================================

-- =============================================
-- CONSULTAS
-- =============================================

-- Listar banners por tipo
DROP PROCEDURE IF EXISTS `consultar_banners_por_tipo`;
DELIMITER //
CREATE PROCEDURE `consultar_banners_por_tipo`(
    IN `p_tipo` VARCHAR(50)
)
BEGIN
    SELECT
        PK_ID_BANNER,
        CLOUDINARY_URL,
        CLOUDINARY_PUBLIC_ID,
        NOMBRE,
        TIPO,
        FORMATO,
        FK_ID_CATEGORIA,
        ACTIVO,
        FECHA_REGISTRO
    FROM banner
    WHERE TIPO = p_tipo AND ACTIVO = 1
    ORDER BY FECHA_REGISTRO DESC;
END//
DELIMITER ;

-- Listar banners por categoría
DROP PROCEDURE IF EXISTS `consultar_banners_por_categoria`;
DELIMITER //
CREATE PROCEDURE `consultar_banners_por_categoria`(
    IN `p_categoria_id` INT
)
BEGIN
    SELECT
        PK_ID_BANNER,
        CLOUDINARY_URL,
        CLOUDINARY_PUBLIC_ID,
        NOMBRE,
        TIPO,
        FORMATO,
        FK_ID_CATEGORIA,
        ACTIVO,
        FECHA_REGISTRO
    FROM banner
    WHERE FK_ID_CATEGORIA = p_categoria_id
      AND TIPO = 'categoria'
      AND ACTIVO = 1
    ORDER BY FORMATO, FECHA_REGISTRO DESC;
END//
DELIMITER ;

-- Obtener banner por ID
DROP PROCEDURE IF EXISTS `consultar_banner_por_id`;
DELIMITER //
CREATE PROCEDURE `consultar_banner_por_id`(
    IN `p_id` INT
)
BEGIN
    SELECT
        PK_ID_BANNER,
        CLOUDINARY_URL,
        CLOUDINARY_PUBLIC_ID,
        NOMBRE,
        TIPO,
        FORMATO,
        FK_ID_CATEGORIA,
        ACTIVO,
        FECHA_REGISTRO
    FROM banner
    WHERE PK_ID_BANNER = p_id;
END//
DELIMITER ;

-- =============================================
-- CREAR
-- =============================================

DROP PROCEDURE IF EXISTS `crear_banner`;
DELIMITER //
CREATE PROCEDURE `crear_banner`(
    IN `p_cloudinary_url` VARCHAR(500),
    IN `p_cloudinary_public_id` VARCHAR(255),
    IN `p_nombre` VARCHAR(100),
    IN `p_tipo` VARCHAR(50),
    IN `p_formato` VARCHAR(10),
    IN `p_categoria_id` INT,
    OUT `mensaje` VARCHAR(255),
    OUT `resultado` INT
)
BEGIN
    INSERT INTO banner (
        CLOUDINARY_URL,
        CLOUDINARY_PUBLIC_ID,
        NOMBRE,
        TIPO,
        FORMATO,
        FK_ID_CATEGORIA,
        ACTIVO,
        FECHA_REGISTRO
    ) VALUES (
        p_cloudinary_url,
        p_cloudinary_public_id,
        p_nombre,
        p_tipo,
        p_formato,
        p_categoria_id,
        1,
        NOW()
    );

    SET resultado = LAST_INSERT_ID();
    SET mensaje = 'Banner creado exitosamente';
END//
DELIMITER ;

-- =============================================
-- ACTUALIZAR
-- =============================================

DROP PROCEDURE IF EXISTS `actualizar_banner`;
DELIMITER //
CREATE PROCEDURE `actualizar_banner`(
    IN `p_id` INT,
    IN `p_cloudinary_url` VARCHAR(500),
    IN `p_cloudinary_public_id` VARCHAR(255),
    OUT `mensaje` VARCHAR(255),
    OUT `resultado` INT
)
BEGIN
    DECLARE existe INT DEFAULT 0;

    SELECT COUNT(*) INTO existe FROM banner WHERE PK_ID_BANNER = p_id;

    IF existe = 0 THEN
        SET mensaje = 'Banner no encontrado';
        SET resultado = 0;
    ELSE
        UPDATE banner
        SET CLOUDINARY_URL = p_cloudinary_url,
            CLOUDINARY_PUBLIC_ID = p_cloudinary_public_id,
            FECHA_REGISTRO = NOW()
        WHERE PK_ID_BANNER = p_id;

        SET mensaje = 'Banner actualizado exitosamente';
        SET resultado = 1;
    END IF;
END//
DELIMITER ;

-- =============================================
-- ELIMINAR
-- =============================================

DROP PROCEDURE IF EXISTS `eliminar_banner`;
DELIMITER //
CREATE PROCEDURE `eliminar_banner`(
    IN `p_id` INT,
    OUT `mensaje` VARCHAR(255),
    OUT `resultado` INT,
    OUT `public_id` VARCHAR(255)
)
BEGIN
    DECLARE existe INT DEFAULT 0;

    -- Obtener public_id antes de eliminar (para borrar de Cloudinary)
    SELECT CLOUDINARY_PUBLIC_ID INTO public_id
    FROM banner
    WHERE PK_ID_BANNER = p_id;

    SELECT COUNT(*) INTO existe FROM banner WHERE PK_ID_BANNER = p_id;

    IF existe = 0 THEN
        SET mensaje = 'Banner no encontrado';
        SET resultado = 0;
        SET public_id = NULL;
    ELSE
        DELETE FROM banner WHERE PK_ID_BANNER = p_id;
        SET mensaje = 'Banner eliminado exitosamente';
        SET resultado = 1;
    END IF;
END//
DELIMITER ;

-- Desactivar banner (soft delete)
DROP PROCEDURE IF EXISTS `desactivar_banner`;
DELIMITER //
CREATE PROCEDURE `desactivar_banner`(
    IN `p_id` INT,
    OUT `mensaje` VARCHAR(255),
    OUT `resultado` INT
)
BEGIN
    DECLARE existe INT DEFAULT 0;

    SELECT COUNT(*) INTO existe FROM banner WHERE PK_ID_BANNER = p_id;

    IF existe = 0 THEN
        SET mensaje = 'Banner no encontrado';
        SET resultado = 0;
    ELSE
        UPDATE banner SET ACTIVO = 0 WHERE PK_ID_BANNER = p_id;
        SET mensaje = 'Banner desactivado exitosamente';
        SET resultado = 1;
    END IF;
END//
DELIMITER ;

SELECT 'Migración 011 completada - Stored procedures de banners creados' AS resultado;
