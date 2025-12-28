-- Migración 062: Sistema Unificado de Permisos por Membresía
-- ============================================================
-- Este script crea el nuevo sistema de permisos donde:
-- 1. permiso_sistema: Catálogo único de permisos (admin + negocio)
-- 2. tipo_membresia_permiso: Plantilla de permisos por membresía
-- 3. usuario_permiso: Permisos efectivos de cada usuario
-- 4. addon_tipo: Catálogo de addons disponibles
-- 5. addon_local: Addons comprados por local
--
-- NOTA: Este script NO elimina las tablas antiguas (rol, permiso, permiso_de_rol)
-- Eso se hará en un script de reset separado para evitar problemas.

-- =====================================================
-- TABLA: permiso_sistema (catálogo único de permisos)
-- =====================================================
CREATE TABLE IF NOT EXISTS permiso_sistema (
    PK_ID_PERMISO INT PRIMARY KEY AUTO_INCREMENT,
    CODIGO VARCHAR(50) NOT NULL UNIQUE COMMENT 'Código único para verificar en código',
    NOMBRE VARCHAR(100) NOT NULL COMMENT 'Nombre para mostrar en UI',
    DESCRIPCION VARCHAR(255) COMMENT 'Descripción del permiso',
    ICONO VARCHAR(50) DEFAULT 'fa-check' COMMENT 'Icono FontAwesome',
    CATEGORIA VARCHAR(50) NOT NULL COMMENT 'ADMIN, PRODUCTOS, OFERTAS, ANALITICAS, etc.',
    ORDEN INT DEFAULT 0 COMMENT 'Orden de visualización',
    ESTADO TINYINT DEFAULT 1 COMMENT '1=Activo, 0=Inactivo'
);

-- =====================================================
-- TABLA: tipo_membresia_permiso (plantilla por membresía)
-- =====================================================
CREATE TABLE IF NOT EXISTS tipo_membresia_permiso (
    FK_ID_TIPO_MEMBRESIA INT NOT NULL,
    FK_ID_PERMISO INT NOT NULL,
    FECHA_ASIGNACION DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (FK_ID_TIPO_MEMBRESIA, FK_ID_PERMISO),
    FOREIGN KEY (FK_ID_TIPO_MEMBRESIA) REFERENCES tipo_membresia(PK_ID_TIPO_MEMBRESIA) ON DELETE CASCADE,
    FOREIGN KEY (FK_ID_PERMISO) REFERENCES permiso_sistema(PK_ID_PERMISO) ON DELETE CASCADE
);

-- =====================================================
-- TABLA: usuario_permiso (permisos efectivos por usuario)
-- =====================================================
CREATE TABLE IF NOT EXISTS usuario_permiso (
    PK_ID INT PRIMARY KEY AUTO_INCREMENT,
    FK_ID_USUARIO INT NOT NULL,
    FK_ID_PERMISO INT NOT NULL,
    FECHA_ASIGNACION DATETIME DEFAULT CURRENT_TIMESTAMP,
    ORIGEN ENUM('ADMIN', 'MEMBRESIA', 'PROMOCION') DEFAULT 'MEMBRESIA' COMMENT 'De dónde vino el permiso',
    ESTADO TINYINT DEFAULT 1 COMMENT '1=Activo, 0=Inactivo',
    UNIQUE KEY UK_usuario_permiso (FK_ID_USUARIO, FK_ID_PERMISO),
    FOREIGN KEY (FK_ID_USUARIO) REFERENCES usuario(PK_ID_USUARIO) ON DELETE CASCADE,
    FOREIGN KEY (FK_ID_PERMISO) REFERENCES permiso_sistema(PK_ID_PERMISO) ON DELETE CASCADE
);

-- =====================================================
-- TABLA: addon_tipo (catálogo de addons disponibles)
-- =====================================================
CREATE TABLE IF NOT EXISTS addon_tipo (
    PK_ID_ADDON INT PRIMARY KEY AUTO_INCREMENT,
    CODIGO VARCHAR(50) NOT NULL UNIQUE COMMENT 'Código único del addon',
    NOMBRE VARCHAR(100) NOT NULL COMMENT 'Nombre para mostrar',
    DESCRIPCION VARCHAR(255) COMMENT 'Descripción del addon',
    TIPO_LIMITE VARCHAR(50) NOT NULL COMMENT 'PRODUCTOS, OFERTAS_FLASH, DURACION_OFERTA',
    CANTIDAD INT NOT NULL COMMENT 'Cuánto agrega (ej: 50 productos)',
    PRECIO DECIMAL(10,2) NOT NULL COMMENT 'Precio del addon',
    ICONO VARCHAR(50) DEFAULT 'fa-plus',
    ESTADO TINYINT DEFAULT 1
);

