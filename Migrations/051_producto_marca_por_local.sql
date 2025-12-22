-- =============================================
-- Migración: 051_producto_marca_por_local.sql
-- Fecha: 2025-12-22
-- Descripción: Agregar FK_ID_LOCAL a producto_marca para que cada local
--              tenga sus propias marcas/precios por producto
-- =============================================

-- Agregar columna FK_ID_LOCAL
ALTER TABLE producto_marca ADD COLUMN FK_ID_LOCAL INT NULL AFTER FK_ID_MARCA;

-- Actualizar registros existentes: obtener el local desde productoslocal
UPDATE producto_marca pm
INNER JOIN productoslocal pl ON pm.FK_ID_PRODUCTO = pl.FK_ID_PRODUCTO
SET pm.FK_ID_LOCAL = pl.FK_ID_LOCAL
WHERE pm.FK_ID_LOCAL IS NULL;

-- Para registros huérfanos (sin productoslocal), asignar local 1 como default
UPDATE producto_marca SET FK_ID_LOCAL = 1 WHERE FK_ID_LOCAL IS NULL;

-- Hacer la columna NOT NULL después de migrar datos
ALTER TABLE producto_marca MODIFY COLUMN FK_ID_LOCAL INT NOT NULL;

-- Agregar FK constraint
ALTER TABLE producto_marca
ADD CONSTRAINT fk_pm_local FOREIGN KEY (FK_ID_LOCAL) REFERENCES local(PK_ID_LOCAL) ON DELETE CASCADE;

-- Eliminar el constraint único anterior
ALTER TABLE producto_marca DROP INDEX uk_producto_marca;

-- Nuevo constraint: un local no puede tener el mismo producto+marca más de una vez
ALTER TABLE producto_marca
ADD CONSTRAINT uk_local_producto_marca UNIQUE (FK_ID_LOCAL, FK_ID_PRODUCTO, FK_ID_MARCA);

-- Índice para mejorar búsquedas por local
CREATE INDEX idx_pm_local ON producto_marca(FK_ID_LOCAL);

SELECT 'Migración 051 completada - producto_marca ahora incluye FK_ID_LOCAL' AS resultado;
