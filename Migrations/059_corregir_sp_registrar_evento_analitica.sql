-- =============================================
-- Migración 059: Corregir SP registrar_evento_analitica
-- Fecha: 2025-12-23
-- Descripción: Modifica el SP para validar que el producto exista antes de
--              insertarlo, evitando errores de foreign key constraint
-- =============================================

DROP PROCEDURE IF EXISTS `registrar_evento_analitica`;
DELIMITER //
CREATE PROCEDURE `registrar_evento_analitica`(
    IN p_id_local INT,
    IN p_id_producto INT,
    IN p_tipo_evento VARCHAR(50),
    IN p_ip_visitante VARCHAR(45),
    IN p_user_agent VARCHAR(500),
    IN p_referrer VARCHAR(500)
)
BEGIN
    DECLARE v_id_producto_validado INT DEFAULT NULL;

    -- Validar que el producto existe si se proporciona un ID
    IF p_id_producto IS NOT NULL THEN
        SELECT PK_ID_PRODUCTO INTO v_id_producto_validado
        FROM producto
        WHERE PK_ID_PRODUCTO = p_id_producto
        LIMIT 1;
    END IF;

    -- Insertar evento individual (con producto validado o NULL)
    INSERT INTO evento_analitica (FK_ID_LOCAL, FK_ID_PRODUCTO, TIPO_EVENTO, IP_VISITANTE, USER_AGENT, REFERRER)
    VALUES (p_id_local, v_id_producto_validado, p_tipo_evento, p_ip_visitante, p_user_agent, p_referrer);

    -- Actualizar resumen diario
    INSERT INTO resumen_analitica_diario (FK_ID_LOCAL, FECHA, VISITAS_LOCAL, VISITAS_PRODUCTOS, CLICS_WHATSAPP, CLICS_TELEFONO, APARICIONES_BUSQUEDA, COMPARTIDOS)
    VALUES (
        p_id_local,
        CURDATE(),
        IF(p_tipo_evento = 'VISITA_LOCAL', 1, 0),
        IF(p_tipo_evento = 'VISITA_PRODUCTO', 1, 0),
        IF(p_tipo_evento = 'CLIC_WHATSAPP', 1, 0),
        IF(p_tipo_evento = 'CLIC_TELEFONO', 1, 0),
        IF(p_tipo_evento = 'BUSQUEDA_APARICION', 1, 0),
        IF(p_tipo_evento = 'COMPARTIR', 1, 0)
    )
    ON DUPLICATE KEY UPDATE
        VISITAS_LOCAL = VISITAS_LOCAL + IF(p_tipo_evento = 'VISITA_LOCAL', 1, 0),
        VISITAS_PRODUCTOS = VISITAS_PRODUCTOS + IF(p_tipo_evento = 'VISITA_PRODUCTO', 1, 0),
        CLICS_WHATSAPP = CLICS_WHATSAPP + IF(p_tipo_evento = 'CLIC_WHATSAPP', 1, 0),
        CLICS_TELEFONO = CLICS_TELEFONO + IF(p_tipo_evento = 'CLIC_TELEFONO', 1, 0),
        APARICIONES_BUSQUEDA = APARICIONES_BUSQUEDA + IF(p_tipo_evento = 'BUSQUEDA_APARICION', 1, 0),
        COMPARTIDOS = COMPARTIDOS + IF(p_tipo_evento = 'COMPARTIR', 1, 0);

    -- Si es vista de producto y el producto existe, actualizar resumen de producto
    IF p_tipo_evento = 'VISITA_PRODUCTO' AND v_id_producto_validado IS NOT NULL THEN
        INSERT INTO resumen_producto_vistas (FK_ID_PRODUCTO, FK_ID_LOCAL, FECHA, VISTAS)
        VALUES (v_id_producto_validado, p_id_local, CURDATE(), 1)
        ON DUPLICATE KEY UPDATE VISTAS = VISTAS + 1;
    END IF;

    SELECT 1 AS resultado;
END//
DELIMITER ;

SELECT 'Migración 059 completada - SP registrar_evento_analitica corregido' AS resultado;
