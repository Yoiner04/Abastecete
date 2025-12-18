-- --------------------------------------------------------
-- Host:                         167.71.91.199
-- Versión del servidor:         8.0.42-0ubuntu0.24.10.1 - (Ubuntu)
-- SO del servidor:              Linux
-- HeidiSQL Versión:             12.10.0.7000
-- --------------------------------------------------------

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET NAMES utf8 */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;


-- Volcando estructura de base de datos para abastecete
CREATE DATABASE IF NOT EXISTS `abastecete` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci */ /*!80016 DEFAULT ENCRYPTION='N' */;
USE `abastecete`;

-- Volcando estructura para evento abastecete.actualizar_estado_membresia
DELIMITER //
CREATE EVENT `actualizar_estado_membresia` ON SCHEDULE EVERY 1 MINUTE STARTS '2025-01-23 09:50:02' ON COMPLETION NOT PRESERVE ENABLE DO BEGIN
    -- Cambiar el estado a 2 (inactivo) si la FECHA_FIN es menor que la fecha actual
    UPDATE membresia
    SET ESTADO = 2
    WHERE FECHA_FIN < NOW() AND ESTADO = 1;

    -- Opcional: Log para seguimiento
    INSERT INTO logs_membresia (mensaje, fecha_registro)
    VALUES ('Se actualizaron membresías vencidas a inactivas', NOW());
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.actualizar_estado_usuario
DELIMITER //
CREATE PROCEDURE `actualizar_estado_usuario`(
  IN `p_id_usuario` INT,
  IN `p_nuevo_estado` TINYINT,
  OUT `mensaje` VARCHAR(255)
)
BEGIN
  -- Verificar si el usuario existe
  IF EXISTS (SELECT 1 FROM usuario WHERE PK_ID_USUARIO = p_id_usuario) THEN
    -- Actualizar el estado del usuario
    UPDATE usuario
    SET ESTADO = p_nuevo_estado
    WHERE PK_ID_USUARIO = p_id_usuario;

    IF p_nuevo_estado = 1 THEN
      SET mensaje = 'Usuario habilitado correctamente.';
    ELSE
      SET mensaje = 'Usuario deshabilitado correctamente.';
    END IF;
  ELSE
    SET mensaje = 'Usuario no encontrado.';
  END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.actualizar_membresia_usuario
DELIMITER //
CREATE PROCEDURE `actualizar_membresia_usuario`(
    IN `p_usuario_id` INT,                   -- ID del usuario cuya membresía se va a actualizar
    IN `p_fk_id_tipo_membresia` INT,         -- ID del tipo de nueva membresía
    IN `p_dias_duracion` INT,                -- Número de días que dura la membresía
    OUT `mensaje` VARCHAR(500),              -- Mensaje de resultado
    OUT `resultado` INT                      -- Resultado de la operación
)
BEGIN
    DECLARE v_costo DECIMAL(10,2);
    DECLARE v_pago_existente INT;
    DECLARE v_fecha_inicio DATETIME;
    DECLARE v_fecha_fin DATETIME;
    DECLARE v_membresia_id INT;
    DECLARE v_finalizar BOOLEAN DEFAULT FALSE; -- Bandera para detener el flujo

    -- Manejo de errores
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK; -- Rollback si hay un error
        SET mensaje = 'Ocurrió un error al actualizar la membresía.';
        SET resultado = 0;
    END;

    -- Inicializar resultado
    SET resultado = 0;

    -- Iniciar transacción
    START TRANSACTION;

    -- Verificar si el usuario existe
    IF NOT EXISTS (SELECT 1 FROM usuario WHERE PK_ID_USUARIO = p_usuario_id) THEN
        SET mensaje = 'El usuario no existe.';
        SET v_finalizar = TRUE;
    END IF;

    -- Verificar si la membresía especificada existe
    IF NOT v_finalizar AND NOT EXISTS (SELECT 1 FROM tipo_membresia WHERE PK_ID_TIPO_MEMBRESIA = p_fk_id_tipo_membresia) THEN
        SET mensaje = 'La membresía especificada no existe.';
        SET v_finalizar = TRUE;
    END IF;

    -- Si no se debe finalizar, verificar el costo de la membresía
    IF NOT v_finalizar THEN
        SELECT COSTO INTO v_costo
        FROM tipo_membresia
        WHERE PK_ID_TIPO_MEMBRESIA = p_fk_id_tipo_membresia;

        -- Si la membresía es de pago, verificar si hay un pago confirmado y tomar la fecha
        IF v_costo > 0 THEN
            SELECT FECHA_PAGO INTO v_fecha_inicio
            FROM pagos
            WHERE FK_ID_USUARIO = p_usuario_id 
            AND FK_ID_TIPO_MEMBRESIA = p_fk_id_tipo_membresia
            AND ESTADO_PAGO = 'CONFIRMADO'
            ORDER BY FECHA_PAGO DESC
            LIMIT 1;

            -- Validar si existe un pago confirmado
            IF v_fecha_inicio IS NULL THEN
                SET mensaje = 'Debe realizar un pago confirmado para esta membresía.';
                SET v_finalizar = TRUE;
            END IF;
        ELSE
            -- Si es una membresía gratuita, usar la fecha actual como inicio
            SET v_fecha_inicio = NOW();
        END IF;

        -- Calcular la fecha de finalización usando la duración proporcionada
        SET v_fecha_fin = DATE_ADD(v_fecha_inicio, INTERVAL p_dias_duracion DAY);
    END IF;

    -- Si no hay errores, proceder con la actualización
    IF NOT v_finalizar THEN
        -- Insertar la nueva membresía en la tabla membresia
        INSERT INTO membresia (FK_ID_TIPO_MEMBRESIA, FECHA_INICIO, FECHA_FIN, ESTADO)
        VALUES (p_fk_id_tipo_membresia, v_fecha_inicio, v_fecha_fin, 1);

        -- Obtener el ID de la membresía recién creada
        SET v_membresia_id = LAST_INSERT_ID();

        -- Actualizar la membresía actual del usuario
        UPDATE usuario 
        SET FK_ID_MEMBRESIA = v_membresia_id
        WHERE PK_ID_USUARIO = p_usuario_id;

        -- Confirmar éxito
        SET mensaje = 'Membresía actualizada correctamente.';
        SET resultado = 1;
    END IF;

    -- Confirmar o revertir la transacción
    IF v_finalizar THEN
        ROLLBACK;
    ELSE
        COMMIT;
    END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.agregar_local_favorito
DELIMITER //
CREATE PROCEDURE `agregar_local_favorito`(
  IN `p_usuario_id` INT,          -- ID del usuario
  IN `p_local_id` INT,            -- ID del local que se desea agregar como favorito
  OUT `mensaje` VARCHAR(500),     -- Mensaje de respuesta
  OUT `resultado` INT             -- Resultado de la operación
)
BEGIN
  -- Inicializar el resultado
  SET resultado = 0;

  -- Verificar si el usuario existe
  IF NOT EXISTS (SELECT 1 FROM usuario WHERE PK_ID_USUARIO = p_usuario_id) THEN
    SET mensaje = 'El usuario no existe.';
  
  -- Verificar si el local existe
  ELSEIF NOT EXISTS (SELECT 1 FROM local WHERE PK_ID_LOCAL = p_local_id) THEN
    SET mensaje = 'El local no existe.';
  
  -- Verificar si el local ya está en los favoritos del usuario
  ELSEIF EXISTS (SELECT 1 FROM favoritos WHERE FK_ID_USUARIO = p_usuario_id AND FK_ID_LOCAL = p_local_id) THEN
    SET mensaje = 'El local ya está en tus favoritos.';
  
  ELSE
    -- Insertar el nuevo local favorito
    INSERT INTO favoritos (FK_ID_USUARIO, FK_ID_LOCAL)
    VALUES (p_usuario_id, p_local_id);

    -- Confirmar éxito
    SET mensaje = 'Local agregado a favoritos con éxito.';
    SET resultado = 1;
  END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.agregar_productos_local
DELIMITER //
CREATE PROCEDURE `agregar_productos_local`(
	IN `producto_id` INT,
	IN `medida` INT,
	IN `valor` INT,
	IN `local_id` INT
)
BEGIN
    DECLARE v_total  INT DEFAULT 0;
    DECLARE v_max    INT DEFAULT 0;

    -- 1) Cuenta cuántos productos ya tiene este local
    SELECT COUNT(*) 
      INTO v_total
    FROM productoslocal
    WHERE FK_ID_LOCAL = local_id;

    -- 2) Lee el límite de productos de la membresía (0 = sin límite)
    SELECT tm.CANTIDAD_PRODUCTOS 
      INTO v_max
    FROM local l
    JOIN tipo_membresia tm 
      ON l.FK_ID_TIPOMEMBRESIA = tm.PK_ID_TIPO_MEMBRESIA
    WHERE l.PK_ID_LOCAL = local_id;

    -- 3) Inserta sólo si no supera el límite
    IF v_max = 0 OR v_total < v_max THEN

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
    END IF;

END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.aprobar_ofertas_flash
DELIMITER //
CREATE PROCEDURE `aprobar_ofertas_flash`(
	IN `p_id_oferta` INT
)
BEGIN
    DECLARE intervalo INT;

	 SELECT tipo_membresia.DURACION_OFERTA INTO intervalo
	 FROM oferta_flash
	 INNER JOIN local ON oferta_flash.FK_ID_LOCAL = local.PK_ID_LOCAL
	 INNER JOIN tipo_membresia ON local.FK_ID_TIPOMEMBRESIA = tipo_membresia.PK_ID_TIPO_MEMBRESIA
	 WHERE oferta_flash.ID_OFERTAFLASH = p_id_oferta;
	 
     UPDATE oferta_flash
     SET ESTADO_OFERTA_FLASH = 1,
         FECHA_OFERTA_FLASH = NOW(),
         TIEMPO_OFERTA_FLASH = NOW() + INTERVAL intervalo HOUR
     WHERE ID_OFERTAFLASH = p_id_oferta;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.asignar_membresia_usuario
DELIMITER //
CREATE PROCEDURE `asignar_membresia_usuario`(
    IN `p_usuario_id` INT,                   
    IN `p_fk_id_tipo_membresia` INT,         
    IN `p_fecha_inicio` DATETIME,            
    OUT `mensaje` VARCHAR(255),             
    OUT `resultado` INT                      
)
BEGIN
    DECLARE v_costo DECIMAL(10,2);
    DECLARE v_pago_existente INT;
    DECLARE v_fecha_inicio DATETIME;
    DECLARE v_fecha_fin DATETIME;
    DECLARE v_finalizar BOOLEAN DEFAULT FALSE; -- Bandera para detener el flujo

    -- Manejo de errores
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK; -- Rollback si hay un error
        SET mensaje = 'Ocurrió un error al asignar la membresía.';
        SET resultado = 0;
    END;

    -- Inicializar resultado
    SET resultado = 0;

    -- Iniciar transacción
    START TRANSACTION;

    -- Verificar si el usuario existe
    IF NOT EXISTS (SELECT 1 FROM usuario WHERE PK_ID_USUARIO = p_usuario_id) THEN
        SET mensaje = 'El usuario no existe.';
        SET v_finalizar = TRUE;
    END IF;

    -- Verificar si el tipo de membresía existe
    IF NOT v_finalizar AND NOT EXISTS (SELECT 1 FROM tipo_membresia WHERE PK_ID_TIPO_MEMBRESIA = p_fk_id_tipo_membresia) THEN
        SET mensaje = 'La membresía especificada no existe.';
        SET v_finalizar = TRUE;
    END IF;

    -- Obtener el costo de la membresía
    IF NOT v_finalizar THEN
        SELECT COSTO INTO v_costo
        FROM tipo_membresia
        WHERE PK_ID_TIPO_MEMBRESIA = p_fk_id_tipo_membresia;

        -- Verificar si la membresía es de pago
        IF v_costo > 0 THEN
            -- Buscar pago confirmado y obtener su fecha de pago
            SELECT FECHA_PAGO INTO v_fecha_inicio
            FROM pagos
            WHERE FK_ID_USUARIO = p_usuario_id
            AND FK_ID_TIPO_MEMBRESIA = p_fk_id_tipo_membresia
            AND ESTADO_PAGO = 'CONFIRMADO'
            ORDER BY FECHA_PAGO DESC
            LIMIT 1;

            -- Si no existe un pago confirmado
            IF v_fecha_inicio IS NULL THEN
                SET mensaje = 'Debe realizar un pago confirmado para obtener esta membresía.';
                SET v_finalizar = TRUE;
            END IF;

            -- Calcular la fecha de finalización sumando 30 días
            SET v_fecha_fin = DATE_ADD(v_fecha_inicio, INTERVAL 30 DAY);
        ELSE
            -- Si la membresía es gratuita, asignar fecha actual como inicio y dejar FECHA_FIN en NULL
            SET v_fecha_inicio = NOW();
            SET v_fecha_fin = NULL;
        END IF;
    END IF;

    -- Asignar la membresía al usuario si todo está correcto
    IF NOT v_finalizar THEN
        -- Insertar la nueva membresía en la tabla membresia
        INSERT INTO membresia (FK_ID_TIPO_MEMBRESIA, FECHA_INICIO, FECHA_FIN, ESTADO)
        VALUES (p_fk_id_tipo_membresia, v_fecha_inicio, v_fecha_fin, 1);

        -- Actualizar la membresía del usuario
        UPDATE usuario
        SET FK_ID_MEMBRESIA = LAST_INSERT_ID()
        WHERE PK_ID_USUARIO = p_usuario_id;

        -- Confirmar éxito
        SET mensaje = 'Membresía asignada correctamente.';
        SET resultado = 1;
    END IF;

    -- Confirmar o revertir la transacción
    IF v_finalizar THEN
        ROLLBACK;
    ELSE
        COMMIT;
    END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.asignar_permiso_rol
DELIMITER //
CREATE PROCEDURE `asignar_permiso_rol`(
  IN `p_id_rol` INT,
  IN `p_id_permiso` INT
)
BEGIN
  SELECT @MAX_ID := MAX(PK_ID_PERMISO_ROL)
  FROM permiso_de_rol pr
  WHERE pr.PFK_ID_ROL = p_id_rol AND pr.PFK_ID_PERMISO = p_id_permiso;

  IF (@MAX_ID IS NULL) THEN
    INSERT INTO permiso_de_rol (PFK_ID_ROL, PFK_ID_PERMISO, ESTADO_PERMISO_ROL)
    VALUES (p_id_rol, p_id_permiso, TRUE);
  ELSE
    SELECT @ESTADO := ESTADO_PERMISO_ROL
    FROM permiso_de_rol pr
    WHERE pr.PFK_ID_ROL = p_id_rol AND pr.PFK_ID_PERMISO = p_id_permiso;

    IF (@ESTADO != TRUE) THEN
      UPDATE permiso_de_rol
      SET ESTADO_PERMISO_ROL = 1
      WHERE PFK_ID_ROL = p_id_rol AND PFK_ID_PERMISO = p_id_permiso;
    ELSE
      UPDATE permiso_de_rol
      SET ESTADO_PERMISO_ROL = 0
      WHERE PFK_ID_ROL = p_id_rol AND PFK_ID_PERMISO = p_id_permiso;
    END IF;
  END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.asignar_producto_a_usuario
DELIMITER //
CREATE PROCEDURE `asignar_producto_a_usuario`(
  IN `p_fk_id_usuario` INT,
  IN `p_fk_id_producto` INT,
  OUT `mensaje` VARCHAR(500)
)
BEGIN
  DECLARE usuario_existe INT;
  DECLARE producto_existe INT;

  -- Verificar si el usuario existe
  SELECT COUNT(*) INTO usuario_existe FROM usuario WHERE PK_ID_USUARIO = p_fk_id_usuario;

  -- Verificar si el producto existe
  SELECT COUNT(*) INTO producto_existe FROM producto WHERE PK_ID_PRODUCTO = p_fk_id_producto;

  IF usuario_existe = 0 THEN
    SET mensaje = 'El usuario especificado no existe.';
  ELSEIF producto_existe = 0 THEN
    SET mensaje = 'El producto especificado no existe.';
  ELSE
    -- Insertar en la tabla de relación producto_usuario
    INSERT INTO producto_usuario (FK_ID_USUARIO, FK_ID_PRODUCTO)
    VALUES (p_fk_id_usuario, p_fk_id_producto);
    SET mensaje = 'Producto asignado al usuario con éxito.';
  END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.asignar_rol
DELIMITER //
CREATE PROCEDURE `asignar_rol`(
	IN `p_id_usuario` INT,
	IN `p_id_rol` INT
)
BEGIN
    -- Manejo de errores
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN
        SELECT 'Error en la base de datos.' AS mensaje;
    END;

    -- Verificar si el usuario existe
    IF NOT EXISTS (SELECT 1 FROM usuario WHERE PK_ID_USUARIO = p_id_usuario) THEN
        SELECT 'El usuario especificado no existe.' AS mensaje;
    -- Verificar si el rol existe
    ELSEIF NOT EXISTS (SELECT 1 FROM rol WHERE PK_ID_ROL = p_id_rol) THEN
        SELECT 'El rol especificado no existe.' AS mensaje;
    ELSE
        -- Asignar el rol al usuario
        UPDATE usuario 
        SET FK_ID_ROL = p_id_rol 
        WHERE PK_ID_USUARIO = p_id_usuario;

        -- Verificar si se actualizó el registro
        IF ROW_COUNT() > 0 THEN
            SELECT 'Rol asignado correctamente al usuario.' AS mensaje;
        ELSE
            SELECT 'No se pudo asignar el rol. Verifique los datos.' AS mensaje;
        END IF;
    END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.buscador_ofertas
DELIMITER //
CREATE PROCEDURE `buscador_ofertas`(
	IN `busqueda` VARCHAR(50)
)
BEGIN

	SELECT * 
	FROM oferta_flash
	INNER JOIN local ON oferta_flash.FK_ID_LOCAL = `local`.PK_ID_LOCAL
	WHERE oferta_flash.PRODUCTO_OFERTA_FLASH LIKE CONCAT('%', busqueda, '%') AND oferta_flash.ESTADO_OFERTA_FLASH = 1;

END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.buscador_productos
DELIMITER //
CREATE PROCEDURE `buscador_productos`(
	IN `busqueda` VARCHAR(50)
)
BEGIN

	SELECT * 
	FROM producto
	INNER JOIN productoslocal ON productoslocal.FK_ID_PRODUCTO = producto.PK_ID_PRODUCTO
	INNER JOIN `local` ON productoslocal.FK_ID_LOCAL = `local`.PK_ID_LOCAL
	WHERE NOMBRE_PRODUCTO LIKE CONCAT('%', busqueda, '%');
    
END//
DELIMITER ;

-- Volcando estructura para tabla abastecete.categoria
CREATE TABLE IF NOT EXISTS `categoria` (
  `PK_ID_CATEGORIA` int NOT NULL AUTO_INCREMENT,
  `NOMBRE_CATEGORIA` varchar(100) NOT NULL,
  `ESTADO_CATEGORIA` tinyint NOT NULL DEFAULT '1',
  `IMAGEN_CATEGORIA` varchar(255) DEFAULT NULL,
  `BANNER_CATEGORIA` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`PK_ID_CATEGORIA`)
) ENGINE=InnoDB AUTO_INCREMENT=17 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Volcando datos para la tabla abastecete.categoria: ~13 rows (aproximadamente)
INSERT INTO `categoria` (`PK_ID_CATEGORIA`, `NOMBRE_CATEGORIA`, `ESTADO_CATEGORIA`, `IMAGEN_CATEGORIA`, `BANNER_CATEGORIA`) VALUES
	(4, 'Frutas y Verduras', 1, '68309cb78e2dc61914d38cb4', '68309cb88e2dc61914d38cb6'),
	(5, 'Proteínas', 1, '68309e8e8e2dc61914d38cbc', '68309e8f8e2dc61914d38cbe'),
	(6, 'Lácteos y Huevos', 1, '68309ea48e2dc61914d38cc0', '68309ea48e2dc61914d38cc2'),
	(7, 'Panadería y Repostería', 1, '68309ebd8e2dc61914d38cc4', '68309ebe8e2dc61914d38cc6'),
	(8, 'Despensa', 1, '68309edc8e2dc61914d38ccc', '68309edc8e2dc61914d38cce'),
	(9, 'Congelados', 1, '68309f158e2dc61914d38cd0', '68309f168e2dc61914d38cd2'),
	(10, 'Bebidas', 1, '6830a1d08e2dc61914d38cf4', '6830a1d08e2dc61914d38cf6'),
	(11, 'Snacks y Aperitivos', 1, '6830a1a58e2dc61914d38cf0', '6830a1a58e2dc61914d38cf2'),
	(12, 'Dulces y Chocolatería', 1, '6830a17b8e2dc61914d38ce9', '6830a17c8e2dc61914d38cee'),
	(13, 'Charcutería y Especialidades', 1, '68309fbe8e2dc61914d38ce0', '68309fbf8e2dc61914d38ce2'),
	(14, 'Aseo del Hogar', 1, '68309f978e2dc61914d38cdc', '68309f988e2dc61914d38cde'),
	(15, 'Cuidado Personal', 1, '68309f798e2dc61914d38cd8', '68309f7a8e2dc61914d38cda'),
	(16, 'Licores y Tabaco', 1, '68309f2f8e2dc61914d38cd4', '68309f2f8e2dc61914d38cd6');

-- Volcando estructura para procedimiento abastecete.confirmar_pago
DELIMITER //
CREATE PROCEDURE `confirmar_pago`(
    IN `p_pago_id` INT,
    OUT `mensaje` VARCHAR(255),
    OUT `resultado` INT
)
BEGIN
    -- Validar si el pago existe
    IF NOT EXISTS (SELECT 1 FROM pagos WHERE PK_ID_PAGO = p_pago_id) THEN
        SET mensaje = 'El pago no existe.';
        SET resultado = 0;

    ELSE
        -- Actualizar el estado del pago a CONFIRMADO
        UPDATE pagos
        SET ESTADO_PAGO = 'CONFIRMADO'
        WHERE PK_ID_PAGO = p_pago_id;

        SET mensaje = 'El pago ha sido confirmado exitosamente.';
        SET resultado = 1;
    END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.consultar_categoria
DELIMITER //
CREATE PROCEDURE `consultar_categoria`()
BEGIN
  
  SELECT * FROM categoria;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.consultar_categoria_por_id
DELIMITER //
CREATE PROCEDURE `consultar_categoria_por_id`(
    IN `p_id_categoria` INT,
    OUT `mensaje` VARCHAR(255),
    OUT `resultado` INT
)
BEGIN
    DECLARE categoria_existe INT DEFAULT 0;

    -- Verificar si la categoría existe
    SELECT COUNT(*) INTO categoria_existe
    FROM categoria
    WHERE PK_ID_CATEGORIA = p_id_categoria;

    IF categoria_existe > 0 THEN
        SELECT * FROM categoria WHERE PK_ID_CATEGORIA = p_id_categoria;
        SET mensaje = 'Categoría encontrada';
        SET resultado = 1;
    ELSE
        SET mensaje = 'Categoría no encontrada';
        SET resultado = 0;
        -- Retornar conjunto vacío con la estructura correcta
        SELECT * FROM categoria WHERE 1 = 0;
    END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.consultar_estado
DELIMITER //
CREATE PROCEDURE `consultar_estado`()
BEGIN
 
  SELECT * FROM estado;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.consultar_estado_local
DELIMITER //
CREATE PROCEDURE `consultar_estado_local`()
BEGIN
  
  SELECT * FROM estado_local;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.consultar_local
DELIMITER //
CREATE PROCEDURE `consultar_local`(
	IN `p_id_persona` INT
)
BEGIN
    -- Si el ID de la persona es 0, traer todos los locales
    IF p_id_persona = 0 THEN
        SELECT * FROM local;
    ELSE
        -- Si se proporciona un ID válido, filtrar por el ID de la persona
        SELECT * FROM local WHERE FK_ID_PERSONA = p_id_persona;
    END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.consultar_local_categoria
DELIMITER //
CREATE PROCEDURE `consultar_local_categoria`(
	IN `idcategoria` INT,
	IN `tipoMembresia` VARCHAR(50)
)
BEGIN
  SELECT l.* 
  FROM local l
  INNER JOIN localcategoria lc ON lc.FK_ID_LOCAL = l.PK_ID_LOCAL
  INNER JOIN tipo_membresia tm ON tm.PK_ID_TIPO_MEMBRESIA = l.FK_ID_TIPOMEMBRESIA
  WHERE lc.FK_ID_CATEGORIA = idcategoria
    AND (
      tipoMembresia = 'Selecciona un Tipo' 
      OR (tipoMembresia = 'Proveedor' AND tm.NOMBRE LIKE 'Plan Proveedor%')
      OR (tipoMembresia = 'Cultivador' AND tm.NOMBRE LIKE 'Plan Cultivador%')
      OR (tipoMembresia = 'Empresa' AND tm.NOMBRE LIKE 'Plan Empresa%')
    );
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.consultar_local_por_categorias
DELIMITER //
CREATE PROCEDURE `consultar_local_por_categorias`(
	IN `idlocal` INT
)
BEGIN

	SELECT * FROM localcategoria
	INNER JOIN categoria ON localcategoria.FK_ID_CATEGORIA = categoria.PK_ID_CATEGORIA
	WHERE localcategoria.FK_ID_LOCAL = idlocal;

END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.consultar_local_por_id
DELIMITER //
CREATE PROCEDURE `consultar_local_por_id`(
	IN `idlocal` INT
)
BEGIN
	SELECT * FROM local
	WHERE local.PK_ID_LOCAL =  idlocal;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.consultar_local_por_id_seguro
DELIMITER //
CREATE PROCEDURE `consultar_local_por_id_seguro`(
    IN `p_id_local` INT,
    OUT `mensaje` VARCHAR(255),
    OUT `resultado` INT
)
BEGIN
    DECLARE local_existe INT DEFAULT 0;

    -- Verificar si existe el local
    SELECT COUNT(*) INTO local_existe
    FROM local
    WHERE PK_ID_LOCAL = p_id_local;

    IF local_existe > 0 THEN
        SELECT * FROM local WHERE PK_ID_LOCAL = p_id_local;
        SET mensaje = 'Local encontrado';
        SET resultado = 1;
    ELSE
        SET mensaje = 'Local no encontrado';
        SET resultado = 0;
        -- Retornar conjunto vacío con la estructura correcta
        SELECT * FROM local WHERE 1 = 0;
    END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.consultar_local_por_persona_seguro
DELIMITER //
CREATE PROCEDURE `consultar_local_por_persona_seguro`(
    IN `p_id_persona` INT,
    OUT `mensaje` VARCHAR(255),
    OUT `resultado` INT
)
BEGIN
    DECLARE local_existe INT DEFAULT 0;

    -- Verificar si existe un local para esta persona
    SELECT COUNT(*) INTO local_existe
    FROM local
    WHERE FK_ID_PERSONA = p_id_persona;

    IF local_existe > 0 THEN
        SELECT * FROM local WHERE FK_ID_PERSONA = p_id_persona LIMIT 1;
        SET mensaje = 'Local encontrado';
        SET resultado = 1;
    ELSE
        SET mensaje = 'No se encontró local para esta persona';
        SET resultado = 0;
        -- Retornar conjunto vacío con la estructura correcta
        SELECT * FROM local WHERE 1 = 0;
    END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.consultar_membresia
DELIMITER //
CREATE PROCEDURE `consultar_membresia`()
BEGIN
  
  SELECT 
    m.*, 
    tm.NOMBRE AS tipo_membresia
  FROM membresia m
  JOIN tipo_membresia tm ON m.FK_ID_TIPO_MEMBRESIA = tm.PK_ID_TIPO_MEMBRESIA;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.consultar_metodo_autenticacion
DELIMITER //
CREATE PROCEDURE `consultar_metodo_autenticacion`()
BEGIN
  
  SELECT * FROM metodo_autenticacion;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.consultar_ofertas_flash
DELIMITER //
CREATE PROCEDURE `consultar_ofertas_flash`()
BEGIN
	SELECT
	oferta_flash.ID_OFERTAFLASH,
	oferta_flash.TITULO_OFERTA_FLASH,
	oferta_flash.DESCRIPCION_OFERTA_FLASH,
	oferta_flash.ESTADO_OFERTA_FLASH,
	oferta_flash.TIEMPO_OFERTA_FLASH,
	oferta_flash.PRODUCTO_OFERTA_FLASH,
	oferta_flash.IMAGEN_PRODUCTO_OFERTA_FLASH,
	oferta_flash.PRIORIDAD_OFERTA_FLASH,
	local.NOMBRE_LOCAL,
	local.FOTOS_LOCAL,
	local.PK_ID_LOCAL
	FROM oferta_flash
	INNER JOIN local ON oferta_flash.FK_ID_LOCAL = local.PK_ID_LOCAL
	WHERE oferta_flash.ESTADO_OFERTA_FLASH != 2
	ORDER BY 
        CASE 
            WHEN oferta_flash.PRIORIDAD_OFERTA_FLASH = 2 THEN 1
            WHEN oferta_flash.PRIORIDAD_OFERTA_FLASH = 1 THEN 2
            ELSE 0 -- Para cualquier otro valor, lo pone al final
        END,
        RAND();
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.consultar_opinion
DELIMITER //
CREATE PROCEDURE `consultar_opinion`()
BEGIN
  
  SELECT * FROM opinion;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.consultar_permiso
DELIMITER //
CREATE PROCEDURE `consultar_permiso`(
  IN `p_id_rol` INT
)
BEGIN
  IF p_id_rol = 0 THEN
    SELECT *, 'False' AS 'ESTADO_PERMISO_ROL' 
    FROM permiso;
  ELSE  
    SELECT p.*, COALESCE(pr.ESTADO_PERMISO_ROL, 'False') AS ESTADO_PERMISO_ROL
    FROM permiso p
    LEFT JOIN permiso_de_rol pr ON pr.PFK_ID_ROL = p_id_rol AND p.PK_ID_PERMISO = pr.PFK_ID_PERMISO;
  END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.consultar_persona
DELIMITER //
CREATE PROCEDURE `consultar_persona`(
	IN `p_id_persona` INT
)
BEGIN
    IF p_id_persona > 0 THEN
        SELECT * FROM persona WHERE PK_ID_PERSONA = p_id_persona;
    ELSE
        SELECT * FROM persona;
    END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.consultar_producto
DELIMITER //
CREATE PROCEDURE `consultar_producto`()
BEGIN
  
  SELECT * FROM producto;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.consultar_productos_subcategoria
DELIMITER //
CREATE PROCEDURE `consultar_productos_subcategoria`(
	IN `id_subcategoria` INT
)
BEGIN
	SELECT * FROM producto WHERE producto.FK_ID_SUB_CATEGORIA= id_subcategoria;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.consultar_producto_negocio
DELIMITER //
CREATE PROCEDURE `consultar_producto_negocio`(
	IN `idproducto` INT,
	IN `idlocal` INT
)
BEGIN
 	SELECT producto.NOMBRE_PRODUCTO,productoslocal.VALOR_PRODUCTS_LOCAL,producto.IMAGEN_URL,unidad.NOMBRE_UNIDAD FROM producto
 	INNER JOIN productoslocal ON productoslocal.FK_ID_PRODUCTO = producto.PK_ID_PRODUCTO
 	INNER JOIN unidad ON productoslocal.FK_ID_UNIDAD = unidad.ID_UNIDAD
 	WHERE productoslocal.FK_ID_PRODUCTO = idproducto AND productoslocal.FK_ID_LOCAL= idlocal;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.consultar_producto_negocio_seguro
