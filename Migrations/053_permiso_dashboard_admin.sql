-- Migration 053: Agregar permiso para Dashboard de Administrador
-- Este permiso permite ver las estadísticas globales del sistema

-- Agregar permiso para ver dashboard admin (si no existe)
INSERT INTO permiso (NOMBRE_PERMISO, ESTADO_PERMISO)
SELECT 'Ver Dashboard Admin', 1
WHERE NOT EXISTS (SELECT 1 FROM permiso WHERE NOMBRE_PERMISO = 'Ver Dashboard Admin');

-- Asignar permiso al rol Administrador (ID 1)
INSERT INTO permiso_de_rol (PFK_ID_ROL, PFK_ID_PERMISO, ESTADO_PERMISO_ROL)
SELECT 1, PK_ID_PERMISO, 1
FROM permiso
WHERE NOMBRE_PERMISO = 'Ver Dashboard Admin'
AND NOT EXISTS (
    SELECT 1 FROM permiso_de_rol pr
    INNER JOIN permiso p ON pr.PFK_ID_PERMISO = p.PK_ID_PERMISO
    WHERE p.NOMBRE_PERMISO = 'Ver Dashboard Admin' AND pr.PFK_ID_ROL = 1
);

SELECT 'Migración 053 completada - Permiso Ver Dashboard Admin creado y asignado' AS resultado;
