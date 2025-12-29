-- Migración 071: Corregir SPs que usan permiso_sistema
-- ============================================================
-- La tabla ya se llama 'permiso', pero algunos SPs aún
-- referencian 'permiso_sistema'. Este script los corrige.
-- ============================================================

-- =====================================================
-- SP: actualizar_permisos_membresia
-- =====================================================
DROP PROCEDURE IF EXISTS actualizar_permisos_membresia;
DELIMITER //
CREATE PROCEDURE actualizar_permisos_membresia(
    IN p_id_tipo_membresia INT,
    IN p_ids_permisos TEXT -- Lista separada por comas: "1,2,3,5"
)
BEGIN
    -- Eliminar permisos actuales de la membresía
    DELETE FROM tipo_membresia_permiso
    WHERE FK_ID_TIPO_MEMBRESIA = p_id_tipo_membresia;

    -- Insertar nuevos permisos si hay alguno
    IF p_ids_permisos IS NOT NULL AND p_ids_permisos != '' THEN
        SET @sql = CONCAT(
            'INSERT INTO tipo_membresia_permiso (FK_ID_TIPO_MEMBRESIA, FK_ID_PERMISO) ',
            'SELECT ', p_id_tipo_membresia, ', PK_ID_PERMISO FROM permiso ',
            'WHERE PK_ID_PERMISO IN (', p_ids_permisos, ') AND ESTADO = 1'
        );
        PREPARE stmt FROM @sql;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END IF;

    SELECT COUNT(*) as permisos_asignados
    FROM tipo_membresia_permiso
    WHERE FK_ID_TIPO_MEMBRESIA = p_id_tipo_membresia;
END//
DELIMITER ;

-- =====================================================
-- SP: obtener_permisos_membresia
-- =====================================================
DROP PROCEDURE IF EXISTS obtener_permisos_membresia;
DELIMITER //
CREATE PROCEDURE obtener_permisos_membresia(
    IN p_id_tipo_membresia INT
)
BEGIN
    SELECT
        ps.PK_ID_PERMISO,
        ps.CODIGO,
        ps.NOMBRE,
        ps.DESCRIPCION,
        ps.ICONO,
        ps.CATEGORIA,
        ps.ORDEN
    FROM permiso ps
    INNER JOIN tipo_membresia_permiso tmp ON ps.PK_ID_PERMISO = tmp.FK_ID_PERMISO
    WHERE tmp.FK_ID_TIPO_MEMBRESIA = p_id_tipo_membresia
    ORDER BY ps.CATEGORIA, ps.ORDEN;
END//
DELIMITER ;

-- =====================================================
-- SP: obtener_permisos_sistema
-- =====================================================
DROP PROCEDURE IF EXISTS obtener_permisos_sistema;
DELIMITER //
CREATE PROCEDURE obtener_permisos_sistema()
BEGIN
    SELECT
        PK_ID_PERMISO,
        CODIGO,
        NOMBRE,
        DESCRIPCION,
        ICONO,
        CATEGORIA,
        ORDEN,
        ESTADO
    FROM permiso
    WHERE ESTADO = 1
    ORDER BY CATEGORIA, ORDEN;
END//
DELIMITER ;

-- =====================================================
-- SP: obtener_permisos_usuario
-- =====================================================
DROP PROCEDURE IF EXISTS obtener_permisos_usuario;
DELIMITER //
CREATE PROCEDURE obtener_permisos_usuario(
    IN p_id_usuario INT
)
BEGIN
    SELECT
        ps.PK_ID_PERMISO,
        ps.CODIGO,
        ps.NOMBRE,
        ps.DESCRIPCION,
        ps.ICONO,
        ps.CATEGORIA,
        ps.ORDEN,
        up.ORIGEN,
        up.FECHA_ASIGNACION,
        up.ESTADO
    FROM usuario_permiso up
    INNER JOIN permiso ps ON up.FK_ID_PERMISO = ps.PK_ID_PERMISO
    WHERE up.FK_ID_USUARIO = p_id_usuario
      AND up.ESTADO = 1
    ORDER BY ps.CATEGORIA, ps.ORDEN;
END//
DELIMITER ;

-- =====================================================
-- SP: verificar_permiso_usuario
-- =====================================================
DROP PROCEDURE IF EXISTS verificar_permiso_usuario;
DELIMITER //
CREATE PROCEDURE verificar_permiso_usuario(
    IN p_id_usuario INT,
    IN p_codigo_permiso VARCHAR(50)
)
BEGIN
    DECLARE v_tiene_permiso INT DEFAULT 0;

    SELECT COUNT(*) INTO v_tiene_permiso
    FROM usuario_permiso up
    INNER JOIN permiso ps ON up.FK_ID_PERMISO = ps.PK_ID_PERMISO
    WHERE up.FK_ID_USUARIO = p_id_usuario
      AND ps.CODIGO = p_codigo_permiso
      AND up.ESTADO = 1;

    SELECT v_tiene_permiso > 0 as tiene_permiso;
END//
DELIMITER ;

-- =====================================================
-- VERIFICACIÓN
-- =====================================================

SELECT 'SPs ACTUALIZADOS:' as info;
SHOW PROCEDURE STATUS WHERE Db = DATABASE() AND Name IN (
    'actualizar_permisos_membresia',
    'obtener_permisos_membresia',
    'obtener_permisos_sistema',
    'obtener_permisos_usuario',
    'verificar_permiso_usuario'
);