-- =====================================================
-- TABLA: addon_local (addons comprados por local)
-- =====================================================
CREATE TABLE IF NOT EXISTS addon_local (
    PK_ID INT PRIMARY KEY AUTO_INCREMENT,
    FK_ID_LOCAL INT NOT NULL,
    FK_ID_ADDON INT NOT NULL,
    CANTIDAD_COMPRADA INT DEFAULT 1 COMMENT 'Cuántas veces compró este addon',
    FECHA_COMPRA DATETIME DEFAULT CURRENT_TIMESTAMP,
    FECHA_EXPIRACION DATETIME NULL COMMENT 'NULL = no expira',
    REF_PAGO VARCHAR(100) COMMENT 'Referencia de pago (ePayco)',
    ESTADO TINYINT DEFAULT 1,
    FOREIGN KEY (FK_ID_LOCAL) REFERENCES local(PK_ID_LOCAL) ON DELETE CASCADE,
    FOREIGN KEY (FK_ID_ADDON) REFERENCES addon_tipo(PK_ID_ADDON) ON DELETE CASCADE
);

-- =====================================================
-- DATOS: Permisos de ADMINISTRACIÓN
-- =====================================================
INSERT INTO permiso_sistema (CODIGO, NOMBRE, DESCRIPCION, ICONO, CATEGORIA, ORDEN) VALUES
('ADMIN_CATEGORIAS', 'Administrar Categorías', 'Crear, editar, eliminar categorías de productos', 'fa-folder-tree', 'ADMIN', 1),
('ADMIN_USUARIOS', 'Administrar Usuarios', 'Ver, editar, bloquear usuarios del sistema', 'fa-users-gear', 'ADMIN', 2),
('ADMIN_MEMBRESIAS', 'Administrar Membresías', 'Configurar planes, precios, permisos por plan', 'fa-id-card', 'ADMIN', 3),
('ADMIN_BANNERS', 'Administrar Banners', 'Gestionar banners del sistema', 'fa-images', 'ADMIN', 4),
('ADMIN_MARCAS', 'Administrar Marcas', 'Gestionar catálogo de marcas', 'fa-tags', 'ADMIN', 5),
('ADMIN_PRODUCTOS', 'Administrar Productos', 'Ver/moderar productos de todos los locales', 'fa-boxes-stacked', 'ADMIN', 6),
('ADMIN_GALERIA', 'Administrar Galería', 'Aprobar/rechazar imágenes de galería', 'fa-image', 'ADMIN', 7),
('ADMIN_LOGS', 'Ver Logs del Sistema', 'Acceso a auditoría y logs', 'fa-file-lines', 'ADMIN', 8),
('ADMIN_DASHBOARD', 'Ver Dashboard Admin', 'Acceso al panel de administración', 'fa-gauge-high', 'ADMIN', 9),
('ADMIN_PERMISOS', 'Gestionar Permisos', 'Asignar permisos a usuarios/locales', 'fa-user-shield', 'ADMIN', 10),
('ADMIN_NEGOCIOS', 'Administrar Negocios', 'Ver, editar, activar/desactivar negocios', 'fa-store', 'ADMIN', 11),
('ADMIN_OFERTAS', 'Moderar Ofertas Flash', 'Aprobar/rechazar ofertas', 'fa-bolt', 'ADMIN', 12),
('ADMIN_REPORTES', 'Ver Reportes Globales', 'Estadísticas de todo el sistema', 'fa-chart-pie', 'ADMIN', 13);

