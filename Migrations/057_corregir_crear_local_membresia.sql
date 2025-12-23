-- =============================================
-- Migración 057: Corregir SP crear_local - ESTADO debe ser 1, no 'Activa'
-- Fecha: 2025-12-22
-- Descripción: Corrige el INSERT de suscripción para usar ESTADO = 1 (numérico)
--              en lugar de 'Activa' (texto) que causa error de tipo
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
    -- CORREGIDO: ESTADO debe ser 1 (numérico), no 'Activa' (texto)
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
            1  -- 1 = Activa (era 'Activa' texto, causaba error)
        );
    END IF;

    SELECT v_id_local AS id_local;
END//
DELIMITER ;
