-- =============================================
-- Migración 027: Crear SP consultar_usuarios_paginado
-- Descripción: Paginación en backend para evitar traer todos los usuarios
--              Incluye datos de local y suscripción en una sola consulta
-- =============================================

DELIMITER //

-- SP con paginación
DROP PROCEDURE IF EXISTS `consultar_usuarios_paginado`//

CREATE PROCEDURE `consultar_usuarios_paginado`(
    IN `p_pagina` INT,
    IN `p_registros_por_pagina` INT,
    IN `p_busqueda` VARCHAR(100)
)
BEGIN
    DECLARE v_offset INT;
    SET v_offset = (p_pagina - 1) * p_registros_por_pagina;

    -- Consulta principal con paginación
    SELECT
        u.PK_ID_USUARIO AS UsuarioId,
        COALESCE(u.ESTADO, 0) AS UsuarioEstado,
        COALESCE(p.PK_ID_PERSONA, 0) AS PersonaId,
        COALESCE(p.NOMBRES, '') AS PersonaNombres,
        COALESCE(p.APELLIDOS, '') AS PersonaApellidos,
        COALESCE(p.TELEFONO, '') AS PersonaTelefono,
        COALESCE(p.CORREO, '') AS PersonaCorreo,
        COALESCE(r.NOMBRE_ROL, 'Sin rol') AS RolNombre,
        l.PK_ID_LOCAL AS LocalId,
        COALESCE(l.NOMBRE_LOCAL, '') AS LocalNombre,
        s.PK_ID_SUSCRIPCION AS SuscripcionId,
        s.FECHA_INICIO AS SuscripcionFechaInicio,
        s.FECHA_FIN AS SuscripcionFechaFin,
        s.ESTADO AS SuscripcionEstado,
        tm.PK_ID_TIPO_MEMBRESIA AS TipoMembresiaId,
        COALESCE(tm.NOMBRE, 'Sin membresía') AS TipoMembresiaNombre
    FROM usuario u
    LEFT JOIN persona p ON u.FK_ID_PERSONA = p.PK_ID_PERSONA
    LEFT JOIN rol r ON u.FK_ID_ROL = r.PK_ID_ROL
    LEFT JOIN local l ON l.FK_ID_PERSONA = p.PK_ID_PERSONA
    LEFT JOIN suscripcion s ON l.FK_ID_SUSCRIPCION_ACTIVA = s.PK_ID_SUSCRIPCION
    LEFT JOIN tipo_membresia tm ON s.FK_ID_TIPO_MEMBRESIA = tm.PK_ID_TIPO_MEMBRESIA
    WHERE (p_busqueda IS NULL OR p_busqueda = '' OR
           p.NOMBRES LIKE CONCAT('%', p_busqueda, '%') OR
           p.APELLIDOS LIKE CONCAT('%', p_busqueda, '%') OR
           p.CORREO LIKE CONCAT('%', p_busqueda, '%') OR
           l.NOMBRE_LOCAL LIKE CONCAT('%', p_busqueda, '%'))
    ORDER BY u.PK_ID_USUARIO DESC
    LIMIT p_registros_por_pagina OFFSET v_offset;
END//

-- SP para contar total de registros (para calcular páginas)
DROP PROCEDURE IF EXISTS `contar_usuarios`//

CREATE PROCEDURE `contar_usuarios`(
    IN `p_busqueda` VARCHAR(100)
)
BEGIN
    SELECT COUNT(DISTINCT u.PK_ID_USUARIO) AS Total
    FROM usuario u
    LEFT JOIN persona p ON u.FK_ID_PERSONA = p.PK_ID_PERSONA
    LEFT JOIN local l ON l.FK_ID_PERSONA = p.PK_ID_PERSONA
    WHERE (p_busqueda IS NULL OR p_busqueda = '' OR
           p.NOMBRES LIKE CONCAT('%', p_busqueda, '%') OR
           p.APELLIDOS LIKE CONCAT('%', p_busqueda, '%') OR
           p.CORREO LIKE CONCAT('%', p_busqueda, '%') OR
           l.NOMBRE_LOCAL LIKE CONCAT('%', p_busqueda, '%'));
END//

DELIMITER ;