-- =====================================================
-- DATOS: Permisos de PRODUCTOS
-- =====================================================
INSERT INTO permiso_sistema (CODIGO, NOMBRE, DESCRIPCION, ICONO, CATEGORIA, ORDEN) VALUES
('PRODUCTOS_BASICO', 'Productos (con límite)', 'Publicar productos con límite según plan', 'fa-box', 'PRODUCTOS', 20),
('PRODUCTOS_ILIMITADOS', 'Productos Ilimitados', 'Sin límite de productos', 'fa-infinity', 'PRODUCTOS', 21),
('MULTIPLES_MARCAS', 'Múltiples Marcas', 'Agregar varias marcas/precios por producto', 'fa-layer-group', 'PRODUCTOS', 22),
('IMAGENES_PRODUCTO', 'Imágenes de Producto', 'Subir imagen principal del producto', 'fa-camera', 'PRODUCTOS', 23);

-- =====================================================
-- DATOS: Permisos de OFERTAS FLASH
-- =====================================================
-- NOTA: Los límites de ofertas (cantidad simultáneas, duración, total)
-- se manejan con valores numéricos en tipo_membresia y se pueden
-- extender comprando addons. Aquí solo está el permiso base.
INSERT INTO permiso_sistema (CODIGO, NOMBRE, DESCRIPCION, ICONO, CATEGORIA, ORDEN) VALUES
('OFERTAS_FLASH', 'Ofertas Flash', 'Crear ofertas con tiempo limitado', 'fa-bolt', 'OFERTAS', 30);

-- =====================================================
-- DATOS: Permisos de GALERÍA Y VISIBILIDAD
-- =====================================================
INSERT INTO permiso_sistema (CODIGO, NOMBRE, DESCRIPCION, ICONO, CATEGORIA, ORDEN) VALUES
('GALERIA_NEGOCIO', 'Galería del Negocio', 'Subir fotos del local/establecimiento', 'fa-images', 'VISIBILIDAD', 40),
('BANNER_PERSONALIZADO', 'Banner Personalizado', 'Seleccionar banner para el perfil', 'fa-panorama', 'VISIBILIDAD', 41),
('PRIORIDAD_BUSQUEDA', 'Prioridad en Búsquedas', 'Aparecer primero en resultados', 'fa-arrow-up-wide-short', 'VISIBILIDAD', 42),
('INSIGNIA_VERIFICADO', 'Insignia Verificado', 'Mostrar sello de verificación', 'fa-circle-check', 'VISIBILIDAD', 43);

-- =====================================================
-- DATOS: Permisos de ANALÍTICAS
-- =====================================================
INSERT INTO permiso_sistema (CODIGO, NOMBRE, DESCRIPCION, ICONO, CATEGORIA, ORDEN) VALUES
('ANALITICAS_BASICAS', 'Analíticas Básicas', 'Ver visitas y clics básicos', 'fa-chart-simple', 'ANALITICAS', 50),
('ANALITICAS_AVANZADAS', 'Analíticas Avanzadas', 'Gráficos, tendencias, períodos', 'fa-chart-line', 'ANALITICAS', 51),
('ANALITICAS_PRODUCTOS', 'Analíticas por Producto', 'Ver productos más vistos', 'fa-box-open', 'ANALITICAS', 52),
('EXPORTAR_ESTADISTICAS', 'Exportar Estadísticas', 'Descargar reportes Excel/PDF', 'fa-file-export', 'ANALITICAS', 53);

-- =====================================================
-- DATOS: Permisos de MARKETING/TRACKING
-- =====================================================
INSERT INTO permiso_sistema (CODIGO, NOMBRE, DESCRIPCION, ICONO, CATEGORIA, ORDEN) VALUES
('META_PIXEL', 'Meta Pixel', 'Vincular Facebook/Instagram Pixel', 'fa-brands fa-meta', 'MARKETING', 60),
('GOOGLE_TAG', 'Google Tag', 'Vincular GA4/Google Tag Manager', 'fa-brands fa-google', 'MARKETING', 61),
('TIKTOK_PIXEL', 'TikTok Pixel', 'Vincular TikTok Pixel', 'fa-brands fa-tiktok', 'MARKETING', 62);

