-- Migración 069: Eliminar tablas obsoletas del sistema de permisos viejo
-- ============================================================
-- Las siguientes tablas ya no se usan porque el nuevo sistema usa:
-- - permiso_sistema (catálogo de permisos)
-- - tipo_membresia_permiso (permisos por membresía)
-- - usuario_permiso (permisos efectivos por usuario)
-- ============================================================

SET FOREIGN_KEY_CHECKS = 0;

-- =====================================================
-- PASO 1: Eliminar SPs obsoletos que usan tabla permiso/rol
-- =====================================================

-- SP que consulta permisos por rol (sistema viejo)
DROP PROCEDURE IF EXISTS consultar_permisos;

-- SP que crea permisos (sistema viejo)
DROP PROCEDURE IF EXISTS crear_permiso;

-- SP que edita permisos (sistema viejo)
DROP PROCEDURE IF EXISTS editar_permiso;

-- SP que elimina permisos (sistema viejo)
DROP PROCEDURE IF EXISTS eliminar_permiso;

-- SP que asigna permiso a rol (sistema viejo)
DROP PROCEDURE IF EXISTS asignar_permiso;

-- SP que quita permiso de rol (sistema viejo)
DROP PROCEDURE IF EXISTS quitar_permiso_rol;

-- SPs de roles (sistema viejo)
DROP PROCEDURE IF EXISTS crear_rol;
DROP PROCEDURE IF EXISTS consultar_roles;
DROP PROCEDURE IF EXISTS asignar_rol;
DROP PROCEDURE IF EXISTS editar_rol;
DROP PROCEDURE IF EXISTS eliminar_rol;

-- SPs de usuarios que usaban persona/rol (sistema viejo)
DROP PROCEDURE IF EXISTS consultar_usuarios;
DROP PROCEDURE IF EXISTS consultar_usuarios_paginado;

-- =====================================================
-- PASO 2: Renombrar tabla permiso a permiso_legacy (si existe)
-- =====================================================
-- La tabla "permiso" se renombra para evitar confusión con "permiso_sistema"
-- Si ya no existe, simplemente continuamos

-- Verificar si existe la tabla permiso antes de renombrar
SET @tabla_existe = (SELECT COUNT(*) FROM information_schema.tables
                     WHERE table_schema = DATABASE() AND table_name = 'permiso');