DELIMITER //
CREATE PROCEDURE `consultar_producto_negocio_seguro`(
    IN `p_id_producto` INT,
    IN `p_id_local` INT,
    OUT `mensaje` VARCHAR(255),
    OUT `resultado` INT
)
BEGIN
    DECLARE producto_existe INT DEFAULT 0;

    -- Verificar si existe el producto en ese local
    SELECT COUNT(*) INTO producto_existe
    FROM productoslocal pl
    INNER JOIN producto p ON pl.FK_ID_PRODUCTO = p.PK_ID_PRODUCTO
    WHERE pl.FK_ID_PRODUCTO = p_id_producto
      AND pl.FK_ID_LOCAL = p_id_local;

    IF producto_existe > 0 THEN
        SELECT
            p.NOMBRE_PRODUCTO,
            pl.VALOR_PRODUCTS_LOCAL,
            p.IMAGEN_URL,
            u.NOMBRE_UNIDAD
        FROM productoslocal pl
        INNER JOIN producto p ON pl.FK_ID_PRODUCTO = p.PK_ID_PRODUCTO
        INNER JOIN unidad u ON p.FK_ID_UNIDAD = u.PK_ID_UNIDAD
        WHERE pl.FK_ID_PRODUCTO = p_id_producto
          AND pl.FK_ID_LOCAL = p_id_local;
        SET mensaje = 'Producto encontrado';
        SET resultado = 1;
    ELSE
        SET mensaje = 'Producto no encontrado en este local';
        SET resultado = 0;
        -- Retornar conjunto vacío
        SELECT NULL AS NOMBRE_PRODUCTO, NULL AS VALOR_PRODUCTS_LOCAL,
               NULL AS IMAGEN_URL, NULL AS NOMBRE_UNIDAD
        WHERE 1 = 0;
    END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.consultar_rol
DELIMITER //
CREATE PROCEDURE `consultar_rol`()
BEGIN
  
  SELECT PK_ID_ROL, NOMBRE_ROL 
  FROM rol;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.consultar_sub_categoria
DELIMITER //
CREATE PROCEDURE `consultar_sub_categoria`(
	IN `p_id_categoria` INT
)
BEGIN
    SELECT * FROM sub_categoria WHERE FK_ID_CATEGORIA = p_id_categoria;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.consultar_tipo_documento
DELIMITER //
CREATE PROCEDURE `consultar_tipo_documento`()
BEGIN
  
  SELECT * FROM tipo_documento;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.consultar_tipo_membresia
DELIMITER //
CREATE PROCEDURE `consultar_tipo_membresia`(
	IN `nombre` VARCHAR(50)
)
BEGIN
if nombre = "" then
	SELECT * FROM tipo_membresia;
ELSE
SELECT * FROM tipo_membresia
	WHERE tipo_membresia.NOMBRE LIKE CONCAT('%', nombre, '%');
END if;

END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.consultar_tipo_membresia_distinct
DELIMITER //
CREATE PROCEDURE `consultar_tipo_membresia_distinct`()
SELECT DISTINCT 
    CASE 
        WHEN NOMBRE LIKE '%Proveedor%' THEN 'Proveedor'
        WHEN NOMBRE LIKE '%Cultivador%' THEN 'Cultivador'
        WHEN NOMBRE LIKE '%Empresa%' THEN 'Empresa'
    END AS Membresia
FROM tipo_membresia//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.consultar_tipo_membresia_por_id
DELIMITER //
CREATE PROCEDURE `consultar_tipo_membresia_por_id`(
	IN `id_membresia` INT
)
BEGIN
	SELECT * FROM tipo_membresia
	WHERE PK_ID_TIPO_MEMBRESIA = id_membresia;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.consultar_unidad
DELIMITER //
CREATE PROCEDURE `consultar_unidad`(
	IN `id_producto` INT
)
BEGIN
	SELECT u.*
    FROM unidad u
    WHERE u.FK_ID_TIPOUNIDAD = (
        SELECT p.FK_ID_TIPOUNIDAD
        FROM producto p
        WHERE p.PK_ID_PRODUCTO = id_producto
    );
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.consultar_usuario
DELIMITER //
CREATE PROCEDURE `consultar_usuario`(
	IN `id_usuario` INT
)
BEGIN
    SELECT 
        u.*,
        p.*,
        r.*,
        td.*
    FROM usuario u
    INNER JOIN persona p ON u.FK_ID_PERSONA = p.PK_ID_PERSONA
    INNER JOIN rol r ON u.FK_ID_ROL = r.PK_ID_ROL
    INNER JOIN tipo_documento td ON p.FK_ID_TIPO_DOCUMENTO = td.PK_ID_TIPO_DOCUMENTO
    
    WHERE u.PK_ID_USUARIO = id_usuario;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.consultar_usuarios
DELIMITER //
CREATE PROCEDURE `consultar_usuarios`()
BEGIN
  SELECT
    usuario.PK_ID_USUARIO,
    persona.NOMBRES,
    persona.APELLIDOS,
    persona.TELEFONO,
    usuario.ESTADO,
    rol.NOMBRE_ROL,
    persona.CORREO,
    tipo_membresia.NOMBRE
  FROM usuario
    LEFT JOIN persona ON usuario.FK_ID_PERSONA = persona.PK_ID_PERSONA
    LEFT JOIN rol ON usuario.FK_ID_ROL = rol.PK_ID_ROL
    LEFT JOIN local ON local.FK_ID_PERSONA = persona.PK_ID_PERSONA
    LEFT JOIN tipo_membresia ON local.FK_ID_TIPOMEMBRESIA = tipo_membresia.PK_ID_TIPO_MEMBRESIA;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.crear_categoria
DELIMITER //
CREATE PROCEDURE `crear_categoria`(
	IN `p_nombre_categoria` VARCHAR(100),
	IN `p_estado_categoria` TINYINT,
	IN `p_imagen_categoria` VARCHAR(255),
	OUT `mensaje` VARCHAR(500),
	IN `p_banner_categoria` INT
)
BEGIN
    DECLARE categoria_existe INT;

    -- Verificar si ya existe una categoría con el mismo nombre
    SELECT COUNT(*) INTO categoria_existe FROM categoria WHERE NOMBRE_CATEGORIA = p_nombre_categoria;

    IF categoria_existe = 0 THEN
        -- Insertar la nueva categoría
        INSERT INTO categoria (NOMBRE_CATEGORIA, ESTADO_CATEGORIA, IMAGEN_CATEGORIA,BANNER_CATEGORIA)
        VALUES (p_nombre_categoria, p_estado_categoria, p_imagen_categoria,p_banner_categoria);
        SET mensaje = 'Categoría creada con éxito.';
    ELSE
        SET mensaje = 'La categoría con el nombre especificado ya existe.';
    END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.crear_detallemedida
DELIMITER //
CREATE PROCEDURE `crear_detallemedida`(
	IN `id_producto` INT,
	IN `id_unidad` INT,
	IN `valor` INT
)
BEGIN
	INSERT INTO detallemedida (detallemedida.FK_ID_PRODUCTO,detallemedida.FK_ID_UNIDAD,detallemedida.VALOR) 
	VALUES (id_producto,id_unidad,valor);
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.crear_estado
DELIMITER //
CREATE PROCEDURE `crear_estado`(
  IN `p_nombre_estado` VARCHAR(50),
  OUT `mensaje` VARCHAR(500),
  OUT `resultado` INT
)
BEGIN
  SET resultado = 0;

  -- Verificar si el estado ya existe
  IF EXISTS (SELECT 1 FROM estado WHERE NOMBRE_ESTADO = p_nombre_estado) THEN
    SET mensaje = 'El estado ya existe.';
  ELSE
    -- Insertar el nuevo estado
    INSERT INTO estado (NOMBRE_ESTADO)
    VALUES (p_nombre_estado);

    -- Si todo fue exitoso
    SET resultado = 1;
    SET mensaje = 'Estado agregado exitosamente.';
  END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.crear_estado_local
DELIMITER //
CREATE PROCEDURE `crear_estado_local`(
  IN `p_nombre_estado` VARCHAR(50),
  OUT `mensaje` VARCHAR(500)
)
BEGIN
  -- Insertar un nuevo estado de local
  INSERT INTO estado_local (NOMBRE_ESTADO)
  VALUES (p_nombre_estado);
  SET mensaje = 'Estado de local creado con éxito.';
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.crear_local
DELIMITER //
CREATE PROCEDURE `crear_local`(
	IN `p_fk_id_persona` INT,
	IN `p_fk_id_estado_local` INT,
	IN `p_fk_id_tipomembresia` INT,
	IN `p_localizacion` VARCHAR(100),
	IN `p_nombre_local` VARCHAR(100),
	IN `p_direccion_local` VARCHAR(200),
	IN `p_telefono_local` VARCHAR(20),
	IN `p_fotos_local` LONGTEXT,
	IN `p_descripcion_local` VARCHAR(200)
)
BEGIN
    DECLARE persona_existe INT;
    DECLARE estado_local_existe INT;
    DECLARE nuevo_local_id INT;

    -- Verificar si la persona existe
    SELECT COUNT(*) INTO persona_existe FROM persona WHERE PK_ID_PERSONA = p_fk_id_persona;

    -- Verificar si el estado del local existe
    SELECT COUNT(*) INTO estado_local_existe FROM estado WHERE PK_ID_ESTADO = p_fk_id_estado_local;

    IF persona_existe > 0 AND estado_local_existe > 0 THEN
        -- Insertar el nuevo local sin la ciudad
        INSERT INTO local (FK_ID_PERSONA, FK_ID_ESTADO_LOCAL, FK_ID_TIPOMEMBRESIA, LOCALIZACION, NOMBRE_LOCAL, DIRECCION_LOCAL, TELEFONO_LOCAL, FOTOS_LOCAL, DESCRIPCION_LOCAL)
        VALUES (p_fk_id_persona, p_fk_id_estado_local, p_fk_id_tipomembresia, p_localizacion, p_nombre_local, p_direccion_local, p_telefono_local, p_fotos_local, p_descripcion_local);

        -- Obtener el ID del nuevo local insertado
        SET nuevo_local_id = LAST_INSERT_ID();

        -- Llamar al procedimiento crear_membresia automáticamente para este local
        CALL crear_membresia_local(nuevo_local_id, p_fk_id_estado_local);
    END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.crear_membresia_local
DELIMITER //
CREATE PROCEDURE `crear_membresia_local`(
	IN `p_local` INT,
	IN `p_estado` INT
)
BEGIN
  DECLARE estado_existe INT;
  DECLARE local_existe INT;

  -- Verificar si el estado existe
  SELECT COUNT(*) INTO estado_existe FROM estado WHERE PK_ID_ESTADO = p_estado;

  -- Verificar si el local existe
  SELECT COUNT(*) INTO local_existe FROM local WHERE PK_ID_LOCAL = p_local;

  IF estado_existe = 0 THEN
    -- Emitir un error y detener la ejecución
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El estado especificado no existe.';
  ELSEIF local_existe = 0 THEN
    -- Emitir un error y detener la ejecución
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El local especificado no existe.';
  ELSE
    -- Insertar la nueva membresía con FECHA_INICIO como el momento actual y FECHA_FIN un mes después
    INSERT INTO membresia_local (FK_ID_LOCAL, FECHA_INICIO, FECHA_FIN, ESTADO)
    VALUES (p_local, NOW(), DATE_ADD(NOW(), INTERVAL 1 MONTH), p_estado);
  END IF;

END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.crear_metodo_autenticacion
DELIMITER //
CREATE PROCEDURE `crear_metodo_autenticacion`(
  IN `p_nombre_metodo` VARCHAR(50),
  OUT `mensaje` VARCHAR(500),
  OUT `resultado` INT
)
BEGIN
  SET resultado = 0;

  -- Verificar si el método de autenticación ya existe
  IF EXISTS (SELECT 1 FROM metodo_autenticacion WHERE NOMBRE = p_nombre_metodo) THEN
    SET mensaje = 'El método de autenticación ya existe.';
  ELSE
    -- Insertar el nuevo método de autenticación
    INSERT INTO metodo_autenticacion (NOMBRE)
    VALUES (p_nombre_metodo);

    -- Si todo fue exitoso
    SET resultado = 1;
    SET mensaje = 'Método de autenticación agregado exitosamente.';
  END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.crear_oferta_flash
DELIMITER //
CREATE PROCEDURE `crear_oferta_flash`(
	IN `p_titulo_oferta` VARCHAR(50),
	IN `p_descripcion_oferta` TEXT,
	IN `p_id_local` INT,
	IN `p_producto` VARCHAR(50),
	IN `p_imagen` VARCHAR(255),
	IN `p_prioridad` INT
)
BEGIN
    DECLARE local_existe INT;

    -- Verificar si el local existe
    SELECT COUNT(*) INTO local_existe FROM local WHERE PK_ID_LOCAL = p_id_local;

    IF local_existe > 0 THEN
        -- Insertar la oferta flash
        INSERT INTO oferta_flash (
		  oferta_flash.TITULO_OFERTA_FLASH,
		  oferta_flash.DESCRIPCION_OFERTA_FLASH,
		  oferta_flash.FK_ID_LOCAL,
		  oferta_flash.PRODUCTO_OFERTA_FLASH,
		  oferta_flash.IMAGEN_PRODUCTO_OFERTA_FLASH,
		  oferta_flash.ESTADO_OFERTA_FLASH,
		  oferta_flash.TIEMPO_OFERTA_FLASH,
		  oferta_flash.PRIORIDAD_OFERTA_FLASH)
	     VALUES (p_titulo_oferta, p_descripcion_oferta, p_id_local, p_producto, p_imagen, 0, NOW(), p_prioridad);
    END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.crear_opinion
DELIMITER //
CREATE PROCEDURE `crear_opinion`(
  IN `p_fk_id_local` INT,
  IN `p_fk_id_persona` INT,
  IN `p_calificacion` TINYINT,
  IN `p_comentario` TEXT,
  OUT `mensaje` VARCHAR(500)
)
BEGIN
  DECLARE local_existe INT;
  DECLARE persona_existe INT;

  -- Verificar si el local existe
  SELECT COUNT(*) INTO local_existe FROM local WHERE PK_ID_LOCAL = p_fk_id_local;

  -- Verificar si la persona existe
  SELECT COUNT(*) INTO persona_existe FROM persona WHERE PK_ID_PERSONA = p_fk_id_persona;

  IF local_existe > 0 AND persona_existe > 0 THEN
    -- Insertar la nueva opinión
    INSERT INTO opinion (FK_ID_LOCAL, FK_ID_PERSONA, CALIFICACION, COMENTARIO)
    VALUES (p_fk_id_local, p_fk_id_persona, p_calificacion, p_comentario);
    SET mensaje = 'Opinión creada con éxito.';
  ELSE
    SET mensaje = 'El local o la persona no existen.';
  END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.crear_permiso
DELIMITER //
CREATE PROCEDURE `crear_permiso`(
  IN `p_nombre_permiso` VARCHAR(100),
  IN `p_estado_permiso` TINYINT
)
BEGIN
  -- Insertar el nuevo permiso
  INSERT INTO permiso (NOMBRE_PERMISO, ESTADO_PERMISO)
  VALUES (p_nombre_permiso, p_estado_permiso);
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.crear_producto
DELIMITER //
CREATE PROCEDURE `crear_producto`(
	IN `p_fk_id_sub_categoria` INT,
	IN `p_nombre_producto` VARCHAR(100),
	IN `p_imagen_url` VARCHAR(255)
)
BEGIN
  DECLARE sub_categoria_existe INT;

  -- Verificar si la subcategoría existe
  SELECT COUNT(*) INTO sub_categoria_existe FROM sub_categoria WHERE PK_ID_SUB_CATEGORIA = p_fk_id_sub_categoria;

  IF sub_categoria_existe > 0 THEN
    -- Insertar el nuevo producto
    INSERT INTO producto (FK_ID_SUB_CATEGORIA, NOMBRE_PRODUCTO, IMAGEN_URL)
    VALUES (p_fk_id_sub_categoria, p_nombre_producto, p_imagen_url);
  END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.crear_rol
DELIMITER //
CREATE PROCEDURE `crear_rol`(
	IN `p_nombre` VARCHAR(20)
)
BEGIN
    -- Manejo de errores
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN
        SELECT 'Error en la base de datos.' AS mensaje;
    END;

    -- Verificar si el rol ya existe
    IF EXISTS (SELECT 1 FROM rol WHERE NOMBRE_ROL = p_nombre) THEN
        SELECT 'El rol ya existe.' AS mensaje;
    ELSE
        -- Insertar el nuevo rol
        INSERT INTO rol (NOMBRE_ROL) VALUES (p_nombre);
        
        -- Verificar si la inserción fue exitosa
        IF ROW_COUNT() > 0 THEN
            SELECT 'Rol creado exitosamente.' AS mensaje;
        ELSE
            SELECT 'Error al crear el rol.' AS mensaje;
        END IF;
    END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.crear_sub_categoria
DELIMITER //
CREATE PROCEDURE `crear_sub_categoria`(
	IN `p_fk_id_categoria` INT,
	IN `p_nombre_sub_categoria` VARCHAR(100),
	IN `p_estado_sub_categoria` TINYINT
)
BEGIN
  DECLARE categoria_existe INT;
  DECLARE sub_categoria_existe INT;

  -- Verificar si la categoría existe
  SELECT COUNT(*) INTO categoria_existe FROM categoria WHERE PK_ID_CATEGORIA = p_fk_id_categoria;

  -- Verificar si ya existe una subcategoría con el mismo nombre en la categoría
  SELECT COUNT(*) INTO sub_categoria_existe FROM sub_categoria WHERE FK_ID_CATEGORIA = p_fk_id_categoria AND NOMBRE_SUB_CATEGORIA = p_nombre_sub_categoria;

  IF categoria_existe > 0 AND sub_categoria_existe = 0 THEN
    -- Insertar la nueva subcategoría
    INSERT INTO sub_categoria (FK_ID_CATEGORIA, NOMBRE_SUB_CATEGORIA, ESTADO_SUB_CATEGORIA)
    VALUES (p_fk_id_categoria, p_nombre_sub_categoria, p_estado_sub_categoria);
  END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.crear_tipo_documento
DELIMITER //
CREATE PROCEDURE `crear_tipo_documento`(
  IN `p_nombre_tipo_documento` VARCHAR(50),
  OUT `mensaje` VARCHAR(500),
  OUT `resultado` INT
)
BEGIN
  SET resultado = 0;

  -- Verificar si el tipo de documento ya existe
  IF EXISTS (SELECT 1 FROM tipo_documento WHERE NOMBRE_TIPO_DOCUMENTO = p_nombre_tipo_documento) THEN
    SET mensaje = 'El tipo de documento ya existe.';
  ELSE
    -- Insertar el nuevo tipo de documento
    INSERT INTO tipo_documento (NOMBRE_TIPO_DOCUMENTO)
    VALUES (p_nombre_tipo_documento);

    -- Si todo fue exitoso
    SET resultado = 1;
    SET mensaje = 'Tipo de documento agregado exitosamente.';
  END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.crear_tipo_membresia
DELIMITER //
CREATE PROCEDURE `crear_tipo_membresia`(
  IN `p_nombre` VARCHAR(50),
  IN `p_descripcion` TEXT,
  IN `p_costo` DECIMAL(10,2),
  OUT `mensaje` VARCHAR(500)
)
BEGIN
  -- Insertar un nuevo tipo de membresía con el costo
  INSERT INTO tipo_membresia (NOMBRE, DESCRIPCION, COSTO)
  VALUES (p_nombre, p_descripcion, p_costo);
  
  SET mensaje = 'Tipo de membresía creado con éxito.';
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.crear_usuario_google
DELIMITER //
CREATE PROCEDURE `crear_usuario_google`(
    IN `p_full_name` VARCHAR(255),
    IN `p_correo` VARCHAR(255),
    IN `p_fk_id_metodo_autenticacion` INT,
    IN `p_fk_id_rol` INT
)
BEGIN
    DECLARE v_first_name VARCHAR(100);
    DECLARE v_last_name VARCHAR(100);
    DECLARE v_persona_id INT;
    DECLARE v_usuario_id INT;
    DECLARE v_resultado INT DEFAULT 0;
    DECLARE v_mensaje VARCHAR(255);
    DECLARE v_codigo_referido VARCHAR(20);
    DECLARE v_codigo_existe INT DEFAULT 1;
    DECLARE v_intentos INT DEFAULT 0;

    -- Handler para errores
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET v_resultado = -99;
        SET v_mensaje = 'Error interno al crear el usuario.';
        SELECT v_resultado AS resultado, v_mensaje AS mensaje, NULL AS id_usuario;
    END;

    -- Iniciar transacción
    START TRANSACTION;

    -- Validar correo
    IF p_correo IS NULL OR TRIM(p_correo) = '' THEN
        SET v_resultado = -1;
        SET v_mensaje = 'El correo es requerido.';
    ELSEIF p_correo NOT REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN
        SET v_resultado = -2;
        SET v_mensaje = 'El correo no es válido.';
    ELSEIF EXISTS (SELECT 1 FROM usuario WHERE NOMBRE_USUARIO = LOWER(TRIM(p_correo))) THEN
        SET v_resultado = -3;
        SET v_mensaje = 'Ya existe un usuario con este correo.';
    ELSEIF EXISTS (SELECT 1 FROM persona WHERE CORREO = LOWER(TRIM(p_correo))) THEN
        SET v_resultado = -4;
        SET v_mensaje = 'Este correo ya está registrado.';
    ELSE
        -- Separar nombre y apellido
        IF p_full_name IS NULL OR TRIM(p_full_name) = '' THEN
            SET v_first_name = 'Usuario';
            SET v_last_name = 'Google';
        ELSE
            SET v_first_name = TRIM(SUBSTRING_INDEX(p_full_name, ' ', 1));
            SET v_last_name = TRIM(SUBSTRING(p_full_name, LOCATE(' ', p_full_name) + 1));

            IF v_last_name = '' OR v_last_name = v_first_name THEN
                SET v_last_name = 'Usuario';
            END IF;
        END IF;

        -- Generar código de referido único
        WHILE v_codigo_existe = 1 AND v_intentos < 10 DO
            SET v_codigo_referido = CONCAT('GOO', LPAD(FLOOR(RAND() * 10000000), 7, '0'));
            SET v_codigo_existe = (SELECT COUNT(*) FROM persona WHERE CODIGO_REFERIDO = v_codigo_referido);
            SET v_intentos = v_intentos + 1;
        END WHILE;

        IF v_codigo_existe = 1 THEN
            SET v_resultado = -5;
            SET v_mensaje = 'Error al generar código de referido.';
        ELSE
            -- Insertar persona (sin teléfono ni documento - se completará después)
            INSERT INTO persona (
                NOMBRES,
                APELLIDOS,
                TELEFONO,
                CORREO,
                DOCUMENTO_IDENTIDAD,
                ESTADO,
                FK_ID_TIPO_DOCUMENTO,
                CODIGO_REFERIDO,
                CODIGO_REFERIDO_USUARIO
            ) VALUES (
                v_first_name,
                v_last_name,
                NULL,  -- Teléfono pendiente de completar
                LOWER(TRIM(p_correo)),
                NULL,  -- Documento pendiente de completar
                1,
                1,     -- Tipo documento por defecto
                v_codigo_referido,
                NULL
            );

            SET v_persona_id = LAST_INSERT_ID();

            -- Insertar usuario (sin contraseña para usuarios de Google)
            INSERT INTO usuario (
                FK_ID_PERSONA,
                NOMBRE_USUARIO,
                CONTRASENIA,
                TIPO_AUTENTICACION,
                FK_ID_ROL,
                ESTADO,
                INTENTOS_FALLIDOS
            ) VALUES (
                v_persona_id,
                LOWER(TRIM(p_correo)),
                NULL,  -- Sin contraseña para auth con Google
                p_fk_id_metodo_autenticacion,
                IFNULL(p_fk_id_rol, 3),  -- Rol 3 por defecto
                1,
                0
            );

            SET v_usuario_id = LAST_INSERT_ID();

            COMMIT;

            SET v_resultado = 1;
            SET v_mensaje = 'Usuario creado exitosamente.';
        END IF;
    END IF;

    -- Si hubo error, hacer rollback
    IF v_resultado < 0 THEN
        ROLLBACK;
    END IF;

    SELECT v_resultado AS resultado, v_mensaje AS mensaje, v_usuario_id AS id_usuario;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.crear_usuario_persona
DELIMITER //
CREATE PROCEDURE `crear_usuario_persona`(
    IN `p_nombre` VARCHAR(40),
    IN `p_apellido` VARCHAR(40),
    IN `p_documento` INT,
    IN `p_fk_tipo_documento` INT,
    IN `p_telefono` VARCHAR(40),
    IN `p_correo` VARCHAR(50),
    IN `p_contrasenia` MEDIUMTEXT,
    IN `p_codigo_referido_usuario` VARCHAR(20),
    IN `p_fk_id_metodo_autenticacion` INT
)
BEGIN
    DECLARE v_mensaje VARCHAR(500);
    DECLARE v_resultado INT DEFAULT 0;
    DECLARE v_idpersona INT;
    DECLARE v_idusuario INT;
    DECLARE v_codigo_nuevo VARCHAR(20);
    DECLARE v_intentos INT DEFAULT 0;
    DECLARE v_codigo_existe INT DEFAULT 1;

    -- Declarar handler para errores
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET v_mensaje = 'Error interno al crear el usuario. Por favor intente nuevamente.';
        SET v_resultado = -99;
        SELECT v_resultado AS resultado, v_mensaje AS mensaje;
    END;

    -- Iniciar transacción
    START TRANSACTION;

    -- Validar campos requeridos
    IF p_nombre IS NULL OR TRIM(p_nombre) = '' THEN
        SET v_mensaje = 'El nombre es requerido.';
        SET v_resultado = -1;
    ELSEIF p_apellido IS NULL OR TRIM(p_apellido) = '' THEN
        SET v_mensaje = 'El apellido es requerido.';
        SET v_resultado = -1;
    ELSEIF p_documento IS NULL OR p_documento <= 0 THEN
        SET v_mensaje = 'El documento de identidad no es válido.';
        SET v_resultado = -1;
    ELSEIF p_correo IS NULL OR TRIM(p_correo) = '' OR p_correo NOT REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN
        SET v_mensaje = 'El correo electrónico no es válido.';
        SET v_resultado = -1;
    ELSEIF p_contrasenia IS NULL OR LENGTH(p_contrasenia) < 8 THEN
        SET v_mensaje = 'La contraseña debe tener al menos 8 caracteres.';
        SET v_resultado = -1;
    ELSEIF EXISTS (SELECT 1 FROM persona WHERE DOCUMENTO_IDENTIDAD = p_documento AND FK_ID_TIPO_DOCUMENTO = p_fk_tipo_documento) THEN
        SET v_mensaje = 'El documento de identidad ya está registrado con otra persona.';
        SET v_resultado = -2;
    ELSEIF EXISTS (SELECT 1 FROM persona WHERE CORREO = p_correo) THEN
        SET v_mensaje = 'El correo electrónico ya está registrado con otra persona.';
        SET v_resultado = -3;
    ELSEIF EXISTS (SELECT 1 FROM usuario WHERE NOMBRE_USUARIO = p_correo) THEN
        SET v_mensaje = 'Ya existe un usuario con este correo electrónico.';
        SET v_resultado = -4;
    ELSEIF NOT EXISTS (SELECT 1 FROM metodo_autenticacion WHERE PK_ID_METODO_AUTENTICACION = p_fk_id_metodo_autenticacion) THEN
        SET v_mensaje = 'El método de autenticación especificado no existe.';
        SET v_resultado = -5;
    ELSE
        -- Generar código de referido único (con reintentos para evitar colisiones)
        WHILE v_codigo_existe = 1 AND v_intentos < 10 DO
            SET v_codigo_nuevo = CONCAT('COD', LPAD(FLOOR(RAND() * 10000000), 7, '0'));
            SET v_codigo_existe = (SELECT COUNT(*) FROM persona WHERE CODIGO_REFERIDO = v_codigo_nuevo);
            SET v_intentos = v_intentos + 1;
        END WHILE;

        IF v_codigo_existe = 1 THEN
            SET v_mensaje = 'Error al generar código de referido. Intente nuevamente.';
            SET v_resultado = -6;
        ELSE
            -- Validar código de referido del usuario (si se proporcionó)
            IF p_codigo_referido_usuario IS NOT NULL
               AND TRIM(p_codigo_referido_usuario) != ''
               AND NOT EXISTS (SELECT 1 FROM persona WHERE CODIGO_REFERIDO = p_codigo_referido_usuario) THEN
                -- El código de referido no existe, lo ignoramos pero continuamos
                SET p_codigo_referido_usuario = NULL;
            END IF;

            -- Insertar persona
            INSERT INTO persona (
                NOMBRES,
                APELLIDOS,
                TELEFONO,
                DOCUMENTO_IDENTIDAD,
                FK_ID_TIPO_DOCUMENTO,
                CORREO,
                ESTADO,
                CODIGO_REFERIDO,
                CODIGO_REFERIDO_USUARIO
            ) VALUES (
                TRIM(p_nombre),
                TRIM(p_apellido),
                p_telefono,
                p_documento,
                p_fk_tipo_documento,
                LOWER(TRIM(p_correo)),
                1,
                v_codigo_nuevo,
                p_codigo_referido_usuario
            );

            -- Obtener el ID de persona recién insertado (CORRECTO: usar LAST_INSERT_ID)
            SET v_idpersona = LAST_INSERT_ID();

            -- Insertar usuario
            INSERT INTO usuario (
                FK_ID_PERSONA,
                FK_ID_ROL,
                NOMBRE_USUARIO,
                CONTRASENIA,
                INTENTOS_FALLIDOS,
                TIPO_AUTENTICACION,
                ESTADO
            ) VALUES (
                v_idpersona,
                3, -- Rol por defecto (usuario normal)
                LOWER(TRIM(p_correo)),
                p_contrasenia,
                0,
                p_fk_id_metodo_autenticacion,
                1
            );

            SET v_idusuario = LAST_INSERT_ID();

            -- Registrar referencia si se usó código válido
            IF p_codigo_referido_usuario IS NOT NULL THEN
                INSERT INTO referencias (FK_ID_DUENO_CODIGO, FK_ID_CLIENTE_REFERIDO, MEMBRESIA_COMPRADA, FECHA_REFERENCIA)
                SELECT
                    u.PK_ID_USUARIO,
                    v_idusuario,
                    0,
                    NOW()
                FROM persona p
                INNER JOIN usuario u ON u.FK_ID_PERSONA = p.PK_ID_PERSONA
                WHERE p.CODIGO_REFERIDO = p_codigo_referido_usuario
                LIMIT 1;
            END IF;

            COMMIT;

            SET v_resultado = 1;
            SET v_mensaje = 'Usuario creado exitosamente.';
        END IF;
    END IF;

    -- Si hubo error, hacer rollback
    IF v_resultado < 0 THEN
        ROLLBACK;
    END IF;

    -- Retornar resultado
    SELECT v_resultado AS resultado, v_mensaje AS mensaje, v_idusuario AS id_usuario;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.Duracion_oferta_flash
DELIMITER //
CREATE PROCEDURE `Duracion_oferta_flash`(
	IN `p_id_local` INT
)
BEGIN
	SELECT tipo_membresia.DURACION_OFERTA
	FROM local 
	INNER JOIN tipo_membresia ON local.FK_ID_TIPOMEMBRESIA = tipo_membresia.PK_ID_TIPO_MEMBRESIA
	WHERE local.PK_ID_LOCAL = p_id_local;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.editar_categoria
DELIMITER //
CREATE PROCEDURE `editar_categoria`(
	IN `p_id_categoria` INT,
	IN `p_nombre_categoria` VARCHAR(100),
	IN `p_estado_categoria` TINYINT,
	OUT `mensaje` VARCHAR(500),
	IN `p_imagen_categoria` VARCHAR(255),
	IN `p_banner_categoria` VARCHAR(50)
)
BEGIN   
	IF EXISTS (SELECT 1 FROM categoria WHERE PK_ID_CATEGORIA = p_id_categoria) THEN
	  -- Actualizar la categoría
		UPDATE categoria
		SET 
		   NOMBRE_CATEGORIA = p_nombre_categoria,
		   ESTADO_CATEGORIA = p_estado_categoria,
		   IMAGEN_CATEGORIA = p_imagen_categoria,
		   BANNER_CATEGORIA = p_banner_categoria
		WHERE PK_ID_CATEGORIA = p_id_categoria;
		
		SET mensaje = 'Categoría actualizada con éxito.';
	ELSE
	  	SET mensaje = 'La categoría especificada no existe.';
	END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.editar_estado
