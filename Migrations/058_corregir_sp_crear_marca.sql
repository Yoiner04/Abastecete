-- =============================================
-- Migración 058: Corregir SP crear_marca
-- Fecha: 2025-12-23
-- Descripción: Modifica el SP para hacer SELECT al final en lugar de usar
--              parámetros OUT, para que sea compatible con EjecutarTransaccion
-- =============================================

DROP PROCEDURE IF EXISTS `crear_marca`;
DELIMITER //
CREATE PROCEDURE `crear_marca`(
    IN `p_nombre` VARCHAR(100),
    IN `p_descripcion` VARCHAR(255),
    IN `p_logo_url` VARCHAR(500),
    IN `p_cloudinary_public_id` VARCHAR(255)
)
BEGIN
    DECLARE v_existe INT DEFAULT 0;
    DECLARE v_resultado INT DEFAULT 0;
    DECLARE v_mensaje VARCHAR(255) DEFAULT '';

    -- Verificar si ya existe una marca con ese nombre
    SELECT COUNT(*) INTO v_existe FROM marca WHERE NOMBRE = p_nombre;

    IF v_existe > 0 THEN
        SET v_mensaje = 'Ya existe una marca con ese nombre';
        SET v_resultado = 0;
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

        SET v_resultado = LAST_INSERT_ID();
        SET v_mensaje = 'Marca creada exitosamente';
    END IF;

    -- Retornar resultado como SELECT (compatible con EjecutarTransaccion)
    SELECT v_resultado AS resultado, v_mensaje AS mensaje;
END//
DELIMITER ;

SELECT 'Migración 058 completada - SP crear_marca corregido' AS resultado;
