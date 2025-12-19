-- =============================================
-- Migración 019: Stored Procedures para gestión de suscripciones
-- Descripción: CRUD y operaciones de suscripciones/historial
-- =============================================

DELIMITER //

-- =============================================
-- SP: Obtener suscripción activa de un local
-- =============================================
DROP PROCEDURE IF EXISTS obtener_suscripcion_activa//
CREATE PROCEDURE obtener_suscripcion_activa(
    IN p_id_local INT
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
        -- Datos del tipo de membresía
        tm.PK_ID_TIPO_MEMBRESIA AS TipoMembresiaId,
        tm.NOMBRE AS TipoMembresiaNombre,
        tm.DESCRIPCION AS TipoMembresiaDescripcion,
        tm.COSTO_MES AS TipoMembresiaCostoMes,
        tm.COSTO_TRIMESTRE AS TipoMembresiaCostoTrimestre,
        tm.COSTO_SEMESTRE AS TipoMembresiaCostoSemestre,
        tm.COSTO_ANIO AS TipoMembresiaCostoAnio,
        tm.ESTADO AS TipoMembresiaEstado
    FROM suscripcion s
    INNER JOIN tipo_membresia tm ON s.FK_ID_TIPO_MEMBRESIA = tm.PK_ID_TIPO_MEMBRESIA
    WHERE s.FK_ID_LOCAL = p_id_local
        AND s.ESTADO = 1
    ORDER BY s.FECHA_CREACION DESC
    LIMIT 1;
END//

-- =============================================
-- SP: Crear nueva suscripción
-- =============================================
DROP PROCEDURE IF EXISTS crear_suscripcion//
CREATE PROCEDURE crear_suscripcion(
    IN p_id_local INT,
    IN p_id_tipo_membresia INT,
    IN p_periodo VARCHAR(20),
    IN p_monto DECIMAL(10,2),
    IN p_metodo_pago VARCHAR(50),
    IN p_notas TEXT
)
BEGIN
    DECLARE v_id_suscripcion_anterior INT DEFAULT NULL;
    DECLARE v_id_tipo_anterior INT DEFAULT NULL;
    DECLARE v_fecha_inicio DATETIME;
    DECLARE v_fecha_fin DATETIME;
    DECLARE v_nueva_suscripcion INT;
    DECLARE v_tipo_cambio VARCHAR(20);

    SET v_fecha_inicio = NOW();

    -- Calcular fecha fin según el período
    SET v_fecha_fin = CASE p_periodo
        WHEN 'MENSUAL' THEN DATE_ADD(v_fecha_inicio, INTERVAL 1 MONTH)
        WHEN 'TRIMESTRAL' THEN DATE_ADD(v_fecha_inicio, INTERVAL 3 MONTH)
        WHEN 'SEMESTRAL' THEN DATE_ADD(v_fecha_inicio, INTERVAL 6 MONTH)
        WHEN 'ANUAL' THEN DATE_ADD(v_fecha_inicio, INTERVAL 1 YEAR)
        ELSE DATE_ADD(v_fecha_inicio, INTERVAL 1 MONTH)
    END;

    -- Buscar suscripción activa actual
    SELECT PK_ID_SUSCRIPCION, FK_ID_TIPO_MEMBRESIA
    INTO v_id_suscripcion_anterior, v_id_tipo_anterior
    FROM suscripcion
    WHERE FK_ID_LOCAL = p_id_local AND ESTADO = 1
    LIMIT 1;

    -- Desactivar suscripción anterior si existe
    IF v_id_suscripcion_anterior IS NOT NULL THEN
        UPDATE suscripcion
        SET ESTADO = 0
        WHERE PK_ID_SUSCRIPCION = v_id_suscripcion_anterior;
    END IF;

    -- Crear nueva suscripción
    INSERT INTO suscripcion (
        FK_ID_LOCAL,
        FK_ID_TIPO_MEMBRESIA,
        ESTADO,
        FECHA_INICIO,
        FECHA_FIN,
        MONTO_PAGADO,
        METODO_PAGO,
        PERIODO,
        NOTAS
    ) VALUES (
        p_id_local,
        p_id_tipo_membresia,
        1,
        v_fecha_inicio,
        v_fecha_fin,
        p_monto,
        p_metodo_pago,
        p_periodo,
        p_notas
    );

    SET v_nueva_suscripcion = LAST_INSERT_ID();

    -- Actualizar local con la nueva suscripción activa
    UPDATE local
    SET FK_ID_SUSCRIPCION_ACTIVA = v_nueva_suscripcion
    WHERE PK_ID_LOCAL = p_id_local;

    -- Determinar tipo de cambio
    IF v_id_tipo_anterior IS NULL THEN
        SET v_tipo_cambio = 'ALTA';
    ELSEIF p_id_tipo_membresia > v_id_tipo_anterior THEN
        SET v_tipo_cambio = 'UPGRADE';
    ELSEIF p_id_tipo_membresia < v_id_tipo_anterior THEN
        SET v_tipo_cambio = 'DOWNGRADE';
    ELSE
        SET v_tipo_cambio = 'RENOVACION';
    END IF;

    -- Registrar en historial
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
    ) VALUES (
        p_id_local,
        v_nueva_suscripcion,
        v_id_tipo_anterior,
        p_id_tipo_membresia,
        v_tipo_cambio,
        v_fecha_inicio,
        v_fecha_fin,
        p_monto,
        p_periodo,
        p_notas
    );

    -- Retornar la nueva suscripción
    SELECT v_nueva_suscripcion AS IdSuscripcion, v_tipo_cambio AS TipoCambio;