DELIMITER //
CREATE PROCEDURE `editar_estado`(
  IN `p_id_estado` INT,
  IN `p_nombre_estado` VARCHAR(50),
  OUT `mensaje` VARCHAR(500),
  OUT `resultado` INT
)
BEGIN
  SET resultado = 0;

  -- Verificar si el estado existe
  IF EXISTS (SELECT 1 FROM estado WHERE PK_ID_ESTADO = p_id_estado) THEN
    -- Verificar si el nuevo nombre ya está en uso
    IF EXISTS (SELECT 1 FROM estado WHERE NOMBRE_ESTADO = p_nombre_estado AND PK_ID_ESTADO != p_id_estado) THEN
      SET mensaje = 'El nombre del estado ya está en uso.';
    ELSE
      UPDATE estado
      SET NOMBRE_ESTADO = p_nombre_estado
      WHERE PK_ID_ESTADO = p_id_estado;

      SET resultado = 1;
      SET mensaje = 'Estado actualizado exitosamente.';
    END IF;
  ELSE
    SET mensaje = 'El estado especificado no existe.';
  END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.editar_estado_local
DELIMITER //
CREATE PROCEDURE `editar_estado_local`(
  IN `p_id_estado_local` INT,
  IN `p_nombre_estado` VARCHAR(50),
  OUT `mensaje` VARCHAR(500)
)
BEGIN
  IF EXISTS (SELECT 1 FROM estado_local WHERE PK_ID_ESTADO_LOCAL = p_id_estado_local) THEN
    -- Actualizar el estado de local
    UPDATE estado_local
    SET NOMBRE_ESTADO = p_nombre_estado
    WHERE PK_ID_ESTADO_LOCAL = p_id_estado_local;
    SET mensaje = 'Estado de local actualizado con éxito.';
  ELSE
    SET mensaje = 'El estado de local especificado no existe.';
  END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.editar_local
DELIMITER //
CREATE PROCEDURE `editar_local`(
	IN `p_id_local` INT,
	IN `p_telefono_local` VARCHAR(20),
	IN `p_nombre_local` VARCHAR(50),
	IN `p_direccion_local` VARCHAR(50),
	IN `p_localizacion_local` VARCHAR(50),
	IN `p_fotos_local` VARCHAR(50),
	IN `p_descripcion_local` VARCHAR(50),
	IN `p_banner_local` VARCHAR(100)
)
BEGIN
  IF EXISTS (SELECT 1 FROM local WHERE PK_ID_LOCAL = p_id_local) THEN
    UPDATE local
    SET 
        NOMBRE_LOCAL = p_nombre_local,
        DIRECCION_LOCAL = p_direccion_local,
        LOCALIZACION = p_localizacion_local,
        TELEFONO_LOCAL = p_telefono_local,
        FOTOS_LOCAL = p_fotos_local,
        DESCRIPCION_LOCAL = p_descripcion_local,
        BANNER_LOCAL = p_banner_local
    WHERE PK_ID_LOCAL = p_id_local;
  END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.editar_membresia
DELIMITER //
CREATE PROCEDURE `editar_membresia`(
  IN `p_id_membresia` INT,
  IN `p_fk_id_tipo_membresia` INT,
  IN `p_fecha_inicio` DATETIME,
  IN `p_fecha_fin` DATETIME,
  IN `p_descripcion` TEXT,
  IN `p_estado` TINYINT,
  OUT `mensaje` VARCHAR(500)
)
BEGIN
  IF EXISTS (SELECT 1 FROM membresia WHERE PK_ID_MEMBRESIA = p_id_membresia) THEN
    UPDATE membresia
    SET FK_ID_TIPO_MEMBRESIA = p_fk_id_tipo_membresia,
        FECHA_INICIO = p_fecha_inicio,
        FECHA_FIN = p_fecha_fin,
        DESCRIPCION = p_descripcion,
        ESTADO = p_estado
    WHERE PK_ID_MEMBRESIA = p_id_membresia;
    SET mensaje = 'Membresía actualizada con éxito.';
  ELSE
    SET mensaje = 'La membresía especificada no existe.';
  END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.editar_metodo_autenticacion
DELIMITER //
CREATE PROCEDURE `editar_metodo_autenticacion`(
  IN `p_id_metodo` INT,
  IN `p_nombre_metodo` VARCHAR(50),
  OUT `mensaje` VARCHAR(500),
  OUT `resultado` INT
)
BEGIN
  SET resultado = 0;

  -- Verificar si el método de autenticación existe
  IF EXISTS (SELECT 1 FROM metodo_autenticacion WHERE PK_ID_METODO_AUTENTICACION = p_id_metodo) THEN
    -- Verificar si el nuevo nombre ya está en uso
    IF EXISTS (SELECT 1 FROM metodo_autenticacion WHERE NOMBRE = p_nombre_metodo AND PK_ID_METODO_AUTENTICACION != p_id_metodo) THEN
      SET mensaje = 'El nombre del método de autenticación ya está en uso.';
    ELSE
      UPDATE metodo_autenticacion
      SET NOMBRE = p_nombre_metodo
      WHERE PK_ID_METODO_AUTENTICACION = p_id_metodo;

      SET resultado = 1;
      SET mensaje = 'Método de autenticación actualizado exitosamente.';
    END IF;
  ELSE
    SET mensaje = 'El método de autenticación especificado no existe.';
  END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.editar_oferta_flash
DELIMITER //
CREATE PROCEDURE `editar_oferta_flash`(
	IN `p_id_oferta` INT,
	IN `p_titulo_oferta` VARCHAR(50),
	IN `p_descripcion_oferta` TEXT
)
BEGIN
    -- Verificar si la oferta existe
    DECLARE oferta_existe INT;
    
    SELECT COUNT(*) INTO oferta_existe FROM oferta_flash WHERE ID_OFERTAFLASH = p_id_oferta;
    
    IF oferta_existe > 0 THEN
        -- Actualizar título y descripción
        UPDATE oferta_flash
        SET TITULO_OFERTA_FLASH = p_titulo_oferta,
            DESCRIPCION_OFERTA_FLASH = p_descripcion_oferta
        WHERE ID_OFERTAFLASH = p_id_oferta;
    END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.editar_opinion
DELIMITER //
CREATE PROCEDURE `editar_opinion`(
  IN `p_id_opinion` INT,
  IN `p_calificacion` TINYINT,
  IN `p_comentario` TEXT,
  OUT `mensaje` VARCHAR(500)
)
BEGIN
  IF EXISTS (SELECT 1 FROM opinion WHERE PK_ID_OPINION = p_id_opinion) THEN
    -- Actualizar la opinión
    UPDATE opinion
    SET CALIFICACION = p_calificacion,
        COMENTARIO = p_comentario
    WHERE PK_ID_OPINION = p_id_opinion;
    SET mensaje = 'Opinión actualizada con éxito.';
  ELSE
    SET mensaje = 'La opinión especificada no existe.';
  END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.editar_permiso
DELIMITER //
CREATE PROCEDURE `editar_permiso`(
  IN `p_id_permiso` INT,
  IN `p_nombre_permiso` VARCHAR(100),
  IN `p_estado_permiso` TINYINT,
  OUT `mensaje` VARCHAR(500),
  OUT `resultado` INT
)
BEGIN
  SET resultado = 0;

  -- Verificar si el permiso existe
  IF EXISTS (SELECT 1 FROM permiso WHERE PK_ID_PERMISO = p_id_permiso) THEN
    -- Verificar si ya existe otro permiso con el mismo nombre
    IF NOT EXISTS (SELECT 1 FROM permiso WHERE NOMBRE_PERMISO = p_nombre_permiso) THEN
      -- Actualizar el nombre y estado del permiso
      UPDATE permiso
      SET NOMBRE_PERMISO = p_nombre_permiso, ESTADO_PERMISO = p_estado_permiso
      WHERE PK_ID_PERMISO = p_id_permiso;

      SET resultado = 1;
      SET mensaje = 'Permiso actualizado exitosamente.';
    ELSE
      SET mensaje = 'El nombre del permiso ya está en uso.';
    END IF;
  ELSE
    SET mensaje = 'El permiso no existe en el sistema.';
  END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.editar_producto
DELIMITER //
CREATE PROCEDURE `editar_producto`(
	IN `p_id_producto` INT,
	IN `p_fk_id_sub_categoria` INT,
	IN `p_nombre_producto` VARCHAR(100),
	IN `p_imagen_url` VARCHAR(255)
)
BEGIN
  DECLARE sub_categoria_existe INT;

  -- Verificar si el producto existe
  IF EXISTS (SELECT 1 FROM producto WHERE PK_ID_PRODUCTO = p_id_producto) THEN
    -- Verificar si la subcategoría existe
    SELECT COUNT(*) INTO sub_categoria_existe FROM sub_categoria WHERE PK_ID_SUB_CATEGORIA = p_fk_id_sub_categoria;

    IF sub_categoria_existe > 0 THEN
      -- Actualizar el producto
      UPDATE producto
      SET FK_ID_SUB_CATEGORIA = p_fk_id_sub_categoria,
          NOMBRE_PRODUCTO = p_nombre_producto,
          IMAGEN_URL = p_imagen_url,
          UNIDAD = p_unidad
      WHERE PK_ID_PRODUCTO = p_id_producto;
    END IF;
  END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.editar_rol
DELIMITER //
CREATE PROCEDURE `editar_rol`(
  IN `p_id_rol` INT,
  IN `p_nombre` VARCHAR(20),
  OUT `mensaje` VARCHAR(500),
  OUT `resultado` INT
)
BEGIN
  SET resultado = 0;

  -- Verificar si el rol existe
  IF EXISTS (SELECT 1 FROM rol WHERE PK_ID_ROL = p_id_rol) THEN
    -- Verificar si ya existe otro rol con el mismo nombre
    IF NOT EXISTS (SELECT 1 FROM rol WHERE NOMBRE_ROL = p_nombre) THEN
      -- Actualizar el nombre del rol
      UPDATE rol
      SET NOMBRE_ROL = p_nombre
      WHERE PK_ID_ROL = p_id_rol;

      SET resultado = 1;
      SET mensaje = 'Rol actualizado exitosamente.';
    ELSE
      SET mensaje = 'El nombre del rol ya está en uso.';
    END IF;
  ELSE
    SET mensaje = 'El rol no existe en el sistema.';
  END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.editar_sub_categoria
DELIMITER //
CREATE PROCEDURE `editar_sub_categoria`(
	IN `p_id_sub_categoria` INT,
	IN `p_fk_id_categoria` INT,
	IN `p_nombre_sub_categoria` VARCHAR(100),
	IN `p_estado_sub_categoria` TINYINT
)
BEGIN
  DECLARE categoria_existe INT;
  DECLARE sub_categoria_existe INT;

  -- Verificar si la subcategoría existe
  IF EXISTS (SELECT 1 FROM sub_categoria WHERE PK_ID_SUB_CATEGORIA = p_id_sub_categoria) THEN
    -- Verificar si la categoría existe
    SELECT COUNT(*) INTO categoria_existe FROM categoria WHERE PK_ID_CATEGORIA = p_fk_id_categoria;

    -- Verificar si ya existe una subcategoría con el mismo nombre en la categoría
    SELECT COUNT(*) INTO sub_categoria_existe FROM sub_categoria 
    WHERE FK_ID_CATEGORIA = p_fk_id_categoria 
      AND NOMBRE_SUB_CATEGORIA = p_nombre_sub_categoria
      AND PK_ID_SUB_CATEGORIA <> p_id_sub_categoria;

    IF categoria_existe > 0 AND sub_categoria_existe = 0 THEN
      -- Actualizar la subcategoría
      UPDATE sub_categoria
      SET FK_ID_CATEGORIA = p_fk_id_categoria,
          NOMBRE_SUB_CATEGORIA = p_nombre_sub_categoria,
          ESTADO_SUB_CATEGORIA = p_estado_sub_categoria
      WHERE PK_ID_SUB_CATEGORIA = p_id_sub_categoria;
    END IF;
  END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.editar_tipo_documento
DELIMITER //
CREATE PROCEDURE `editar_tipo_documento`(
  IN `p_id_tipo_documento` INT,
  IN `p_nombre_tipo_documento` VARCHAR(50),
  OUT `mensaje` VARCHAR(500),
  OUT `resultado` INT
)
BEGIN
  SET resultado = 0;

  -- Verificar si el tipo de documento existe
  IF EXISTS (SELECT 1 FROM tipo_documento WHERE PK_ID_TIPO_DOCUMENTO = p_id_tipo_documento) THEN
    -- Verificar si el nuevo nombre ya está en uso
    IF EXISTS (SELECT 1 FROM tipo_documento WHERE NOMBRE_TIPO_DOCUMENTO = p_nombre_tipo_documento AND PK_ID_TIPO_DOCUMENTO != p_id_tipo_documento) THEN
      SET mensaje = 'El nombre del tipo de documento ya está en uso.';
    ELSE
      UPDATE tipo_documento
      SET NOMBRE_TIPO_DOCUMENTO = p_nombre_tipo_documento
      WHERE PK_ID_TIPO_DOCUMENTO = p_id_tipo_documento;

      SET resultado = 1;
      SET mensaje = 'Tipo de documento actualizado exitosamente.';
    END IF;
  ELSE
    SET mensaje = 'El tipo de documento especificado no existe.';
  END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.editar_tipo_membresia
DELIMITER //
CREATE PROCEDURE `editar_tipo_membresia`(
	IN `p_id_tipo_membresia` INT,
	IN `p_nombre` VARCHAR(50),
	IN `p_descripcion` TEXT,
	IN `p_costo` DECIMAL(10,2),
	IN `p_estado` TINYINT,
	IN `p_duracion` INT,
	IN `p_cantidad` INT,
	IN `p_costo_trimestral` DECIMAL(10,2),
	IN `p_costo_semestral` DECIMAL(10,2),
	IN `p_costo_anual` DECIMAL(10,2)
)
BEGIN
    UPDATE tipo_membresia
    SET NOMBRE = p_nombre,
        DESCRIPCION = p_descripcion,
        COSTO = p_costo,
        ESTADO = p_estado,
        DURACION_OFERTA = p_duracion,
        CANTIDAD_PRODUCTOS = p_cantidad,
        COSTO_TRIMESTRAL = p_costo_trimestral,
        COSTO_SEMESTRAL = p_costo_semestral,
        COSTO_ANUAL = p_costo_anual
    WHERE PK_ID_TIPO_MEMBRESIA = p_id_tipo_membresia;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.editar_usuario_persona
DELIMITER //
CREATE PROCEDURE `editar_usuario_persona`(
	IN `p_nombre` VARCHAR(40),
	IN `p_apellido` VARCHAR(40),
	IN `p_documento` VARCHAR(50),
	IN `p_fk_tipo_documento` INT,
	IN `p_telefono` VARCHAR(40),
	IN `p_correo` VARCHAR(50)
)
UPDATE persona
  SET 
    NOMBRES = p_nombre,
    APELLIDOS = p_apellido,
    DOCUMENTO_IDENTIDAD = p_documento,
    FK_ID_TIPO_DOCUMENTO = p_fk_tipo_documento,
    TELEFONO = p_telefono,
    CORREO = p_correo
  WHERE CORREO = p_correo//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.eliminar_categoria
DELIMITER //
CREATE PROCEDURE `eliminar_categoria`(
  IN `p_id_categoria` INT,
  OUT `mensaje` VARCHAR(500)
)
BEGIN
  IF EXISTS (SELECT 1 FROM categoria WHERE PK_ID_CATEGORIA = p_id_categoria) THEN
    -- Eliminar la categoría
    DELETE FROM categoria WHERE PK_ID_CATEGORIA = p_id_categoria;
    SET mensaje = 'Categoría eliminada con éxito.';
  ELSE
    SET mensaje = 'La categoría especificada no existe.';
  END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.eliminar_estado
DELIMITER //
CREATE PROCEDURE `eliminar_estado`(
  IN `p_id_estado` INT,
  OUT `mensaje` VARCHAR(500),
  OUT `resultado` INT
)
BEGIN
  SET resultado = 0;

  -- Verificar si el estado existe
  IF EXISTS (SELECT 1 FROM estado WHERE PK_ID_ESTADO = p_id_estado) THEN
    DELETE FROM estado WHERE PK_ID_ESTADO = p_id_estado;
    SET resultado = 1;
    SET mensaje = 'Estado eliminado exitosamente.';
  ELSE
    SET mensaje = 'El estado especificado no existe.';
  END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.eliminar_estado_local
DELIMITER //
CREATE PROCEDURE `eliminar_estado_local`(
  IN `p_id_estado_local` INT,
  OUT `mensaje` VARCHAR(500)
)
BEGIN
  IF EXISTS (SELECT 1 FROM estado_local WHERE PK_ID_ESTADO_LOCAL = p_id_estado_local) THEN
    -- Eliminar el estado de local
    DELETE FROM estado_local WHERE PK_ID_ESTADO_LOCAL = p_id_estado_local;
    SET mensaje = 'Estado de local eliminado con éxito.';
  ELSE
    SET mensaje = 'El estado de local especificado no existe.';
  END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.eliminar_local
DELIMITER //
CREATE PROCEDURE `eliminar_local`(
  IN `p_id_local` INT,
  OUT `mensaje` VARCHAR(500)
)
BEGIN
  IF EXISTS (SELECT 1 FROM local WHERE PK_ID_LOCAL = p_id_local) THEN
    -- Eliminar el local
    DELETE FROM local WHERE PK_ID_LOCAL = p_id_local;
    SET mensaje = 'Local eliminado con éxito.';
  ELSE
    SET mensaje = 'El local especificado no existe.';
  END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.eliminar_local_favorito
DELIMITER //
CREATE PROCEDURE `eliminar_local_favorito`(
  IN `p_usuario_id` INT,          -- ID del usuario
  IN `p_local_id` INT,            -- ID del local que se desea eliminar de favoritos
  OUT `mensaje` VARCHAR(500),     -- Mensaje de respuesta
  OUT `resultado` INT             -- Resultado de la operación
)
BEGIN
  -- Inicializar el resultado
  SET resultado = 0;

  -- Verificar si el usuario existe
  IF NOT EXISTS (SELECT 1 FROM usuario WHERE PK_ID_USUARIO = p_usuario_id) THEN
    SET mensaje = 'El usuario no existe.';
  
  -- Verificar si el local existe
  ELSEIF NOT EXISTS (SELECT 1 FROM local WHERE PK_ID_LOCAL = p_local_id) THEN
    SET mensaje = 'El local no existe.';
  
  -- Verificar si el local está en los favoritos del usuario
  ELSEIF NOT EXISTS (SELECT 1 FROM favoritos WHERE FK_ID_USUARIO = p_usuario_id AND FK_ID_LOCAL = p_local_id) THEN
    SET mensaje = 'El local no está en tu lista de favoritos.';
  
  ELSE
    -- Eliminar el local de favoritos
    DELETE FROM favoritos
    WHERE FK_ID_USUARIO = p_usuario_id AND FK_ID_LOCAL = p_local_id;

    -- Confirmar éxito
    SET mensaje = 'Local eliminado de favoritos con éxito.';
    SET resultado = 1;
  END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.eliminar_membresia
DELIMITER //
CREATE PROCEDURE `eliminar_membresia`(
  IN `p_id_membresia` INT,
  OUT `mensaje` VARCHAR(500)
)
BEGIN
  IF EXISTS (SELECT 1 FROM membresia WHERE PK_ID_MEMBRESIA = p_id_membresia) THEN
    DELETE FROM membresia WHERE PK_ID_MEMBRESIA = p_id_membresia;
    SET mensaje = 'Membresía eliminada con éxito.';
  ELSE
    SET mensaje = 'La membresía especificada no existe.';
  END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.eliminar_metodo_autenticacion
DELIMITER //
CREATE PROCEDURE `eliminar_metodo_autenticacion`(
  IN `p_id_metodo` INT,
  OUT `mensaje` VARCHAR(500),
  OUT `resultado` INT
)
BEGIN
  SET resultado = 0;

  -- Verificar si el método de autenticación existe
  IF EXISTS (SELECT 1 FROM metodo_autenticacion WHERE PK_ID_METODO_AUTENTICACION = p_id_metodo) THEN
    DELETE FROM metodo_autenticacion WHERE PK_ID_METODO_AUTENTICACION = p_id_metodo;
    SET resultado = 1;
    SET mensaje = 'Método de autenticación eliminado exitosamente.';
  ELSE
    SET mensaje = 'El método de autenticación especificado no existe.';
  END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.eliminar_oferta_flash
DELIMITER //
CREATE PROCEDURE `eliminar_oferta_flash`(
	IN `p_id_oferta` INT
)
BEGIN
    DELETE FROM oferta_flash WHERE ID_OFERTAFLASH = p_id_oferta;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.eliminar_opinion
DELIMITER //
CREATE PROCEDURE `eliminar_opinion`(
  IN `p_id_opinion` INT,
  OUT `mensaje` VARCHAR(500)
)
BEGIN
  IF EXISTS (SELECT 1 FROM opinion WHERE PK_ID_OPINION = p_id_opinion) THEN
    -- Eliminar la opinión
    DELETE FROM opinion WHERE PK_ID_OPINION = p_id_opinion;
    SET mensaje = 'Opinión eliminada con éxito.';
  ELSE
    SET mensaje = 'La opinión especificada no existe.';
  END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.eliminar_permiso
DELIMITER //
CREATE PROCEDURE `eliminar_permiso`(
  IN `p_id_permiso` INT,
  OUT `mensaje` VARCHAR(500),
  OUT `resultado` INT
)
BEGIN
  SET resultado = 0;

  -- Verificar si el permiso existe
  IF EXISTS (SELECT 1 FROM permiso WHERE PK_ID_PERMISO = p_id_permiso) THEN
    -- Verificar si el permiso está asignado a algún rol
    IF NOT EXISTS (SELECT 1 FROM permiso_de_rol WHERE PFK_ID_PERMISO = p_id_permiso) THEN
      -- Eliminar el permiso
      DELETE FROM permiso WHERE PK_ID_PERMISO = p_id_permiso;

      SET resultado = 1;
      SET mensaje = 'Permiso eliminado exitosamente.';
    ELSE
      SET mensaje = 'El permiso está asignado a un rol y no puede ser eliminado.';
    END IF;
  ELSE
    SET mensaje = 'El permiso no existe en el sistema.';
  END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.eliminar_producto
DELIMITER //
CREATE PROCEDURE `eliminar_producto`(
	IN `p_id_producto` INT
)
BEGIN
  IF EXISTS (SELECT 1 FROM producto WHERE PK_ID_PRODUCTO = p_id_producto) THEN
    -- Eliminar el producto
    DELETE FROM producto WHERE PK_ID_PRODUCTO = p_id_producto;
  END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.eliminar_rol
DELIMITER //
CREATE PROCEDURE `eliminar_rol`(
  IN `p_id_rol` INT,
  OUT `mensaje` VARCHAR(500),
  OUT `resultado` INT
)
BEGIN
  SET resultado = 0;

  -- Verificar si el rol existe
  IF EXISTS (SELECT 1 FROM rol WHERE PK_ID_ROL = p_id_rol) THEN
    -- Eliminar el rol
    DELETE FROM rol WHERE PK_ID_ROL = p_id_rol;

    SET resultado = 1;
    SET mensaje = 'Rol eliminado exitosamente.';
  ELSE
    SET mensaje = 'El rol no existe en el sistema.';
  END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.eliminar_sub_categoria
DELIMITER //
CREATE PROCEDURE `eliminar_sub_categoria`(
	IN `p_id_sub_categoria` INT
)
BEGIN
  -- Verificar si la subcategoría existe antes de eliminarla
  IF EXISTS (SELECT 1 FROM sub_categoria WHERE PK_ID_SUB_CATEGORIA = p_id_sub_categoria) THEN
    -- Eliminar la subcategoría
    DELETE FROM sub_categoria WHERE PK_ID_SUB_CATEGORIA = p_id_sub_categoria;
  END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.eliminar_tipo_documento
DELIMITER //
CREATE PROCEDURE `eliminar_tipo_documento`(
  IN `p_id_tipo_documento` INT,
  OUT `mensaje` VARCHAR(500),
  OUT `resultado` INT
)
BEGIN
  SET resultado = 0;

  -- Verificar si el tipo de documento existe
  IF EXISTS (SELECT 1 FROM tipo_documento WHERE PK_ID_TIPO_DOCUMENTO = p_id_tipo_documento) THEN
    DELETE FROM tipo_documento WHERE PK_ID_TIPO_DOCUMENTO = p_id_tipo_documento;
    SET resultado = 1;
    SET mensaje = 'Tipo de documento eliminado exitosamente.';
  ELSE
    SET mensaje = 'El tipo de documento especificado no existe.';
  END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.eliminar_tipo_membresia
DELIMITER //
CREATE PROCEDURE `eliminar_tipo_membresia`(
  IN `p_id_tipo_membresia` INT,
  OUT `mensaje` VARCHAR(500)
)
BEGIN
  IF EXISTS (SELECT 1 FROM tipo_membresia WHERE PK_ID_TIPO_MEMBRESIA = p_id_tipo_membresia) THEN
    -- Eliminar el tipo de membresía
    DELETE FROM tipo_membresia WHERE PK_ID_TIPO_MEMBRESIA = p_id_tipo_membresia;
    SET mensaje = 'Tipo de membresía eliminado con éxito.';
  ELSE
    SET mensaje = 'El tipo de membresía especificado no existe.';
  END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.eliminar_usuario_persona
DELIMITER //
CREATE PROCEDURE `eliminar_usuario_persona`(
  IN `p_id_persona` INT,
  OUT `mensaje` VARCHAR(500),
  OUT `resultado` INT
)
BEGIN
  SET resultado = 0;

  -- Verificar si existe el usuario
  IF EXISTS (SELECT 1 FROM usuario WHERE FK_ID_PERSONA = p_id_persona) THEN
    -- Eliminar primero de la tabla usuario
    DELETE FROM usuario WHERE FK_ID_PERSONA = p_id_persona;
    
    -- Eliminar luego de la tabla persona
    DELETE FROM persona WHERE PK_ID_PERSONA = p_id_persona;

    -- Si todo fue exitoso
    SET resultado = 1;
    SET mensaje = 'Usuario y persona eliminados exitosamente.';
  ELSE
    SET mensaje = 'El usuario no existe en el sistema.';
  END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.enviar_correo_verificacion
DELIMITER //
CREATE PROCEDURE `enviar_correo_verificacion`(
  IN `p_fk_id_usuario` INT,
  OUT `mensaje` VARCHAR(500)
)
BEGIN
  DECLARE token_verificacion VARCHAR(255);
  DECLARE fecha_expiracion DATETIME;

  -- Verificar si el usuario existe
  IF NOT EXISTS (SELECT 1 FROM usuario WHERE PK_ID_USUARIO = p_fk_id_usuario) THEN
    SET mensaje = 'Correo no encontrado.';
  ELSE
    -- Obtener la fecha de expiración del token
    SELECT FECHA_EXPIRACION_TOKEN INTO fecha_expiracion
    FROM usuario
    WHERE PK_ID_USUARIO = p_fk_id_usuario;

    -- Si el token actual no ha expirado, no generar un nuevo token
    IF fecha_expiracion IS NOT NULL AND fecha_expiracion > NOW() THEN
      SET mensaje = 'El token actual aún es válido, no se ha generado uno nuevo.';
    ELSE
      -- Generar un nuevo token único
      SET token_verificacion = UUID(); -- Generar un UUID como token
      
      -- Establecer la fecha de expiración del token (por ejemplo, en 2 minutos)
      UPDATE usuario
      SET TOKEN_RECUPERACION = token_verificacion,
          FECHA_EXPIRACION_TOKEN = NOW() + INTERVAL 2 MINUTE
      WHERE PK_ID_USUARIO = p_fk_id_usuario;

      SET mensaje = CONCAT('Se ha enviado un correo de verificación al usuario. Token: ', token_verificacion);
    END IF;
  END IF;

END//
DELIMITER ;

