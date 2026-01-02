-- Migración 026: SP para obtener permisos de múltiples membresías en una sola consulta
-- Optimización para evitar consultas N+1

DELIMITER //

DROP PROCEDURE IF EXISTS obtener_permisos_membresias_bulk//

CREATE PROCEDURE obtener_permisos_membresias_bulk(
    IN p_ids_membresias TEXT
)
BEGIN
    SELECT
        mp.FK_ID_TIPO_MEMBRESIA,
        p.PK_ID_PERMISO,
        p.CODIGO,
        p.NOMBRE,
        p.DESCRIPCION,
        p.ICONO,
        p.CATEGORIA,
        p.ORDEN
    FROM membresia_permiso mp
    INNER JOIN permiso_sistema p ON mp.FK_ID_PERMISO = p.PK_ID_PERMISO
    WHERE FIND_IN_SET(mp.FK_ID_TIPO_MEMBRESIA, p_ids_membresias) > 0
      AND mp.ESTADO = 1
    ORDER BY mp.FK_ID_TIPO_MEMBRESIA, p.ORDEN ASC;
END//

DELIMITER ;
