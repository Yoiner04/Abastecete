-- =============================================
-- Migración 025: Corregir consultar_usuarios para evitar errores de constraints
-- Descripción: Asegurar que no haya valores NULL que causen problemas en DataTable
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
        COALESCE(p.CORREO, '') AS CORREO,
        COALESCE(tm.NOMBRE, 'Sin membresía') AS NOMBRE_MEMBRESIA
    FROM usuario u
    LEFT JOIN persona p ON u.FK_ID_PERSONA = p.PK_ID_PERSONA
    LEFT JOIN rol r ON u.FK_ID_ROL = r.PK_ID_ROL
    LEFT JOIN local l ON l.FK_ID_PERSONA = p.PK_ID_PERSONA
    LEFT JOIN suscripcion s ON l.FK_ID_SUSCRIPCION_ACTIVA = s.PK_ID_SUSCRIPCION AND s.ESTADO = 1
    LEFT JOIN tipo_membresia tm ON s.FK_ID_TIPO_MEMBRESIA = tm.PK_ID_TIPO_MEMBRESIA
    WHERE (id_usuario = 0 OR u.PK_ID_USUARIO = id_usuario)
    GROUP BY u.PK_ID_USUARIO;
END//

DELIMITER ;
