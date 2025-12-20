-- =============================================
-- Migración 032: Limpieza de código obsoleto
-- Fecha: 2025-12-20
-- Descripción: Elimina tablas, SPs y código que ya no se usa
-- =============================================

-- =============================================
-- PARTE 1: Eliminar Stored Procedures obsoletos
-- =============================================

-- SPs de favoritos (tablas nunca creadas)
DROP PROCEDURE IF EXISTS `agregar_local_favorito`;
DROP PROCEDURE IF EXISTS `eliminar_local_favorito`;
DROP PROCEDURE IF EXISTS `listar_favoritos_usuario`;

-- SPs de producto_usuario (tabla nunca creada)
DROP PROCEDURE IF EXISTS `asignar_producto_a_usuario`;

-- SP de detallemedida (tabla nunca creada)
DROP PROCEDURE IF EXISTS `crear_detallemedida`;

-- SPs de estado obsoletos
DROP PROCEDURE IF EXISTS `consultar_estado`;
DROP PROCEDURE IF EXISTS `crear_estado`;
DROP PROCEDURE IF EXISTS `consultar_estado_local`;
DROP PROCEDURE IF EXISTS `crear_estado_local`;
DROP PROCEDURE IF EXISTS `editar_estado_local`;
DROP PROCEDURE IF EXISTS `eliminar_estado_local`;

-- SPs de autenticación obsoletos
DROP PROCEDURE IF EXISTS `consultar_metodo_autenticacion`;
DROP PROCEDURE IF EXISTS `crear_metodo_autenticacion`;

-- SPs del sistema de membresía antiguo (reemplazado por suscripciones)
DROP PROCEDURE IF EXISTS `actualizar_membresia_usuario`;
DROP PROCEDURE IF EXISTS `asignar_membresia_usuario`;
DROP PROCEDURE IF EXISTS `consultar_membresia`;
DROP PROCEDURE IF EXISTS `crear_membresia_local`;

-- =============================================
-- PARTE 2: Eliminar tablas obsoletas
-- =============================================

-- Tabla de logs antigua (reemplazada por logs_sistema)
DROP TABLE IF EXISTS `logs_membresia`;

-- Tabla de membresía local deprecated (datos ya migrados a suscripcion)
DROP TABLE IF EXISTS `membresia_local_deprecated`;

-- =============================================
-- PARTE 3: Corregir SP crear_local
-- (eliminar llamada a crear_membresia_local que ya no existe)
-- =============================================

DROP PROCEDURE IF EXISTS `crear_local`;

DELIMITER //
CREATE PROCEDURE `crear_local`(
    IN `p_nombre_local` VARCHAR(100),
    IN `p_direccion` VARCHAR(255),
    IN `p_fk_id_persona` INT,
    IN `p_fk_id_barrio` INT,
    IN `p_fk_id_estado_local` INT,
    IN `p_latitud` DECIMAL(10,8),
    IN `p_longitud` DECIMAL(11,8),
    IN `p_telefono` VARCHAR(20),
    IN `p_descripcion` TEXT,
    IN `p_cloudinary_url` VARCHAR(500),
    IN `p_cloudinary_public_id` VARCHAR(255),
    OUT `mensaje` VARCHAR(255),
    OUT `resultado` INT
)
BEGIN
    DECLARE nuevo_local_id INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET mensaje = 'Error al crear el local';
        SET resultado = 0;
    END;

    START TRANSACTION;

    INSERT INTO local (
        NOMBRE_LOCAL,
        DIRECCION,
        FK_ID_PERSONA,
        FK_ID_BARRIO,
        FK_ID_ESTADO_LOCAL,
        LATITUD,
        LONGITUD,
        TELEFONO,
        DESCRIPCION,
        CLOUDINARY_URL,
        CLOUDINARY_PUBLIC_ID,
        FECHA_REGISTRO
    ) VALUES (
        p_nombre_local,
        p_direccion,
        p_fk_id_persona,
        p_fk_id_barrio,
        p_fk_id_estado_local,
        p_latitud,
        p_longitud,
        p_telefono,
        p_descripcion,
        p_cloudinary_url,
        p_cloudinary_public_id,
        NOW()
    );

    SET nuevo_local_id = LAST_INSERT_ID();

    -- Nota: Ya no se llama a crear_membresia_local
    -- Las suscripciones ahora se crean por separado vía ManejadorSuscripciones

    COMMIT;

    SET mensaje = 'Local creado exitosamente';
    SET resultado = nuevo_local_id;
END//
DELIMITER ;

-- =============================================
-- PARTE 4: Actualizar SP listar_locales_membresia
-- (usar tabla suscripcion en lugar de membresia_local)
-- =============================================

DROP PROCEDURE IF EXISTS `listar_locales_membresia`;

DELIMITER //
CREATE PROCEDURE `listar_locales_membresia`()
BEGIN
    SELECT
        l.PK_ID_LOCAL,
        l.NOMBRE_LOCAL,
        l.DIRECCION,
        l.TELEFONO,
        l.CLOUDINARY_URL,
        tm.NOMBRE AS TIPO_MEMBRESIA,
        s.FECHA_INICIO,
        s.FECHA_FIN,
        s.ESTADO AS ESTADO_SUSCRIPCION,
        DATEDIFF(s.FECHA_FIN, NOW()) AS DIAS_RESTANTES
    FROM local l
    INNER JOIN suscripcion s ON s.PK_ID_SUSCRIPCION = l.FK_ID_SUSCRIPCION_ACTIVA
    INNER JOIN tipo_membresia tm ON tm.PK_ID_TIPO_MEMBRESIA = s.FK_ID_TIPO_MEMBRESIA
    WHERE s.ESTADO = 1
    AND NOW() BETWEEN s.FECHA_INICIO AND s.FECHA_FIN
    ORDER BY l.NOMBRE_LOCAL;
END//
DELIMITER ;

-- =============================================
-- PARTE 5: Eliminar evento obsoleto
-- =============================================

-- El evento usa tabla membresia que ya no es el sistema principal
DROP EVENT IF EXISTS `actualizar_estado_membresia`;

-- Crear nuevo evento para actualizar suscripciones vencidas
DROP EVENT IF EXISTS `actualizar_estado_suscripcion`;

DELIMITER //
CREATE EVENT `actualizar_estado_suscripcion`
ON SCHEDULE EVERY 1 HOUR
STARTS CURRENT_TIMESTAMP
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    -- Cambiar el estado a 0 (inactivo) si la FECHA_FIN es menor que la fecha actual
    UPDATE suscripcion
    SET ESTADO = 0
    WHERE FECHA_FIN < NOW() AND ESTADO = 1;

    -- Log para seguimiento
    INSERT INTO logs_sistema (MODULO, ACCION, DESCRIPCION, FECHA_REGISTRO)
    VALUES ('SUSCRIPCIONES', 'AUTO_UPDATE',
            CONCAT('Suscripciones vencidas actualizadas a inactivas: ', ROW_COUNT()),
            NOW());
END//
DELIMITER ;

-- =============================================
-- Verificación final
-- =============================================
SELECT 'Migración 032 completada: Código obsoleto eliminado' AS resultado;