-- Volcando estructura para tabla abastecete.estado
CREATE TABLE IF NOT EXISTS `estado` (
  `PK_ID_ESTADO` int NOT NULL AUTO_INCREMENT,
  `NOMBRE_ESTADO` varchar(50) NOT NULL,
  PRIMARY KEY (`PK_ID_ESTADO`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Volcando datos para la tabla abastecete.estado: ~2 rows (aproximadamente)
INSERT INTO `estado` (`PK_ID_ESTADO`, `NOMBRE_ESTADO`) VALUES
	(1, 'Activo'),
	(2, 'Inactivo');

-- Volcando estructura para evento abastecete.expirar_ofertas_flash
DELIMITER //
CREATE EVENT `expirar_ofertas_flash` ON SCHEDULE EVERY 1 HOUR STARTS '2025-03-04 02:00:00' ON COMPLETION NOT PRESERVE ENABLE COMMENT 'Elimina ofertas flash cuando su tiempo haya expirado' DO UPDATE oferta_flash
SET ESTADO_OFERTA_FLASH = 2 
WHERE TIEMPO_OFERTA_FLASH <= NOW() 
AND ESTADO_OFERTA_FLASH = 1//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.generar_token_recuperacion
DELIMITER //
CREATE PROCEDURE `generar_token_recuperacion`(IN p_fk_id_usuario INT)
BEGIN
    DECLARE v_nuevo_token VARCHAR(6);
    DECLARE v_intentos_hoy INT DEFAULT 0;
    DECLARE v_resultado INT DEFAULT 0;
    DECLARE v_mensaje VARCHAR(255);

    -- Verificar si el usuario existe
    IF NOT EXISTS (SELECT 1 FROM usuario WHERE PK_ID_USUARIO = p_fk_id_usuario) THEN
        SET v_resultado = -1;
        SET v_mensaje = 'Usuario no encontrado.';
    ELSE
        -- Verificar intentos de recuperación en las últimas 24 horas
        SELECT IFNULL(INTENTOS_RECUPERACION, 0) INTO v_intentos_hoy
        FROM usuario
        WHERE PK_ID_USUARIO = p_fk_id_usuario
        AND FECHA_ULTIMO_INTENTO_RECUPERACION > NOW() - INTERVAL 24 HOUR;

        IF v_intentos_hoy >= 5 THEN
            SET v_resultado = -2;
            SET v_mensaje = 'Has excedido el límite de intentos de recuperación. Intenta en 24 horas.';
        ELSE
            -- Generar código de 6 dígitos
            SET v_nuevo_token = LPAD(FLOOR(RAND() * 1000000), 6, '0');

            -- Actualizar el token y la fecha de expiración
            UPDATE usuario
            SET TOKEN_RECUPERACION = v_nuevo_token,
                FECHA_EXPIRACION_TOKEN = NOW() + INTERVAL 5 MINUTE,
                INTENTOS_RECUPERACION = IFNULL(INTENTOS_RECUPERACION, 0) + 1,
                FECHA_ULTIMO_INTENTO_RECUPERACION = NOW()
            WHERE PK_ID_USUARIO = p_fk_id_usuario;

            SET v_resultado = 1;
            SET v_mensaje = 'Token generado exitosamente.';
        END IF;
    END IF;

    SELECT v_resultado AS resultado, v_mensaje AS mensaje;
END//
DELIMITER ;

-- Volcando estructura para evento abastecete.limpiar_bloqueos_usuario
DELIMITER //
CREATE EVENT `limpiar_bloqueos_usuario` ON SCHEDULE EVERY 5 MINUTE STARTS '2025-02-05 18:54:55' ON COMPLETION NOT PRESERVE ENABLE DO BEGIN
    UPDATE usuario
    SET ESTADO = 1,
        INTENTOS_FALLIDOS = 0,
        FECHA_BLOQUEO = NULL
    WHERE ESTADO = 0 
    AND FECHA_BLOQUEO IS NOT NULL 
    AND FECHA_BLOQUEO <= NOW();
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.listar_favoritos_usuario
DELIMITER //
CREATE PROCEDURE `listar_favoritos_usuario`(
  IN `p_usuario_id` INT,       
  OUT `mensaje` VARCHAR(500),         
  OUT `resultado` INT                 
)
BEGIN
  -- Inicializar el resultado
  SET resultado = 0;

  -- Verificar si el usuario existe
  IF NOT EXISTS (SELECT 1 FROM usuario WHERE PK_ID_USUARIO = p_usuario_id) THEN
    SET mensaje = 'El usuario no existe.';
  
  ELSE
    -- Obtener la lista de locales favoritos del usuario
    SELECT l.PK_ID_LOCAL, l.NOMBRE_LOCAL, l.DIRECCION_LOCAL, l.BARRIO_LOCAL, l.TELEFONO_LOCAL, l.FOTOS_LOCAL
    FROM favoritos f
    JOIN local l ON f.FK_ID_LOCAL = l.PK_ID_LOCAL
    WHERE f.FK_ID_USUARIO = p_usuario_id;

    -- Confirmar que la operación fue exitosa
    SET mensaje = 'Favoritos listados con éxito.';
    SET resultado = 1;
  END IF;
END//
DELIMITER ;

-- Volcando estructura para tabla abastecete.local
CREATE TABLE IF NOT EXISTS `local` (
  `PK_ID_LOCAL` int NOT NULL AUTO_INCREMENT,
  `FK_ID_PERSONA` int NOT NULL,
  `FK_ID_ESTADO_LOCAL` int NOT NULL,
  `FK_ID_TIPOMEMBRESIA` int NOT NULL,
  `NOMBRE_LOCAL` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `LOCALIZACION` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL,
  `DIRECCION_LOCAL` varchar(200) NOT NULL,
  `TELEFONO_LOCAL` varchar(20) DEFAULT NULL,
  `FOTOS_LOCAL` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
  `BANNER_LOCAL` varchar(50) DEFAULT NULL,
  `IMAGENES_LOCAL` varchar(150) DEFAULT NULL,
  `DESCRIPCION_LOCAL` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`PK_ID_LOCAL`),
  KEY `FK_local_persona` (`FK_ID_PERSONA`),
  KEY `FK_local_estado_local` (`FK_ID_ESTADO_LOCAL`),
  KEY `FK_local_membresia` (`FK_ID_TIPOMEMBRESIA`) USING BTREE,
  KEY `idx_local_persona` (`FK_ID_PERSONA`),
  KEY `idx_local_membresia` (`FK_ID_TIPOMEMBRESIA`),
  CONSTRAINT `FK_local_estado` FOREIGN KEY (`FK_ID_ESTADO_LOCAL`) REFERENCES `estado` (`PK_ID_ESTADO`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `FK_local_persona` FOREIGN KEY (`FK_ID_PERSONA`) REFERENCES `persona` (`PK_ID_PERSONA`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `FK_local_tipomembresia` FOREIGN KEY (`FK_ID_TIPOMEMBRESIA`) REFERENCES `tipo_membresia` (`PK_ID_TIPO_MEMBRESIA`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=38 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Volcando datos para la tabla abastecete.local: ~14 rows (aproximadamente)
INSERT INTO `local` (`PK_ID_LOCAL`, `FK_ID_PERSONA`, `FK_ID_ESTADO_LOCAL`, `FK_ID_TIPOMEMBRESIA`, `NOMBRE_LOCAL`, `LOCALIZACION`, `DIRECCION_LOCAL`, `TELEFONO_LOCAL`, `FOTOS_LOCAL`, `BANNER_LOCAL`, `IMAGENES_LOCAL`, `DESCRIPCION_LOCAL`) VALUES
	(1, 6, 1, 12, 'Verduras don pepe', 'Pablo VI', 'Calle 12', '3123687285', '', NULL, NULL, NULL),
	(3, 6, 1, 18, 'pepito', 'abbas', 'calle 24', '21414', '', NULL, NULL, NULL),
	(21, 12, 1, 17, 'Donas Micha', '1.6153858,-75.60423639999999', 'Florencia, Caquetá, Colombia', '78456', '', NULL, NULL, NULL),
	(22, 24, 1, 13, 'Horizons', '1.6234506622739668,-75.60409692513122', 'Florencia, Caquetá, Colombia', '3204440787', '', NULL, NULL, NULL),
	(23, 25, 1, 13, 'Horizons', '1.6234506622739668,-75.60409692513122', 'Florencia, Caquetá, Colombia', '3204440787', '683e1755f65d6c711a287e84', '683436604765d87a461b341a', NULL, 'Negocio realizado para la comunidad'),
	(24, 30, 1, 16, 'blablabla blebleble', '1.6222087305724857, -75.61084289841457', 'Florencia caqueta', '3204440787', '', NULL, NULL, NULL),
	(26, 34, 1, 16, 'Coratiendas', '1.6123400192086215,-75.60642508255614', 'Florencia, Caquetá, Colombia', '3652547', '', NULL, NULL, NULL),
	(27, 36, 1, 13, 'EdifiK', '4.3356027,-74.3683957', 'Carrera 13 # 18-26, Fusagasugá, Cundinamarca, Colombia', '3103348519', '', NULL, NULL, NULL),
	(28, 37, 1, 11, 'K-OS', '1.6234506622739668,-75.60409692513122', 'Florencia, Caquetá, Colombia', '3204440787', '6833960e9c313657f5e02550', '6834362b4765d87a461b3408', NULL, 'Pq si'),
	(29, 38, 1, 19, 'Prome', '1.6234506622739668,-75.60409692513122', 'Florencia, Caquetá, Colombia', '3204440787', '', NULL, NULL, NULL),
	(34, 40, 1, 11, 'Pan pa\' ya', '1.6046943720574707,-75.60290677490232', 'Cra. 15a #2d-115, Florencia, Caquetá', '3204440787', '6850ac1dac6622168168c557', '683436264765d87a461b3405', NULL, 'panaderia de pan'),
	(35, 50, 1, 11, 'Abastecible', '2.9339860379526495,-75.27426106872556', 'Los pinos', '3112929178', '687ee8f4ac6622168168c559', '683436264765d87a461b3405', NULL, 'Pinos'),
	(36, 51, 1, 13, 'Websen', NULL, 'Fusagasugá', '3103348519', '68a648005c46ee78254291cf', '683436264765d87a461b3405', NULL, NULL),
	(37, 36, 1, 11, 'Edifik', NULL, 'villa counrty', '3103348519', '68a674485c46ee78254291d1', NULL, NULL, NULL);

-- Volcando estructura para tabla abastecete.localcategoria
CREATE TABLE IF NOT EXISTS `localcategoria` (
  `PK_ID_LOCALCATEGORIA` int NOT NULL AUTO_INCREMENT,
  `FK_ID_LOCAL` int DEFAULT NULL,
  `FK_ID_CATEGORIA` int DEFAULT NULL,
  PRIMARY KEY (`PK_ID_LOCALCATEGORIA`),
  KEY `FK_ID_LOCAL` (`FK_ID_LOCAL`),
  KEY `FK_ID_CATEGORIA` (`FK_ID_CATEGORIA`),
  KEY `idx_localcategoria_local` (`FK_ID_LOCAL`),
  KEY `idx_localcategoria_categoria` (`FK_ID_CATEGORIA`),
  CONSTRAINT `FK1` FOREIGN KEY (`FK_ID_LOCAL`) REFERENCES `local` (`PK_ID_LOCAL`),
  CONSTRAINT `FK2` FOREIGN KEY (`FK_ID_CATEGORIA`) REFERENCES `categoria` (`PK_ID_CATEGORIA`)
) ENGINE=InnoDB AUTO_INCREMENT=38 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Volcando datos para la tabla abastecete.localcategoria: ~16 rows (aproximadamente)
INSERT INTO `localcategoria` (`PK_ID_LOCALCATEGORIA`, `FK_ID_LOCAL`, `FK_ID_CATEGORIA`) VALUES
	(22, 28, 4),
	(23, 34, 7),
	(24, 35, 7),
	(25, 35, 4),
	(26, 35, 13),
	(27, 35, 14),
	(28, 35, 5),
	(29, 36, 5),
	(30, 36, 6),
	(31, 36, 7),
	(32, 36, 10),
	(33, 36, 8),
	(34, 27, 5),
	(35, 27, 10),
	(36, 27, 12),
	(37, 27, 16);

-- Volcando estructura para procedimiento abastecete.login_usuario
DELIMITER //
CREATE PROCEDURE `login_usuario`(
    IN `p_nombre_usuario` VARCHAR(50),
    IN `p_contrasenia` MEDIUMTEXT
)
BEGIN
    DECLARE id_usuario INT DEFAULT NULL;
    DECLARE estado_usuario INT DEFAULT NULL;
    DECLARE fecha_bloqueo DATETIME DEFAULT NULL;
    DECLARE intentos_actuales INT DEFAULT 0;
    DECLARE contrasenia_correcta BOOLEAN DEFAULT FALSE;
    DECLARE id_tipo_membresia INT DEFAULT NULL;
    DECLARE usuario_inhabilitado INT DEFAULT 0;

    -- Iniciar una transacción
    START TRANSACTION;

    -- Obtener datos del usuario y bloquear la fila para evitar modificaciones simultáneas
    SELECT
        PK_ID_USUARIO,
        ESTADO,
        FECHA_BLOQUEO,
        IFNULL(INTENTOS_FALLIDOS, 0),
        (CONTRASENIA = p_contrasenia) AS contrasenia_correcta
    INTO id_usuario, estado_usuario, fecha_bloqueo, intentos_actuales, contrasenia_correcta
    FROM usuario
    WHERE NOMBRE_USUARIO = p_nombre_usuario
    FOR UPDATE;

    -- Si el usuario no existe, cancelar transacción y devolver código de error
    IF id_usuario IS NULL THEN
        ROLLBACK;
        SELECT 98 AS FK_ID_ROL, NULL AS FK_ID_PERSONA, NULL AS PK_ID_USUARIO, NULL AS FK_ID_TIPOMEMBRESIA, NULL AS NOMBRE_USUARIO;

    -- Verificar si el usuario está inhabilitado permanentemente (estado = 97)
    ELSEIF estado_usuario = 97 THEN
        ROLLBACK;
        SELECT 97 AS FK_ID_ROL, NULL AS FK_ID_PERSONA, NULL AS PK_ID_USUARIO, NULL AS FK_ID_TIPOMEMBRESIA, NULL AS NOMBRE_USUARIO;

    -- Verificar si el usuario está bloqueado temporalmente
    ELSEIF estado_usuario = 0 AND fecha_bloqueo IS NOT NULL AND fecha_bloqueo > NOW() THEN
        ROLLBACK;
        SELECT 0 AS FK_ID_ROL, NULL AS FK_ID_PERSONA, NULL AS PK_ID_USUARIO, NULL AS FK_ID_TIPOMEMBRESIA, NULL AS NOMBRE_USUARIO;

    ELSE
        -- Si la fecha de bloqueo ya pasó, desbloquear usuario
        IF estado_usuario = 0 AND (fecha_bloqueo IS NULL OR fecha_bloqueo <= NOW()) THEN
            UPDATE usuario
            SET ESTADO = 1, INTENTOS_FALLIDOS = 0, FECHA_BLOQUEO = NULL
            WHERE PK_ID_USUARIO = id_usuario;
            SET estado_usuario = 1;
            SET intentos_actuales = 0;
        END IF;

        -- Si el usuario está activo
        IF estado_usuario = 1 THEN
            IF contrasenia_correcta THEN
                -- Si la contraseña es correcta, reiniciar intentos fallidos
                UPDATE usuario
                SET INTENTOS_FALLIDOS = 0
                WHERE PK_ID_USUARIO = id_usuario;

                -- Obtener el tipo de membresía (usando LEFT JOIN para manejar usuarios sin local)
                SELECT l.FK_ID_TIPOMEMBRESIA
                INTO id_tipo_membresia
                FROM usuario u
                INNER JOIN persona p ON u.FK_ID_PERSONA = p.PK_ID_PERSONA
                LEFT JOIN local l ON l.FK_ID_PERSONA = p.PK_ID_PERSONA
                WHERE u.PK_ID_USUARIO = id_usuario
                LIMIT 1;

                COMMIT;

                -- Retornar datos del usuario
                SELECT
                    u.NOMBRE_USUARIO,
                    u.FK_ID_ROL,
                    u.FK_ID_PERSONA,
                    u.PK_ID_USUARIO,
                    IFNULL(id_tipo_membresia, 0) AS FK_ID_TIPOMEMBRESIA
                FROM usuario u
                WHERE u.PK_ID_USUARIO = id_usuario;

            ELSE
                -- Incrementar intentos fallidos
                SET intentos_actuales = intentos_actuales + 1;

                UPDATE usuario
                SET INTENTOS_FALLIDOS = intentos_actuales
                WHERE PK_ID_USUARIO = id_usuario;

                -- Si alcanza 5 intentos, bloquear usuario por 1 hora
                IF intentos_actuales >= 5 THEN
                    UPDATE usuario
                    SET ESTADO = 0, FECHA_BLOQUEO = NOW() + INTERVAL 1 HOUR
                    WHERE PK_ID_USUARIO = id_usuario;

                    COMMIT;
                    SELECT 0 AS FK_ID_ROL, NULL AS FK_ID_PERSONA, NULL AS PK_ID_USUARIO, NULL AS FK_ID_TIPOMEMBRESIA, NULL AS NOMBRE_USUARIO;
                ELSE
                    COMMIT;
                    SELECT 99 AS FK_ID_ROL, NULL AS FK_ID_PERSONA, NULL AS PK_ID_USUARIO, NULL AS FK_ID_TIPOMEMBRESIA, NULL AS NOMBRE_USUARIO;
                END IF;
            END IF;
        ELSE
            -- Estado desconocido - retornar error genérico
            ROLLBACK;
            SELECT 98 AS FK_ID_ROL, NULL AS FK_ID_PERSONA, NULL AS PK_ID_USUARIO, NULL AS FK_ID_TIPOMEMBRESIA, NULL AS NOMBRE_USUARIO;
        END IF;
    END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.login_usuario_google
DELIMITER //
CREATE PROCEDURE `login_usuario_google`(
    IN `p_correo` VARCHAR(255)
)
BEGIN
    DECLARE v_user_count INT DEFAULT 0;
    DECLARE v_estado INT DEFAULT 0;
    DECLARE v_id_usuario INT DEFAULT NULL;
    DECLARE v_fecha_bloqueo DATETIME DEFAULT NULL;

    -- Verificar si el usuario existe
    SELECT
        COUNT(*),
        MAX(PK_ID_USUARIO),
        MAX(ESTADO),
        MAX(FECHA_BLOQUEO)
    INTO v_user_count, v_id_usuario, v_estado, v_fecha_bloqueo
    FROM usuario
    WHERE NOMBRE_USUARIO = LOWER(TRIM(p_correo));

    IF v_user_count = 0 THEN
        -- Usuario no existe - retornar código para registro
        SELECT
            NULL AS PK_ID_USUARIO,
            0 AS FK_ID_ROL,
            NULL AS FK_ID_PERSONA,
            NULL AS NOMBRE_USUARIO,
            NULL AS FK_ID_TIPOMEMBRESIA,
            'NO_EXISTE' AS estado_login;

    ELSEIF v_estado = 97 THEN
        -- Usuario inhabilitado permanentemente
        SELECT
            NULL AS PK_ID_USUARIO,
            97 AS FK_ID_ROL,
            NULL AS FK_ID_PERSONA,
            NULL AS NOMBRE_USUARIO,
            NULL AS FK_ID_TIPOMEMBRESIA,
            'INHABILITADO' AS estado_login;

    ELSEIF v_estado = 0 AND v_fecha_bloqueo IS NOT NULL AND v_fecha_bloqueo > NOW() THEN
        -- Usuario bloqueado temporalmente
        SELECT
            NULL AS PK_ID_USUARIO,
            0 AS FK_ID_ROL,
            NULL AS FK_ID_PERSONA,
            NULL AS NOMBRE_USUARIO,
            NULL AS FK_ID_TIPOMEMBRESIA,
            'BLOQUEADO' AS estado_login;

    ELSE
        -- Desbloquear si el tiempo de bloqueo ya pasó
        IF v_estado = 0 AND (v_fecha_bloqueo IS NULL OR v_fecha_bloqueo <= NOW()) THEN
            UPDATE usuario
            SET ESTADO = 1,
                INTENTOS_FALLIDOS = 0,
                FECHA_BLOQUEO = NULL
            WHERE PK_ID_USUARIO = v_id_usuario;
        END IF;

        -- Login exitoso - retornar datos del usuario
        SELECT
            u.PK_ID_USUARIO,
            u.FK_ID_ROL,
            u.FK_ID_PERSONA,
            u.NOMBRE_USUARIO,
            l.FK_ID_TIPOMEMBRESIA,
            'OK' AS estado_login
        FROM usuario u
        LEFT JOIN persona p ON u.FK_ID_PERSONA = p.PK_ID_PERSONA
        LEFT JOIN local l ON l.FK_ID_PERSONA = p.PK_ID_PERSONA
        WHERE u.PK_ID_USUARIO = v_id_usuario
        LIMIT 1;

        -- Actualizar último acceso (opcional - agregar columna si se desea)
        -- UPDATE usuario SET ULTIMO_ACCESO = NOW() WHERE PK_ID_USUARIO = v_id_usuario;
    END IF;
END//
DELIMITER ;

-- Volcando estructura para tabla abastecete.logs_membresia
CREATE TABLE IF NOT EXISTS `logs_membresia` (
  `ID_LOG` int NOT NULL AUTO_INCREMENT,
  `MENSAJE` varchar(255) DEFAULT NULL,
  `FECHA_REGISTRO` datetime DEFAULT NULL,
  PRIMARY KEY (`ID_LOG`)
) ENGINE=InnoDB AUTO_INCREMENT=84 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Volcando datos para la tabla abastecete.logs_membresia: ~23 rows (aproximadamente)
INSERT INTO `logs_membresia` (`ID_LOG`, `MENSAJE`, `FECHA_REGISTRO`) VALUES
	(61, 'Se actualizaron membresías vencidas a inactivas', '2025-02-20 14:28:02'),
	(62, 'Se actualizaron membresías vencidas a inactivas', '2025-02-20 14:29:02'),
	(63, 'Se actualizaron membresías vencidas a inactivas', '2025-02-20 14:30:02'),
	(64, 'Se actualizaron membresías vencidas a inactivas', '2025-02-20 14:31:02'),
	(65, 'Se actualizaron membresías vencidas a inactivas', '2025-02-20 14:32:02'),
	(66, 'Se actualizaron membresías vencidas a inactivas', '2025-02-20 14:33:02'),
	(67, 'Se actualizaron membresías vencidas a inactivas', '2025-02-20 14:34:02'),
	(68, 'Se actualizaron membresías vencidas a inactivas', '2025-02-20 14:35:02'),
	(69, 'Se actualizaron membresías vencidas a inactivas', '2025-02-20 14:36:02'),
	(70, 'Se actualizaron membresías vencidas a inactivas', '2025-02-20 14:37:02'),
	(71, 'Se actualizaron membresías vencidas a inactivas', '2025-02-20 14:38:02'),
	(72, 'Se actualizaron membresías vencidas a inactivas', '2025-02-20 14:39:02'),
	(73, 'Se actualizaron membresías vencidas a inactivas', '2025-02-20 14:40:02'),
	(74, 'Se actualizaron membresías vencidas a inactivas', '2025-02-20 14:41:02'),
	(75, 'Se actualizaron membresías vencidas a inactivas', '2025-02-20 14:42:02'),
	(76, 'Se actualizaron membresías vencidas a inactivas', '2025-02-20 14:43:02'),
	(77, 'Se actualizaron membresías vencidas a inactivas', '2025-02-20 14:44:02'),
	(78, 'Se actualizaron membresías vencidas a inactivas', '2025-02-20 14:45:02'),
	(79, 'Se actualizaron membresías vencidas a inactivas', '2025-02-20 14:46:02'),
	(80, 'Se actualizaron membresías vencidas a inactivas', '2025-02-20 14:47:02'),
	(81, 'Se actualizaron membresías vencidas a inactivas', '2025-02-20 14:48:43'),
	(82, 'Se actualizaron membresías vencidas a inactivas', '2025-02-20 14:49:02'),
	(83, 'Se actualizaron membresías vencidas a inactivas', '2025-02-20 14:50:02');

-- Volcando estructura para tabla abastecete.membresia_local
CREATE TABLE IF NOT EXISTS `membresia_local` (
  `PK_ID_MEMBRESIA` int NOT NULL AUTO_INCREMENT,
  `FK_ID_LOCAL` int DEFAULT NULL,
  `ESTADO` int NOT NULL,
  `FECHA_INICIO` datetime NOT NULL,
  `FECHA_FIN` datetime DEFAULT NULL,
  PRIMARY KEY (`PK_ID_MEMBRESIA`),
  KEY `FK_membresia_estado` (`ESTADO`),
  KEY `FK_membresia_local` (`FK_ID_LOCAL`),
  CONSTRAINT `FK_membresia_estado` FOREIGN KEY (`ESTADO`) REFERENCES `estado` (`PK_ID_ESTADO`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `FK_membresia_local` FOREIGN KEY (`FK_ID_LOCAL`) REFERENCES `local` (`PK_ID_LOCAL`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=37 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Volcando datos para la tabla abastecete.membresia_local: ~13 rows (aproximadamente)
INSERT INTO `membresia_local` (`PK_ID_MEMBRESIA`, `FK_ID_LOCAL`, `ESTADO`, `FECHA_INICIO`, `FECHA_FIN`) VALUES
	(2, 1, 1, '2025-02-20 10:05:41', '2025-03-20 10:05:41'),
	(3, 3, 1, '2025-02-20 10:43:17', '2025-03-20 10:43:17'),
	(21, 21, 1, '2025-03-22 11:18:16', '2025-04-22 11:18:16'),
	(23, 23, 1, '2025-03-31 20:15:55', '2025-04-30 20:15:55'),
	(24, 24, 1, '2025-04-01 15:31:50', '2025-05-01 15:31:50'),
	(25, 26, 1, '2025-04-02 20:33:17', '2025-05-02 20:33:17'),
	(26, 27, 1, '2025-04-10 03:18:21', '2025-05-10 03:18:21'),
	(27, 28, 1, '2025-04-21 15:28:29', '2025-05-21 15:28:29'),
	(28, 29, 1, '2025-04-26 09:25:06', '2025-05-26 09:25:06'),
	(33, 34, 1, '2025-06-16 23:43:32', '2025-07-16 23:43:32'),
	(34, 35, 1, '2025-07-22 01:28:20', '2025-08-22 01:28:20'),
	(35, 36, 1, '2025-08-20 22:11:19', '2025-09-20 22:11:19'),
	(36, 37, 1, '2025-08-21 01:20:45', '2025-09-21 01:20:45');

-- Volcando estructura para tabla abastecete.metodo_autenticacion
CREATE TABLE IF NOT EXISTS `metodo_autenticacion` (
  `PK_ID_METODO_AUTENTICACION` int NOT NULL AUTO_INCREMENT,
  `NOMBRE` varchar(50) NOT NULL,
  PRIMARY KEY (`PK_ID_METODO_AUTENTICACION`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Volcando datos para la tabla abastecete.metodo_autenticacion: ~2 rows (aproximadamente)
INSERT INTO `metodo_autenticacion` (`PK_ID_METODO_AUTENTICACION`, `NOMBRE`) VALUES
	(1, 'Local'),
	(2, 'Google');

-- Volcando estructura para procedimiento abastecete.ObtenerLocalesAleatorios
DELIMITER //
CREATE PROCEDURE `ObtenerLocalesAleatorios`()
BEGIN
    SELECT PK_ID_LOCAL, NOMBRE_LOCAL, FOTOS_LOCAL, FK_ID_TIPOMEMBRESIA
FROM (
    (
        SELECT PK_ID_LOCAL, NOMBRE_LOCAL, FOTOS_LOCAL, FK_ID_TIPOMEMBRESIA
        FROM local
        WHERE FK_ID_TIPOMEMBRESIA IN (19, 18, 17)
        ORDER BY RAND()
        LIMIT 6
    )
    UNION ALL
    (
        SELECT PK_ID_LOCAL, NOMBRE_LOCAL, FOTOS_LOCAL, FK_ID_TIPOMEMBRESIA
        FROM local
        WHERE FK_ID_TIPOMEMBRESIA IN (16, 15, 14)
        ORDER BY RAND()
        LIMIT 6
    )
    
) AS locales_priorizados
LIMIT 6;

END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.obtener_token_recuperacion
DELIMITER //
CREATE PROCEDURE `obtener_token_recuperacion`(IN p_fk_id_usuario INT)
BEGIN
    SELECT
        TOKEN_RECUPERACION,
        FECHA_EXPIRACION_TOKEN,
        CASE
            WHEN TOKEN_RECUPERACION IS NULL THEN 0
            WHEN FECHA_EXPIRACION_TOKEN <= NOW() THEN -1
            ELSE 1
        END AS estado_token
    FROM usuario
    WHERE PK_ID_USUARIO = p_fk_id_usuario;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.obtener_usuario_por_correo
DELIMITER //
CREATE PROCEDURE `obtener_usuario_por_correo`(IN p_correo VARCHAR(255))
BEGIN
    SELECT PK_ID_USUARIO FROM usuario WHERE TRIM(NOMBRE_USUARIO) = TRIM(p_correo);
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.ofertas_actuales
DELIMITER //
CREATE PROCEDURE `ofertas_actuales`(
	IN `p_id_local` INT
)
BEGIN
	SELECT COUNT(*)
	FROM oferta_flash
	INNER JOIN `local` ON oferta_flash.FK_ID_LOCAL = `local`.PK_ID_LOCAL
	WHERE local.PK_ID_LOCAL = p_id_local AND oferta_flash.ESTADO_OFERTA_FLASH = 1;
END//
DELIMITER ;

-- Volcando estructura para tabla abastecete.oferta_flash
CREATE TABLE IF NOT EXISTS `oferta_flash` (
  `ID_OFERTAFLASH` int NOT NULL AUTO_INCREMENT,
  `TITULO_OFERTA_FLASH` varchar(50) DEFAULT NULL,
  `DESCRIPCION_OFERTA_FLASH` text,
  `ESTADO_OFERTA_FLASH` tinyint DEFAULT NULL,
  `FECHA_OFERTA_FLASH` datetime DEFAULT CURRENT_TIMESTAMP,
  `TIEMPO_OFERTA_FLASH` datetime DEFAULT NULL,
  `FK_ID_LOCAL` int DEFAULT NULL,
  `PRODUCTO_OFERTA_FLASH` varchar(50) DEFAULT NULL,
  `IMAGEN_PRODUCTO_OFERTA_FLASH` varchar(255) DEFAULT NULL,
  `PRIORIDAD_OFERTA_FLASH` tinyint DEFAULT NULL,
  PRIMARY KEY (`ID_OFERTAFLASH`),
  KEY `FK_ID_LOCAL` (`FK_ID_LOCAL`),
  CONSTRAINT `FK_ID_LOCAL` FOREIGN KEY (`FK_ID_LOCAL`) REFERENCES `local` (`PK_ID_LOCAL`)
) ENGINE=InnoDB AUTO_INCREMENT=53 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Volcando datos para la tabla abastecete.oferta_flash: ~18 rows (aproximadamente)
INSERT INTO `oferta_flash` (`ID_OFERTAFLASH`, `TITULO_OFERTA_FLASH`, `DESCRIPCION_OFERTA_FLASH`, `ESTADO_OFERTA_FLASH`, `FECHA_OFERTA_FLASH`, `TIEMPO_OFERTA_FLASH`, `FK_ID_LOCAL`, `PRODUCTO_OFERTA_FLASH`, `IMAGEN_PRODUCTO_OFERTA_FLASH`, `PRIORIDAD_OFERTA_FLASH`) VALUES
	(14, 'si', 'si', 2, '2025-03-19 00:49:27', '2025-03-20 00:49:27', 21, 'Manzanas', '/images/12a0aa8d-394e-4859-a8d9-6f5143432b4c_pan.webp', 1),
	(16, 'Ejemplo oferta flash', 'Aprovecha este descuento por tiempo limitado', 2, '2025-03-24 16:06:00', '2025-03-25 16:06:00', 21, 'Producto de ejemplo', '/images/12a0aa8d-394e-4859-a8d9-6f5143432b4c_pan.webp', 1),
	(17, '25% al por mayor', 'Aprovecha este descuento por tiempo limitado', 2, '2025-03-24 16:06:09', '2025-03-25 16:06:09', 21, 'Arroz integral', '/images/12a0aa8d-394e-4859-a8d9-6f5143432b4c_pan.webp', 2),
	(18, 'Prueba Prioridad', 'Prueba Prioridad', 2, '2025-03-24 22:53:13', '2025-03-25 22:53:13', 21, 'Arroz integral', '/images/12a0aa8d-394e-4859-a8d9-6f5143432b4c_pan.webp', 1),
	(19, 'Prueba Prioridad 2 ', 'Prueba Prioridad 2 ', 2, '2025-03-24 16:06:06', '2025-03-25 16:06:06', 21, 'Bananas', '/images/5185084c-d1a7-4384-8a90-daa3d822d9b9_congelados.webp', 2),
	(20, 'Prueba', 'Esto es una prueba de ofertas flash', 2, '2025-03-24 22:53:12', '2025-03-25 22:53:12', 21, 'Punta de anca', '', 2),
	(22, 'Prueba', 'qweqewq', 2, '2025-03-28 14:36:36', '2025-03-29 14:36:36', 21, 'Manzanas', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Frutas fresca/MANZANAS.webp', 2),
	(40, 'DESCUENTO DE 23231 %', 'PREMIUN', 2, '2025-04-11 03:45:57', '2025-04-11 09:45:57', 27, 'Tomahawk', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de res/Tomahawk.webp', 0),
	(43, 'prueba...', 'a ver?', 2, '2025-04-11 03:45:51', '2025-04-12 03:45:51', 21, 'Fresas', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Frutas fresca/Fresa.webp', 2),
	(44, 'prueba mensaje', 'prueba mensaje', 0, '2025-04-11 04:29:44', '2025-04-11 04:29:44', 21, 'Queso crema', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Quesos y cuajadas/Queso crema.webp', 2),
	(45, 'prueba mensaje 2', 'Para confirmar que se creó', 0, '2025-04-11 04:40:03', '2025-04-11 04:40:03', 21, 'Manzanas', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Frutas fresca/MANZANAS.webp', 2),
	(46, 'DESCUENTO DE 23231 %', 'NBSDBFFALKIWIFNGAE', 0, '2025-04-11 16:56:08', '2025-04-11 16:56:08', 27, 'Pan campesino', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Pan fresco y artesanal/Pan campesino.webp', 0),
	(47, 'DESCUENTO DE 23231 %', 'NBSDBFFALKIWIFNGAE', 0, '2025-04-11 16:56:10', '2025-04-11 16:56:10', 27, 'Pan campesino', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Pan fresco y artesanal/Pan campesino.webp', 0),
	(48, 'DESCUENTO DE 23231 %', 'NBSDBFFALKIWIFNGAE', 0, '2025-04-11 16:57:33', '2025-04-11 16:57:33', 27, 'Pan campesino', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Pan fresco y artesanal/Pan campesino.webp', 0),
	(49, 'DESCUENTO DE 23231 %', 'NBSDBFFALKIWIFNGAE', 0, '2025-04-11 16:58:05', '2025-04-11 16:58:05', 27, 'Pan campesino', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Pan fresco y artesanal/Pan campesino.webp', 0),
	(50, 'Prueba', 'Prueba', 2, '2025-07-22 01:54:13', '2025-07-22 07:54:13', 34, 'Pan de masa madre', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Pan fresco y artesanal/Pan de masa madre.webp', 0),
	(51, 'Prueba', 'Prueba', 0, '2025-06-16 23:49:59', '2025-06-16 23:49:59', 34, 'Pan de masa madre', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Pan fresco y artesanal/Pan de masa madre.webp', 0),
	(52, 'Descuento', 'Descuento esta semana', 2, '2025-08-02 15:40:38', '2025-08-02 21:40:38', 35, 'Baguette', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Pan fresco y artesanal/Baguette.webp', 0);

-- Volcando estructura para tabla abastecete.opinion
CREATE TABLE IF NOT EXISTS `opinion` (
  `PK_ID_OPINION` int NOT NULL AUTO_INCREMENT,
  `FK_ID_LOCAL` int NOT NULL,
  `FK_ID_PERSONA` int NOT NULL,
  `CALIFICACION` tinyint NOT NULL,
  `COMENTARIO` text,
  `FECHA_OPINION` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`PK_ID_OPINION`),
  KEY `FK_opinion_local` (`FK_ID_LOCAL`),
  KEY `FK_opinion_persona` (`FK_ID_PERSONA`),
  CONSTRAINT `FK_opinion_local` FOREIGN KEY (`FK_ID_LOCAL`) REFERENCES `local` (`PK_ID_LOCAL`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `FK_opinion_persona` FOREIGN KEY (`FK_ID_PERSONA`) REFERENCES `persona` (`PK_ID_PERSONA`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Volcando datos para la tabla abastecete.opinion: ~0 rows (aproximadamente)

-- Volcando estructura para tabla abastecete.pagos
CREATE TABLE IF NOT EXISTS `pagos` (
  `PK_ID_PAGO` int NOT NULL AUTO_INCREMENT,
  `FK_ID_USUARIO` int NOT NULL,
  `FK_ID_TIPO_MEMBRESIA` int NOT NULL,
  `NOMBRE` varchar(100) NOT NULL,
  `APELLIDOS` varchar(100) NOT NULL,
  `EMPRESA` varchar(100) NOT NULL,
  `DIRECCION` varchar(100) NOT NULL,
  `DEPARTAMENTO` varchar(100) NOT NULL,
  `MUNICIPIO` varchar(100) NOT NULL,
  `TELEFONO` varchar(100) NOT NULL,
  `CORREO` varchar(100) NOT NULL,
  `MONTO` decimal(10,2) NOT NULL,
  `ESTADO_PAGO` varchar(20) NOT NULL DEFAULT 'PENDIENTE',
  `FECHA_PAGO` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`PK_ID_PAGO`),
  KEY `FK_ID_USUARIO` (`FK_ID_USUARIO`),
  KEY `FK_ID_TIPO_MEMBRESIA` (`FK_ID_TIPO_MEMBRESIA`),
  CONSTRAINT `pagos_ibfk_1` FOREIGN KEY (`FK_ID_USUARIO`) REFERENCES `usuario` (`PK_ID_USUARIO`),
  CONSTRAINT `pagos_ibfk_2` FOREIGN KEY (`FK_ID_TIPO_MEMBRESIA`) REFERENCES `tipo_membresia` (`PK_ID_TIPO_MEMBRESIA`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Volcando datos para la tabla abastecete.pagos: ~0 rows (aproximadamente)

-- Volcando estructura para tabla abastecete.permiso
CREATE TABLE IF NOT EXISTS `permiso` (
  `PK_ID_PERMISO` int NOT NULL AUTO_INCREMENT,
  `NOMBRE_PERMISO` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL,
  `ESTADO_PERMISO` tinyint NOT NULL,
  PRIMARY KEY (`PK_ID_PERMISO`)
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Volcando datos para la tabla abastecete.permiso: ~8 rows (aproximadamente)
INSERT INTO `permiso` (`PK_ID_PERMISO`, `NOMBRE_PERMISO`, `ESTADO_PERMISO`) VALUES
	(2, 'Administrar Categorias', 1),
	(3, 'Administrar Usuarios', 1),
	(4, 'Publica tu negocio', 1),
	(5, 'Dejanos tu reseña', 1),
	(6, 'Administrar Roles', 1),
	(7, 'Administrar Membresias', 1),
	(8, 'Mi negocio', 1),
	(9, 'Administrar Banners', 1);

-- Volcando estructura para tabla abastecete.permiso_de_rol
CREATE TABLE IF NOT EXISTS `permiso_de_rol` (
  `PK_ID_PERMISO_ROL` int NOT NULL AUTO_INCREMENT,
  `PFK_ID_ROL` int NOT NULL,
  `PFK_ID_PERMISO` int NOT NULL,
  `ESTADO_PERMISO_ROL` tinyint(1) NOT NULL,
  PRIMARY KEY (`PK_ID_PERMISO_ROL`,`PFK_ID_ROL`,`PFK_ID_PERMISO`) USING BTREE,
  KEY `FK_permiso_de_rol_rol` (`PFK_ID_ROL`),
  KEY `FK_permiso_de_rol_permiso` (`PFK_ID_PERMISO`),
  CONSTRAINT `FK_permiso_de_rol_permiso` FOREIGN KEY (`PFK_ID_PERMISO`) REFERENCES `permiso` (`PK_ID_PERMISO`),
  CONSTRAINT `FK_permiso_de_rol_rol` FOREIGN KEY (`PFK_ID_ROL`) REFERENCES `rol` (`PK_ID_ROL`)
) ENGINE=InnoDB AUTO_INCREMENT=33 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Volcando datos para la tabla abastecete.permiso_de_rol: ~24 rows (aproximadamente)
INSERT INTO `permiso_de_rol` (`PK_ID_PERMISO_ROL`, `PFK_ID_ROL`, `PFK_ID_PERMISO`, `ESTADO_PERMISO_ROL`) VALUES
	(2, 1, 2, 1),
	(3, 3, 4, 1),
	(4, 3, 5, 1),
	(5, 1, 3, 1),
	(6, 1, 6, 1),
	(11, 2, 2, 0),
	(12, 2, 5, 1),
	(13, 3, 6, 0),
	(14, 2, 2, 0),
	(15, 1, 4, 0),
	(16, 1, 7, 1),
	(17, 3, 8, 0),
	(18, 1, 8, 0),
	(19, 2, 8, 1),
	(20, 1, 9, 1),
	(22, 8, 2, 1),
	(23, 8, 8, 1),
	(24, 8, 5, 1),
	(25, 8, 9, 1),
	(26, 8, 6, 1),
	(27, 8, 3, 1),
	(28, 8, 4, 1),
	(29, 8, 7, 1),
	(32, 1, 5, 0);

-- Volcando estructura para tabla abastecete.persona
CREATE TABLE IF NOT EXISTS `persona` (
  `PK_ID_PERSONA` int NOT NULL AUTO_INCREMENT,
  `NOMBRES` varchar(40) NOT NULL,
  `APELLIDOS` varchar(40) NOT NULL,
  `TELEFONO` varchar(40) DEFAULT NULL,
  `CORREO` varchar(100) NOT NULL,
  `DOCUMENTO_IDENTIDAD` int DEFAULT NULL,
  `ESTADO` tinyint NOT NULL,
  `FK_ID_TIPO_DOCUMENTO` int NOT NULL,
  `CODIGO_REFERIDO` varchar(20) DEFAULT NULL,
  `CODIGO_REFERIDO_USUARIO` varchar(20) DEFAULT NULL,
  PRIMARY KEY (`PK_ID_PERSONA`),
  KEY `FK_persona_tipo_documento` (`FK_ID_TIPO_DOCUMENTO`),
  KEY `idx_persona_correo` (`CORREO`),
  KEY `idx_persona_documento` (`DOCUMENTO_IDENTIDAD`,`FK_ID_TIPO_DOCUMENTO`),
  KEY `idx_persona_codigo_referido` (`CODIGO_REFERIDO`),
  CONSTRAINT `FK_persona_tipo_documento` FOREIGN KEY (`FK_ID_TIPO_DOCUMENTO`) REFERENCES `tipo_documento` (`PK_ID_TIPO_DOCUMENTO`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=54 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Volcando datos para la tabla abastecete.persona: ~29 rows (aproximadamente)
INSERT INTO `persona` (`PK_ID_PERSONA`, `NOMBRES`, `APELLIDOS`, `TELEFONO`, `CORREO`, `DOCUMENTO_IDENTIDAD`, `ESTADO`, `FK_ID_TIPO_DOCUMENTO`, `CODIGO_REFERIDO`, `CODIGO_REFERIDO_USUARIO`) VALUES
	(2, 'Kevin', 'Benavidez', '3123687284', 'kevin12@gmail.com', 1080360, 1, 1, 'COD659438', NULL),
	(3, 'Sebastian', 'Sierra', '312361', 'sierra@gmail.com', 1020, 1, 1, 'COD638751', NULL),
	(4, 'Sebastian', 'Medina', '312582', 'sebastian@gmail.com', 108, 1, 1, 'COD224480', NULL),
	(5, 'Yoiner', 'Molina', '236', 'yoiner@gmail.com', 1030, 1, 1, 'COD492487', NULL),
	(6, 'Andrea', 'Ledesma', '656', 'ledes@gmail.com', 128, 1, 1, 'COD436555', NULL),
	(7, 'Andres', 'Trujillo', '45', 'andres@gmail.com', 78, 1, 1, 'COD553247', NULL),
	(11, 'Matias', 'Molina', '3123687288', 'matias@gmail.com', 1080364, 1, 1, NULL, NULL),
	(12, 'Yoiner', 'Molina Hurtatiz', '3123687289', 'yoiner.mh04@gmail.com', 1080365, 1, 1, NULL, NULL),
	(23, 'johan', 'ramirez', '3204440787', 'johans.ramirez@udla.edu.co', 1006538132, 1, 1, 'COD506552', NULL),
	(24, 'Danna', 'navia', '3204440787', 'da.navia@udla.edu.co', 1007546321, 1, 1, 'COD059268', NULL),
	(25, 'gilberto', 'tocamelo', '3204440787', 'johan05182002.com@gmail.com', 0, 1, 1, 'COD054204', NULL),
	(26, 'argenis', 'murcia', '3204050072', 'armuca@gmail.com', 123456, 1, 1, 'COD615803', NULL),
	(27, 'ñoño', 'gonzales', '1245789825', 'c@gmail.com', 125478, 1, 1, 'COD745814', NULL),
	(30, 'Michael', 'Martínez', '3122453755', 'may13xd@gmail.com', 1006538101, 1, 1, 'COD607286', NULL),
	(31, 'Juan David', 'Martinez Guzman', '30000000', 'juandavidloquendero@gmail.com', 1211515611, 1, 1, 'COD250569', NULL),
	(32, 'luis', 'lopez', '3253655224', 'h@gmail.com', 1006254545, 1, 1, 'COD040979', NULL),
	(33, 'Santiago', 'CEO', '3202832456', 'osnidio@yopmail.com', 1001134567, 1, 1, 'COD500181', NULL),
	(34, 'Miguel Angel', 'Torres', '3102521245', 'l@gmail.com', 1018512777, 1, 1, 'COD856925', NULL),
	(35, 'A', 'B', '3142482732', 'sdfdsfsdf@d', 1234567890, 1, 1, 'COD889220', NULL),
	(36, 'Andres', 'Trujillo', '3103348519', 'andrestrujillo20166@gmail.com', 1018512787, 1, 1, 'COD703366', NULL),
	(37, 'Juan', 'Alvira', '3204440787', 'hola@gmail.com', 1005231123, 1, 1, 'COD144229', NULL),
	(38, 'Kevin', 'Lopez', '3204440787', 'hola1@gmail.com', 1002514478, 1, 1, 'COD786988', NULL),
	(39, 'juan', 'perez', '3204440787', 'hola2@gmail.com', 1005487123, 1, 1, 'COD664012', NULL),
	(40, 'Brayan', 'Angarita', '900586', 'hola4@gmail.com', 1006538139, 1, 2, 'COD544443', NULL),
	(49, 'Gran', 'ATEKE', '3253655225', 'atekegran@gmail.com', 1234567891, 1, 1, NULL, NULL),
	(50, 'Sebastian', 'Sierra', '3253655226', 'sebsirra13@gmail.com', 1234567892, 1, 1, NULL, NULL),
	(51, 'WEBSEN', 'WEBSEN', '3253655227', 'websencol@gmail.com', 1234567893, 1, 1, NULL, NULL),
	(52, 'Dana', 'Nabia', '3253655228', 'dananabia2000@gmail.com', 1234567894, 1, 1, NULL, NULL);

-- Volcando estructura para tabla abastecete.producto
CREATE TABLE IF NOT EXISTS `producto` (
  `PK_ID_PRODUCTO` int NOT NULL AUTO_INCREMENT,
  `FK_ID_SUB_CATEGORIA` int NOT NULL,
  `NOMBRE_PRODUCTO` varchar(100) NOT NULL,
  `IMAGEN_URL` varchar(255) DEFAULT NULL,
  `FK_ID_TIPOUNIDAD` int DEFAULT NULL,
  PRIMARY KEY (`PK_ID_PRODUCTO`),
  KEY `FK_producto_sub_categoria` (`FK_ID_SUB_CATEGORIA`),
  KEY `fk_tipounidad` (`FK_ID_TIPOUNIDAD`),
  CONSTRAINT `FK_producto_sub_categoria` FOREIGN KEY (`FK_ID_SUB_CATEGORIA`) REFERENCES `sub_categoria` (`PK_ID_SUB_CATEGORIA`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_tipounidad` FOREIGN KEY (`FK_ID_TIPOUNIDAD`) REFERENCES `tipo_unidad` (`ID_TIPOUNIDAD`)
) ENGINE=InnoDB AUTO_INCREMENT=582 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Volcando datos para la tabla abastecete.producto: ~580 rows (aproximadamente)
INSERT INTO `producto` (`PK_ID_PRODUCTO`, `FK_ID_SUB_CATEGORIA`, `NOMBRE_PRODUCTO`, `IMAGEN_URL`, `FK_ID_TIPOUNIDAD`) VALUES
	(1, 1, 'Manzanas', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Frutas frescas/Manzanas.webp', 1),
	(2, 1, 'Bananas', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Frutas frescas/Bananas.webp', 1),
	(3, 1, 'Naranjas', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Frutas frescas/Naranjas.webp', 1),
	(4, 1, 'Peras', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Frutas frescas/Peras.webp', 1),
	(5, 1, 'Uvas', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Frutas frescas/Uvas.webp', 1),
	(6, 1, 'Mangos', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Frutas frescas/Mangos.webp', 1),
	(7, 1, 'Papayas', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Frutas frescas/Papayas.webp', 1),
	(8, 1, 'Piñas', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Frutas frescas/Piñas.webp', 1),
	(9, 1, 'Fresas', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Frutas frescas/Fresas.webp', 1),
	(10, 1, 'Kiwis', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Frutas frescas/Kiwis.webp', 1),
	(11, 1, 'Limones', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Frutas frescas/Limones.webp', 1),
	(12, 1, 'Mandarinas', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Frutas frescas/Mandarinas.webp', 1),
	(13, 1, 'Cerezas', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Frutas frescas/Cerezas.webp', 1),
	(14, 1, 'Melones', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Frutas frescas/Melones.webp', 1),
	(15, 1, 'Sandías', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Frutas frescas/Sandías.webp', 1),
	(16, 1, 'Duraznos', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Frutas frescas/Duraznos.webp', 1),
	(17, 1, 'Ciruelas', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Frutas frescas/Ciruelas.webp', 1),
	(18, 1, 'Aguacates', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Frutas frescas/Aguacates.webp', 1),
	(19, 1, 'Granadillas', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Frutas frescas/Granadillas.webp', 1),
	(21, 2, 'Tomates', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Verduras frescas/Tomates.webp', 1),
	(22, 2, 'Lechugas', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Verduras frescas/Lechugas.webp', 1),
	(23, 2, 'Zanahorias', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Verduras frescas/Zanahorias.webp', 1),
	(24, 2, 'Cebollas', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Verduras frescas/Cebollas.webp', 1),
	(25, 2, 'Pimientos', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Verduras frescas/Pimientos.webp', 1),
	(26, 2, 'Pepinos', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Verduras frescas/Pepinos.webp', 1),
	(27, 2, 'Espinacas', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Verduras frescas/Espinacas.webp', 1),
	(29, 2, 'Coliflores', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Verduras frescas/Coliflores.webp', 1),
	(30, 2, 'Berenjenas', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Verduras frescas/Berenjenas.webp', 1),
	(31, 2, 'Calabacines', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Verduras frescas/Calabacines.webp', 1),
	(32, 2, 'Ajos', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Verduras frescas/Ajos.webp', 1),
	(33, 2, 'Apios', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Verduras frescas/Apios.webp', 1),
	(34, 2, 'Repollo', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Verduras frescas/Repollo.webp', 1),
	(35, 2, 'Remolachas', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Verduras frescas/Remolachas.webp', 1),
	(36, 2, 'Rábanos', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Verduras frescas/Rábanos.webp', 1),
	(37, 2, 'Guisantes', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Verduras frescas/Guisantes.webp', 1),
	(38, 2, 'Habichuelas', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Verduras frescas/Habichuelas.webp', 1),
	(39, 2, 'Champiñones', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Verduras frescas/Champiñones.webp', 1),
	(40, 2, 'Alcachofas', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Verduras frescas/Alcachofas.webp', 1),
	(41, 3, 'Cilantro', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Hierbas y especias frescas/Cilantro.webp', 1),
	(42, 3, 'Perejil', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Hierbas y especias frescas/Perejil.webp', 1),
	(43, 3, 'Albahaca', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Hierbas y especias frescas/Albahaca.webp', 1),
	(44, 3, 'Hierbabuena', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Hierbas y especias frescas/Hierbabuena.webp', 1),
	(45, 3, 'Orégano', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Hierbas y especias frescas/Orégano.webp', 1),
	(46, 3, 'Tomillo', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Hierbas y especias frescas/Tomillo.webp', 1),
	(47, 3, 'Romero', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Hierbas y especias frescas/Romero.webp', 1),
	(48, 3, 'Laurel', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Hierbas y especias frescas/Laurel.webp', 1),
	(49, 3, 'Menta', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Hierbas y especias frescas/Menta.webp', 1),
	(50, 3, 'Estragón', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Hierbas y especias frescas/Estragón.webp', 1),
	(51, 3, 'Salvia', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Hierbas y especias frescas/Salvia.webp', 1),
	(53, 3, 'Cebollín', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Hierbas y especias frescas/Cebollín.webp', 1),
	(54, 3, 'Ajedrea', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Hierbas y especias frescas/Ajedrea.webp', 1),
	(55, 3, 'Mejorana', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Hierbas y especias frescas/Mejorana.webp', 1),
	(56, 3, 'Hinojo', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Hierbas y especias frescas/Hinojo.webp', 1),
	(57, 3, 'Lemongrass', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Hierbas y especias frescas/Lemongrass.webp', 1),
	(58, 3, 'Cúrcuma fresca', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Hierbas y especias frescas/Cúrcuma fresca.webp', 1),
	(59, 3, 'Jengibre fresco', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Hierbas y especias frescas/Jengibre fresco.webp', 1),
	(62, 4, 'Yucas', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Tubérculos y raíces/Yucas.webp', 1),
	(65, 4, 'Arracachas', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Tubérculos y raíces/Arracachas.webp', 1),
	(66, 4, 'Rábano', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Tubérculos y raíces/Rábano.webp', 1),
	(67, 4, 'Jengibre', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Tubérculos y raíces/Jengibre.webp', 1),
	(68, 4, 'Cúrcuma', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Tubérculos y raíces/Cúrcuma.webp', 1),
	(69, 4, 'Zanahorias', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Tubérculos y raíces/Zanahorias.webp', 1),
	(70, 4, 'Remolachas', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Tubérculos y raíces/Remolachas.webp', 1),
	(71, 4, 'Yacón', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Tubérculos y raíces/Yacón.webp', 1),
	(72, 4, 'Malanga', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Tubérculos y raíces/Malanga.webp', 1),
	(73, 4, 'Ocas', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Tubérculos y raíces/Ocas.webp', 1),
	(74, 4, 'Mashuas', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Tubérculos y raíces/Mashuas.webp', 1),
	(75, 4, 'Achiras', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Tubérculos y raíces/Achiras.webp', 1),
	(76, 4, 'Chirivías', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Tubérculos y raíces/Chirivías.webp', 1),
	(77, 4, 'Topinambur', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Tubérculos y raíces/Topinambur.webp', 1),
	(78, 4, 'Taro', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Tubérculos y raíces/Taro.webp', 1),
	(79, 4, 'Celeriaco', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Tubérculos y raíces/Celeriaco.webp', 1),
	(80, 4, 'Jícama', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Tubérculos y raíces/Jícama.webp', 1),
	(81, 5, 'Lomo de res', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de res/Lomo de res.webp', 1),
	(82, 5, 'Solomo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de res/Solomo.webp', 1),
	(83, 5, 'Punta de anca', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de res/Punta de anca.webp', 1),
	(84, 5, 'Costilla de res', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de res/Costilla de res.webp', 1),
	(85, 5, 'Carne molida', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de res/Carne molida.webp', 1),
	(86, 5, 'Bistec', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de res/Bistec.webp', 1),
	(87, 5, 'Hígado de res', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de res/Hígado de res.webp', 1),
	(88, 5, 'Rabo de res', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de res/Rabo de res.webp', 1),
	(89, 5, 'Morrillo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de res/Morrillo.webp', 1),
	(90, 5, 'Chatas', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de res/Chatas.webp', 1),
	(91, 5, 'Paletero', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de res/Paletero.webp', 1),
	(92, 5, 'Posta', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de res/Posta.webp', 1),
	(93, 5, 'Muchacho', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de res/Muchacho.webp', 1),
	(94, 5, 'Pecho de res', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de res/Pecho de res.webp', 1),
	(95, 5, 'Entrecot', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de res/Entrecot.webp', 1),
	(96, 5, 'T-bone', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de res/T-bone.webp', 1),
	(97, 5, 'Tomahawk', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de res/Tomahawk.webp', 1),
	(98, 5, 'Asado de tira', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de res/Asado de tira.webp', 1),
	(99, 5, 'Colita de cuadril', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de res/Colita de cuadril.webp', 1),
	(100, 5, 'Punta trasera', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de res/Punta trasera.webp', 1),
	(101, 6, 'Chuletas de cerdo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de cerdo/Chuletas de cerdo.webp', 1),
	(102, 6, 'Costillas de cerdo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de cerdo/Costillas de cerdo.webp', 1),
	(103, 6, 'Lomo de cerdo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de cerdo/Lomo de cerdo.webp', 1),
	(104, 6, 'Pernil de cerdo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de cerdo/Pernil de cerdo.webp', 1),
	(105, 6, 'Tocino', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de cerdo/Tocino.webp', 1),
	(106, 6, 'Chicharrón', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de cerdo/Chicharrón.webp', 1),
	(107, 6, 'Jamón', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de cerdo/Jamón.webp', 1),
	(108, 6, 'Salchichas', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de cerdo/Salchichas.webp', 1),
	(109, 6, 'Morcilla', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de cerdo/Morcilla.webp', 1),
	(110, 6, 'Chorizo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de cerdo/Chorizo.webp', 1),
	(111, 6, 'Panceta', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de cerdo/Panceta.webp', 1),
	(112, 6, 'Bondiola', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de cerdo/Bondiola.webp', 1),
	(113, 6, 'Cabeza de lomo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de cerdo/Cabeza de lomo.webp', 1),
	(114, 6, 'Paleta de cerdo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de cerdo/Paleta de cerdo.webp', 1),
	(115, 6, 'Pata de cerdo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de cerdo/Pata de cerdo.webp', 1),
	(116, 6, 'Carrilleras de cerdo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de cerdo/Carrilleras de cerdo.webp', 1),
	(117, 6, 'Secreto ibérico', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de cerdo/Secreto ibérico.webp', 1),
	(118, 6, 'Pluma ibérica', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de cerdo/Pluma ibérica.webp', 1),
	(119, 6, 'Abanico de cerdo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de cerdo/Abanico de cerdo.webp', 1),
	(120, 6, 'Lagarto de cerdo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de cerdo/Lagarto de cerdo.webp', 1),
	(121, 7, 'Pechuga de pollo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de pollo/Pechuga de pollo.webp', 1),
	(122, 7, 'Muslos de pollo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de pollo/Muslos de pollo.webp', 1),
	(123, 7, 'Alitas de pollo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de pollo/Alitas de pollo.webp', 1),
	(124, 7, 'Piernas de pollo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de pollo/Piernas de pollo.webp', 1),
	(125, 7, 'Contramuslos de pollo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de pollo/Contramuslos de pollo.webp', 1),
	(126, 7, 'Pollo entero', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de pollo/Pollo entero.webp', 1),
	(127, 7, 'Filete de pechuga', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de pollo/Filete de pechuga.webp', 1),
	(128, 7, 'Mollejas de pollo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de pollo/Mollejas de pollo.webp', 1),
	(129, 7, 'Hígados de pollo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de pollo/Hígados de pollo.webp', 1),
	(130, 7, 'Corazones de pollo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de pollo/Corazones de pollo.webp', 1),
	(131, 7, 'Cuartos traseros', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de pollo/Cuartos traseros.webp', 1),
	(132, 7, 'Cuartos delanteros', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de pollo/Cuartos delanteros.webp', 1),
	(133, 7, 'Carcasa de pollo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de pollo/Carcasa de pollo.webp', 1),
	(134, 7, 'Nuggets de pollo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de pollo/Nuggets de pollo.webp', 1),
	(135, 7, 'Tiras de pollo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de pollo/Tiras de pollo.webp', 1),
	(136, 7, 'Hamburguesas de pollo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de pollo/Hamburguesas de pollo.webp', 1),
	(137, 7, 'Salchichas de pollo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de pollo/Salchichas de pollo.webp', 1),
	(138, 7, 'Chorizo de pollo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de pollo/Chorizo de pollo.webp', 1),
	(139, 7, 'Brochetas de pollo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de pollo/Brochetas de pollo.webp', 1),
	(140, 7, 'Pollo desmechado', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de pollo/Pollo desmechado.webp', 1),
	(141, 8, 'Salmón', '/images/PRODUCTOS ABASTECETE/Proteínas/Pescados y mariscos/Salmón.webp', 1),
	(142, 8, 'Tilapia', '/images/PRODUCTOS ABASTECETE/Proteínas/Pescados y mariscos/Tilapia.webp', 1),
	(143, 8, 'Trucha', '/images/PRODUCTOS ABASTECETE/Proteínas/Pescados y mariscos/Trucha.webp', 1),
	(144, 8, 'Bagre', '/images/PRODUCTOS ABASTECETE/Proteínas/Pescados y mariscos/Bagre.webp', 1),
	(145, 8, 'Atún', '/images/PRODUCTOS ABASTECETE/Proteínas/Pescados y mariscos/Atún.webp', 1),
	(146, 8, 'Sardinas', '/images/PRODUCTOS ABASTECETE/Proteínas/Pescados y mariscos/Sardinas.webp', 1),
	(147, 8, 'Camarones', '/images/PRODUCTOS ABASTECETE/Proteínas/Pescados y mariscos/Camarones.webp', 1),
	(149, 8, 'Calamares', '/images/PRODUCTOS ABASTECETE/Proteínas/Pescados y mariscos/Calamares.webp', 1),
	(150, 8, 'Pulpo', '/images/PRODUCTOS ABASTECETE/Proteínas/Pescados y mariscos/Pulpo.webp', 1),
	(151, 8, 'Mejillones', '/images/PRODUCTOS ABASTECETE/Proteínas/Pescados y mariscos/Mejillones.webp', 1),
	(152, 8, 'Almejas', '/images/PRODUCTOS ABASTECETE/Proteínas/Pescados y mariscos/Almejas.webp', 1),
	(153, 8, 'Ostras', '/images/PRODUCTOS ABASTECETE/Proteínas/Pescados y mariscos/Ostras.webp', 1),
	(154, 8, 'Cangrejo', '/images/PRODUCTOS ABASTECETE/Proteínas/Pescados y mariscos/Cangrejo.webp', 1),
	(155, 8, 'Langosta', '/images/PRODUCTOS ABASTECETE/Proteínas/Pescados y mariscos/Langosta.webp', 1),
	(156, 8, 'Merluza', '/images/PRODUCTOS ABASTECETE/Proteínas/Pescados y mariscos/Merluza.webp', 1),
	(157, 8, 'Bacalao', '/images/PRODUCTOS ABASTECETE/Proteínas/Pescados y mariscos/Bacalao.webp', 1),
	(158, 8, 'Róbalo', '/images/PRODUCTOS ABASTECETE/Proteínas/Pescados y mariscos/Róbalo.webp', 1),
	(159, 8, 'Pargo', '/images/PRODUCTOS ABASTECETE/Proteínas/Pescados y mariscos/Pargo.webp', 1),
	(160, 8, 'Mojarra', '/images/PRODUCTOS ABASTECETE/Proteínas/Pescados y mariscos/Mojarra.webp', 1),
	(161, 9, 'Jamón de cerdo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes procesadas/Jamón de cerdo.webp', 1),
	(162, 9, 'Jamón de pavo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes procesadas/Jamón de pavo.webp', 1),
	(163, 9, 'Salchichas tipo Frankfurt', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes procesadas/Salchichas tipo Frankfurt.webp', 1),
	(164, 9, 'Chorizo procesado', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes procesadas/Chorizo procesado.webp', 1),
	(165, 9, 'Morcilla procesada', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes procesadas/Morcilla procesada.webp', 1),
	(166, 9, 'Tocineta', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes procesadas/Tocineta.webp', 1),
	(167, 9, 'Salami', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes procesadas/Salami.webp', 1),
	(168, 9, 'Mortadela', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes procesadas/Mortadela.webp', 1),
	(169, 9, 'Pepperoni', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes procesadas/Pepperoni.webp', 1),
	(170, 9, 'Pastrami', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes procesadas/Pastrami.webp', 1),
	(171, 9, 'Lomo embuchado', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes procesadas/Lomo embuchado.webp', 1),
	(172, 9, 'Cecina', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes procesadas/Cecina.webp', 1),
	(173, 9, 'Prosciutto', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes procesadas/Prosciutto.webp', 1),
	(174, 9, 'Bresaola', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes procesadas/Bresaola.webp', 1),
	(175, 9, 'Lomo canadiense', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes procesadas/Lomo canadiense.webp', 1),
	(176, 9, 'Fuet', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes procesadas/Fuet.webp', 1),
	(177, 9, 'Sobrasada', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes procesadas/Sobrasada.webp', 1),
	(179, 9, 'Butifarra', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes procesadas/Butifarra.webp', 1),
	(180, 9, 'Salchichón', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes procesadas/Salchichón.webp', 1),
	(181, 10, 'Leche entera', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Leche y derivado/Leche entera.webp', 2),
	(182, 10, 'Leche descremada', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Leche y derivado/Leche descremada.webp', 2),
	(183, 10, 'Leche semidescremada', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Leche y derivado/Leche semidescremada.webp', 2),
	(184, 10, 'Leche deslactosada', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Leche y derivado/Leche deslactosada.webp', 2),
	(185, 10, 'Leche en polvo', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Leche y derivado/Leche en polvo.webp', 2),
	(186, 10, 'Leche condensada', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Leche y derivado/Leche condensada.webp', 2),
	(187, 10, 'Leche evaporada', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Leche y derivado/Leche evaporada.webp', 2),
	(188, 10, 'Crema de leche', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Leche y derivados/Crema de leche.webp', 2),
	(189, 10, 'Suero costeño', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Leche y derivado/Suero costeño.webp', 2),
	(190, 10, 'Kéfir', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Leche y derivado/Kéfir.webp', 2),
	(191, 10, 'Leche de cabra', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Leche y derivado/Leche de cabra.webp', 2),
	(192, 10, 'Leche de búfala', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Leche y derivado/Leche de búfala.webp', 2),
	(193, 10, 'Leche saborizada', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Leche y derivado/Leche saborizada.webp', 2),
	(194, 11, 'Queso campesino', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Quesos y cuajadas/Queso campesino.webp', 1),
	(195, 11, 'Queso costeño', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Quesos y cuajadas/Queso costeño.webp', 1),
	(196, 11, 'Queso doble crema', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Quesos y cuajadas/Queso doble crema.webp', 1),
	(197, 11, 'Queso mozzarella', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Quesos y cuajadas/Queso mozzarella.webp', 1),
	(198, 11, 'Queso parmesano', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Quesos y cuajadas/Queso parmesano.webp', 1),
	(199, 11, 'Queso cheddar', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Quesos y cuajadas/Queso cheddar.webp', 1),
	(200, 11, 'Queso feta', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Quesos y cuajadas/Queso feta.webp', 1),
	(201, 11, 'Queso azul', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Quesos y cuajadas/Queso azul.webp', 1),
	(202, 11, 'Cuajada', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Quesos y cuajadas/Cuajada.webp', 1),
	(203, 11, 'Queso ricotta', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Quesos y cuajadas/Queso ricotta.webp', 1),
	(204, 11, 'Queso crema', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Quesos y cuajadas/Queso crema.webp', 1),
	(205, 11, 'Queso gouda', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Quesos y cuajadas/Queso gouda.webp', 1),
	(206, 11, 'Queso suizo', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Quesos y cuajadas/Queso suizo.webp', 1),
	(207, 11, 'Queso brie', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Quesos y cuajadas/Queso brie.webp', 1),
	(208, 12, 'Yogurt natural', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Yogurt y bebidas lácteas/Yogurt natural.webp', 2),
	(209, 12, 'Yogurt griego', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Yogurt y bebidas lácteas/Yogurt griego.webp', 2),
	(210, 12, 'Yogurt de frutas', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Yogurt y bebidas lácteas/Yogurt de frutas.webp', 2),
	(211, 12, 'Yogurt bebible', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Yogurt y bebidas lácteas/Yogurt bebible.webp', 2),
	(212, 12, 'Yogurt deslactosado', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Yogurt y bebidas lácteas/Yogurt deslactosado.webp', 2),
	(213, 12, 'Bebidas probióticas', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Yogurt y bebidas lácteas/Bebidas probióticas.webp', 2),
	(214, 12, 'Yogurt con granola', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Yogurt y bebidas lácteas/Yogurt con granola.webp', 2),
	(215, 13, 'Mantequilla sin sal', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Mantequilla y margarinas/Mantequilla sin sal.webp', 3),
	(216, 13, 'Mantequilla con sal', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Mantequilla y margarinas/Mantequilla con sal.webp', 3),
	(217, 13, 'Margarina vegetal', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Mantequilla y margarinas/Margarina vegetal.webp', 3),
	(218, 13, 'Margarina con sabor a mantequilla', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Mantequilla y margarinas/Margarina con sabor a mantequilla.webp', 3),
	(219, 14, 'Huevos blancos', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Huevos/Huevos blancos.webp', 3),
	(220, 14, 'Huevos rojos', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Huevos/Huevos rojos.webp', 3),
	(221, 14, 'Huevos de codorniz', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Huevos/Huevos de codorniz.webp', 3),
	(222, 14, 'Huevos orgánicos', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Huevos/Huevos orgánicos.webp', 3),
	(223, 14, 'Huevos enriquecidos con omega 3', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Huevos/Huevos enriquecidos con omega 3.webp', 3),
	(224, 15, 'Pan de masa madre', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Pan fresco y artesanal/Pan de masa madre.webp', 3),
	(225, 15, 'Pan francés', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Pan fresco y artesanal/Pan francés.webp', 3),
	(226, 15, 'Pan campesino', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Pan fresco y artesanal/Pan campesino.webp', 3),
	(227, 15, 'Baguette', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Pan fresco y artesanal/Baguette.webp', 3),
	(228, 15, 'Pan ciabatta', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Pan fresco y artesanal/Pan ciabatta.webp', 3),
	(229, 15, 'Pan brioche', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Pan fresco y artesanal/Pan brioche.webp', 3),
	(230, 15, 'Pan integral', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Pan fresco y artesanal/Pan integral.webp', 3),
	(231, 15, 'Pan de queso', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Pan fresco y artesanal/Pan de queso.webp', 3),
	(232, 15, 'Pan de coco', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Pan fresco y artesanal/Pan de coco.webp', 3),
	(233, 15, 'Pan de yuca', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Pan fresco y artesanal/Pan de yuca.webp', 3),
	(234, 16, 'Pan blanco empacado', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Panadería empacada/Pan blanco empacado.webp', 3),
	(235, 16, 'Pan integral empacado', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Panadería empacada/Pan integral empacado.webp', 3),
	(236, 16, 'Pan tostado', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Panadería empacada/Pan tostado.webp', 3),
	(237, 16, 'Pan de molde', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Panadería empacada/Pan de molde.webp', 3),
	(238, 16, 'Pan para hamburguesa', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Panadería empacada/Pan para hamburguesa.webp', 3),
	(239, 16, 'Pan para perro caliente', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Panadería empacada/Pan para perro caliente.webp', 3),
	(240, 16, 'Pan pita', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Panadería empacada/Pan pita.webp', 3),
	(241, 17, 'Torta de chocolate', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Tortas y postres frescos/Torta de chocolate.webp', 3),
	(242, 17, 'Torta de zanahoria', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Tortas y postres frescos/Torta de zanahoria.webp', 3),
	(243, 17, 'Tres leches', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Tortas y postres frescos/Tres leches.webp', 3),
	(244, 17, 'Cheesecake', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Tortas y postres frescos/Cheesecake.webp', 3),
	(245, 17, 'Flan', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Tortas y postres frescos/Flan.webp', 3),
	(246, 17, 'Pionono', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Tortas y postres frescos/Pionono.webp', 3),
	(247, 17, 'Tiramisú', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Tortas y postres frescos/Tiramisú.webp', 3),
	(248, 17, 'Postres individuales', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Tortas y postres frescos/Postres individuales.webp', 3),
	(249, 17, 'Volcán de chocolate', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Tortas y postres frescos/Volcán de chocolate.webp', 3),
	(250, 18, 'Galletas de chocolate', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Repostería industrial/Galletas de chocolate.webp', 3),
	(251, 18, 'Galletas de avena', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Repostería industrial/Galletas de avena.webp', 3),
	(252, 18, 'Brownies', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Repostería industrial/Brownies.webp', 3),
	(253, 18, 'Muffins', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Repostería industrial/Muffins.webp', 3),
	(254, 18, 'Cupcakes', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Repostería industrial/Cupcakes.webp', 3),
	(255, 18, 'Alfajores', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Repostería industrial/Alfajores.webp', 3),
	(256, 18, 'Macarons', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Repostería industrial/Macarons.webp', 3),
	(257, 19, 'Arroz blanco', '/images/PRODUCTOS ABASTECETE/Despensa/Arroz, granos y legumbres/Arroz blanco.webp', 1),
	(258, 19, 'Arroz integral', '/images/PRODUCTOS ABASTECETE/Despensa/Arroz, granos y legumbres/Arroz integral.webp', 1),
	(259, 19, 'Arroz para sushi', '/images/PRODUCTOS ABASTECETE/Despensa/Arroz, granos y legumbres/Arroz para sushi.webp', 1),
	(260, 19, 'Arroz basmati', '/images/PRODUCTOS ABASTECETE/Despensa/Arroz, granos y legumbres/Arroz basmati.webp', 1),
	(261, 19, 'Arroz jazmín', '/images/PRODUCTOS ABASTECETE/Despensa/Arroz, granos y legumbres/Arroz jazmín.webp', 1),
	(262, 19, 'Frijoles rojos', '/images/PRODUCTOS ABASTECETE/Despensa/Arroz, granos y legumbres/Frijoles rojos.webp', 1),
	(263, 19, 'Frijoles negros', '/images/PRODUCTOS ABASTECETE/Despensa/Arroz, granos y legumbres/Frijoles negros.webp', 1),
	(264, 19, 'Lentejas', '/images/PRODUCTOS ABASTECETE/Despensa/Arroz, granos y legumbres/Lentejas.webp', 1),
	(265, 19, 'Garbanzo', '/images/PRODUCTOS ABASTECETE/Despensa/Arroz, granos y legumbres/Garbanzo.webp', 1),
	(266, 19, 'Arveja seca', '/images/PRODUCTOS ABASTECETE/Despensa/Arroz, granos y legumbres/Arveja seca.webp', 1),
	(267, 20, 'Espagueti', '/images/PRODUCTOS ABASTECETE/Despensa/Pastas y harinas/Espagueti.webp', 3),
	(268, 20, 'Fettuccine', '/images/PRODUCTOS ABASTECETE/Despensa/Pastas y harinas/Fettuccine.webp', 3),
	(269, 20, 'Macarrones', '/images/PRODUCTOS ABASTECETE/Despensa/Pastas y harinas/Macarrones.webp', 3),
	(270, 20, 'Lasaña', '/images/PRODUCTOS ABASTECETE/Despensa/Pastas y harinas/Lasaña.webp', 3),
	(271, 20, 'Cavatappi', '/images/PRODUCTOS ABASTECETE/Despensa/Pastas y harinas/Cavatappi.webp', 3),
	(272, 20, 'Harina de trigo', '/images/PRODUCTOS ABASTECETE/Despensa/Pastas y harinas/Harina de trigo.webp', 3),
	(273, 20, 'Harina de maíz', '/images/PRODUCTOS ABASTECETE/Despensa/Pastas y harinas/Harina de maíz.webp', 3),
	(274, 20, 'Harina de avena', '/images/PRODUCTOS ABASTECETE/Despensa/Pastas y harinas/Harina de avena.webp', 3),
	(275, 20, 'Harina para pizza', '/images/PRODUCTOS ABASTECETE/Despensa/Pastas y harinas/Harina para pizza.webp', 3),
	(276, 21, 'Aceite de girasol', '/images/PRODUCTOS ABASTECETE/Despensa/Aceites y vinagres/Aceite de girasol.webp', 2),
	(277, 21, 'Aceite de oliva extra virgen', '/images/PRODUCTOS ABASTECETE/Despensa/Aceites y vinagres/Aceite de oliva extra virgen.webp', 2),
	(278, 21, 'Aceite de coco', '/images/PRODUCTOS ABASTECETE/Despensa/Aceites y vinagres/Aceite de coco.webp', 2),
	(279, 21, 'Aceite de canola', '/images/PRODUCTOS ABASTECETE/Despensa/Aceites y vinagres/Aceite de canola.webp', 2),
	(280, 21, 'Vinagre blanco', '/images/PRODUCTOS ABASTECETE/Despensa/Aceites y vinagres/Vinagre blanco.webp', 2),
	(281, 21, 'Vinagre balsámico', '/images/PRODUCTOS ABASTECETE/Despensa/Aceites y vinagres/Vinagre balsámico.webp', 2),
	(282, 21, 'Vinagre de manzana', '/images/PRODUCTOS ABASTECETE/Despensa/Aceites y vinagres/Vinagre de manzana.webp', 2),
	(283, 22, 'Salsa de tomate', '/images/PRODUCTOS ABASTECETE/Despensa/Salsas y condimentos/Salsa de tomate.webp', 3),
	(284, 22, 'Mayonesa', '/images/PRODUCTOS ABASTECETE/Despensa/Salsas y condimentos/Mayonesa.webp', 3),
	(285, 22, 'Mostaza', '/images/PRODUCTOS ABASTECETE/Despensa/Salsas y condimentos/Mostaza.webp', 3),
	(286, 22, 'Salsa barbacoa', '/images/PRODUCTOS ABASTECETE/Despensa/Salsas y condimentos/Salsa barbacoa.webp', 3),
	(287, 22, 'Salsa teriyaki', '/images/PRODUCTOS ABASTECETE/Despensa/Salsas y condimentos/Salsa teriyaki.webp', 3),
	(288, 22, 'Pimienta negra', '/images/PRODUCTOS ABASTECETE/Despensa/Salsas y condimentos/Pimienta negra.webp', 3),
	(289, 22, 'Comino', '/images/PRODUCTOS ABASTECETE/Despensa/Salsas y condimentos/Comino.webp', 3),
	(290, 22, 'Curry', '/images/PRODUCTOS ABASTECETE/Despensa/Salsas y condimentos/Curry.webp', 3),
	(291, 22, 'Orégano seco', '/images/PRODUCTOS ABASTECETE/Despensa/Salsas y condimentos/Orégano seco.webp', 3),
	(292, 22, 'Ajo en polvo', '/images/PRODUCTOS ABASTECETE/Despensa/Salsas y condimentos/Ajo en polvo.webp', 3),
	(293, 23, 'Café molido', '/images/PRODUCTOS ABASTECETE/Despensa/Café y bebidas calientes/Café molido.webp', 3),
	(294, 23, 'Café instantáneo', '/images/PRODUCTOS ABASTECETE/Despensa/Café y bebidas calientes/Café instantáneo.webp', 3),
	(295, 23, 'Café en grano', '/images/PRODUCTOS ABASTECETE/Despensa/Café y bebidas calientes/Café en grano.webp', 3),
	(296, 23, 'Café descafeinado', '/images/PRODUCTOS ABASTECETE/Despensa/Café y bebidas calientes/Café descafeinado.webp', 3),
	(297, 23, 'Chocolate en polvo', '/images/PRODUCTOS ABASTECETE/Despensa/Café y bebidas calientes/Chocolate en polvo.webp', 3),
	(298, 23, 'Cacao instantáneo', '/images/PRODUCTOS ABASTECETE/Despensa/Café y bebidas calientes/Cacao instantáneo.webp', 3),
	(299, 23, 'Té negro', '/images/PRODUCTOS ABASTECETE/Despensa/Café y bebidas calientes/Té negro.webp', 3),
	(300, 23, 'Té verde', '/images/PRODUCTOS ABASTECETE/Despensa/Café y bebidas calientes/Té verde.webp', 3),
	(301, 24, 'Atún en aceite', '/images/PRODUCTOS ABASTECETE/Despensa/Conservas y enlatados/Atún en aceite.webp', 3),
	(302, 24, 'Atún en agua', '/images/PRODUCTOS ABASTECETE/Despensa/Conservas y enlatados/Atún en agua.webp', 3),
	(303, 24, 'Sardinas enlatadas', '/images/PRODUCTOS ABASTECETE/Despensa/Conservas y enlatados/Sardinas enlatadas.webp', 3),
	(304, 24, 'Vegetales mixtos enlatados', '/images/PRODUCTOS ABASTECETE/Despensa/Conservas y enlatados/Vegetales mixtos enlatados.webp', 3),
	(305, 24, 'Chícharos enlatados', '/images/PRODUCTOS ABASTECETE/Despensa/Conservas y enlatados/Chícharos enlatados.webp', 3),
	(306, 24, 'Maíz dulce enlatado', '/images/PRODUCTOS ABASTECETE/Despensa/Conservas y enlatados/Maíz dulce enlatado.webp', 3),
	(307, 24, 'Frutas en almíbar', '/images/PRODUCTOS ABASTECETE/Despensa/Conservas y enlatados/Frutas en almíbar.webp', 3),
	(308, 24, 'Purés de tomate', '/images/PRODUCTOS ABASTECETE/Despensa/Conservas y enlatados/Purés de tomate.webp', 3),
	(309, 25, 'Corn Flakes', '/images/PRODUCTOS ABASTECETE/Despensa/Cereales y granolas/Corn Flakes.webp', 3),
	(310, 25, 'Granola con frutos secos', '/images/PRODUCTOS ABASTECETE/Despensa/Cereales y granolas/Granola con frutos secos.webp', 3),
	(311, 25, 'Granola con chocolate', '/images/PRODUCTOS ABASTECETE/Despensa/Cereales y granolas/Granola con chocolate.webp', 3),
	(312, 25, 'Avena instantánea', '/images/PRODUCTOS ABASTECETE/Despensa/Cereales y granolas/Avena instantánea.webp', 3),
	(313, 25, 'Cereal integral', '/images/PRODUCTOS ABASTECETE/Despensa/Cereales y granolas/Cereal integral.webp', 3),
	(314, 25, 'Cereal con miel', '/images/PRODUCTOS ABASTECETE/Despensa/Cereales y granolas/Cereal con miel.webp', 3),
	(315, 25, 'Cereal para niños', '/images/PRODUCTOS ABASTECETE/Despensa/Cereales y granolas/Cereal para niños.webp', 3),
	(316, 25, 'Barritas de cereal', '/images/PRODUCTOS ABASTECETE/Despensa/Cereales y granolas/Barritas de cereal.webp', 3),
	(317, 26, 'Azúcar blanca', '/images/PRODUCTOS ABASTECETE/Despensa/Azúcar, endulzantes y sal/Azúcar blanca.webp', 3),
	(318, 26, 'Azúcar morena', '/images/PRODUCTOS ABASTECETE/Despensa/Azúcar, endulzantes y sal/Azúcar morena.webp', 3),
	(319, 26, 'Panela en bloques', '/images/PRODUCTOS ABASTECETE/Despensa/Azúcar, endulzantes y sal/Panela en bloques.webp', 3),
	(320, 26, 'Panela pulverizada', '/images/PRODUCTOS ABASTECETE/Despensa/Azúcar, endulzantes y sal/Panela pulverizada.webp', 3),
	(321, 26, 'Miel de abejas', '/images/PRODUCTOS ABASTECETE/Despensa/Azúcar, endulzantes y sal/Miel de abejas.webp', 3),
	(322, 26, 'Stevia', '/images/PRODUCTOS ABASTECETE/Despensa/Azúcar, endulzantes y sal/Stevia.webp', 3),
	(323, 26, 'Eritritol', '/images/PRODUCTOS ABASTECETE/Despensa/Azúcar, endulzantes y sal/Eritritol.webp', 3),
	(324, 26, 'Sal marina', '/images/PRODUCTOS ABASTECETE/Despensa/Azúcar, endulzantes y sal/Sal marina.webp', 3),
	(325, 26, 'Sal rosada del Himalaya', '/images/PRODUCTOS ABASTECETE/Despensa/Azúcar, endulzantes y sal/Sal rosada del Himalaya.webp', 3),
	(326, 27, 'Papas congeladas', '/images/PRODUCTOS ABASTECETE/Congelados/Verduras y tubérculos congelados/Papas congeladas.webp', 1),
	(327, 27, 'Brócoli congelado', '/images/PRODUCTOS ABASTECETE/Congelados/Verduras y tubérculos congelados/Brócoli congelado.webp', 1),
	(328, 27, 'Espinacas congeladas', '/images/PRODUCTOS ABASTECETE/Congelados/Verduras y tubérculos congelados/Espinacas congeladas.webp', 1),
	(329, 27, 'Zanahorias congeladas', '/images/PRODUCTOS ABASTECETE/Congelados/Verduras y tubérculos congelados/Zanahorias congeladas.webp', 1),
	(330, 27, 'Yuca congelada', '/images/PRODUCTOS ABASTECETE/Congelados/Verduras y tubérculos congelados/Yuca congelada.webp', 1),
	(331, 27, 'Mazorca congelada', '/images/PRODUCTOS ABASTECETE/Congelados/Verduras y tubérculos congelados/Mazorca congelada.webp', 1),
	(332, 27, 'Arvejas congeladas', '/images/PRODUCTOS ABASTECETE/Congelados/Verduras y tubérculos congelados/Arvejas congeladas.webp', 1),
	(333, 27, 'Mezcla de verduras congeladas', '/images/PRODUCTOS ABASTECETE/Congelados/Verduras y tubérculos congelados/Mezcla de verduras congeladas.webp', 1),
	(334, 28, 'Lasagna congelada', '/images/PRODUCTOS ABASTECETE/Congelados/Comidas listas para calentar/Lasagna congelada.webp', 3),
	(335, 28, 'Pizza congelada', '/images/PRODUCTOS ABASTECETE/Congelados/Comidas listas para calentar/Pizza congelada.webp', 3),
	(336, 28, 'Hamburguesas precocinadas', '/images/PRODUCTOS ABASTECETE/Congelados/Comidas listas para calentar/Hamburguesas precocinadas.webp', 3),
	(337, 28, 'Pollo apanado congelado', '/images/PRODUCTOS ABASTECETE/Congelados/Comidas listas para calentar/Pollo apanado congelado.webp', 3),
	(338, 28, 'Tacos congelados', '/images/PRODUCTOS ABASTECETE/Congelados/Comidas listas para calentar/Tacos congelados.webp', 3),
	(339, 28, 'Enchiladas congeladas', '/images/PRODUCTOS ABASTECETE/Congelados/Comidas listas para calentar/Enchiladas congeladas.webp', 3),
	(340, 28, 'Burritos congelados', '/images/PRODUCTOS ABASTECETE/Congelados/Comidas listas para calentar/Burritos congelados.webp', 3),
	(341, 29, 'Deditos de queso', '/images/PRODUCTOS ABASTECETE/Congelados/Pasabocas congelados/Deditos de queso.webp', 3),
	(342, 29, 'Empanadas congeladas', '/images/PRODUCTOS ABASTECETE/Congelados/Pasabocas congelados/Empanadas congeladas.webp', 3),
	(343, 29, 'Croquetas de pollo', '/images/PRODUCTOS ABASTECETE/Congelados/Pasabocas congelados/Croquetas de pollo.webp', 3),
	(344, 29, 'Palitos de pescado', '/images/PRODUCTOS ABASTECETE/Congelados/Pasabocas congelados/Palitos de pescado.webp', 3),
	(345, 29, 'Spring rolls', '/images/PRODUCTOS ABASTECETE/Congelados/Pasabocas congelados/Spring rolls.webp', 3),
	(346, 29, 'Mini arepas', '/images/PRODUCTOS ABASTECETE/Congelados/Pasabocas congelados/Mini arepas.webp', 3),
	(347, 29, 'Pasabocas de maíz', '/images/PRODUCTOS ABASTECETE/Congelados/Pasabocas congelados/Pasabocas de maíz.webp', 3),
	(348, 30, 'Helado de vainilla', '/images/PRODUCTOS ABASTECETE/Congelados/Helados y postres congelados/Helado de vainilla.webp', 3),
	(349, 30, 'Helado de chocolate', '/images/PRODUCTOS ABASTECETE/Congelados/Helados y postres congelados/Helado de chocolate.webp', 3),
	(350, 30, 'Paletas de frutas', '/images/PRODUCTOS ABASTECETE/Congelados/Helados y postres congelados/Paletas de frutas.webp', 3),
	(351, 30, 'Brownies helados', '/images/PRODUCTOS ABASTECETE/Congelados/Helados y postres congelados/Brownies helados.webp', 3),
	(352, 30, 'Sundaes', '/images/PRODUCTOS ABASTECETE/Congelados/Helados y postres congelados/Sundaes.webp', 3),
	(353, 30, 'Helados sin lactosa', '/images/PRODUCTOS ABASTECETE/Congelados/Helados y postres congelados/Helados sin lactosa.webp', 3),
	(354, 30, 'Tartaletas congeladas', '/images/PRODUCTOS ABASTECETE/Congelados/Helados y postres congelados/Tartaletas congeladas.webp', 3),
	(355, 31, 'Coca-Cola', '/images/PRODUCTOS ABASTECETE/Bebidas/Gaseosas y sodas/Coca-Cola.webp', 2),
	(356, 31, 'Pepsi', '/images/PRODUCTOS ABASTECETE/Bebidas/Gaseosas y sodas/Pepsi.webp', 2),
	(357, 31, '7 Up', '/images/PRODUCTOS ABASTECETE/Bebidas/Gaseosas y sodas/7 Up.webp', 2),
	(358, 31, 'Postobón', '/images/PRODUCTOS ABASTECETE/Bebidas/Gaseosas y sodas/Postobón.webp', 2),
	(359, 31, 'Fanta', '/images/PRODUCTOS ABASTECETE/Bebidas/Gaseosas y sodas/Fanta.webp', 2),
	(360, 31, 'Sprite', '/images/PRODUCTOS ABASTECETE/Bebidas/Gaseosas y sodas/Sprite.webp', 2),
	(361, 31, 'Ginger Ale', '/images/PRODUCTOS ABASTECETE/Bebidas/Gaseosas y sodas/Ginger Ale.webp', 2),
	(362, 31, 'Kola Roman', '/images/PRODUCTOS ABASTECETE/Bebidas/Gaseosas y sodas/Kola Roman.webp', 2),
	(363, 32, 'Jugo de naranja', '/images/PRODUCTOS ABASTECETE/Bebidas/Jugos y zumos/Jugo de naranja.webp', 2),
	(364, 32, 'Jugo de mango', '/images/PRODUCTOS ABASTECETE/Bebidas/Jugos y zumos/Jugo de mango.webp', 2),
	(365, 32, 'Jugo de manzana', '/images/PRODUCTOS ABASTECETE/Bebidas/Jugos y zumos/Jugo de manzana.webp', 2),
	(366, 32, 'Jugo de uva', '/images/PRODUCTOS ABASTECETE/Bebidas/Jugos y zumos/Jugo de uva.webp', 2),
	(367, 32, 'Néctar de durazno', '/images/PRODUCTOS ABASTECETE/Bebidas/Jugos y zumos/Néctar de durazno.webp', 2),
	(368, 32, 'Limonada natural', '/images/PRODUCTOS ABASTECETE/Bebidas/Jugos y zumos/Limonada natural.webp', 2),
	(369, 32, 'Jugo tropical', '/images/PRODUCTOS ABASTECETE/Bebidas/Jugos y zumos/Jugo tropical.webp', 2),
	(370, 32, 'Smoothies envasados', '/images/PRODUCTOS ABASTECETE/Bebidas/Jugos y zumos/Smoothies envasados.webp', 2),
	(371, 33, 'Agua mineral', '/images/PRODUCTOS ABASTECETE/Bebidas/Agua embotellada y té/Agua mineral.webp', 2),
	(372, 33, 'Agua con gas', '/images/PRODUCTOS ABASTECETE/Bebidas/Agua embotellada y té/Agua con gas.webp', 2),
	(373, 33, 'Té negro', '/images/PRODUCTOS ABASTECETE/Bebidas/Agua embotellada y té/Té negro.webp', 2),
	(374, 33, 'Té verde', '/images/PRODUCTOS ABASTECETE/Bebidas/Agua embotellada y té/Té verde.webp', 2),
	(375, 33, 'Té de hierbas', '/images/PRODUCTOS ABASTECETE/Bebidas/Agua embotellada y té/Té de hierbas.webp', 2),
	(376, 33, 'Té chai', '/images/PRODUCTOS ABASTECETE/Bebidas/Agua embotellada y té/Té chai.webp', 2),
	(377, 33, 'Té helado', '/images/PRODUCTOS ABASTECETE/Bebidas/Agua embotellada y té/Té helado.webp', 2),
	(378, 33, 'Infusiones frutales', '/images/PRODUCTOS ABASTECETE/Bebidas/Agua embotellada y té/Infusiones frutales.webp', 2),
	(379, 34, 'Gatorade', '/images/PRODUCTOS ABASTECETE/Bebidas/Bebidas isotónicas y energizantes/Gatorade.webp', 2),
	(380, 34, 'Powerade', '/images/PRODUCTOS ABASTECETE/Bebidas/Bebidas isotónicas y energizantes/Powerade.webp', 2),
	(381, 34, 'Red Bull', '/images/PRODUCTOS ABASTECETE/Bebidas/Bebidas isotónicas y energizantes/Red Bull.webp', 2),
	(382, 34, 'Monster Energy', '/images/PRODUCTOS ABASTECETE/Bebidas/Bebidas isotónicas y energizantes/Monster Energy.webp', 2),
	(383, 34, 'Bebidas hidratantes sin azúcar', '/images/PRODUCTOS ABASTECETE/Bebidas/Bebidas isotónicas y energizantes/Bebidas hidratantes sin azúcar.webp', 2),
	(384, 35, 'Chips de papa', '/images/PRODUCTOS ABASTECETE/Snacks y Aperitivos/Pasabocas empacados/Chips de papa.webp', 3),
	(385, 35, 'Nachos', '/images/PRODUCTOS ABASTECETE/Snacks y Aperitivos/Pasabocas empacados/Nachos.webp', 3),
	(386, 35, 'Platanitos', '/images/PRODUCTOS ABASTECETE/Snacks y Aperitivos/Pasabocas empacados/Platanitos.webp', 3),
	(387, 35, 'Palomitas de maíz', '/images/PRODUCTOS ABASTECETE/Snacks y Aperitivos/Pasabocas empacados/Palomitas de maíz.webp', 3),
	(388, 35, 'Cortezas de cerdo', '/images/PRODUCTOS ABASTECETE/Snacks y Aperitivos/Pasabocas empacados/Cortezas de cerdo.webp', 3),
	(389, 35, 'Pasabocas de queso', '/images/PRODUCTOS ABASTECETE/Snacks y Aperitivos/Pasabocas empacados/Pasabocas de queso.webp', 3),
	(390, 35, 'Pasabocas picantes', '/images/PRODUCTOS ABASTECETE/Snacks y Aperitivos/Pasabocas empacados/Pasabocas picantes.webp', 3),
	(391, 36, 'Almendras', '/images/PRODUCTOS ABASTECETE/Snacks y Aperitivos/Frutos secos y semillas/Almendras.webp', 3),
	(392, 36, 'Nueces', '/images/PRODUCTOS ABASTECETE/Snacks y Aperitivos/Frutos secos y semillas/Nueces.webp', 3),
	(393, 36, 'Pistachos', '/images/PRODUCTOS ABASTECETE/Snacks y Aperitivos/Frutos secos y semillas/Pistachos.webp', 3),
	(394, 36, 'Avellanas', '/images/PRODUCTOS ABASTECETE/Snacks y Aperitivos/Frutos secos y semillas/Avellanas.webp', 3),
	(395, 36, 'Semillas de girasol', '/images/PRODUCTOS ABASTECETE/Snacks y Aperitivos/Frutos secos y semillas/Semillas de girasol.webp', 3),
	(396, 36, 'Semillas de calabaza', '/images/PRODUCTOS ABASTECETE/Snacks y Aperitivos/Frutos secos y semillas/Semillas de calabaza.webp', 3),
	(397, 36, 'Mix de frutos secos', '/images/PRODUCTOS ABASTECETE/Snacks y Aperitivos/Frutos secos y semillas/Mix de frutos secos.webp', 3),
	(398, 36, 'Maní salado', '/images/PRODUCTOS ABASTECETE/Snacks y Aperitivos/Frutos secos y semillas/Maní salado.webp', 3),
	(399, 36, 'Maní confitado', '/images/PRODUCTOS ABASTECETE/Snacks y Aperitivos/Frutos secos y semillas/Maní confitado.webp', 3),
	(400, 37, 'Galletas de avena', '/images/PRODUCTOS ABASTECETE/Snacks y Aperitivos/Galletas dulces y saladas/Galletas de avena.webp', 3),
	(401, 37, 'Galletas de chocolate', '/images/PRODUCTOS ABASTECETE/Snacks y Aperitivos/Galletas dulces y saladas/Galletas de chocolate.webp', 3),
	(402, 37, 'Galletas de mantequilla', '/images/PRODUCTOS ABASTECETE/Snacks y Aperitivos/Galletas dulces y saladas/Galletas de mantequilla.webp', 3),
	(403, 37, 'Crackers saladas', '/images/PRODUCTOS ABASTECETE/Snacks y Aperitivos/Galletas dulces y saladas/Crackers saladas.webp', 3),
	(404, 37, 'Galletas integrales', '/images/PRODUCTOS ABASTECETE/Snacks y Aperitivos/Galletas dulces y saladas/Galletas integrales.webp', 3),
	(405, 37, 'Galletas rellenas', '/images/PRODUCTOS ABASTECETE/Snacks y Aperitivos/Galletas dulces y saladas/Galletas rellenas.webp', 3),
	(406, 38, 'Barritas de chocolate', '/images/PRODUCTOS ABASTECETE/Dulces y Chocolatería/Chocolatería fina/Barritas de chocolate.webp', 3),
	(407, 38, 'Chocolates rellenos', '/images/PRODUCTOS ABASTECETE/Dulces y Chocolatería/Chocolatería fina/Chocolates rellenos.webp', 3),
	(408, 38, 'Trufas', '/images/PRODUCTOS ABASTECETE/Dulces y Chocolatería/Chocolatería fina/Trufas.webp', 3),
	(409, 38, 'Bombones de chocolate', '/images/PRODUCTOS ABASTECETE/Dulces y Chocolatería/Chocolatería fina/Bombones de chocolate.webp', 3),
	(410, 39, 'Caramelos duros', '/images/PRODUCTOS ABASTECETE/Dulces y Chocolatería/Confitería/Caramelos duros.webp', 3),
	(411, 39, 'Caramelos masticables', '/images/PRODUCTOS ABASTECETE/Dulces y Chocolatería/Confitería/Caramelos masticables.webp', 3),
	(412, 39, 'Gomitas', '/images/PRODUCTOS ABASTECETE/Dulces y Chocolatería/Confitería/Gomitas.webp', 3),
	(413, 39, 'Masmelos', '/images/PRODUCTOS ABASTECETE/Dulces y Chocolatería/Confitería/Masmelos.webp', 3),
	(414, 39, 'Dulces ácidos', '/images/PRODUCTOS ABASTECETE/Dulces y Chocolatería/Confitería/Dulces ácidos.webp', 3),
	(415, 40, 'Arequipe tradicional', '/images/PRODUCTOS ABASTECETE/Dulces y Chocolatería/Arequipe y derivados lácteos dulces/Arequipe tradicional.webp', 3),
	(416, 40, 'Arequipe con chocolate', '/images/PRODUCTOS ABASTECETE/Dulces y Chocolatería/Arequipe y derivados lácteos dulces/Arequipe con chocolate.webp', 3),
	(417, 40, 'Leche condensada', '/images/PRODUCTOS ABASTECETE/Dulces y Chocolatería/Arequipe y derivados lácteos dulces/Leche condensada.webp', 3),
	(418, 40, 'Dulce de leche', '/images/PRODUCTOS ABASTECETE/Dulces y Chocolatería/Arequipe y derivados lácteos dulces/Dulce de leche.webp', 3),
	(419, 41, 'Chicles de menta', '/images/PRODUCTOS ABASTECETE/Dulces y Chocolatería/Chicles y masticables/Chicles de menta.webp', 3),
	(420, 41, 'Chicles de frutas', '/images/PRODUCTOS ABASTECETE/Dulces y Chocolatería/Chicles y masticables/Chicles de frutas.webp', 3),
	(421, 41, 'Chicles sin azúcar', '/images/PRODUCTOS ABASTECETE/Dulces y Chocolatería/Chicles y masticables/Chicles sin azúcar.webp', 3),
	(422, 41, 'Caramelos elásticos', '/images/PRODUCTOS ABASTECETE/Dulces y Chocolatería/Chicles y masticables/Caramelos elásticos.webp', 3),
	(423, 42, 'Queso parmesano', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Quesos madurados y gourmet/Queso parmesano.webp', 1),
	(424, 42, 'Queso gouda', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Quesos madurados y gourmet/Queso gouda.webp', 1),
	(425, 42, 'Queso brie', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Quesos madurados y gourmet/Queso brie.webp', 1),
	(426, 42, 'Queso camembert', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Quesos madurados y gourmet/Queso camembert.webp', 1),
	(427, 42, 'Queso roquefort', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Quesos madurados y gourmet/Queso roquefort.webp', 1),
	(428, 42, 'Queso pecorino', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Quesos madurados y gourmet/Queso pecorino.webp', 1),
	(429, 42, 'Queso emmental', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Quesos madurados y gourmet/Queso emmental.webp', 1),
	(430, 42, 'Queso gruyere', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Quesos madurados y gourmet/Queso gruyere.webp', 1),
	(431, 42, 'Queso manchego', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Quesos madurados y gourmet/Queso manchego.webp', 1),
	(432, 42, 'Queso azul', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Quesos madurados y gourmet/Queso azul.webp', 1),
	(433, 43, 'Jamón serrano', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Carnes curadas y especiales/Jamón serrano.webp', 1),
	(434, 43, 'Jamón ibérico', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Carnes curadas y especiales/Jamón ibérico.webp', 1),
	(435, 43, 'Prosciutto', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Carnes curadas y especiales/Prosciutto.webp', 1),
	(436, 43, 'Salami', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Carnes curadas y especiales/Salami.webp', 1),
	(437, 43, 'Pastrami', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Carnes curadas y especiales/Pastrami.webp', 1),
	(438, 43, 'Bresaola', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Carnes curadas y especiales/Bresaola.webp', 1),
	(439, 43, 'Lomo embuchado', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Carnes curadas y especiales/Lomo embuchado.webp', 1),
	(440, 43, 'Longaniza', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Carnes curadas y especiales/Longaniza.webp', 1),
	(441, 43, 'Cecina', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Carnes curadas y especiales/Cecina.webp', 1),
	(442, 43, 'Sobrasada', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Carnes curadas y especiales/Sobrasada.webp', 1),
	(443, 44, 'Pepinillos encurtidos', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Encurtidos, conservas y patés/Pepinillos encurtidos.webp', 3),
	(444, 44, 'Aceitunas verdes', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Encurtidos, conservas y patés/Aceitunas verdes.webp', 3),
	(445, 44, 'Aceitunas negras', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Encurtidos, conservas y patés/Aceitunas negras.webp', 3),
	(446, 44, 'Corazones de alcachofa', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Encurtidos, conservas y patés/Corazones de alcachofa.webp', 3),
	(447, 44, 'Paté de hígado', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Encurtidos, conservas y patés/Paté de hígado.webp', 3),
	(448, 44, 'Paté de cerdo', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Encurtidos, conservas y patés/Paté de cerdo.webp', 3),
	(449, 44, 'Conserva de champiñones', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Encurtidos, conservas y patés/Conserva de champiñones.webp', 3),
	(450, 44, 'Conserva de espárragos', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Encurtidos, conservas y patés/Conserva de espárragos.webp', 3),
	(451, 44, 'Chiles encurtidos', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Encurtidos, conservas y patés/Chiles encurtidos.webp', 3),
	(452, 44, 'Tapenade', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Encurtidos, conservas y patés/Tapenade.webp', 3),
	(453, 45, 'Detergente líquido', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Jabones y detergentes/Detergente líquido.webp', 3),
	(454, 45, 'Detergente en polvo', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Jabones y detergentes/Detergente en polvo.webp', 3),
	(455, 45, 'Jabón para ropa delicada', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Jabones y detergentes/Jabón para ropa delicada.webp', 3),
	(456, 45, 'Jabón líquido multiuso', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Jabones y detergentes/Jabón líquido multiuso.webp', 3),
	(457, 45, 'Detergente para ropa oscura', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Jabones y detergentes/Detergente para ropa oscura.webp', 3),
	(458, 45, 'Detergente para ropa blanca', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Jabones y detergentes/Detergente para ropa blanca.webp', 3),
	(459, 45, 'Jabón en barra', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Jabones y detergentes/Jabón en barra.webp', 3),
	(460, 46, 'Limpiador en spray', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Limpiadores multiusos/Limpiador en spray.webp', 2),
	(461, 46, 'Limpiador concentrado', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Limpiadores multiusos/Limpiador concentrado.webp', 2),
	(462, 46, 'Limpiador con cloro', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Limpiadores multiusos/Limpiador con cloro.webp', 2),
	(463, 46, 'Limpiador antibacterial', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Limpiadores multiusos/Limpiador antibacterial.webp', 2),
	(464, 46, 'Limpiador ecológico', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Limpiadores multiusos/Limpiador ecológico.webp', 2),
	(465, 46, 'Limpiador aromático', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Limpiadores multiusos/Limpiador aromático.webp', 2),
	(466, 47, 'Papel higiénico de hoja sencilla', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Papel higiénico y servilletas/Papel higiénico de hoja sencilla.webp', 3),
	(467, 47, 'Papel higiénico de hoja doble', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Papel higiénico y servilletas/Papel higiénico de hoja doble.webp', 3),
	(468, 47, 'Servilletas blancas', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Papel higiénico y servilletas/Servilletas blancas.webp', 3),
	(469, 47, 'Servilletas decorativas', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Papel higiénico y servilletas/Servilletas decorativas.webp', 3),
	(470, 47, 'Rollos de cocina', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Papel higiénico y servilletas/Rollos de cocina.webp', 3),
	(471, 47, 'Toallas de papel absorbente', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Papel higiénico y servilletas/Toallas de papel absorbente.webp', 3),
	(472, 48, 'Ambientador en spray', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Ambientadores y control de plagas/Ambientador en spray.webp', 2),
	(473, 48, 'Ambientador en gel', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Ambientadores y control de plagas/Ambientador en gel.webp', 2),
	(474, 48, 'Velas aromáticas', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Ambientadores y control de plagas/Velas aromáticas.webp', 2),
	(475, 48, 'Difusores de aroma', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Ambientadores y control de plagas/Difusores de aroma.webp', 2),
	(476, 48, 'Insecticida en aerosol', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Ambientadores y control de plagas/Insecticida en aerosol.webp', 2),
	(477, 48, 'Insecticida eléctrico', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Ambientadores y control de plagas/Insecticida eléctrico.webp', 2),
	(478, 48, 'Trampas para insectos', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Ambientadores y control de plagas/Trampas para insectos.webp', 2),
	(479, 49, 'Esponjas', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Implementos de limpieza/Esponjas.webp', 3),
	(480, 49, 'Trapos de microfibra', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Implementos de limpieza/Trapos de microfibra.webp', 3),
	(481, 49, 'Escobas', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Implementos de limpieza/Escobas.webp', 3),
	(482, 49, 'Cepillos de limpieza', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Implementos de limpieza/Cepillos de limpieza.webp', 3),
	(483, 49, 'Trapeadores', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Implementos de limpieza/Trapeadores.webp', 3),
	(484, 49, 'Plumeros', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Implementos de limpieza/Plumeros.webp', 3),
	(485, 49, 'Baldes', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Implementos de limpieza/Baldes.webp', 3),
	(486, 49, 'Guantes de látex', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Implementos de limpieza/Guantes de látex.webp', 3),
	(487, 49, 'Paños absorbentes', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Implementos de limpieza/Paños absorbentes.webp', 3),
	(488, 49, 'Raspadores', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Implementos de limpieza/Raspadores.webp', 3),
	(489, 50, 'Shampoo para cabello seco', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Cuidado capilar/Shampoo para cabello seco.webp', 2),
	(490, 50, 'Shampoo para cabello graso', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Cuidado capilar/Shampoo para cabello graso.webp', 2),
	(491, 50, 'Acondicionador hidratante', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Cuidado capilar/Acondicionador hidratante.webp', 2),
	(492, 50, 'Mascarilla capilar', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Cuidado capilar/Mascarilla capilar.webp', 2),
	(493, 50, 'Sérum para puntas abiertas', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Cuidado capilar/Sérum para puntas abiertas.webp', 2),
	(494, 50, 'Aceite capilar', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Cuidado capilar/Aceite capilar.webp', 2),
	(495, 50, 'Spray para peinar', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Cuidado capilar/Spray para peinar.webp', 2),
	(496, 51, 'Crema hidratante facial', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Cuidado facial y corporal/Crema hidratante facial.webp', 2),
	(497, 51, 'Protector solar', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Cuidado facial y corporal/Protector solar.webp', 2),
	(498, 51, 'Tónico facial', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Cuidado facial y corporal/Tónico facial.webp', 2),
	(499, 51, 'Jabón corporal líquido', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Cuidado facial y corporal/Jabón corporal líquido.webp', 2),
	(500, 51, 'Exfoliante corporal', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Cuidado facial y corporal/Exfoliante corporal.webp', 2),
	(501, 51, 'Crema para manos', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Cuidado facial y corporal/Crema para manos.webp', 2),
	(502, 51, 'Aceite corporal', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Cuidado facial y corporal/Aceite corporal.webp', 2),
	(503, 51, 'Gel de aloe vera', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Cuidado facial y corporal/Gel de aloe vera.webp', 2),
	(504, 52, 'Toallas higiénicas', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Higiene íntima/Toallas higiénicas.webp', 3),
	(505, 52, 'Tampones', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Higiene íntima/Tampones.webp', 3),
	(506, 52, 'Copa menstrual', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Higiene íntima/Copa menstrual.webp', 3),
	(507, 52, 'Jabón íntimo', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Higiene íntima/Jabón íntimo.webp', 3),
	(508, 52, 'Toallas húmedas íntimas', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Higiene íntima/Toallas húmedas íntimas.webp', 3),
	(509, 52, 'Protegeslips', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Higiene íntima/Protegeslips.webp', 3),
	(510, 53, 'Pañales desechables', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Higiene para bebés y niños/Pañales desechables.webp', 3),
	(511, 53, 'Pañales ecológicos', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Higiene para bebés y niños/Pañales ecológicos.webp', 3),
	(512, 53, 'Toallitas húmedas', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Higiene para bebés y niños/Toallitas húmedas.webp', 3),
	(513, 53, 'Jabón líquido para bebés', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Higiene para bebés y niños/Jabón líquido para bebés.webp', 3),
	(514, 53, 'Shampoo para bebés', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Higiene para bebés y niños/Shampoo para bebés.webp', 3),
	(515, 53, 'Crema antipañalitis', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Higiene para bebés y niños/Crema antipañalitis.webp', 3),
	(516, 53, 'Loción hidratante para bebés', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Higiene para bebés y niños/Loción hidratante para bebés.webp', 3),
	(517, 54, 'Preservativos de látex', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Bienestar sexual/Preservativos de látex.webp', 3),
	(518, 54, 'Preservativos sin látex', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Bienestar sexual/Preservativos sin látex.webp', 3),
	(519, 54, 'Lubricantes a base de agua', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Bienestar sexual/Lubricantes a base de agua.webp', 3),
	(520, 54, 'Lubricantes a base de silicona', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Bienestar sexual/Lubricantes a base de silicona.webp', 3),
	(521, 54, 'Anillos estimulantes', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Bienestar sexual/Anillos estimulantes.webp', 3),
	(522, 55, 'Bloqueador solar FPS 30', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Protección solar y repelentes/Bloqueador solar FPS 30.webp', 2),
	(523, 55, 'Bloqueador solar FPS 50', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Protección solar y repelentes/Bloqueador solar FPS 50.webp', 2),
	(524, 55, 'Protector solar en spray', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Protección solar y repelentes/Protector solar en spray.webp', 2),
	(525, 55, 'Repelente en crema', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Protección solar y repelentes/Repelente en crema.webp', 2),
	(526, 55, 'Repelente en aerosol', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Protección solar y repelentes/Repelente en aerosol.webp', 2),
	(527, 55, 'Pulseras repelentes', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Protección solar y repelentes/Pulseras repelentes.webp', 2),
	(528, 56, 'Analgésicos', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Salud y medicamentos/Analgésicos.webp', 3),
	(529, 56, 'Antiinflamatorios', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Salud y medicamentos/Antiinflamatorios.webp', 3),
	(530, 56, 'Jarabe para la tos', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Salud y medicamentos/Jarabe para la tos.webp', 3),
	(531, 56, 'Vitaminas y suplementos', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Salud y medicamentos/Vitaminas y suplementos.webp', 3),
	(532, 56, 'Medicamentos antialérgicos', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Salud y medicamentos/Medicamentos antialérgicos.webp', 3),
	(533, 56, 'Pastillas para el dolor de garganta', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Salud y medicamentos/Pastillas para el dolor de garganta.webp', 3),
	(534, 56, 'Ungüentos tópicos', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Salud y medicamentos/Ungüentos tópicos.webp', 3),
	(535, 57, 'Cerveza lager', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Cervezas/Cerveza lager.webp', 2),
	(536, 57, 'Cerveza pilsner', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Cervezas/Cerveza pilsner.webp', 2),
	(537, 57, 'Cerveza stout', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Cervezas/Cerveza stout.webp', 2),
	(538, 57, 'Cerveza IPA', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Cervezas/Cerveza IPA.webp', 2),
	(539, 57, 'Cerveza artesanal', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Cervezas/Cerveza artesanal.webp', 2),
	(540, 57, 'Cerveza sin alcohol', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Cervezas/Cerveza sin alcohol.webp', 2),
	(541, 57, 'Cerveza rubia', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Cervezas/Cerveza rubia.webp', 2),
	(542, 57, 'Cerveza roja', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Cervezas/Cerveza roja.webp', 2),
	(543, 58, 'Vino tinto', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Vinos/Vino tinto.webp', 2),
	(544, 58, 'Vino blanco', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Vinos/Vino blanco.webp', 2),
	(545, 58, 'Vino rosado', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Vinos/Vino rosado.webp', 2),
	(546, 58, 'Vino espumoso', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Vinos/Vino espumoso.webp', 2),
	(547, 58, 'Vino de postre', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Vinos/Vino de postre.webp', 2),
	(548, 58, 'Vino orgánico', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Vinos/Vino orgánico.webp', 2),
	(549, 58, 'Vino crianza', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Vinos/Vino crianza.webp', 2),
	(550, 58, 'Vino reserva', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Vinos/Vino reserva.webp', 2),
	(551, 59, 'Whisky escocés', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Whisky y ron/Whisky escocés.webp', 2),
	(552, 59, 'Whisky irlandés', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Whisky y ron/Whisky irlandés.webp', 2),
	(553, 59, 'Whisky americano', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Whisky y ron/Whisky americano.webp', 2),
	(554, 59, 'Ron oscuro', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Whisky y ron/Ron oscuro.webp', 2),
	(555, 59, 'Ron dorado', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Whisky y ron/Ron dorado.webp', 2),
	(556, 59, 'Ron blanco', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Whisky y ron/Ron blanco.webp', 2),
	(557, 59, 'Ron especiado', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Whisky y ron/Ron especiado.webp', 2),
	(558, 60, 'Tequila blanco', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Tequilas y otros destilados/Tequila blanco.webp', 2),
	(559, 60, 'Tequila reposado', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Tequilas y otros destilados/Tequila reposado.webp', 2),
	(560, 60, 'Tequila añejo', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Tequilas y otros destilados/Tequila añejo.webp', 2),
	(561, 60, 'Tequila extra añejo', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Tequilas y otros destilados/Tequila extra añejo.webp', 2),
	(562, 60, 'Mezcal', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Tequilas y otros destilados/Mezcal.webp', 2),
	(563, 60, 'Vodka', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Tequilas y otros destilados/Vodka.webp', 2),
	(564, 60, 'Gin', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Tequilas y otros destilados/Gin.webp', 2),
	(565, 60, 'Aguardiente', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Tequilas y otros destilados/Aguardiente.webp', 2),
	(566, 61, 'Vermouth', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Coctelería/Vermouth.webp', 2),
	(567, 61, 'Aperol', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Coctelería/Aperol.webp', 2),
	(568, 61, 'Campari', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Coctelería/Campari.webp', 2),
	(569, 61, 'Triple sec', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Coctelería/Triple sec.webp', 2),
	(570, 61, 'Cointreau', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Coctelería/Cointreau.webp', 2),
	(571, 61, 'Jugo de limón para coctelería', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Coctelería/Jugo de limón para coctelería.webp', 2),
	(572, 61, 'Jarabe de azúcar', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Coctelería/Jarabe de azúcar.webp', 2),
	(573, 61, 'Bitters', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Coctelería/Bitters.webp', 2),
	(574, 62, 'Cigarrillos mentolados', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Cigarrillos y vapeadores/Cigarrillos mentolados.webp', 3),
	(575, 62, 'Cigarrillos light', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Cigarrillos y vapeadores/Cigarrillos light.webp', 3),
	(576, 62, 'Vapeadores desechables', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Cigarrillos y vapeadores/Vapeadores desechables.webp', 3),
	(577, 62, 'Vapeadores recargables', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Cigarrillos y vapeadores/Vapeadores recargables.webp', 3),
	(578, 62, 'Pods de nicotina', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Cigarrillos y vapeadores/Pods de nicotina.webp', 3),
	(579, 62, 'Líquidos para vapeadores', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Cigarrillos y vapeadores/Líquidos para vapeadores.webp', 3),
	(580, 62, 'Cigarrillos electrónicos', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Cigarrillos y vapeadores/Cigarrillos electrónicos.webp', 3),
	(581, 38, 'Chocolatería fina', '/images/PRODUCTOS ABASTECETE/Dulces y Chocolatería/Chocolatería fina/Chocolatería fina.webp', 3);

-- Volcando estructura para tabla abastecete.productoslocal
CREATE TABLE IF NOT EXISTS `productoslocal` (
  `PK_ID_PRODUCTS_LOCAL` int NOT NULL AUTO_INCREMENT,
  `FK_ID_PRODUCTO` int NOT NULL DEFAULT '0',
  `FK_ID_UNIDAD` int NOT NULL DEFAULT '0',
  `VALOR_PRODUCTS_LOCAL` int NOT NULL DEFAULT '0',
  `FK_ID_LOCAL` int NOT NULL DEFAULT '0',
  `FK_ESTADO` int NOT NULL DEFAULT '1',
  PRIMARY KEY (`PK_ID_PRODUCTS_LOCAL`),
  KEY `fk_local` (`FK_ID_LOCAL`),
  KEY `fk_estado` (`FK_ESTADO`),
  KEY `FK_ID_UNIDAD` (`FK_ID_UNIDAD`),
  KEY `FK_ID_PRODUCTO` (`FK_ID_PRODUCTO`),
  KEY `idx_productoslocal_producto` (`FK_ID_PRODUCTO`),
  KEY `idx_productoslocal_local` (`FK_ID_LOCAL`),
  CONSTRAINT `fk3` FOREIGN KEY (`FK_ID_PRODUCTO`) REFERENCES `producto` (`PK_ID_PRODUCTO`),
  CONSTRAINT `fk4` FOREIGN KEY (`FK_ID_UNIDAD`) REFERENCES `unidad` (`ID_UNIDAD`),
  CONSTRAINT `fk_estado` FOREIGN KEY (`FK_ESTADO`) REFERENCES `estado` (`PK_ID_ESTADO`),
  CONSTRAINT `fk_local` FOREIGN KEY (`FK_ID_LOCAL`) REFERENCES `local` (`PK_ID_LOCAL`)
) ENGINE=InnoDB AUTO_INCREMENT=130 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Volcando datos para la tabla abastecete.productoslocal: ~26 rows (aproximadamente)
INSERT INTO `productoslocal` (`PK_ID_PRODUCTS_LOCAL`, `FK_ID_PRODUCTO`, `FK_ID_UNIDAD`, `VALOR_PRODUCTS_LOCAL`, `FK_ID_LOCAL`, `FK_ESTADO`) VALUES
	(104, 1, 6, 5000, 28, 1),
	(105, 5, 6, 7000, 28, 1),
	(106, 34, 6, 10000, 28, 1),
	(107, 224, 10, 2000, 34, 1),
	(108, 227, 10, 6000, 35, 1),
	(109, 13, 1, 4200, 35, 1),
	(110, 429, 2, 11000, 35, 1),
	(111, 462, 5, 13500, 35, 1),
	(112, 90, 2, 23000, 35, 1),
	(113, 81, 2, 10000, 36, 1),
	(114, 189, 4, 10000, 36, 1),
	(115, 227, 10, 3000, 36, 1),
	(116, 192, 4, 20000, 36, 1),
	(117, 360, 4, 5000, 36, 1),
	(118, 110, 2, 13000, 36, 1),
	(119, 90, 2, 60000, 36, 1),
	(120, 111, 2, 20000, 36, 1),
	(121, 113, 2, 8000, 36, 1),
	(122, 267, 10, 1000, 36, 1),
	(123, 269, 10, 2000, 36, 1),
	(124, 173, 2, 150000, 36, 1),
	(125, 84, 2, 20000, 27, 1),
	(126, 355, 4, 7000, 27, 1),
	(127, 410, 10, 2000, 27, 1),
	(128, 535, 5, 8000, 27, 1),
	(129, 143, 1, 6000, 27, 1);

-- Volcando estructura para procedimiento abastecete.productos_local
DELIMITER //
CREATE PROCEDURE `productos_local`(
	IN `localid` INT
)
BEGIN

	SELECT local.PK_ID_LOCAL,
	local.NOMBRE_LOCAL,
	producto.PK_ID_PRODUCTO,
	producto.NOMBRE_PRODUCTO,
	producto.IMAGEN_URL,
	producto.FK_ID_SUB_CATEGORIA,
	categoria.PK_ID_CATEGORIA,
	GROUP_CONCAT(productoslocal.VALOR_PRODUCTS_LOCAL SEPARATOR ', ') AS PRECIOS,
	GROUP_CONCAT(unidad.NOMBRE_UNIDAD SEPARATOR ', ') AS UNIDADES
 	FROM  local
	INNER JOIN productoslocal ON productoslocal.FK_ID_LOCAL =  local.PK_ID_LOCAL
	INNER JOIN producto ON productoslocal.FK_ID_PRODUCTO =  producto.PK_ID_PRODUCTO
	INNER JOIN unidad ON productoslocal.FK_ID_UNIDAD =  unidad.ID_UNIDAD
	INNER JOIN sub_categoria ON producto.FK_ID_SUB_CATEGORIA = sub_categoria.PK_ID_SUB_CATEGORIA
	INNER JOIN categoria ON sub_categoria.FK_ID_CATEGORIA= categoria.PK_ID_CATEGORIA
	WHERE local.PK_ID_LOCAL = localid
	GROUP BY local.PK_ID_LOCAL,local.NOMBRE_LOCAL,producto.PK_ID_PRODUCTO,producto.NOMBRE_PRODUCTO,producto.FK_ID_SUB_CATEGORIA
	ORDER BY producto.NOMBRE_PRODUCTO ASC;

END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.realizar_pago_membresia
DELIMITER //
CREATE PROCEDURE `realizar_pago_membresia`(
    IN `p_usuario_id` INT,                   -- ID del usuario que realiza el pago
    IN `p_tipo_membresia_id` INT,            -- ID del tipo de membresía
    IN `p_codigo_referido` VARCHAR(20),      -- Código referido ingresado
    OUT `mensaje` VARCHAR(255),              -- Mensaje de resultado
    OUT `resultado` INT                      -- Resultado de la operación (0 = fallo, 1 = éxito)
)
BEGIN
    DECLARE v_costo DECIMAL(10,2);
    DECLARE v_descuento DECIMAL(10,2);
    DECLARE v_monto_final DECIMAL(10,2);
    DECLARE v_usuario_existente INT;
    DECLARE v_codigo_valido BOOLEAN DEFAULT FALSE;
    DECLARE v_dueno_codigo_id INT;
    DECLARE v_clientes_validos INT DEFAULT 0;
    DECLARE v_finalizar BOOLEAN DEFAULT FALSE; -- Bandera para controlar la finalización

    -- Inicializar resultado
    SET resultado = 0;

    -- Verificar si el usuario existe
    SELECT COUNT(*) INTO v_usuario_existente
    FROM usuario
    WHERE PK_ID_USUARIO = p_usuario_id;

    IF v_usuario_existente = 0 THEN
        SET mensaje = 'El usuario no existe.';
        SET v_finalizar = TRUE;
    END IF;

    -- Si no hay errores, continuar
    IF NOT v_finalizar THEN
        -- Obtener el costo de la membresía
        SELECT COSTO INTO v_costo
        FROM tipo_membresia
        WHERE PK_ID_TIPO_MEMBRESIA = p_tipo_membresia_id;

        -- Verificar si la membresía existe
        IF v_costo IS NULL THEN
            SET mensaje = 'La membresía especificada no existe.';
            SET v_finalizar = TRUE;
        END IF;
    END IF;

    -- Si no hay errores, validar el código de recomendación
    IF NOT v_finalizar AND p_codigo_referido IS NOT NULL THEN
        -- Obtener el ID del dueño del código de recomendación
        SELECT PK_ID_USUARIO INTO v_dueno_codigo_id
        FROM usuario u
        INNER JOIN persona p ON u.FK_ID_PERSONA = p.PK_ID_PERSONA
        WHERE p.CODIGO_REFERIDO = p_codigo_referido;

        -- Validar si el código de recomendación existe
        IF v_dueno_codigo_id IS NULL THEN
            SET mensaje = 'El código de recomendación no es válido.';
            SET v_finalizar = TRUE;
        END IF;

        -- Si el código es válido, registrar la referencia y actualizar contadores
        IF NOT v_finalizar THEN
            INSERT INTO referencias (FK_ID_DUENO_CODIGO, FK_ID_CLIENTE_REFERIDO, MEMBRESIA_COMPRADA)
            VALUES (v_dueno_codigo_id, p_usuario_id, TRUE);

            UPDATE usuario
            SET CLIENTES_REFERIDOS_TOTAL = CLIENTES_REFERIDOS_TOTAL + 1,
                CLIENTES_REFERIDOS_VALIDOS = CASE
                    WHEN CLIENTES_REFERIDOS_VALIDOS < 10 THEN CLIENTES_REFERIDOS_VALIDOS + 1
                    ELSE CLIENTES_REFERIDOS_VALIDOS
                END
            WHERE PK_ID_USUARIO = v_dueno_codigo_id;

            -- Verificar si el dueño alcanzó los 10 clientes válidos
            SELECT CLIENTES_REFERIDOS_VALIDOS INTO v_clientes_validos
            FROM usuario
            WHERE PK_ID_USUARIO = v_dueno_codigo_id;

            IF v_clientes_validos >= 10 THEN
                UPDATE usuario
                SET CLIENTES_REFERIDOS_VALIDOS = 0,
                    DESCUENTOS_ACUMULADOS = DESCUENTOS_ACUMULADOS + 1,
                    FECHA_ULTIMO_DESCUENTO = NOW()
                WHERE PK_ID_USUARIO = v_dueno_codigo_id;
            END IF;

            SET v_codigo_valido = TRUE;
        END IF;
    END IF;

    -- Si no hay errores, calcular el descuento y registrar el pago
    IF NOT v_finalizar THEN
        IF p_codigo_referido IS NOT NULL AND v_codigo_valido THEN
            SET v_descuento = v_costo * 0.10;  -- 10% de descuento
        ELSE
            SET v_descuento = 0;
        END IF;

        -- Calcular el monto final con descuento
        SET v_monto_final = v_costo - v_descuento;

        -- Registrar el pago en la tabla pagos
        INSERT INTO pagos (
            FK_ID_USUARIO, FK_ID_TIPO_MEMBRESIA, MONTO, MONTO_CON_DESCUENTO, CODIGO_REFERIDO, ESTADO_PAGO, FECHA_PAGO
        ) VALUES (
            p_usuario_id, p_tipo_membresia_id, v_costo, v_monto_final, p_codigo_referido, 'CONFIRMADO', NOW()
        );

        -- Configurar mensaje
        SET mensaje = CONCAT('El pago ha sido registrado correctamente. Monto final: ', v_monto_final);
        SET resultado = 1;
    END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.recuperar_contrasenia
DELIMITER //
CREATE PROCEDURE `recuperar_contrasenia`(
    IN `p_id_usuario` INT,
    IN `p_nueva_contrasenia` MEDIUMTEXT
)
BEGIN
    DECLARE v_resultado INT DEFAULT 0;
    DECLARE v_mensaje VARCHAR(255);

    -- Verificar si el usuario existe
    IF NOT EXISTS (SELECT 1 FROM usuario WHERE PK_ID_USUARIO = p_id_usuario) THEN
        SET v_resultado = -1;
        SET v_mensaje = 'Usuario no encontrado.';
    ELSEIF p_nueva_contrasenia IS NULL OR LENGTH(p_nueva_contrasenia) < 8 THEN
        SET v_resultado = -2;
        SET v_mensaje = 'La contraseña debe tener al menos 8 caracteres.';
    ELSE
        -- Actualizar la contraseña e invalidar el token
        UPDATE usuario
        SET CONTRASENIA = p_nueva_contrasenia,
            TOKEN_RECUPERACION = NULL,
            FECHA_EXPIRACION_TOKEN = NULL,
            INTENTOS_RECUPERACION = 0,
            INTENTOS_FALLIDOS = 0,
            ESTADO = 1,
            FECHA_BLOQUEO = NULL
        WHERE PK_ID_USUARIO = p_id_usuario;

        SET v_resultado = 1;
        SET v_mensaje = 'Contraseña actualizada exitosamente.';
    END IF;

    SELECT v_resultado AS resultado, v_mensaje AS mensaje;
END//
DELIMITER ;

-- Volcando estructura para tabla abastecete.referencias
CREATE TABLE IF NOT EXISTS `referencias` (
  `PK_ID_REFERENCIA` int NOT NULL AUTO_INCREMENT,
  `FK_ID_DUENO_CODIGO` int NOT NULL,
  `FK_ID_CLIENTE_REFERIDO` int NOT NULL,
  `MEMBRESIA_COMPRADA` tinyint(1) DEFAULT '0',
  `FECHA_REFERENCIA` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`PK_ID_REFERENCIA`),
  KEY `FK_ID_DUENO_CODIGO` (`FK_ID_DUENO_CODIGO`),
  KEY `FK_ID_CLIENTE_REFERIDO` (`FK_ID_CLIENTE_REFERIDO`),
  CONSTRAINT `referencias_ibfk_1` FOREIGN KEY (`FK_ID_DUENO_CODIGO`) REFERENCES `usuario` (`PK_ID_USUARIO`),
  CONSTRAINT `referencias_ibfk_2` FOREIGN KEY (`FK_ID_CLIENTE_REFERIDO`) REFERENCES `usuario` (`PK_ID_USUARIO`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Volcando datos para la tabla abastecete.referencias: ~0 rows (aproximadamente)

-- Volcando estructura para procedimiento abastecete.registrar_pago
DELIMITER //
CREATE PROCEDURE `registrar_pago`(
	IN `p_id_usuario` INT,
	IN `p_id_tipo_membresia` INT,
	IN `p_nombre` VARCHAR(100),
	IN `p_apellidos` VARCHAR(100),
	IN `p_empresa` VARCHAR(100),
	IN `p_direccion` VARCHAR(100),
	IN `p_departamento` VARCHAR(100),
	IN `p_municipio` VARCHAR(100),
	IN `p_telefono` VARCHAR(100),
	IN `p_correo` VARCHAR(100),
	IN `p_monto` DECIMAL(20,6)
)
BEGIN
	INSERT INTO pagos (
        FK_ID_USUARIO,
        FK_ID_TIPO_MEMBRESIA,
        NOMBRE,
        APELLIDOS,
        EMPRESA,
        DIRECCION,
        DEPARTAMENTO,
        MUNICIPIO,
        TELEFONO,
        CORREO,
        MONTO,
        ESTADO_PAGO,
        FECHA_PAGO
    ) VALUES (
        p_id_usuario,
        p_id_tipo_membresia,
        p_nombre,
        p_apellidos,
        p_empresa,
        p_direccion,
        p_departamento,
        p_municipio,
        p_telefono,
        p_correo,
        p_monto,
        'PENDIENTE',
        NOW()
    );
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.registrar_referencia
DELIMITER //
CREATE PROCEDURE `registrar_referencia`(
    IN p_cliente_id INT,                  -- ID del cliente que usa el código
    IN p_codigo_referido VARCHAR(20),     -- Código de recomendación ingresado
    IN p_membresia_comprada BOOLEAN,      -- Si el cliente compró una membresía
    OUT mensaje VARCHAR(500),             -- Mensaje de resultado
    OUT resultado INT                     -- Resultado (0 = fallo, 1 = éxito)
)
BEGIN
    DECLARE v_dueno_codigo_id INT;
    DECLARE v_clientes_validos INT;
    DECLARE v_finalizar BOOLEAN DEFAULT FALSE; -- Bandera para controlar la terminación

    -- Inicializar el resultado
    SET resultado = 0;

    -- Obtener el dueño del código de recomendación
    SELECT PK_ID_USUARIO INTO v_dueno_codigo_id
    FROM usuario u
    INNER JOIN persona p ON u.FK_ID_PERSONA = p.PK_ID_PERSONA
    WHERE p.CODIGO_REFERIDO = p_codigo_referido;

    -- Validar si el código existe
    IF v_dueno_codigo_id IS NULL THEN
        SET mensaje = 'El código de recomendación no es válido.';
        SET v_finalizar = TRUE;
    END IF;

    -- Si no hay errores, registrar la referencia
    IF NOT v_finalizar THEN
        INSERT INTO referencias (FK_ID_DUENO_CODIGO, FK_ID_CLIENTE_REFERIDO, MEMBRESIA_COMPRADA)
        VALUES (v_dueno_codigo_id, p_cliente_id, p_membresia_comprada);

        -- Si el cliente no compró membresía, actualizar clientes referidos válidos
        IF NOT p_membresia_comprada THEN
            -- Incrementar el conteo de clientes referidos válidos
            UPDATE usuario
            SET CLIENTES_REFERIDOS_VALIDOS = CLIENTES_REFERIDOS_VALIDOS + 1
            WHERE PK_ID_USUARIO = v_dueno_codigo_id;

            -- Verificar si el dueño alcanzó 10 clientes referidos
            SELECT CLIENTES_REFERIDOS_VALIDOS INTO v_clientes_validos
            FROM usuario
            WHERE PK_ID_USUARIO = v_dueno_codigo_id;

            IF v_clientes_validos >= 10 THEN
                -- Resetear los clientes válidos y actualizar el descuento
                UPDATE usuario
                SET CLIENTES_REFERIDOS_VALIDOS = 0,
                    DESCUENTOS_ACUMULADOS = DESCUENTOS_ACUMULADOS + 1,
                    FECHA_ULTIMO_DESCUENTO = NOW()
                WHERE PK_ID_USUARIO = v_dueno_codigo_id;

                SET mensaje = 'El dueño del código tiene 10 clientes referidos válidos y puede obtener un descuento.';
            ELSE
                SET mensaje = CONCAT('Referencia registrada. El dueño del código tiene ', v_clientes_validos, ' clientes referidos válidos.');
            END IF;
        ELSE
            -- Si el cliente compró una membresía, aplicar el descuento directamente
            SET mensaje = 'Referencia registrada. Descuento aplicado al dueño del código.';
        END IF;

        SET resultado = 1;
    END IF;
END//
DELIMITER ;

-- Volcando estructura para evento abastecete.resetear_intentos_fallidos
DELIMITER //
CREATE EVENT `resetear_intentos_fallidos` ON SCHEDULE EVERY 5 MINUTE STARTS '2025-02-05 18:54:55' ON COMPLETION NOT PRESERVE ENABLE DO BEGIN
    UPDATE usuario
    SET INTENTOS_FALLIDOS = 0
    WHERE INTENTOS_FALLIDOS > 0;
END//
DELIMITER ;

-- Volcando estructura para tabla abastecete.rol
CREATE TABLE IF NOT EXISTS `rol` (
  `PK_ID_ROL` int NOT NULL AUTO_INCREMENT,
  `NOMBRE_ROL` varchar(20) NOT NULL,
  PRIMARY KEY (`PK_ID_ROL`)
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Volcando datos para la tabla abastecete.rol: ~4 rows (aproximadamente)
INSERT INTO `rol` (`PK_ID_ROL`, `NOMBRE_ROL`) VALUES
	(1, 'Administrador'),
	(2, 'Proveedor'),
	(3, 'Cliente'),
	(7, 'Prueba'),
	(8, 'Director de Proyecto');

-- Volcando estructura para tabla abastecete.sub_categoria
CREATE TABLE IF NOT EXISTS `sub_categoria` (
  `PK_ID_SUB_CATEGORIA` int NOT NULL AUTO_INCREMENT,
  `FK_ID_CATEGORIA` int NOT NULL,
  `NOMBRE_SUB_CATEGORIA` varchar(100) NOT NULL,
  `ESTADO_SUB_CATEGORIA` tinyint NOT NULL DEFAULT '1',
  PRIMARY KEY (`PK_ID_SUB_CATEGORIA`),
  KEY `FK_sub_categoria_categoria` (`FK_ID_CATEGORIA`),
  CONSTRAINT `FK_sub_categoria_categoria` FOREIGN KEY (`FK_ID_CATEGORIA`) REFERENCES `categoria` (`PK_ID_CATEGORIA`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=63 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Volcando datos para la tabla abastecete.sub_categoria: ~62 rows (aproximadamente)
INSERT INTO `sub_categoria` (`PK_ID_SUB_CATEGORIA`, `FK_ID_CATEGORIA`, `NOMBRE_SUB_CATEGORIA`, `ESTADO_SUB_CATEGORIA`) VALUES
	(1, 4, 'Frutas frescas', 1),
	(2, 4, 'Verduras frescas', 1),
	(3, 4, 'Hierbas y especias frescas', 1),
	(4, 4, 'Tubérculos y raíces', 1),
	(5, 5, 'Carnes de res', 1),
	(6, 5, 'Carnes de cerdo', 1),
	(7, 5, 'Carnes de pollo', 1),
	(8, 5, 'Pescados y mariscos', 1),
	(9, 5, 'Carnes procesadas', 1),
	(10, 6, 'Leche y derivados', 1),
	(11, 6, 'Quesos y cuajadas', 1),
	(12, 6, 'Yogurt y bebidas lácteas', 1),
	(13, 6, 'Mantequilla y margarinas', 1),
	(14, 6, 'Huevos', 1),
	(15, 7, 'Pan fresco y artesanal', 1),
	(16, 7, 'Panadería empacada', 1),
	(17, 7, 'Tortas y postres frescos', 1),
	(18, 7, 'Repostería industrial', 1),
	(19, 8, 'Arroz, granos y legumbres', 1),
	(20, 8, 'Pastas y harinas', 1),
	(21, 8, 'Aceites y vinagres', 1),
	(22, 8, 'Salsas y condimentos', 1),
	(23, 8, 'Café y bebidas calientes', 1),
	(24, 8, 'Conservas y enlatados', 1),
	(25, 8, 'Cereales y granolas', 1),
	(26, 8, 'Azúcar, endulzantes y sal', 1),
	(27, 9, 'Verduras y tubérculos congelados', 1),
	(28, 9, 'Comidas listas para calentar', 1),
	(29, 9, 'Pasabocas congelados', 1),
	(30, 9, 'Helados y postres congelados', 1),
	(31, 10, 'Gaseosas y sodas', 1),
	(32, 10, 'Jugos y zumos', 1),
	(33, 10, 'Agua embotellada y té', 1),
	(34, 10, 'Bebidas isotónicas y energizantes', 1),
	(35, 11, 'Pasabocas empacados', 1),
	(36, 11, 'Frutos secos y semillas', 1),
	(37, 11, 'Galletas dulces y saladas', 1),
	(38, 12, 'Chocolatería fina', 1),
	(39, 12, 'Confitería', 1),
	(40, 12, 'Arequipe y derivados lácteos dulces', 1),
	(41, 12, 'Chicles y masticables', 1),
	(42, 13, 'Quesos madurados y gourmet', 1),
	(43, 13, 'Carnes curadas y especiales', 1),
	(44, 13, 'Encurtidos, conservas y patés', 1),
	(45, 14, 'Jabones y detergentes', 1),
	(46, 14, 'Limpiadores multiusos', 1),
	(47, 14, 'Papel higiénico y servilletas', 1),
	(48, 14, 'Ambientadores y control de plagas', 1),
	(49, 14, 'Implementos de limpieza', 1),
	(50, 15, 'Cuidado capilar', 1),
	(51, 15, 'Cuidado facial y corporal', 1),
	(52, 15, 'Higiene íntima', 1),
	(53, 15, 'Higiene para bebés y niños', 1),
	(54, 15, 'Bienestar sexual', 1),
	(55, 15, 'Protección solar y repelentes', 1),
	(56, 15, 'Salud y medicamentos', 1),
	(57, 16, 'Cervezas', 1),
	(58, 16, 'Vinos', 1),
	(59, 16, 'Whisky y ron', 1),
	(60, 16, 'Tequilas y otros destilados', 1),
	(61, 16, 'Coctelería', 1),
	(62, 16, 'Cigarrillos y vapeadores', 1);

-- Volcando estructura para tabla abastecete.tipo_documento
CREATE TABLE IF NOT EXISTS `tipo_documento` (
  `PK_ID_TIPO_DOCUMENTO` int NOT NULL AUTO_INCREMENT,
  `NOMBRE_TIPO_DOCUMENTO` varchar(50) NOT NULL,
  PRIMARY KEY (`PK_ID_TIPO_DOCUMENTO`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Volcando datos para la tabla abastecete.tipo_documento: ~4 rows (aproximadamente)
INSERT INTO `tipo_documento` (`PK_ID_TIPO_DOCUMENTO`, `NOMBRE_TIPO_DOCUMENTO`) VALUES
	(1, 'CC'),
	(2, 'CE'),
	(3, 'TI'),
	(4, 'PAS');

-- Volcando estructura para tabla abastecete.tipo_membresia
CREATE TABLE IF NOT EXISTS `tipo_membresia` (
  `PK_ID_TIPO_MEMBRESIA` int NOT NULL AUTO_INCREMENT,
  `NOMBRE` varchar(50) NOT NULL,
  `DESCRIPCION` text,
  `COSTO` int NOT NULL DEFAULT '0',
  `ESTADO` tinyint DEFAULT '1',
  `DURACION_OFERTA` int DEFAULT '0',
  `COSTO_TRIMESTRAL` int DEFAULT '0',
  `COSTO_SEMESTRAL` int DEFAULT '0',
  `COSTO_ANUAL` int DEFAULT '0',
  `CANTIDAD_PRODUCTOS` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`PK_ID_TIPO_MEMBRESIA`)
) ENGINE=InnoDB AUTO_INCREMENT=20 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Volcando datos para la tabla abastecete.tipo_membresia: ~9 rows (aproximadamente)
INSERT INTO `tipo_membresia` (`PK_ID_TIPO_MEMBRESIA`, `NOMBRE`, `DESCRIPCION`, `COSTO`, `ESTADO`, `DURACION_OFERTA`, `COSTO_TRIMESTRAL`, `COSTO_SEMESTRAL`, `COSTO_ANUAL`, `CANTIDAD_PRODUCTOS`) VALUES
	(11, 'Plan Proveedor Básico', '* Publicación de hasta 10 productos.\r\n* Perfil de proveedor con información de contacto.\r\n* Estadísticas básicas de visualización.\r\n* Posicionamiento orgánico en la búsqueda.\r\n* 5% de descuento en add-on de producción de contenido visual.', 0, 1, 6, 0, 0, 0, '10'),
	(12, 'Plan Cultivador Básico', '* Publicación de hasta 1 producto.\r\n* Perfil de cultivador con información de contacto y ubicación.\r\n* Estadísticas básicas de visualización.\r\n* Posicionamiento orgánico en la búsqueda.\r\n* 5% de descuento en add-on de producción de contenido visual.', 0, 1, 6, 0, 0, 0, '1'),
	(13, 'Plan Empresa Básico', '* Publicación de hasta 50 productos.\r\n* Perfil empresarial con datos de contacto y ubicación.\r\n* Estadísticas básicas de visualización y clics.\r\n* Posicionamiento orgánico en la búsqueda.\r\n* 5% de descuento en add-ons de producción de contenido visual.', 0, 1, 6, 0, 0, 0, '50'),
	(14, 'Plan Proveedor Pro ', '* Publicación de hasta 30 productos.\r\n* 3 productos destacados en la sección de "Ofertas Flash" por mes.\r\n* Estadísticas avanzadas con datos de visualización y clics.\r\n* Prioridad media en los resultados de búsqueda.\r\n* Integración con redes sociales y sitio web.\r\n* Acceso a promociones y eventos exclusivos.\r\n* 10% de descuento en add-on de producción de contenido visual.', 50000, 1, 12, 135000, 255000, 480000, '30'),
	(15, 'Plan Cultivador Pro ', '* Publicación de hasta 3 productos.\r\n* 2 productos destacados en la sección de "Ofertas Flash" por mes.\r\n* Estadísticas avanzadas con datos de visualización y clics.\r\n* Prioridad media en los resultados de búsqueda.\r\n* Redireccionamiento a redes sociales y sitio web. \r\n* Opción de mostrar certificaciones y sellos de calidad. \r\n* 10% de descuento en add-on de producción de contenido visual.', 50000, 1, 12, 135000, 255000, 480000, '3'),
	(16, 'Plan Empresa Pro', '* Publicación de hasta 150 productos.\r\n* 10 productos destacados en la sección de "Ofertas Flash" por mes.\r\n* Estadísticas avanzadas con datos de visualización y clics.\r\n* Prioridad media en los resultados de búsqueda.\r\n* Integración con redes sociales y sitio web.\r\n* Acceso a promociones y eventos exclusivos.\r\n* 10% de descuento en add-ons de producción de contenido visual.', 150000, 1, 12, 405000, 765000, 1440000, '150'),
	(17, 'Plan Proveedor Premium ', '* Publicación ilimitada de productos.\r\n* 10 productos destacados en la sección de "Ofertas Flash" por mes.\r\n* Posicionamiento prioritario en los resultados de búsqueda.\r\n* Publicidad en banners dentro de la página.\r\n* Acceso a analítica avanzada con tendencias de mercado.\r\n* Campañas de email marketing segmentadas.\r\n* Soporte premium y asesoramiento en estrategias de venta.\r\n* 25% de descuento en add-on de producción de contenido visual\r\n* Gestión de Sello de Verificación.', 100000, 1, 24, 270000, 510000, 960000, '0'),
	(18, 'Plan Cultivador Premium ', '* Publicación ilimitada de productos.\r\n* 5 productos destacados en la sección de "Ofertas Flash" por mes.\r\n* Posicionamiento prioritario en los resultados de búsqueda.\r\n* Publicidad en banners dentro de la página.\r\n* Acceso a analítica avanzada con tendencias de mercado. \r\n* Promoción destacada de cosechas y lotes a granel.\r\n* Campañas de email marketing segmentadas.\r\n* Soporte premium y asesoramiento en estrategias de venta.\r\n* 25% de descuento en add-on de producción de contenido visual.\r\n* Sello de Verificación.', 100000, 1, 24, 270000, 510000, 960000, '0'),
	(19, 'Plan Empresa Premium ', '* Publicación ilimitada de productos.\r\n* 20 productos destacados en la sección de "Ofertas Flash" por mes.\r\n* Posicionamiento prioritario en los resultados de búsqueda.\r\n* Publicidad en banners dentro de la plataforma.\r\n* Acceso a reportes avanzados de tendencias de mercado.\r\n* Campañas de email marketing segmentadas.\r\n* Soporte premium y asesoramiento en estrategias de compra.\r\n* Conexión directa con proveedores exclusivos.\r\n* 25% de descuento en add-ons de producción de contenido visual.', 300000, 1, 24, 810000, 1530000, 2880000, '0');

-- Volcando estructura para tabla abastecete.tipo_unidad
CREATE TABLE IF NOT EXISTS `tipo_unidad` (
  `ID_TIPOUNIDAD` int NOT NULL AUTO_INCREMENT,
  `NOMBRE_TIPOUNIDAD` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`ID_TIPOUNIDAD`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Volcando datos para la tabla abastecete.tipo_unidad: ~2 rows (aproximadamente)
INSERT INTO `tipo_unidad` (`ID_TIPOUNIDAD`, `NOMBRE_TIPOUNIDAD`) VALUES
	(1, 'Peso'),
	(2, 'Volumen'),
	(3, 'Unidad');

-- Volcando estructura para procedimiento abastecete.total_ofertas_flash_local
DELIMITER //
CREATE PROCEDURE `total_ofertas_flash_local`(
	IN `p_id_local` INT
)
BEGIN
    SELECT COUNT(*) 
    FROM oferta_flash
    INNER JOIN local ON oferta_flash.FK_ID_LOCAL = local.PK_ID_LOCAL
    INNER JOIN membresia_local ON membresia_local.FK_ID_LOCAL = local.PK_ID_LOCAL
    WHERE local.PK_ID_LOCAL = p_id_local
    AND NOW() BETWEEN membresia_local.FECHA_INICIO
	 AND membresia_local.FECHA_FIN
	 AND oferta_flash.ESTADO_OFERTA_FLASH != 2;
END//
DELIMITER ;

-- Volcando estructura para tabla abastecete.unidad
CREATE TABLE IF NOT EXISTS `unidad` (
  `ID_UNIDAD` int NOT NULL AUTO_INCREMENT,
  `NOMBRE_UNIDAD` varchar(50) NOT NULL,
  `ESTADO_UNIDAD` tinyint NOT NULL DEFAULT (1),
  `FK_ID_TIPOUNIDAD` int DEFAULT NULL,
  PRIMARY KEY (`ID_UNIDAD`),
  KEY `idx_unidad_tipo` (`FK_ID_TIPOUNIDAD`),
  KEY `idx_unidad_estado` (`ESTADO_UNIDAD`),
  KEY `idx_unidad_nombre` (`NOMBRE_UNIDAD`),
  CONSTRAINT `FK_Unidad_TipoUnidad` FOREIGN KEY (`FK_ID_TIPOUNIDAD`) REFERENCES `tipo_unidad` (`ID_TIPOUNIDAD`)
) ENGINE=InnoDB AUTO_INCREMENT=12 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Volcando datos para la tabla abastecete.unidad: ~9 rows (aproximadamente)
INSERT INTO `unidad` (`ID_UNIDAD`, `NOMBRE_UNIDAD`, `ESTADO_UNIDAD`, `FK_ID_TIPOUNIDAD`) VALUES
	(1, 'lb', 1, 1),
	(2, 'Kg', 1, 1),
	(4, 'L', 1, 2),
	(5, 'mL', 1, 2),
	(6, 'gr', 1, 1),
	(8, 'oz', 1, 2),
	(9, 'gal', 1, 2),
	(10, 'Unidad', 1, 3),
	(11, 'Docena', 1, 3);

-- Volcando estructura para tabla abastecete.usuario
CREATE TABLE IF NOT EXISTS `usuario` (
  `PK_ID_USUARIO` int NOT NULL AUTO_INCREMENT,
  `FK_ID_PERSONA` int NOT NULL,
  `FK_ID_ROL` int NOT NULL,
  `FK_ID_MEMBRESIA` int DEFAULT NULL,
  `NOMBRE_USUARIO` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `CONTRASENIA` mediumtext CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `TOKEN_RECUPERACION` varchar(255) DEFAULT NULL,
  `FECHA_EXPIRACION_TOKEN` datetime DEFAULT NULL,
  `TIPO_AUTENTICACION` int DEFAULT NULL,
  `INTENTOS_FALLIDOS` tinyint DEFAULT '0',
  `FECHA_BLOQUEO` datetime DEFAULT NULL,
  `CORREO_VERIFICADO` tinyint unsigned DEFAULT '0',
  `ESTADO` tinyint NOT NULL DEFAULT '1' COMMENT '1 = Activo, 0 = Inactivo',
  `CLIENTES_REFERIDOS_TOTAL` int DEFAULT '0',
  `INTENTOS_RECUPERACION` int DEFAULT '0',
  `FECHA_ULTIMO_INTENTO_RECUPERACION` datetime DEFAULT NULL,
  PRIMARY KEY (`PK_ID_USUARIO`),
  UNIQUE KEY `UQ_NOMBRE_USUARIO` (`NOMBRE_USUARIO`),
  KEY `FK_usuario_persona` (`FK_ID_PERSONA`),
  KEY `FK_usuario_rol` (`FK_ID_ROL`),
  KEY `FK_usuario_membresia` (`FK_ID_MEMBRESIA`),
  KEY `FK_usuario_tipo_autenticacion` (`TIPO_AUTENTICACION`),
  KEY `idx_usuario_nombre_usuario` (`NOMBRE_USUARIO`),
  KEY `idx_usuario_token` (`TOKEN_RECUPERACION`),
  KEY `idx_usuario_bloqueo` (`ESTADO`,`FECHA_BLOQUEO`),
  CONSTRAINT `FK_usuario_membresia` FOREIGN KEY (`FK_ID_MEMBRESIA`) REFERENCES `membresia_local` (`PK_ID_MEMBRESIA`),
  CONSTRAINT `FK_usuario_persona` FOREIGN KEY (`FK_ID_PERSONA`) REFERENCES `persona` (`PK_ID_PERSONA`),
  CONSTRAINT `FK_usuario_rol` FOREIGN KEY (`FK_ID_ROL`) REFERENCES `rol` (`PK_ID_ROL`),
  CONSTRAINT `FK_usuario_tipo_autenticacion` FOREIGN KEY (`TIPO_AUTENTICACION`) REFERENCES `metodo_autenticacion` (`PK_ID_METODO_AUTENTICACION`)
) ENGINE=InnoDB AUTO_INCREMENT=53 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Volcando datos para la tabla abastecete.usuario: ~26 rows (aproximadamente)
INSERT INTO `usuario` (`PK_ID_USUARIO`, `FK_ID_PERSONA`, `FK_ID_ROL`, `FK_ID_MEMBRESIA`, `NOMBRE_USUARIO`, `CONTRASENIA`, `TOKEN_RECUPERACION`, `FECHA_EXPIRACION_TOKEN`, `TIPO_AUTENTICACION`, `INTENTOS_FALLIDOS`, `FECHA_BLOQUEO`, `CORREO_VERIFICADO`, `ESTADO`, `CLIENTES_REFERIDOS_TOTAL`, `INTENTOS_RECUPERACION`, `FECHA_ULTIMO_INTENTO_RECUPERACION`) VALUES
	(2, 2, 1, 2, 'kevin12@gmail.com', 'stCAUXlvlTCDOFCW3+AFGw==', NULL, NULL, 1, 0, NULL, 0, 1, 0, 0, NULL),
	(4, 4, 1, 2, 'sebastian@gmail.com', 'MApNL/Xu9KjSguqWMlk1aA==', NULL, NULL, 1, 0, NULL, 0, 1, 0, 0, NULL),
	(5, 5, 3, 2, 'yoiner@gmail.com', 'k61Us9qfNYtvCy6F/XOgoA==', NULL, NULL, 1, 0, NULL, 0, 1, 0, 0, NULL),
	(6, 6, 3, 2, 'ledes@gmail.com', 'urhs6MFsrUJFRJwthrYYcQ==', NULL, NULL, 1, 0, NULL, 0, 1, 0, 0, NULL),
	(7, 7, 1, 2, 'andres@gmail.com', 'kzWvH2roKKCxJWi2nOZhvQ==', NULL, NULL, 1, 0, NULL, 0, 1, 0, 0, NULL),
	(12, 12, 2, 2, 'yoiner.mh04@gmail.com', 'xOBcl5JnPT+4p9sI5fpiGQ==', 'f7917a01-efcf-11ef-8a42-00155d007000', '2025-02-20 16:21:36', 2, 0, NULL, 0, 1, 0, 0, NULL),
	(23, 23, 1, NULL, 'johans.ramirez@udla.edu.co', 'BGpwluhHTW0TzB09JfYwqw==', NULL, NULL, 1, 0, NULL, 0, 1, 0, 0, NULL),
	(24, 24, 3, NULL, 'da.navia@udla.edu.co', 'BGpwluhHTW0TzB09JfYwqw==', 'dc9ff21a-0687-11f0-806b-d843ae9e6717', '2025-03-21 14:13:24', 1, 0, NULL, 0, 1, 0, 0, NULL),
	(25, 25, 2, 2, 'johan05182002.com@gmail.com', 'BGpwluhHTW0TzB09JfYwqw==', NULL, NULL, 1, 0, NULL, 0, 1, 0, 0, NULL),
	(26, 26, 3, NULL, 'armuca@gmail.com', 'BGpwluhHTW0TzB09JfYwqw==', NULL, NULL, 1, 0, NULL, 0, 1, 0, 0, NULL),
	(27, 27, 3, NULL, 'c@gmail.com', 'BGpwluhHTW0TzB09JfYwqw==', NULL, NULL, 1, 0, NULL, 0, 1, 0, 0, NULL),
	(30, 30, 2, NULL, 'may13xd@gmail.com', 'zTLp/d8kn9F+qgWExhUrfA==', NULL, NULL, 1, 0, NULL, 0, 1, 0, 0, NULL),
	(31, 31, 3, NULL, 'juandavidloquendero@gmail.com', 'QhuouUOvL0DiHxB8XrQeUg==', NULL, NULL, 1, 0, NULL, 0, 1, 0, 0, NULL),
	(32, 32, 3, NULL, 'h@gmail.com', 'zTLp/d8kn9F+qgWExhUrfA==', NULL, NULL, 1, 0, NULL, 0, 1, 0, 0, NULL),
	(33, 33, 3, NULL, 'osnidio@yopmail.com', 'HJjNmQMNUaeX2PxRK2lTPg==', '6964cb39-15b9-11f0-9953-e688b28ab077', '2025-04-10 03:15:52', 1, 0, NULL, 0, 1, 0, 0, NULL),
	(34, 34, 2, NULL, 'l@gmail.com', 'zTLp/d8kn9F+qgWExhUrfA==', NULL, NULL, 1, 0, NULL, 0, 1, 0, 0, NULL),
	(35, 35, 3, NULL, 'sdfdsfsdf@d', 'bzmmZWxCrQlFMzRWXnqfTA==', '781dfc63-1026-11f0-9953-e688b28ab077', '2025-04-03 01:01:25', 1, 0, NULL, 0, 1, 0, 0, NULL),
	(36, 36, 2, NULL, 'andrestrujillo20166@gmail.com', '7CP2YJdKY1Z9UU+Bb+ESMQ==', NULL, NULL, 1, 0, NULL, 0, 1, 0, 0, NULL),
	(37, 37, 2, NULL, 'hola@gmail.com', 'y3rFyft55CWVYwszuPNHUA==', NULL, NULL, 1, 0, NULL, 0, 1, 0, 0, NULL),
	(38, 38, 2, NULL, 'hola1@gmail.com', 'y3rFyft55CWVYwszuPNHUA==', NULL, NULL, 1, 0, NULL, 0, 1, 0, 0, NULL),
	(39, 39, 3, NULL, 'hola2@gmail.com', 'y3rFyft55CWVYwszuPNHUA==', NULL, NULL, 1, 0, NULL, 0, 1, 0, 0, NULL),
	(40, 40, 2, NULL, 'hola4@gmail.com', 'YQn/NzNFobs1CxYU0g9iTQ==', NULL, NULL, 1, 0, NULL, 0, 1, 0, 0, NULL),
	(49, 49, 3, NULL, 'atekegran@gmail.com', 'stCAUXlvlTCDOFCW3+AFGw==', NULL, NULL, 2, 0, NULL, 0, 1, 0, 0, NULL),
	(50, 50, 2, 34, 'sebsirra13@gmail.com', 'stCAUXlvlTCDOFCW3+AFGw==', NULL, NULL, 2, 0, NULL, 0, 1, 0, 0, NULL),
	(51, 51, 2, NULL, 'websencol@gmail.com', 'stCAUXlvlTCDOFCW3+AFGw==', NULL, NULL, 2, 0, NULL, 0, 1, 0, 0, NULL),
	(52, 52, 3, NULL, 'dananabia2000@gmail.com', 'stCAUXlvlTCDOFCW3+AFGw==', NULL, NULL, 2, 0, NULL, 0, 1, 0, 0, NULL);

-- Volcando estructura para procedimiento abastecete.validar_token_recuperacion
DELIMITER //
CREATE PROCEDURE `validar_token_recuperacion`(IN p_token VARCHAR(255))
BEGIN
    DECLARE v_id_usuario INT DEFAULT NULL;
    DECLARE v_fecha_expiracion DATETIME;

    -- Buscar el usuario por token
    SELECT PK_ID_USUARIO, FECHA_EXPIRACION_TOKEN
    INTO v_id_usuario, v_fecha_expiracion
    FROM usuario
    WHERE TOKEN_RECUPERACION = p_token
    LIMIT 1;

    -- Verificar si el token existe y no ha expirado
    IF v_id_usuario IS NULL THEN
        SELECT
            NULL AS PK_ID_USUARIO,
            -1 AS resultado,
            'Token no encontrado.' AS mensaje;
    ELSEIF v_fecha_expiracion <= NOW() THEN
        -- Limpiar token expirado
        UPDATE usuario
        SET TOKEN_RECUPERACION = NULL, FECHA_EXPIRACION_TOKEN = NULL
        WHERE PK_ID_USUARIO = v_id_usuario;

        SELECT
            NULL AS PK_ID_USUARIO,
            -2 AS resultado,
            'El código ha expirado. Solicita uno nuevo.' AS mensaje;
    ELSE
        SELECT
            v_id_usuario AS PK_ID_USUARIO,
            1 AS resultado,
            'Token válido.' AS mensaje;
    END IF;
END//
DELIMITER ;

-- Volcando estructura para disparador abastecete.asignar_categoria_local
SET @OLDTMP_SQL_MODE=@@SQL_MODE, SQL_MODE='ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';
DELIMITER //
CREATE TRIGGER `asignar_categoria_local` AFTER INSERT ON `productoslocal` FOR EACH ROW BEGIN
	DECLARE idcategoria INT DEFAULT NULL;

	-- Intentar obtener la categoría de forma segura
	SELECT c.PK_ID_CATEGORIA
	INTO idcategoria
	FROM producto p
	INNER JOIN sub_categoria sc ON p.FK_ID_SUB_CATEGORIA = sc.PK_ID_SUB_CATEGORIA
	INNER JOIN categoria c ON sc.FK_ID_CATEGORIA = c.PK_ID_CATEGORIA
	WHERE p.PK_ID_PRODUCTO = NEW.FK_ID_PRODUCTO
	LIMIT 1;

	-- Solo insertar si se obtuvo una categoría válida
	IF idcategoria IS NOT NULL THEN
		IF NOT EXISTS (
			SELECT 1 FROM localcategoria
			WHERE FK_ID_CATEGORIA = idcategoria
			  AND FK_ID_LOCAL = NEW.FK_ID_LOCAL
		) THEN
			INSERT INTO localcategoria (FK_ID_LOCAL, FK_ID_CATEGORIA)
			VALUES (NEW.FK_ID_LOCAL, idcategoria);
		END IF;
	END IF;
END//
DELIMITER ;
SET SQL_MODE=@OLDTMP_SQL_MODE;

/*!40103 SET TIME_ZONE=IFNULL(@OLD_TIME_ZONE, 'system') */;
/*!40101 SET SQL_MODE=IFNULL(@OLD_SQL_MODE, '') */;
/*!40014 SET FOREIGN_KEY_CHECKS=IFNULL(@OLD_FOREIGN_KEY_CHECKS, 1) */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40111 SET SQL_NOTES=IFNULL(@OLD_SQL_NOTES, 1) */;