END//

-- =============================================
-- SP: Renovar suscripción existente
-- =============================================
DROP PROCEDURE IF EXISTS renovar_suscripcion//
CREATE PROCEDURE renovar_suscripcion(
    IN p_id_suscripcion INT,
    IN p_periodo VARCHAR(20),
    IN p_monto DECIMAL(10,2),
    IN p_metodo_pago VARCHAR(50)
)
BEGIN
    DECLARE v_id_local INT;
    DECLARE v_id_tipo_membresia INT;
    DECLARE v_fecha_fin_actual DATETIME;
    DECLARE v_nueva_fecha_fin DATETIME;

    -- Obtener datos de la suscripción actual
    SELECT FK_ID_LOCAL, FK_ID_TIPO_MEMBRESIA, FECHA_FIN
    INTO v_id_local, v_id_tipo_membresia, v_fecha_fin_actual
    FROM suscripcion
    WHERE PK_ID_SUSCRIPCION = p_id_suscripcion;

    -- Calcular nueva fecha fin (extender desde la fecha actual o la fecha fin actual, lo que sea mayor)
    SET v_nueva_fecha_fin = GREATEST(v_fecha_fin_actual, NOW());
    SET v_nueva_fecha_fin = CASE p_periodo
        WHEN 'MENSUAL' THEN DATE_ADD(v_nueva_fecha_fin, INTERVAL 1 MONTH)
        WHEN 'TRIMESTRAL' THEN DATE_ADD(v_nueva_fecha_fin, INTERVAL 3 MONTH)
        WHEN 'SEMESTRAL' THEN DATE_ADD(v_nueva_fecha_fin, INTERVAL 6 MONTH)
        WHEN 'ANUAL' THEN DATE_ADD(v_nueva_fecha_fin, INTERVAL 1 YEAR)
        ELSE DATE_ADD(v_nueva_fecha_fin, INTERVAL 1 MONTH)
    END;

    -- Actualizar suscripción
    UPDATE suscripcion
    SET FECHA_FIN = v_nueva_fecha_fin,
        MONTO_PAGADO = COALESCE(MONTO_PAGADO, 0) + p_monto,
        METODO_PAGO = p_metodo_pago,
        PERIODO = p_periodo,
        ESTADO = 1
    WHERE PK_ID_SUSCRIPCION = p_id_suscripcion;

    -- Registrar en historial
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
    ) VALUES (
        v_id_local,
        p_id_suscripcion,
        v_id_tipo_membresia,
        v_id_tipo_membresia,
        'RENOVACION',
        GREATEST(v_fecha_fin_actual, NOW()),
        v_nueva_fecha_fin,
        p_monto,
        p_periodo,
        'Renovación de suscripción'
    );

    SELECT p_id_suscripcion AS IdSuscripcion, v_nueva_fecha_fin AS NuevaFechaFin;
END//

-- =============================================
-- SP: Cancelar suscripción
-- =============================================
DROP PROCEDURE IF EXISTS cancelar_suscripcion//
CREATE PROCEDURE cancelar_suscripcion(
    IN p_id_suscripcion INT,
    IN p_motivo TEXT
)
BEGIN
    DECLARE v_id_local INT;
    DECLARE v_id_tipo_membresia INT;
    DECLARE v_fecha_inicio DATETIME;
    DECLARE v_fecha_fin DATETIME;

    -- Obtener datos de la suscripción
    SELECT FK_ID_LOCAL, FK_ID_TIPO_MEMBRESIA, FECHA_INICIO, FECHA_FIN
    INTO v_id_local, v_id_tipo_membresia, v_fecha_inicio, v_fecha_fin
    FROM suscripcion
    WHERE PK_ID_SUSCRIPCION = p_id_suscripcion;

    -- Marcar como cancelada
    UPDATE suscripcion
    SET ESTADO = 2
    WHERE PK_ID_SUSCRIPCION = p_id_suscripcion;

    -- Quitar suscripción activa del local
    UPDATE local
    SET FK_ID_SUSCRIPCION_ACTIVA = NULL
    WHERE PK_ID_LOCAL = v_id_local;

    -- Registrar en historial
    INSERT INTO historial_membresia (
        FK_ID_LOCAL,
        FK_ID_SUSCRIPCION,
        FK_ID_TIPO_ANTERIOR,
        FK_ID_TIPO_NUEVO,
        TIPO_CAMBIO,
        FECHA_INICIO_PERIODO,
        FECHA_FIN_PERIODO,
        NOTAS
    ) VALUES (
        v_id_local,
        p_id_suscripcion,
        v_id_tipo_membresia,
        v_id_tipo_membresia,
        'CANCELACION',
        v_fecha_inicio,
        NOW(),
        p_motivo
    );

    SELECT p_id_suscripcion AS IdSuscripcion, 'CANCELADA' AS Estado;
