-- =============================================
-- Migración 045: Actualizar tabla logs_sistema para LOGIN/LOGOUT
-- Fecha: 2025-12-21
-- Descripción: Modifica el ENUM de TIPO_ACCION para incluir LOGIN y LOGOUT
-- =============================================

-- Modificar la columna TIPO_ACCION para incluir LOGIN y LOGOUT
ALTER TABLE `logs_sistema`
MODIFY COLUMN `TIPO_ACCION` ENUM('CREATE','UPDATE','DELETE','LOGIN','LOGOUT') NOT NULL;

-- Actualizar el stored procedure para aceptar LOGIN/LOGOUT
DROP PROCEDURE IF EXISTS `insertar_log_sistema`;

DELIMITER //
CREATE PROCEDURE `insertar_log_sistema`(
    IN p_id_usuario INT,
    IN p_nombre_usuario VARCHAR(200),
    IN p_modulo VARCHAR(50),
    IN p_tipo_accion VARCHAR(10),
    IN p_entidad_id INT,
    IN p_entidad_descripcion VARCHAR(255),
    IN p_datos_anteriores JSON,
    IN p_datos_nuevos JSON,
    IN p_ip_cliente VARCHAR(45),
    IN p_user_agent VARCHAR(500),
    IN p_resultado VARCHAR(10),
    IN p_mensaje_error VARCHAR(500),
    IN p_controller VARCHAR(100),
    IN p_action VARCHAR(100)
)
BEGIN
    INSERT INTO logs_sistema (
        FK_ID_USUARIO,
        NOMBRE_USUARIO,
        MODULO,
        TIPO_ACCION,
        ENTIDAD_ID,
        ENTIDAD_DESCRIPCION,
        DATOS_ANTERIORES,
        DATOS_NUEVOS,
        IP_CLIENTE,
        USER_AGENT,
        RESULTADO,
        MENSAJE_ERROR,
        CONTROLLER,
        ACTION
    ) VALUES (
        p_id_usuario,
        p_nombre_usuario,
        p_modulo,
        p_tipo_accion,
        p_entidad_id,
        p_entidad_descripcion,
        p_datos_anteriores,
        p_datos_nuevos,
        p_ip_cliente,
        p_user_agent,
        p_resultado,
        p_mensaje_error,
        p_controller,
        p_action
    );

    SELECT LAST_INSERT_ID() AS id_log;
END//

DELIMITER ;