-- =====================================================
-- DATOS: Permisos de COMUNICACIÓN
-- =====================================================
INSERT INTO permiso_sistema (CODIGO, NOMBRE, DESCRIPCION, ICONO, CATEGORIA, ORDEN) VALUES
('WHATSAPP_VISIBLE', 'WhatsApp Visible', 'Mostrar botón de WhatsApp en perfil', 'fa-brands fa-whatsapp', 'COMUNICACION', 70),
('REDES_SOCIALES', 'Redes Sociales', 'Mostrar links a Instagram, Facebook, TikTok, etc.', 'fa-share-nodes', 'COMUNICACION', 71),
('SITIO_WEB', 'Sitio Web', 'Mostrar link al sitio web', 'fa-globe', 'COMUNICACION', 72),
('EMAIL_CONTACTO', 'Email de Contacto', 'Mostrar email público', 'fa-envelope', 'COMUNICACION', 73);

-- =====================================================
-- DATOS: Permisos de INFORMACIÓN DEL NEGOCIO
-- =====================================================
INSERT INTO permiso_sistema (CODIGO, NOMBRE, DESCRIPCION, ICONO, CATEGORIA, ORDEN) VALUES
('HORARIOS_ATENCION', 'Horarios de Atención', 'Configurar y mostrar horarios', 'fa-clock', 'NEGOCIO', 80),
('UBICACION_MAPA', 'Ubicación en Mapa', 'Mostrar ubicación con Google Maps', 'fa-location-dot', 'NEGOCIO', 81),
('DESCRIPCION_EXTENDIDA', 'Descripción Extendida', 'Descripción detallada del negocio', 'fa-align-left', 'NEGOCIO', 82);

-- =====================================================
-- DATOS: Addons iniciales
-- =====================================================
INSERT INTO addon_tipo (CODIGO, NOMBRE, DESCRIPCION, TIPO_LIMITE, CANTIDAD, PRECIO, ICONO) VALUES
('ADDON_PRODUCTOS_50', '+50 Productos', 'Agrega 50 productos adicionales a tu límite', 'PRODUCTOS', 50, 25000, 'fa-box-open'),
('ADDON_PRODUCTOS_100', '+100 Productos', 'Agrega 100 productos adicionales a tu límite', 'PRODUCTOS', 100, 45000, 'fa-boxes-stacked'),
('ADDON_OFERTAS_10', '+10 Ofertas Flash', 'Agrega 10 ofertas flash adicionales', 'OFERTAS_FLASH', 10, 15000, 'fa-bolt'),
('ADDON_OFERTAS_25', '+25 Ofertas Flash', 'Agrega 25 ofertas flash adicionales', 'OFERTAS_FLASH', 25, 30000, 'fa-bolt');

-- =====================================================
-- STORED PROCEDURES
-- =====================================================

-- SP: Obtener todos los permisos del sistema (catálogo)
DROP PROCEDURE IF EXISTS obtener_permisos_sistema;
DELIMITER //
CREATE PROCEDURE obtener_permisos_sistema()
BEGIN
    SELECT
        PK_ID_PERMISO,
        CODIGO,
        NOMBRE,
        DESCRIPCION,
        ICONO,
        CATEGORIA,
        ORDEN,
        ESTADO
    FROM permiso_sistema
    WHERE ESTADO = 1
    ORDER BY CATEGORIA, ORDEN;
END//
DELIMITER ;

-- SP: Obtener permisos de una membresía (plantilla)
DROP PROCEDURE IF EXISTS obtener_permisos_membresia;
DELIMITER //
CREATE PROCEDURE obtener_permisos_membresia(
    IN p_id_tipo_membresia INT
)
BEGIN
    SELECT
        ps.PK_ID_PERMISO,
        ps.CODIGO,
        ps.NOMBRE,
        ps.DESCRIPCION,
        ps.ICONO,
        ps.CATEGORIA,
        ps.ORDEN
    FROM permiso_sistema ps
    INNER JOIN tipo_membresia_permiso tmp ON ps.PK_ID_PERMISO = tmp.FK_ID_PERMISO
    WHERE tmp.FK_ID_TIPO_MEMBRESIA = p_id_tipo_membresia
        AND ps.ESTADO = 1
    ORDER BY ps.CATEGORIA, ps.ORDEN;
END//
DELIMITER ;

