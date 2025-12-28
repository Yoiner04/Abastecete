-- Migración 070: Renombrar permiso_sistema a permiso
-- ============================================================
-- La tabla permiso_sistema se renombra a permiso (nombre más simple)
-- Se ajustan las FKs y SPs que la referencian
-- REQUIERE: Ejecutar primero 069 (eliminar tablas viejas)
-- ============================================================

SET FOREIGN_KEY_CHECKS = 0;

-- =====================================================
-- PASO 1: Eliminar tablas viejas si aún existen
-- =====================================================

DROP TABLE IF EXISTS permiso_de_rol;
DROP TABLE IF EXISTS permiso_legacy;

-- Verificar si existe la tabla permiso vieja y eliminarla
SET @tabla_permiso_vieja = (SELECT COUNT(*) FROM information_schema.tables
                            WHERE table_schema = DATABASE() AND table_name = 'permiso');

SET @sql_drop = IF(@tabla_permiso_vieja > 0, 'DROP TABLE permiso', 'SELECT 1');
PREPARE stmt FROM @sql_drop;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- =====================================================
-- PASO 2: Eliminar FKs que apuntan a permiso_sistema
-- =====================================================

-- FK de tipo_membresia_permiso
ALTER TABLE tipo_membresia_permiso DROP FOREIGN KEY tipo_membresia_permiso_ibfk_2;

-- FK de usuario_permiso
ALTER TABLE usuario_permiso DROP FOREIGN KEY usuario_permiso_ibfk_2;

-- =====================================================
-- PASO 3: Renombrar permiso_sistema a permiso
-- =====================================================

RENAME TABLE permiso_sistema TO permiso;

-- =====================================================
-- PASO 4: Recrear FKs apuntando a la nueva tabla permiso
-- =====================================================

ALTER TABLE tipo_membresia_permiso
ADD CONSTRAINT FK_tipo_membresia_permiso_permiso
FOREIGN KEY (FK_ID_PERMISO) REFERENCES permiso(PK_ID_PERMISO) ON DELETE CASCADE;

ALTER TABLE usuario_permiso
ADD CONSTRAINT FK_usuario_permiso_permiso
FOREIGN KEY (FK_ID_PERMISO) REFERENCES permiso(PK_ID_PERMISO) ON DELETE CASCADE;

SET FOREIGN_KEY_CHECKS = 1;

-- =====================================================
-- PASO 5: Actualizar SPs que usan permiso_sistema
-- =====================================================

-- SP: asignar_permisos_membresia
DROP PROCEDURE IF EXISTS asignar_permisos_membresia;
DELIMITER //
CREATE PROCEDURE asignar_permisos_membresia(
    IN p_id_tipo_membresia INT,
    IN p_codigos_permisos TEXT
)
BEGIN
    DECLARE v_sql TEXT;

    -- Eliminar permisos actuales de la membresía
    DELETE FROM tipo_membresia_permiso WHERE FK_ID_TIPO_MEMBRESIA = p_id_tipo_membresia;

    -- Insertar nuevos permisos
    IF p_codigos_permisos IS NOT NULL AND p_codigos_permisos != '' THEN
        SET @sql = CONCAT(
            'INSERT INTO tipo_membresia_permiso (FK_ID_TIPO_MEMBRESIA, FK_ID_PERMISO) ',
            'SELECT ', p_id_tipo_membresia, ', PK_ID_PERMISO FROM permiso ',
            'WHERE FIND_IN_SET(CODIGO, ''', p_codigos_permisos, ''') > 0'
        );
        PREPARE stmt FROM @sql;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END IF;

    SELECT ROW_COUNT() as permisos_asignados;
END//
DELIMITER ;

-- SP: consultar_permisos_membresia
DROP PROCEDURE IF EXISTS consultar_permisos_membresia;
DELIMITER //
CREATE PROCEDURE consultar_permisos_membresia(
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

-- SP: consultar_permisos_sistema
DROP PROCEDURE IF EXISTS consultar_permisos_sistema;
DELIMITER //
CREATE PROCEDURE consultar_permisos_sistema()
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

-- SP: consultar_permisos_usuario
DROP PROCEDURE IF EXISTS consultar_permisos_usuario;
DELIMITER //
CREATE PROCEDURE consultar_permisos_usuario(
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
        up.ORIGEN,
        up.FECHA_ASIGNACION
    FROM usuario_permiso up
    INNER JOIN permiso ps ON up.FK_ID_PERMISO = ps.PK_ID_PERMISO
    WHERE up.FK_ID_USUARIO = p_id_usuario
      AND up.ESTADO = 1
    ORDER BY ps.CATEGORIA, ps.ORDEN;
END//
DELIMITER ;

-- =====================================================
-- VERIFICACIÓN
-- =====================================================

SELECT 'TABLA RENOMBRADA:' as info;
SELECT 'permiso_sistema -> permiso' as cambio;

SELECT 'ESTRUCTURA DE TABLA PERMISO:' as info;
DESCRIBE permiso;

SELECT 'FKs ACTUALIZADAS:' as info;
SELECT
    TABLE_NAME,
    CONSTRAINT_NAME,
    REFERENCED_TABLE_NAME
FROM information_schema.KEY_COLUMN_USAGE
WHERE REFERENCED_TABLE_NAME = 'permiso'
  AND TABLE_SCHEMA = DATABASE();

SELECT 'TOTAL PERMISOS:' as info;
SELECT COUNT(*) as total FROM permiso;
