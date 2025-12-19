-- =============================================
-- Migración 023: Corregir nombres de columnas en SPs de suscripciones
-- Descripción: Los SPs usaban COSTO_MES pero la columna real es COSTO
-- =============================================

DELIMITER //

-- Corregir obtener_suscripcion_activa
DROP PROCEDURE IF EXISTS `obtener_suscripcion_activa`//

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
        COALESCE(tm.DESCRIPCION, '') AS TipoMembresiaDescripcion,
        COALESCE(tm.COSTO, 0) AS TipoMembresiaCostoMes,
        COALESCE(tm.COSTO_TRIMESTRAL, 0) AS TipoMembresiaCostoTrimestre,
        COALESCE(tm.COSTO_SEMESTRAL, 0) AS TipoMembresiaCostoSemestre,
        COALESCE(tm.COSTO_ANUAL, 0) AS TipoMembresiaCostoAnio,
        COALESCE(tm.ESTADO, 1) AS TipoMembresiaEstado
    FROM suscripcion s
    INNER JOIN tipo_membresia tm ON s.FK_ID_TIPO_MEMBRESIA = tm.PK_ID_TIPO_MEMBRESIA
    WHERE s.FK_ID_LOCAL = p_id_local
    AND s.ESTADO = 1
    AND s.FECHA_FIN > NOW()
    ORDER BY s.FECHA_CREACION DESC
    LIMIT 1;
END//

-- Corregir obtener_suscripciones_local
DROP PROCEDURE IF EXISTS `obtener_suscripciones_local`//

CREATE PROCEDURE `obtener_suscripciones_local`(
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
        COALESCE(tm.COSTO, 0) AS TipoMembresiaCostoMes
    FROM suscripcion s
    INNER JOIN tipo_membresia tm ON s.FK_ID_TIPO_MEMBRESIA = tm.PK_ID_TIPO_MEMBRESIA
    WHERE s.FK_ID_LOCAL = p_id_local
    ORDER BY s.FECHA_CREACION DESC;
END//

DELIMITER ;