-- SP: Obtener permisos efectivos de un usuario
DROP PROCEDURE IF EXISTS obtener_permisos_usuario;
DELIMITER //
CREATE PROCEDURE obtener_permisos_usuario(
    IN p_id_usuario INT
)
BEGIN
    SELECT
        ps.PK_ID_PERMISO,
        ps.CODIGO,
        ps.NOMBRE,
        ps.DESCRIPCION,
        ps.ICONO,
        ps.CATEGORIA,
        ps.ORDEN,
        up.ORIGEN,
        up.FECHA_ASIGNACION,
        up.ESTADO
    FROM permiso_sistema ps
    INNER JOIN usuario_permiso up ON ps.PK_ID_PERMISO = up.FK_ID_PERMISO
    WHERE up.FK_ID_USUARIO = p_id_usuario
        AND up.ESTADO = 1
        AND ps.ESTADO = 1
    ORDER BY ps.CATEGORIA, ps.ORDEN;
END//
DELIMITER ;

-- SP: Verificar si un usuario tiene un permiso específico
DROP PROCEDURE IF EXISTS verificar_permiso_usuario;
DELIMITER //
CREATE PROCEDURE verificar_permiso_usuario(
    IN p_id_usuario INT,
    IN p_codigo_permiso VARCHAR(50)
)
BEGIN
    SELECT COUNT(*) > 0 as tiene_permiso
    FROM usuario_permiso up
    INNER JOIN permiso_sistema ps ON up.FK_ID_PERMISO = ps.PK_ID_PERMISO
    WHERE up.FK_ID_USUARIO = p_id_usuario
        AND ps.CODIGO = p_codigo_permiso
        AND up.ESTADO = 1
        AND ps.ESTADO = 1;
END//
DELIMITER ;

-- SP: Asignar permisos de membresía a un usuario
DROP PROCEDURE IF EXISTS asignar_permisos_membresia_usuario;
DELIMITER //
CREATE PROCEDURE asignar_permisos_membresia_usuario(
    IN p_id_usuario INT,
    IN p_id_tipo_membresia INT
)
BEGIN
    -- Eliminar permisos anteriores con origen MEMBRESIA
    DELETE FROM usuario_permiso
    WHERE FK_ID_USUARIO = p_id_usuario
        AND ORIGEN = 'MEMBRESIA';

    -- Insertar nuevos permisos de la membresía
    INSERT INTO usuario_permiso (FK_ID_USUARIO, FK_ID_PERMISO, ORIGEN, ESTADO)
    SELECT p_id_usuario, FK_ID_PERMISO, 'MEMBRESIA', 1
    FROM tipo_membresia_permiso
    WHERE FK_ID_TIPO_MEMBRESIA = p_id_tipo_membresia;

    SELECT ROW_COUNT() as permisos_asignados;
END//
DELIMITER ;

-- SP: Asignar permiso individual a usuario (por admin)
DROP PROCEDURE IF EXISTS asignar_permiso_usuario;
DELIMITER //
CREATE PROCEDURE asignar_permiso_usuario(
    IN p_id_usuario INT,
    IN p_id_permiso INT,
    IN p_origen VARCHAR(20)
)
BEGIN
    INSERT INTO usuario_permiso (FK_ID_USUARIO, FK_ID_PERMISO, ORIGEN, ESTADO)
    VALUES (p_id_usuario, p_id_permiso, p_origen, 1)
    ON DUPLICATE KEY UPDATE ESTADO = 1, ORIGEN = p_origen;

    SELECT ROW_COUNT() as resultado;
END//
DELIMITER ;

-- SP: Remover permiso de usuario
DROP PROCEDURE IF EXISTS remover_permiso_usuario;
DELIMITER //
CREATE PROCEDURE remover_permiso_usuario(
    IN p_id_usuario INT,
    IN p_id_permiso INT
)
BEGIN
    UPDATE usuario_permiso
    SET ESTADO = 0
    WHERE FK_ID_USUARIO = p_id_usuario
        AND FK_ID_PERMISO = p_id_permiso;

    SELECT ROW_COUNT() as resultado;
END//
DELIMITER ;

