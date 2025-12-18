-- =============================================
-- Migración: 009_fix_ofertas_actuales_include_pending.sql
-- Fecha: 2025-12-17
-- Descripción: Corrige el procedimiento ofertas_actuales para incluir
--              ofertas pendientes (Estado=0) además de aprobadas (Estado=1)
--              al validar el límite de ofertas simultáneas.
--
-- Problema: El procedimiento original solo contaba ofertas con Estado=1
--           (aprobadas), lo que permitía a un usuario crear más ofertas
--           de las permitidas si tenía varias pendientes de aprobación.
--
-- Solución: Ahora cuenta ofertas con Estado IN (0, 1) para incluir
--           pendientes y aprobadas en la validación del límite.
-- =============================================

-- Eliminar el procedimiento existente
DROP PROCEDURE IF EXISTS `ofertas_actuales`;

-- Crear el procedimiento corregido
DELIMITER //
CREATE PROCEDURE `ofertas_actuales`(
    IN `p_id_local` INT
)
BEGIN
    -- Cuenta ofertas activas: pendientes (0) y aprobadas (1)
    -- Excluye eliminadas/expiradas (2)
    SELECT COUNT(*)
    FROM oferta_flash
    INNER JOIN `local` ON oferta_flash.FK_ID_LOCAL = `local`.PK_ID_LOCAL
    WHERE local.PK_ID_LOCAL = p_id_local
    AND oferta_flash.ESTADO_OFERTA_FLASH IN (0, 1);
END//
DELIMITER ;

SELECT 'Migración 009 completada - ofertas_actuales ahora incluye pendientes' AS resultado;
