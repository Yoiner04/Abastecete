-- Migración 076: Corregir SPs que usan tabla persona (ya no existe)
-- ============================================================
-- La tabla persona fue eliminada, ahora todo está en usuario
-- ============================================================

-- =====================================================
-- SP: consultar_usuarios_paginado
-- =====================================================
DROP PROCEDURE IF EXISTS consultar_usuarios_paginado;
DELIMITER //
CREATE PROCEDURE consultar_usuarios_paginado(
    IN p_pagina INT,
    IN p_registros_por_pagina INT,
    IN p_busqueda VARCHAR(100),
    IN p_estado INT
)
BEGIN
    DECLARE v_offset INT;
    SET v_offset = (p_pagina - 1) * p_registros_por_pagina;

    -- Consulta principal
    SELECT
        u.PK_ID_USUARIO AS Id,
        u.NOMBRES,
        u.APELLIDOS,
        CONCAT(u.NOMBRES, ' ', u.APELLIDOS) AS NombreCompleto,
        u.NOMBRE_USUARIO AS Correo,
        u.TELEFONO,
        u.DOCUMENTO_IDENTIDAD,
        u.ESTADO,
        u.CODIGO_REFERIDO,
        u.CREDITO_REFERIDOS,
        tm.NOMBRE AS NombreMembresia,
        tm.PK_ID_TIPO_MEMBRESIA AS TipoMembresiaId,
        s.FECHA_FIN AS FechaVencimientoMembresia,
        CASE
            WHEN s.PK_ID_SUSCRIPCION IS NULL THEN 'Sin membresía'
            WHEN s.FECHA_FIN < NOW() THEN 'Vencida'
            WHEN s.FECHA_FIN < DATE_ADD(NOW(), INTERVAL 7 DAY) THEN 'Por vencer'
            ELSE 'Activa'
        END AS EstadoMembresia
    FROM usuario u
    LEFT JOIN (
        SELECT s1.* FROM suscripcion s1
        INNER JOIN (
            SELECT FK_ID_LOCAL, MAX(FECHA_INICIO) as MaxFecha
            FROM suscripcion
            WHERE ESTADO IN (1, 2)
            GROUP BY FK_ID_LOCAL
        ) s2 ON s1.FK_ID_LOCAL = s2.FK_ID_LOCAL AND s1.FECHA_INICIO = s2.MaxFecha
    ) s ON s.FK_ID_LOCAL = (SELECT PK_ID_LOCAL FROM local WHERE FK_ID_USUARIO = u.PK_ID_USUARIO LIMIT 1)
    LEFT JOIN tipo_membresia tm ON s.FK_ID_TIPO_MEMBRESIA = tm.PK_ID_TIPO_MEMBRESIA
    WHERE
        (p_estado = -1 OR u.ESTADO = p_estado)
        AND (
            p_busqueda IS NULL
            OR p_busqueda = ''
            OR u.NOMBRES LIKE CONCAT('%', p_busqueda, '%')
            OR u.APELLIDOS LIKE CONCAT('%', p_busqueda, '%')
            OR u.NOMBRE_USUARIO LIKE CONCAT('%', p_busqueda, '%')
            OR u.DOCUMENTO_IDENTIDAD LIKE CONCAT('%', p_busqueda, '%')
            OR u.TELEFONO LIKE CONCAT('%', p_busqueda, '%')
        )
    ORDER BY u.PK_ID_USUARIO DESC
    LIMIT v_offset, p_registros_por_pagina;

    -- Total de registros
    SELECT COUNT(*) AS TotalRegistros
    FROM usuario u
    WHERE
        (p_estado = -1 OR u.ESTADO = p_estado)
        AND (
            p_busqueda IS NULL
            OR p_busqueda = ''
            OR u.NOMBRES LIKE CONCAT('%', p_busqueda, '%')
            OR u.APELLIDOS LIKE CONCAT('%', p_busqueda, '%')
            OR u.NOMBRE_USUARIO LIKE CONCAT('%', p_busqueda, '%')
            OR u.DOCUMENTO_IDENTIDAD LIKE CONCAT('%', p_busqueda, '%')
            OR u.TELEFONO LIKE CONCAT('%', p_busqueda, '%')
        );
END//
DELIMITER ;

-- =====================================================
-- SP: consultar_persona (ahora consulta usuario)
-- =====================================================
DROP PROCEDURE IF EXISTS consultar_persona;
DELIMITER //
CREATE PROCEDURE consultar_persona(
    IN p_id_persona INT
)
BEGIN
    IF p_id_persona IS NOT NULL AND p_id_persona > 0 THEN
        SELECT * FROM usuario WHERE PK_ID_USUARIO = p_id_persona;
    ELSE
        SELECT * FROM usuario;
    END IF;
