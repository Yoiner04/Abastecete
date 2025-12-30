-- ============================================================
-- Migración 006: SPs para administración de Addons
-- ============================================================

-- =====================================================
-- SP: obtener_todos_addons_admin
-- Obtiene todos los addons (incluyendo inactivos)
-- =====================================================
DROP PROCEDURE IF EXISTS obtener_todos_addons_admin;

DELIMITER //
CREATE PROCEDURE obtener_todos_addons_admin()
BEGIN
    SELECT
        PK_ID_ADDON,
        CODIGO,
        NOMBRE,
        DESCRIPCION,
        TIPO_LIMITE,
        CANTIDAD,
        PRECIO,
        ICONO,
        ESTADO
    FROM addon_tipo
    ORDER BY TIPO_LIMITE, NOMBRE;
END//
DELIMITER ;

-- =====================================================
-- SP: crear_addon
-- Crea un nuevo addon
-- =====================================================
DROP PROCEDURE IF EXISTS crear_addon;

DELIMITER //
CREATE PROCEDURE crear_addon(
    IN p_codigo VARCHAR(50),
    IN p_nombre VARCHAR(100),
    IN p_descripcion VARCHAR(500),
    IN p_tipo_limite VARCHAR(50),
    IN p_cantidad INT,
    IN p_precio DECIMAL(10,2),
    IN p_icono VARCHAR(50)
)
BEGIN
    DECLARE v_id INT;

    -- Verificar que no exista un addon con el mismo código
    IF EXISTS (SELECT 1 FROM addon_tipo WHERE CODIGO = p_codigo) THEN
        SELECT 0 AS id_addon, 'Ya existe un addon con ese código' AS mensaje;
    ELSE
        INSERT INTO addon_tipo (CODIGO, NOMBRE, DESCRIPCION, TIPO_LIMITE, CANTIDAD, PRECIO, ICONO, ESTADO)
        VALUES (p_codigo, p_nombre, p_descripcion, p_tipo_limite, p_cantidad, p_precio, p_icono, 1);

        SET v_id = LAST_INSERT_ID();
        SELECT v_id AS id_addon, 'Addon creado exitosamente' AS mensaje;
    END IF;
END//
DELIMITER ;

-- =====================================================
-- SP: actualizar_addon
-- Actualiza un addon existente
-- =====================================================
DROP PROCEDURE IF EXISTS actualizar_addon;

DELIMITER //
CREATE PROCEDURE actualizar_addon(
    IN p_id INT,
    IN p_codigo VARCHAR(50),
    IN p_nombre VARCHAR(100),
    IN p_descripcion VARCHAR(500),
    IN p_tipo_limite VARCHAR(50),
    IN p_cantidad INT,
    IN p_precio DECIMAL(10,2),
    IN p_icono VARCHAR(50)
)
BEGIN
    UPDATE addon_tipo
    SET CODIGO = p_codigo,
        NOMBRE = p_nombre,
        DESCRIPCION = p_descripcion,
        TIPO_LIMITE = p_tipo_limite,
        CANTIDAD = p_cantidad,
        PRECIO = p_precio,
        ICONO = p_icono
    WHERE PK_ID_ADDON = p_id;
END//
DELIMITER ;

-- =====================================================
-- SP: cambiar_estado_addon
-- Activa o desactiva un addon
-- =====================================================
DROP PROCEDURE IF EXISTS cambiar_estado_addon;

DELIMITER //
CREATE PROCEDURE cambiar_estado_addon(
    IN p_id INT,
    IN p_estado INT
)
BEGIN
    UPDATE addon_tipo
    SET ESTADO = p_estado
    WHERE PK_ID_ADDON = p_id;
END//
DELIMITER ;

-- =====================================================
-- SP: eliminar_addon
-- Elimina un addon si no tiene compras asociadas
-- =====================================================
DROP PROCEDURE IF EXISTS eliminar_addon;

DELIMITER //
CREATE PROCEDURE eliminar_addon(
    IN p_id INT
)
BEGIN
    DECLARE v_compras INT;

    -- Verificar si tiene compras asociadas
    SELECT COUNT(*) INTO v_compras FROM addon_local WHERE FK_ID_ADDON = p_id;

    IF v_compras > 0 THEN
        SELECT 0 AS resultado, 'No se puede eliminar: el addon tiene compras asociadas' AS mensaje;
    ELSE
        DELETE FROM addon_tipo WHERE PK_ID_ADDON = p_id;
        SELECT 1 AS resultado, 'Addon eliminado exitosamente' AS mensaje;
    END IF;
END//
DELIMITER ;

-- =====================================================
-- SP: obtener_estadisticas_addons
-- Estadísticas de ventas de addons
-- =====================================================
DROP PROCEDURE IF EXISTS obtener_estadisticas_addons;

DELIMITER //
CREATE PROCEDURE obtener_estadisticas_addons()
BEGIN
    SELECT
        at.PK_ID_ADDON AS id_addon,
        at.NOMBRE AS nombre,
        COUNT(al.PK_ID) AS total_ventas,
        COALESCE(SUM(al.CANTIDAD_COMPRADA), 0) AS cantidad_total,
        COALESCE(SUM(al.CANTIDAD_COMPRADA * at.PRECIO), 0) AS ingreso_total
    FROM addon_tipo at
    LEFT JOIN addon_local al ON at.PK_ID_ADDON = al.FK_ID_ADDON AND al.ESTADO = 1
    GROUP BY at.PK_ID_ADDON, at.NOMBRE
    ORDER BY ingreso_total DESC;
END//
DELIMITER ;

SELECT 'MIGRACIÓN 006 - SPs de Addons Admin creados' as info;
