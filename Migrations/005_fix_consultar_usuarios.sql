-- ============================================================
-- Migración 005: Corregir SP consultar_usuarios
-- La tabla usuario no tiene FECHA_REGISTRO
-- ============================================================

DROP PROCEDURE IF EXISTS consultar_usuarios;

DELIMITER //
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
        u.CODIGO_REFERIDO
    FROM usuario u
    WHERE id_usuario IS NULL
       OR id_usuario = 0
       OR u.PK_ID_USUARIO = id_usuario
    ORDER BY u.PK_ID_USUARIO DESC;
END//
DELIMITER ;

SELECT 'MIGRACIÓN 005 - SP consultar_usuarios corregido' as info;
