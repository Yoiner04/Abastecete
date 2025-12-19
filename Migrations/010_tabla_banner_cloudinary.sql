-- =============================================
-- Migración: 010_tabla_banner_cloudinary.sql
-- Fecha: 2025-12-18
-- Descripción: Crea tabla banner para almacenar metadatos
--              de imágenes en Cloudinary (reemplaza MongoDB)
-- =============================================

-- Tabla principal de banners
CREATE TABLE IF NOT EXISTS banner (
    PK_ID_BANNER INT AUTO_INCREMENT PRIMARY KEY,
    CLOUDINARY_URL VARCHAR(500) NOT NULL,
    CLOUDINARY_PUBLIC_ID VARCHAR(255) NOT NULL,
    NOMBRE VARCHAR(100),
    TIPO VARCHAR(50) NOT NULL COMMENT 'proveedores, inicio, categoria, sesion, ofertas',
    FORMATO VARCHAR(10) DEFAULT '16:9' COMMENT '16:9 o 1:1',
    FK_ID_CATEGORIA INT NULL,
    ACTIVO TINYINT DEFAULT 1,
    FECHA_REGISTRO DATETIME DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_banner_tipo (TIPO),
    INDEX idx_banner_categoria (FK_ID_CATEGORIA),
    INDEX idx_banner_activo (ACTIVO),
    INDEX idx_banner_tipo_activo (TIPO, ACTIVO)
);

-- Agregar foreign key si la tabla categoria existe
-- (usamos procedimiento para evitar errores si ya existe)
DROP PROCEDURE IF EXISTS add_banner_fk;
DELIMITER //
CREATE PROCEDURE add_banner_fk()
BEGIN
    DECLARE CONTINUE HANDLER FOR 1005 BEGIN END; -- Error de FK
    DECLARE CONTINUE HANDLER FOR 1022 BEGIN END; -- Duplicate key
    DECLARE CONTINUE HANDLER FOR 1061 BEGIN END; -- Duplicate key name

    -- Intentar agregar la FK
    SET @sql = 'ALTER TABLE banner ADD CONSTRAINT fk_banner_categoria
                FOREIGN KEY (FK_ID_CATEGORIA) REFERENCES categoria(PK_ID_CATEGORIA)
                ON DELETE SET NULL';
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
END//
DELIMITER ;

CALL add_banner_fk();
DROP PROCEDURE IF EXISTS add_banner_fk;

SELECT 'Migración 010 completada - Tabla banner creada' AS resultado;
