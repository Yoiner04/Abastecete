-- =====================================================
-- Migración 020: Corregir UNIQUE KEY de producto_marca
-- Fecha: 2025-12-31
-- Problema: El UNIQUE KEY actual solo incluye (FK_ID_PRODUCTO, FK_ID_MARCA)
-- Solución: Debe incluir (FK_ID_LOCAL, FK_ID_PRODUCTO, FK_ID_MARCA, FK_ID_UNIDAD)
-- para permitir distintas presentaciones por local
-- =====================================================

-- El índice uk_producto_marca no tiene FK asociado, pero MySQL puede estar
-- confundiéndolo. Creamos primero el nuevo índice único y luego eliminamos el viejo.

-- 1. Crear el nuevo UNIQUE KEY que incluye local y unidad
ALTER TABLE producto_marca
ADD CONSTRAINT uk_producto_marca_local_unidad
UNIQUE (FK_ID_LOCAL, FK_ID_PRODUCTO, FK_ID_MARCA, FK_ID_UNIDAD);

-- 2. Ahora eliminar el UNIQUE KEY antiguo (ya no es necesario porque el nuevo lo cubre)
ALTER TABLE producto_marca DROP INDEX uk_producto_marca;

-- =====================================================
SELECT 'Migración 020 completada - UNIQUE KEY corregido' AS Mensaje;
-- =====================================================