END//

-- =============================================
-- SP: Consultar historial de membresía de un local
-- =============================================
DROP PROCEDURE IF EXISTS consultar_historial_membresia//
CREATE PROCEDURE consultar_historial_membresia(
    IN p_id_local INT
)
BEGIN
    SELECT
        hm.PK_ID_HISTORIAL AS Id,
        hm.FK_ID_LOCAL AS LocalId,
        hm.FK_ID_SUSCRIPCION AS SuscripcionId,
        hm.TIPO_CAMBIO AS TipoCambio,
        hm.FECHA_CAMBIO AS FechaCambio,
        hm.FECHA_INICIO_PERIODO AS FechaInicioPeriodo,
        hm.FECHA_FIN_PERIODO AS FechaFinPeriodo,
        hm.MONTO AS Monto,
        hm.PERIODO AS Periodo,
        hm.NOTAS AS Notas,
        -- Tipo anterior
        ta.PK_ID_TIPO_MEMBRESIA AS TipoAnteriorId,
        ta.NOMBRE AS TipoAnteriorNombre,
        -- Tipo nuevo
        tn.PK_ID_TIPO_MEMBRESIA AS TipoNuevoId,
        tn.NOMBRE AS TipoNuevoNombre
    FROM historial_membresia hm
    LEFT JOIN tipo_membresia ta ON hm.FK_ID_TIPO_ANTERIOR = ta.PK_ID_TIPO_MEMBRESIA
    INNER JOIN tipo_membresia tn ON hm.FK_ID_TIPO_NUEVO = tn.PK_ID_TIPO_MEMBRESIA
    WHERE hm.FK_ID_LOCAL = p_id_local
    ORDER BY hm.FECHA_CAMBIO DESC;
END//

-- =============================================
-- SP: Verificar y marcar suscripciones vencidas
-- (Para ejecutar periódicamente con un job o trigger)
-- =============================================
DROP PROCEDURE IF EXISTS verificar_suscripciones_vencidas//
CREATE PROCEDURE verificar_suscripciones_vencidas()
BEGIN
    -- Marcar como vencidas las suscripciones activas cuya fecha fin ya pasó
    UPDATE suscripcion s
    INNER JOIN local l ON s.PK_ID_SUSCRIPCION = l.FK_ID_SUSCRIPCION_ACTIVA
    SET s.ESTADO = 3,
        l.FK_ID_SUSCRIPCION_ACTIVA = NULL
    WHERE s.ESTADO = 1
        AND s.FECHA_FIN < NOW();

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
        FK_ID_LOCAL,
        PK_ID_SUSCRIPCION,
        FK_ID_TIPO_MEMBRESIA,
        FK_ID_TIPO_MEMBRESIA,
        'VENCIMIENTO',
        FECHA_INICIO,
        FECHA_FIN,
        'Suscripción vencida automáticamente'
    FROM suscripcion
    WHERE ESTADO = 3
        AND NOT EXISTS (
            SELECT 1 FROM historial_membresia hm
            WHERE hm.FK_ID_SUSCRIPCION = suscripcion.PK_ID_SUSCRIPCION
                AND hm.TIPO_CAMBIO = 'VENCIMIENTO'
        );

    SELECT ROW_COUNT() AS SuscripcionesVencidas;
END//

-- =============================================
-- SP: Obtener todas las suscripciones de un local
-- =============================================
DROP PROCEDURE IF EXISTS obtener_suscripciones_local//
CREATE PROCEDURE obtener_suscripciones_local(
    IN p_id_local INT
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
        tm.COSTO_MES AS TipoMembresiaCostoMes
    FROM suscripcion s
    INNER JOIN tipo_membresia tm ON s.FK_ID_TIPO_MEMBRESIA = tm.PK_ID_TIPO_MEMBRESIA
    WHERE s.FK_ID_LOCAL = p_id_local
    ORDER BY s.FECHA_CREACION DESC;
END//

DELIMITER ;
