-- Migración 063: Unificar tablas persona y usuario
-- ============================================================
-- ADVERTENCIA: Este script modifica estructura de BD.
-- Hacer backup antes de ejecutar.
-- ============================================================

SET FOREIGN_KEY_CHECKS = 0;

-- =====================================================
-- PASO 1: Agregar columnas de persona a usuario
-- =====================================================

-- Agregar columnas de persona que no existen en usuario
ALTER TABLE usuario
    ADD COLUMN NOMBRES VARCHAR(40) NOT NULL DEFAULT '' AFTER PK_ID_USUARIO,
    ADD COLUMN APELLIDOS VARCHAR(40) NOT NULL DEFAULT '' AFTER NOMBRES,
    ADD COLUMN TELEFONO VARCHAR(40) DEFAULT NULL AFTER APELLIDOS,
    ADD COLUMN DOCUMENTO_IDENTIDAD BIGINT DEFAULT NULL AFTER TELEFONO,
    ADD COLUMN FK_ID_TIPO_DOCUMENTO INT DEFAULT 1 AFTER DOCUMENTO_IDENTIDAD,
    ADD COLUMN CODIGO_REFERIDO VARCHAR(20) DEFAULT NULL AFTER FK_ID_TIPO_DOCUMENTO,
    ADD COLUMN CODIGO_REFERIDO_USADO VARCHAR(20) DEFAULT NULL AFTER CODIGO_REFERIDO;

-- =====================================================
-- PASO 2: Migrar datos de persona a usuario
-- =====================================================

UPDATE usuario u
INNER JOIN persona p ON u.FK_ID_PERSONA = p.PK_ID_PERSONA
SET
    u.NOMBRES = p.NOMBRES,
    u.APELLIDOS = p.APELLIDOS,
    u.TELEFONO = p.TELEFONO,
    u.DOCUMENTO_IDENTIDAD = p.DOCUMENTO_IDENTIDAD,
    u.FK_ID_TIPO_DOCUMENTO = p.FK_ID_TIPO_DOCUMENTO,
    u.CODIGO_REFERIDO = p.CODIGO_REFERIDO,
    u.CODIGO_REFERIDO_USADO = p.CODIGO_REFERIDO_USUARIO;

-- =====================================================
-- PASO 3: Actualizar FK en tabla local
-- =====================================================

-- Agregar columna FK_ID_USUARIO a local
ALTER TABLE local ADD COLUMN FK_ID_USUARIO INT DEFAULT NULL AFTER FK_ID_PERSONA;

-- Migrar FK_ID_PERSONA a FK_ID_USUARIO
UPDATE local l
INNER JOIN usuario u ON l.FK_ID_PERSONA = u.FK_ID_PERSONA
SET l.FK_ID_USUARIO = u.PK_ID_USUARIO;

-- Crear FK hacia usuario
ALTER TABLE local
    ADD CONSTRAINT FK_local_usuario FOREIGN KEY (FK_ID_USUARIO) REFERENCES usuario(PK_ID_USUARIO) ON DELETE CASCADE;

-- Eliminar FK hacia persona y columna
ALTER TABLE local DROP FOREIGN KEY FK_local_persona;
ALTER TABLE local DROP COLUMN FK_ID_PERSONA;

-- =====================================================
-- PASO 4: Actualizar FK en tabla opinion (si existe)
-- =====================================================

-- Verificar si opinion tiene FK_ID_PERSONA y actualizarla
ALTER TABLE opinion ADD COLUMN FK_ID_USUARIO INT DEFAULT NULL AFTER FK_ID_PERSONA;

UPDATE opinion o
INNER JOIN usuario u ON o.FK_ID_PERSONA = u.FK_ID_PERSONA
SET o.FK_ID_USUARIO = u.PK_ID_USUARIO;

ALTER TABLE opinion
    ADD CONSTRAINT FK_opinion_usuario FOREIGN KEY (FK_ID_USUARIO) REFERENCES usuario(PK_ID_USUARIO) ON DELETE CASCADE;

ALTER TABLE opinion DROP FOREIGN KEY FK_opinion_persona;
ALTER TABLE opinion DROP COLUMN FK_ID_PERSONA;

-- =====================================================
-- PASO 5: Eliminar FK_ID_PERSONA de usuario y tabla persona
-- =====================================================

