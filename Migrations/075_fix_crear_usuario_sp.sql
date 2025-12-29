-- Migración 075: Corregir SP crear_usuario
-- ============================================================
-- El SP debe retornar SELECT con resultado/mensaje en lugar de
-- usar parámetros OUT, para compatibilidad con EjecutarTransaccionConMensaje
-- NOTA: La tabla usuario NO tiene FK_ID_ROL, usa usuario_permiso
-- ============================================================

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
    IN p_codigo_referido_usado VARCHAR(50)
)
BEGIN
    DECLARE v_codigo_referido VARCHAR(20);
    DECLARE v_codigo_existe INT DEFAULT 1;
    DECLARE v_id_dueno INT DEFAULT 0;
    DECLARE v_id_usuario INT DEFAULT 0;
    DECLARE v_mensaje VARCHAR(255) DEFAULT '';

    -- Validaciones
    IF EXISTS (SELECT 1 FROM usuario WHERE NOMBRE_USUARIO = LOWER(TRIM(p_correo))) THEN
        SET v_mensaje = 'El correo electrónico ya está registrado.';
        SELECT 0 AS resultado, v_mensaje AS mensaje;
    ELSEIF p_documento IS NOT NULL AND p_documento > 0 AND EXISTS (SELECT 1 FROM usuario WHERE DOCUMENTO_IDENTIDAD = p_documento AND FK_ID_TIPO_DOCUMENTO = p_fk_tipo_documento) THEN
        SET v_mensaje = 'El documento de identidad ya está registrado.';
        SELECT 0 AS resultado, v_mensaje AS mensaje;
    ELSE
        -- Generar código de referido único
        WHILE v_codigo_existe > 0 DO
            SET v_codigo_referido = CONCAT('COD', LPAD(FLOOR(RAND() * 1000000), 6, '0'));
            SELECT COUNT(*) INTO v_codigo_existe FROM usuario WHERE CODIGO_REFERIDO = v_codigo_referido;
        END WHILE;

        -- Insertar usuario (sin FK_ID_ROL - el sistema usa usuario_permiso)
        INSERT INTO usuario (
            NOMBRES, APELLIDOS, TELEFONO, DOCUMENTO_IDENTIDAD, FK_ID_TIPO_DOCUMENTO,
            CODIGO_REFERIDO, CODIGO_REFERIDO_USADO, NOMBRE_USUARIO, CONTRASENIA, ESTADO,
            CREDITO_REFERIDOS, YA_USO_DESCUENTO_REFERIDO
        ) VALUES (
            p_nombres, p_apellidos, p_telefono,
            CASE WHEN p_documento > 0 THEN p_documento ELSE NULL END,
            COALESCE(p_fk_tipo_documento, 1),
            v_codigo_referido,
            CASE WHEN p_codigo_referido_usado IS NOT NULL AND p_codigo_referido_usado != '' THEN p_codigo_referido_usado ELSE NULL END,
            LOWER(TRIM(p_correo)), p_contrasenia, 1, 0, 0
        );

        SET v_id_usuario = LAST_INSERT_ID();

        -- Registrar referencia si hay código usado
        IF p_codigo_referido_usado IS NOT NULL AND p_codigo_referido_usado != '' THEN
            SELECT PK_ID_USUARIO INTO v_id_dueno
            FROM usuario WHERE CODIGO_REFERIDO = p_codigo_referido_usado AND ESTADO = 1
            LIMIT 1;

            IF v_id_dueno > 0 THEN
                INSERT INTO referencias (FK_ID_DUENO_CODIGO, FK_ID_CLIENTE_REFERIDO, MEMBRESIA_COMPRADA)
                VALUES (v_id_dueno, v_id_usuario, 0);

                -- Incrementar contador de referidos del dueño
                UPDATE usuario
                SET CLIENTES_REFERIDOS_TOTAL = COALESCE(CLIENTES_REFERIDOS_TOTAL, 0) + 1
                WHERE PK_ID_USUARIO = v_id_dueno;
            END IF;
        END IF;

        SET v_mensaje = 'Usuario creado exitosamente.';
        SELECT v_id_usuario AS resultado, v_mensaje AS mensaje;
    END IF;
END//
DELIMITER ;

SELECT 'MIGRACIÓN 075 - SP crear_usuario CORREGIDO' as info;
