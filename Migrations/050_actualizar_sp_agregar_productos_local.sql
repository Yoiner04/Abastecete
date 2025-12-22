-- =============================================
-- Migración: 050_actualizar_sp_agregar_productos_local.sql
-- Fecha: 2025-12-22
-- Descripción: Actualizar SP agregar_productos_local para incluir marca
--              y agregar a tabla producto_marca
-- =============================================

DELIMITER //

DROP PROCEDURE IF EXISTS `agregar_productos_local`//

CREATE PROCEDURE `agregar_productos_local`(
    IN `producto_id` INT,
    IN `medida` INT,
    IN `valor` INT,
    IN `local_id` INT,
    IN `marca_id` INT
)
BEGIN
    DECLARE v_total INT DEFAULT 0;
    DECLARE v_max INT DEFAULT 0;
    DECLARE v_pl_id INT DEFAULT 0;
    DECLARE v_marca INT DEFAULT 1;

    -- Si no se pasa marca, usar la marca del producto o 1 (Sin Marca)
    SET v_marca = COALESCE(marca_id, (SELECT FK_ID_MARCA FROM producto WHERE PK_ID_PRODUCTO = producto_id), 1);

    -- Cuenta cuántos productos ya tiene este local
    SELECT COUNT(*)
    INTO v_total
    FROM productoslocal
    WHERE FK_ID_LOCAL = local_id;

    -- Lee el límite de productos de la membresía desde la suscripción activa
    SELECT COALESCE(tm.CANTIDAD_PRODUCTOS, 0)
    INTO v_max
    FROM local l
    LEFT JOIN suscripcion s ON l.FK_ID_SUSCRIPCION_ACTIVA = s.PK_ID_SUSCRIPCION AND s.ESTADO = 1
    LEFT JOIN tipo_membresia tm ON s.FK_ID_TIPO_MEMBRESIA = tm.PK_ID_TIPO_MEMBRESIA
    WHERE l.PK_ID_LOCAL = local_id;

    -- Inserta sólo si no supera el límite (0 = sin límite)
    IF v_max = 0 OR v_total < v_max THEN
        -- Verificar si ya existe el producto con la misma marca y unidad
        SELECT PK_ID_PRODUCTS_LOCAL INTO v_pl_id
        FROM productoslocal
        WHERE FK_ID_LOCAL = local_id
          AND FK_ID_PRODUCTO = producto_id
          AND FK_ID_UNIDAD = medida
        LIMIT 1;

        IF v_pl_id > 0 THEN
            -- Ya existe, actualizar el precio y agregar/actualizar la marca
            UPDATE productoslocal
            SET VALOR_PRODUCTS_LOCAL = valor
            WHERE PK_ID_PRODUCTS_LOCAL = v_pl_id;
        ELSE
            -- No existe, insertar nuevo
            INSERT INTO productoslocal (
                FK_ID_PRODUCTO,
                FK_ID_UNIDAD,
                VALOR_PRODUCTS_LOCAL,
                FK_ID_LOCAL
            ) VALUES (
                producto_id,
                medida,
                valor,
                local_id
            );
            SET v_pl_id = LAST_INSERT_ID();
        END IF;

        -- Agregar/actualizar la marca en producto_marca
        INSERT INTO producto_marca (FK_ID_PRODUCTO, FK_ID_MARCA, PRECIO, DISPONIBLE)
        VALUES (producto_id, v_marca, valor, 1)
        ON DUPLICATE KEY UPDATE
            PRECIO = valor,
            DISPONIBLE = 1,
            FECHA_ACTUALIZACION = CURRENT_TIMESTAMP;

        SELECT 1 AS resultado, 'Producto agregado correctamente' AS mensaje;
    ELSE
        SELECT 0 AS resultado, 'Límite de productos alcanzado' AS mensaje;
    END IF;
END//

DELIMITER ;

SELECT 'Migración 050 completada - SP agregar_productos_local actualizado con soporte para marca' AS resultado;