-- SP: Actualizar permisos de una membresía (admin)
DROP PROCEDURE IF EXISTS actualizar_permisos_membresia;
DELIMITER //
CREATE PROCEDURE actualizar_permisos_membresia(
    IN p_id_tipo_membresia INT,
    IN p_ids_permisos TEXT -- Lista separada por comas: "1,2,3,5"
)
BEGIN
    -- Eliminar permisos actuales de la membresía
    DELETE FROM tipo_membresia_permiso
    WHERE FK_ID_TIPO_MEMBRESIA = p_id_tipo_membresia;

    -- Insertar nuevos permisos si hay alguno
    IF p_ids_permisos IS NOT NULL AND p_ids_permisos != '' THEN
        SET @sql = CONCAT(
            'INSERT INTO tipo_membresia_permiso (FK_ID_TIPO_MEMBRESIA, FK_ID_PERMISO) ',
            'SELECT ', p_id_tipo_membresia, ', PK_ID_PERMISO FROM permiso_sistema ',
            'WHERE PK_ID_PERMISO IN (', p_ids_permisos, ') AND ESTADO = 1'
        );
        PREPARE stmt FROM @sql;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END IF;

    SELECT COUNT(*) as permisos_asignados
    FROM tipo_membresia_permiso
    WHERE FK_ID_TIPO_MEMBRESIA = p_id_tipo_membresia;
END//
DELIMITER ;

-- SP: Obtener membresías con conteo de permisos (para admin)
DROP PROCEDURE IF EXISTS obtener_membresias_con_permisos;
DELIMITER //
CREATE PROCEDURE obtener_membresias_con_permisos()
BEGIN
    SELECT
        tm.PK_ID_TIPO_MEMBRESIA,
        tm.NOMBRE,
        tm.COSTO,
        tm.ESTADO,
        tm.CANTIDAD_PRODUCTOS,
        tm.OFERTAS_FLASH_SIMULTANEAS,
        tm.DURACION_OFERTA,
        COUNT(tmp.FK_ID_PERMISO) as total_permisos
    FROM tipo_membresia tm
    LEFT JOIN tipo_membresia_permiso tmp ON tm.PK_ID_TIPO_MEMBRESIA = tmp.FK_ID_TIPO_MEMBRESIA
    GROUP BY tm.PK_ID_TIPO_MEMBRESIA
    ORDER BY tm.NOMBRE;
END//
DELIMITER ;

-- SP: Obtener addons disponibles
DROP PROCEDURE IF EXISTS obtener_addons_disponibles;
DELIMITER //
CREATE PROCEDURE obtener_addons_disponibles()
BEGIN
    SELECT
        PK_ID_ADDON,
        CODIGO,
        NOMBRE,
        DESCRIPCION,
        TIPO_LIMITE,
        CANTIDAD,
        PRECIO,
        ICONO
    FROM addon_tipo
    WHERE ESTADO = 1
    ORDER BY TIPO_LIMITE, CANTIDAD;
END//
DELIMITER ;

-- SP: Obtener addons comprados por un local
DROP PROCEDURE IF EXISTS obtener_addons_local;
DELIMITER //
CREATE PROCEDURE obtener_addons_local(
    IN p_id_local INT
)
BEGIN
    SELECT
        al.PK_ID,
        al.FK_ID_LOCAL,
        al.FK_ID_ADDON,
        al.CANTIDAD_COMPRADA,
        al.FECHA_COMPRA,
        al.FECHA_EXPIRACION,
        al.REF_PAGO,
        al.ESTADO,
        at.CODIGO,
        at.NOMBRE,
        at.TIPO_LIMITE,
        at.CANTIDAD,
        (at.CANTIDAD * al.CANTIDAD_COMPRADA) as total_agregado
    FROM addon_local al
    INNER JOIN addon_tipo at ON al.FK_ID_ADDON = at.PK_ID_ADDON
    WHERE al.FK_ID_LOCAL = p_id_local
        AND al.ESTADO = 1
        AND (al.FECHA_EXPIRACION IS NULL OR al.FECHA_EXPIRACION > NOW())
    ORDER BY at.TIPO_LIMITE, al.FECHA_COMPRA DESC;
END//
DELIMITER ;

-- SP: Registrar compra de addon
DROP PROCEDURE IF EXISTS registrar_compra_addon;
DELIMITER //
CREATE PROCEDURE registrar_compra_addon(
    IN p_id_local INT,
    IN p_id_addon INT,
    IN p_cantidad INT,
    IN p_ref_pago VARCHAR(100),
    IN p_fecha_expiracion DATETIME
)
BEGIN
    INSERT INTO addon_local (FK_ID_LOCAL, FK_ID_ADDON, CANTIDAD_COMPRADA, REF_PAGO, FECHA_EXPIRACION)
    VALUES (p_id_local, p_id_addon, p_cantidad, p_ref_pago, p_fecha_expiracion);

    SELECT LAST_INSERT_ID() as id_compra;
