-- =============================================
-- Migración 020: Limpiar estructura antigua
-- IMPORTANTE: EJECUTAR SOLO DESPUÉS DE VERIFICAR QUE LA MIGRACIÓN FUNCIONA
-- Se recomienda hacer backup antes de ejecutar este script
-- =============================================

-- ==========================================
-- ADVERTENCIA: Este script elimina columnas y tablas antiguas
-- Solo ejecutar cuando se confirme que el sistema funciona correctamente
-- con la nueva estructura de suscripciones
-- ==========================================

-- Paso 1: Eliminar FK de usuario a membresia (si existe)
-- Primero verificamos si existe el constraint
SET @constraint_exists = (
    SELECT COUNT(*)
    FROM information_schema.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE()
    AND TABLE_NAME = 'usuario'
    AND CONSTRAINT_NAME = 'FK_usuario_membresia'
);

-- Si existe, lo eliminamos
SET @sql = IF(@constraint_exists > 0,
    'ALTER TABLE usuario DROP FOREIGN KEY FK_usuario_membresia',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Verificar si la columna FK_ID_MEMBRESIA existe antes de eliminarla
SET @column_exists = (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'usuario'
    AND COLUMN_NAME = 'FK_ID_MEMBRESIA'
);

SET @sql = IF(@column_exists > 0,
    'ALTER TABLE usuario DROP COLUMN FK_ID_MEMBRESIA',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Paso 2: Eliminar FK de local a tipo_membresia (si existe)
SET @constraint_exists = (
    SELECT COUNT(*)
    FROM information_schema.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE()
    AND TABLE_NAME = 'local'
    AND CONSTRAINT_NAME = 'FK_local_tipomembresia'
);

SET @sql = IF(@constraint_exists > 0,
    'ALTER TABLE local DROP FOREIGN KEY FK_local_tipomembresia',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Verificar si la columna FK_ID_TIPOMEMBRESIA existe
SET @column_exists = (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'local'
    AND COLUMN_NAME = 'FK_ID_TIPOMEMBRESIA'
);

SET @sql = IF(@column_exists > 0,
    'ALTER TABLE local DROP COLUMN FK_ID_TIPOMEMBRESIA',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Paso 3: Renombrar tabla antigua (preservar por seguridad en lugar de eliminar)
-- Verificar si la tabla membresia_local existe
SET @table_exists = (
    SELECT COUNT(*)
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'membresia_local'
);

SET @sql = IF(@table_exists > 0,
    'RENAME TABLE membresia_local TO membresia_local_deprecated',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Mensaje informativo
SELECT 'Limpieza completada. La tabla membresia_local fue renombrada a membresia_local_deprecated.' AS Mensaje;
SELECT 'Puede eliminarla manualmente con: DROP TABLE membresia_local_deprecated;' AS Nota;
