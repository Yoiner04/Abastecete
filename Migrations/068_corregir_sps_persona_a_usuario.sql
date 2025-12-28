-- Migración 068: Corregir SPs que usan FK_ID_PERSONA a FK_ID_USUARIO
-- ============================================================
-- La tabla local ahora usa FK_ID_USUARIO en lugar de FK_ID_PERSONA
-- Estos SPs estaban obsoletos y causaban errores
-- ============================================================

-- SP: consultar_local (corregido para usar FK_ID_USUARIO)
DROP PROCEDURE IF EXISTS consultar_local;
DELIMITER //
CREATE PROCEDURE consultar_local(
    IN p_id_usuario INT
)
BEGIN
    IF p_id_usuario = 0 THEN
        SELECT * FROM local;
    ELSE
        SELECT * FROM local WHERE FK_ID_USUARIO = p_id_usuario;
    END IF;
END//
DELIMITER ;

-- SP: consultar_local_por_persona_seguro -> renombrado a consultar_local_por_usuario_seguro
DROP PROCEDURE IF EXISTS consultar_local_por_persona_seguro;
DROP PROCEDURE IF EXISTS consultar_local_por_usuario_seguro;
DELIMITER //
CREATE PROCEDURE consultar_local_por_usuario_seguro(
    IN p_id_usuario INT,
    OUT mensaje VARCHAR(255),
    OUT resultado INT
)
BEGIN
    DECLARE local_existe INT DEFAULT 0;

    SELECT COUNT(*) INTO local_existe
    FROM local
    WHERE FK_ID_USUARIO = p_id_usuario;

    IF local_existe > 0 THEN
        SELECT * FROM local WHERE FK_ID_USUARIO = p_id_usuario LIMIT 1;
        SET mensaje = 'Local encontrado';
        SET resultado = 1;
    ELSE
        SET mensaje = 'No se encontró local para este usuario';
        SET resultado = 0;
        SELECT NULL AS PK_ID_LOCAL WHERE 1=0;
    END IF;
END//
DELIMITER ;

-- SP: consultar_negocio (corregido para usar FK_ID_USUARIO)
DROP PROCEDURE IF EXISTS consultar_negocio;
DELIMITER //
CREATE PROCEDURE consultar_negocio(
    IN p_id_usuario INT
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
        l.FK_ID_SUSCRIPCION_ACTIVA,
        l.CLOUDINARY_PUBLIC_ID_LOGOTIPO,
        tm.NOMBRE AS TIPO_MEMBRESIA,
        s.FECHA_FIN AS FECHA_FIN_MEMBRESIA,
        DATEDIFF(s.FECHA_FIN, NOW()) AS DIAS_RESTANTES
    FROM local l
    LEFT JOIN suscripcion s ON l.FK_ID_SUSCRIPCION_ACTIVA = s.PK_ID_SUSCRIPCION
    LEFT JOIN tipo_membresia tm ON s.FK_ID_TIPO_MEMBRESIA = tm.PK_ID_TIPO_MEMBRESIA
    WHERE l.FK_ID_USUARIO = p_id_usuario
    LIMIT 1;
END//
DELIMITER ;

-- Verificación
SELECT 'SPs corregidos:' as info;
SHOW PROCEDURE STATUS WHERE Db = DATABASE() AND Name IN ('consultar_local', 'consultar_local_por_usuario_seguro', 'consultar_negocio');
