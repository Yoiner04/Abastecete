-- =============================================
-- Migración 033: Expansión de tabla local
-- Fecha: 2025-12-20
-- Descripción: Agrega campos para redes sociales, horarios,
--              contacto adicional y crea tabla de galería
-- =============================================

-- =============================================
-- PARTE 1: Expandir campo DESCRIPCION_LOCAL
-- =============================================

ALTER TABLE `local`
MODIFY COLUMN `DESCRIPCION_LOCAL` VARCHAR(1000) DEFAULT NULL;

-- =============================================
-- PARTE 2: Agregar campos de contacto
-- =============================================

ALTER TABLE `local`
ADD COLUMN `EMAIL_CONTACTO` VARCHAR(100) DEFAULT NULL AFTER `DESCRIPCION_LOCAL`,
ADD COLUMN `WHATSAPP` VARCHAR(20) DEFAULT NULL AFTER `EMAIL_CONTACTO`,
ADD COLUMN `SITIO_WEB` VARCHAR(255) DEFAULT NULL AFTER `WHATSAPP`,
ADD COLUMN `NIT` VARCHAR(20) DEFAULT NULL AFTER `SITIO_WEB`;

-- =============================================
-- PARTE 3: Agregar campos de redes sociales
-- =============================================

ALTER TABLE `local`
ADD COLUMN `INSTAGRAM` VARCHAR(100) DEFAULT NULL AFTER `NIT`,
ADD COLUMN `FACEBOOK` VARCHAR(255) DEFAULT NULL AFTER `INSTAGRAM`,
ADD COLUMN `TIKTOK` VARCHAR(100) DEFAULT NULL AFTER `FACEBOOK`,
ADD COLUMN `YOUTUBE` VARCHAR(255) DEFAULT NULL AFTER `TIKTOK`,
ADD COLUMN `TWITTER` VARCHAR(100) DEFAULT NULL AFTER `YOUTUBE`;

-- =============================================
-- PARTE 4: Agregar campos de horario estructurado
-- =============================================

ALTER TABLE `local`
ADD COLUMN `HORARIO_LUNES` VARCHAR(20) DEFAULT NULL AFTER `TWITTER`,
ADD COLUMN `HORARIO_MARTES` VARCHAR(20) DEFAULT NULL AFTER `HORARIO_LUNES`,
ADD COLUMN `HORARIO_MIERCOLES` VARCHAR(20) DEFAULT NULL AFTER `HORARIO_MARTES`,
ADD COLUMN `HORARIO_JUEVES` VARCHAR(20) DEFAULT NULL AFTER `HORARIO_MIERCOLES`,
ADD COLUMN `HORARIO_VIERNES` VARCHAR(20) DEFAULT NULL AFTER `HORARIO_JUEVES`,
ADD COLUMN `HORARIO_SABADO` VARCHAR(20) DEFAULT NULL AFTER `HORARIO_VIERNES`,
ADD COLUMN `HORARIO_DOMINGO` VARCHAR(20) DEFAULT NULL AFTER `HORARIO_SABADO`;

-- =============================================
-- PARTE 5: Agregar coordenadas GPS separadas
-- =============================================

ALTER TABLE `local`
ADD COLUMN `LATITUD` DECIMAL(10,8) DEFAULT NULL AFTER `HORARIO_DOMINGO`,
ADD COLUMN `LONGITUD` DECIMAL(11,8) DEFAULT NULL AFTER `LATITUD`;

-- =============================================
-- PARTE 6: Agregar campos de auditoría
-- =============================================

ALTER TABLE `local`
ADD COLUMN `FECHA_REGISTRO` DATETIME DEFAULT CURRENT_TIMESTAMP AFTER `LONGITUD`,
ADD COLUMN `FECHA_ACTUALIZACION` DATETIME DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP AFTER `FECHA_REGISTRO`;

-- Poblar FECHA_REGISTRO para registros existentes
UPDATE `local` SET FECHA_REGISTRO = NOW() WHERE FECHA_REGISTRO IS NULL;

-- =============================================
-- PARTE 7: Crear tabla de galería de imágenes
-- =============================================

