-- =============================================
-- Migración 038: Corregir obtención de suscripción activa y auto-renovación gratuita
-- Fecha: 2025-12-21
-- Problemas que resuelve:
--   1. El SP actual no encuentra suscripciones activas correctamente
--   2. Los planes gratuitos no se renuevan automáticamente
-- =============================================

DELIMITER //

-- =============================================
-- SP: Obtener suscripción activa (CORREGIDO)
-- Ahora usa FK_ID_SUSCRIPCION_ACTIVA del local como fuente primaria
-- =============================================
DROP PROCEDURE IF EXISTS `obtener_suscripcion_activa`//

CREATE PROCEDURE `obtener_suscripcion_activa`(
    IN `p_id_local` INT
)
BEGIN
    -- Usar FK_ID_SUSCRIPCION_ACTIVA del local como referencia principal
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
        COALESCE(tm.ESTADO, 1) AS TipoMembresiaEstado,
        -- Campos de límites (nombres coinciden con MapearSuscripcion en C#)
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

-- =============================================
-- SP: Auto-renovar planes gratuitos vencidos
-- Renueva automáticamente las suscripciones gratuitas por 1 mes más
-- =============================================
DROP PROCEDURE IF EXISTS `autorenovar_planes_gratuitos`//

CREATE PROCEDURE `autorenovar_planes_gratuitos`()
BEGIN
    -- Actualizar fecha fin de suscripciones gratuitas vencidas o por vencer
    UPDATE suscripcion s
    INNER JOIN tipo_membresia tm ON s.FK_ID_TIPO_MEMBRESIA = tm.PK_ID_TIPO_MEMBRESIA
    INNER JOIN local l ON l.FK_ID_SUSCRIPCION_ACTIVA = s.PK_ID_SUSCRIPCION
    SET s.FECHA_FIN = DATE_ADD(GREATEST(s.FECHA_FIN, NOW()), INTERVAL 1 MONTH),
        s.NOTAS = CONCAT(COALESCE(s.NOTAS, ''), ' | Auto-renovado: ', NOW())
    WHERE s.ESTADO = 1
      AND tm.COSTO = 0
      AND s.FECHA_FIN <= DATE_ADD(NOW(), INTERVAL 1 DAY);

    -- Registrar en historial las renovaciones automáticas
    INSERT INTO historial_membresia (
        FK_ID_LOCAL,
        FK_ID_SUSCRIPCION,
        FK_ID_TIPO_ANTERIOR,
        FK_ID_TIPO_NUEVO,
        TIPO_CAMBIO,
        FECHA_INICIO_PERIODO,
        FECHA_FIN_PERIODO,
        MONTO,
        PERIODO,
        NOTAS
    )
    SELECT
        s.FK_ID_LOCAL,
        s.PK_ID_SUSCRIPCION,
        s.FK_ID_TIPO_MEMBRESIA,
        s.FK_ID_TIPO_MEMBRESIA,
        'RENOVACION',
        NOW(),
        s.FECHA_FIN,
        0,
        'MENSUAL',
        'Auto-renovación de plan gratuito'
    FROM suscripcion s
    INNER JOIN tipo_membresia tm ON s.FK_ID_TIPO_MEMBRESIA = tm.PK_ID_TIPO_MEMBRESIA
    WHERE s.ESTADO = 1
      AND tm.COSTO = 0
      AND DATE(s.FECHA_FIN) = DATE(DATE_ADD(NOW(), INTERVAL 1 MONTH))
      AND NOT EXISTS (
          SELECT 1 FROM historial_membresia hm
          WHERE hm.FK_ID_SUSCRIPCION = s.PK_ID_SUSCRIPCION
            AND hm.TIPO_CAMBIO = 'RENOVACION'
            AND DATE(hm.FECHA_CAMBIO) = DATE(NOW())
      );

    SELECT ROW_COUNT() AS PlanesRenovados;
END//

-- =============================================
-- SP: Verificar suscripciones vencidas (ACTUALIZADO)
-- Primero auto-renueva gratuitos, luego marca de pago como vencidas
-- =============================================
DROP PROCEDURE IF EXISTS `verificar_suscripciones_vencidas`//

CREATE PROCEDURE `verificar_suscripciones_vencidas`()
BEGIN
    -- Primero auto-renovar planes gratuitos
    CALL autorenovar_planes_gratuitos();

    -- Luego marcar como vencidas las suscripciones de pago que expiraron
    UPDATE suscripcion s
    INNER JOIN local l ON s.PK_ID_SUSCRIPCION = l.FK_ID_SUSCRIPCION_ACTIVA
    INNER JOIN tipo_membresia tm ON s.FK_ID_TIPO_MEMBRESIA = tm.PK_ID_TIPO_MEMBRESIA
    SET s.ESTADO = 3,
        l.FK_ID_SUSCRIPCION_ACTIVA = NULL
    WHERE s.ESTADO = 1
      AND s.FECHA_FIN < NOW()
      AND tm.COSTO > 0;

    -- Registrar en historial los vencimientos
    INSERT INTO historial_membresia (
        FK_ID_LOCAL,
        FK_ID_SUSCRIPCION,
        FK_ID_TIPO_ANTERIOR,
        FK_ID_TIPO_NUEVO,
        TIPO_CAMBIO,
        FECHA_INICIO_PERIODO,
        FECHA_FIN_PERIODO,
        NOTAS
    )
    SELECT
        s.FK_ID_LOCAL,
        s.PK_ID_SUSCRIPCION,
        s.FK_ID_TIPO_MEMBRESIA,
        s.FK_ID_TIPO_MEMBRESIA,
        'VENCIMIENTO',
        s.FECHA_INICIO,
        s.FECHA_FIN,
        'Suscripción de pago vencida'
    FROM suscripcion s
    INNER JOIN tipo_membresia tm ON s.FK_ID_TIPO_MEMBRESIA = tm.PK_ID_TIPO_MEMBRESIA
    WHERE s.ESTADO = 3
      AND tm.COSTO > 0
      AND NOT EXISTS (
          SELECT 1 FROM historial_membresia hm
          WHERE hm.FK_ID_SUSCRIPCION = s.PK_ID_SUSCRIPCION
            AND hm.TIPO_CAMBIO = 'VENCIMIENTO'
      );

    SELECT ROW_COUNT() AS SuscripcionesVencidas;
END//

DELIMITER ;

-- =============================================
-- DIAGNÓSTICO: Ejecuta esto para ver el estado de tu suscripción
-- =============================================
-- SELECT
--     l.PK_ID_LOCAL,
--     l.NOMBRE AS NombreLocal,
--     l.FK_ID_SUSCRIPCION_ACTIVA,
--     s.PK_ID_SUSCRIPCION,
--     s.ESTADO AS EstadoSuscripcion,
--     s.FECHA_INICIO,
--     s.FECHA_FIN,
--     s.FECHA_FIN > NOW() AS NoVencida,
--     tm.NOMBRE AS NombreMembresia,
--     tm.COSTO
-- FROM local l
-- LEFT JOIN suscripcion s ON l.FK_ID_SUSCRIPCION_ACTIVA = s.PK_ID_SUSCRIPCION
-- LEFT JOIN tipo_membresia tm ON s.FK_ID_TIPO_MEMBRESIA = tm.PK_ID_TIPO_MEMBRESIA
-- WHERE l.PK_ID_LOCAL = 1;  -- Cambia por tu ID de local
