-- Migration 054: Stored Procedures para Dashboard de Administrador
-- Estadísticas globales del sistema

DELIMITER //

-- SP para obtener estadísticas globales del sistema
DROP PROCEDURE IF EXISTS sp_obtener_estadisticas_globales//
CREATE PROCEDURE sp_obtener_estadisticas_globales(
    IN p_fecha_inicio DATE,
    IN p_fecha_fin DATE
)
BEGIN
    SELECT
        -- Totales de locales
        (SELECT COUNT(*) FROM local WHERE ACTIVO = 1) AS TotalLocalesActivos,
        (SELECT COUNT(*) FROM local) AS TotalLocales,

        -- Totales de usuarios
        (SELECT COUNT(*) FROM usuario WHERE ACTIVO = 1) AS TotalUsuariosActivos,
        (SELECT COUNT(*) FROM usuario) AS TotalUsuarios,

        -- Usuarios registrados en el período
        (SELECT COUNT(*) FROM persona WHERE FECHA_REGISTRO BETWEEN p_fecha_inicio AND DATE_ADD(p_fecha_fin, INTERVAL 1 DAY)) AS NuevosUsuariosPeriodo,

        -- Locales registrados en el período
        (SELECT COUNT(*) FROM local WHERE FECHA_REGISTRO BETWEEN p_fecha_inicio AND DATE_ADD(p_fecha_fin, INTERVAL 1 DAY)) AS NuevosLocalesPeriodo,

        -- Totales de productos
        (SELECT COUNT(*) FROM producto WHERE ACTIVO = 1) AS TotalProductosActivos,

        -- Estadísticas de eventos
        COALESCE((SELECT SUM(CANTIDAD) FROM resumen_analitica_diario
                  WHERE FECHA BETWEEN p_fecha_inicio AND p_fecha_fin
                  AND TIPO_EVENTO = 'VISITA_LOCAL'), 0) AS TotalVisitasLocales,

        COALESCE((SELECT SUM(CANTIDAD) FROM resumen_analitica_diario
                  WHERE FECHA BETWEEN p_fecha_inicio AND p_fecha_fin
                  AND TIPO_EVENTO = 'CLIC_WHATSAPP'), 0) AS TotalClicsWhatsapp,

        COALESCE((SELECT SUM(CANTIDAD) FROM resumen_analitica_diario
                  WHERE FECHA BETWEEN p_fecha_inicio AND p_fecha_fin
                  AND TIPO_EVENTO = 'VISITA_PRODUCTO'), 0) AS TotalVisitasProductos,

        COALESCE((SELECT SUM(CANTIDAD) FROM resumen_analitica_diario
                  WHERE FECHA BETWEEN p_fecha_inicio AND p_fecha_fin
                  AND TIPO_EVENTO = 'BUSQUEDA_APARICION'), 0) AS TotalBusquedas;
END//

-- SP para obtener distribución de membresías
DROP PROCEDURE IF EXISTS sp_obtener_distribucion_membresias//
CREATE PROCEDURE sp_obtener_distribucion_membresias()
BEGIN
    SELECT
        tm.NOMBRE_MEMBRESIA AS NombreMembresia,
        tm.PK_ID_MEMBRESIA AS IdMembresia,
        COUNT(s.PK_ID_SUSCRIPCION) AS CantidadSuscripciones,
        COALESCE(SUM(CASE WHEN s.ESTADO = 'Activa' THEN 1 ELSE 0 END), 0) AS Activas,
        COALESCE(SUM(CASE WHEN s.ESTADO = 'Pendiente' THEN 1 ELSE 0 END), 0) AS Pendientes,
        COALESCE(SUM(CASE WHEN s.ESTADO = 'Vencida' THEN 1 ELSE 0 END), 0) AS Vencidas
    FROM tipo_membresia tm
    LEFT JOIN suscripcion s ON tm.PK_ID_MEMBRESIA = s.FK_ID_TIPO_MEMBRESIA
    WHERE tm.ACTIVO = 1
    GROUP BY tm.PK_ID_MEMBRESIA, tm.NOMBRE_MEMBRESIA
    ORDER BY CantidadSuscripciones DESC;
END//

-- SP para obtener locales más visitados
DROP PROCEDURE IF EXISTS sp_obtener_locales_mas_visitados//
CREATE PROCEDURE sp_obtener_locales_mas_visitados(
    IN p_fecha_inicio DATE,
    IN p_fecha_fin DATE,
    IN p_limite INT
)
BEGIN
    SELECT
        l.PK_ID_LOCAL AS IdLocal,
        l.NOMBRE AS NombreLocal,
        l.LOGO_URL AS LogoUrl,
        l.DIRECCION AS Direccion,
        COALESCE(SUM(rad.CANTIDAD), 0) AS TotalVisitas
    FROM local l
    LEFT JOIN resumen_analitica_diario rad ON l.PK_ID_LOCAL = rad.FK_ID_LOCAL
        AND rad.TIPO_EVENTO = 'VISITA_LOCAL'
        AND rad.FECHA BETWEEN p_fecha_inicio AND p_fecha_fin
    WHERE l.ACTIVO = 1
    GROUP BY l.PK_ID_LOCAL, l.NOMBRE, l.LOGO_URL, l.DIRECCION
    ORDER BY TotalVisitas DESC
    LIMIT p_limite;
END//

