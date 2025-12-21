-- =============================================
-- Migración 034: SP para buscar locales
-- Fecha: 2025-12-21
-- Descripción: Agrega stored procedure para buscar locales por nombre/descripción
-- =============================================

DROP PROCEDURE IF EXISTS `buscador_locales`;

DELIMITER //
CREATE PROCEDURE `buscador_locales`(
    IN p_busqueda VARCHAR(100)
)
BEGIN
    SELECT
        l.PK_ID_LOCAL,
        l.NOMBRE_LOCAL,
        l.DESCRIPCION_LOCAL,
        l.DIRECCION_LOCAL,
        l.TELEFONO_LOCAL,
        l.FOTOS_LOCAL,
        l.LOCALIZACION
    FROM `local` l
    WHERE l.FK_ID_ESTADO_LOCAL = 1
    AND (
        l.NOMBRE_LOCAL LIKE CONCAT('%', p_busqueda, '%')
        OR l.DESCRIPCION_LOCAL LIKE CONCAT('%', p_busqueda, '%')
    )
    ORDER BY
        CASE
            WHEN l.NOMBRE_LOCAL LIKE CONCAT(p_busqueda, '%') THEN 1
            WHEN l.NOMBRE_LOCAL LIKE CONCAT('%', p_busqueda, '%') THEN 2
            ELSE 3
        END,
        l.NOMBRE_LOCAL ASC
    LIMIT 20;
END//
DELIMITER ;

SELECT 'Migración 034 completada: SP buscador_locales creado' AS resultado;
