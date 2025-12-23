-- =============================================
-- Migración 056: Corregir SP sp_listar_todas_marcas y agregar marcas disponibles por producto
-- Fecha: 2025-12-22
-- Descripción:
--   1. Corrige el nombre de columna ACTIVA → ACTIVO en SP
--   2. Crea tabla producto_marcas_disponibles para múltiples marcas por producto a nivel global
-- =============================================

-- =============================================
-- PASO 1: Corregir SP sp_listar_todas_marcas
-- =============================================
DROP PROCEDURE IF EXISTS `sp_listar_todas_marcas`;
DELIMITER //
CREATE PROCEDURE `sp_listar_todas_marcas`()
BEGIN
    SELECT
        PK_ID_MARCA as Id,
        NOMBRE as Nombre,
        DESCRIPCION as Descripcion,
        LOGO_URL as LogoUrl,
        CLOUDINARY_PUBLIC_ID as CloudinaryPublicId,
        ACTIVO as Activo
    FROM marca
    WHERE ACTIVO = 1
    ORDER BY NOMBRE;
END //
DELIMITER ;

-- =============================================
-- PASO 2: Crear tabla para marcas disponibles por producto (nivel global)
-- =============================================
CREATE TABLE IF NOT EXISTS `producto_marcas_disponibles` (
    `PK_ID` INT NOT NULL AUTO_INCREMENT,
    `FK_ID_PRODUCTO` INT NOT NULL,
    `FK_ID_MARCA` INT NOT NULL,
    `FECHA_REGISTRO` DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`PK_ID`),
    UNIQUE KEY `uk_producto_marca_disponible` (`FK_ID_PRODUCTO`, `FK_ID_MARCA`),
    KEY `idx_pmd_producto` (`FK_ID_PRODUCTO`),
    KEY `idx_pmd_marca` (`FK_ID_MARCA`),
    CONSTRAINT `fk_pmd_producto` FOREIGN KEY (`FK_ID_PRODUCTO`) REFERENCES `producto` (`PK_ID_PRODUCTO`) ON DELETE CASCADE,
    CONSTRAINT `fk_pmd_marca` FOREIGN KEY (`FK_ID_MARCA`) REFERENCES `marca` (`PK_ID_MARCA`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- =============================================
-- PASO 3: Migrar datos existentes (FK_ID_MARCA de producto a la nueva tabla)
-- =============================================
INSERT IGNORE INTO `producto_marcas_disponibles` (`FK_ID_PRODUCTO`, `FK_ID_MARCA`)
SELECT `PK_ID_PRODUCTO`, `FK_ID_MARCA`
FROM `producto`
WHERE `FK_ID_MARCA` IS NOT NULL AND `FK_ID_MARCA` > 0;

-- =============================================
-- PASO 4: SP para listar marcas disponibles de un producto
-- =============================================
DROP PROCEDURE IF EXISTS `sp_listar_marcas_disponibles_producto`;
DELIMITER //
CREATE PROCEDURE `sp_listar_marcas_disponibles_producto`(
    IN p_id_producto INT
)
BEGIN
    SELECT
        m.PK_ID_MARCA as Id,
        m.NOMBRE as Nombre,
        m.LOGO_URL as LogoUrl
    FROM producto_marcas_disponibles pmd
    INNER JOIN marca m ON pmd.FK_ID_MARCA = m.PK_ID_MARCA
    WHERE pmd.FK_ID_PRODUCTO = p_id_producto
    AND m.ACTIVO = 1
    ORDER BY m.NOMBRE;
END //
DELIMITER ;

-- =============================================
-- PASO 5: SP para guardar marcas disponibles de un producto
-- =============================================
DROP PROCEDURE IF EXISTS `sp_guardar_marcas_disponibles_producto`;
DELIMITER //
CREATE PROCEDURE `sp_guardar_marcas_disponibles_producto`(
    IN p_id_producto INT,
    IN p_marcas_ids VARCHAR(500) -- Lista separada por comas: "1,2,3,5"
)
BEGIN
    -- Eliminar marcas anteriores
    DELETE FROM producto_marcas_disponibles WHERE FK_ID_PRODUCTO = p_id_producto;

    -- Insertar nuevas marcas
    IF p_marcas_ids IS NOT NULL AND p_marcas_ids != '' THEN
        SET @sql = CONCAT(
            'INSERT INTO producto_marcas_disponibles (FK_ID_PRODUCTO, FK_ID_MARCA) ',
            'SELECT ', p_id_producto, ', PK_ID_MARCA FROM marca WHERE PK_ID_MARCA IN (', p_marcas_ids, ') AND ACTIVO = 1'
        );
        PREPARE stmt FROM @sql;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END IF;

    SELECT ROW_COUNT() as cantidad;
END //
DELIMITER ;
