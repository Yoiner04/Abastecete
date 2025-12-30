-- =====================================================
-- Migración: Agregar unidad/medida a producto_marca
-- Fecha: 2025-12-30
-- Descripción: Permite que un producto tenga múltiples
--              presentaciones (marca + medida + precio)
-- =====================================================

-- NOTA: Si la columna FK_ID_UNIDAD ya existe, omitir las líneas 1-4
-- y ejecutar solo los stored procedures

-- =====================================================
-- Actualizar stored procedure para listar marcas
-- =====================================================
DROP PROCEDURE IF EXISTS sp_listar_marcas_producto;

DELIMITER //
CREATE PROCEDURE sp_listar_marcas_producto(
    IN p_id_local INT,
    IN p_id_producto INT
)
BEGIN
    SELECT
        pm.PK_ID as Id,
        pm.FK_ID_LOCAL as IdLocal,
        pm.FK_ID_PRODUCTO as IdProducto,
        pm.FK_ID_MARCA as IdMarca,
        m.NOMBRE as NombreMarca,
        m.LOGO_URL as LogoMarca,
        pm.FK_ID_UNIDAD as IdUnidad,
        COALESCE(u.NOMBRE_UNIDAD, '') as NombreUnidad,
        pm.PRECIO as Precio,
        pm.STOCK as Stock,
        pm.DISPONIBLE as Disponible,
        pm.FECHA_REGISTRO as FechaRegistro,
        pm.FECHA_ACTUALIZACION as FechaActualizacion
    FROM producto_marca pm
    INNER JOIN marca m ON pm.FK_ID_MARCA = m.PK_ID_MARCA
    LEFT JOIN unidad u ON pm.FK_ID_UNIDAD = u.ID_UNIDAD
    WHERE pm.FK_ID_LOCAL = p_id_local
      AND pm.FK_ID_PRODUCTO = p_id_producto
    ORDER BY pm.PRECIO ASC;
END//
DELIMITER ;

-- =====================================================
-- Actualizar stored procedure para agregar marca/presentación
-- =====================================================
DROP PROCEDURE IF EXISTS sp_agregar_marca_producto;

DELIMITER //
CREATE PROCEDURE sp_agregar_marca_producto(
    IN p_id_local INT,
    IN p_id_producto INT,
    IN p_id_marca INT,
    IN p_id_unidad INT,
    IN p_precio DECIMAL(12,2),
    IN p_stock INT,
    IN p_disponible TINYINT
)
BEGIN
    DECLARE v_existing_id INT DEFAULT 0;

    -- Verificar si ya existe esta combinación
    SELECT PK_ID INTO v_existing_id
    FROM producto_marca
    WHERE FK_ID_LOCAL = p_id_local
      AND FK_ID_PRODUCTO = p_id_producto
      AND FK_ID_MARCA = p_id_marca
      AND ((FK_ID_UNIDAD = p_id_unidad) OR (FK_ID_UNIDAD IS NULL AND (p_id_unidad IS NULL OR p_id_unidad = 0)))
    LIMIT 1;

    IF v_existing_id > 0 THEN
        -- Ya existe, actualizar
        UPDATE producto_marca
        SET PRECIO = p_precio,
            STOCK = p_stock,
            DISPONIBLE = p_disponible,
            FECHA_ACTUALIZACION = NOW()
        WHERE PK_ID = v_existing_id;

        SELECT v_existing_id as Id, 'Presentación actualizada' as Mensaje;
    ELSE
        -- No existe, insertar
        INSERT INTO producto_marca (FK_ID_LOCAL, FK_ID_PRODUCTO, FK_ID_MARCA, FK_ID_UNIDAD, PRECIO, STOCK, DISPONIBLE)
        VALUES (p_id_local, p_id_producto, p_id_marca, NULLIF(p_id_unidad, 0), p_precio, p_stock, p_disponible);

        SELECT LAST_INSERT_ID() as Id, 'Presentación creada' as Mensaje;
    END IF;
END//
DELIMITER ;

-- =====================================================
-- Actualizar stored procedure para actualizar presentación
-- =====================================================
DROP PROCEDURE IF EXISTS sp_actualizar_marca_producto;

DELIMITER //
CREATE PROCEDURE sp_actualizar_marca_producto(
    IN p_id INT,
    IN p_id_unidad INT,
    IN p_precio DECIMAL(12,2),
    IN p_stock INT,
    IN p_disponible TINYINT
)
BEGIN
    UPDATE producto_marca
    SET FK_ID_UNIDAD = NULLIF(p_id_unidad, 0),
        PRECIO = p_precio,
        STOCK = p_stock,
        DISPONIBLE = p_disponible,
        FECHA_ACTUALIZACION = NOW()
    WHERE PK_ID = p_id;

    SELECT ROW_COUNT() as FilasAfectadas;
END//
DELIMITER ;

-- =====================================================
-- Mensaje de confirmación
-- =====================================================
SELECT 'Migración completada: stored procedures actualizados para presentaciones' as Mensaje;
