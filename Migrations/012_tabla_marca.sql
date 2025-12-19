-- =============================================
-- Migración: 012_tabla_marca.sql
-- Fecha: 2025-12-18
-- Descripción: Crear tabla de marcas para productos
-- =============================================

-- Crear tabla marca
CREATE TABLE IF NOT EXISTS marca (
    PK_ID_MARCA INT AUTO_INCREMENT PRIMARY KEY,
    NOMBRE VARCHAR(100) NOT NULL,
    DESCRIPCION VARCHAR(255),
    LOGO_URL VARCHAR(500),
    CLOUDINARY_PUBLIC_ID VARCHAR(255),
    ACTIVO TINYINT DEFAULT 1,
    FECHA_REGISTRO DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_marca_nombre UNIQUE (NOMBRE)
);

-- Insertar marca por defecto
INSERT INTO marca (NOMBRE, DESCRIPCION, ACTIVO)
VALUES ('Sin Marca', 'Productos sin marca específica', 1)
ON DUPLICATE KEY UPDATE NOMBRE = NOMBRE;

SELECT 'Migración 012 completada - Tabla marca creada' AS resultado;
