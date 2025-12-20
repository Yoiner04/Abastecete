-- Migración 030: Sistema de Logs/Auditoría
-- Descripción: Tabla única para registrar todas las acciones CRUD del sistema

-- Crear tabla de logs del sistema
CREATE TABLE IF NOT EXISTS `logs_sistema` (
    `PK_ID_LOG` INT NOT NULL AUTO_INCREMENT,
    `FK_ID_USUARIO` INT NULL,
    `NOMBRE_USUARIO` VARCHAR(200) NULL,
    `MODULO` VARCHAR(50) NOT NULL,
    `TIPO_ACCION` ENUM('CREATE', 'UPDATE', 'DELETE') NOT NULL,
    `ENTIDAD_ID` INT NULL,
    `ENTIDAD_DESCRIPCION` VARCHAR(255) NULL,
    `DATOS_ANTERIORES` JSON NULL,
    `DATOS_NUEVOS` JSON NULL,
    `IP_CLIENTE` VARCHAR(45) NULL,
    `USER_AGENT` VARCHAR(500) NULL,
    `FECHA_REGISTRO` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `RESULTADO` ENUM('EXITO', 'ERROR') NOT NULL DEFAULT 'EXITO',
    `MENSAJE_ERROR` VARCHAR(500) NULL,
    `CONTROLLER` VARCHAR(100) NULL,
    `ACTION` VARCHAR(100) NULL,
    PRIMARY KEY (`PK_ID_LOG`),
    INDEX `IDX_logs_fecha` (`FECHA_REGISTRO` DESC),
    INDEX `IDX_logs_usuario` (`FK_ID_USUARIO`),
    INDEX `IDX_logs_modulo` (`MODULO`),
    INDEX `IDX_logs_tipo_accion` (`TIPO_ACCION`),
    INDEX `IDX_logs_entidad` (`MODULO`, `ENTIDAD_ID`),
    CONSTRAINT `FK_logs_usuario` FOREIGN KEY (`FK_ID_USUARIO`)
        REFERENCES `usuario` (`PK_ID_USUARIO`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- =============================================
-- SP: Insertar log en el sistema
-- =============================================
DELIMITER //

DROP PROCEDURE IF EXISTS `insertar_log_sistema`//

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

-- =============================================
-- SP: Consultar logs con paginación y filtros
-- =============================================
DELIMITER //

DROP PROCEDURE IF EXISTS `consultar_logs_sistema`//

CREATE PROCEDURE `consultar_logs_sistema`(
    IN p_fecha_desde DATETIME,
    IN p_fecha_hasta DATETIME,
    IN p_modulo VARCHAR(50),
    IN p_tipo_accion VARCHAR(10),
    IN p_id_usuario INT,
    IN p_termino_busqueda VARCHAR(100),
    IN p_pagina INT,
    IN p_registros_por_pagina INT
)
BEGIN
    DECLARE v_offset INT;
    SET v_offset = (p_pagina - 1) * p_registros_por_pagina;

    SELECT
        l.PK_ID_LOG AS Id,
        l.FK_ID_USUARIO AS UsuarioId,
        l.NOMBRE_USUARIO AS NombreUsuario,
        l.MODULO AS Modulo,
        l.TIPO_ACCION AS TipoAccion,
        l.ENTIDAD_ID AS EntidadId,
        l.ENTIDAD_DESCRIPCION AS EntidadDescripcion,
        l.DATOS_ANTERIORES AS DatosAnteriores,
        l.DATOS_NUEVOS AS DatosNuevos,
        l.IP_CLIENTE AS IpCliente,
        l.USER_AGENT AS UserAgent,
        l.FECHA_REGISTRO AS FechaRegistro,
        l.RESULTADO AS Resultado,
        l.MENSAJE_ERROR AS MensajeError,
        l.CONTROLLER AS Controller,
        l.ACTION AS Action
    FROM logs_sistema l
    WHERE
        (p_fecha_desde IS NULL OR l.FECHA_REGISTRO >= p_fecha_desde)
        AND (p_fecha_hasta IS NULL OR l.FECHA_REGISTRO <= p_fecha_hasta)
        AND (p_modulo IS NULL OR p_modulo = '' OR l.MODULO = p_modulo)
        AND (p_tipo_accion IS NULL OR p_tipo_accion = '' OR l.TIPO_ACCION = p_tipo_accion)
        AND (p_id_usuario IS NULL OR p_id_usuario = 0 OR l.FK_ID_USUARIO = p_id_usuario)
        AND (p_termino_busqueda IS NULL OR p_termino_busqueda = ''
             OR l.NOMBRE_USUARIO LIKE CONCAT('%', p_termino_busqueda, '%')
             OR l.ENTIDAD_DESCRIPCION LIKE CONCAT('%', p_termino_busqueda, '%'))
    ORDER BY l.FECHA_REGISTRO DESC
    LIMIT p_registros_por_pagina OFFSET v_offset;
END//

DELIMITER ;

-- =============================================
-- SP: Contar logs para paginación
-- =============================================
DELIMITER //

DROP PROCEDURE IF EXISTS `contar_logs_sistema`//

CREATE PROCEDURE `contar_logs_sistema`(
    IN p_fecha_desde DATETIME,
    IN p_fecha_hasta DATETIME,
    IN p_modulo VARCHAR(50),
    IN p_tipo_accion VARCHAR(10),
    IN p_id_usuario INT,
    IN p_termino_busqueda VARCHAR(100)
)
BEGIN
    SELECT COUNT(*) AS TotalRegistros
    FROM logs_sistema l
    WHERE
        (p_fecha_desde IS NULL OR l.FECHA_REGISTRO >= p_fecha_desde)
        AND (p_fecha_hasta IS NULL OR l.FECHA_REGISTRO <= p_fecha_hasta)
        AND (p_modulo IS NULL OR p_modulo = '' OR l.MODULO = p_modulo)
        AND (p_tipo_accion IS NULL OR p_tipo_accion = '' OR l.TIPO_ACCION = p_tipo_accion)
        AND (p_id_usuario IS NULL OR p_id_usuario = 0 OR l.FK_ID_USUARIO = p_id_usuario)
        AND (p_termino_busqueda IS NULL OR p_termino_busqueda = ''
             OR l.NOMBRE_USUARIO LIKE CONCAT('%', p_termino_busqueda, '%')
             OR l.ENTIDAD_DESCRIPCION LIKE CONCAT('%', p_termino_busqueda, '%'));
END//

DELIMITER ;

-- Agregar permiso para ver logs (si no existe)
INSERT INTO permiso (NOMBRE_PERMISO, ESTADO_PERMISO)
SELECT 'Ver Logs Sistema', 1
WHERE NOT EXISTS (SELECT 1 FROM permiso WHERE NOMBRE_PERMISO = 'Ver Logs Sistema');

-- Asignar permiso al rol Administrador (ID 1)
INSERT INTO permiso_de_rol (PFK_ID_ROL, PFK_ID_PERMISO, ESTADO_PERMISO_ROL)
SELECT 1, PK_ID_PERMISO, 1
FROM permiso
WHERE NOMBRE_PERMISO = 'Ver Logs Sistema'
AND NOT EXISTS (
    SELECT 1 FROM permiso_de_rol pr
    INNER JOIN permiso p ON pr.PFK_ID_PERMISO = p.PK_ID_PERMISO
    WHERE p.NOMBRE_PERMISO = 'Ver Logs Sistema' AND pr.PFK_ID_ROL = 1
);
