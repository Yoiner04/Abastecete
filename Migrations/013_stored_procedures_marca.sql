-- =============================================
-- Migración: 013_stored_procedures_marca.sql
-- Fecha: 2025-12-18
-- Descripción: Stored procedures para CRUD de marcas
-- =============================================

-- =============================================
-- CONSULTAS
-- =============================================

-- Listar todas las marcas activas
DROP PROCEDURE IF EXISTS `consultar_marcas`;
DELIMITER //
CREATE PROCEDURE `consultar_marcas`()
BEGIN
    SELECT
        PK_ID_MARCA,
        NOMBRE,
        DESCRIPCION,
        LOGO_URL,
        CLOUDINARY_PUBLIC_ID,
        ACTIVO,
        FECHA_REGISTRO
    FROM marca
    WHERE ACTIVO = 1
    ORDER BY NOMBRE ASC;
END//
DELIMITER ;

-- Listar todas las marcas (incluye inactivas)
DROP PROCEDURE IF EXISTS `consultar_marcas_todas`;
DELIMITER //
CREATE PROCEDURE `consultar_marcas_todas`()
BEGIN
    SELECT
        PK_ID_MARCA,
        NOMBRE,
        DESCRIPCION,
        LOGO_URL,
        CLOUDINARY_PUBLIC_ID,
        ACTIVO,
        FECHA_REGISTRO
    FROM marca
    ORDER BY ACTIVO DESC, NOMBRE ASC;
END//
DELIMITER ;

-- Obtener marca por ID
DROP PROCEDURE IF EXISTS `consultar_marca_por_id`;
DELIMITER //
CREATE PROCEDURE `consultar_marca_por_id`(
    IN `p_id` INT
)
BEGIN
    SELECT
        PK_ID_MARCA,
        NOMBRE,
        DESCRIPCION,
        LOGO_URL,
        CLOUDINARY_PUBLIC_ID,
        ACTIVO,
        FECHA_REGISTRO
    FROM marca
    WHERE PK_ID_MARCA = p_id;
END//
DELIMITER ;

-- =============================================
-- CREAR
-- =============================================

DROP PROCEDURE IF EXISTS `crear_marca`;
DELIMITER //
CREATE PROCEDURE `crear_marca`(
    IN `p_nombre` VARCHAR(100),
    IN `p_descripcion` VARCHAR(255),
    IN `p_logo_url` VARCHAR(500),
    IN `p_cloudinary_public_id` VARCHAR(255),
    OUT `mensaje` VARCHAR(255),
    OUT `resultado` INT
)
BEGIN
    DECLARE existe INT DEFAULT 0;

    -- Verificar si ya existe una marca con ese nombre
    SELECT COUNT(*) INTO existe FROM marca WHERE NOMBRE = p_nombre;

    IF existe > 0 THEN
        SET mensaje = 'Ya existe una marca con ese nombre';
        SET resultado = 0;
    ELSE
        INSERT INTO marca (
            NOMBRE,
            DESCRIPCION,
            LOGO_URL,
            CLOUDINARY_PUBLIC_ID,
            ACTIVO,
            FECHA_REGISTRO
        ) VALUES (
            p_nombre,
            p_descripcion,
            p_logo_url,
            p_cloudinary_public_id,
            1,
            NOW()
        );

        SET resultado = LAST_INSERT_ID();
        SET mensaje = 'Marca creada exitosamente';
    END IF;
END//
DELIMITER ;

-- =============================================
-- ACTUALIZAR
-- =============================================

DROP PROCEDURE IF EXISTS `editar_marca`;
DELIMITER //
CREATE PROCEDURE `editar_marca`(
    IN `p_id` INT,
    IN `p_nombre` VARCHAR(100),
    IN `p_descripcion` VARCHAR(255),
    IN `p_logo_url` VARCHAR(500),
    IN `p_cloudinary_public_id` VARCHAR(255),
    OUT `mensaje` VARCHAR(255),
    OUT `resultado` INT
)
BEGIN
    DECLARE existe INT DEFAULT 0;
    DECLARE nombre_duplicado INT DEFAULT 0;

    -- Verificar que existe la marca
    SELECT COUNT(*) INTO existe FROM marca WHERE PK_ID_MARCA = p_id;

    IF existe = 0 THEN
        SET mensaje = 'Marca no encontrada';
        SET resultado = 0;
    ELSE
        -- Verificar que no hay otra marca con el mismo nombre
        SELECT COUNT(*) INTO nombre_duplicado
        FROM marca
        WHERE NOMBRE = p_nombre AND PK_ID_MARCA != p_id;

        IF nombre_duplicado > 0 THEN
            SET mensaje = 'Ya existe otra marca con ese nombre';
            SET resultado = 0;
        ELSE
            UPDATE marca
            SET NOMBRE = p_nombre,
                DESCRIPCION = p_descripcion,
                LOGO_URL = COALESCE(p_logo_url, LOGO_URL),
                CLOUDINARY_PUBLIC_ID = COALESCE(p_cloudinary_public_id, CLOUDINARY_PUBLIC_ID)
            WHERE PK_ID_MARCA = p_id;

            SET mensaje = 'Marca actualizada exitosamente';
            SET resultado = 1;
        END IF;
    END IF;