END//
DELIMITER ;

-- =====================================================
-- SP: login_usuario (sin tabla persona)
-- =====================================================
DROP PROCEDURE IF EXISTS login_usuario;
DELIMITER //
CREATE PROCEDURE login_usuario(
    IN p_nombre_usuario VARCHAR(100),
    IN p_contrasenia TEXT
)
BEGIN
    DECLARE v_id_usuario INT DEFAULT 0;
    DECLARE v_estado INT DEFAULT 0;
    DECLARE v_fecha_bloqueo DATETIME DEFAULT NULL;
    DECLARE v_contrasenia_hash TEXT DEFAULT NULL;
    DECLARE v_intentos INT DEFAULT 0;

    -- Buscar usuario
    SELECT PK_ID_USUARIO, ESTADO, FECHA_BLOQUEO, CONTRASENIA, INTENTOS_FALLIDOS
    INTO v_id_usuario, v_estado, v_fecha_bloqueo, v_contrasenia_hash, v_intentos
    FROM usuario
    WHERE NOMBRE_USUARIO = LOWER(TRIM(p_nombre_usuario))
    LIMIT 1;

    -- Usuario no existe
    IF v_id_usuario = 0 OR v_id_usuario IS NULL THEN
        SELECT 98 AS CODIGO_ESTADO, NULL AS CONTRASENIA_HASH, 0 AS PK_ID_USUARIO;
    -- Usuario inhabilitado
    ELSEIF v_estado = 0 THEN
        SELECT 97 AS CODIGO_ESTADO, NULL AS CONTRASENIA_HASH, v_id_usuario AS PK_ID_USUARIO;
    -- Usuario bloqueado temporalmente
    ELSEIF v_fecha_bloqueo IS NOT NULL AND v_fecha_bloqueo > NOW() THEN
        SELECT 0 AS CODIGO_ESTADO, NULL AS CONTRASENIA_HASH, v_id_usuario AS PK_ID_USUARIO;
    -- Usuario válido - retornar datos para verificación
    ELSE
        SELECT
            1 AS CODIGO_ESTADO,
            u.CONTRASENIA AS CONTRASENIA_HASH,
            u.PK_ID_USUARIO,
            u.NOMBRES,
            u.APELLIDOS,
            u.NOMBRE_USUARIO AS CORREO,
            u.TELEFONO,
            u.DOCUMENTO_IDENTIDAD,
            u.FK_ID_TIPO_DOCUMENTO,
            u.ESTADO,
            u.INTENTOS_FALLIDOS,
            u.FECHA_BLOQUEO,
            u.CODIGO_REFERIDO,
            u.CREDITO_REFERIDOS,
            l.PK_ID_LOCAL AS ID_LOCAL,
            l.NOMBRE AS NOMBRE_LOCAL
        FROM usuario u
        LEFT JOIN local l ON l.FK_ID_USUARIO = u.PK_ID_USUARIO
        WHERE u.PK_ID_USUARIO = v_id_usuario;
    END IF;
END//
DELIMITER ;

-- =====================================================
-- SP: obtener_estadisticas_dashboard (sin persona)
-- =====================================================
DROP PROCEDURE IF EXISTS obtener_estadisticas_dashboard;
DELIMITER //
CREATE PROCEDURE obtener_estadisticas_dashboard(
    IN p_fecha_inicio DATE,
    IN p_fecha_fin DATE
)
BEGIN
    -- Estadísticas generales
    SELECT
        (SELECT COUNT(*) FROM usuario WHERE ESTADO = 1) AS TotalUsuariosActivos,
        (SELECT COUNT(*) FROM local WHERE ESTADO = 1) AS TotalNegociosActivos,
        (SELECT COUNT(*) FROM producto WHERE ESTADO = 1) AS TotalProductosActivos,
        (SELECT COUNT(*) FROM suscripcion WHERE ESTADO = 1 AND FECHA_FIN >= NOW()) AS SuscripcionesActivas,
        (SELECT COUNT(*) FROM usuario WHERE DATE(FECHA_BLOQUEO) BETWEEN p_fecha_inicio AND p_fecha_fin) AS NuevosUsuariosPeriodo,
        (SELECT COALESCE(SUM(MONTO), 0) FROM suscripcion WHERE DATE(FECHA_INICIO) BETWEEN p_fecha_inicio AND p_fecha_fin) AS IngresosPeriodo;
END//
DELIMITER ;

SELECT 'MIGRACIÓN 076 - SPs CORREGIDOS (sin tabla persona)' as info;
