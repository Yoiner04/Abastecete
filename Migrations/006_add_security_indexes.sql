-- =============================================
-- Migración: 006_add_security_indexes.sql
-- Fecha: 2025-12-15
-- Descripción: Agrega índices para mejorar seguridad y rendimiento
-- =============================================

-- Procedimiento auxiliar para crear índices de forma segura
DROP PROCEDURE IF EXISTS crear_indice_seguro;

DELIMITER //
CREATE PROCEDURE crear_indice_seguro(
    IN p_tabla VARCHAR(64),
    IN p_indice VARCHAR(64),
    IN p_columnas VARCHAR(255)
)
BEGIN
    DECLARE CONTINUE HANDLER FOR 1061 BEGIN END;

    SET @sql = CONCAT('CREATE INDEX ', p_indice, ' ON ', p_tabla, '(', p_columnas, ')');
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
END//
DELIMITER ;

-- Crear índices
CALL crear_indice_seguro('usuario', 'idx_usuario_nombre_usuario', 'NOMBRE_USUARIO');
CALL crear_indice_seguro('persona', 'idx_persona_correo', 'CORREO');
CALL crear_indice_seguro('persona', 'idx_persona_documento', 'DOCUMENTO_IDENTIDAD, FK_ID_TIPO_DOCUMENTO');
CALL crear_indice_seguro('usuario', 'idx_usuario_token', 'TOKEN_RECUPERACION');
CALL crear_indice_seguro('usuario', 'idx_usuario_bloqueo', 'ESTADO, FECHA_BLOQUEO');
CALL crear_indice_seguro('persona', 'idx_persona_codigo_referido', 'CODIGO_REFERIDO');

-- Limpiar procedimiento auxiliar
DROP PROCEDURE IF EXISTS crear_indice_seguro;

SELECT 'Índices creados exitosamente' AS resultado;
