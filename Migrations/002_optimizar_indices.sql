-- ============================================================
-- Migración 002: Optimizar índices y SPs para mejorar rendimiento
-- ============================================================

-- =====================================================
-- PARTE 1: SP para cargar todos los banners de categorías en UNA consulta
-- =====================================================
DROP PROCEDURE IF EXISTS consultar_todos_banners_categorias;
DELIMITER //
CREATE PROCEDURE consultar_todos_banners_categorias()
BEGIN
    SELECT
        b.PK_ID_BANNER,
        b.CLOUDINARY_URL,
        b.CLOUDINARY_PUBLIC_ID,
        b.NOMBRE,
        b.TIPO,
        b.FORMATO,
        b.FK_ID_CATEGORIA,
        b.ACTIVO,
        b.FECHA_REGISTRO
    FROM banner b
    WHERE b.TIPO = 'categoria'
      AND b.ACTIVO = 1
      AND b.FK_ID_CATEGORIA IS NOT NULL
    ORDER BY b.FK_ID_CATEGORIA, b.FECHA_REGISTRO DESC;
END//
DELIMITER ;

SELECT 'MIGRACIÓN 002 - Optimizaciones aplicadas' as info;
