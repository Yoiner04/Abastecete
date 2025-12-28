-- Migración 064: Reset del Sistema - Nuevas Membresías
-- ============================================================
-- ADVERTENCIA: Este script ELIMINA datos de producción.
-- Solo ejecutar en desarrollo o después de un backup completo.
-- REQUIERE: Ejecutar primero 063_unificar_persona_usuario.sql
-- ============================================================

SET FOREIGN_KEY_CHECKS = 0;

-- =====================================================
-- PASO 1: Limpiar datos dependientes
-- =====================================================

TRUNCATE TABLE addon_local;
TRUNCATE TABLE usuario_permiso;
TRUNCATE TABLE tipo_membresia_permiso;

DELETE FROM oferta_flash WHERE 1=1;
DELETE FROM producto WHERE 1=1;
DELETE FROM suscripcion WHERE 1=1;
DELETE FROM local WHERE 1=1;
TRUNCATE TABLE usuario;
DELETE FROM tipo_membresia WHERE 1=1;

-- =====================================================
-- PASO 2: Crear usuario admin
-- =====================================================

INSERT INTO usuario (
    NOMBRES, APELLIDOS, TELEFONO, DOCUMENTO_IDENTIDAD, FK_ID_TIPO_DOCUMENTO,
    CODIGO_REFERIDO, NOMBRE_USUARIO, CONTRASENIA, FK_ID_ROL, ESTADO
) VALUES (
    'Administrador', 'Sistema', '0000000000', NULL, 1,
    'ADMIN001', 'admin@abastecete.com',
    '$2a$11$rQbHvCLuNGHN.gTVYPqEHOKE8XQmC1Y0nIZw1LWQR7Lk3GQKkPvKO', -- admin123
    1, 1
);

SET FOREIGN_KEY_CHECKS = 1;

-- =====================================================
-- PASO 3: Crear las 3 nuevas membresías
-- =====================================================

INSERT INTO tipo_membresia (
    PK_ID_TIPO_MEMBRESIA,
    NOMBRE,
    COSTO,
    CANTIDAD_PRODUCTOS,
    OFERTAS_FLASH_SIMULTANEAS,
    OFERTAS_FLASH_TOTAL,
    DURACION_OFERTA,
    ESTADO
) VALUES
(1, 'Plan Básico', 0, 10, 1, 5, 6, 1),
(2, 'Plan Pro', 50000, 50, 3, 20, 12, 1),
(3, 'Plan Premium', 120000, 0, 5, 0, 24, 1);
-- NOTA: CANTIDAD_PRODUCTOS=0 = ilimitado, OFERTAS_FLASH_TOTAL=0 = ilimitado

-- =====================================================
-- PASO 4: Asignar permisos a cada membresía
-- =====================================================

-- PLAN BÁSICO (ID=1)
INSERT INTO tipo_membresia_permiso (FK_ID_TIPO_MEMBRESIA, FK_ID_PERMISO)
SELECT 1, PK_ID_PERMISO FROM permiso_sistema WHERE CODIGO IN (
    'PRODUCTOS_BASICO',
    'IMAGENES_PRODUCTO',
    'OFERTAS_FLASH',
    'ANALITICAS_BASICAS',
    'WHATSAPP_VISIBLE',
    'EMAIL_CONTACTO',
    'HORARIOS_ATENCION',
    'UBICACION_MAPA'
);

-- PLAN PRO (ID=2)
INSERT INTO tipo_membresia_permiso (FK_ID_TIPO_MEMBRESIA, FK_ID_PERMISO)
SELECT 2, PK_ID_PERMISO FROM permiso_sistema WHERE CODIGO IN (
    'PRODUCTOS_BASICO',
    'IMAGENES_PRODUCTO',
    'MULTIPLES_MARCAS',
    'OFERTAS_FLASH',
    'GALERIA_NEGOCIO',
    'BANNER_PERSONALIZADO',
    'ANALITICAS_BASICAS',
    'ANALITICAS_AVANZADAS',
    'ANALITICAS_PRODUCTOS',
    'META_PIXEL',
    'GOOGLE_TAG',
    'WHATSAPP_VISIBLE',
    'EMAIL_CONTACTO',
    'REDES_SOCIALES',
    'SITIO_WEB',
    'HORARIOS_ATENCION',
    'UBICACION_MAPA',
    'DESCRIPCION_EXTENDIDA'
);

-- PLAN PREMIUM (ID=3): TODOS los permisos de negocio
INSERT INTO tipo_membresia_permiso (FK_ID_TIPO_MEMBRESIA, FK_ID_PERMISO)
SELECT 3, PK_ID_PERMISO FROM permiso_sistema
WHERE CATEGORIA != 'ADMIN';

-- =====================================================
-- PASO 5: Asignar permisos ADMIN al usuario admin
-- =====================================================

INSERT INTO usuario_permiso (FK_ID_USUARIO, FK_ID_PERMISO, ORIGEN, ESTADO)
SELECT 1, PK_ID_PERMISO, 'ADMIN', 1
FROM permiso_sistema
WHERE CATEGORIA = 'ADMIN'
ON DUPLICATE KEY UPDATE ESTADO = 1, ORIGEN = 'ADMIN';

-- =====================================================
-- PASO 6: Reset auto-increment
-- =====================================================

ALTER TABLE local AUTO_INCREMENT = 1;
ALTER TABLE producto AUTO_INCREMENT = 1;
ALTER TABLE suscripcion AUTO_INCREMENT = 1;
ALTER TABLE oferta_flash AUTO_INCREMENT = 1;
ALTER TABLE addon_local AUTO_INCREMENT = 1;

-- =====================================================
-- VERIFICACIÓN
-- =====================================================

SELECT 'USUARIO ADMIN:' as info;
SELECT PK_ID_USUARIO, NOMBRES, APELLIDOS, NOMBRE_USUARIO, FK_ID_ROL FROM usuario;

SELECT 'MEMBRESÍAS CREADAS:' as info;
SELECT PK_ID_TIPO_MEMBRESIA as ID, NOMBRE, COSTO, CANTIDAD_PRODUCTOS as Productos,
       OFERTAS_FLASH_SIMULTANEAS as OfertasSimult, DURACION_OFERTA as DuracionHoras
FROM tipo_membresia;

SELECT 'PERMISOS POR MEMBRESÍA:' as info;
SELECT tm.NOMBRE as Membresia, COUNT(tmp.FK_ID_PERMISO) as TotalPermisos
FROM tipo_membresia tm
LEFT JOIN tipo_membresia_permiso tmp ON tm.PK_ID_TIPO_MEMBRESIA = tmp.FK_ID_TIPO_MEMBRESIA
GROUP BY tm.PK_ID_TIPO_MEMBRESIA;

SELECT 'PERMISOS DEL ADMIN:' as info;
SELECT ps.CODIGO, ps.NOMBRE
FROM usuario_permiso up
INNER JOIN permiso_sistema ps ON up.FK_ID_PERMISO = ps.PK_ID_PERMISO
WHERE up.FK_ID_USUARIO = 1;
