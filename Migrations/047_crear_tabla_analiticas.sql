-- Migration 047: Crear sistema de analíticas para locales
-- Tabla para tracking de eventos y vistas agregadas por día

-- Tabla principal de eventos (registra cada evento individual)
CREATE TABLE IF NOT EXISTS `evento_analitica` (
    `PK_ID_EVENTO` BIGINT NOT NULL AUTO_INCREMENT,
    `FK_ID_LOCAL` INT NOT NULL,
    `FK_ID_PRODUCTO` INT NULL,
    `TIPO_EVENTO` ENUM('VISITA_LOCAL', 'VISITA_PRODUCTO', 'CLIC_WHATSAPP', 'BUSQUEDA_APARICION', 'CLIC_TELEFONO', 'COMPARTIR') NOT NULL,
    `IP_VISITANTE` VARCHAR(45) NULL,
    `USER_AGENT` VARCHAR(500) NULL,
    `REFERRER` VARCHAR(500) NULL,
    `FECHA_EVENTO` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`PK_ID_EVENTO`),
    INDEX `idx_evento_local` (`FK_ID_LOCAL`),
    INDEX `idx_evento_fecha` (`FECHA_EVENTO`),
    INDEX `idx_evento_tipo` (`TIPO_EVENTO`),
    INDEX `idx_evento_local_fecha` (`FK_ID_LOCAL`, `FECHA_EVENTO`),
    CONSTRAINT `fk_evento_local` FOREIGN KEY (`FK_ID_LOCAL`) REFERENCES `local` (`PK_ID_LOCAL`) ON DELETE CASCADE,
    CONSTRAINT `fk_evento_producto` FOREIGN KEY (`FK_ID_PRODUCTO`) REFERENCES `producto` (`PK_ID_PRODUCTO`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Tabla de resumen diario (para consultas rápidas de estadísticas)
CREATE TABLE IF NOT EXISTS `resumen_analitica_diario` (
    `PK_ID_RESUMEN` INT NOT NULL AUTO_INCREMENT,
    `FK_ID_LOCAL` INT NOT NULL,
    `FECHA` DATE NOT NULL,
    `VISITAS_LOCAL` INT NOT NULL DEFAULT 0,
    `VISITAS_PRODUCTOS` INT NOT NULL DEFAULT 0,
    `CLICS_WHATSAPP` INT NOT NULL DEFAULT 0,
    `CLICS_TELEFONO` INT NOT NULL DEFAULT 0,
    `APARICIONES_BUSQUEDA` INT NOT NULL DEFAULT 0,
    `COMPARTIDOS` INT NOT NULL DEFAULT 0,
    PRIMARY KEY (`PK_ID_RESUMEN`),
    UNIQUE KEY `uk_local_fecha` (`FK_ID_LOCAL`, `FECHA`),
    INDEX `idx_resumen_fecha` (`FECHA`),
    CONSTRAINT `fk_resumen_local` FOREIGN KEY (`FK_ID_LOCAL`) REFERENCES `local` (`PK_ID_LOCAL`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Tabla de productos más vistos (resumen)
CREATE TABLE IF NOT EXISTS `resumen_producto_vistas` (
    `PK_ID_RESUMEN` INT NOT NULL AUTO_INCREMENT,
    `FK_ID_PRODUCTO` INT NOT NULL,
    `FK_ID_LOCAL` INT NOT NULL,
    `FECHA` DATE NOT NULL,
    `VISTAS` INT NOT NULL DEFAULT 0,
    PRIMARY KEY (`PK_ID_RESUMEN`),
    UNIQUE KEY `uk_producto_fecha` (`FK_ID_PRODUCTO`, `FECHA`),
    INDEX `idx_producto_local` (`FK_ID_LOCAL`),
    CONSTRAINT `fk_resumen_producto` FOREIGN KEY (`FK_ID_PRODUCTO`) REFERENCES `producto` (`PK_ID_PRODUCTO`) ON DELETE CASCADE,
    CONSTRAINT `fk_resumen_producto_local` FOREIGN KEY (`FK_ID_LOCAL`) REFERENCES `local` (`PK_ID_LOCAL`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DELIMITER //

-- SP para registrar un evento
DROP PROCEDURE IF EXISTS `registrar_evento_analitica`//
CREATE PROCEDURE `registrar_evento_analitica`(
    IN p_id_local INT,
    IN p_id_producto INT,
    IN p_tipo_evento VARCHAR(50),
    IN p_ip_visitante VARCHAR(45),
    IN p_user_agent VARCHAR(500),
    IN p_referrer VARCHAR(500)
)
BEGIN
    -- Insertar evento individual
    INSERT INTO evento_analitica (FK_ID_LOCAL, FK_ID_PRODUCTO, TIPO_EVENTO, IP_VISITANTE, USER_AGENT, REFERRER)
    VALUES (p_id_local, p_id_producto, p_tipo_evento, p_ip_visitante, p_user_agent, p_referrer);

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

    -- Si es vista de producto, actualizar resumen de producto
    IF p_tipo_evento = 'VISITA_PRODUCTO' AND p_id_producto IS NOT NULL THEN
        INSERT INTO resumen_producto_vistas (FK_ID_PRODUCTO, FK_ID_LOCAL, FECHA, VISTAS)
        VALUES (p_id_producto, p_id_local, CURDATE(), 1)
        ON DUPLICATE KEY UPDATE VISTAS = VISTAS + 1;
    END IF;

    SELECT 1 AS resultado;
END//

-- SP para obtener estadísticas de un local por rango de fechas
DROP PROCEDURE IF EXISTS `obtener_estadisticas_local`//
CREATE PROCEDURE `obtener_estadisticas_local`(
    IN p_id_local INT,
    IN p_fecha_inicio DATE,
    IN p_fecha_fin DATE
)
BEGIN
    SELECT
        COALESCE(SUM(VISITAS_LOCAL), 0) AS total_visitas,
        COALESCE(SUM(VISITAS_PRODUCTOS), 0) AS total_visitas_productos,
        COALESCE(SUM(CLICS_WHATSAPP), 0) AS total_clics_whatsapp,
        COALESCE(SUM(CLICS_TELEFONO), 0) AS total_clics_telefono,
        COALESCE(SUM(APARICIONES_BUSQUEDA), 0) AS total_apariciones_busqueda,
        COALESCE(SUM(COMPARTIDOS), 0) AS total_compartidos
    FROM resumen_analitica_diario
    WHERE FK_ID_LOCAL = p_id_local
      AND FECHA BETWEEN p_fecha_inicio AND p_fecha_fin;
END//

-- SP para obtener estadísticas diarias (para gráficos)
DROP PROCEDURE IF EXISTS `obtener_estadisticas_diarias_local`//
CREATE PROCEDURE `obtener_estadisticas_diarias_local`(
    IN p_id_local INT,
    IN p_fecha_inicio DATE,
    IN p_fecha_fin DATE
)
BEGIN
    SELECT
        FECHA as fecha,
        VISITAS_LOCAL as visitas,
        VISITAS_PRODUCTOS as visitas_productos,
        CLICS_WHATSAPP as clics_whatsapp,
        CLICS_TELEFONO as clics_telefono,
        APARICIONES_BUSQUEDA as apariciones_busqueda,
        COMPARTIDOS as compartidos
    FROM resumen_analitica_diario
    WHERE FK_ID_LOCAL = p_id_local
      AND FECHA BETWEEN p_fecha_inicio AND p_fecha_fin
    ORDER BY FECHA ASC;
END//

-- SP para obtener productos más vistos de un local
DROP PROCEDURE IF EXISTS `obtener_productos_mas_vistos`//
CREATE PROCEDURE `obtener_productos_mas_vistos`(
    IN p_id_local INT,
    IN p_fecha_inicio DATE,
    IN p_fecha_fin DATE,
    IN p_limite INT
)
BEGIN
    SELECT
        p.PK_ID_PRODUCTO as id_producto,
        p.NOMBRE as nombre_producto,
        p.IMAGEN_URL as imagen_url,
        COALESCE(SUM(rpv.VISTAS), 0) as total_vistas
    FROM producto p
    LEFT JOIN resumen_producto_vistas rpv ON p.PK_ID_PRODUCTO = rpv.FK_ID_PRODUCTO
        AND rpv.FECHA BETWEEN p_fecha_inicio AND p_fecha_fin
    WHERE p.FK_ID_LOCAL = p_id_local
    GROUP BY p.PK_ID_PRODUCTO, p.NOMBRE, p.IMAGEN_URL
    ORDER BY total_vistas DESC
    LIMIT p_limite;
END//

-- SP para obtener comparativa con período anterior
DROP PROCEDURE IF EXISTS `obtener_comparativa_periodo`//
CREATE PROCEDURE `obtener_comparativa_periodo`(
    IN p_id_local INT,
    IN p_fecha_inicio DATE,
    IN p_fecha_fin DATE
)
BEGIN
    DECLARE v_dias INT;
    DECLARE v_fecha_inicio_anterior DATE;
    DECLARE v_fecha_fin_anterior DATE;

    -- Calcular días del período
    SET v_dias = DATEDIFF(p_fecha_fin, p_fecha_inicio) + 1;
    SET v_fecha_fin_anterior = DATE_SUB(p_fecha_inicio, INTERVAL 1 DAY);
    SET v_fecha_inicio_anterior = DATE_SUB(v_fecha_fin_anterior, INTERVAL v_dias - 1 DAY);

    -- Período actual
    SELECT
        'actual' as periodo,
        COALESCE(SUM(VISITAS_LOCAL), 0) AS visitas,
        COALESCE(SUM(CLICS_WHATSAPP), 0) AS clics_whatsapp,
        COALESCE(SUM(VISITAS_PRODUCTOS), 0) AS visitas_productos
    FROM resumen_analitica_diario
    WHERE FK_ID_LOCAL = p_id_local
      AND FECHA BETWEEN p_fecha_inicio AND p_fecha_fin

    UNION ALL

    -- Período anterior
    SELECT
        'anterior' as periodo,
        COALESCE(SUM(VISITAS_LOCAL), 0) AS visitas,
        COALESCE(SUM(CLICS_WHATSAPP), 0) AS clics_whatsapp,
        COALESCE(SUM(VISITAS_PRODUCTOS), 0) AS visitas_productos
    FROM resumen_analitica_diario
    WHERE FK_ID_LOCAL = p_id_local
      AND FECHA BETWEEN v_fecha_inicio_anterior AND v_fecha_fin_anterior;
END//

DELIMITER ;
