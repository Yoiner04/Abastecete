-- =============================================
-- Migración: 048_tabla_producto_marca.sql
-- Fecha: 2025-12-22
-- Descripción: Crear tabla intermedia para relación muchos a muchos entre producto y marca
--              Permite que un producto tenga múltiples marcas con precios diferentes
-- =============================================

-- Crear tabla producto_marca (relación muchos a muchos)
CREATE TABLE IF NOT EXISTS producto_marca (
    PK_ID INT AUTO_INCREMENT PRIMARY KEY,
    FK_ID_PRODUCTO INT NOT NULL,
    FK_ID_MARCA INT NOT NULL,
    PRECIO DECIMAL(12,2) NOT NULL,
    STOCK INT DEFAULT 0,
    DISPONIBLE TINYINT DEFAULT 1,
    FECHA_REGISTRO DATETIME DEFAULT CURRENT_TIMESTAMP,
    FECHA_ACTUALIZACION DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    -- Foreign keys
    CONSTRAINT fk_pm_producto FOREIGN KEY (FK_ID_PRODUCTO) REFERENCES producto(PK_ID_PRODUCTO) ON DELETE CASCADE,
    CONSTRAINT fk_pm_marca FOREIGN KEY (FK_ID_MARCA) REFERENCES marca(PK_ID_MARCA) ON DELETE CASCADE,

    -- Un producto no puede tener la misma marca más de una vez
    CONSTRAINT uk_producto_marca UNIQUE (FK_ID_PRODUCTO, FK_ID_MARCA)
);

-- Índices para mejorar rendimiento (solo se crean si la tabla es nueva)
-- Los índices se crean automáticamente con la tabla si no existen

-- Migrar datos existentes: desde productoslocal que tiene el precio
-- Si ya existe, actualiza el precio
INSERT INTO producto_marca (FK_ID_PRODUCTO, FK_ID_MARCA, PRECIO, DISPONIBLE)
SELECT DISTINCT
    pl.FK_ID_PRODUCTO,
    COALESCE(p.FK_ID_MARCA, 1) as FK_ID_MARCA,
    pl.VALOR_PRODUCTS_LOCAL as PRECIO,
    1 as DISPONIBLE
FROM productoslocal pl
INNER JOIN producto p ON pl.FK_ID_PRODUCTO = p.PK_ID_PRODUCTO
ON DUPLICATE KEY UPDATE PRECIO = VALUES(PRECIO);

SELECT 'Migración 048 completada - Tabla producto_marca creada y datos migrados' AS resultado;
