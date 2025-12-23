-- =============================================
-- Migración 055: Agregar CloudinaryPublicId a categorías y locales
-- Fecha: 2025-12-22
-- Descripción: Agrega columnas para almacenar el PublicId de Cloudinary
--              necesario para eliminar imágenes anteriores al actualizar
-- =============================================

-- =============================================
-- PASO 1: Agregar columnas a tabla categoria
-- =============================================
ALTER TABLE `categoria`
ADD COLUMN `CLOUDINARY_PUBLIC_ID_IMAGEN` VARCHAR(255) DEFAULT NULL AFTER `BANNER_CATEGORIA`,
ADD COLUMN `CLOUDINARY_PUBLIC_ID_BANNER` VARCHAR(255) DEFAULT NULL AFTER `CLOUDINARY_PUBLIC_ID_IMAGEN`;

-- =============================================
-- PASO 2: Agregar columna a tabla local (para logotipo)
-- =============================================
ALTER TABLE `local`
ADD COLUMN `CLOUDINARY_PUBLIC_ID_LOGOTIPO` VARCHAR(255) DEFAULT NULL AFTER `FOTOS_LOCAL`;

-- =============================================
-- PASO 3: Actualizar SP crear_categoria
-- =============================================
DROP PROCEDURE IF EXISTS `crear_categoria`;
DELIMITER //
CREATE PROCEDURE `crear_categoria`(
    IN `p_nombre_categoria` VARCHAR(100),
    IN `p_estado_categoria` TINYINT,
    IN `p_imagen_categoria` VARCHAR(255),
    IN `p_cloudinary_public_id_imagen` VARCHAR(255),
    IN `p_banner_categoria` VARCHAR(255),
    IN `p_cloudinary_public_id_banner` VARCHAR(255),
    OUT `mensaje` VARCHAR(500)
)
BEGIN
    DECLARE categoria_existe INT;

    -- Verificar si ya existe una categoría con el mismo nombre
    SELECT COUNT(*) INTO categoria_existe FROM categoria WHERE NOMBRE_CATEGORIA = p_nombre_categoria;

    IF categoria_existe = 0 THEN
        -- Insertar la nueva categoría
        INSERT INTO categoria (
            NOMBRE_CATEGORIA,
            ESTADO_CATEGORIA,
            IMAGEN_CATEGORIA,
            CLOUDINARY_PUBLIC_ID_IMAGEN,
            BANNER_CATEGORIA,
            CLOUDINARY_PUBLIC_ID_BANNER
        )
        VALUES (
            p_nombre_categoria,
            p_estado_categoria,
            p_imagen_categoria,
            p_cloudinary_public_id_imagen,
            p_banner_categoria,
            p_cloudinary_public_id_banner
        );
        SET mensaje = 'Categoría creada con éxito.';
    ELSE
        SET mensaje = 'La categoría con el nombre especificado ya existe.';
    END IF;
END//
DELIMITER ;

-- =============================================
-- PASO 4: Actualizar SP editar_categoria
-- =============================================
DROP PROCEDURE IF EXISTS `editar_categoria`;
DELIMITER //
CREATE PROCEDURE `editar_categoria`(
    IN `p_id_categoria` INT,
    IN `p_nombre_categoria` VARCHAR(100),
    IN `p_estado_categoria` TINYINT,
    IN `p_imagen_categoria` VARCHAR(255),
    IN `p_cloudinary_public_id_imagen` VARCHAR(255),
    IN `p_banner_categoria` VARCHAR(255),
    IN `p_cloudinary_public_id_banner` VARCHAR(255),
    OUT `mensaje` VARCHAR(500)
)
BEGIN
    IF EXISTS (SELECT 1 FROM categoria WHERE PK_ID_CATEGORIA = p_id_categoria) THEN
        -- Actualizar la categoría
        UPDATE categoria
        SET
           NOMBRE_CATEGORIA = p_nombre_categoria,
           ESTADO_CATEGORIA = p_estado_categoria,
           IMAGEN_CATEGORIA = p_imagen_categoria,
           CLOUDINARY_PUBLIC_ID_IMAGEN = p_cloudinary_public_id_imagen,
           BANNER_CATEGORIA = p_banner_categoria,
           CLOUDINARY_PUBLIC_ID_BANNER = p_cloudinary_public_id_banner
        WHERE PK_ID_CATEGORIA = p_id_categoria;

        SET mensaje = 'Categoría actualizada con éxito.';
    ELSE
        SET mensaje = 'La categoría especificada no existe.';
    END IF;
