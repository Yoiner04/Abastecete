-- =============================================================================
-- Migración 007: Corregir SPs de usuarios que referencian tablas inexistentes
-- Fecha: 2025-12-29
-- Descripción: Los SPs contar_usuarios y consultar_usuarios_paginado
--              referenciaban la tabla 'persona' que ya no existe.
--              Ahora usan directamente la tabla 'usuario'.
-- =============================================================================

-- Eliminar SPs antiguos
DROP PROCEDURE IF EXISTS contar_usuarios;
DROP PROCEDURE IF EXISTS consultar_usuarios_paginado;

-- =============================================================================
-- SP: contar_usuarios
-- Cuenta el total de usuarios con filtro de búsqueda
-- =============================================================================
DELIMITER //
CREATE PROCEDURE `contar_usuarios`(
    IN `p_busqueda` VARCHAR(100)
)
BEGIN
    SELECT COUNT(DISTINCT u.PK_ID_USUARIO) AS Total
    FROM usuario u
    LEFT JOIN local l ON l.FK_ID_USUARIO = u.PK_ID_USUARIO
    WHERE (p_busqueda IS NULL OR p_busqueda = '' OR
           u.NOMBRES LIKE CONCAT('%', p_busqueda, '%') OR
           u.APELLIDOS LIKE CONCAT('%', p_busqueda, '%') OR
           u.NOMBRE_USUARIO LIKE CONCAT('%', p_busqueda, '%') OR
           l.NOMBRE_LOCAL LIKE CONCAT('%', p_busqueda, '%'));
END//
DELIMITER ;

-- =============================================================================
-- SP: consultar_usuarios_paginado
-- Obtiene usuarios con paginación e información de local y suscripción
-- =============================================================================
DELIMITER //
CREATE PROCEDURE `consultar_usuarios_paginado`(
    IN `p_pagina` INT,
    IN `p_registros_por_pagina` INT,
    IN `p_busqueda` VARCHAR(100)
)
BEGIN
    DECLARE v_offset INT;
    SET v_offset = (p_pagina - 1) * p_registros_por_pagina;

    SELECT
        u.PK_ID_USUARIO AS UsuarioId,
        u.NOMBRES AS Nombres,
        u.APELLIDOS AS Apellidos,
        u.TELEFONO AS Telefono,
        u.NOMBRE_USUARIO AS Correo,
        u.ESTADO AS UsuarioEstado,
        '' AS RolNombre,
        l.PK_ID_LOCAL AS LocalId,
        l.NOMBRE_LOCAL AS LocalNombre,
        s.PK_ID_SUSCRIPCION AS SuscripcionId,
        s.FECHA_INICIO AS SuscripcionFechaInicio,
        s.FECHA_FIN AS SuscripcionFechaFin,
        s.ESTADO AS SuscripcionEstado,
        tm.PK_ID_TIPO_MEMBRESIA AS TipoMembresiaId,
        tm.NOMBRE AS TipoMembresiaNombre
    FROM usuario u
    LEFT JOIN local l ON l.FK_ID_USUARIO = u.PK_ID_USUARIO
    LEFT JOIN suscripcion s ON s.PK_ID_SUSCRIPCION = l.FK_ID_SUSCRIPCION_ACTIVA
    LEFT JOIN tipo_membresia tm ON tm.PK_ID_TIPO_MEMBRESIA = s.FK_ID_TIPO_MEMBRESIA
    WHERE (p_busqueda IS NULL OR p_busqueda = '' OR
           u.NOMBRES LIKE CONCAT('%', p_busqueda, '%') OR
           u.APELLIDOS LIKE CONCAT('%', p_busqueda, '%') OR
           u.NOMBRE_USUARIO LIKE CONCAT('%', p_busqueda, '%') OR
           l.NOMBRE_LOCAL LIKE CONCAT('%', p_busqueda, '%'))
    ORDER BY u.PK_ID_USUARIO DESC
    LIMIT v_offset, p_registros_por_pagina;
END//
DELIMITER ;

-- =============================================================================
-- Verificación
-- =============================================================================
SELECT 'SPs contar_usuarios y consultar_usuarios_paginado actualizados correctamente' AS Mensaje;