SET @sql = IF(@tabla_existe > 0, 'RENAME TABLE permiso TO permiso_legacy', 'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- =====================================================
-- PASO 2: Eliminar FK de usuario hacia rol
-- =====================================================

-- Eliminar la constraint FK_usuario_rol
ALTER TABLE usuario DROP FOREIGN KEY FK_usuario_rol;

-- Eliminar la columna FK_ID_ROL de usuario
ALTER TABLE usuario DROP COLUMN FK_ID_ROL;

-- =====================================================
-- PASO 3: Eliminar tablas obsoletas
-- =====================================================

-- Eliminar tabla permiso_de_rol (relación rol-permiso)
DROP TABLE IF EXISTS permiso_de_rol;

-- Eliminar tabla permiso_legacy (permisos viejos de menú)
DROP TABLE IF EXISTS permiso_legacy;

-- Eliminar tabla rol (Admin, Proveedor, Cliente)
DROP TABLE IF EXISTS rol;

SET FOREIGN_KEY_CHECKS = 1;

-- =====================================================
-- PASO 4: Recrear SPs de usuarios sin referencias a persona/rol
-- =====================================================

-- SP: consultar_usuario (ahora sin FK_ID_ROL)
DROP PROCEDURE IF EXISTS consultar_usuario;
DELIMITER //
CREATE PROCEDURE consultar_usuario(
    IN p_id_usuario INT
)
BEGIN
    IF p_id_usuario > 0 THEN
        SELECT
            PK_ID_USUARIO, NOMBRES, APELLIDOS, TELEFONO, NOMBRE_USUARIO AS CORREO,
            DOCUMENTO_IDENTIDAD, FK_ID_TIPO_DOCUMENTO, ESTADO,
            CODIGO_REFERIDO, CODIGO_REFERIDO_USADO, CORREO_VERIFICADO,
            CLIENTES_REFERIDOS_TOTAL
        FROM usuario
        WHERE PK_ID_USUARIO = p_id_usuario;
    ELSE
        SELECT
            PK_ID_USUARIO, NOMBRES, APELLIDOS, TELEFONO, NOMBRE_USUARIO AS CORREO,
            DOCUMENTO_IDENTIDAD, FK_ID_TIPO_DOCUMENTO, ESTADO,
            CODIGO_REFERIDO, CODIGO_REFERIDO_USADO, CORREO_VERIFICADO,
            CLIENTES_REFERIDOS_TOTAL
        FROM usuario;
    END IF;
END//
DELIMITER ;

-- SP: consultar_usuarios_paginado (sin persona ni rol, con membresía)
DROP PROCEDURE IF EXISTS consultar_usuarios_paginado;
DELIMITER //
CREATE PROCEDURE consultar_usuarios_paginado(
    IN p_pagina INT,
    IN p_registros_por_pagina INT,
    IN p_busqueda VARCHAR(100)
)
BEGIN
    DECLARE v_offset INT;
    SET v_offset = (p_pagina - 1) * p_registros_por_pagina;

    SELECT
        u.PK_ID_USUARIO AS UsuarioId,
        COALESCE(u.ESTADO, 0) AS UsuarioEstado,
        COALESCE(u.NOMBRES, '') AS Nombres,
        COALESCE(u.APELLIDOS, '') AS Apellidos,
        COALESCE(u.TELEFONO, '') AS Telefono,
        COALESCE(u.NOMBRE_USUARIO, '') AS Correo,
        l.PK_ID_LOCAL AS LocalId,
        COALESCE(l.NOMBRE_LOCAL, '') AS LocalNombre,
        s.PK_ID_SUSCRIPCION AS SuscripcionId,
        s.FECHA_INICIO AS SuscripcionFechaInicio,
        s.FECHA_FIN AS SuscripcionFechaFin,
        s.ESTADO AS SuscripcionEstado,
        tm.PK_ID_TIPO_MEMBRESIA AS TipoMembresiaId,
        COALESCE(tm.NOMBRE, 'Sin membresía') AS TipoMembresiaNombre
    FROM usuario u
    LEFT JOIN local l ON l.FK_ID_USUARIO = u.PK_ID_USUARIO
    LEFT JOIN suscripcion s ON l.FK_ID_SUSCRIPCION_ACTIVA = s.PK_ID_SUSCRIPCION
    LEFT JOIN tipo_membresia tm ON s.FK_ID_TIPO_MEMBRESIA = tm.PK_ID_TIPO_MEMBRESIA
    WHERE (p_busqueda IS NULL OR p_busqueda = '' OR
           u.NOMBRES LIKE CONCAT('%', p_busqueda, '%') OR
           u.APELLIDOS LIKE CONCAT('%', p_busqueda, '%') OR
           u.NOMBRE_USUARIO LIKE CONCAT('%', p_busqueda, '%') OR
           l.NOMBRE_LOCAL LIKE CONCAT('%', p_busqueda, '%'))
    ORDER BY u.PK_ID_USUARIO DESC
    LIMIT p_registros_por_pagina OFFSET v_offset;
END//
DELIMITER ;

-- =====================================================
-- VERIFICACIÓN
-- =====================================================

SELECT 'TABLAS ELIMINADAS:' as info;
SELECT 'permiso_de_rol, permiso (renombrada a permiso_legacy y eliminada), rol' as tablas_eliminadas;

SELECT 'COLUMNAS ELIMINADAS DE USUARIO:' as info;
SELECT 'FK_ID_ROL' as columna_eliminada;

SELECT 'ESTRUCTURA ACTUAL DE USUARIO:' as info;
DESCRIBE usuario;