-- Eliminar FK de usuario hacia persona
ALTER TABLE usuario DROP FOREIGN KEY FK_usuario_persona;
ALTER TABLE usuario DROP COLUMN FK_ID_PERSONA;

-- Eliminar tabla persona
DROP TABLE persona;

-- =====================================================
-- PASO 6: Agregar índices a nuevas columnas
-- =====================================================

ALTER TABLE usuario
    ADD INDEX idx_usuario_documento (DOCUMENTO_IDENTIDAD, FK_ID_TIPO_DOCUMENTO),
    ADD INDEX idx_usuario_codigo_referido (CODIGO_REFERIDO);

-- Agregar FK a tipo_documento
ALTER TABLE usuario
    ADD CONSTRAINT FK_usuario_tipo_documento FOREIGN KEY (FK_ID_TIPO_DOCUMENTO)
    REFERENCES tipo_documento(PK_ID_TIPO_DOCUMENTO) ON DELETE SET NULL ON UPDATE CASCADE;

SET FOREIGN_KEY_CHECKS = 1;

-- =====================================================
-- PASO 7: Actualizar/Crear SPs principales
-- =====================================================

-- SP: Crear usuario (reemplaza crear_usuario_persona)
DROP PROCEDURE IF EXISTS crear_usuario;
DELIMITER //
CREATE PROCEDURE crear_usuario(
    IN p_nombres VARCHAR(40),
    IN p_apellidos VARCHAR(40),
    IN p_telefono VARCHAR(40),
    IN p_correo VARCHAR(100),
    IN p_contrasenia TEXT,
    IN p_documento BIGINT,
    IN p_fk_tipo_documento INT,
    IN p_fk_rol INT,
    OUT p_mensaje VARCHAR(255),
    OUT p_id_usuario INT
)
BEGIN
    DECLARE v_codigo_referido VARCHAR(20);
    DECLARE v_codigo_existe INT DEFAULT 1;

    SET p_mensaje = '';
    SET p_id_usuario = 0;

    -- Validaciones
    IF EXISTS (SELECT 1 FROM usuario WHERE NOMBRE_USUARIO = LOWER(TRIM(p_correo))) THEN
        SET p_mensaje = 'El correo electrónico ya está registrado.';
    ELSEIF p_documento IS NOT NULL AND EXISTS (SELECT 1 FROM usuario WHERE DOCUMENTO_IDENTIDAD = p_documento AND FK_ID_TIPO_DOCUMENTO = p_fk_tipo_documento) THEN
        SET p_mensaje = 'El documento de identidad ya está registrado.';
    ELSE
        -- Generar código de referido único
        WHILE v_codigo_existe > 0 DO
            SET v_codigo_referido = CONCAT('COD', LPAD(FLOOR(RAND() * 1000000), 6, '0'));
            SELECT COUNT(*) INTO v_codigo_existe FROM usuario WHERE CODIGO_REFERIDO = v_codigo_referido;
        END WHILE;

        -- Insertar usuario
        INSERT INTO usuario (
            NOMBRES, APELLIDOS, TELEFONO, DOCUMENTO_IDENTIDAD, FK_ID_TIPO_DOCUMENTO,
            CODIGO_REFERIDO, NOMBRE_USUARIO, CONTRASENIA, FK_ID_ROL, ESTADO
        ) VALUES (
            p_nombres, p_apellidos, p_telefono, p_documento, COALESCE(p_fk_tipo_documento, 1),
            v_codigo_referido, LOWER(TRIM(p_correo)), p_contrasenia, p_fk_rol, 1
        );

        SET p_id_usuario = LAST_INSERT_ID();
        SET p_mensaje = 'Usuario creado exitosamente.';
    END IF;
END//
DELIMITER ;

