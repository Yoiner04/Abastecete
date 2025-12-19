-- =============================================
-- Migracion: 014_mejoras_producto.sql
-- Fecha: 2025-12-18
-- Descripcion: Agregar campos marca, descripcion, SKU y Cloudinary a productos
-- =============================================

-- Agregar columna FK_ID_MARCA con valor por defecto 1 (Sin Marca)
ALTER TABLE producto ADD COLUMN FK_ID_MARCA INT DEFAULT 1;

-- Agregar constraint de FK a marca
ALTER TABLE producto ADD CONSTRAINT fk_producto_marca
    FOREIGN KEY (FK_ID_MARCA) REFERENCES marca(PK_ID_MARCA);

-- Agregar columna de descripcion
ALTER TABLE producto ADD COLUMN DESCRIPCION TEXT;

-- Agregar columna SKU (Stock Keeping Unit) - identificador unico del producto
ALTER TABLE producto ADD COLUMN SKU VARCHAR(50);

-- Agregar indice unico para SKU (permite NULL pero valores no-nulos deben ser unicos)
ALTER TABLE producto ADD UNIQUE INDEX idx_producto_sku (SKU);

-- Agregar columna para el Public ID de Cloudinary (para poder eliminar imagenes)
ALTER TABLE producto ADD COLUMN CLOUDINARY_PUBLIC_ID VARCHAR(255);

-- Indice para busquedas por marca
ALTER TABLE producto ADD INDEX idx_producto_marca (FK_ID_MARCA);

SELECT 'Migracion 014 completada - Campos marca, descripcion, SKU y Cloudinary agregados a producto' AS resultado;
