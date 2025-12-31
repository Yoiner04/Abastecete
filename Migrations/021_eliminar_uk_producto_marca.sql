-- =====================================================
-- Migración 021: Eliminar el UNIQUE KEY viejo uk_producto_marca
-- Fecha: 2025-12-31
-- El índice está siendo usado por FK, hay que recrearlas
-- =====================================================

-- 1. Eliminar las FK que dependen del índice
ALTER TABLE producto_marca DROP FOREIGN KEY fk_pm_producto;
ALTER TABLE producto_marca DROP FOREIGN KEY fk_pm_marca;

-- 2. Ahora sí podemos eliminar el índice viejo
ALTER TABLE producto_marca DROP INDEX uk_producto_marca;

-- 3. Recrear las FK (usarán los índices existentes fk_pm_producto y fk_pm_marca)
ALTER TABLE producto_marca
ADD CONSTRAINT fk_pm_producto
FOREIGN KEY (FK_ID_PRODUCTO) REFERENCES producto(PK_ID_PRODUCTO) ON DELETE CASCADE;

ALTER TABLE producto_marca
ADD CONSTRAINT fk_pm_marca
FOREIGN KEY (FK_ID_MARCA) REFERENCES marca(PK_ID_MARCA) ON DELETE CASCADE;

-- =====================================================
SELECT 'Migración 021 completada - uk_producto_marca eliminado' AS Mensaje;
-- =====================================================
