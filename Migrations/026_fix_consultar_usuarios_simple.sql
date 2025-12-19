-- =============================================
-- Migración 026: Simplificar consultar_usuarios
-- Descripción: El código C# no usa NOMBRE_MEMBRESIA, así que eliminamos
--              los JOINs innecesarios que causan problemas con GROUP BY.
--              Esto también mejora el rendimiento de la consulta.
-- =============================================

DELIMITER //

DROP PROCEDURE IF EXISTS `consultar_usuarios`//

CREATE PROCEDURE `consultar_usuarios`(
    IN `id_usuario` INT
)
BEGIN
    SELECT
        u.PK_ID_USUARIO,
        COALESCE(p.PK_ID_PERSONA, 0) AS PK_ID_PERSONA,
        COALESCE(p.NOMBRES, '') AS NOMBRES,
        COALESCE(p.APELLIDOS, '') AS APELLIDOS,
        COALESCE(p.TELEFONO, '') AS TELEFONO,
        COALESCE(u.ESTADO, 0) AS ESTADO,
        COALESCE(r.NOMBRE_ROL, 'Sin rol') AS NOMBRE_ROL,
        COALESCE(p.CORREO, '') AS CORREO
    FROM usuario u
    LEFT JOIN persona p ON u.FK_ID_PERSONA = p.PK_ID_PERSONA
    LEFT JOIN rol r ON u.FK_ID_ROL = r.PK_ID_ROL
    WHERE (id_usuario = 0 OR u.PK_ID_USUARIO = id_usuario);
END//

DELIMITER ;
