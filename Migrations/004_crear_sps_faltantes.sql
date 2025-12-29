-- ============================================================
-- Migración 004: Crear SPs faltantes
-- NOTA: Ejecutar en MySQL Workbench o cliente que soporte DELIMITER
-- ============================================================

-- =====================================================
-- SP: consultar_usuarios
-- =====================================================
DROP PROCEDURE IF EXISTS consultar_usuarios;

CREATE PROCEDURE consultar_usuarios(IN id_usuario INT)
BEGIN
    SELECT
        u.PK_ID_USUARIO,
        u.NOMBRES,
        u.APELLIDOS,
        u.TELEFONO,
        u.NOMBRE_USUARIO AS CORREO,
        u.ESTADO,
        u.DOCUMENTO_IDENTIDAD,
        u.FK_ID_TIPO_DOCUMENTO,
        u.CODIGO_REFERIDO,
        u.FECHA_REGISTRO
    FROM usuario u
    WHERE id_usuario IS NULL
       OR id_usuario = 0
       OR u.PK_ID_USUARIO = id_usuario
    ORDER BY u.PK_ID_USUARIO DESC;
END;

-- =====================================================
-- SP: consultar_negocio_usuario
-- =====================================================
DROP PROCEDURE IF EXISTS consultar_negocio_usuario;

CREATE PROCEDURE consultar_negocio_usuario(IN p_id_usuario INT)
BEGIN
    SELECT
        l.PK_ID_LOCAL,
        l.FK_ID_USUARIO,
        l.FK_ID_ESTADO_LOCAL,
        l.NOMBRE_LOCAL,
        l.LOCALIZACION,
        l.DIRECCION_LOCAL,
        l.TELEFONO_LOCAL,
        l.FOTOS_LOCAL,
        l.CLOUDINARY_PUBLIC_ID_LOGOTIPO,
        l.BANNER_LOCAL,
        l.DESCRIPCION_LOCAL,
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
        l.FK_ID_SUSCRIPCION_ACTIVA
    FROM `local` l
    WHERE l.FK_ID_USUARIO = p_id_usuario
    LIMIT 1;
END;

-- =====================================================
-- SP: asignar_rol
-- =====================================================
DROP PROCEDURE IF EXISTS asignar_rol;

CREATE PROCEDURE asignar_rol(IN p_id_usuario INT, IN p_id_rol INT)
BEGIN
    INSERT IGNORE INTO usuario_permiso (FK_ID_USUARIO, FK_ID_PERMISO, ORIGEN, ESTADO)
    SELECT
        p_id_usuario,
        rp.FK_ID_PERMISO,
        CONCAT('ROL_', p_id_rol),
        1
    FROM rol_permiso rp
    WHERE rp.FK_ID_ROL = p_id_rol
      AND rp.ESTADO = 1;

    SELECT ROW_COUNT() AS permisos_asignados;
END;

SELECT 'MIGRACIÓN 004 - SPs faltantes creados' as info;
