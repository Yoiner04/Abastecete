-- =============================================
-- Migración 022: Actualizar consultar_usuarios para nueva estructura
-- Descripción: El SP consultar_usuarios usaba FK_ID_TIPOMEMBRESIA de la tabla local,
--              pero esa columna fue eliminada en la migración 020.
--              Además, el SP no tenía parámetro pero el código lo esperaba.
-- =============================================

DELIMITER //

DROP PROCEDURE IF EXISTS `consultar_usuarios`//

CREATE PROCEDURE `consultar_usuarios`(
    IN `id_usuario` INT
)
BEGIN
    SELECT
        u.PK_ID_USUARIO,
        p.PK_ID_PERSONA,
        p.NOMBRES,
        p.APELLIDOS,
        p.TELEFONO,
        u.ESTADO,
        r.NOMBRE_ROL,
        p.CORREO,
        IFNULL(tm.NOMBRE, 'Sin membresía') AS NOMBRE_MEMBRESIA
    FROM usuario u
    LEFT JOIN persona p ON u.FK_ID_PERSONA = p.PK_ID_PERSONA
    LEFT JOIN rol r ON u.FK_ID_ROL = r.PK_ID_ROL
    LEFT JOIN local l ON l.FK_ID_PERSONA = p.PK_ID_PERSONA
    LEFT JOIN suscripcion s ON l.FK_ID_SUSCRIPCION_ACTIVA = s.PK_ID_SUSCRIPCION AND s.ESTADO = 1
    LEFT JOIN tipo_membresia tm ON s.FK_ID_TIPO_MEMBRESIA = tm.PK_ID_TIPO_MEMBRESIA
    WHERE (id_usuario = 0 OR u.PK_ID_USUARIO = id_usuario);
END//

DELIMITER ;