END//
DELIMITER ;

-- =============================================
-- ELIMINAR
-- =============================================

-- Soft delete
DROP PROCEDURE IF EXISTS `eliminar_marca`;
DELIMITER //
CREATE PROCEDURE `eliminar_marca`(
    IN `p_id` INT,
    OUT `mensaje` VARCHAR(255),
    OUT `resultado` INT,
    OUT `public_id` VARCHAR(255)
)
BEGIN
    DECLARE existe INT DEFAULT 0;
    DECLARE productos_asociados INT DEFAULT 0;

    -- Obtener public_id antes de desactivar
    SELECT CLOUDINARY_PUBLIC_ID INTO public_id
    FROM marca
    WHERE PK_ID_MARCA = p_id;

    -- Verificar que existe la marca
    SELECT COUNT(*) INTO existe FROM marca WHERE PK_ID_MARCA = p_id;

    IF existe = 0 THEN
        SET mensaje = 'Marca no encontrada';
        SET resultado = 0;
        SET public_id = NULL;
    ELSE
        -- Verificar si tiene productos asociados
        SELECT COUNT(*) INTO productos_asociados
        FROM producto
        WHERE FK_ID_MARCA = p_id;

        IF productos_asociados > 0 THEN
            -- Soft delete si tiene productos
            UPDATE marca SET ACTIVO = 0 WHERE PK_ID_MARCA = p_id;
            SET mensaje = 'Marca desactivada (tiene productos asociados)';
            SET resultado = 1;
        ELSE
            -- Hard delete si no tiene productos
            DELETE FROM marca WHERE PK_ID_MARCA = p_id;
            SET mensaje = 'Marca eliminada exitosamente';
            SET resultado = 1;
        END IF;
    END IF;
END//
DELIMITER ;

-- Reactivar marca
DROP PROCEDURE IF EXISTS `activar_marca`;
DELIMITER //
CREATE PROCEDURE `activar_marca`(
    IN `p_id` INT,
    OUT `mensaje` VARCHAR(255),
    OUT `resultado` INT
)
BEGIN
    DECLARE existe INT DEFAULT 0;

    SELECT COUNT(*) INTO existe FROM marca WHERE PK_ID_MARCA = p_id;

    IF existe = 0 THEN
        SET mensaje = 'Marca no encontrada';
        SET resultado = 0;
    ELSE
        UPDATE marca SET ACTIVO = 1 WHERE PK_ID_MARCA = p_id;
        SET mensaje = 'Marca activada exitosamente';
        SET resultado = 1;
    END IF;
END//
DELIMITER ;

-- =============================================
-- PERMISOS
-- =============================================

-- Crear permiso para administrar marcas
INSERT INTO permiso (PK_ID_PERMISO, NOMBRE_PERMISO, ESTADO_PERMISO)
VALUES (11, 'Administrar Marcas', 1)
ON DUPLICATE KEY UPDATE NOMBRE_PERMISO = 'Administrar Marcas';

-- Asignar a Administrador (rol 1) y Director de Proyecto (rol 8)
INSERT INTO permiso_de_rol (PFK_ID_ROL, PFK_ID_PERMISO, ESTADO_PERMISO_ROL)
VALUES (1, 11, 1)
ON DUPLICATE KEY UPDATE ESTADO_PERMISO_ROL = 1;

INSERT INTO permiso_de_rol (PFK_ID_ROL, PFK_ID_PERMISO, ESTADO_PERMISO_ROL)
VALUES (8, 11, 1)
ON DUPLICATE KEY UPDATE ESTADO_PERMISO_ROL = 1;

SELECT 'Migración 013 completada - Stored procedures de marcas y permisos creados' AS resultado;
