-- =============================================
-- Migración 032: Agregar permiso ADMIN_REFERIDOS
-- Fecha: 2025-12-30
-- =============================================

-- Insertar permiso ADMIN_REFERIDOS si no existe (sin especificar ID, usa AUTO_INCREMENT)
INSERT INTO permiso (CODIGO, NOMBRE, DESCRIPCION, ICONO, CATEGORIA, ORDEN, ESTADO)
SELECT 'ADMIN_REFERIDOS', 'Configurar Referidos', 'Configurar descuentos y sistema de referidos', 'fa-user-group', 'ADMIN', 14, 1
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM permiso WHERE CODIGO = 'ADMIN_REFERIDOS');

-- Asignar el permiso al admin (usuario 1)
INSERT INTO usuario_permiso (FK_ID_USUARIO, FK_ID_PERMISO, FECHA_ASIGNACION, ORIGEN, ESTADO)
SELECT 1, (SELECT PK_ID_PERMISO FROM permiso WHERE CODIGO = 'ADMIN_REFERIDOS'), NOW(), 'ADMIN', 1
FROM DUAL
WHERE NOT EXISTS (
    SELECT 1 FROM usuario_permiso
    WHERE FK_ID_USUARIO = 1
    AND FK_ID_PERMISO = (SELECT PK_ID_PERMISO FROM permiso WHERE CODIGO = 'ADMIN_REFERIDOS')
);

SELECT 'Migracion 032 completada: Permiso ADMIN_REFERIDOS creado' AS resultado;