-- SP: Login (actualizado)
DROP PROCEDURE IF EXISTS login_usuario;
DELIMITER //
CREATE PROCEDURE login_usuario(
    IN p_correo VARCHAR(100)
)
BEGIN
    SELECT
        u.PK_ID_USUARIO,
        u.NOMBRES,
        u.APELLIDOS,
        u.NOMBRE_USUARIO AS CORREO,
        u.CONTRASENIA,
        u.FK_ID_ROL,
        u.ESTADO,
        u.INTENTOS_FALLIDOS,
        u.FECHA_BLOQUEO,
        u.CORREO_VERIFICADO,
        l.PK_ID_LOCAL AS ID_LOCAL,
        l.NOMBRE AS NOMBRE_LOCAL,
        CASE WHEN s.PK_ID_SUSCRIPCION IS NOT NULL AND s.ESTADO = 1 THEN 1 ELSE 0 END AS TIENE_MEMBRESIA_ACTIVA,
        tm.NOMBRE AS NOMBRE_MEMBRESIA
    FROM usuario u
    LEFT JOIN local l ON l.FK_ID_USUARIO = u.PK_ID_USUARIO
    LEFT JOIN suscripcion s ON s.FK_ID_LOCAL = l.PK_ID_LOCAL AND s.ESTADO = 1
    LEFT JOIN tipo_membresia tm ON s.FK_ID_TIPO_MEMBRESIA = tm.PK_ID_TIPO_MEMBRESIA
    WHERE u.NOMBRE_USUARIO = LOWER(TRIM(p_correo))
    LIMIT 1;
END//
DELIMITER ;

-- SP: Consultar usuario
DROP PROCEDURE IF EXISTS consultar_usuario;
DELIMITER //
CREATE PROCEDURE consultar_usuario(
    IN p_id_usuario INT
)
BEGIN
    IF p_id_usuario > 0 THEN
        SELECT
            PK_ID_USUARIO, NOMBRES, APELLIDOS, TELEFONO, NOMBRE_USUARIO AS CORREO,
            DOCUMENTO_IDENTIDAD, FK_ID_TIPO_DOCUMENTO, FK_ID_ROL, ESTADO,
            CODIGO_REFERIDO, CODIGO_REFERIDO_USADO, CORREO_VERIFICADO,
            CLIENTES_REFERIDOS_TOTAL
        FROM usuario
        WHERE PK_ID_USUARIO = p_id_usuario;
    ELSE
        SELECT
            PK_ID_USUARIO, NOMBRES, APELLIDOS, TELEFONO, NOMBRE_USUARIO AS CORREO,
            DOCUMENTO_IDENTIDAD, FK_ID_TIPO_DOCUMENTO, FK_ID_ROL, ESTADO,
            CODIGO_REFERIDO, CODIGO_REFERIDO_USADO, CORREO_VERIFICADO,
            CLIENTES_REFERIDOS_TOTAL
        FROM usuario;
    END IF;
END//
DELIMITER ;

-- SP: Consultar local por usuario
DROP PROCEDURE IF EXISTS consultar_local_por_usuario;
DELIMITER //
CREATE PROCEDURE consultar_local_por_usuario(
    IN p_id_usuario INT
)
BEGIN
    IF p_id_usuario = 0 THEN
        SELECT * FROM local;
    ELSE
        SELECT * FROM local WHERE FK_ID_USUARIO = p_id_usuario;
    END IF;
END//
DELIMITER ;

-- SP: Editar usuario
DROP PROCEDURE IF EXISTS editar_usuario;
DELIMITER //
CREATE PROCEDURE editar_usuario(
    IN p_id_usuario INT,
    IN p_nombres VARCHAR(40),
    IN p_apellidos VARCHAR(40),
    IN p_telefono VARCHAR(40)
)
BEGIN
    UPDATE usuario
    SET
        NOMBRES = COALESCE(p_nombres, NOMBRES),
        APELLIDOS = COALESCE(p_apellidos, APELLIDOS),
        TELEFONO = COALESCE(p_telefono, TELEFONO)
    WHERE PK_ID_USUARIO = p_id_usuario;

    SELECT ROW_COUNT() AS filas_afectadas;
END//
DELIMITER ;

-- SP: Eliminar usuario
DROP PROCEDURE IF EXISTS eliminar_usuario;
DELIMITER //
CREATE PROCEDURE eliminar_usuario(
    IN p_id_usuario INT,
    OUT p_mensaje VARCHAR(255)
)
BEGIN
    IF EXISTS (SELECT 1 FROM usuario WHERE PK_ID_USUARIO = p_id_usuario) THEN
        DELETE FROM usuario WHERE PK_ID_USUARIO = p_id_usuario;
        SET p_mensaje = 'Usuario eliminado exitosamente.';
    ELSE
        SET p_mensaje = 'Usuario no encontrado.';
    END IF;
END//
DELIMITER ;

-- =====================================================
-- VERIFICACIÓN
-- =====================================================

SELECT 'ESTRUCTURA USUARIO UNIFICADA:' as info;
DESCRIBE usuario;

SELECT 'TOTAL USUARIOS:' as info;
SELECT COUNT(*) as total FROM usuario;