END//
DELIMITER ;

-- =============================================
-- PASO 5: Actualizar SP editar_local para incluir cloudinary_public_id_logotipo
-- =============================================
DROP PROCEDURE IF EXISTS `editar_local`;
DELIMITER //
CREATE PROCEDURE `editar_local`(
    IN p_id_local INT,
    IN p_nombre_local VARCHAR(100),
    IN p_direccion_local VARCHAR(200),
    IN p_localizacion_local VARCHAR(100),
    IN p_telefono_local VARCHAR(20),
    IN p_fotos_local LONGTEXT,
    IN p_cloudinary_public_id_logotipo VARCHAR(255),
    IN p_descripcion_local VARCHAR(1000),
    IN p_banner_local VARCHAR(50),
    IN p_email_contacto VARCHAR(100),
    IN p_whatsapp VARCHAR(20),
    IN p_sitio_web VARCHAR(255),
    IN p_nit VARCHAR(20),
    IN p_instagram VARCHAR(100),
    IN p_facebook VARCHAR(255),
    IN p_tiktok VARCHAR(100),
    IN p_youtube VARCHAR(255),
    IN p_twitter VARCHAR(100),
    IN p_horario_lunes VARCHAR(20),
    IN p_horario_martes VARCHAR(20),
    IN p_horario_miercoles VARCHAR(20),
    IN p_horario_jueves VARCHAR(20),
    IN p_horario_viernes VARCHAR(20),
    IN p_horario_sabado VARCHAR(20),
    IN p_horario_domingo VARCHAR(20),
    IN p_latitud DECIMAL(10,8),
    IN p_longitud DECIMAL(11,8)
)
BEGIN
    UPDATE `local` SET
        NOMBRE_LOCAL = p_nombre_local,
        DIRECCION_LOCAL = p_direccion_local,
        LOCALIZACION = p_localizacion_local,
        TELEFONO_LOCAL = p_telefono_local,
        FOTOS_LOCAL = p_fotos_local,
        CLOUDINARY_PUBLIC_ID_LOGOTIPO = p_cloudinary_public_id_logotipo,
        DESCRIPCION_LOCAL = p_descripcion_local,
        BANNER_LOCAL = p_banner_local,
        EMAIL_CONTACTO = p_email_contacto,
        WHATSAPP = p_whatsapp,
        SITIO_WEB = p_sitio_web,
        NIT = p_nit,
        INSTAGRAM = p_instagram,
        FACEBOOK = p_facebook,
        TIKTOK = p_tiktok,
        YOUTUBE = p_youtube,
        TWITTER = p_twitter,
        HORARIO_LUNES = p_horario_lunes,
        HORARIO_MARTES = p_horario_martes,
        HORARIO_MIERCOLES = p_horario_miercoles,
        HORARIO_JUEVES = p_horario_jueves,
        HORARIO_VIERNES = p_horario_viernes,
        HORARIO_SABADO = p_horario_sabado,
        HORARIO_DOMINGO = p_horario_domingo,
        LATITUD = p_latitud,
        LONGITUD = p_longitud,
        FECHA_ACTUALIZACION = NOW()
    WHERE PK_ID_LOCAL = p_id_local;
END//
DELIMITER ;
