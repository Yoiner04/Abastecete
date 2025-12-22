-- =============================================
-- Migración 039: Corregir SP obtener_suscripcion_activa
-- Fecha: 2025-12-21
-- Problema: El SP usaba tm.DESCRIPCION que no existe en la tabla
--           y no incluía los campos de límites de membresía
-- =============================================

DROP PROCEDURE IF EXISTS `obtener_suscripcion_activa`;

DELIMITER //

CREATE PROCEDURE `obtener_suscripcion_activa`(
    IN `p_id_local` INT
)
BEGIN
    SELECT
        s.PK_ID_SUSCRIPCION AS Id,
        s.FK_ID_LOCAL AS LocalId,
        s.ESTADO AS Estado,
        s.FECHA_INICIO AS FechaInicio,
        s.FECHA_FIN AS FechaFin,
        s.FECHA_CREACION AS FechaCreacion,
        s.MONTO_PAGADO AS MontoPagado,
        s.METODO_PAGO AS MetodoPago,
        s.PERIODO AS Periodo,
        s.NOTAS AS Notas,
        tm.PK_ID_TIPO_MEMBRESIA AS TipoMembresiaId,
        tm.NOMBRE AS TipoMembresiaNombre,
        '' AS TipoMembresiaDescripcion,
        COALESCE(tm.COSTO, 0) AS TipoMembresiaCostoMes,
        COALESCE(tm.COSTO_TRIMESTRAL, 0) AS TipoMembresiaCostoTrimestre,
        COALESCE(tm.COSTO_SEMESTRAL, 0) AS TipoMembresiaCostoSemestre,
        COALESCE(tm.COSTO_ANUAL, 0) AS TipoMembresiaCostoAnio,
        COALESCE(tm.ESTADO, 1) AS TipoMembresiaEstado,
        -- Campos de límites
        COALESCE(tm.CANTIDAD_PRODUCTOS, 0) AS TipoMembresiaCantidad,
        COALESCE(tm.DURACION_OFERTA, 24) AS TipoMembresiaDuracion,
        COALESCE(tm.OFERTAS_FLASH_SIMULTANEAS, 1) AS TipoMembresiaOfertasSimultaneas,
        COALESCE(tm.OFERTAS_FLASH_TOTAL, 0) AS TipoMembresiaOfertasTotal
    FROM local l
    INNER JOIN suscripcion s ON l.FK_ID_SUSCRIPCION_ACTIVA = s.PK_ID_SUSCRIPCION
    INNER JOIN tipo_membresia tm ON s.FK_ID_TIPO_MEMBRESIA = tm.PK_ID_TIPO_MEMBRESIA
    WHERE l.PK_ID_LOCAL = p_id_local
      AND s.ESTADO = 1
      AND s.FECHA_FIN > NOW()
    LIMIT 1;
END//

DELIMITER ;