CREATE TABLE IF NOT EXISTS `galeria_local` (
    `PK_ID_GALERIA` INT NOT NULL AUTO_INCREMENT,
    `FK_ID_LOCAL` INT NOT NULL,
    `CLOUDINARY_URL` VARCHAR(500) NOT NULL,
    `CLOUDINARY_PUBLIC_ID` VARCHAR(255) DEFAULT NULL,
    `ESTADO` INT DEFAULT 0 COMMENT '0=Pendiente, 1=Aprobada, 2=Rechazada',
    `FECHA_SUBIDA` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `FECHA_REVISION` DATETIME DEFAULT NULL,
    `FK_ID_USUARIO_REVISOR` INT DEFAULT NULL,
    `MOTIVO_RECHAZO` VARCHAR(255) DEFAULT NULL,
    PRIMARY KEY (`PK_ID_GALERIA`),
    KEY `idx_galeria_local` (`FK_ID_LOCAL`),
    KEY `idx_galeria_estado` (`ESTADO`),
    CONSTRAINT `FK_galeria_local` FOREIGN KEY (`FK_ID_LOCAL`) REFERENCES `local` (`PK_ID_LOCAL`) ON DELETE CASCADE,
    CONSTRAINT `FK_galeria_revisor` FOREIGN KEY (`FK_ID_USUARIO_REVISOR`) REFERENCES `usuario` (`PK_ID_USUARIO`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================
-- PARTE 8: Actualizar SP editar_local
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

-- =============================================
-- PARTE 9: Actualizar SP consultar_negocio
-- =============================================

DROP PROCEDURE IF EXISTS `consultar_negocio`;

DELIMITER //
CREATE PROCEDURE `consultar_negocio`(
    IN p_id_persona INT
)
BEGIN
    SELECT
        l.PK_ID_LOCAL,
        l.NOMBRE_LOCAL,
        l.LOCALIZACION,
        l.DIRECCION_LOCAL,
        l.TELEFONO_LOCAL,
        l.FOTOS_LOCAL,
        l.DESCRIPCION_LOCAL,
        l.BANNER_LOCAL,
        l.FK_ID_ESTADO_LOCAL,
        l.EMAIL_CONTACTO,
        l.WHATSAPP,
        l.SITIO_WEB,
        l.NIT,
        l.INSTAGRAM,
        l.FACEBOOK,
        l.TIKTOK,
        l.YOUTUBE,
        l.TWITTER,
        l.HORARIO_LUNES,
        l.HORARIO_MARTES,
        l.HORARIO_MIERCOLES,
        l.HORARIO_JUEVES,
        l.HORARIO_VIERNES,
        l.HORARIO_SABADO,
        l.HORARIO_DOMINGO,
        l.LATITUD,
        l.LONGITUD,
        l.FECHA_REGISTRO,
        l.FECHA_ACTUALIZACION,
        s.PK_ID_SUSCRIPCION,
        s.FK_ID_TIPO_MEMBRESIA,
        s.FECHA_INICIO AS SUSCRIPCION_FECHA_INICIO,
        s.FECHA_FIN AS SUSCRIPCION_FECHA_FIN,
        s.ESTADO AS SUSCRIPCION_ESTADO,
        tm.NOMBRE AS TIPO_MEMBRESIA_NOMBRE
    FROM `local` l
    LEFT JOIN suscripcion s ON s.PK_ID_SUSCRIPCION = l.FK_ID_SUSCRIPCION_ACTIVA
    LEFT JOIN tipo_membresia tm ON tm.PK_ID_TIPO_MEMBRESIA = s.FK_ID_TIPO_MEMBRESIA
    WHERE l.FK_ID_PERSONA = p_id_persona
    LIMIT 1;
END//
DELIMITER ;

-- =============================================
-- PARTE 10: SPs para galería de imágenes
-- =============================================

-- Agregar imagen a galería
DROP PROCEDURE IF EXISTS `agregar_imagen_galeria`;

DELIMITER //
CREATE PROCEDURE `agregar_imagen_galeria`(
    IN p_id_local INT,
    IN p_cloudinary_url VARCHAR(500),
    IN p_cloudinary_public_id VARCHAR(255)
)
BEGIN
    INSERT INTO galeria_local (FK_ID_LOCAL, CLOUDINARY_URL, CLOUDINARY_PUBLIC_ID, ESTADO, FECHA_SUBIDA)
    VALUES (p_id_local, p_cloudinary_url, p_cloudinary_public_id, 0, NOW());

    SELECT LAST_INSERT_ID() AS id_galeria;
END//
DELIMITER ;

-- Listar imágenes de galería por local
DROP PROCEDURE IF EXISTS `listar_galeria_local`;

DELIMITER //
CREATE PROCEDURE `listar_galeria_local`(
    IN p_id_local INT
)
BEGIN
    SELECT
        PK_ID_GALERIA,
        FK_ID_LOCAL,
        CLOUDINARY_URL,
        CLOUDINARY_PUBLIC_ID,
        ESTADO,
        FECHA_SUBIDA,
        FECHA_REVISION,
        FK_ID_USUARIO_REVISOR,
        MOTIVO_RECHAZO
    FROM galeria_local
    WHERE FK_ID_LOCAL = p_id_local
    ORDER BY FECHA_SUBIDA DESC;
END//
DELIMITER ;

-- Aprobar/Rechazar imagen (para admin)
DROP PROCEDURE IF EXISTS `revisar_imagen_galeria`;

DELIMITER //
CREATE PROCEDURE `revisar_imagen_galeria`(
    IN p_id_galeria INT,
    IN p_estado INT,
    IN p_id_revisor INT,
    IN p_motivo_rechazo VARCHAR(255)
)
BEGIN
    UPDATE galeria_local SET
        ESTADO = p_estado,
        FECHA_REVISION = NOW(),
        FK_ID_USUARIO_REVISOR = p_id_revisor,
        MOTIVO_RECHAZO = CASE WHEN p_estado = 2 THEN p_motivo_rechazo ELSE NULL END
    WHERE PK_ID_GALERIA = p_id_galeria;
END//
DELIMITER ;

-- Eliminar imagen de galería
DROP PROCEDURE IF EXISTS `eliminar_imagen_galeria`;

DELIMITER //
CREATE PROCEDURE `eliminar_imagen_galeria`(
    IN p_id_galeria INT
)
BEGIN
    SELECT CLOUDINARY_PUBLIC_ID INTO @public_id FROM galeria_local WHERE PK_ID_GALERIA = p_id_galeria;
    DELETE FROM galeria_local WHERE PK_ID_GALERIA = p_id_galeria;
    SELECT @public_id AS cloudinary_public_id;
END//
DELIMITER ;

-- Listar imágenes pendientes de revisión (para admin)
DROP PROCEDURE IF EXISTS `listar_galeria_pendientes`;

DELIMITER //
CREATE PROCEDURE `listar_galeria_pendientes`()
BEGIN
    SELECT
        g.PK_ID_GALERIA,
        g.FK_ID_LOCAL,
        g.CLOUDINARY_URL,
        g.CLOUDINARY_PUBLIC_ID,
        g.ESTADO,
        g.FECHA_SUBIDA,
        l.NOMBRE_LOCAL,
        p.NOMBRES AS PROPIETARIO_NOMBRE,
        p.APELLIDOS AS PROPIETARIO_APELLIDO
    FROM galeria_local g
    INNER JOIN `local` l ON l.PK_ID_LOCAL = g.FK_ID_LOCAL
    INNER JOIN persona p ON p.PK_ID_PERSONA = l.FK_ID_PERSONA
    WHERE g.ESTADO = 0
    ORDER BY g.FECHA_SUBIDA ASC;
END//
DELIMITER ;

-- Contar imágenes pendientes (para badge en admin)
DROP PROCEDURE IF EXISTS `contar_galeria_pendientes`;

DELIMITER //
CREATE PROCEDURE `contar_galeria_pendientes`()
BEGIN
    SELECT COUNT(*) AS total_pendientes FROM galeria_local WHERE ESTADO = 0;
END//
DELIMITER ;

-- =============================================
-- PARTE 11: Crear permiso para administrar galería
-- =============================================

-- Agregar permiso para administrar galería de locales
INSERT INTO permiso (NOMBRE_PERMISO, ESTADO_PERMISO)
SELECT 'Administrar Galeria', 1
WHERE NOT EXISTS (SELECT 1 FROM permiso WHERE NOMBRE_PERMISO = 'Administrar Galeria');

-- Asignar permiso al rol Administrador (ID 1)
INSERT INTO permiso_de_rol (PFK_ID_ROL, PFK_ID_PERMISO, ESTADO_PERMISO_ROL)
SELECT 1, PK_ID_PERMISO, 1
FROM permiso
WHERE NOMBRE_PERMISO = 'Administrar Galeria'
AND NOT EXISTS (
    SELECT 1 FROM permiso_de_rol pr
    INNER JOIN permiso p ON pr.PFK_ID_PERMISO = p.PK_ID_PERMISO
    WHERE p.NOMBRE_PERMISO = 'Administrar Galeria' AND pr.PFK_ID_ROL = 1
);

-- =============================================
-- PARTE 12: Actualizar SP crear_local con campos nuevos
-- =============================================

DROP PROCEDURE IF EXISTS `crear_local`;

DELIMITER //
CREATE PROCEDURE `crear_local`(
    IN p_fk_id_persona INT,
    IN p_fk_id_estado_local INT,
    IN p_fk_id_tipomembresia INT,
    IN p_localizacion VARCHAR(100),
    IN p_nombre_local VARCHAR(100),
    IN p_direccion_local VARCHAR(200),
    IN p_telefono_local BIGINT,
    IN p_fotos_local VARCHAR(255),
    IN p_descripcion_local VARCHAR(1000),
    -- Campos nuevos de contacto
    IN p_email_contacto VARCHAR(100),
    IN p_whatsapp VARCHAR(20),
    IN p_sitio_web VARCHAR(255),
    -- Redes sociales
    IN p_instagram VARCHAR(100),
    IN p_facebook VARCHAR(255),
    IN p_tiktok VARCHAR(100),
    IN p_youtube VARCHAR(255),
    IN p_twitter VARCHAR(100),
    -- Horarios
    IN p_horario_lunes VARCHAR(20),
    IN p_horario_martes VARCHAR(20),
    IN p_horario_miercoles VARCHAR(20),
    IN p_horario_jueves VARCHAR(20),
    IN p_horario_viernes VARCHAR(20),
    IN p_horario_sabado VARCHAR(20),
    IN p_horario_domingo VARCHAR(20)
)
BEGIN
    DECLARE v_id_local INT;

    INSERT INTO `local` (
        FK_ID_PERSONA,
        FK_ID_ESTADO_LOCAL,
        LOCALIZACION,
        NOMBRE_LOCAL,
        DIRECCION_LOCAL,
        TELEFONO_LOCAL,
        FOTOS_LOCAL,
        DESCRIPCION_LOCAL,
        EMAIL_CONTACTO,
        WHATSAPP,
        SITIO_WEB,
        INSTAGRAM,
        FACEBOOK,
        TIKTOK,
        YOUTUBE,
        TWITTER,
        HORARIO_LUNES,
        HORARIO_MARTES,
        HORARIO_MIERCOLES,
        HORARIO_JUEVES,
        HORARIO_VIERNES,
        HORARIO_SABADO,
        HORARIO_DOMINGO,
        FECHA_REGISTRO
    ) VALUES (
        p_fk_id_persona,
        p_fk_id_estado_local,
        p_localizacion,
        p_nombre_local,
        p_direccion_local,
        p_telefono_local,
        p_fotos_local,
        p_descripcion_local,
        p_email_contacto,
        p_whatsapp,
        p_sitio_web,
        p_instagram,
        p_facebook,
        p_tiktok,
        p_youtube,
        p_twitter,
        p_horario_lunes,
        p_horario_martes,
        p_horario_miercoles,
        p_horario_jueves,
        p_horario_viernes,
        p_horario_sabado,
        p_horario_domingo,
        NOW()
    );

    SET v_id_local = LAST_INSERT_ID();

    -- Crear suscripción inicial (si se pasa tipo membresía)
    IF p_fk_id_tipomembresia IS NOT NULL AND p_fk_id_tipomembresia > 0 THEN
        INSERT INTO suscripcion (
            FK_ID_LOCAL,
            FK_ID_TIPO_MEMBRESIA,
            FECHA_INICIO,
            FECHA_FIN,
            ESTADO
        ) VALUES (
            v_id_local,
            p_fk_id_tipomembresia,
            NOW(),
            DATE_ADD(NOW(), INTERVAL 30 DAY),
            'Activa'
        );
    END IF;

    SELECT v_id_local AS id_local;
END//
DELIMITER ;

-- =============================================
-- Verificación final
-- =============================================
SELECT 'Migración 033 completada: Tabla local expandida, galería creada, permisos agregados y SP crear_local actualizado' AS resultado;
