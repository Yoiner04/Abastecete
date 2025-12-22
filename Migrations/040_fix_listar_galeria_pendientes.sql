-- =============================================
-- Migración 040: Corregir SP listar_galeria_pendientes
-- Fecha: 2025-12-21
-- Problema: El SP no incluía las columnas FECHA_REVISION,
--           FK_ID_USUARIO_REVISOR y MOTIVO_RECHAZO que espera
--           el método MapearGaleria en C#
-- =============================================

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
        g.FECHA_REVISION,
        g.FK_ID_USUARIO_REVISOR,
        g.MOTIVO_RECHAZO,
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