END//
DELIMITER ;

-- SP: Obtener límite efectivo de productos para un local
DROP PROCEDURE IF EXISTS obtener_limite_productos_local;
DELIMITER //
CREATE PROCEDURE obtener_limite_productos_local(
    IN p_id_local INT
)
BEGIN
    DECLARE limite_base INT DEFAULT 0;
    DECLARE addons_extra INT DEFAULT 0;

    -- Límite base de la membresía activa
    SELECT COALESCE(CAST(tm.CANTIDAD_PRODUCTOS AS UNSIGNED), 0) INTO limite_base
    FROM suscripcion s
    INNER JOIN tipo_membresia tm ON s.FK_ID_TIPO_MEMBRESIA = tm.PK_ID_TIPO_MEMBRESIA
    WHERE s.FK_ID_LOCAL = p_id_local AND s.ESTADO = 1
    ORDER BY s.FECHA_INICIO DESC
    LIMIT 1;

    -- Addons comprados (tipo PRODUCTOS)
    SELECT COALESCE(SUM(at.CANTIDAD * al.CANTIDAD_COMPRADA), 0) INTO addons_extra
    FROM addon_local al
    INNER JOIN addon_tipo at ON al.FK_ID_ADDON = at.PK_ID_ADDON
    WHERE al.FK_ID_LOCAL = p_id_local
        AND at.TIPO_LIMITE = 'PRODUCTOS'
        AND al.ESTADO = 1
        AND (al.FECHA_EXPIRACION IS NULL OR al.FECHA_EXPIRACION > NOW());

    -- Si límite base es 0, es ilimitado
    IF limite_base = 0 THEN
        SELECT 0 as limite_base, 0 as addons_extra, 0 as limite_total, 1 as es_ilimitado;
    ELSE
        SELECT limite_base, addons_extra, (limite_base + addons_extra) as limite_total, 0 as es_ilimitado;
    END IF;
END//
DELIMITER ;

-- SP: Obtener límite efectivo de ofertas flash para un local
DROP PROCEDURE IF EXISTS obtener_limite_ofertas_local;
DELIMITER //
CREATE PROCEDURE obtener_limite_ofertas_local(
    IN p_id_local INT
)
BEGIN
    DECLARE limite_simultaneas INT DEFAULT 1;
    DECLARE limite_total INT DEFAULT 0;
    DECLARE duracion_base INT DEFAULT 6;
    DECLARE addons_ofertas INT DEFAULT 0;

    -- Límites base de la membresía activa
    SELECT
        COALESCE(tm.OFERTAS_FLASH_SIMULTANEAS, 1),
        COALESCE(tm.OFERTAS_FLASH_TOTAL, 0),
        COALESCE(tm.DURACION_OFERTA, 6)
    INTO limite_simultaneas, limite_total, duracion_base
    FROM suscripcion s
    INNER JOIN tipo_membresia tm ON s.FK_ID_TIPO_MEMBRESIA = tm.PK_ID_TIPO_MEMBRESIA
    WHERE s.FK_ID_LOCAL = p_id_local AND s.ESTADO = 1
    ORDER BY s.FECHA_INICIO DESC
    LIMIT 1;

    -- Addons comprados (tipo OFERTAS_FLASH)
    SELECT COALESCE(SUM(at.CANTIDAD * al.CANTIDAD_COMPRADA), 0) INTO addons_ofertas
    FROM addon_local al
    INNER JOIN addon_tipo at ON al.FK_ID_ADDON = at.PK_ID_ADDON
    WHERE al.FK_ID_LOCAL = p_id_local
        AND at.TIPO_LIMITE = 'OFERTAS_FLASH'
        AND al.ESTADO = 1
        AND (al.FECHA_EXPIRACION IS NULL OR al.FECHA_EXPIRACION > NOW());

    SELECT
        limite_simultaneas,
        limite_total as limite_total_base,
        addons_ofertas,
        CASE WHEN limite_total = 0 THEN 0 ELSE (limite_total + addons_ofertas) END as limite_total_efectivo,
        duracion_base as duracion_horas,
        CASE WHEN limite_total = 0 THEN 1 ELSE 0 END as es_ilimitado;
END//
DELIMITER ;
