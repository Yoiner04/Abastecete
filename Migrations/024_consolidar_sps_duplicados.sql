-- =====================================================
-- Migración 024: Consolidar SPs duplicados y agregar índices
-- Fecha: 2025-01-01
-- =====================================================

-- =====================================================
-- 1. ELIMINAR SPs DUPLICADOS DE BÚSQUEDA
-- =====================================================

-- Eliminar buscar_productos (duplicado de buscador_productos)
DROP PROCEDURE IF EXISTS buscar_productos;

-- Eliminar buscar_sugerencias_productos (duplicado de buscador_productos_sugerencias)
DROP PROCEDURE IF EXISTS buscar_sugerencias_productos;

-- =====================================================
-- 2. ELIMINAR SPs DUPLICADOS DE PERMISOS
-- (Mantener solo los "obtener_*" que son más completos)
-- =====================================================

-- Eliminar consultar_permisos_membresia (duplicado de obtener_permisos_membresia)
DROP PROCEDURE IF EXISTS consultar_permisos_membresia;

-- Eliminar consultar_permisos_sistema (duplicado de obtener_permisos_sistema)
DROP PROCEDURE IF EXISTS consultar_permisos_sistema;

-- Eliminar consultar_permisos_usuario (duplicado de obtener_permisos_usuario)
DROP PROCEDURE IF EXISTS consultar_permisos_usuario;

-- =====================================================
-- 3. AGREGAR ÍNDICES A TABLAS ANALÍTICAS
-- =====================================================

-- Índices para resumen_analitica_diario
CREATE INDEX idx_rad_fecha ON resumen_analitica_diario (FECHA);
CREATE INDEX idx_rad_local_fecha ON resumen_analitica_diario (FK_ID_LOCAL, FECHA);

-- Índices para resumen_producto_vistas
CREATE INDEX idx_rpv_fecha ON resumen_producto_vistas (FECHA);
CREATE INDEX idx_rpv_local_fecha ON resumen_producto_vistas (FK_ID_LOCAL, FECHA);
CREATE INDEX idx_rpv_producto ON resumen_producto_vistas (FK_ID_PRODUCTO);

-- Índices para evento_analitica
CREATE INDEX idx_ea_fecha ON evento_analitica (FECHA_EVENTO);
CREATE INDEX idx_ea_local_fecha ON evento_analitica (FK_ID_LOCAL, FECHA_EVENTO);
CREATE INDEX idx_ea_tipo ON evento_analitica (TIPO_EVENTO);

-- =====================================================
SELECT 'Migración 024 completada - SPs duplicados eliminados e índices agregados' AS Mensaje;
