-- =============================================
-- Migracion: 016_permiso_administrar_productos.sql
-- Fecha: 2025-12-18
-- Descripcion: Crear permiso para administrar productos globalmente
-- =============================================

-- Crear permiso "Administrar Productos" (ID 12)
-- Este permiso permite al SuperAdmin gestionar productos de todos los negocios
INSERT INTO permiso (PK_ID_PERMISO, NOMBRE_PERMISO, ESTADO_PERMISO)
VALUES (12, 'Administrar Productos', 1)
ON DUPLICATE KEY UPDATE NOMBRE_PERMISO = 'Administrar Productos';

-- Asignar permiso al rol Admin (ID 1)
INSERT INTO permiso_de_rol (PFK_ID_ROL, PFK_ID_PERMISO, ESTADO_PERMISO_ROL)
VALUES (1, 12, 1)
ON DUPLICATE KEY UPDATE ESTADO_PERMISO_ROL = 1;

-- Asignar permiso al rol Director (ID 8)
INSERT INTO permiso_de_rol (PFK_ID_ROL, PFK_ID_PERMISO, ESTADO_PERMISO_ROL)
VALUES (8, 12, 1)
ON DUPLICATE KEY UPDATE ESTADO_PERMISO_ROL = 1;

SELECT 'Migracion 016 completada - Permiso Administrar Productos creado y asignado' AS resultado;