-- SP para obtener estadísticas diarias globales (para gráfico)
DROP PROCEDURE IF EXISTS sp_obtener_estadisticas_diarias_globales//
CREATE PROCEDURE sp_obtener_estadisticas_diarias_globales(
    IN p_fecha_inicio DATE,
    IN p_fecha_fin DATE
)
BEGIN
    -- Generar todas las fechas del rango
    WITH RECURSIVE fechas AS (
        SELECT p_fecha_inicio AS fecha
        UNION ALL
        SELECT DATE_ADD(fecha, INTERVAL 1 DAY)
        FROM fechas
        WHERE fecha < p_fecha_fin
    )
    SELECT
        f.fecha AS Fecha,
        COALESCE(SUM(CASE WHEN rad.TIPO_EVENTO = 'VISITA_LOCAL' THEN rad.CANTIDAD ELSE 0 END), 0) AS Visitas,
        COALESCE(SUM(CASE WHEN rad.TIPO_EVENTO = 'CLIC_WHATSAPP' THEN rad.CANTIDAD ELSE 0 END), 0) AS ClicsWhatsapp,
        COALESCE(SUM(CASE WHEN rad.TIPO_EVENTO = 'VISITA_PRODUCTO' THEN rad.CANTIDAD ELSE 0 END), 0) AS VisitasProductos,
        -- Nuevos usuarios por día
        (SELECT COUNT(*) FROM persona WHERE DATE(FECHA_REGISTRO) = f.fecha) AS NuevosUsuarios,
        -- Nuevos locales por día
        (SELECT COUNT(*) FROM local WHERE DATE(FECHA_REGISTRO) = f.fecha) AS NuevosLocales
    FROM fechas f
    LEFT JOIN resumen_analitica_diario rad ON f.fecha = rad.FECHA
    GROUP BY f.fecha
    ORDER BY f.fecha;
END//

-- SP para obtener actividad reciente (últimos eventos)
DROP PROCEDURE IF EXISTS sp_obtener_actividad_reciente//
CREATE PROCEDURE sp_obtener_actividad_reciente(
    IN p_limite INT
)
BEGIN
    SELECT
        ea.PK_ID_EVENTO AS IdEvento,
        ea.TIPO_EVENTO AS TipoEvento,
        ea.FECHA_HORA AS FechaHora,
        l.NOMBRE AS NombreLocal,
        l.PK_ID_LOCAL AS IdLocal,
        p.NOMBRE_PRODUCTO AS NombreProducto,
        ea.FK_ID_PRODUCTO AS IdProducto
    FROM evento_analitica ea
    INNER JOIN local l ON ea.FK_ID_LOCAL = l.PK_ID_LOCAL
    LEFT JOIN producto p ON ea.FK_ID_PRODUCTO = p.PK_ID_PRODUCTO
    ORDER BY ea.FECHA_HORA DESC
    LIMIT p_limite;
END//

-- SP para comparar estadísticas entre dos períodos (para calcular cambios %)
DROP PROCEDURE IF EXISTS sp_comparar_estadisticas_globales//
CREATE PROCEDURE sp_comparar_estadisticas_globales(
    IN p_fecha_inicio_actual DATE,
    IN p_fecha_fin_actual DATE,
    IN p_fecha_inicio_anterior DATE,
    IN p_fecha_fin_anterior DATE
)
BEGIN
    SELECT
        -- Período actual
        COALESCE((SELECT SUM(CANTIDAD) FROM resumen_analitica_diario
                  WHERE FECHA BETWEEN p_fecha_inicio_actual AND p_fecha_fin_actual
                  AND TIPO_EVENTO = 'VISITA_LOCAL'), 0) AS VisitasActual,

        COALESCE((SELECT SUM(CANTIDAD) FROM resumen_analitica_diario
                  WHERE FECHA BETWEEN p_fecha_inicio_actual AND p_fecha_fin_actual
                  AND TIPO_EVENTO = 'CLIC_WHATSAPP'), 0) AS WhatsappActual,

        (SELECT COUNT(*) FROM persona
         WHERE FECHA_REGISTRO BETWEEN p_fecha_inicio_actual AND DATE_ADD(p_fecha_fin_actual, INTERVAL 1 DAY)) AS NuevosUsuariosActual,

        (SELECT COUNT(*) FROM local
         WHERE FECHA_REGISTRO BETWEEN p_fecha_inicio_actual AND DATE_ADD(p_fecha_fin_actual, INTERVAL 1 DAY)) AS NuevosLocalesActual,

        -- Período anterior
        COALESCE((SELECT SUM(CANTIDAD) FROM resumen_analitica_diario
                  WHERE FECHA BETWEEN p_fecha_inicio_anterior AND p_fecha_fin_anterior
                  AND TIPO_EVENTO = 'VISITA_LOCAL'), 0) AS VisitasAnterior,

        COALESCE((SELECT SUM(CANTIDAD) FROM resumen_analitica_diario
                  WHERE FECHA BETWEEN p_fecha_inicio_anterior AND p_fecha_fin_anterior
                  AND TIPO_EVENTO = 'CLIC_WHATSAPP'), 0) AS WhatsappAnterior,

        (SELECT COUNT(*) FROM persona
         WHERE FECHA_REGISTRO BETWEEN p_fecha_inicio_anterior AND DATE_ADD(p_fecha_fin_anterior, INTERVAL 1 DAY)) AS NuevosUsuariosAnterior,

        (SELECT COUNT(*) FROM local
         WHERE FECHA_REGISTRO BETWEEN p_fecha_inicio_anterior AND DATE_ADD(p_fecha_fin_anterior, INTERVAL 1 DAY)) AS NuevosLocalesAnterior;
END//

DELIMITER ;

SELECT 'Migración 054 completada - SPs para Dashboard Admin creados' AS resultado;
