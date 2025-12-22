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

-- Volcando estructura para procedimiento abastecete.activar_marca
DELIMITER //
CREATE PROCEDURE `activar_marca`(
    IN `p_id` INT,
    OUT `mensaje` VARCHAR(255),
    OUT `resultado` INT
)
BEGIN
    DECLARE existe INT DEFAULT 0;

    SELECT COUNT(*) INTO existe FROM marca WHERE PK_ID_MARCA = p_id;

    IF existe = 0 THEN
        SET mensaje = 'Marca no encontrada';
        SET resultado = 0;
    ELSE
        UPDATE marca SET ACTIVO = 1 WHERE PK_ID_MARCA = p_id;
        SET mensaje = 'Marca activada exitosamente';
        SET resultado = 1;
    END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.actualizar_banner
DELIMITER //
CREATE PROCEDURE `actualizar_banner`(
    IN `p_id` INT,
    IN `p_cloudinary_url` VARCHAR(500),
    IN `p_cloudinary_public_id` VARCHAR(255),
    OUT `mensaje` VARCHAR(255),
    OUT `resultado` INT
)
BEGIN
    DECLARE existe INT DEFAULT 0;

    SELECT COUNT(*) INTO existe FROM banner WHERE PK_ID_BANNER = p_id;

    IF existe = 0 THEN
        SET mensaje = 'Banner no encontrado';
        SET resultado = 0;
    ELSE
        UPDATE banner
        SET CLOUDINARY_URL = p_cloudinary_url,
            CLOUDINARY_PUBLIC_ID = p_cloudinary_public_id,
            FECHA_REGISTRO = NOW()
        WHERE PK_ID_BANNER = p_id;

        SET mensaje = 'Banner actualizado exitosamente';
        SET resultado = 1;
    END IF;
END//
DELIMITER ;

-- Volcando estructura para evento abastecete.actualizar_estado_suscripcion
DELIMITER //
CREATE EVENT `actualizar_estado_suscripcion` ON SCHEDULE EVERY 1 HOUR STARTS '2025-12-20 19:46:20' ON COMPLETION PRESERVE ENABLE DO BEGIN
    -- Cambiar el estado a 0 (inactivo) si la FECHA_FIN es menor que la fecha actual
    UPDATE suscripcion
    SET ESTADO = 0
    WHERE FECHA_FIN < NOW() AND ESTADO = 1;

    -- Log para seguimiento
    INSERT INTO logs_sistema (MODULO, ACCION, DESCRIPCION, FECHA_REGISTRO)
    VALUES ('SUSCRIPCIONES', 'AUTO_UPDATE',
            CONCAT('Suscripciones vencidas actualizadas a inactivas: ', ROW_COUNT()),
            NOW());
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

-- Volcando estructura para procedimiento abastecete.agregar_imagen_galeria
DELIMITER //
CREATE PROCEDURE `agregar_imagen_galeria`(
    IN p_id_local INT,
    IN p_cloudinary_url VARCHAR(500),
    IN p_cloudinary_public_id VARCHAR(255)
)
BEGIN
    INSERT INTO galeria_local (FK_ID_LOCAL, CLOUDINARY_URL, CLOUDINARY_PUBLIC_ID, ESTADO, FECHA_SUBIDA)
    VALUES (p_id_local, p_cloudinary_url, p_cloudinary_public_id, 0, NOW());

    SELECT LAST_INSERT_ID() AS id_galeria;
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
    DECLARE v_total INT DEFAULT 0;
    DECLARE v_max INT DEFAULT 0;

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
    DECLARE intervalo INT DEFAULT 24; -- Valor por defecto: 24 horas

    -- Obtener duración de oferta desde la suscripción activa del local
    SELECT COALESCE(tm.DURACION_OFERTA, 24) INTO intervalo
    FROM oferta_flash ofl
    INNER JOIN local l ON ofl.FK_ID_LOCAL = l.PK_ID_LOCAL
    LEFT JOIN suscripcion s ON l.FK_ID_SUSCRIPCION_ACTIVA = s.PK_ID_SUSCRIPCION AND s.ESTADO = 1
    LEFT JOIN tipo_membresia tm ON s.FK_ID_TIPO_MEMBRESIA = tm.PK_ID_TIPO_MEMBRESIA
    WHERE ofl.ID_OFERTAFLASH = p_id_oferta;

    UPDATE oferta_flash
    SET ESTADO_OFERTA_FLASH = 1,
        FECHA_OFERTA_FLASH = NOW(),
        TIEMPO_OFERTA_FLASH = NOW() + INTERVAL intervalo HOUR
    WHERE ID_OFERTAFLASH = p_id_oferta;
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

-- Volcando estructura para tabla abastecete.banner
CREATE TABLE IF NOT EXISTS `banner` (
  `PK_ID_BANNER` int NOT NULL AUTO_INCREMENT,
  `CLOUDINARY_URL` varchar(500) NOT NULL,
  `CLOUDINARY_PUBLIC_ID` varchar(255) NOT NULL,
  `NOMBRE` varchar(100) DEFAULT NULL,
  `TIPO` varchar(50) NOT NULL COMMENT 'proveedores, inicio, categoria, sesion, ofertas',
  `FORMATO` varchar(10) DEFAULT '16:9' COMMENT '16:9 o 1:1',
  `FK_ID_CATEGORIA` int DEFAULT NULL,
  `ACTIVO` tinyint DEFAULT '1',
  `FECHA_REGISTRO` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`PK_ID_BANNER`),
  KEY `idx_banner_tipo` (`TIPO`),
  KEY `idx_banner_categoria` (`FK_ID_CATEGORIA`),
  KEY `idx_banner_activo` (`ACTIVO`),
  KEY `idx_banner_tipo_activo` (`TIPO`,`ACTIVO`),
  CONSTRAINT `fk_banner_categoria` FOREIGN KEY (`FK_ID_CATEGORIA`) REFERENCES `categoria` (`PK_ID_CATEGORIA`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Volcando datos para la tabla abastecete.banner: ~0 rows (aproximadamente)

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

-- Volcando estructura para procedimiento abastecete.buscar_productos
DELIMITER //
CREATE PROCEDURE `buscar_productos`(
    IN `p_termino` VARCHAR(100),
    IN `p_id_categoria` INT,
    IN `p_id_subcategoria` INT,
    IN `p_id_marca` INT
)
BEGIN
    SELECT
        p.PK_ID_PRODUCTO,
        p.FK_ID_SUB_CATEGORIA,
        p.NOMBRE_PRODUCTO,
        p.IMAGEN_URL,
        p.FK_ID_MARCA,
        p.DESCRIPCION,
        p.SKU,
        p.CLOUDINARY_PUBLIC_ID,
        p.FK_ID_TIPOUNIDAD,
        m.NOMBRE AS NOMBRE_MARCA,
        tu.NOMBRE_TIPOUNIDAD,
        sc.NOMBRE_SUB_CATEGORIA,
        c.PK_ID_CATEGORIA,
        c.NOMBRE_CATEGORIA
    FROM producto p
    LEFT JOIN marca m ON p.FK_ID_MARCA = m.PK_ID_MARCA
    LEFT JOIN tipo_unidad tu ON p.FK_ID_TIPOUNIDAD = tu.ID_TIPOUNIDAD
    LEFT JOIN sub_categoria sc ON p.FK_ID_SUB_CATEGORIA = sc.PK_ID_SUB_CATEGORIA
    LEFT JOIN categoria c ON sc.FK_ID_CATEGORIA = c.PK_ID_CATEGORIA
    WHERE
        (p_termino IS NULL OR p_termino = '' OR
         p.NOMBRE_PRODUCTO LIKE CONCAT('%', p_termino, '%') OR
         p.SKU LIKE CONCAT('%', p_termino, '%'))
        AND (p_id_categoria IS NULL OR p_id_categoria = 0 OR c.PK_ID_CATEGORIA = p_id_categoria)
        AND (p_id_subcategoria IS NULL OR p_id_subcategoria = 0 OR p.FK_ID_SUB_CATEGORIA = p_id_subcategoria)
        AND (p_id_marca IS NULL OR p_id_marca = 0 OR p.FK_ID_MARCA = p_id_marca)
    ORDER BY p.NOMBRE_PRODUCTO;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.cancelar_suscripcion
DELIMITER //
CREATE PROCEDURE `cancelar_suscripcion`(
    IN p_id_suscripcion INT,
    IN p_motivo TEXT
)
BEGIN
    DECLARE v_id_local INT;
    DECLARE v_id_tipo_membresia INT;
    DECLARE v_fecha_inicio DATETIME;
    DECLARE v_fecha_fin DATETIME;

    -- Obtener datos de la suscripción
    SELECT FK_ID_LOCAL, FK_ID_TIPO_MEMBRESIA, FECHA_INICIO, FECHA_FIN
    INTO v_id_local, v_id_tipo_membresia, v_fecha_inicio, v_fecha_fin
    FROM suscripcion
    WHERE PK_ID_SUSCRIPCION = p_id_suscripcion;

    -- Marcar como cancelada
    UPDATE suscripcion
    SET ESTADO = 2
    WHERE PK_ID_SUSCRIPCION = p_id_suscripcion;

    -- Quitar suscripción activa del local
    UPDATE local
    SET FK_ID_SUSCRIPCION_ACTIVA = NULL
    WHERE PK_ID_LOCAL = v_id_local;

    -- Registrar en historial
    INSERT INTO historial_membresia (
        FK_ID_LOCAL,
        FK_ID_SUSCRIPCION,
        FK_ID_TIPO_ANTERIOR,
        FK_ID_TIPO_NUEVO,
        TIPO_CAMBIO,
        FECHA_INICIO_PERIODO,
        FECHA_FIN_PERIODO,
        NOTAS
    ) VALUES (
        v_id_local,
        p_id_suscripcion,
        v_id_tipo_membresia,
        v_id_tipo_membresia,
        'CANCELACION',
        v_fecha_inicio,
        NOW(),
        p_motivo
    );

    SELECT p_id_suscripcion AS IdSuscripcion, 'CANCELADA' AS Estado;
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

-- Volcando estructura para procedimiento abastecete.consultar_banners_por_categoria
DELIMITER //
CREATE PROCEDURE `consultar_banners_por_categoria`(
    IN `p_categoria_id` INT
)
BEGIN
    SELECT
        PK_ID_BANNER,
        CLOUDINARY_URL,
        CLOUDINARY_PUBLIC_ID,
        NOMBRE,
        TIPO,
        FORMATO,
        FK_ID_CATEGORIA,
        ACTIVO,
        FECHA_REGISTRO
    FROM banner
    WHERE FK_ID_CATEGORIA = p_categoria_id
      AND TIPO = 'categoria'
      AND ACTIVO = 1
    ORDER BY FORMATO, FECHA_REGISTRO DESC;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.consultar_banners_por_tipo
DELIMITER //
CREATE PROCEDURE `consultar_banners_por_tipo`(
    IN `p_tipo` VARCHAR(50)
)
BEGIN
    SELECT
        PK_ID_BANNER,
        CLOUDINARY_URL,
        CLOUDINARY_PUBLIC_ID,
        NOMBRE,
        TIPO,
        FORMATO,
        FK_ID_CATEGORIA,
        ACTIVO,
        FECHA_REGISTRO
    FROM banner
    WHERE TIPO = p_tipo AND ACTIVO = 1
    ORDER BY FECHA_REGISTRO DESC;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.consultar_banner_por_id
DELIMITER //
CREATE PROCEDURE `consultar_banner_por_id`(
    IN `p_id` INT
)
BEGIN
    SELECT
        PK_ID_BANNER,
        CLOUDINARY_URL,
        CLOUDINARY_PUBLIC_ID,
        NOMBRE,
        TIPO,
        FORMATO,
        FK_ID_CATEGORIA,
        ACTIVO,
        FECHA_REGISTRO
    FROM banner
    WHERE PK_ID_BANNER = p_id;
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

-- Volcando estructura para procedimiento abastecete.consultar_historial_membresia
DELIMITER //
CREATE PROCEDURE `consultar_historial_membresia`(
    IN p_id_local INT
)
BEGIN
    SELECT
        hm.PK_ID_HISTORIAL AS Id,
        hm.FK_ID_LOCAL AS LocalId,
        hm.FK_ID_SUSCRIPCION AS SuscripcionId,
        hm.TIPO_CAMBIO AS TipoCambio,
        hm.FECHA_CAMBIO AS FechaCambio,
        hm.FECHA_INICIO_PERIODO AS FechaInicioPeriodo,
        hm.FECHA_FIN_PERIODO AS FechaFinPeriodo,
        hm.MONTO AS Monto,
        hm.PERIODO AS Periodo,
        hm.NOTAS AS Notas,
        -- Tipo anterior
        ta.PK_ID_TIPO_MEMBRESIA AS TipoAnteriorId,
        ta.NOMBRE AS TipoAnteriorNombre,
        -- Tipo nuevo
        tn.PK_ID_TIPO_MEMBRESIA AS TipoNuevoId,
        tn.NOMBRE AS TipoNuevoNombre
    FROM historial_membresia hm
    LEFT JOIN tipo_membresia ta ON hm.FK_ID_TIPO_ANTERIOR = ta.PK_ID_TIPO_MEMBRESIA
    INNER JOIN tipo_membresia tn ON hm.FK_ID_TIPO_NUEVO = tn.PK_ID_TIPO_MEMBRESIA
    WHERE hm.FK_ID_LOCAL = p_id_local
    ORDER BY hm.FECHA_CAMBIO DESC;
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

-- Volcando estructura para procedimiento abastecete.consultar_locales_por_categoria
DELIMITER //
CREATE PROCEDURE `consultar_locales_por_categoria`(
    IN `idcategoria` INT,
    IN `tipoMembresia` VARCHAR(50)
)
BEGIN
    SELECT l.*
    FROM local l
    INNER JOIN localcategoria lc ON lc.FK_ID_LOCAL = l.PK_ID_LOCAL
    LEFT JOIN suscripcion s ON l.FK_ID_SUSCRIPCION_ACTIVA = s.PK_ID_SUSCRIPCION AND s.ESTADO = 1
    LEFT JOIN tipo_membresia tm ON s.FK_ID_TIPO_MEMBRESIA = tm.PK_ID_TIPO_MEMBRESIA
    WHERE lc.FK_ID_CATEGORIA = idcategoria
    AND (
        tipoMembresia = 'Selecciona un Tipo'
        OR tm.NOMBRE = tipoMembresia
        OR tipoMembresia IS NULL
        OR tipoMembresia = ''
    );
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

-- Volcando estructura para procedimiento abastecete.consultar_logs_sistema
DELIMITER //
CREATE PROCEDURE `consultar_logs_sistema`(
    IN p_fecha_desde DATETIME,
    IN p_fecha_hasta DATETIME,
    IN p_modulo VARCHAR(50),
    IN p_tipo_accion VARCHAR(10),
    IN p_id_usuario INT,
    IN p_termino_busqueda VARCHAR(100),
    IN p_pagina INT,
    IN p_registros_por_pagina INT
)
BEGIN
    DECLARE v_offset INT;
    SET v_offset = (p_pagina - 1) * p_registros_por_pagina;

    SELECT
        l.PK_ID_LOG AS Id,
        l.FK_ID_USUARIO AS UsuarioId,
        l.NOMBRE_USUARIO AS NombreUsuario,
        l.MODULO AS Modulo,
        l.TIPO_ACCION AS TipoAccion,
        l.ENTIDAD_ID AS EntidadId,
        l.ENTIDAD_DESCRIPCION AS EntidadDescripcion,
        l.DATOS_ANTERIORES AS DatosAnteriores,
        l.DATOS_NUEVOS AS DatosNuevos,
        l.IP_CLIENTE AS IpCliente,
        l.USER_AGENT AS UserAgent,
        l.FECHA_REGISTRO AS FechaRegistro,
        l.RESULTADO AS Resultado,
        l.MENSAJE_ERROR AS MensajeError,
        l.CONTROLLER AS Controller,
        l.ACTION AS Action
    FROM logs_sistema l
    WHERE
        (p_fecha_desde IS NULL OR l.FECHA_REGISTRO >= p_fecha_desde)
        AND (p_fecha_hasta IS NULL OR l.FECHA_REGISTRO <= p_fecha_hasta)
        AND (p_modulo IS NULL OR p_modulo = '' OR l.MODULO = p_modulo)
        AND (p_tipo_accion IS NULL OR p_tipo_accion = '' OR l.TIPO_ACCION = p_tipo_accion)
        AND (p_id_usuario IS NULL OR p_id_usuario = 0 OR l.FK_ID_USUARIO = p_id_usuario)
        AND (p_termino_busqueda IS NULL OR p_termino_busqueda = ''
             OR l.NOMBRE_USUARIO LIKE CONCAT('%', p_termino_busqueda, '%')
             OR l.ENTIDAD_DESCRIPCION LIKE CONCAT('%', p_termino_busqueda, '%'))
    ORDER BY l.FECHA_REGISTRO DESC
    LIMIT p_registros_por_pagina OFFSET v_offset;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.consultar_marcas
DELIMITER //
CREATE PROCEDURE `consultar_marcas`()
BEGIN
    SELECT
        PK_ID_MARCA,
        NOMBRE,
        DESCRIPCION,
        LOGO_URL,
        CLOUDINARY_PUBLIC_ID,
        ACTIVO,
        FECHA_REGISTRO
    FROM marca
    WHERE ACTIVO = 1
    ORDER BY NOMBRE ASC;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.consultar_marcas_todas
DELIMITER //
CREATE PROCEDURE `consultar_marcas_todas`()
BEGIN
    SELECT
        PK_ID_MARCA,
        NOMBRE,
        DESCRIPCION,
        LOGO_URL,
        CLOUDINARY_PUBLIC_ID,
        ACTIVO,
        FECHA_REGISTRO
    FROM marca
    ORDER BY ACTIVO DESC, NOMBRE ASC;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.consultar_marca_por_id
DELIMITER //
CREATE PROCEDURE `consultar_marca_por_id`(
    IN `p_id` INT
)
BEGIN
    SELECT
        PK_ID_MARCA,
        NOMBRE,
        DESCRIPCION,
        LOGO_URL,
        CLOUDINARY_PUBLIC_ID,
        ACTIVO,
        FECHA_REGISTRO
    FROM marca
    WHERE PK_ID_MARCA = p_id;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.consultar_negocio
DELIMITER //
CREATE PROCEDURE `consultar_negocio`(
    IN p_id_persona INT
)
BEGIN
    SELECT
        l.PK_ID_LOCAL,
        l.NOMBRE_LOCAL,
        l.LOCALIZACION,
        l.DIRECCION_LOCAL,
        l.TELEFONO_LOCAL,
        l.FOTOS_LOCAL,
        l.DESCRIPCION_LOCAL,
        l.BANNER_LOCAL,
        l.FK_ID_ESTADO_LOCAL,
        l.EMAIL_CONTACTO,
        l.WHATSAPP,
        l.SITIO_WEB,
        l.NIT,
        l.INSTAGRAM,
        l.FACEBOOK,
        l.TIKTOK,
        l.YOUTUBE,
        l.TWITTER,
        l.HORARIO_LUNES,
        l.HORARIO_MARTES,
        l.HORARIO_MIERCOLES,
        l.HORARIO_JUEVES,
        l.HORARIO_VIERNES,
        l.HORARIO_SABADO,
        l.HORARIO_DOMINGO,
        l.LATITUD,
        l.LONGITUD,
        l.FECHA_REGISTRO,
        l.FECHA_ACTUALIZACION,
        s.PK_ID_SUSCRIPCION,
        s.FK_ID_TIPO_MEMBRESIA,
        s.FECHA_INICIO AS SUSCRIPCION_FECHA_INICIO,
        s.FECHA_FIN AS SUSCRIPCION_FECHA_FIN,
        s.ESTADO AS SUSCRIPCION_ESTADO,
        tm.NOMBRE AS TIPO_MEMBRESIA_NOMBRE
    FROM `local` l
    LEFT JOIN suscripcion s ON s.PK_ID_SUSCRIPCION = l.FK_ID_SUSCRIPCION_ACTIVA
    LEFT JOIN tipo_membresia tm ON tm.PK_ID_TIPO_MEMBRESIA = s.FK_ID_TIPO_MEMBRESIA
    WHERE l.FK_ID_PERSONA = p_id_persona
    LIMIT 1;
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
    SELECT
        p.PK_ID_PRODUCTO,
        p.FK_ID_SUB_CATEGORIA,
        p.NOMBRE_PRODUCTO,
        p.IMAGEN_URL,
        p.FK_ID_MARCA,
        p.DESCRIPCION,
        p.SKU,
        p.CLOUDINARY_PUBLIC_ID,
        p.FK_ID_TIPOUNIDAD,
        m.NOMBRE AS NOMBRE_MARCA,
        tu.NOMBRE_TIPOUNIDAD
    FROM producto p
    LEFT JOIN marca m ON p.FK_ID_MARCA = m.PK_ID_MARCA
    LEFT JOIN tipo_unidad tu ON p.FK_ID_TIPOUNIDAD = tu.ID_TIPOUNIDAD;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.consultar_productos_por_marca
DELIMITER //
CREATE PROCEDURE `consultar_productos_por_marca`(
    IN `p_id_marca` INT
)
BEGIN
    SELECT
        p.PK_ID_PRODUCTO,
        p.FK_ID_SUB_CATEGORIA,
        p.NOMBRE_PRODUCTO,
        p.IMAGEN_URL,
        p.FK_ID_MARCA,
        p.DESCRIPCION,
        p.SKU,
        p.CLOUDINARY_PUBLIC_ID,
        m.NOMBRE AS NOMBRE_MARCA,
        sc.NOMBRE_SUB_CATEGORIA
    FROM producto p
    LEFT JOIN marca m ON p.FK_ID_MARCA = m.PK_ID_MARCA
    LEFT JOIN sub_categoria sc ON p.FK_ID_SUB_CATEGORIA = sc.PK_ID_SUB_CATEGORIA
    WHERE p.FK_ID_MARCA = p_id_marca;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.consultar_productos_subcategoria
DELIMITER //
CREATE PROCEDURE `consultar_productos_subcategoria`(
    IN `id_subcategoria` INT
)
BEGIN
    SELECT
        p.PK_ID_PRODUCTO,
        p.FK_ID_SUB_CATEGORIA,
        p.NOMBRE_PRODUCTO,
        p.IMAGEN_URL,
        p.FK_ID_MARCA,
        p.DESCRIPCION,
        p.SKU,
        p.CLOUDINARY_PUBLIC_ID,
        p.FK_ID_TIPOUNIDAD,
        m.NOMBRE AS NOMBRE_MARCA,
        tu.NOMBRE_TIPOUNIDAD
    FROM producto p
    LEFT JOIN marca m ON p.FK_ID_MARCA = m.PK_ID_MARCA
    LEFT JOIN tipo_unidad tu ON p.FK_ID_TIPOUNIDAD = tu.ID_TIPOUNIDAD
    WHERE p.FK_ID_SUB_CATEGORIA = id_subcategoria;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.consultar_productos_todos
DELIMITER //
CREATE PROCEDURE `consultar_productos_todos`()
BEGIN
    SELECT
        p.PK_ID_PRODUCTO,
        p.FK_ID_SUB_CATEGORIA,
        p.NOMBRE_PRODUCTO,
        p.IMAGEN_URL,
        p.FK_ID_MARCA,
        p.DESCRIPCION,
        p.SKU,
        p.CLOUDINARY_PUBLIC_ID,
        p.FK_ID_TIPOUNIDAD,
        m.NOMBRE AS NOMBRE_MARCA,
        tu.NOMBRE_TIPOUNIDAD,
        sc.NOMBRE_SUB_CATEGORIA,
        c.PK_ID_CATEGORIA,
        c.NOMBRE_CATEGORIA
    FROM producto p
    LEFT JOIN marca m ON p.FK_ID_MARCA = m.PK_ID_MARCA
    LEFT JOIN tipo_unidad tu ON p.FK_ID_TIPOUNIDAD = tu.ID_TIPOUNIDAD
    LEFT JOIN sub_categoria sc ON p.FK_ID_SUB_CATEGORIA = sc.PK_ID_SUB_CATEGORIA
    LEFT JOIN categoria c ON sc.FK_ID_CATEGORIA = c.PK_ID_CATEGORIA
    ORDER BY c.NOMBRE_CATEGORIA, sc.NOMBRE_SUB_CATEGORIA, p.NOMBRE_PRODUCTO;
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
            COALESCE(u.NOMBRE_UNIDAD, '') AS NOMBRE_UNIDAD
        FROM productoslocal pl
        INNER JOIN producto p ON pl.FK_ID_PRODUCTO = p.PK_ID_PRODUCTO
        LEFT JOIN unidad u ON pl.FK_ID_UNIDAD = u.ID_UNIDAD
        WHERE pl.FK_ID_PRODUCTO = p_id_producto
          AND pl.FK_ID_LOCAL = p_id_local
        LIMIT 1;
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

-- Volcando estructura para procedimiento abastecete.consultar_producto_por_id
DELIMITER //
CREATE PROCEDURE `consultar_producto_por_id`(
    IN `p_id` INT
)
BEGIN
    SELECT
        p.PK_ID_PRODUCTO,
        p.FK_ID_SUB_CATEGORIA,
        p.NOMBRE_PRODUCTO,
        p.IMAGEN_URL,
        p.FK_ID_MARCA,
        p.DESCRIPCION,
        p.SKU,
        p.CLOUDINARY_PUBLIC_ID,
        p.FK_ID_TIPOUNIDAD,
        m.NOMBRE AS NOMBRE_MARCA,
        tu.NOMBRE_TIPOUNIDAD,
        sc.NOMBRE_SUB_CATEGORIA,
        c.PK_ID_CATEGORIA,
        c.NOMBRE_CATEGORIA
    FROM producto p
    LEFT JOIN marca m ON p.FK_ID_MARCA = m.PK_ID_MARCA
    LEFT JOIN tipo_unidad tu ON p.FK_ID_TIPOUNIDAD = tu.ID_TIPOUNIDAD
    LEFT JOIN sub_categoria sc ON p.FK_ID_SUB_CATEGORIA = sc.PK_ID_SUB_CATEGORIA
    LEFT JOIN categoria c ON sc.FK_ID_CATEGORIA = c.PK_ID_CATEGORIA
    WHERE p.PK_ID_PRODUCTO = p_id;
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

-- Volcando estructura para procedimiento abastecete.consultar_tipos_unidad
DELIMITER //
CREATE PROCEDURE `consultar_tipos_unidad`()
BEGIN
    SELECT
        ID_TIPOUNIDAD,
        NOMBRE_TIPOUNIDAD
    FROM tipo_unidad
    ORDER BY NOMBRE_TIPOUNIDAD;
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

-- Volcando estructura para procedimiento abastecete.consultar_tipo_unidad_por_id
DELIMITER //
CREATE PROCEDURE `consultar_tipo_unidad_por_id`(
    IN `p_id` INT
)
BEGIN
    SELECT
        ID_TIPOUNIDAD,
        NOMBRE_TIPOUNIDAD
    FROM tipo_unidad
    WHERE ID_TIPOUNIDAD = p_id;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.consultar_todas_unidades
DELIMITER //
CREATE PROCEDURE `consultar_todas_unidades`()
BEGIN
    SELECT
        u.ID_UNIDAD,
        u.NOMBRE_UNIDAD,
        u.ESTADO_UNIDAD,
        u.FK_ID_TIPOUNIDAD,
        tu.NOMBRE_TIPOUNIDAD
    FROM unidad u
    LEFT JOIN tipo_unidad tu ON u.FK_ID_TIPOUNIDAD = tu.ID_TIPOUNIDAD
    ORDER BY tu.NOMBRE_TIPOUNIDAD, u.NOMBRE_UNIDAD;
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

-- Volcando estructura para procedimiento abastecete.consultar_unidades_por_tipo
DELIMITER //
CREATE PROCEDURE `consultar_unidades_por_tipo`(
    IN `p_tipo_unidad_id` INT
)
BEGIN
    SELECT
        u.ID_UNIDAD,
        u.NOMBRE_UNIDAD,
        u.ESTADO_UNIDAD,
        u.FK_ID_TIPOUNIDAD,
        tu.NOMBRE_TIPOUNIDAD
    FROM unidad u
    LEFT JOIN tipo_unidad tu ON u.FK_ID_TIPOUNIDAD = tu.ID_TIPOUNIDAD
    WHERE u.FK_ID_TIPOUNIDAD = p_tipo_unidad_id
    AND u.ESTADO_UNIDAD = 1
    ORDER BY u.NOMBRE_UNIDAD;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.consultar_unidad_por_id
DELIMITER //
CREATE PROCEDURE `consultar_unidad_por_id`(
    IN `p_id` INT
)
BEGIN
    SELECT
        u.ID_UNIDAD,
        u.NOMBRE_UNIDAD,
        u.ESTADO_UNIDAD,
        u.FK_ID_TIPOUNIDAD,
        tu.NOMBRE_TIPOUNIDAD
    FROM unidad u
    LEFT JOIN tipo_unidad tu ON u.FK_ID_TIPOUNIDAD = tu.ID_TIPOUNIDAD
    WHERE u.ID_UNIDAD = p_id;
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
CREATE PROCEDURE `consultar_usuarios`(
    IN `id_usuario` INT
)
BEGIN
    SELECT
        u.PK_ID_USUARIO,
        COALESCE(p.PK_ID_PERSONA, 0) AS PK_ID_PERSONA,
        COALESCE(p.NOMBRES, '') AS NOMBRES,
        COALESCE(p.APELLIDOS, '') AS APELLIDOS,
        COALESCE(p.TELEFONO, '') AS TELEFONO,
        COALESCE(u.ESTADO, 0) AS ESTADO,
        COALESCE(r.NOMBRE_ROL, 'Sin rol') AS NOMBRE_ROL,
        COALESCE(p.CORREO, '') AS CORREO
    FROM usuario u
    LEFT JOIN persona p ON u.FK_ID_PERSONA = p.PK_ID_PERSONA
    LEFT JOIN rol r ON u.FK_ID_ROL = r.PK_ID_ROL
    WHERE (id_usuario = 0 OR u.PK_ID_USUARIO = id_usuario);
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.consultar_usuarios_paginado
DELIMITER //
CREATE PROCEDURE `consultar_usuarios_paginado`(
    IN `p_pagina` INT,
    IN `p_registros_por_pagina` INT,
    IN `p_busqueda` VARCHAR(100)
)
BEGIN
    DECLARE v_offset INT;
    SET v_offset = (p_pagina - 1) * p_registros_por_pagina;

    -- Consulta principal con paginación
    SELECT
        u.PK_ID_USUARIO AS UsuarioId,
        COALESCE(u.ESTADO, 0) AS UsuarioEstado,
        COALESCE(p.PK_ID_PERSONA, 0) AS PersonaId,
        COALESCE(p.NOMBRES, '') AS PersonaNombres,
        COALESCE(p.APELLIDOS, '') AS PersonaApellidos,
        COALESCE(p.TELEFONO, '') AS PersonaTelefono,
        COALESCE(p.CORREO, '') AS PersonaCorreo,
        COALESCE(r.NOMBRE_ROL, 'Sin rol') AS RolNombre,
        l.PK_ID_LOCAL AS LocalId,
        COALESCE(l.NOMBRE_LOCAL, '') AS LocalNombre,
        s.PK_ID_SUSCRIPCION AS SuscripcionId,
        s.FECHA_INICIO AS SuscripcionFechaInicio,
        s.FECHA_FIN AS SuscripcionFechaFin,
        s.ESTADO AS SuscripcionEstado,
        tm.PK_ID_TIPO_MEMBRESIA AS TipoMembresiaId,
        COALESCE(tm.NOMBRE, 'Sin membresía') AS TipoMembresiaNombre
    FROM usuario u
    LEFT JOIN persona p ON u.FK_ID_PERSONA = p.PK_ID_PERSONA
    LEFT JOIN rol r ON u.FK_ID_ROL = r.PK_ID_ROL
    LEFT JOIN local l ON l.FK_ID_PERSONA = p.PK_ID_PERSONA
    LEFT JOIN suscripcion s ON l.FK_ID_SUSCRIPCION_ACTIVA = s.PK_ID_SUSCRIPCION
    LEFT JOIN tipo_membresia tm ON s.FK_ID_TIPO_MEMBRESIA = tm.PK_ID_TIPO_MEMBRESIA
    WHERE (p_busqueda IS NULL OR p_busqueda = '' OR
           p.NOMBRES LIKE CONCAT('%', p_busqueda, '%') OR
           p.APELLIDOS LIKE CONCAT('%', p_busqueda, '%') OR
           p.CORREO LIKE CONCAT('%', p_busqueda, '%') OR
           l.NOMBRE_LOCAL LIKE CONCAT('%', p_busqueda, '%'))
    ORDER BY u.PK_ID_USUARIO DESC
    LIMIT p_registros_por_pagina OFFSET v_offset;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.contar_galeria_pendientes
DELIMITER //
CREATE PROCEDURE `contar_galeria_pendientes`()
BEGIN
    SELECT COUNT(*) AS total_pendientes FROM galeria_local WHERE ESTADO = 0;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.contar_logs_sistema
DELIMITER //
CREATE PROCEDURE `contar_logs_sistema`(
    IN p_fecha_desde DATETIME,
    IN p_fecha_hasta DATETIME,
    IN p_modulo VARCHAR(50),
    IN p_tipo_accion VARCHAR(10),
    IN p_id_usuario INT,
    IN p_termino_busqueda VARCHAR(100)
)
BEGIN
    SELECT COUNT(*) AS TotalRegistros
    FROM logs_sistema l
    WHERE
        (p_fecha_desde IS NULL OR l.FECHA_REGISTRO >= p_fecha_desde)
        AND (p_fecha_hasta IS NULL OR l.FECHA_REGISTRO <= p_fecha_hasta)
        AND (p_modulo IS NULL OR p_modulo = '' OR l.MODULO = p_modulo)
        AND (p_tipo_accion IS NULL OR p_tipo_accion = '' OR l.TIPO_ACCION = p_tipo_accion)
        AND (p_id_usuario IS NULL OR p_id_usuario = 0 OR l.FK_ID_USUARIO = p_id_usuario)
        AND (p_termino_busqueda IS NULL OR p_termino_busqueda = ''
             OR l.NOMBRE_USUARIO LIKE CONCAT('%', p_termino_busqueda, '%')
             OR l.ENTIDAD_DESCRIPCION LIKE CONCAT('%', p_termino_busqueda, '%'));
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.contar_usuarios
DELIMITER //
CREATE PROCEDURE `contar_usuarios`(
    IN `p_busqueda` VARCHAR(100)
)
BEGIN
    SELECT COUNT(DISTINCT u.PK_ID_USUARIO) AS Total
    FROM usuario u
    LEFT JOIN persona p ON u.FK_ID_PERSONA = p.PK_ID_PERSONA
    LEFT JOIN local l ON l.FK_ID_PERSONA = p.PK_ID_PERSONA
    WHERE (p_busqueda IS NULL OR p_busqueda = '' OR
           p.NOMBRES LIKE CONCAT('%', p_busqueda, '%') OR
           p.APELLIDOS LIKE CONCAT('%', p_busqueda, '%') OR
           p.CORREO LIKE CONCAT('%', p_busqueda, '%') OR
           l.NOMBRE_LOCAL LIKE CONCAT('%', p_busqueda, '%'));
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.crear_banner
DELIMITER //
CREATE PROCEDURE `crear_banner`(
    IN `p_cloudinary_url` VARCHAR(500),
    IN `p_cloudinary_public_id` VARCHAR(255),
    IN `p_nombre` VARCHAR(100),
    IN `p_tipo` VARCHAR(50),
    IN `p_formato` VARCHAR(10),
    IN `p_categoria_id` INT,
    OUT `mensaje` VARCHAR(255),
    OUT `resultado` INT
)
BEGIN
    INSERT INTO banner (
        CLOUDINARY_URL,
        CLOUDINARY_PUBLIC_ID,
        NOMBRE,
        TIPO,
        FORMATO,
        FK_ID_CATEGORIA,
        ACTIVO,
        FECHA_REGISTRO
    ) VALUES (
        p_cloudinary_url,
        p_cloudinary_public_id,
        p_nombre,
        p_tipo,
        p_formato,
        p_categoria_id,
        1,
        NOW()
    );

    SET resultado = LAST_INSERT_ID();
    SET mensaje = 'Banner creado exitosamente';
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

-- Volcando estructura para procedimiento abastecete.crear_local
DELIMITER //
CREATE PROCEDURE `crear_local`(
    IN p_fk_id_persona INT,
    IN p_fk_id_estado_local INT,
    IN p_fk_id_tipomembresia INT,
    IN p_localizacion VARCHAR(100),
    IN p_nombre_local VARCHAR(100),
    IN p_direccion_local VARCHAR(200),
    IN p_telefono_local BIGINT,
    IN p_fotos_local VARCHAR(255),
    IN p_descripcion_local VARCHAR(1000),
    -- Campos nuevos de contacto
    IN p_email_contacto VARCHAR(100),
    IN p_whatsapp VARCHAR(20),
    IN p_sitio_web VARCHAR(255),
    -- Redes sociales
    IN p_instagram VARCHAR(100),
    IN p_facebook VARCHAR(255),
    IN p_tiktok VARCHAR(100),
    IN p_youtube VARCHAR(255),
    IN p_twitter VARCHAR(100),
    -- Horarios
    IN p_horario_lunes VARCHAR(20),
    IN p_horario_martes VARCHAR(20),
    IN p_horario_miercoles VARCHAR(20),
    IN p_horario_jueves VARCHAR(20),
    IN p_horario_viernes VARCHAR(20),
    IN p_horario_sabado VARCHAR(20),
    IN p_horario_domingo VARCHAR(20)
)
BEGIN
    DECLARE v_id_local INT;

    INSERT INTO `local` (
        FK_ID_PERSONA,
        FK_ID_ESTADO_LOCAL,
        LOCALIZACION,
        NOMBRE_LOCAL,
        DIRECCION_LOCAL,
        TELEFONO_LOCAL,
        FOTOS_LOCAL,
        DESCRIPCION_LOCAL,
        EMAIL_CONTACTO,
        WHATSAPP,
        SITIO_WEB,
        INSTAGRAM,
        FACEBOOK,
        TIKTOK,
        YOUTUBE,
        TWITTER,
        HORARIO_LUNES,
        HORARIO_MARTES,
        HORARIO_MIERCOLES,
        HORARIO_JUEVES,
        HORARIO_VIERNES,
        HORARIO_SABADO,
        HORARIO_DOMINGO,
        FECHA_REGISTRO
    ) VALUES (
        p_fk_id_persona,
        p_fk_id_estado_local,
        p_localizacion,
        p_nombre_local,
        p_direccion_local,
        p_telefono_local,
        p_fotos_local,
        p_descripcion_local,
        p_email_contacto,
        p_whatsapp,
        p_sitio_web,
        p_instagram,
        p_facebook,
        p_tiktok,
        p_youtube,
        p_twitter,
        p_horario_lunes,
        p_horario_martes,
        p_horario_miercoles,
        p_horario_jueves,
        p_horario_viernes,
        p_horario_sabado,
        p_horario_domingo,
        NOW()
    );

    SET v_id_local = LAST_INSERT_ID();

    -- Crear suscripción inicial (si se pasa tipo membresía)
    IF p_fk_id_tipomembresia IS NOT NULL AND p_fk_id_tipomembresia > 0 THEN
        INSERT INTO suscripcion (
            FK_ID_LOCAL,
            FK_ID_TIPO_MEMBRESIA,
            FECHA_INICIO,
            FECHA_FIN,
            ESTADO
        ) VALUES (
            v_id_local,
            p_fk_id_tipomembresia,
            NOW(),
            DATE_ADD(NOW(), INTERVAL 30 DAY),
            'Activa'
        );
    END IF;

    SELECT v_id_local AS id_local;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.crear_marca
DELIMITER //
CREATE PROCEDURE `crear_marca`(
    IN `p_nombre` VARCHAR(100),
    IN `p_descripcion` VARCHAR(255),
    IN `p_logo_url` VARCHAR(500),
    IN `p_cloudinary_public_id` VARCHAR(255),
    OUT `mensaje` VARCHAR(255),
    OUT `resultado` INT
)
BEGIN
    DECLARE existe INT DEFAULT 0;

    -- Verificar si ya existe una marca con ese nombre
    SELECT COUNT(*) INTO existe FROM marca WHERE NOMBRE = p_nombre;

    IF existe > 0 THEN
        SET mensaje = 'Ya existe una marca con ese nombre';
        SET resultado = 0;
    ELSE
        INSERT INTO marca (
            NOMBRE,
            DESCRIPCION,
            LOGO_URL,
            CLOUDINARY_PUBLIC_ID,
            ACTIVO,
            FECHA_REGISTRO
        ) VALUES (
            p_nombre,
            p_descripcion,
            p_logo_url,
            p_cloudinary_public_id,
            1,
            NOW()
        );

        SET resultado = LAST_INSERT_ID();
        SET mensaje = 'Marca creada exitosamente';
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
    IN `p_imagen_url` VARCHAR(500),
    IN `p_fk_id_marca` INT,
    IN `p_descripcion` TEXT,
    IN `p_sku` VARCHAR(50),
    IN `p_cloudinary_public_id` VARCHAR(255),
    IN `p_fk_id_tipounidad` INT
)
BEGIN
    DECLARE sub_categoria_existe INT;
    DECLARE marca_id INT;

    -- Verificar si la subcategoria existe
    SELECT COUNT(*) INTO sub_categoria_existe
    FROM sub_categoria
    WHERE PK_ID_SUB_CATEGORIA = p_fk_id_sub_categoria;

    -- Si no se proporciona marca, usar la marca por defecto (Sin Marca)
    SET marca_id = IFNULL(p_fk_id_marca, 1);

    IF sub_categoria_existe > 0 THEN
        -- Insertar el nuevo producto
        INSERT INTO producto (
            FK_ID_SUB_CATEGORIA,
            NOMBRE_PRODUCTO,
            IMAGEN_URL,
            FK_ID_MARCA,
            DESCRIPCION,
            SKU,
            CLOUDINARY_PUBLIC_ID,
            FK_ID_TIPOUNIDAD
        )
        VALUES (
            p_fk_id_sub_categoria,
            p_nombre_producto,
            p_imagen_url,
            marca_id,
            p_descripcion,
            NULLIF(p_sku, ''),
            p_cloudinary_public_id,
            NULLIF(p_fk_id_tipounidad, 0)
        );

        SELECT LAST_INSERT_ID() AS id_producto, 'Producto creado exitosamente' AS mensaje;
    ELSE
        SELECT 0 AS id_producto, 'Subcategoria no encontrada' AS mensaje;
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

-- Volcando estructura para procedimiento abastecete.crear_suscripcion
DELIMITER //
CREATE PROCEDURE `crear_suscripcion`(
    IN p_id_local INT,
    IN p_id_tipo_membresia INT,
    IN p_periodo VARCHAR(20),
    IN p_monto DECIMAL(10,2),
    IN p_metodo_pago VARCHAR(50),
    IN p_notas TEXT
)
BEGIN
    DECLARE v_id_suscripcion_anterior INT DEFAULT NULL;
    DECLARE v_id_tipo_anterior INT DEFAULT NULL;
    DECLARE v_fecha_inicio DATETIME;
    DECLARE v_fecha_fin DATETIME;
    DECLARE v_nueva_suscripcion INT;
    DECLARE v_tipo_cambio VARCHAR(20);

    SET v_fecha_inicio = NOW();

    -- Calcular fecha fin según el período
    SET v_fecha_fin = CASE p_periodo
        WHEN 'MENSUAL' THEN DATE_ADD(v_fecha_inicio, INTERVAL 1 MONTH)
        WHEN 'TRIMESTRAL' THEN DATE_ADD(v_fecha_inicio, INTERVAL 3 MONTH)
        WHEN 'SEMESTRAL' THEN DATE_ADD(v_fecha_inicio, INTERVAL 6 MONTH)
        WHEN 'ANUAL' THEN DATE_ADD(v_fecha_inicio, INTERVAL 1 YEAR)
        ELSE DATE_ADD(v_fecha_inicio, INTERVAL 1 MONTH)
    END;

    -- Buscar suscripción activa actual
    SELECT PK_ID_SUSCRIPCION, FK_ID_TIPO_MEMBRESIA
    INTO v_id_suscripcion_anterior, v_id_tipo_anterior
    FROM suscripcion
    WHERE FK_ID_LOCAL = p_id_local AND ESTADO = 1
    LIMIT 1;

    -- Desactivar suscripción anterior si existe
    IF v_id_suscripcion_anterior IS NOT NULL THEN
        UPDATE suscripcion
        SET ESTADO = 0
        WHERE PK_ID_SUSCRIPCION = v_id_suscripcion_anterior;
    END IF;

    -- Crear nueva suscripción
    INSERT INTO suscripcion (
        FK_ID_LOCAL,
        FK_ID_TIPO_MEMBRESIA,
        ESTADO,
        FECHA_INICIO,
        FECHA_FIN,
        MONTO_PAGADO,
        METODO_PAGO,
        PERIODO,
        NOTAS
    ) VALUES (
        p_id_local,
        p_id_tipo_membresia,
        1,
        v_fecha_inicio,
        v_fecha_fin,
        p_monto,
        p_metodo_pago,
        p_periodo,
        p_notas
    );

    SET v_nueva_suscripcion = LAST_INSERT_ID();

    -- Actualizar local con la nueva suscripción activa
    UPDATE local
    SET FK_ID_SUSCRIPCION_ACTIVA = v_nueva_suscripcion
    WHERE PK_ID_LOCAL = p_id_local;

    -- Determinar tipo de cambio
    IF v_id_tipo_anterior IS NULL THEN
        SET v_tipo_cambio = 'ALTA';
    ELSEIF p_id_tipo_membresia > v_id_tipo_anterior THEN
        SET v_tipo_cambio = 'UPGRADE';
    ELSEIF p_id_tipo_membresia < v_id_tipo_anterior THEN
        SET v_tipo_cambio = 'DOWNGRADE';
    ELSE
        SET v_tipo_cambio = 'RENOVACION';
    END IF;

    -- Registrar en historial
    INSERT INTO historial_membresia (
        FK_ID_LOCAL,
        FK_ID_SUSCRIPCION,
        FK_ID_TIPO_ANTERIOR,
        FK_ID_TIPO_NUEVO,
        TIPO_CAMBIO,
        FECHA_INICIO_PERIODO,
        FECHA_FIN_PERIODO,
        MONTO,
        PERIODO,
        NOTAS
    ) VALUES (
        p_id_local,
        v_nueva_suscripcion,
        v_id_tipo_anterior,
        p_id_tipo_membresia,
        v_tipo_cambio,
        v_fecha_inicio,
        v_fecha_fin,
        p_monto,
        p_periodo,
        p_notas
    );

    -- Retornar la nueva suscripción
    SELECT v_nueva_suscripcion AS IdSuscripcion, v_tipo_cambio AS TipoCambio;
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

-- Volcando estructura para procedimiento abastecete.crear_tipo_unidad
DELIMITER //
CREATE PROCEDURE `crear_tipo_unidad`(
    IN `p_nombre` VARCHAR(50),
    OUT `mensaje` VARCHAR(255),
    OUT `resultado` INT
)
BEGIN
    DECLARE existe INT DEFAULT 0;

    -- Verificar si ya existe
    SELECT COUNT(*) INTO existe
    FROM tipo_unidad
    WHERE LOWER(NOMBRE_TIPOUNIDAD) = LOWER(p_nombre);

    IF existe > 0 THEN
        SET mensaje = 'Ya existe un tipo de unidad con ese nombre';
        SET resultado = 0;
    ELSE
        INSERT INTO tipo_unidad (NOMBRE_TIPOUNIDAD)
        VALUES (p_nombre);

        SET mensaje = 'Tipo de unidad creado exitosamente';
        SET resultado = LAST_INSERT_ID();
    END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.crear_unidad
DELIMITER //
CREATE PROCEDURE `crear_unidad`(
    IN `p_nombre` VARCHAR(50),
    IN `p_estado` TINYINT,
    IN `p_tipo_unidad_id` INT,
    OUT `mensaje` VARCHAR(255),
    OUT `resultado` INT
)
BEGIN
    DECLARE existe INT DEFAULT 0;
    DECLARE tipo_existe INT DEFAULT 1;

    -- Verificar si existe el tipo de unidad (solo si se especificó uno)
    IF p_tipo_unidad_id IS NOT NULL THEN
        SELECT COUNT(*) INTO tipo_existe
        FROM tipo_unidad
        WHERE ID_TIPOUNIDAD = p_tipo_unidad_id;
    END IF;

    IF tipo_existe = 0 THEN
        SET mensaje = 'El tipo de unidad especificado no existe';
        SET resultado = 0;
    ELSE
        -- Verificar si ya existe una unidad con ese nombre en el mismo tipo
        SELECT COUNT(*) INTO existe
        FROM unidad
        WHERE LOWER(NOMBRE_UNIDAD) = LOWER(p_nombre)
        AND (FK_ID_TIPOUNIDAD = p_tipo_unidad_id OR (FK_ID_TIPOUNIDAD IS NULL AND p_tipo_unidad_id IS NULL));

        IF existe > 0 THEN
            SET mensaje = 'Ya existe una unidad con ese nombre en este tipo';
            SET resultado = 0;
        ELSE
            INSERT INTO unidad (NOMBRE_UNIDAD, ESTADO_UNIDAD, FK_ID_TIPOUNIDAD)
            VALUES (p_nombre, p_estado, p_tipo_unidad_id);

            SET mensaje = 'Unidad creada exitosamente';
            SET resultado = LAST_INSERT_ID();
        END IF;
    END IF;
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

-- Volcando estructura para procedimiento abastecete.desactivar_banner
DELIMITER //
CREATE PROCEDURE `desactivar_banner`(
    IN `p_id` INT,
    OUT `mensaje` VARCHAR(255),
    OUT `resultado` INT
)
BEGIN
    DECLARE existe INT DEFAULT 0;

    SELECT COUNT(*) INTO existe FROM banner WHERE PK_ID_BANNER = p_id;

    IF existe = 0 THEN
        SET mensaje = 'Banner no encontrado';
        SET resultado = 0;
    ELSE
        UPDATE banner SET ACTIVO = 0 WHERE PK_ID_BANNER = p_id;
        SET mensaje = 'Banner desactivado exitosamente';
        SET resultado = 1;
    END IF;
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

-- Volcando estructura para procedimiento abastecete.editar_local
DELIMITER //
CREATE PROCEDURE `editar_local`(
    IN p_id_local INT,
    IN p_nombre_local VARCHAR(100),
    IN p_direccion_local VARCHAR(200),
    IN p_localizacion_local VARCHAR(100),
    IN p_telefono_local VARCHAR(20),
    IN p_fotos_local LONGTEXT,
    IN p_descripcion_local VARCHAR(1000),
    IN p_banner_local VARCHAR(50),
    IN p_email_contacto VARCHAR(100),
    IN p_whatsapp VARCHAR(20),
    IN p_sitio_web VARCHAR(255),
    IN p_nit VARCHAR(20),
    IN p_instagram VARCHAR(100),
    IN p_facebook VARCHAR(255),
    IN p_tiktok VARCHAR(100),
    IN p_youtube VARCHAR(255),
    IN p_twitter VARCHAR(100),
    IN p_horario_lunes VARCHAR(20),
    IN p_horario_martes VARCHAR(20),
    IN p_horario_miercoles VARCHAR(20),
    IN p_horario_jueves VARCHAR(20),
    IN p_horario_viernes VARCHAR(20),
    IN p_horario_sabado VARCHAR(20),
    IN p_horario_domingo VARCHAR(20),
    IN p_latitud DECIMAL(10,8),
    IN p_longitud DECIMAL(11,8)
)
BEGIN
    UPDATE `local` SET
        NOMBRE_LOCAL = p_nombre_local,
        DIRECCION_LOCAL = p_direccion_local,
        LOCALIZACION = p_localizacion_local,
        TELEFONO_LOCAL = p_telefono_local,
        FOTOS_LOCAL = p_fotos_local,
        DESCRIPCION_LOCAL = p_descripcion_local,
        BANNER_LOCAL = p_banner_local,
        EMAIL_CONTACTO = p_email_contacto,
        WHATSAPP = p_whatsapp,
        SITIO_WEB = p_sitio_web,
        NIT = p_nit,
        INSTAGRAM = p_instagram,
        FACEBOOK = p_facebook,
        TIKTOK = p_tiktok,
        YOUTUBE = p_youtube,
        TWITTER = p_twitter,
        HORARIO_LUNES = p_horario_lunes,
        HORARIO_MARTES = p_horario_martes,
        HORARIO_MIERCOLES = p_horario_miercoles,
        HORARIO_JUEVES = p_horario_jueves,
        HORARIO_VIERNES = p_horario_viernes,
        HORARIO_SABADO = p_horario_sabado,
        HORARIO_DOMINGO = p_horario_domingo,
        LATITUD = p_latitud,
        LONGITUD = p_longitud,
        FECHA_ACTUALIZACION = NOW()
    WHERE PK_ID_LOCAL = p_id_local;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.editar_marca
DELIMITER //
CREATE PROCEDURE `editar_marca`(
    IN `p_id` INT,
    IN `p_nombre` VARCHAR(100),
    IN `p_descripcion` VARCHAR(255),
    IN `p_logo_url` VARCHAR(500),
    IN `p_cloudinary_public_id` VARCHAR(255),
    OUT `mensaje` VARCHAR(255),
    OUT `resultado` INT
)
BEGIN
    DECLARE existe INT DEFAULT 0;
    DECLARE nombre_duplicado INT DEFAULT 0;

    -- Verificar que existe la marca
    SELECT COUNT(*) INTO existe FROM marca WHERE PK_ID_MARCA = p_id;

    IF existe = 0 THEN
        SET mensaje = 'Marca no encontrada';
        SET resultado = 0;
    ELSE
        -- Verificar que no hay otra marca con el mismo nombre
        SELECT COUNT(*) INTO nombre_duplicado
        FROM marca
        WHERE NOMBRE = p_nombre AND PK_ID_MARCA != p_id;

        IF nombre_duplicado > 0 THEN
            SET mensaje = 'Ya existe otra marca con ese nombre';
            SET resultado = 0;
        ELSE
            UPDATE marca
            SET NOMBRE = p_nombre,
                DESCRIPCION = p_descripcion,
                LOGO_URL = COALESCE(p_logo_url, LOGO_URL),
                CLOUDINARY_PUBLIC_ID = COALESCE(p_cloudinary_public_id, CLOUDINARY_PUBLIC_ID)
            WHERE PK_ID_MARCA = p_id;

            SET mensaje = 'Marca actualizada exitosamente';
            SET resultado = 1;
        END IF;
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
    IN `p_imagen_url` VARCHAR(500),
    IN `p_fk_id_marca` INT,
    IN `p_descripcion` TEXT,
    IN `p_sku` VARCHAR(50),
    IN `p_cloudinary_public_id` VARCHAR(255),
    IN `p_fk_id_tipounidad` INT
)
BEGIN
    DECLARE sub_categoria_existe INT;
    DECLARE marca_id INT;

    -- Verificar si el producto existe
    IF EXISTS (SELECT 1 FROM producto WHERE PK_ID_PRODUCTO = p_id_producto) THEN
        -- Verificar si la subcategoria existe
        SELECT COUNT(*) INTO sub_categoria_existe
        FROM sub_categoria
        WHERE PK_ID_SUB_CATEGORIA = p_fk_id_sub_categoria;

        -- Si no se proporciona marca, usar la marca por defecto (Sin Marca)
        SET marca_id = IFNULL(p_fk_id_marca, 1);

        IF sub_categoria_existe > 0 THEN
            -- Actualizar el producto
            UPDATE producto
            SET FK_ID_SUB_CATEGORIA = p_fk_id_sub_categoria,
                NOMBRE_PRODUCTO = p_nombre_producto,
                IMAGEN_URL = p_imagen_url,
                FK_ID_MARCA = marca_id,
                DESCRIPCION = p_descripcion,
                SKU = NULLIF(p_sku, ''),
                CLOUDINARY_PUBLIC_ID = p_cloudinary_public_id,
                FK_ID_TIPOUNIDAD = NULLIF(p_fk_id_tipounidad, 0)
            WHERE PK_ID_PRODUCTO = p_id_producto;

            SELECT 1 AS resultado, 'Producto actualizado exitosamente' AS mensaje;
        ELSE
            SELECT 0 AS resultado, 'Subcategoria no encontrada' AS mensaje;
        END IF;
    ELSE
        SELECT 0 AS resultado, 'Producto no encontrado' AS mensaje;
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
    IN p_id_tipo_membresia INT,
    IN p_nombre VARCHAR(50),
    IN p_costo INT,
    IN p_estado TINYINT,
    IN p_duracion INT,
    IN p_cantidad INT,
    IN p_ofertas_flash_simultaneas INT,
    IN p_ofertas_flash_total INT,
    IN p_costo_trimestral INT,
    IN p_costo_semestral INT,
    IN p_costo_anual INT
)
BEGIN
    UPDATE tipo_membresia SET
        NOMBRE = p_nombre,
        COSTO = p_costo,
        ESTADO = p_estado,
        DURACION_OFERTA = p_duracion,
        CANTIDAD_PRODUCTOS = p_cantidad,
        OFERTAS_FLASH_SIMULTANEAS = p_ofertas_flash_simultaneas,
        OFERTAS_FLASH_TOTAL = p_ofertas_flash_total,
        COSTO_TRIMESTRAL = p_costo_trimestral,
        COSTO_SEMESTRAL = p_costo_semestral,
        COSTO_ANUAL = p_costo_anual
    WHERE PK_ID_TIPO_MEMBRESIA = p_id_tipo_membresia;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.editar_tipo_unidad
DELIMITER //
CREATE PROCEDURE `editar_tipo_unidad`(
    IN `p_id` INT,
    IN `p_nombre` VARCHAR(50),
    OUT `mensaje` VARCHAR(255),
    OUT `resultado` INT
)
BEGIN
    DECLARE existe INT DEFAULT 0;
    DECLARE duplicado INT DEFAULT 0;

    -- Verificar si existe el tipo
    SELECT COUNT(*) INTO existe
    FROM tipo_unidad
    WHERE ID_TIPOUNIDAD = p_id;

    IF existe = 0 THEN
        SET mensaje = 'Tipo de unidad no encontrado';
        SET resultado = 0;
    ELSE
        -- Verificar nombre duplicado (excluyendo el actual)
        SELECT COUNT(*) INTO duplicado
        FROM tipo_unidad
        WHERE LOWER(NOMBRE_TIPOUNIDAD) = LOWER(p_nombre)
        AND ID_TIPOUNIDAD != p_id;

        IF duplicado > 0 THEN
            SET mensaje = 'Ya existe otro tipo de unidad con ese nombre';
            SET resultado = 0;
        ELSE
            UPDATE tipo_unidad
            SET NOMBRE_TIPOUNIDAD = p_nombre
            WHERE ID_TIPOUNIDAD = p_id;

            SET mensaje = 'Tipo de unidad actualizado exitosamente';
            SET resultado = 1;
        END IF;
    END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.editar_unidad
DELIMITER //
CREATE PROCEDURE `editar_unidad`(
    IN `p_id` INT,
    IN `p_nombre` VARCHAR(50),
    IN `p_estado` TINYINT,
    IN `p_tipo_unidad_id` INT,
    OUT `mensaje` VARCHAR(255),
    OUT `resultado` INT
)
BEGIN
    DECLARE existe INT DEFAULT 0;
    DECLARE duplicado INT DEFAULT 0;

    -- Verificar si existe la unidad
    SELECT COUNT(*) INTO existe
    FROM unidad
    WHERE ID_UNIDAD = p_id;

    IF existe = 0 THEN
        SET mensaje = 'Unidad no encontrada';
        SET resultado = 0;
    ELSE
        -- Verificar nombre duplicado (excluyendo la actual)
        SELECT COUNT(*) INTO duplicado
        FROM unidad
        WHERE LOWER(NOMBRE_UNIDAD) = LOWER(p_nombre)
        AND ID_UNIDAD != p_id
        AND (FK_ID_TIPOUNIDAD = p_tipo_unidad_id OR (FK_ID_TIPOUNIDAD IS NULL AND p_tipo_unidad_id IS NULL));

        IF duplicado > 0 THEN
            SET mensaje = 'Ya existe otra unidad con ese nombre en este tipo';
            SET resultado = 0;
        ELSE
            UPDATE unidad
            SET NOMBRE_UNIDAD = p_nombre,
                ESTADO_UNIDAD = p_estado,
                FK_ID_TIPOUNIDAD = p_tipo_unidad_id
            WHERE ID_UNIDAD = p_id;

            SET mensaje = 'Unidad actualizada exitosamente';
            SET resultado = 1;
        END IF;
    END IF;
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

-- Volcando estructura para procedimiento abastecete.eliminar_banner
DELIMITER //
CREATE PROCEDURE `eliminar_banner`(
    IN `p_id` INT,
    OUT `mensaje` VARCHAR(255),
    OUT `resultado` INT,
    OUT `public_id` VARCHAR(255)
)
BEGIN
    DECLARE existe INT DEFAULT 0;

    -- Obtener public_id antes de eliminar (para borrar de Cloudinary)
    SELECT CLOUDINARY_PUBLIC_ID INTO public_id
    FROM banner
    WHERE PK_ID_BANNER = p_id;

    SELECT COUNT(*) INTO existe FROM banner WHERE PK_ID_BANNER = p_id;

    IF existe = 0 THEN
        SET mensaje = 'Banner no encontrado';
        SET resultado = 0;
        SET public_id = NULL;
    ELSE
        DELETE FROM banner WHERE PK_ID_BANNER = p_id;
        SET mensaje = 'Banner eliminado exitosamente';
        SET resultado = 1;
    END IF;
END//
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

-- Volcando estructura para procedimiento abastecete.eliminar_imagen_galeria
DELIMITER //
CREATE PROCEDURE `eliminar_imagen_galeria`(
    IN p_id_galeria INT
)
BEGIN
    SELECT CLOUDINARY_PUBLIC_ID INTO @public_id FROM galeria_local WHERE PK_ID_GALERIA = p_id_galeria;
    DELETE FROM galeria_local WHERE PK_ID_GALERIA = p_id_galeria;
    SELECT @public_id AS cloudinary_public_id;
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

-- Volcando estructura para procedimiento abastecete.eliminar_marca
DELIMITER //
CREATE PROCEDURE `eliminar_marca`(
    IN `p_id` INT,
    OUT `mensaje` VARCHAR(255),
    OUT `resultado` INT,
    OUT `public_id` VARCHAR(255)
)
BEGIN
    DECLARE existe INT DEFAULT 0;
    DECLARE productos_asociados INT DEFAULT 0;

    -- Obtener public_id antes de desactivar
    SELECT CLOUDINARY_PUBLIC_ID INTO public_id
    FROM marca
    WHERE PK_ID_MARCA = p_id;

    -- Verificar que existe la marca
    SELECT COUNT(*) INTO existe FROM marca WHERE PK_ID_MARCA = p_id;

    IF existe = 0 THEN
        SET mensaje = 'Marca no encontrada';
        SET resultado = 0;
        SET public_id = NULL;
    ELSE
        -- Verificar si tiene productos asociados
        SELECT COUNT(*) INTO productos_asociados
        FROM producto
        WHERE FK_ID_MARCA = p_id;

        IF productos_asociados > 0 THEN
            -- Soft delete si tiene productos
            UPDATE marca SET ACTIVO = 0 WHERE PK_ID_MARCA = p_id;
            SET mensaje = 'Marca desactivada (tiene productos asociados)';
            SET resultado = 1;
        ELSE
            -- Hard delete si no tiene productos
            DELETE FROM marca WHERE PK_ID_MARCA = p_id;
            SET mensaje = 'Marca eliminada exitosamente';
            SET resultado = 1;
        END IF;
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

-- Volcando estructura para procedimiento abastecete.eliminar_tipo_unidad
DELIMITER //
CREATE PROCEDURE `eliminar_tipo_unidad`(
    IN `p_id` INT,
    OUT `mensaje` VARCHAR(255),
    OUT `resultado` INT
)
BEGIN
    DECLARE existe INT DEFAULT 0;
    DECLARE tiene_unidades INT DEFAULT 0;

    -- Verificar si existe
    SELECT COUNT(*) INTO existe
    FROM tipo_unidad
    WHERE ID_TIPOUNIDAD = p_id;

    IF existe = 0 THEN
        SET mensaje = 'Tipo de unidad no encontrado';
        SET resultado = 0;
    ELSE
        -- Verificar si tiene unidades asociadas
        SELECT COUNT(*) INTO tiene_unidades
        FROM unidad
        WHERE FK_ID_TIPOUNIDAD = p_id;

        IF tiene_unidades > 0 THEN
            SET mensaje = CONCAT('No se puede eliminar. Tiene ', tiene_unidades, ' unidades asociadas');
            SET resultado = 0;
        ELSE
            DELETE FROM tipo_unidad WHERE ID_TIPOUNIDAD = p_id;
            SET mensaje = 'Tipo de unidad eliminado exitosamente';
            SET resultado = 1;
        END IF;
    END IF;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.eliminar_unidad
DELIMITER //
CREATE PROCEDURE `eliminar_unidad`(
    IN `p_id` INT,
    OUT `mensaje` VARCHAR(255),
    OUT `resultado` INT
)
BEGIN
    DECLARE existe INT DEFAULT 0;
    DECLARE en_uso INT DEFAULT 0;

    -- Verificar si existe
    SELECT COUNT(*) INTO existe
    FROM unidad
    WHERE ID_UNIDAD = p_id;

    IF existe = 0 THEN
        SET mensaje = 'Unidad no encontrada';
        SET resultado = 0;
    ELSE
        -- Verificar si está en uso en productoslocal
        SELECT COUNT(*) INTO en_uso
        FROM productoslocal
        WHERE FK_ID_UNIDAD = p_id;

        IF en_uso > 0 THEN
            SET mensaje = CONCAT('No se puede eliminar. La unidad está siendo usada en ', en_uso, ' productos');
            SET resultado = 0;
        ELSE
            DELETE FROM unidad WHERE ID_UNIDAD = p_id;
            SET mensaje = 'Unidad eliminada exitosamente';
            SET resultado = 1;
        END IF;
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

-- Volcando estructura para tabla abastecete.galeria_local
CREATE TABLE IF NOT EXISTS `galeria_local` (
  `PK_ID_GALERIA` int NOT NULL AUTO_INCREMENT,
  `FK_ID_LOCAL` int NOT NULL,
  `CLOUDINARY_URL` varchar(500) COLLATE utf8mb4_unicode_ci NOT NULL,
  `CLOUDINARY_PUBLIC_ID` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `ESTADO` int DEFAULT '0' COMMENT '0=Pendiente, 1=Aprobada, 2=Rechazada',
  `FECHA_SUBIDA` datetime DEFAULT CURRENT_TIMESTAMP,
  `FECHA_REVISION` datetime DEFAULT NULL,
  `FK_ID_USUARIO_REVISOR` int DEFAULT NULL,
  `MOTIVO_RECHAZO` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`PK_ID_GALERIA`),
  KEY `idx_galeria_local` (`FK_ID_LOCAL`),
  KEY `idx_galeria_estado` (`ESTADO`),
  KEY `FK_galeria_revisor` (`FK_ID_USUARIO_REVISOR`),
  CONSTRAINT `FK_galeria_local` FOREIGN KEY (`FK_ID_LOCAL`) REFERENCES `local` (`PK_ID_LOCAL`) ON DELETE CASCADE,
  CONSTRAINT `FK_galeria_revisor` FOREIGN KEY (`FK_ID_USUARIO_REVISOR`) REFERENCES `usuario` (`PK_ID_USUARIO`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Volcando datos para la tabla abastecete.galeria_local: ~1 rows (aproximadamente)
INSERT INTO `galeria_local` (`PK_ID_GALERIA`, `FK_ID_LOCAL`, `CLOUDINARY_URL`, `CLOUDINARY_PUBLIC_ID`, `ESTADO`, `FECHA_SUBIDA`, `FECHA_REVISION`, `FK_ID_USUARIO_REVISOR`, `MOTIVO_RECHAZO`) VALUES
	(1, 28, 'https://res.cloudinary.com/dwl5ggfhd/image/upload/v1766353804/galeria/locales/xtx4pvn7tyockpdhge4x.jpg', 'galeria/locales/xtx4pvn7tyockpdhge4x', 1, '2025-12-21 21:50:05', '2025-12-21 22:31:12', 2, NULL);

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

-- Volcando estructura para tabla abastecete.historial_membresia
CREATE TABLE IF NOT EXISTS `historial_membresia` (
  `PK_ID_HISTORIAL` int NOT NULL AUTO_INCREMENT,
  `FK_ID_LOCAL` int NOT NULL,
  `FK_ID_SUSCRIPCION` int DEFAULT NULL,
  `FK_ID_TIPO_ANTERIOR` int DEFAULT NULL,
  `FK_ID_TIPO_NUEVO` int NOT NULL,
  `TIPO_CAMBIO` enum('ALTA','UPGRADE','DOWNGRADE','RENOVACION','CANCELACION','VENCIMIENTO','MIGRACION') NOT NULL,
  `FECHA_CAMBIO` datetime DEFAULT CURRENT_TIMESTAMP,
  `FECHA_INICIO_PERIODO` datetime NOT NULL,
  `FECHA_FIN_PERIODO` datetime NOT NULL,
  `MONTO` decimal(10,2) DEFAULT NULL,
  `PERIODO` enum('MENSUAL','TRIMESTRAL','SEMESTRAL','ANUAL') DEFAULT NULL,
  `NOTAS` text,
  PRIMARY KEY (`PK_ID_HISTORIAL`),
  KEY `IDX_historial_local` (`FK_ID_LOCAL`),
  KEY `IDX_historial_fecha` (`FECHA_CAMBIO`),
  CONSTRAINT `FK_historial_local` FOREIGN KEY (`FK_ID_LOCAL`) REFERENCES `local` (`PK_ID_LOCAL`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=17 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Volcando datos para la tabla abastecete.historial_membresia: ~25 rows (aproximadamente)
INSERT INTO `historial_membresia` (`PK_ID_HISTORIAL`, `FK_ID_LOCAL`, `FK_ID_SUSCRIPCION`, `FK_ID_TIPO_ANTERIOR`, `FK_ID_TIPO_NUEVO`, `TIPO_CAMBIO`, `FECHA_CAMBIO`, `FECHA_INICIO_PERIODO`, `FECHA_FIN_PERIODO`, `MONTO`, `PERIODO`, `NOTAS`) VALUES
	(1, 1, 1, NULL, 12, 'MIGRACION', '2025-12-19 05:42:03', '2025-02-20 10:05:41', '2025-03-20 10:05:41', NULL, NULL, 'Registro inicial migrado automáticamente'),
	(2, 3, 2, NULL, 18, 'MIGRACION', '2025-12-19 05:42:03', '2025-02-20 10:43:17', '2025-03-20 10:43:17', NULL, NULL, 'Registro inicial migrado automáticamente'),
	(3, 21, 3, NULL, 17, 'MIGRACION', '2025-12-19 05:42:03', '2025-03-22 11:18:16', '2025-04-22 11:18:16', NULL, NULL, 'Registro inicial migrado automáticamente'),
	(4, 23, 4, NULL, 13, 'MIGRACION', '2025-12-19 05:42:03', '2025-03-31 20:15:55', '2025-04-30 20:15:55', NULL, NULL, 'Registro inicial migrado automáticamente'),
	(5, 24, 5, NULL, 16, 'MIGRACION', '2025-12-19 05:42:03', '2025-04-01 15:31:50', '2025-05-01 15:31:50', NULL, NULL, 'Registro inicial migrado automáticamente'),
	(6, 26, 6, NULL, 16, 'MIGRACION', '2025-12-19 05:42:03', '2025-04-02 20:33:17', '2025-05-02 20:33:17', NULL, NULL, 'Registro inicial migrado automáticamente'),
	(7, 27, 7, NULL, 13, 'MIGRACION', '2025-12-19 05:42:03', '2025-04-10 03:18:21', '2025-05-10 03:18:21', NULL, NULL, 'Registro inicial migrado automáticamente'),
	(8, 28, 8, NULL, 11, 'MIGRACION', '2025-12-19 05:42:03', '2025-04-21 15:28:29', '2025-05-21 15:28:29', NULL, NULL, 'Registro inicial migrado automáticamente'),
	(9, 29, 9, NULL, 19, 'MIGRACION', '2025-12-19 05:42:03', '2025-04-26 09:25:06', '2025-05-26 09:25:06', NULL, NULL, 'Registro inicial migrado automáticamente'),
	(10, 34, 10, NULL, 11, 'MIGRACION', '2025-12-19 05:42:03', '2025-06-16 23:43:32', '2025-07-16 23:43:32', NULL, NULL, 'Registro inicial migrado automáticamente'),
	(11, 35, 11, NULL, 11, 'MIGRACION', '2025-12-19 05:42:03', '2025-07-22 01:28:20', '2025-08-22 01:28:20', NULL, NULL, 'Registro inicial migrado automáticamente'),
	(12, 36, 12, NULL, 13, 'MIGRACION', '2025-12-19 05:42:03', '2025-08-20 22:11:19', '2025-09-20 22:11:19', NULL, NULL, 'Registro inicial migrado automáticamente'),
	(13, 37, 13, NULL, 11, 'MIGRACION', '2025-12-19 05:42:03', '2025-08-21 01:20:45', '2025-09-21 01:20:45', NULL, NULL, 'Registro inicial migrado automáticamente'),
	(16, 36, 16, 13, 11, 'DOWNGRADE', '2025-12-20 13:19:13', '2025-12-20 13:19:13', '2026-01-20 13:19:13', 0.00, 'MENSUAL', 'Cambio de membresía desde panel de administración'),
	(17, 23, 17, NULL, 13, 'ALTA', '2025-12-21 19:26:58', '2025-12-21 19:26:58', '2026-01-21 19:26:58', 0.00, 'MENSUAL', 'Cambio de plan desde Mi Membresía'),
	(18, 23, 18, 13, 13, 'RENOVACION', '2025-12-21 19:29:16', '2025-12-21 19:29:16', '2026-01-21 19:29:16', 0.00, 'MENSUAL', 'Cambio de plan desde Mi Membresía'),
	(19, 23, 19, 13, 11, 'DOWNGRADE', '2025-12-21 19:34:10', '2025-12-21 19:34:10', '2026-01-21 19:34:10', 0.00, 'MENSUAL', 'Cambio de plan desde Mi Membresía'),
	(20, 23, 20, 11, 13, 'UPGRADE', '2025-12-21 19:37:44', '2025-12-21 19:37:44', '2026-01-21 19:37:44', 0.00, 'MENSUAL', 'Cambio de plan desde Mi Membresía'),
	(21, 23, 21, 13, 13, 'RENOVACION', '2025-12-21 19:38:13', '2025-12-21 19:38:13', '2026-01-21 19:38:13', 0.00, 'MENSUAL', 'Cambio de plan desde Mi Membresía'),
	(22, 23, 22, 13, 13, 'RENOVACION', '2025-12-21 21:17:35', '2025-12-21 21:17:35', '2026-01-21 21:17:35', 0.00, 'MENSUAL', 'Cambio de plan desde Mi Membresía'),
	(23, 23, 23, 13, 12, 'DOWNGRADE', '2025-12-21 21:21:37', '2025-12-21 21:21:37', '2026-01-21 21:21:37', 0.00, 'MENSUAL', 'Cambio de plan desde Mi Membresía'),
	(24, 28, 24, NULL, 13, 'ALTA', '2025-12-21 21:53:49', '2025-12-21 21:53:49', '2026-01-21 21:53:49', 0.00, 'MENSUAL', 'Cambio de plan desde Mi Membresía'),
	(25, 28, 25, 13, 12, 'DOWNGRADE', '2025-12-21 21:54:12', '2025-12-21 21:54:12', '2026-01-21 21:54:12', 0.00, 'MENSUAL', 'Cambio de plan desde Mi Membresía'),
	(26, 28, 26, 12, 13, 'UPGRADE', '2025-12-21 22:32:49', '2025-12-21 22:32:49', '2026-01-21 22:32:49', 0.00, 'MENSUAL', 'Cambio de plan desde Mi Membresía'),
	(27, 28, 28, NULL, 13, 'ALTA', '2025-12-21 22:51:01', '2025-12-21 22:51:01', '2026-01-21 22:51:01', 0.00, 'MENSUAL', 'Cambio de plan desde Mi Membresía');

-- Volcando estructura para procedimiento abastecete.insertar_log_sistema
DELIMITER //
CREATE PROCEDURE `insertar_log_sistema`(
    IN p_id_usuario INT,
    IN p_nombre_usuario VARCHAR(200),
    IN p_modulo VARCHAR(50),
    IN p_tipo_accion VARCHAR(10),
    IN p_entidad_id INT,
    IN p_entidad_descripcion VARCHAR(255),
    IN p_datos_anteriores JSON,
    IN p_datos_nuevos JSON,
    IN p_ip_cliente VARCHAR(45),
    IN p_user_agent VARCHAR(500),
    IN p_resultado VARCHAR(10),
    IN p_mensaje_error VARCHAR(500),
    IN p_controller VARCHAR(100),
    IN p_action VARCHAR(100)
)
BEGIN
    INSERT INTO logs_sistema (
        FK_ID_USUARIO,
        NOMBRE_USUARIO,
        MODULO,
        TIPO_ACCION,
        ENTIDAD_ID,
        ENTIDAD_DESCRIPCION,
        DATOS_ANTERIORES,
        DATOS_NUEVOS,
        IP_CLIENTE,
        USER_AGENT,
        RESULTADO,
        MENSAJE_ERROR,
        CONTROLLER,
        ACTION
    ) VALUES (
        p_id_usuario,
        p_nombre_usuario,
        p_modulo,
        p_tipo_accion,
        p_entidad_id,
        p_entidad_descripcion,
        p_datos_anteriores,
        p_datos_nuevos,
        p_ip_cliente,
        p_user_agent,
        p_resultado,
        p_mensaje_error,
        p_controller,
        p_action
    );

    SELECT LAST_INSERT_ID() AS id_log;
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

-- Volcando estructura para procedimiento abastecete.listar_galeria_local
DELIMITER //
CREATE PROCEDURE `listar_galeria_local`(
    IN p_id_local INT
)
BEGIN
    SELECT
        PK_ID_GALERIA,
        FK_ID_LOCAL,
        CLOUDINARY_URL,
        CLOUDINARY_PUBLIC_ID,
        ESTADO,
        FECHA_SUBIDA,
        FECHA_REVISION,
        FK_ID_USUARIO_REVISOR,
        MOTIVO_RECHAZO
    FROM galeria_local
    WHERE FK_ID_LOCAL = p_id_local
    ORDER BY FECHA_SUBIDA DESC;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.listar_galeria_pendientes
DELIMITER //
CREATE PROCEDURE `listar_galeria_pendientes`()
BEGIN
    SELECT
        g.PK_ID_GALERIA,
        g.FK_ID_LOCAL,
        g.CLOUDINARY_URL,
        g.CLOUDINARY_PUBLIC_ID,
        g.ESTADO,
        g.FECHA_SUBIDA,
        l.NOMBRE_LOCAL,
        p.NOMBRES AS PROPIETARIO_NOMBRE,
        p.APELLIDOS AS PROPIETARIO_APELLIDO
    FROM galeria_local g
    INNER JOIN `local` l ON l.PK_ID_LOCAL = g.FK_ID_LOCAL
    INNER JOIN persona p ON p.PK_ID_PERSONA = l.FK_ID_PERSONA
    WHERE g.ESTADO = 0
    ORDER BY g.FECHA_SUBIDA ASC;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.listar_locales_membresia
DELIMITER //
CREATE PROCEDURE `listar_locales_membresia`()
BEGIN
    SELECT
        l.PK_ID_LOCAL,
        l.NOMBRE_LOCAL,
        l.DIRECCION,
        l.TELEFONO,
        l.CLOUDINARY_URL,
        tm.NOMBRE AS TIPO_MEMBRESIA,
        s.FECHA_INICIO,
        s.FECHA_FIN,
        s.ESTADO AS ESTADO_SUSCRIPCION,
        DATEDIFF(s.FECHA_FIN, NOW()) AS DIAS_RESTANTES
    FROM local l
    INNER JOIN suscripcion s ON s.PK_ID_SUSCRIPCION = l.FK_ID_SUSCRIPCION_ACTIVA
    INNER JOIN tipo_membresia tm ON tm.PK_ID_TIPO_MEMBRESIA = s.FK_ID_TIPO_MEMBRESIA
    WHERE s.ESTADO = 1
    AND NOW() BETWEEN s.FECHA_INICIO AND s.FECHA_FIN
    ORDER BY l.NOMBRE_LOCAL;
END//
DELIMITER ;

-- Volcando estructura para tabla abastecete.local
CREATE TABLE IF NOT EXISTS `local` (
  `PK_ID_LOCAL` int NOT NULL AUTO_INCREMENT,
  `FK_ID_PERSONA` int NOT NULL,
  `FK_ID_ESTADO_LOCAL` int NOT NULL,
  `NOMBRE_LOCAL` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `LOCALIZACION` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL,
  `DIRECCION_LOCAL` varchar(200) NOT NULL,
  `TELEFONO_LOCAL` varchar(20) DEFAULT NULL,
  `FOTOS_LOCAL` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
  `BANNER_LOCAL` varchar(50) DEFAULT NULL,
  `IMAGENES_LOCAL` varchar(150) DEFAULT NULL,
  `DESCRIPCION_LOCAL` varchar(1000) DEFAULT NULL,
  `EMAIL_CONTACTO` varchar(100) DEFAULT NULL,
  `WHATSAPP` varchar(20) DEFAULT NULL,
  `SITIO_WEB` varchar(255) DEFAULT NULL,
  `NIT` varchar(20) DEFAULT NULL,
  `INSTAGRAM` varchar(100) DEFAULT NULL,
  `FACEBOOK` varchar(255) DEFAULT NULL,
  `TIKTOK` varchar(100) DEFAULT NULL,
  `YOUTUBE` varchar(255) DEFAULT NULL,
  `TWITTER` varchar(100) DEFAULT NULL,
  `HORARIO_LUNES` varchar(20) DEFAULT NULL,
  `HORARIO_MARTES` varchar(20) DEFAULT NULL,
  `HORARIO_MIERCOLES` varchar(20) DEFAULT NULL,
  `HORARIO_JUEVES` varchar(20) DEFAULT NULL,
  `HORARIO_VIERNES` varchar(20) DEFAULT NULL,
  `HORARIO_SABADO` varchar(20) DEFAULT NULL,
  `HORARIO_DOMINGO` varchar(20) DEFAULT NULL,
  `LATITUD` decimal(10,8) DEFAULT NULL,
  `LONGITUD` decimal(11,8) DEFAULT NULL,
  `FECHA_REGISTRO` datetime DEFAULT CURRENT_TIMESTAMP,
  `FECHA_ACTUALIZACION` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  `FK_ID_SUSCRIPCION_ACTIVA` int DEFAULT NULL,
  PRIMARY KEY (`PK_ID_LOCAL`),
  KEY `FK_local_persona` (`FK_ID_PERSONA`),
  KEY `FK_local_estado_local` (`FK_ID_ESTADO_LOCAL`),
  KEY `idx_local_persona` (`FK_ID_PERSONA`),
  KEY `FK_local_suscripcion_activa` (`FK_ID_SUSCRIPCION_ACTIVA`),
  CONSTRAINT `FK_local_estado` FOREIGN KEY (`FK_ID_ESTADO_LOCAL`) REFERENCES `estado` (`PK_ID_ESTADO`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `FK_local_persona` FOREIGN KEY (`FK_ID_PERSONA`) REFERENCES `persona` (`PK_ID_PERSONA`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `FK_local_suscripcion_activa` FOREIGN KEY (`FK_ID_SUSCRIPCION_ACTIVA`) REFERENCES `suscripcion` (`PK_ID_SUSCRIPCION`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=38 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Volcando datos para la tabla abastecete.local: ~14 rows (aproximadamente)
INSERT INTO `local` (`PK_ID_LOCAL`, `FK_ID_PERSONA`, `FK_ID_ESTADO_LOCAL`, `NOMBRE_LOCAL`, `LOCALIZACION`, `DIRECCION_LOCAL`, `TELEFONO_LOCAL`, `FOTOS_LOCAL`, `BANNER_LOCAL`, `IMAGENES_LOCAL`, `DESCRIPCION_LOCAL`, `EMAIL_CONTACTO`, `WHATSAPP`, `SITIO_WEB`, `NIT`, `INSTAGRAM`, `FACEBOOK`, `TIKTOK`, `YOUTUBE`, `TWITTER`, `HORARIO_LUNES`, `HORARIO_MARTES`, `HORARIO_MIERCOLES`, `HORARIO_JUEVES`, `HORARIO_VIERNES`, `HORARIO_SABADO`, `HORARIO_DOMINGO`, `LATITUD`, `LONGITUD`, `FECHA_REGISTRO`, `FECHA_ACTUALIZACION`, `FK_ID_SUSCRIPCION_ACTIVA`) VALUES
	(1, 6, 1, 'Verduras don pepe', 'Pablo VI', 'Calle 12', '3123687285', '', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2025-12-20 20:19:09', NULL, 1),
	(3, 6, 1, 'pepito', 'abbas', 'calle 24', '21414', '', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2025-12-20 20:19:09', NULL, 2),
	(21, 12, 1, 'Donas Micha', '1.6153858,-75.60423639999999', 'Florencia, Caquetá, Colombia', '78456', '', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2025-12-20 20:19:09', NULL, 3),
	(22, 24, 1, 'Horizons', '1.6234506622739668,-75.60409692513122', 'Florencia, Caquetá, Colombia', '3204440787', '', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2025-12-20 20:19:09', NULL, NULL),
	(23, 25, 1, 'Horizons', '1.6234506622739668,-75.60409692513122', 'Florencia, Caquetá, Colombia', '3204440787', '683e1755f65d6c711a287e84', '683436604765d87a461b341a', NULL, 'Negocio realizado para la comunidad', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2025-12-20 20:19:09', '2025-12-21 21:21:37', 23),
	(24, 30, 1, 'blablabla blebleble', '1.6222087305724857, -75.61084289841457', 'Florencia caqueta', '3204440787', '', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2025-12-20 20:19:09', NULL, 5),
	(26, 34, 1, 'Coratiendas', '1.6123400192086215,-75.60642508255614', 'Florencia, Caquetá, Colombia', '3652547', '', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2025-12-20 20:19:09', NULL, 6),
	(27, 36, 1, 'EdifiK', '4.3356027,-74.3683957', 'Carrera 13 # 18-26, Fusagasugá, Cundinamarca, Colombia', '3103348519', '', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2025-12-20 20:19:09', NULL, 7),
	(28, 37, 1, 'K-OS', '1.6234506622739668,-75.60409692513122', 'Florencia, Caquetá, Colombia', '3204440787', '6833960e9c313657f5e02550', '6834362b4765d87a461b3408', NULL, 'Pq si', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', NULL, NULL, '2025-12-20 20:19:09', '2025-12-21 22:51:01', 28),
	(29, 38, 1, 'Prome', '1.6234506622739668,-75.60409692513122', 'Florencia, Caquetá, Colombia', '3204440787', '', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2025-12-20 20:19:09', NULL, 9),
	(34, 40, 1, 'Pan pa\' ya', '1.6046943720574707,-75.60290677490232', 'Cra. 15a #2d-115, Florencia, Caquetá', '3204440787', '6850ac1dac6622168168c557', '683436264765d87a461b3405', NULL, 'panaderia de pan', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2025-12-20 20:19:09', NULL, 10),
	(35, 50, 1, 'Abastecible', '2.9339860379526495,-75.27426106872556', 'Los pinos', '3112929178', '687ee8f4ac6622168168c559', '683436264765d87a461b3405', NULL, 'Pinos', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2025-12-20 20:19:09', NULL, 11),
	(36, 51, 1, 'Websen', NULL, 'Fusagasugá', '3103348519', '68a648005c46ee78254291cf', '683436264765d87a461b3405', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2025-12-20 20:19:09', NULL, 16),
	(37, 36, 1, 'Edifik', NULL, 'villa counrty', '3103348519', '68a674485c46ee78254291d1', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2025-12-20 20:19:09', NULL, 13);

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
) ENGINE=InnoDB AUTO_INCREMENT=39 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Volcando datos para la tabla abastecete.localcategoria: ~17 rows (aproximadamente)
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
	(37, 27, 16),
	(38, 28, 6);

-- Volcando estructura para procedimiento abastecete.login_google
DELIMITER //
CREATE PROCEDURE `login_google`(
    IN `p_correo` VARCHAR(100)
)
BEGIN
    DECLARE v_id_usuario INT;
    DECLARE v_id_persona INT;
    DECLARE v_estado INT;
    DECLARE v_fecha_bloqueo DATETIME;
    DECLARE v_id_tipo_membresia INT DEFAULT NULL;

    -- Obtener datos del usuario por correo
    SELECT u.PK_ID_USUARIO, u.FK_ID_PERSONA, u.ESTADO, u.FECHA_BLOQUEO
    INTO v_id_usuario, v_id_persona, v_estado, v_fecha_bloqueo
    FROM usuario u
    INNER JOIN persona p ON u.FK_ID_PERSONA = p.PK_ID_PERSONA
    WHERE p.CORREO = p_correo
    LIMIT 1;

    -- Si el usuario no existe
    IF v_id_usuario IS NULL THEN
        SELECT
            0 AS FK_ID_ROL,
            NULL AS FK_ID_PERSONA,
            NULL AS NOMBRE_USUARIO,
            NULL AS FK_ID_TIPOMEMBRESIA,
            'NO_EXISTE' AS estado_login;

    -- Si el usuario está inhabilitado
    ELSEIF v_estado = 97 THEN
        SELECT
            97 AS FK_ID_ROL,
            NULL AS FK_ID_PERSONA,
            NULL AS NOMBRE_USUARIO,
            NULL AS FK_ID_TIPOMEMBRESIA,
            'INHABILITADO' AS estado_login;

    -- Si el usuario está bloqueado
    ELSEIF v_estado = 0 AND v_fecha_bloqueo IS NOT NULL AND v_fecha_bloqueo > NOW() THEN
        SELECT
            0 AS FK_ID_ROL,
            NULL AS FK_ID_PERSONA,
            NULL AS NOMBRE_USUARIO,
            NULL AS FK_ID_TIPOMEMBRESIA,
            'BLOQUEADO' AS estado_login;

    ELSE
        -- Obtener tipo de membresía desde la suscripción activa
        SELECT s.FK_ID_TIPO_MEMBRESIA
        INTO v_id_tipo_membresia
        FROM persona p
        LEFT JOIN local l ON l.FK_ID_PERSONA = p.PK_ID_PERSONA
        LEFT JOIN suscripcion s ON l.FK_ID_SUSCRIPCION_ACTIVA = s.PK_ID_SUSCRIPCION AND s.ESTADO = 1
        WHERE p.PK_ID_PERSONA = v_id_persona
        LIMIT 1;

        -- Retornar datos del usuario
        SELECT
            u.PK_ID_USUARIO,
            u.FK_ID_ROL,
            u.FK_ID_PERSONA,
            u.NOMBRE_USUARIO,
            COALESCE(v_id_tipo_membresia, 0) AS FK_ID_TIPOMEMBRESIA,
            'OK' AS estado_login
        FROM usuario u
        WHERE u.PK_ID_USUARIO = v_id_usuario;
    END IF;
END//
DELIMITER ;

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

                -- Obtener el tipo de membresía desde la nueva estructura de suscripciones
                -- Usa la tabla suscripcion en lugar de la columna eliminada FK_ID_TIPOMEMBRESIA
                SELECT s.FK_ID_TIPO_MEMBRESIA
                INTO id_tipo_membresia
                FROM usuario u
                INNER JOIN persona p ON u.FK_ID_PERSONA = p.PK_ID_PERSONA
                LEFT JOIN local l ON l.FK_ID_PERSONA = p.PK_ID_PERSONA
                LEFT JOIN suscripcion s ON l.FK_ID_SUSCRIPCION_ACTIVA = s.PK_ID_SUSCRIPCION AND s.ESTADO = 1
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

-- Volcando estructura para tabla abastecete.logs_sistema
CREATE TABLE IF NOT EXISTS `logs_sistema` (
  `PK_ID_LOG` int NOT NULL AUTO_INCREMENT,
  `FK_ID_USUARIO` int DEFAULT NULL,
  `NOMBRE_USUARIO` varchar(200) DEFAULT NULL,
  `MODULO` varchar(50) NOT NULL,
  `TIPO_ACCION` enum('CREATE','UPDATE','DELETE','LOGIN','LOGOUT') NOT NULL,
  `ENTIDAD_ID` int DEFAULT NULL,
  `ENTIDAD_DESCRIPCION` varchar(255) DEFAULT NULL,
  `DATOS_ANTERIORES` json DEFAULT NULL,
  `DATOS_NUEVOS` json DEFAULT NULL,
  `IP_CLIENTE` varchar(45) DEFAULT NULL,
  `USER_AGENT` varchar(500) DEFAULT NULL,
  `FECHA_REGISTRO` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `RESULTADO` enum('EXITO','ERROR') NOT NULL DEFAULT 'EXITO',
  `MENSAJE_ERROR` varchar(500) DEFAULT NULL,
  `CONTROLLER` varchar(100) DEFAULT NULL,
  `ACTION` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`PK_ID_LOG`),
  KEY `IDX_logs_fecha` (`FECHA_REGISTRO` DESC),
  KEY `IDX_logs_usuario` (`FK_ID_USUARIO`),
  KEY `IDX_logs_modulo` (`MODULO`),
  KEY `IDX_logs_tipo_accion` (`TIPO_ACCION`),
  KEY `IDX_logs_entidad` (`MODULO`,`ENTIDAD_ID`),
  CONSTRAINT `FK_logs_usuario` FOREIGN KEY (`FK_ID_USUARIO`) REFERENCES `usuario` (`PK_ID_USUARIO`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Volcando datos para la tabla abastecete.logs_sistema: ~0 rows (aproximadamente)

-- Volcando estructura para tabla abastecete.marca
CREATE TABLE IF NOT EXISTS `marca` (
  `PK_ID_MARCA` int NOT NULL AUTO_INCREMENT,
  `NOMBRE` varchar(100) NOT NULL,
  `DESCRIPCION` varchar(255) DEFAULT NULL,
  `LOGO_URL` varchar(500) DEFAULT NULL,
  `CLOUDINARY_PUBLIC_ID` varchar(255) DEFAULT NULL,
  `ACTIVO` tinyint DEFAULT '1',
  `FECHA_REGISTRO` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`PK_ID_MARCA`),
  UNIQUE KEY `uk_marca_nombre` (`NOMBRE`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Volcando datos para la tabla abastecete.marca: ~1 rows (aproximadamente)
INSERT INTO `marca` (`PK_ID_MARCA`, `NOMBRE`, `DESCRIPCION`, `LOGO_URL`, `CLOUDINARY_PUBLIC_ID`, `ACTIVO`, `FECHA_REGISTRO`) VALUES
	(1, 'Sin Marca', 'Productos sin marca específica', NULL, NULL, 1, '2025-12-19 03:16:12');

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
    -- Estrategia optimizada: seleccionar IDs aleatorios primero, luego hacer JOIN
    -- Esto es mucho más rápido que ORDER BY RAND() en tablas grandes

    SELECT
        l.PK_ID_LOCAL,
        l.NOMBRE_LOCAL,
        l.FOTOS_LOCAL,
        COALESCE(s.FK_ID_TIPO_MEMBRESIA, 0) AS FK_ID_TIPOMEMBRESIA
    FROM local l
    LEFT JOIN suscripcion s ON l.FK_ID_SUSCRIPCION_ACTIVA = s.PK_ID_SUSCRIPCION AND s.ESTADO = 1
    WHERE l.FK_ID_ESTADO_LOCAL = 1
    ORDER BY
        -- Priorizar por tipo de membresía (premium primero)
        CASE
            WHEN s.FK_ID_TIPO_MEMBRESIA IN (19, 18, 17) THEN 1
            WHEN s.FK_ID_TIPO_MEMBRESIA IN (16, 15, 14) THEN 2
            ELSE 3
        END,
        -- Aleatorio dentro de cada grupo
        RAND()
    LIMIT 6;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.obtener_duracion_oferta
DELIMITER //
CREATE PROCEDURE `obtener_duracion_oferta`(
    IN `p_id_local` INT
)
BEGIN
    SELECT COALESCE(tm.DURACION_OFERTA, 24) AS DURACION_OFERTA
    FROM local l
    LEFT JOIN suscripcion s ON l.FK_ID_SUSCRIPCION_ACTIVA = s.PK_ID_SUSCRIPCION AND s.ESTADO = 1
    LEFT JOIN tipo_membresia tm ON s.FK_ID_TIPO_MEMBRESIA = tm.PK_ID_TIPO_MEMBRESIA
    WHERE l.PK_ID_LOCAL = p_id_local;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.obtener_suscripciones_local
DELIMITER //
CREATE PROCEDURE `obtener_suscripciones_local`(
    IN `p_id_local` INT
)
BEGIN
    SELECT
        s.PK_ID_SUSCRIPCION AS Id,
        s.FK_ID_LOCAL AS LocalId,
        s.ESTADO AS Estado,
        s.FECHA_INICIO AS FechaInicio,
        s.FECHA_FIN AS FechaFin,
        s.FECHA_CREACION AS FechaCreacion,
        s.MONTO_PAGADO AS MontoPagado,
        s.METODO_PAGO AS MetodoPago,
        s.PERIODO AS Periodo,
        s.NOTAS AS Notas,
        tm.PK_ID_TIPO_MEMBRESIA AS TipoMembresiaId,
        tm.NOMBRE AS TipoMembresiaNombre,
        COALESCE(tm.COSTO, 0) AS TipoMembresiaCostoMes
    FROM suscripcion s
    INNER JOIN tipo_membresia tm ON s.FK_ID_TIPO_MEMBRESIA = tm.PK_ID_TIPO_MEMBRESIA
    WHERE s.FK_ID_LOCAL = p_id_local
    ORDER BY s.FECHA_CREACION DESC;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.obtener_suscripcion_activa
DELIMITER //
CREATE PROCEDURE `obtener_suscripcion_activa`(
    IN `p_id_local` INT
)
BEGIN
    SELECT
        s.PK_ID_SUSCRIPCION AS Id,
        s.FK_ID_LOCAL AS LocalId,
        s.ESTADO AS Estado,
        s.FECHA_INICIO AS FechaInicio,
        s.FECHA_FIN AS FechaFin,
        s.FECHA_CREACION AS FechaCreacion,
        s.MONTO_PAGADO AS MontoPagado,
        s.METODO_PAGO AS MetodoPago,
        s.PERIODO AS Periodo,
        s.NOTAS AS Notas,
        tm.PK_ID_TIPO_MEMBRESIA AS TipoMembresiaId,
        tm.NOMBRE AS TipoMembresiaNombre,
        COALESCE(tm.DESCRIPCION, '') AS TipoMembresiaDescripcion,
        COALESCE(tm.COSTO, 0) AS TipoMembresiaCostoMes,
        COALESCE(tm.COSTO_TRIMESTRAL, 0) AS TipoMembresiaCostoTrimestre,
        COALESCE(tm.COSTO_SEMESTRAL, 0) AS TipoMembresiaCostoSemestre,
        COALESCE(tm.COSTO_ANUAL, 0) AS TipoMembresiaCostoAnio,
        COALESCE(tm.ESTADO, 1) AS TipoMembresiaEstado
    FROM suscripcion s
    INNER JOIN tipo_membresia tm ON s.FK_ID_TIPO_MEMBRESIA = tm.PK_ID_TIPO_MEMBRESIA
    WHERE s.FK_ID_LOCAL = p_id_local
    AND s.ESTADO = 1
    AND s.FECHA_FIN > NOW()
    ORDER BY s.FECHA_CREACION DESC
    LIMIT 1;
END//
DELIMITER ;

-- Volcando estructura para procedimiento abastecete.obtener_todas_membresias
DELIMITER //
CREATE PROCEDURE `obtener_todas_membresias`()
BEGIN
    SELECT
        PK_ID_TIPO_MEMBRESIA,
        NOMBRE,
        COSTO AS COSTO_MES,
        COSTO_TRIMESTRAL AS COSTO_TRIMESTRE,
        COSTO_SEMESTRAL AS COSTO_SEMESTRE,
        COSTO_ANUAL AS COSTO_ANIO,
        ESTADO
    FROM tipo_membresia
    WHERE ESTADO = 1
    ORDER BY NOMBRE;
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
    -- Cuenta ofertas activas: pendientes (0) y aprobadas (1)
    -- Excluye eliminadas/expiradas (2)
    SELECT COUNT(*)
    FROM oferta_flash
    INNER JOIN `local` ON oferta_flash.FK_ID_LOCAL = `local`.PK_ID_LOCAL
    WHERE local.PK_ID_LOCAL = p_id_local
    AND oferta_flash.ESTADO_OFERTA_FLASH IN (0, 1);
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
) ENGINE=InnoDB AUTO_INCREMENT=15 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Volcando datos para la tabla abastecete.permiso: ~12 rows (aproximadamente)
INSERT INTO `permiso` (`PK_ID_PERMISO`, `NOMBRE_PERMISO`, `ESTADO_PERMISO`) VALUES
	(2, 'Administrar Categorias', 1),
	(3, 'Administrar Usuarios', 1),
	(4, 'Publica tu negocio', 1),
	(5, 'Dejanos tu reseña', 1),
	(6, 'Administrar Roles', 1),
	(7, 'Administrar Membresias', 1),
	(8, 'Mi negocio', 1),
	(9, 'Administrar Banners', 1),
	(11, 'Administrar Marcas', 1),
	(12, 'Administrar Productos', 1),
	(13, 'Ver Logs Sistema', 1),
	(14, 'Administrar Galeria', 1);

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
) ENGINE=InnoDB AUTO_INCREMENT=39 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Volcando datos para la tabla abastecete.permiso_de_rol: ~30 rows (aproximadamente)
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
	(32, 1, 5, 0),
	(33, 1, 11, 1),
	(34, 8, 11, 1),
	(35, 1, 12, 1),
	(36, 8, 12, 1),
	(37, 1, 13, 1),
	(38, 1, 14, 1);

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

-- Volcando datos para la tabla abastecete.persona: ~28 rows (aproximadamente)
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
	(52, 'Dana', 'Nabia', '3253655228', 'dananabia2000@gmail.com', 1234567894, 1, 1, NULL, NULL),
	(56, 'juan', 'asado', '3204050072', 'prueba123@gmail.com', 10051241478, 1, 1, 'COD3464077', NULL);

-- Volcando estructura para tabla abastecete.producto
CREATE TABLE IF NOT EXISTS `producto` (
  `PK_ID_PRODUCTO` int NOT NULL AUTO_INCREMENT,
  `FK_ID_SUB_CATEGORIA` int NOT NULL,
  `NOMBRE_PRODUCTO` varchar(100) NOT NULL,
  `IMAGEN_URL` varchar(255) DEFAULT NULL,
  `FK_ID_TIPOUNIDAD` int DEFAULT NULL,
  `FK_ID_MARCA` int DEFAULT '1',
  `DESCRIPCION` text,
  `SKU` varchar(50) DEFAULT NULL,
  `CLOUDINARY_PUBLIC_ID` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`PK_ID_PRODUCTO`),
  UNIQUE KEY `idx_producto_sku` (`SKU`),
  KEY `FK_producto_sub_categoria` (`FK_ID_SUB_CATEGORIA`),
  KEY `fk_tipounidad` (`FK_ID_TIPOUNIDAD`),
  KEY `idx_producto_marca` (`FK_ID_MARCA`),
  CONSTRAINT `fk_producto_marca` FOREIGN KEY (`FK_ID_MARCA`) REFERENCES `marca` (`PK_ID_MARCA`),
  CONSTRAINT `FK_producto_sub_categoria` FOREIGN KEY (`FK_ID_SUB_CATEGORIA`) REFERENCES `sub_categoria` (`PK_ID_SUB_CATEGORIA`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_tipounidad` FOREIGN KEY (`FK_ID_TIPOUNIDAD`) REFERENCES `tipo_unidad` (`ID_TIPOUNIDAD`)
) ENGINE=InnoDB AUTO_INCREMENT=584 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Volcando datos para la tabla abastecete.producto: ~573 rows (aproximadamente)
INSERT INTO `producto` (`PK_ID_PRODUCTO`, `FK_ID_SUB_CATEGORIA`, `NOMBRE_PRODUCTO`, `IMAGEN_URL`, `FK_ID_TIPOUNIDAD`, `FK_ID_MARCA`, `DESCRIPCION`, `SKU`, `CLOUDINARY_PUBLIC_ID`) VALUES
	(1, 1, 'Manzanas', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Frutas frescas/Manzanas.webp', 1, 1, NULL, NULL, NULL),
	(2, 1, 'Bananas', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Frutas frescas/Bananas.webp', 1, 1, NULL, NULL, NULL),
	(3, 1, 'Naranjas', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Frutas frescas/Naranjas.webp', 1, 1, NULL, NULL, NULL),
	(4, 1, 'Peras', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Frutas frescas/Peras.webp', 1, 1, NULL, NULL, NULL),
	(5, 1, 'Uvas', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Frutas frescas/Uvas.webp', 1, 1, NULL, NULL, NULL),
	(6, 1, 'Mangos', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Frutas frescas/Mangos.webp', 1, 1, NULL, NULL, NULL),
	(7, 1, 'Papayas', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Frutas frescas/Papayas.webp', 1, 1, NULL, NULL, NULL),
	(8, 1, 'Piñas', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Frutas frescas/Piñas.webp', 1, 1, NULL, NULL, NULL),
	(9, 1, 'Fresas', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Frutas frescas/Fresas.webp', 1, 1, NULL, NULL, NULL),
	(10, 1, 'Kiwis', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Frutas frescas/Kiwis.webp', 1, 1, NULL, NULL, NULL),
	(11, 1, 'Limones', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Frutas frescas/Limones.webp', 1, 1, NULL, NULL, NULL),
	(12, 1, 'Mandarinas', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Frutas frescas/Mandarinas.webp', 1, 1, NULL, NULL, NULL),
	(13, 1, 'Cerezas', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Frutas frescas/Cerezas.webp', 1, 1, NULL, NULL, NULL),
	(14, 1, 'Melones', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Frutas frescas/Melones.webp', 1, 1, NULL, NULL, NULL),
	(15, 1, 'Sandías', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Frutas frescas/Sandías.webp', 1, 1, NULL, NULL, NULL),
	(16, 1, 'Duraznos', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Frutas frescas/Duraznos.webp', 1, 1, NULL, NULL, NULL),
	(17, 1, 'Ciruelas', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Frutas frescas/Ciruelas.webp', 1, 1, NULL, NULL, NULL),
	(18, 1, 'Aguacates', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Frutas frescas/Aguacates.webp', 1, 1, NULL, NULL, NULL),
	(19, 1, 'Granadillas', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Frutas frescas/Granadillas.webp', 1, 1, NULL, NULL, NULL),
	(21, 2, 'Tomates', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Verduras frescas/Tomates.webp', 1, 1, NULL, NULL, NULL),
	(22, 2, 'Lechugas', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Verduras frescas/Lechugas.webp', 1, 1, NULL, NULL, NULL),
	(23, 2, 'Zanahorias', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Verduras frescas/Zanahorias.webp', 1, 1, NULL, NULL, NULL),
	(24, 2, 'Cebollas', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Verduras frescas/Cebollas.webp', 1, 1, NULL, NULL, NULL),
	(25, 2, 'Pimientos', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Verduras frescas/Pimientos.webp', 1, 1, NULL, NULL, NULL),
	(26, 2, 'Pepinos', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Verduras frescas/Pepinos.webp', 1, 1, NULL, NULL, NULL),
	(27, 2, 'Espinacas', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Verduras frescas/Espinacas.webp', 1, 1, NULL, NULL, NULL),
	(29, 2, 'Coliflores', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Verduras frescas/Coliflores.webp', 1, 1, NULL, NULL, NULL),
	(30, 2, 'Berenjenas', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Verduras frescas/Berenjenas.webp', 1, 1, NULL, NULL, NULL),
	(31, 2, 'Calabacines', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Verduras frescas/Calabacines.webp', 1, 1, NULL, NULL, NULL),
	(32, 2, 'Ajos', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Verduras frescas/Ajos.webp', 1, 1, NULL, NULL, NULL),
	(33, 2, 'Apios', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Verduras frescas/Apios.webp', 1, 1, NULL, NULL, NULL),
	(34, 2, 'Repollo', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Verduras frescas/Repollo.webp', 1, 1, NULL, NULL, NULL),
	(35, 2, 'Remolachas', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Verduras frescas/Remolachas.webp', 1, 1, NULL, NULL, NULL),
	(36, 2, 'Rábanos', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Verduras frescas/Rábanos.webp', 1, 1, NULL, NULL, NULL),
	(37, 2, 'Guisantes', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Verduras frescas/Guisantes.webp', 1, 1, NULL, NULL, NULL),
	(38, 2, 'Habichuelas', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Verduras frescas/Habichuelas.webp', 1, 1, NULL, NULL, NULL),
	(39, 2, 'Champiñones', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Verduras frescas/Champiñones.webp', 1, 1, NULL, NULL, NULL),
	(40, 2, 'Alcachofas', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Verduras frescas/Alcachofas.webp', 1, 1, NULL, NULL, NULL),
	(41, 3, 'Cilantro', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Hierbas y especias frescas/Cilantro.webp', 1, 1, NULL, NULL, NULL),
	(42, 3, 'Perejil', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Hierbas y especias frescas/Perejil.webp', 1, 1, NULL, NULL, NULL),
	(43, 3, 'Albahaca', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Hierbas y especias frescas/Albahaca.webp', 1, 1, NULL, NULL, NULL),
	(44, 3, 'Hierbabuena', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Hierbas y especias frescas/Hierbabuena.webp', 1, 1, NULL, NULL, NULL),
	(45, 3, 'Orégano', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Hierbas y especias frescas/Orégano.webp', 1, 1, NULL, NULL, NULL),
	(46, 3, 'Tomillo', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Hierbas y especias frescas/Tomillo.webp', 1, 1, NULL, NULL, NULL),
	(47, 3, 'Romero', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Hierbas y especias frescas/Romero.webp', 1, 1, NULL, NULL, NULL),
	(48, 3, 'Laurel', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Hierbas y especias frescas/Laurel.webp', 1, 1, NULL, NULL, NULL),
	(49, 3, 'Menta', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Hierbas y especias frescas/Menta.webp', 1, 1, NULL, NULL, NULL),
	(50, 3, 'Estragón', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Hierbas y especias frescas/Estragón.webp', 1, 1, NULL, NULL, NULL),
	(51, 3, 'Salvia', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Hierbas y especias frescas/Salvia.webp', 1, 1, NULL, NULL, NULL),
	(53, 3, 'Cebollín', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Hierbas y especias frescas/Cebollín.webp', 1, 1, NULL, NULL, NULL),
	(54, 3, 'Ajedrea', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Hierbas y especias frescas/Ajedrea.webp', 1, 1, NULL, NULL, NULL),
	(55, 3, 'Mejorana', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Hierbas y especias frescas/Mejorana.webp', 1, 1, NULL, NULL, NULL),
	(56, 3, 'Hinojo', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Hierbas y especias frescas/Hinojo.webp', 1, 1, NULL, NULL, NULL),
	(57, 3, 'Lemongrass', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Hierbas y especias frescas/Lemongrass.webp', 1, 1, NULL, NULL, NULL),
	(58, 3, 'Cúrcuma fresca', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Hierbas y especias frescas/Cúrcuma fresca.webp', 1, 1, NULL, NULL, NULL),
	(59, 3, 'Jengibre fresco', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Hierbas y especias frescas/Jengibre fresco.webp', 1, 1, NULL, NULL, NULL),
	(62, 4, 'Yucas', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Tubérculos y raíces/Yucas.webp', 1, 1, NULL, NULL, NULL),
	(65, 4, 'Arracachas', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Tubérculos y raíces/Arracachas.webp', 1, 1, NULL, NULL, NULL),
	(66, 4, 'Rábano', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Tubérculos y raíces/Rábano.webp', 1, 1, NULL, NULL, NULL),
	(67, 4, 'Jengibre', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Tubérculos y raíces/Jengibre.webp', 1, 1, NULL, NULL, NULL),
	(68, 4, 'Cúrcuma', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Tubérculos y raíces/Cúrcuma.webp', 1, 1, NULL, NULL, NULL),
	(69, 4, 'Zanahorias', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Tubérculos y raíces/Zanahorias.webp', 1, 1, NULL, NULL, NULL),
	(70, 4, 'Remolachas', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Tubérculos y raíces/Remolachas.webp', 1, 1, NULL, NULL, NULL),
	(71, 4, 'Yacón', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Tubérculos y raíces/Yacón.webp', 1, 1, NULL, NULL, NULL),
	(72, 4, 'Malanga', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Tubérculos y raíces/Malanga.webp', 1, 1, NULL, NULL, NULL),
	(73, 4, 'Ocas', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Tubérculos y raíces/Ocas.webp', 1, 1, NULL, NULL, NULL),
	(74, 4, 'Mashuas', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Tubérculos y raíces/Mashuas.webp', 1, 1, NULL, NULL, NULL),
	(75, 4, 'Achiras', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Tubérculos y raíces/Achiras.webp', 1, 1, NULL, NULL, NULL),
	(76, 4, 'Chirivías', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Tubérculos y raíces/Chirivías.webp', 1, 1, NULL, NULL, NULL),
	(77, 4, 'Topinambur', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Tubérculos y raíces/Topinambur.webp', 1, 1, NULL, NULL, NULL),
	(78, 4, 'Taro', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Tubérculos y raíces/Taro.webp', 1, 1, NULL, NULL, NULL),
	(79, 4, 'Celeriaco', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Tubérculos y raíces/Celeriaco.webp', 1, 1, NULL, NULL, NULL),
	(80, 4, 'Jícama', '/images/PRODUCTOS ABASTECETE/Frutas y Verduras/Tubérculos y raíces/Jícama.webp', 1, 1, NULL, NULL, NULL),
	(81, 5, 'Lomo de res', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de res/Lomo de res.webp', 1, 1, NULL, NULL, NULL),
	(82, 5, 'Solomo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de res/Solomo.webp', 1, 1, NULL, NULL, NULL),
	(83, 5, 'Punta de anca', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de res/Punta de anca.webp', 1, 1, NULL, NULL, NULL),
	(84, 5, 'Costilla de res', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de res/Costilla de res.webp', 1, 1, NULL, NULL, NULL),
	(85, 5, 'Carne molida', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de res/Carne molida.webp', 1, 1, NULL, NULL, NULL),
	(86, 5, 'Bistec', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de res/Bistec.webp', 1, 1, NULL, NULL, NULL),
	(87, 5, 'Hígado de res', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de res/Hígado de res.webp', 1, 1, NULL, NULL, NULL),
	(88, 5, 'Rabo de res', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de res/Rabo de res.webp', 1, 1, NULL, NULL, NULL),
	(89, 5, 'Morrillo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de res/Morrillo.webp', 1, 1, NULL, NULL, NULL),
	(90, 5, 'Chatas', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de res/Chatas.webp', 1, 1, NULL, NULL, NULL),
	(91, 5, 'Paletero', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de res/Paletero.webp', 1, 1, NULL, NULL, NULL),
	(92, 5, 'Posta', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de res/Posta.webp', 1, 1, NULL, NULL, NULL),
	(93, 5, 'Muchacho', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de res/Muchacho.webp', 1, 1, NULL, NULL, NULL),
	(94, 5, 'Pecho de res', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de res/Pecho de res.webp', 1, 1, NULL, NULL, NULL),
	(95, 5, 'Entrecot', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de res/Entrecot.webp', 1, 1, NULL, NULL, NULL),
	(96, 5, 'T-bone', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de res/T-bone.webp', 1, 1, NULL, NULL, NULL),
	(97, 5, 'Tomahawk', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de res/Tomahawk.webp', 1, 1, NULL, NULL, NULL),
	(98, 5, 'Asado de tira', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de res/Asado de tira.webp', 1, 1, NULL, NULL, NULL),
	(99, 5, 'Colita de cuadril', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de res/Colita de cuadril.webp', 1, 1, NULL, NULL, NULL),
	(100, 5, 'Punta trasera', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de res/Punta trasera.webp', 1, 1, NULL, NULL, NULL),
	(101, 6, 'Chuletas de cerdo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de cerdo/Chuletas de cerdo.webp', 1, 1, NULL, NULL, NULL),
	(102, 6, 'Costillas de cerdo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de cerdo/Costillas de cerdo.webp', 1, 1, NULL, NULL, NULL),
	(103, 6, 'Lomo de cerdo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de cerdo/Lomo de cerdo.webp', 1, 1, NULL, NULL, NULL),
	(104, 6, 'Pernil de cerdo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de cerdo/Pernil de cerdo.webp', 1, 1, NULL, NULL, NULL),
	(105, 6, 'Tocino', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de cerdo/Tocino.webp', 1, 1, NULL, NULL, NULL),
	(106, 6, 'Chicharrón', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de cerdo/Chicharrón.webp', 1, 1, NULL, NULL, NULL),
	(107, 6, 'Jamón', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de cerdo/Jamón.webp', 1, 1, NULL, NULL, NULL),
	(108, 6, 'Salchichas', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de cerdo/Salchichas.webp', 1, 1, NULL, NULL, NULL),
	(109, 6, 'Morcilla', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de cerdo/Morcilla.webp', 1, 1, NULL, NULL, NULL),
	(110, 6, 'Chorizo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de cerdo/Chorizo.webp', 1, 1, NULL, NULL, NULL),
	(111, 6, 'Panceta', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de cerdo/Panceta.webp', 1, 1, NULL, NULL, NULL),
	(112, 6, 'Bondiola', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de cerdo/Bondiola.webp', 1, 1, NULL, NULL, NULL),
	(113, 6, 'Cabeza de lomo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de cerdo/Cabeza de lomo.webp', 1, 1, NULL, NULL, NULL),
	(114, 6, 'Paleta de cerdo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de cerdo/Paleta de cerdo.webp', 1, 1, NULL, NULL, NULL),
	(115, 6, 'Pata de cerdo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de cerdo/Pata de cerdo.webp', 1, 1, NULL, NULL, NULL),
	(116, 6, 'Carrilleras de cerdo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de cerdo/Carrilleras de cerdo.webp', 1, 1, NULL, NULL, NULL),
	(117, 6, 'Secreto ibérico', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de cerdo/Secreto ibérico.webp', 1, 1, NULL, NULL, NULL),
	(118, 6, 'Pluma ibérica', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de cerdo/Pluma ibérica.webp', 1, 1, NULL, NULL, NULL),
	(119, 6, 'Abanico de cerdo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de cerdo/Abanico de cerdo.webp', 1, 1, NULL, NULL, NULL),
	(120, 6, 'Lagarto de cerdo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de cerdo/Lagarto de cerdo.webp', 1, 1, NULL, NULL, NULL),
	(121, 7, 'Pechuga de pollo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de pollo/Pechuga de pollo.webp', 1, 1, NULL, NULL, NULL),
	(122, 7, 'Muslos de pollo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de pollo/Muslos de pollo.webp', 1, 1, NULL, NULL, NULL),
	(123, 7, 'Alitas de pollo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de pollo/Alitas de pollo.webp', 1, 1, NULL, NULL, NULL),
	(124, 7, 'Piernas de pollo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de pollo/Piernas de pollo.webp', 1, 1, NULL, NULL, NULL),
	(125, 7, 'Contramuslos de pollo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de pollo/Contramuslos de pollo.webp', 1, 1, NULL, NULL, NULL),
	(126, 7, 'Pollo entero', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de pollo/Pollo entero.webp', 1, 1, NULL, NULL, NULL),
	(127, 7, 'Filete de pechuga', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de pollo/Filete de pechuga.webp', 1, 1, NULL, NULL, NULL),
	(128, 7, 'Mollejas de pollo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de pollo/Mollejas de pollo.webp', 1, 1, NULL, NULL, NULL),
	(129, 7, 'Hígados de pollo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de pollo/Hígados de pollo.webp', 1, 1, NULL, NULL, NULL),
	(130, 7, 'Corazones de pollo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de pollo/Corazones de pollo.webp', 1, 1, NULL, NULL, NULL),
	(131, 7, 'Cuartos traseros', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de pollo/Cuartos traseros.webp', 1, 1, NULL, NULL, NULL),
	(132, 7, 'Cuartos delanteros', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de pollo/Cuartos delanteros.webp', 1, 1, NULL, NULL, NULL),
	(133, 7, 'Carcasa de pollo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de pollo/Carcasa de pollo.webp', 1, 1, NULL, NULL, NULL),
	(134, 7, 'Nuggets de pollo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de pollo/Nuggets de pollo.webp', 1, 1, NULL, NULL, NULL),
	(135, 7, 'Tiras de pollo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de pollo/Tiras de pollo.webp', 1, 1, NULL, NULL, NULL),
	(136, 7, 'Hamburguesas de pollo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de pollo/Hamburguesas de pollo.webp', 1, 1, NULL, NULL, NULL),
	(137, 7, 'Salchichas de pollo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de pollo/Salchichas de pollo.webp', 1, 1, NULL, NULL, NULL),
	(138, 7, 'Chorizo de pollo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de pollo/Chorizo de pollo.webp', 1, 1, NULL, NULL, NULL),
	(139, 7, 'Brochetas de pollo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de pollo/Brochetas de pollo.webp', 1, 1, NULL, NULL, NULL),
	(140, 7, 'Pollo desmechado', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes de pollo/Pollo desmechado.webp', 1, 1, NULL, NULL, NULL),
	(141, 8, 'Salmón', '/images/PRODUCTOS ABASTECETE/Proteínas/Pescados y mariscos/Salmón.webp', 1, 1, NULL, NULL, NULL),
	(142, 8, 'Tilapia', '/images/PRODUCTOS ABASTECETE/Proteínas/Pescados y mariscos/Tilapia.webp', 1, 1, NULL, NULL, NULL),
	(143, 8, 'Trucha', '/images/PRODUCTOS ABASTECETE/Proteínas/Pescados y mariscos/Trucha.webp', 1, 1, NULL, NULL, NULL),
	(144, 8, 'Bagre', '/images/PRODUCTOS ABASTECETE/Proteínas/Pescados y mariscos/Bagre.webp', 1, 1, NULL, NULL, NULL),
	(145, 8, 'Atún', '/images/PRODUCTOS ABASTECETE/Proteínas/Pescados y mariscos/Atún.webp', 1, 1, NULL, NULL, NULL),
	(146, 8, 'Sardinas', '/images/PRODUCTOS ABASTECETE/Proteínas/Pescados y mariscos/Sardinas.webp', 1, 1, NULL, NULL, NULL),
	(147, 8, 'Camarones', '/images/PRODUCTOS ABASTECETE/Proteínas/Pescados y mariscos/Camarones.webp', 1, 1, NULL, NULL, NULL),
	(149, 8, 'Calamares', '/images/PRODUCTOS ABASTECETE/Proteínas/Pescados y mariscos/Calamares.webp', 1, 1, NULL, NULL, NULL),
	(150, 8, 'Pulpo', '/images/PRODUCTOS ABASTECETE/Proteínas/Pescados y mariscos/Pulpo.webp', 1, 1, NULL, NULL, NULL),
	(151, 8, 'Mejillones', '/images/PRODUCTOS ABASTECETE/Proteínas/Pescados y mariscos/Mejillones.webp', 1, 1, NULL, NULL, NULL),
	(152, 8, 'Almejas', '/images/PRODUCTOS ABASTECETE/Proteínas/Pescados y mariscos/Almejas.webp', 1, 1, NULL, NULL, NULL),
	(153, 8, 'Ostras', '/images/PRODUCTOS ABASTECETE/Proteínas/Pescados y mariscos/Ostras.webp', 1, 1, NULL, NULL, NULL),
	(154, 8, 'Cangrejo', '/images/PRODUCTOS ABASTECETE/Proteínas/Pescados y mariscos/Cangrejo.webp', 1, 1, NULL, NULL, NULL),
	(155, 8, 'Langosta', '/images/PRODUCTOS ABASTECETE/Proteínas/Pescados y mariscos/Langosta.webp', 1, 1, NULL, NULL, NULL),
	(156, 8, 'Merluza', '/images/PRODUCTOS ABASTECETE/Proteínas/Pescados y mariscos/Merluza.webp', 1, 1, NULL, NULL, NULL),
	(157, 8, 'Bacalao', '/images/PRODUCTOS ABASTECETE/Proteínas/Pescados y mariscos/Bacalao.webp', 1, 1, NULL, NULL, NULL),
	(158, 8, 'Róbalo', '/images/PRODUCTOS ABASTECETE/Proteínas/Pescados y mariscos/Róbalo.webp', 1, 1, NULL, NULL, NULL),
	(159, 8, 'Pargo', '/images/PRODUCTOS ABASTECETE/Proteínas/Pescados y mariscos/Pargo.webp', 1, 1, NULL, NULL, NULL),
	(160, 8, 'Mojarra', '/images/PRODUCTOS ABASTECETE/Proteínas/Pescados y mariscos/Mojarra.webp', 1, 1, NULL, NULL, NULL),
	(161, 9, 'Jamón de cerdo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes procesadas/Jamón de cerdo.webp', 1, 1, NULL, NULL, NULL),
	(162, 9, 'Jamón de pavo', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes procesadas/Jamón de pavo.webp', 1, 1, NULL, NULL, NULL),
	(163, 9, 'Salchichas tipo Frankfurt', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes procesadas/Salchichas tipo Frankfurt.webp', 1, 1, NULL, NULL, NULL),
	(164, 9, 'Chorizo procesado', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes procesadas/Chorizo procesado.webp', 1, 1, NULL, NULL, NULL),
	(165, 9, 'Morcilla procesada', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes procesadas/Morcilla procesada.webp', 1, 1, NULL, NULL, NULL),
	(166, 9, 'Tocineta', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes procesadas/Tocineta.webp', 1, 1, NULL, NULL, NULL),
	(167, 9, 'Salami', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes procesadas/Salami.webp', 1, 1, NULL, NULL, NULL),
	(168, 9, 'Mortadela', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes procesadas/Mortadela.webp', 1, 1, NULL, NULL, NULL),
	(169, 9, 'Pepperoni', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes procesadas/Pepperoni.webp', 1, 1, NULL, NULL, NULL),
	(170, 9, 'Pastrami', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes procesadas/Pastrami.webp', 1, 1, NULL, NULL, NULL),
	(171, 9, 'Lomo embuchado', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes procesadas/Lomo embuchado.webp', 1, 1, NULL, NULL, NULL),
	(172, 9, 'Cecina', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes procesadas/Cecina.webp', 1, 1, NULL, NULL, NULL),
	(173, 9, 'Prosciutto', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes procesadas/Prosciutto.webp', 1, 1, NULL, NULL, NULL),
	(174, 9, 'Bresaola', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes procesadas/Bresaola.webp', 1, 1, NULL, NULL, NULL),
	(175, 9, 'Lomo canadiense', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes procesadas/Lomo canadiense.webp', 1, 1, NULL, NULL, NULL),
	(176, 9, 'Fuet', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes procesadas/Fuet.webp', 1, 1, NULL, NULL, NULL),
	(177, 9, 'Sobrasada', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes procesadas/Sobrasada.webp', 1, 1, NULL, NULL, NULL),
	(179, 9, 'Butifarra', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes procesadas/Butifarra.webp', 1, 1, NULL, NULL, NULL),
	(180, 9, 'Salchichón', '/images/PRODUCTOS ABASTECETE/Proteínas/Carnes procesadas/Salchichón.webp', 1, 1, NULL, NULL, NULL),
	(181, 10, 'Leche entera', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Leche y derivado/Leche entera.webp', 2, 1, NULL, NULL, NULL),
	(182, 10, 'Leche descremada', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Leche y derivado/Leche descremada.webp', 2, 1, NULL, NULL, NULL),
	(183, 10, 'Leche semidescremada', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Leche y derivado/Leche semidescremada.webp', 2, 1, NULL, NULL, NULL),
	(184, 10, 'Leche deslactosada', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Leche y derivado/Leche deslactosada.webp', 2, 1, NULL, NULL, NULL),
	(185, 10, 'Leche en polvo', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Leche y derivado/Leche en polvo.webp', 2, 1, NULL, NULL, NULL),
	(186, 10, 'Leche condensada', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Leche y derivado/Leche condensada.webp', 2, 1, NULL, NULL, NULL),
	(187, 10, 'Leche evaporada', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Leche y derivado/Leche evaporada.webp', 2, 1, NULL, NULL, NULL),
	(188, 10, 'Crema de leche', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Leche y derivados/Crema de leche.webp', 2, 1, NULL, NULL, NULL),
	(189, 10, 'Suero costeño', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Leche y derivado/Suero costeño.webp', 2, 1, NULL, NULL, NULL),
	(190, 10, 'Kéfir', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Leche y derivado/Kéfir.webp', 2, 1, NULL, NULL, NULL),
	(191, 10, 'Leche de cabra', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Leche y derivado/Leche de cabra.webp', 2, 1, NULL, NULL, NULL),
	(192, 10, 'Leche de búfala', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Leche y derivado/Leche de búfala.webp', 2, 1, NULL, NULL, NULL),
	(193, 10, 'Leche saborizada', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Leche y derivado/Leche saborizada.webp', 2, 1, NULL, NULL, NULL),
	(194, 11, 'Queso campesino', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Quesos y cuajadas/Queso campesino.webp', 1, 1, NULL, NULL, NULL),
	(195, 11, 'Queso costeño', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Quesos y cuajadas/Queso costeño.webp', 1, 1, NULL, NULL, NULL),
	(196, 11, 'Queso doble crema', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Quesos y cuajadas/Queso doble crema.webp', 1, 1, NULL, NULL, NULL),
	(197, 11, 'Queso mozzarella', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Quesos y cuajadas/Queso mozzarella.webp', 1, 1, NULL, NULL, NULL),
	(198, 11, 'Queso parmesano', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Quesos y cuajadas/Queso parmesano.webp', 1, 1, NULL, NULL, NULL),
	(199, 11, 'Queso cheddar', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Quesos y cuajadas/Queso cheddar.webp', 1, 1, NULL, NULL, NULL),
	(200, 11, 'Queso feta', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Quesos y cuajadas/Queso feta.webp', 1, 1, NULL, NULL, NULL),
	(201, 11, 'Queso azul', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Quesos y cuajadas/Queso azul.webp', 1, 1, NULL, NULL, NULL),
	(202, 11, 'Cuajada', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Quesos y cuajadas/Cuajada.webp', 1, 1, NULL, NULL, NULL),
	(203, 11, 'Queso ricotta', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Quesos y cuajadas/Queso ricotta.webp', 1, 1, NULL, NULL, NULL),
	(204, 11, 'Queso crema', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Quesos y cuajadas/Queso crema.webp', 1, 1, NULL, NULL, NULL),
	(205, 11, 'Queso gouda', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Quesos y cuajadas/Queso gouda.webp', 1, 1, NULL, NULL, NULL),
	(206, 11, 'Queso suizo', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Quesos y cuajadas/Queso suizo.webp', 1, 1, NULL, NULL, NULL),
	(207, 11, 'Queso brie', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Quesos y cuajadas/Queso brie.webp', 1, 1, NULL, NULL, NULL),
	(208, 12, 'Yogurt natural', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Yogurt y bebidas lácteas/Yogurt natural.webp', 2, 1, NULL, NULL, NULL),
	(209, 12, 'Yogurt griego', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Yogurt y bebidas lácteas/Yogurt griego.webp', 2, 1, NULL, NULL, NULL),
	(210, 12, 'Yogurt de frutas', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Yogurt y bebidas lácteas/Yogurt de frutas.webp', 2, 1, NULL, NULL, NULL),
	(211, 12, 'Yogurt bebible', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Yogurt y bebidas lácteas/Yogurt bebible.webp', 2, 1, NULL, NULL, NULL),
	(212, 12, 'Yogurt deslactosado', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Yogurt y bebidas lácteas/Yogurt deslactosado.webp', 2, 1, NULL, NULL, NULL),
	(213, 12, 'Bebidas probióticas', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Yogurt y bebidas lácteas/Bebidas probióticas.webp', 2, 1, NULL, NULL, NULL),
	(214, 12, 'Yogurt con granola', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Yogurt y bebidas lácteas/Yogurt con granola.webp', 2, 1, NULL, NULL, NULL),
	(215, 13, 'Mantequilla sin sal', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Mantequilla y margarinas/Mantequilla sin sal.webp', 3, 1, NULL, NULL, NULL),
	(216, 13, 'Mantequilla con sal', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Mantequilla y margarinas/Mantequilla con sal.webp', 3, 1, NULL, NULL, NULL),
	(217, 13, 'Margarina vegetal', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Mantequilla y margarinas/Margarina vegetal.webp', 3, 1, NULL, NULL, NULL),
	(218, 13, 'Margarina con sabor a mantequilla', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Mantequilla y margarinas/Margarina con sabor a mantequilla.webp', 3, 1, NULL, NULL, NULL),
	(219, 14, 'Huevos blancos', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Huevos/Huevos blancos.webp', 3, 1, NULL, NULL, NULL),
	(220, 14, 'Huevos rojos', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Huevos/Huevos rojos.webp', 3, 1, NULL, NULL, NULL),
	(221, 14, 'Huevos de codorniz', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Huevos/Huevos de codorniz.webp', 3, 1, NULL, NULL, NULL),
	(222, 14, 'Huevos orgánicos', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Huevos/Huevos orgánicos.webp', 3, 1, NULL, NULL, NULL),
	(223, 14, 'Huevos enriquecidos con omega 3', '/images/PRODUCTOS ABASTECETE/Lácteos y Huevos/Huevos/Huevos enriquecidos con omega 3.webp', 3, 1, NULL, NULL, NULL),
	(224, 15, 'Pan de masa madre', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Pan fresco y artesanal/Pan de masa madre.webp', 3, 1, NULL, NULL, NULL),
	(225, 15, 'Pan francés', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Pan fresco y artesanal/Pan francés.webp', 3, 1, NULL, NULL, NULL),
	(226, 15, 'Pan campesino', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Pan fresco y artesanal/Pan campesino.webp', 3, 1, NULL, NULL, NULL),
	(227, 15, 'Baguette', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Pan fresco y artesanal/Baguette.webp', 3, 1, NULL, NULL, NULL),
	(228, 15, 'Pan ciabatta', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Pan fresco y artesanal/Pan ciabatta.webp', 3, 1, NULL, NULL, NULL),
	(229, 15, 'Pan brioche', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Pan fresco y artesanal/Pan brioche.webp', 3, 1, NULL, NULL, NULL),
	(230, 15, 'Pan integral', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Pan fresco y artesanal/Pan integral.webp', 3, 1, NULL, NULL, NULL),
	(231, 15, 'Pan de queso', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Pan fresco y artesanal/Pan de queso.webp', 3, 1, NULL, NULL, NULL),
	(232, 15, 'Pan de coco', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Pan fresco y artesanal/Pan de coco.webp', 3, 1, NULL, NULL, NULL),
	(233, 15, 'Pan de yuca', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Pan fresco y artesanal/Pan de yuca.webp', 3, 1, NULL, NULL, NULL),
	(234, 16, 'Pan blanco empacado', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Panadería empacada/Pan blanco empacado.webp', 3, 1, NULL, NULL, NULL),
	(235, 16, 'Pan integral empacado', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Panadería empacada/Pan integral empacado.webp', 3, 1, NULL, NULL, NULL),
	(236, 16, 'Pan tostado', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Panadería empacada/Pan tostado.webp', 3, 1, NULL, NULL, NULL),
	(237, 16, 'Pan de molde', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Panadería empacada/Pan de molde.webp', 3, 1, NULL, NULL, NULL),
	(238, 16, 'Pan para hamburguesa', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Panadería empacada/Pan para hamburguesa.webp', 3, 1, NULL, NULL, NULL),
	(239, 16, 'Pan para perro caliente', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Panadería empacada/Pan para perro caliente.webp', 3, 1, NULL, NULL, NULL),
	(240, 16, 'Pan pita', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Panadería empacada/Pan pita.webp', 3, 1, NULL, NULL, NULL),
	(241, 17, 'Torta de chocolate', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Tortas y postres frescos/Torta de chocolate.webp', 3, 1, NULL, NULL, NULL),
	(242, 17, 'Torta de zanahoria', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Tortas y postres frescos/Torta de zanahoria.webp', 3, 1, NULL, NULL, NULL),
	(243, 17, 'Tres leches', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Tortas y postres frescos/Tres leches.webp', 3, 1, NULL, NULL, NULL),
	(244, 17, 'Cheesecake', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Tortas y postres frescos/Cheesecake.webp', 3, 1, NULL, NULL, NULL),
	(245, 17, 'Flan', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Tortas y postres frescos/Flan.webp', 3, 1, NULL, NULL, NULL),
	(246, 17, 'Pionono', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Tortas y postres frescos/Pionono.webp', 3, 1, NULL, NULL, NULL),
	(247, 17, 'Tiramisú', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Tortas y postres frescos/Tiramisú.webp', 3, 1, NULL, NULL, NULL),
	(248, 17, 'Postres individuales', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Tortas y postres frescos/Postres individuales.webp', 3, 1, NULL, NULL, NULL),
	(249, 17, 'Volcán de chocolate', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Tortas y postres frescos/Volcán de chocolate.webp', 3, 1, NULL, NULL, NULL),
	(250, 18, 'Galletas de chocolate', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Repostería industrial/Galletas de chocolate.webp', 3, 1, NULL, NULL, NULL),
	(251, 18, 'Galletas de avena', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Repostería industrial/Galletas de avena.webp', 3, 1, NULL, NULL, NULL),
	(252, 18, 'Brownies', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Repostería industrial/Brownies.webp', 3, 1, NULL, NULL, NULL),
	(253, 18, 'Muffins', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Repostería industrial/Muffins.webp', 3, 1, NULL, NULL, NULL),
	(254, 18, 'Cupcakes', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Repostería industrial/Cupcakes.webp', 3, 1, NULL, NULL, NULL),
	(255, 18, 'Alfajores', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Repostería industrial/Alfajores.webp', 3, 1, NULL, NULL, NULL),
	(256, 18, 'Macarons', '/images/PRODUCTOS ABASTECETE/Panadería y Repostería/Repostería industrial/Macarons.webp', 3, 1, NULL, NULL, NULL),
	(257, 19, 'Arroz blanco', '/images/PRODUCTOS ABASTECETE/Despensa/Arroz, granos y legumbres/Arroz blanco.webp', 1, 1, NULL, NULL, NULL),
	(258, 19, 'Arroz integral', '/images/PRODUCTOS ABASTECETE/Despensa/Arroz, granos y legumbres/Arroz integral.webp', 1, 1, NULL, NULL, NULL),
	(259, 19, 'Arroz para sushi', '/images/PRODUCTOS ABASTECETE/Despensa/Arroz, granos y legumbres/Arroz para sushi.webp', 1, 1, NULL, NULL, NULL),
	(260, 19, 'Arroz basmati', '/images/PRODUCTOS ABASTECETE/Despensa/Arroz, granos y legumbres/Arroz basmati.webp', 1, 1, NULL, NULL, NULL),
	(261, 19, 'Arroz jazmín', '/images/PRODUCTOS ABASTECETE/Despensa/Arroz, granos y legumbres/Arroz jazmín.webp', 1, 1, NULL, NULL, NULL),
	(262, 19, 'Frijoles rojos', '/images/PRODUCTOS ABASTECETE/Despensa/Arroz, granos y legumbres/Frijoles rojos.webp', 1, 1, NULL, NULL, NULL),
	(263, 19, 'Frijoles negros', '/images/PRODUCTOS ABASTECETE/Despensa/Arroz, granos y legumbres/Frijoles negros.webp', 1, 1, NULL, NULL, NULL),
	(264, 19, 'Lentejas', '/images/PRODUCTOS ABASTECETE/Despensa/Arroz, granos y legumbres/Lentejas.webp', 1, 1, NULL, NULL, NULL),
	(265, 19, 'Garbanzo', '/images/PRODUCTOS ABASTECETE/Despensa/Arroz, granos y legumbres/Garbanzo.webp', 1, 1, NULL, NULL, NULL),
	(266, 19, 'Arveja seca', '/images/PRODUCTOS ABASTECETE/Despensa/Arroz, granos y legumbres/Arveja seca.webp', 1, 1, NULL, NULL, NULL),
	(267, 20, 'Espagueti', '/images/PRODUCTOS ABASTECETE/Despensa/Pastas y harinas/Espagueti.webp', 3, 1, NULL, NULL, NULL),
	(268, 20, 'Fettuccine', '/images/PRODUCTOS ABASTECETE/Despensa/Pastas y harinas/Fettuccine.webp', 3, 1, NULL, NULL, NULL),
	(269, 20, 'Macarrones', '/images/PRODUCTOS ABASTECETE/Despensa/Pastas y harinas/Macarrones.webp', 3, 1, NULL, NULL, NULL),
	(270, 20, 'Lasaña', '/images/PRODUCTOS ABASTECETE/Despensa/Pastas y harinas/Lasaña.webp', 3, 1, NULL, NULL, NULL),
	(271, 20, 'Cavatappi', '/images/PRODUCTOS ABASTECETE/Despensa/Pastas y harinas/Cavatappi.webp', 3, 1, NULL, NULL, NULL),
	(272, 20, 'Harina de trigo', '/images/PRODUCTOS ABASTECETE/Despensa/Pastas y harinas/Harina de trigo.webp', 3, 1, NULL, NULL, NULL),
	(273, 20, 'Harina de maíz', '/images/PRODUCTOS ABASTECETE/Despensa/Pastas y harinas/Harina de maíz.webp', 3, 1, NULL, NULL, NULL),
	(274, 20, 'Harina de avena', '/images/PRODUCTOS ABASTECETE/Despensa/Pastas y harinas/Harina de avena.webp', 3, 1, NULL, NULL, NULL),
	(275, 20, 'Harina para pizza', '/images/PRODUCTOS ABASTECETE/Despensa/Pastas y harinas/Harina para pizza.webp', 3, 1, NULL, NULL, NULL),
	(276, 21, 'Aceite de girasol', '/images/PRODUCTOS ABASTECETE/Despensa/Aceites y vinagres/Aceite de girasol.webp', 2, 1, NULL, NULL, NULL),
	(277, 21, 'Aceite de oliva extra virgen', '/images/PRODUCTOS ABASTECETE/Despensa/Aceites y vinagres/Aceite de oliva extra virgen.webp', 2, 1, NULL, NULL, NULL),
	(278, 21, 'Aceite de coco', '/images/PRODUCTOS ABASTECETE/Despensa/Aceites y vinagres/Aceite de coco.webp', 2, 1, NULL, NULL, NULL),
	(279, 21, 'Aceite de canola', '/images/PRODUCTOS ABASTECETE/Despensa/Aceites y vinagres/Aceite de canola.webp', 2, 1, NULL, NULL, NULL),
	(280, 21, 'Vinagre blanco', '/images/PRODUCTOS ABASTECETE/Despensa/Aceites y vinagres/Vinagre blanco.webp', 2, 1, NULL, NULL, NULL),
	(281, 21, 'Vinagre balsámico', '/images/PRODUCTOS ABASTECETE/Despensa/Aceites y vinagres/Vinagre balsámico.webp', 2, 1, NULL, NULL, NULL),
	(282, 21, 'Vinagre de manzana', '/images/PRODUCTOS ABASTECETE/Despensa/Aceites y vinagres/Vinagre de manzana.webp', 2, 1, NULL, NULL, NULL),
	(283, 22, 'Salsa de tomate', '/images/PRODUCTOS ABASTECETE/Despensa/Salsas y condimentos/Salsa de tomate.webp', 3, 1, NULL, NULL, NULL),
	(284, 22, 'Mayonesa', '/images/PRODUCTOS ABASTECETE/Despensa/Salsas y condimentos/Mayonesa.webp', 3, 1, NULL, NULL, NULL),
	(285, 22, 'Mostaza', '/images/PRODUCTOS ABASTECETE/Despensa/Salsas y condimentos/Mostaza.webp', 3, 1, NULL, NULL, NULL),
	(286, 22, 'Salsa barbacoa', '/images/PRODUCTOS ABASTECETE/Despensa/Salsas y condimentos/Salsa barbacoa.webp', 3, 1, NULL, NULL, NULL),
	(287, 22, 'Salsa teriyaki', '/images/PRODUCTOS ABASTECETE/Despensa/Salsas y condimentos/Salsa teriyaki.webp', 3, 1, NULL, NULL, NULL),
	(288, 22, 'Pimienta negra', '/images/PRODUCTOS ABASTECETE/Despensa/Salsas y condimentos/Pimienta negra.webp', 3, 1, NULL, NULL, NULL),
	(289, 22, 'Comino', '/images/PRODUCTOS ABASTECETE/Despensa/Salsas y condimentos/Comino.webp', 3, 1, NULL, NULL, NULL),
	(290, 22, 'Curry', '/images/PRODUCTOS ABASTECETE/Despensa/Salsas y condimentos/Curry.webp', 3, 1, NULL, NULL, NULL),
	(291, 22, 'Orégano seco', '/images/PRODUCTOS ABASTECETE/Despensa/Salsas y condimentos/Orégano seco.webp', 3, 1, NULL, NULL, NULL),
	(292, 22, 'Ajo en polvo', '/images/PRODUCTOS ABASTECETE/Despensa/Salsas y condimentos/Ajo en polvo.webp', 3, 1, NULL, NULL, NULL),
	(293, 23, 'Café molido', '/images/PRODUCTOS ABASTECETE/Despensa/Café y bebidas calientes/Café molido.webp', 3, 1, NULL, NULL, NULL),
	(294, 23, 'Café instantáneo', '/images/PRODUCTOS ABASTECETE/Despensa/Café y bebidas calientes/Café instantáneo.webp', 3, 1, NULL, NULL, NULL),
	(295, 23, 'Café en grano', '/images/PRODUCTOS ABASTECETE/Despensa/Café y bebidas calientes/Café en grano.webp', 3, 1, NULL, NULL, NULL),
	(296, 23, 'Café descafeinado', '/images/PRODUCTOS ABASTECETE/Despensa/Café y bebidas calientes/Café descafeinado.webp', 3, 1, NULL, NULL, NULL),
	(297, 23, 'Chocolate en polvo', '/images/PRODUCTOS ABASTECETE/Despensa/Café y bebidas calientes/Chocolate en polvo.webp', 3, 1, NULL, NULL, NULL),
	(298, 23, 'Cacao instantáneo', '/images/PRODUCTOS ABASTECETE/Despensa/Café y bebidas calientes/Cacao instantáneo.webp', 3, 1, NULL, NULL, NULL),
	(299, 23, 'Té negro', '/images/PRODUCTOS ABASTECETE/Despensa/Café y bebidas calientes/Té negro.webp', 3, 1, NULL, NULL, NULL),
	(300, 23, 'Té verde', '/images/PRODUCTOS ABASTECETE/Despensa/Café y bebidas calientes/Té verde.webp', 3, 1, NULL, NULL, NULL),
	(301, 24, 'Atún en aceite', '/images/PRODUCTOS ABASTECETE/Despensa/Conservas y enlatados/Atún en aceite.webp', 3, 1, NULL, NULL, NULL),
	(302, 24, 'Atún en agua', '/images/PRODUCTOS ABASTECETE/Despensa/Conservas y enlatados/Atún en agua.webp', 3, 1, NULL, NULL, NULL),
	(303, 24, 'Sardinas enlatadas', '/images/PRODUCTOS ABASTECETE/Despensa/Conservas y enlatados/Sardinas enlatadas.webp', 3, 1, NULL, NULL, NULL),
	(304, 24, 'Vegetales mixtos enlatados', '/images/PRODUCTOS ABASTECETE/Despensa/Conservas y enlatados/Vegetales mixtos enlatados.webp', 3, 1, NULL, NULL, NULL),
	(305, 24, 'Chícharos enlatados', '/images/PRODUCTOS ABASTECETE/Despensa/Conservas y enlatados/Chícharos enlatados.webp', 3, 1, NULL, NULL, NULL),
	(306, 24, 'Maíz dulce enlatado', '/images/PRODUCTOS ABASTECETE/Despensa/Conservas y enlatados/Maíz dulce enlatado.webp', 3, 1, NULL, NULL, NULL),
	(307, 24, 'Frutas en almíbar', '/images/PRODUCTOS ABASTECETE/Despensa/Conservas y enlatados/Frutas en almíbar.webp', 3, 1, NULL, NULL, NULL),
	(308, 24, 'Purés de tomate', '/images/PRODUCTOS ABASTECETE/Despensa/Conservas y enlatados/Purés de tomate.webp', 3, 1, NULL, NULL, NULL),
	(309, 25, 'Corn Flakes', '/images/PRODUCTOS ABASTECETE/Despensa/Cereales y granolas/Corn Flakes.webp', 3, 1, NULL, NULL, NULL),
	(310, 25, 'Granola con frutos secos', '/images/PRODUCTOS ABASTECETE/Despensa/Cereales y granolas/Granola con frutos secos.webp', 3, 1, NULL, NULL, NULL),
	(311, 25, 'Granola con chocolate', '/images/PRODUCTOS ABASTECETE/Despensa/Cereales y granolas/Granola con chocolate.webp', 3, 1, NULL, NULL, NULL),
	(312, 25, 'Avena instantánea', '/images/PRODUCTOS ABASTECETE/Despensa/Cereales y granolas/Avena instantánea.webp', 3, 1, NULL, NULL, NULL),
	(313, 25, 'Cereal integral', '/images/PRODUCTOS ABASTECETE/Despensa/Cereales y granolas/Cereal integral.webp', 3, 1, NULL, NULL, NULL),
	(314, 25, 'Cereal con miel', '/images/PRODUCTOS ABASTECETE/Despensa/Cereales y granolas/Cereal con miel.webp', 3, 1, NULL, NULL, NULL),
	(315, 25, 'Cereal para niños', '/images/PRODUCTOS ABASTECETE/Despensa/Cereales y granolas/Cereal para niños.webp', 3, 1, NULL, NULL, NULL),
	(316, 25, 'Barritas de cereal', '/images/PRODUCTOS ABASTECETE/Despensa/Cereales y granolas/Barritas de cereal.webp', 3, 1, NULL, NULL, NULL),
	(317, 26, 'Azúcar blanca', '/images/PRODUCTOS ABASTECETE/Despensa/Azúcar, endulzantes y sal/Azúcar blanca.webp', 3, 1, NULL, NULL, NULL),
	(318, 26, 'Azúcar morena', '/images/PRODUCTOS ABASTECETE/Despensa/Azúcar, endulzantes y sal/Azúcar morena.webp', 3, 1, NULL, NULL, NULL),
	(319, 26, 'Panela en bloques', '/images/PRODUCTOS ABASTECETE/Despensa/Azúcar, endulzantes y sal/Panela en bloques.webp', 3, 1, NULL, NULL, NULL),
	(320, 26, 'Panela pulverizada', '/images/PRODUCTOS ABASTECETE/Despensa/Azúcar, endulzantes y sal/Panela pulverizada.webp', 3, 1, NULL, NULL, NULL),
	(321, 26, 'Miel de abejas', '/images/PRODUCTOS ABASTECETE/Despensa/Azúcar, endulzantes y sal/Miel de abejas.webp', 3, 1, NULL, NULL, NULL),
	(322, 26, 'Stevia', '/images/PRODUCTOS ABASTECETE/Despensa/Azúcar, endulzantes y sal/Stevia.webp', 3, 1, NULL, NULL, NULL),
	(323, 26, 'Eritritol', '/images/PRODUCTOS ABASTECETE/Despensa/Azúcar, endulzantes y sal/Eritritol.webp', 3, 1, NULL, NULL, NULL),
	(324, 26, 'Sal marina', '/images/PRODUCTOS ABASTECETE/Despensa/Azúcar, endulzantes y sal/Sal marina.webp', 3, 1, NULL, NULL, NULL),
	(325, 26, 'Sal rosada del Himalaya', '/images/PRODUCTOS ABASTECETE/Despensa/Azúcar, endulzantes y sal/Sal rosada del Himalaya.webp', 3, 1, NULL, NULL, NULL),
	(326, 27, 'Papas congeladas', '/images/PRODUCTOS ABASTECETE/Congelados/Verduras y tubérculos congelados/Papas congeladas.webp', 1, 1, NULL, NULL, NULL),
	(327, 27, 'Brócoli congelado', '/images/PRODUCTOS ABASTECETE/Congelados/Verduras y tubérculos congelados/Brócoli congelado.webp', 1, 1, NULL, NULL, NULL),
	(328, 27, 'Espinacas congeladas', '/images/PRODUCTOS ABASTECETE/Congelados/Verduras y tubérculos congelados/Espinacas congeladas.webp', 1, 1, NULL, NULL, NULL),
	(329, 27, 'Zanahorias congeladas', '/images/PRODUCTOS ABASTECETE/Congelados/Verduras y tubérculos congelados/Zanahorias congeladas.webp', 1, 1, NULL, NULL, NULL),
	(330, 27, 'Yuca congelada', '/images/PRODUCTOS ABASTECETE/Congelados/Verduras y tubérculos congelados/Yuca congelada.webp', 1, 1, NULL, NULL, NULL),
	(331, 27, 'Mazorca congelada', '/images/PRODUCTOS ABASTECETE/Congelados/Verduras y tubérculos congelados/Mazorca congelada.webp', 1, 1, NULL, NULL, NULL),
	(332, 27, 'Arvejas congeladas', '/images/PRODUCTOS ABASTECETE/Congelados/Verduras y tubérculos congelados/Arvejas congeladas.webp', 1, 1, NULL, NULL, NULL),
	(333, 27, 'Mezcla de verduras congeladas', '/images/PRODUCTOS ABASTECETE/Congelados/Verduras y tubérculos congelados/Mezcla de verduras congeladas.webp', 1, 1, NULL, NULL, NULL),
	(334, 28, 'Lasagna congelada', '/images/PRODUCTOS ABASTECETE/Congelados/Comidas listas para calentar/Lasagna congelada.webp', 3, 1, NULL, NULL, NULL),
	(335, 28, 'Pizza congelada', '/images/PRODUCTOS ABASTECETE/Congelados/Comidas listas para calentar/Pizza congelada.webp', 3, 1, NULL, NULL, NULL),
	(336, 28, 'Hamburguesas precocinadas', '/images/PRODUCTOS ABASTECETE/Congelados/Comidas listas para calentar/Hamburguesas precocinadas.webp', 3, 1, NULL, NULL, NULL),
	(337, 28, 'Pollo apanado congelado', '/images/PRODUCTOS ABASTECETE/Congelados/Comidas listas para calentar/Pollo apanado congelado.webp', 3, 1, NULL, NULL, NULL),
	(338, 28, 'Tacos congelados', '/images/PRODUCTOS ABASTECETE/Congelados/Comidas listas para calentar/Tacos congelados.webp', 3, 1, NULL, NULL, NULL),
	(339, 28, 'Enchiladas congeladas', '/images/PRODUCTOS ABASTECETE/Congelados/Comidas listas para calentar/Enchiladas congeladas.webp', 3, 1, NULL, NULL, NULL),
	(340, 28, 'Burritos congelados', '/images/PRODUCTOS ABASTECETE/Congelados/Comidas listas para calentar/Burritos congelados.webp', 3, 1, NULL, NULL, NULL),
	(341, 29, 'Deditos de queso', '/images/PRODUCTOS ABASTECETE/Congelados/Pasabocas congelados/Deditos de queso.webp', 3, 1, NULL, NULL, NULL),
	(342, 29, 'Empanadas congeladas', '/images/PRODUCTOS ABASTECETE/Congelados/Pasabocas congelados/Empanadas congeladas.webp', 3, 1, NULL, NULL, NULL),
	(343, 29, 'Croquetas de pollo', '/images/PRODUCTOS ABASTECETE/Congelados/Pasabocas congelados/Croquetas de pollo.webp', 3, 1, NULL, NULL, NULL),
	(344, 29, 'Palitos de pescado', '/images/PRODUCTOS ABASTECETE/Congelados/Pasabocas congelados/Palitos de pescado.webp', 3, 1, NULL, NULL, NULL),
	(345, 29, 'Spring rolls', '/images/PRODUCTOS ABASTECETE/Congelados/Pasabocas congelados/Spring rolls.webp', 3, 1, NULL, NULL, NULL),
	(346, 29, 'Mini arepas', '/images/PRODUCTOS ABASTECETE/Congelados/Pasabocas congelados/Mini arepas.webp', 3, 1, NULL, NULL, NULL),
	(347, 29, 'Pasabocas de maíz', '/images/PRODUCTOS ABASTECETE/Congelados/Pasabocas congelados/Pasabocas de maíz.webp', 3, 1, NULL, NULL, NULL),
	(348, 30, 'Helado de vainilla', '/images/PRODUCTOS ABASTECETE/Congelados/Helados y postres congelados/Helado de vainilla.webp', 3, 1, NULL, NULL, NULL),
	(349, 30, 'Helado de chocolate', '/images/PRODUCTOS ABASTECETE/Congelados/Helados y postres congelados/Helado de chocolate.webp', 3, 1, NULL, NULL, NULL),
	(350, 30, 'Paletas de frutas', '/images/PRODUCTOS ABASTECETE/Congelados/Helados y postres congelados/Paletas de frutas.webp', 3, 1, NULL, NULL, NULL),
	(351, 30, 'Brownies helados', '/images/PRODUCTOS ABASTECETE/Congelados/Helados y postres congelados/Brownies helados.webp', 3, 1, NULL, NULL, NULL),
	(352, 30, 'Sundaes', '/images/PRODUCTOS ABASTECETE/Congelados/Helados y postres congelados/Sundaes.webp', 3, 1, NULL, NULL, NULL),
	(353, 30, 'Helados sin lactosa', '/images/PRODUCTOS ABASTECETE/Congelados/Helados y postres congelados/Helados sin lactosa.webp', 3, 1, NULL, NULL, NULL),
	(354, 30, 'Tartaletas congeladas', '/images/PRODUCTOS ABASTECETE/Congelados/Helados y postres congelados/Tartaletas congeladas.webp', 3, 1, NULL, NULL, NULL),
	(355, 31, 'Coca-Cola', '/images/PRODUCTOS ABASTECETE/Bebidas/Gaseosas y sodas/Coca-Cola.webp', 2, 1, NULL, NULL, NULL),
	(356, 31, 'Pepsi', '/images/PRODUCTOS ABASTECETE/Bebidas/Gaseosas y sodas/Pepsi.webp', 2, 1, NULL, NULL, NULL),
	(357, 31, '7 Up', '/images/PRODUCTOS ABASTECETE/Bebidas/Gaseosas y sodas/7 Up.webp', 2, 1, NULL, NULL, NULL),
	(358, 31, 'Postobón', '/images/PRODUCTOS ABASTECETE/Bebidas/Gaseosas y sodas/Postobón.webp', 2, 1, NULL, NULL, NULL),
	(359, 31, 'Fanta', '/images/PRODUCTOS ABASTECETE/Bebidas/Gaseosas y sodas/Fanta.webp', 2, 1, NULL, NULL, NULL),
	(360, 31, 'Sprite', '/images/PRODUCTOS ABASTECETE/Bebidas/Gaseosas y sodas/Sprite.webp', 2, 1, NULL, NULL, NULL),
	(361, 31, 'Ginger Ale', '/images/PRODUCTOS ABASTECETE/Bebidas/Gaseosas y sodas/Ginger Ale.webp', 2, 1, NULL, NULL, NULL),
	(362, 31, 'Kola Roman', '/images/PRODUCTOS ABASTECETE/Bebidas/Gaseosas y sodas/Kola Roman.webp', 2, 1, NULL, NULL, NULL),
	(363, 32, 'Jugo de naranja', '/images/PRODUCTOS ABASTECETE/Bebidas/Jugos y zumos/Jugo de naranja.webp', 2, 1, NULL, NULL, NULL),
	(364, 32, 'Jugo de mango', '/images/PRODUCTOS ABASTECETE/Bebidas/Jugos y zumos/Jugo de mango.webp', 2, 1, NULL, NULL, NULL),
	(365, 32, 'Jugo de manzana', '/images/PRODUCTOS ABASTECETE/Bebidas/Jugos y zumos/Jugo de manzana.webp', 2, 1, NULL, NULL, NULL),
	(366, 32, 'Jugo de uva', '/images/PRODUCTOS ABASTECETE/Bebidas/Jugos y zumos/Jugo de uva.webp', 2, 1, NULL, NULL, NULL),
	(367, 32, 'Néctar de durazno', '/images/PRODUCTOS ABASTECETE/Bebidas/Jugos y zumos/Néctar de durazno.webp', 2, 1, NULL, NULL, NULL),
	(368, 32, 'Limonada natural', '/images/PRODUCTOS ABASTECETE/Bebidas/Jugos y zumos/Limonada natural.webp', 2, 1, NULL, NULL, NULL),
	(369, 32, 'Jugo tropical', '/images/PRODUCTOS ABASTECETE/Bebidas/Jugos y zumos/Jugo tropical.webp', 2, 1, NULL, NULL, NULL),
	(370, 32, 'Smoothies envasados', '/images/PRODUCTOS ABASTECETE/Bebidas/Jugos y zumos/Smoothies envasados.webp', 2, 1, NULL, NULL, NULL),
	(371, 33, 'Agua mineral', '/images/PRODUCTOS ABASTECETE/Bebidas/Agua embotellada y té/Agua mineral.webp', 2, 1, NULL, NULL, NULL),
	(372, 33, 'Agua con gas', '/images/PRODUCTOS ABASTECETE/Bebidas/Agua embotellada y té/Agua con gas.webp', 2, 1, NULL, NULL, NULL),
	(373, 33, 'Té negro', '/images/PRODUCTOS ABASTECETE/Bebidas/Agua embotellada y té/Té negro.webp', 2, 1, NULL, NULL, NULL),
	(374, 33, 'Té verde', '/images/PRODUCTOS ABASTECETE/Bebidas/Agua embotellada y té/Té verde.webp', 2, 1, NULL, NULL, NULL),
	(375, 33, 'Té de hierbas', '/images/PRODUCTOS ABASTECETE/Bebidas/Agua embotellada y té/Té de hierbas.webp', 2, 1, NULL, NULL, NULL),
	(376, 33, 'Té chai', '/images/PRODUCTOS ABASTECETE/Bebidas/Agua embotellada y té/Té chai.webp', 2, 1, NULL, NULL, NULL),
	(377, 33, 'Té helado', '/images/PRODUCTOS ABASTECETE/Bebidas/Agua embotellada y té/Té helado.webp', 2, 1, NULL, NULL, NULL),
	(378, 33, 'Infusiones frutales', '/images/PRODUCTOS ABASTECETE/Bebidas/Agua embotellada y té/Infusiones frutales.webp', 2, 1, NULL, NULL, NULL),
	(379, 34, 'Gatorade', '/images/PRODUCTOS ABASTECETE/Bebidas/Bebidas isotónicas y energizantes/Gatorade.webp', 2, 1, NULL, NULL, NULL),
	(380, 34, 'Powerade', '/images/PRODUCTOS ABASTECETE/Bebidas/Bebidas isotónicas y energizantes/Powerade.webp', 2, 1, NULL, NULL, NULL),
	(381, 34, 'Red Bull', '/images/PRODUCTOS ABASTECETE/Bebidas/Bebidas isotónicas y energizantes/Red Bull.webp', 2, 1, NULL, NULL, NULL),
	(382, 34, 'Monster Energy', '/images/PRODUCTOS ABASTECETE/Bebidas/Bebidas isotónicas y energizantes/Monster Energy.webp', 2, 1, NULL, NULL, NULL),
	(383, 34, 'Bebidas hidratantes sin azúcar', '/images/PRODUCTOS ABASTECETE/Bebidas/Bebidas isotónicas y energizantes/Bebidas hidratantes sin azúcar.webp', 2, 1, NULL, NULL, NULL),
	(384, 35, 'Chips de papa', '/images/PRODUCTOS ABASTECETE/Snacks y Aperitivos/Pasabocas empacados/Chips de papa.webp', 3, 1, NULL, NULL, NULL),
	(385, 35, 'Nachos', '/images/PRODUCTOS ABASTECETE/Snacks y Aperitivos/Pasabocas empacados/Nachos.webp', 3, 1, NULL, NULL, NULL),
	(386, 35, 'Platanitos', '/images/PRODUCTOS ABASTECETE/Snacks y Aperitivos/Pasabocas empacados/Platanitos.webp', 3, 1, NULL, NULL, NULL),
	(387, 35, 'Palomitas de maíz', '/images/PRODUCTOS ABASTECETE/Snacks y Aperitivos/Pasabocas empacados/Palomitas de maíz.webp', 3, 1, NULL, NULL, NULL),
	(388, 35, 'Cortezas de cerdo', '/images/PRODUCTOS ABASTECETE/Snacks y Aperitivos/Pasabocas empacados/Cortezas de cerdo.webp', 3, 1, NULL, NULL, NULL),
	(389, 35, 'Pasabocas de queso', '/images/PRODUCTOS ABASTECETE/Snacks y Aperitivos/Pasabocas empacados/Pasabocas de queso.webp', 3, 1, NULL, NULL, NULL),
	(390, 35, 'Pasabocas picantes', '/images/PRODUCTOS ABASTECETE/Snacks y Aperitivos/Pasabocas empacados/Pasabocas picantes.webp', 3, 1, NULL, NULL, NULL),
	(391, 36, 'Almendras', '/images/PRODUCTOS ABASTECETE/Snacks y Aperitivos/Frutos secos y semillas/Almendras.webp', 3, 1, NULL, NULL, NULL),
	(392, 36, 'Nueces', '/images/PRODUCTOS ABASTECETE/Snacks y Aperitivos/Frutos secos y semillas/Nueces.webp', 3, 1, NULL, NULL, NULL),
	(393, 36, 'Pistachos', '/images/PRODUCTOS ABASTECETE/Snacks y Aperitivos/Frutos secos y semillas/Pistachos.webp', 3, 1, NULL, NULL, NULL),
	(394, 36, 'Avellanas', '/images/PRODUCTOS ABASTECETE/Snacks y Aperitivos/Frutos secos y semillas/Avellanas.webp', 3, 1, NULL, NULL, NULL),
	(395, 36, 'Semillas de girasol', '/images/PRODUCTOS ABASTECETE/Snacks y Aperitivos/Frutos secos y semillas/Semillas de girasol.webp', 3, 1, NULL, NULL, NULL),
	(396, 36, 'Semillas de calabaza', '/images/PRODUCTOS ABASTECETE/Snacks y Aperitivos/Frutos secos y semillas/Semillas de calabaza.webp', 3, 1, NULL, NULL, NULL),
	(397, 36, 'Mix de frutos secos', '/images/PRODUCTOS ABASTECETE/Snacks y Aperitivos/Frutos secos y semillas/Mix de frutos secos.webp', 3, 1, NULL, NULL, NULL),
	(398, 36, 'Maní salado', '/images/PRODUCTOS ABASTECETE/Snacks y Aperitivos/Frutos secos y semillas/Maní salado.webp', 3, 1, NULL, NULL, NULL),
	(399, 36, 'Maní confitado', '/images/PRODUCTOS ABASTECETE/Snacks y Aperitivos/Frutos secos y semillas/Maní confitado.webp', 3, 1, NULL, NULL, NULL),
	(400, 37, 'Galletas de avena', '/images/PRODUCTOS ABASTECETE/Snacks y Aperitivos/Galletas dulces y saladas/Galletas de avena.webp', 3, 1, NULL, NULL, NULL),
	(401, 37, 'Galletas de chocolate', '/images/PRODUCTOS ABASTECETE/Snacks y Aperitivos/Galletas dulces y saladas/Galletas de chocolate.webp', 3, 1, NULL, NULL, NULL),
	(402, 37, 'Galletas de mantequilla', '/images/PRODUCTOS ABASTECETE/Snacks y Aperitivos/Galletas dulces y saladas/Galletas de mantequilla.webp', 3, 1, NULL, NULL, NULL),
	(403, 37, 'Crackers saladas', '/images/PRODUCTOS ABASTECETE/Snacks y Aperitivos/Galletas dulces y saladas/Crackers saladas.webp', 3, 1, NULL, NULL, NULL),
	(404, 37, 'Galletas integrales', '/images/PRODUCTOS ABASTECETE/Snacks y Aperitivos/Galletas dulces y saladas/Galletas integrales.webp', 3, 1, NULL, NULL, NULL),
	(405, 37, 'Galletas rellenas', '/images/PRODUCTOS ABASTECETE/Snacks y Aperitivos/Galletas dulces y saladas/Galletas rellenas.webp', 3, 1, NULL, NULL, NULL),
	(406, 38, 'Barritas de chocolate', '/images/PRODUCTOS ABASTECETE/Dulces y Chocolatería/Chocolatería fina/Barritas de chocolate.webp', 3, 1, NULL, NULL, NULL),
	(407, 38, 'Chocolates rellenos', '/images/PRODUCTOS ABASTECETE/Dulces y Chocolatería/Chocolatería fina/Chocolates rellenos.webp', 3, 1, NULL, NULL, NULL),
	(408, 38, 'Trufas', '/images/PRODUCTOS ABASTECETE/Dulces y Chocolatería/Chocolatería fina/Trufas.webp', 3, 1, NULL, NULL, NULL),
	(409, 38, 'Bombones de chocolate', '/images/PRODUCTOS ABASTECETE/Dulces y Chocolatería/Chocolatería fina/Bombones de chocolate.webp', 3, 1, NULL, NULL, NULL),
	(410, 39, 'Caramelos duros', '/images/PRODUCTOS ABASTECETE/Dulces y Chocolatería/Confitería/Caramelos duros.webp', 3, 1, NULL, NULL, NULL),
	(411, 39, 'Caramelos masticables', '/images/PRODUCTOS ABASTECETE/Dulces y Chocolatería/Confitería/Caramelos masticables.webp', 3, 1, NULL, NULL, NULL),
	(412, 39, 'Gomitas', '/images/PRODUCTOS ABASTECETE/Dulces y Chocolatería/Confitería/Gomitas.webp', 3, 1, NULL, NULL, NULL),
	(413, 39, 'Masmelos', '/images/PRODUCTOS ABASTECETE/Dulces y Chocolatería/Confitería/Masmelos.webp', 3, 1, NULL, NULL, NULL),
	(414, 39, 'Dulces ácidos', '/images/PRODUCTOS ABASTECETE/Dulces y Chocolatería/Confitería/Dulces ácidos.webp', 3, 1, NULL, NULL, NULL),
	(415, 40, 'Arequipe tradicional', '/images/PRODUCTOS ABASTECETE/Dulces y Chocolatería/Arequipe y derivados lácteos dulces/Arequipe tradicional.webp', 3, 1, NULL, NULL, NULL),
	(416, 40, 'Arequipe con chocolate', '/images/PRODUCTOS ABASTECETE/Dulces y Chocolatería/Arequipe y derivados lácteos dulces/Arequipe con chocolate.webp', 3, 1, NULL, NULL, NULL),
	(417, 40, 'Leche condensada', '/images/PRODUCTOS ABASTECETE/Dulces y Chocolatería/Arequipe y derivados lácteos dulces/Leche condensada.webp', 3, 1, NULL, NULL, NULL),
	(418, 40, 'Dulce de leche', '/images/PRODUCTOS ABASTECETE/Dulces y Chocolatería/Arequipe y derivados lácteos dulces/Dulce de leche.webp', 3, 1, NULL, NULL, NULL),
	(419, 41, 'Chicles de menta', '/images/PRODUCTOS ABASTECETE/Dulces y Chocolatería/Chicles y masticables/Chicles de menta.webp', 3, 1, NULL, NULL, NULL),
	(420, 41, 'Chicles de frutas', '/images/PRODUCTOS ABASTECETE/Dulces y Chocolatería/Chicles y masticables/Chicles de frutas.webp', 3, 1, NULL, NULL, NULL),
	(421, 41, 'Chicles sin azúcar', '/images/PRODUCTOS ABASTECETE/Dulces y Chocolatería/Chicles y masticables/Chicles sin azúcar.webp', 3, 1, NULL, NULL, NULL),
	(422, 41, 'Caramelos elásticos', '/images/PRODUCTOS ABASTECETE/Dulces y Chocolatería/Chicles y masticables/Caramelos elásticos.webp', 3, 1, NULL, NULL, NULL),
	(423, 42, 'Queso parmesano', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Quesos madurados y gourmet/Queso parmesano.webp', 1, 1, NULL, NULL, NULL),
	(424, 42, 'Queso gouda', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Quesos madurados y gourmet/Queso gouda.webp', 1, 1, NULL, NULL, NULL),
	(425, 42, 'Queso brie', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Quesos madurados y gourmet/Queso brie.webp', 1, 1, NULL, NULL, NULL),
	(426, 42, 'Queso camembert', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Quesos madurados y gourmet/Queso camembert.webp', 1, 1, NULL, NULL, NULL),
	(427, 42, 'Queso roquefort', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Quesos madurados y gourmet/Queso roquefort.webp', 1, 1, NULL, NULL, NULL),
	(428, 42, 'Queso pecorino', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Quesos madurados y gourmet/Queso pecorino.webp', 1, 1, NULL, NULL, NULL),
	(429, 42, 'Queso emmental', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Quesos madurados y gourmet/Queso emmental.webp', 1, 1, NULL, NULL, NULL),
	(430, 42, 'Queso gruyere', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Quesos madurados y gourmet/Queso gruyere.webp', 1, 1, NULL, NULL, NULL),
	(431, 42, 'Queso manchego', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Quesos madurados y gourmet/Queso manchego.webp', 1, 1, NULL, NULL, NULL),
	(432, 42, 'Queso azul', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Quesos madurados y gourmet/Queso azul.webp', 1, 1, NULL, NULL, NULL),
	(433, 43, 'Jamón serrano', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Carnes curadas y especiales/Jamón serrano.webp', 1, 1, NULL, NULL, NULL),
	(434, 43, 'Jamón ibérico', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Carnes curadas y especiales/Jamón ibérico.webp', 1, 1, NULL, NULL, NULL),
	(435, 43, 'Prosciutto', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Carnes curadas y especiales/Prosciutto.webp', 1, 1, NULL, NULL, NULL),
	(436, 43, 'Salami', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Carnes curadas y especiales/Salami.webp', 1, 1, NULL, NULL, NULL),
	(437, 43, 'Pastrami', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Carnes curadas y especiales/Pastrami.webp', 1, 1, NULL, NULL, NULL),
	(438, 43, 'Bresaola', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Carnes curadas y especiales/Bresaola.webp', 1, 1, NULL, NULL, NULL),
	(439, 43, 'Lomo embuchado', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Carnes curadas y especiales/Lomo embuchado.webp', 1, 1, NULL, NULL, NULL),
	(440, 43, 'Longaniza', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Carnes curadas y especiales/Longaniza.webp', 1, 1, NULL, NULL, NULL),
	(441, 43, 'Cecina', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Carnes curadas y especiales/Cecina.webp', 1, 1, NULL, NULL, NULL),
	(442, 43, 'Sobrasada', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Carnes curadas y especiales/Sobrasada.webp', 1, 1, NULL, NULL, NULL),
	(443, 44, 'Pepinillos encurtidos', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Encurtidos, conservas y patés/Pepinillos encurtidos.webp', 3, 1, NULL, NULL, NULL),
	(444, 44, 'Aceitunas verdes', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Encurtidos, conservas y patés/Aceitunas verdes.webp', 3, 1, NULL, NULL, NULL),
	(445, 44, 'Aceitunas negras', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Encurtidos, conservas y patés/Aceitunas negras.webp', 3, 1, NULL, NULL, NULL),
	(446, 44, 'Corazones de alcachofa', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Encurtidos, conservas y patés/Corazones de alcachofa.webp', 3, 1, NULL, NULL, NULL),
	(447, 44, 'Paté de hígado', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Encurtidos, conservas y patés/Paté de hígado.webp', 3, 1, NULL, NULL, NULL),
	(448, 44, 'Paté de cerdo', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Encurtidos, conservas y patés/Paté de cerdo.webp', 3, 1, NULL, NULL, NULL),
	(449, 44, 'Conserva de champiñones', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Encurtidos, conservas y patés/Conserva de champiñones.webp', 3, 1, NULL, NULL, NULL),
	(450, 44, 'Conserva de espárragos', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Encurtidos, conservas y patés/Conserva de espárragos.webp', 3, 1, NULL, NULL, NULL),
	(451, 44, 'Chiles encurtidos', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Encurtidos, conservas y patés/Chiles encurtidos.webp', 3, 1, NULL, NULL, NULL),
	(452, 44, 'Tapenade', '/images/PRODUCTOS ABASTECETE/Charcutería y Especialidades/Encurtidos, conservas y patés/Tapenade.webp', 3, 1, NULL, NULL, NULL),
	(453, 45, 'Detergente líquido', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Jabones y detergentes/Detergente líquido.webp', 3, 1, NULL, NULL, NULL),
	(454, 45, 'Detergente en polvo', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Jabones y detergentes/Detergente en polvo.webp', 3, 1, NULL, NULL, NULL),
	(455, 45, 'Jabón para ropa delicada', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Jabones y detergentes/Jabón para ropa delicada.webp', 3, 1, NULL, NULL, NULL),
	(456, 45, 'Jabón líquido multiuso', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Jabones y detergentes/Jabón líquido multiuso.webp', 3, 1, NULL, NULL, NULL),
	(457, 45, 'Detergente para ropa oscura', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Jabones y detergentes/Detergente para ropa oscura.webp', 3, 1, NULL, NULL, NULL),
	(458, 45, 'Detergente para ropa blanca', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Jabones y detergentes/Detergente para ropa blanca.webp', 3, 1, NULL, NULL, NULL),
	(459, 45, 'Jabón en barra', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Jabones y detergentes/Jabón en barra.webp', 3, 1, NULL, NULL, NULL),
	(460, 46, 'Limpiador en spray', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Limpiadores multiusos/Limpiador en spray.webp', 2, 1, NULL, NULL, NULL),
	(461, 46, 'Limpiador concentrado', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Limpiadores multiusos/Limpiador concentrado.webp', 2, 1, NULL, NULL, NULL),
	(462, 46, 'Limpiador con cloro', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Limpiadores multiusos/Limpiador con cloro.webp', 2, 1, NULL, NULL, NULL),
	(463, 46, 'Limpiador antibacterial', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Limpiadores multiusos/Limpiador antibacterial.webp', 2, 1, NULL, NULL, NULL),
	(464, 46, 'Limpiador ecológico', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Limpiadores multiusos/Limpiador ecológico.webp', 2, 1, NULL, NULL, NULL),
	(465, 46, 'Limpiador aromático', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Limpiadores multiusos/Limpiador aromático.webp', 2, 1, NULL, NULL, NULL),
	(466, 47, 'Papel higiénico de hoja sencilla', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Papel higiénico y servilletas/Papel higiénico de hoja sencilla.webp', 3, 1, NULL, NULL, NULL),
	(467, 47, 'Papel higiénico de hoja doble', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Papel higiénico y servilletas/Papel higiénico de hoja doble.webp', 3, 1, NULL, NULL, NULL),
	(468, 47, 'Servilletas blancas', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Papel higiénico y servilletas/Servilletas blancas.webp', 3, 1, NULL, NULL, NULL),
	(469, 47, 'Servilletas decorativas', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Papel higiénico y servilletas/Servilletas decorativas.webp', 3, 1, NULL, NULL, NULL),
	(470, 47, 'Rollos de cocina', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Papel higiénico y servilletas/Rollos de cocina.webp', 3, 1, NULL, NULL, NULL),
	(471, 47, 'Toallas de papel absorbente', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Papel higiénico y servilletas/Toallas de papel absorbente.webp', 3, 1, NULL, NULL, NULL),
	(472, 48, 'Ambientador en spray', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Ambientadores y control de plagas/Ambientador en spray.webp', 2, 1, NULL, NULL, NULL),
	(473, 48, 'Ambientador en gel', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Ambientadores y control de plagas/Ambientador en gel.webp', 2, 1, NULL, NULL, NULL),
	(474, 48, 'Velas aromáticas', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Ambientadores y control de plagas/Velas aromáticas.webp', 2, 1, NULL, NULL, NULL),
	(475, 48, 'Difusores de aroma', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Ambientadores y control de plagas/Difusores de aroma.webp', 2, 1, NULL, NULL, NULL),
	(476, 48, 'Insecticida en aerosol', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Ambientadores y control de plagas/Insecticida en aerosol.webp', 2, 1, NULL, NULL, NULL),
	(477, 48, 'Insecticida eléctrico', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Ambientadores y control de plagas/Insecticida eléctrico.webp', 2, 1, NULL, NULL, NULL),
	(478, 48, 'Trampas para insectos', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Ambientadores y control de plagas/Trampas para insectos.webp', 2, 1, NULL, NULL, NULL),
	(479, 49, 'Esponjas', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Implementos de limpieza/Esponjas.webp', 3, 1, NULL, NULL, NULL),
	(480, 49, 'Trapos de microfibra', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Implementos de limpieza/Trapos de microfibra.webp', 3, 1, NULL, NULL, NULL),
	(481, 49, 'Escobas', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Implementos de limpieza/Escobas.webp', 3, 1, NULL, NULL, NULL),
	(482, 49, 'Cepillos de limpieza', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Implementos de limpieza/Cepillos de limpieza.webp', 3, 1, NULL, NULL, NULL),
	(483, 49, 'Trapeadores', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Implementos de limpieza/Trapeadores.webp', 3, 1, NULL, NULL, NULL),
	(484, 49, 'Plumeros', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Implementos de limpieza/Plumeros.webp', 3, 1, NULL, NULL, NULL),
	(485, 49, 'Baldes', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Implementos de limpieza/Baldes.webp', 3, 1, NULL, NULL, NULL),
	(486, 49, 'Guantes de látex', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Implementos de limpieza/Guantes de látex.webp', 3, 1, NULL, NULL, NULL),
	(487, 49, 'Paños absorbentes', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Implementos de limpieza/Paños absorbentes.webp', 3, 1, NULL, NULL, NULL),
	(488, 49, 'Raspadores', '/images/PRODUCTOS ABASTECETE/Aseo del Hogar/Implementos de limpieza/Raspadores.webp', 3, 1, NULL, NULL, NULL),
	(489, 50, 'Shampoo para cabello seco', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Cuidado capilar/Shampoo para cabello seco.webp', 2, 1, NULL, NULL, NULL),
	(490, 50, 'Shampoo para cabello graso', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Cuidado capilar/Shampoo para cabello graso.webp', 2, 1, NULL, NULL, NULL),
	(491, 50, 'Acondicionador hidratante', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Cuidado capilar/Acondicionador hidratante.webp', 2, 1, NULL, NULL, NULL),
	(492, 50, 'Mascarilla capilar', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Cuidado capilar/Mascarilla capilar.webp', 2, 1, NULL, NULL, NULL),
	(493, 50, 'Sérum para puntas abiertas', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Cuidado capilar/Sérum para puntas abiertas.webp', 2, 1, NULL, NULL, NULL),
	(494, 50, 'Aceite capilar', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Cuidado capilar/Aceite capilar.webp', 2, 1, NULL, NULL, NULL),
	(495, 50, 'Spray para peinar', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Cuidado capilar/Spray para peinar.webp', 2, 1, NULL, NULL, NULL),
	(496, 51, 'Crema hidratante facial', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Cuidado facial y corporal/Crema hidratante facial.webp', 2, 1, NULL, NULL, NULL),
	(497, 51, 'Protector solar', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Cuidado facial y corporal/Protector solar.webp', 2, 1, NULL, NULL, NULL),
	(498, 51, 'Tónico facial', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Cuidado facial y corporal/Tónico facial.webp', 2, 1, NULL, NULL, NULL),
	(499, 51, 'Jabón corporal líquido', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Cuidado facial y corporal/Jabón corporal líquido.webp', 2, 1, NULL, NULL, NULL),
	(500, 51, 'Exfoliante corporal', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Cuidado facial y corporal/Exfoliante corporal.webp', 2, 1, NULL, NULL, NULL),
	(501, 51, 'Crema para manos', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Cuidado facial y corporal/Crema para manos.webp', 2, 1, NULL, NULL, NULL),
	(502, 51, 'Aceite corporal', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Cuidado facial y corporal/Aceite corporal.webp', 2, 1, NULL, NULL, NULL),
	(503, 51, 'Gel de aloe vera', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Cuidado facial y corporal/Gel de aloe vera.webp', 2, 1, NULL, NULL, NULL),
	(504, 52, 'Toallas higiénicas', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Higiene íntima/Toallas higiénicas.webp', 3, 1, NULL, NULL, NULL),
	(505, 52, 'Tampones', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Higiene íntima/Tampones.webp', 3, 1, NULL, NULL, NULL),
	(506, 52, 'Copa menstrual', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Higiene íntima/Copa menstrual.webp', 3, 1, NULL, NULL, NULL),
	(507, 52, 'Jabón íntimo', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Higiene íntima/Jabón íntimo.webp', 3, 1, NULL, NULL, NULL),
	(508, 52, 'Toallas húmedas íntimas', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Higiene íntima/Toallas húmedas íntimas.webp', 3, 1, NULL, NULL, NULL),
	(509, 52, 'Protegeslips', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Higiene íntima/Protegeslips.webp', 3, 1, NULL, NULL, NULL),
	(510, 53, 'Pañales desechables', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Higiene para bebés y niños/Pañales desechables.webp', 3, 1, NULL, NULL, NULL),
	(511, 53, 'Pañales ecológicos', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Higiene para bebés y niños/Pañales ecológicos.webp', 3, 1, NULL, NULL, NULL),
	(512, 53, 'Toallitas húmedas', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Higiene para bebés y niños/Toallitas húmedas.webp', 3, 1, NULL, NULL, NULL),
	(513, 53, 'Jabón líquido para bebés', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Higiene para bebés y niños/Jabón líquido para bebés.webp', 3, 1, NULL, NULL, NULL),
	(514, 53, 'Shampoo para bebés', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Higiene para bebés y niños/Shampoo para bebés.webp', 3, 1, NULL, NULL, NULL),
	(515, 53, 'Crema antipañalitis', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Higiene para bebés y niños/Crema antipañalitis.webp', 3, 1, NULL, NULL, NULL),
	(516, 53, 'Loción hidratante para bebés', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Higiene para bebés y niños/Loción hidratante para bebés.webp', 3, 1, NULL, NULL, NULL),
	(517, 54, 'Preservativos de látex', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Bienestar sexual/Preservativos de látex.webp', 3, 1, NULL, NULL, NULL),
	(518, 54, 'Preservativos sin látex', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Bienestar sexual/Preservativos sin látex.webp', 3, 1, NULL, NULL, NULL),
	(519, 54, 'Lubricantes a base de agua', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Bienestar sexual/Lubricantes a base de agua.webp', 3, 1, NULL, NULL, NULL),
	(520, 54, 'Lubricantes a base de silicona', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Bienestar sexual/Lubricantes a base de silicona.webp', 3, 1, NULL, NULL, NULL),
	(521, 54, 'Anillos estimulantes', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Bienestar sexual/Anillos estimulantes.webp', 3, 1, NULL, NULL, NULL),
	(522, 55, 'Bloqueador solar FPS 30', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Protección solar y repelentes/Bloqueador solar FPS 30.webp', 2, 1, NULL, NULL, NULL),
	(523, 55, 'Bloqueador solar FPS 50', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Protección solar y repelentes/Bloqueador solar FPS 50.webp', 2, 1, NULL, NULL, NULL),
	(524, 55, 'Protector solar en spray', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Protección solar y repelentes/Protector solar en spray.webp', 2, 1, NULL, NULL, NULL),
	(525, 55, 'Repelente en crema', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Protección solar y repelentes/Repelente en crema.webp', 2, 1, NULL, NULL, NULL),
	(526, 55, 'Repelente en aerosol', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Protección solar y repelentes/Repelente en aerosol.webp', 2, 1, NULL, NULL, NULL),
	(527, 55, 'Pulseras repelentes', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Protección solar y repelentes/Pulseras repelentes.webp', 2, 1, NULL, NULL, NULL),
	(528, 56, 'Analgésicos', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Salud y medicamentos/Analgésicos.webp', 3, 1, NULL, NULL, NULL),
	(529, 56, 'Antiinflamatorios', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Salud y medicamentos/Antiinflamatorios.webp', 3, 1, NULL, NULL, NULL),
	(530, 56, 'Jarabe para la tos', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Salud y medicamentos/Jarabe para la tos.webp', 3, 1, NULL, NULL, NULL),
	(531, 56, 'Vitaminas y suplementos', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Salud y medicamentos/Vitaminas y suplementos.webp', 3, 1, NULL, NULL, NULL),
	(532, 56, 'Medicamentos antialérgicos', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Salud y medicamentos/Medicamentos antialérgicos.webp', 3, 1, NULL, NULL, NULL),
	(533, 56, 'Pastillas para el dolor de garganta', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Salud y medicamentos/Pastillas para el dolor de garganta.webp', 3, 1, NULL, NULL, NULL),
	(534, 56, 'Ungüentos tópicos', '/images/PRODUCTOS ABASTECETE/Cuidado Personal/Salud y medicamentos/Ungüentos tópicos.webp', 3, 1, NULL, NULL, NULL),
	(535, 57, 'Cerveza lager', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Cervezas/Cerveza lager.webp', 2, 1, NULL, NULL, NULL),
	(536, 57, 'Cerveza pilsner', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Cervezas/Cerveza pilsner.webp', 2, 1, NULL, NULL, NULL),
	(537, 57, 'Cerveza stout', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Cervezas/Cerveza stout.webp', 2, 1, NULL, NULL, NULL),
	(538, 57, 'Cerveza IPA', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Cervezas/Cerveza IPA.webp', 2, 1, NULL, NULL, NULL),
	(539, 57, 'Cerveza artesanal', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Cervezas/Cerveza artesanal.webp', 2, 1, NULL, NULL, NULL),
	(540, 57, 'Cerveza sin alcohol', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Cervezas/Cerveza sin alcohol.webp', 2, 1, NULL, NULL, NULL),
	(541, 57, 'Cerveza rubia', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Cervezas/Cerveza rubia.webp', 2, 1, NULL, NULL, NULL),
	(542, 57, 'Cerveza roja', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Cervezas/Cerveza roja.webp', 2, 1, NULL, NULL, NULL),
	(543, 58, 'Vino tinto', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Vinos/Vino tinto.webp', 2, 1, NULL, NULL, NULL),
	(544, 58, 'Vino blanco', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Vinos/Vino blanco.webp', 2, 1, NULL, NULL, NULL),
	(545, 58, 'Vino rosado', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Vinos/Vino rosado.webp', 2, 1, NULL, NULL, NULL),
	(546, 58, 'Vino espumoso', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Vinos/Vino espumoso.webp', 2, 1, NULL, NULL, NULL),
	(547, 58, 'Vino de postre', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Vinos/Vino de postre.webp', 2, 1, NULL, NULL, NULL),
	(548, 58, 'Vino orgánico', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Vinos/Vino orgánico.webp', 2, 1, NULL, NULL, NULL),
	(549, 58, 'Vino crianza', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Vinos/Vino crianza.webp', 2, 1, NULL, NULL, NULL),
	(550, 58, 'Vino reserva', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Vinos/Vino reserva.webp', 2, 1, NULL, NULL, NULL),
	(551, 59, 'Whisky escocés', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Whisky y ron/Whisky escocés.webp', 2, 1, NULL, NULL, NULL),
	(552, 59, 'Whisky irlandés', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Whisky y ron/Whisky irlandés.webp', 2, 1, NULL, NULL, NULL),
	(553, 59, 'Whisky americano', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Whisky y ron/Whisky americano.webp', 2, 1, NULL, NULL, NULL),
	(554, 59, 'Ron oscuro', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Whisky y ron/Ron oscuro.webp', 2, 1, NULL, NULL, NULL),
	(555, 59, 'Ron dorado', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Whisky y ron/Ron dorado.webp', 2, 1, NULL, NULL, NULL),
	(556, 59, 'Ron blanco', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Whisky y ron/Ron blanco.webp', 2, 1, NULL, NULL, NULL),
	(557, 59, 'Ron especiado', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Whisky y ron/Ron especiado.webp', 2, 1, NULL, NULL, NULL),
	(558, 60, 'Tequila blanco', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Tequilas y otros destilados/Tequila blanco.webp', 2, 1, NULL, NULL, NULL),
	(559, 60, 'Tequila reposado', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Tequilas y otros destilados/Tequila reposado.webp', 2, 1, NULL, NULL, NULL),
	(560, 60, 'Tequila añejo', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Tequilas y otros destilados/Tequila añejo.webp', 2, 1, NULL, NULL, NULL),
	(561, 60, 'Tequila extra añejo', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Tequilas y otros destilados/Tequila extra añejo.webp', 2, 1, NULL, NULL, NULL),
	(562, 60, 'Mezcal', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Tequilas y otros destilados/Mezcal.webp', 2, 1, NULL, NULL, NULL),
	(563, 60, 'Vodka', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Tequilas y otros destilados/Vodka.webp', 2, 1, NULL, NULL, NULL),
	(564, 60, 'Gin', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Tequilas y otros destilados/Gin.webp', 2, 1, NULL, NULL, NULL),
	(565, 60, 'Aguardiente', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Tequilas y otros destilados/Aguardiente.webp', 2, 1, NULL, NULL, NULL),
	(566, 61, 'Vermouth', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Coctelería/Vermouth.webp', 2, 1, NULL, NULL, NULL),
	(567, 61, 'Aperol', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Coctelería/Aperol.webp', 2, 1, NULL, NULL, NULL),
	(568, 61, 'Campari', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Coctelería/Campari.webp', 2, 1, NULL, NULL, NULL),
	(569, 61, 'Triple sec', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Coctelería/Triple sec.webp', 2, 1, NULL, NULL, NULL),
	(570, 61, 'Cointreau', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Coctelería/Cointreau.webp', 2, 1, NULL, NULL, NULL),
	(571, 61, 'Jugo de limón para coctelería', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Coctelería/Jugo de limón para coctelería.webp', 2, 1, NULL, NULL, NULL),
	(572, 61, 'Jarabe de azúcar', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Coctelería/Jarabe de azúcar.webp', 2, 1, NULL, NULL, NULL),
	(573, 61, 'Bitters', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Coctelería/Bitters.webp', 2, 1, NULL, NULL, NULL),
	(574, 62, 'Cigarrillos mentolados', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Cigarrillos y vapeadores/Cigarrillos mentolados.webp', 3, 1, NULL, NULL, NULL),
	(575, 62, 'Cigarrillos light', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Cigarrillos y vapeadores/Cigarrillos light.webp', 3, 1, NULL, NULL, NULL),
	(576, 62, 'Vapeadores desechables', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Cigarrillos y vapeadores/Vapeadores desechables.webp', 3, 1, NULL, NULL, NULL),
	(577, 62, 'Vapeadores recargables', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Cigarrillos y vapeadores/Vapeadores recargables.webp', 3, 1, NULL, NULL, NULL),
	(578, 62, 'Pods de nicotina', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Cigarrillos y vapeadores/Pods de nicotina.webp', 3, 1, NULL, NULL, NULL),
	(579, 62, 'Líquidos para vapeadores', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Cigarrillos y vapeadores/Líquidos para vapeadores.webp', 3, 1, NULL, NULL, NULL),
	(580, 62, 'Cigarrillos electrónicos', '/images/PRODUCTOS ABASTECETE/Licores y Tabaco/Cigarrillos y vapeadores/Cigarrillos electrónicos.webp', 3, 1, NULL, NULL, NULL),
	(581, 38, 'Chocolatería fina', '/images/PRODUCTOS ABASTECETE/Dulces y Chocolatería/Chocolatería fina/Chocolatería fina.webp', 3, 1, NULL, NULL, NULL),
	(583, 51, 'Prueba', 'https://res.cloudinary.com/dwl5ggfhd/image/upload/v1766234586/productos/ffjleq3lqniflonmphg0.png', 3, 1, 'aaaaaaaaaaaaaaaa', 'prueba-000', 'productos/ffjleq3lqniflonmphg0');

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
) ENGINE=InnoDB AUTO_INCREMENT=131 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Volcando datos para la tabla abastecete.productoslocal: ~27 rows (aproximadamente)
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
	(129, 143, 1, 6000, 27, 1),
	(130, 205, 1, 5000, 28, 1);

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

-- Volcando estructura para procedimiento abastecete.renovar_suscripcion
DELIMITER //
CREATE PROCEDURE `renovar_suscripcion`(
    IN p_id_suscripcion INT,
    IN p_periodo VARCHAR(20),
    IN p_monto DECIMAL(10,2),
    IN p_metodo_pago VARCHAR(50)
)
BEGIN
    DECLARE v_id_local INT;
    DECLARE v_id_tipo_membresia INT;
    DECLARE v_fecha_fin_actual DATETIME;
    DECLARE v_nueva_fecha_fin DATETIME;

    -- Obtener datos de la suscripción actual
    SELECT FK_ID_LOCAL, FK_ID_TIPO_MEMBRESIA, FECHA_FIN
    INTO v_id_local, v_id_tipo_membresia, v_fecha_fin_actual
    FROM suscripcion
    WHERE PK_ID_SUSCRIPCION = p_id_suscripcion;

    -- Calcular nueva fecha fin (extender desde la fecha actual o la fecha fin actual, lo que sea mayor)
    SET v_nueva_fecha_fin = GREATEST(v_fecha_fin_actual, NOW());
    SET v_nueva_fecha_fin = CASE p_periodo
        WHEN 'MENSUAL' THEN DATE_ADD(v_nueva_fecha_fin, INTERVAL 1 MONTH)
        WHEN 'TRIMESTRAL' THEN DATE_ADD(v_nueva_fecha_fin, INTERVAL 3 MONTH)
        WHEN 'SEMESTRAL' THEN DATE_ADD(v_nueva_fecha_fin, INTERVAL 6 MONTH)
        WHEN 'ANUAL' THEN DATE_ADD(v_nueva_fecha_fin, INTERVAL 1 YEAR)
        ELSE DATE_ADD(v_nueva_fecha_fin, INTERVAL 1 MONTH)
    END;

    -- Actualizar suscripción
    UPDATE suscripcion
    SET FECHA_FIN = v_nueva_fecha_fin,
        MONTO_PAGADO = COALESCE(MONTO_PAGADO, 0) + p_monto,
        METODO_PAGO = p_metodo_pago,
        PERIODO = p_periodo,
        ESTADO = 1
    WHERE PK_ID_SUSCRIPCION = p_id_suscripcion;

    -- Registrar en historial
    INSERT INTO historial_membresia (
        FK_ID_LOCAL,
        FK_ID_SUSCRIPCION,
        FK_ID_TIPO_ANTERIOR,
        FK_ID_TIPO_NUEVO,
        TIPO_CAMBIO,
        FECHA_INICIO_PERIODO,
        FECHA_FIN_PERIODO,
        MONTO,
        PERIODO,
        NOTAS
    ) VALUES (
        v_id_local,
        p_id_suscripcion,
        v_id_tipo_membresia,
        v_id_tipo_membresia,
        'RENOVACION',
        GREATEST(v_fecha_fin_actual, NOW()),
        v_nueva_fecha_fin,
        p_monto,
        p_periodo,
        'Renovación de suscripción'
    );

    SELECT p_id_suscripcion AS IdSuscripcion, v_nueva_fecha_fin AS NuevaFechaFin;
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

-- Volcando estructura para procedimiento abastecete.revisar_imagen_galeria
DELIMITER //
CREATE PROCEDURE `revisar_imagen_galeria`(
    IN p_id_galeria INT,
    IN p_estado INT,
    IN p_id_revisor INT,
    IN p_motivo_rechazo VARCHAR(255)
)
BEGIN
    UPDATE galeria_local SET
        ESTADO = p_estado,
        FECHA_REVISION = NOW(),
        FK_ID_USUARIO_REVISOR = p_id_revisor,
        MOTIVO_RECHAZO = CASE WHEN p_estado = 2 THEN p_motivo_rechazo ELSE NULL END
    WHERE PK_ID_GALERIA = p_id_galeria;
END//
DELIMITER ;

-- Volcando estructura para tabla abastecete.rol
CREATE TABLE IF NOT EXISTS `rol` (
  `PK_ID_ROL` int NOT NULL AUTO_INCREMENT,
  `NOMBRE_ROL` varchar(20) NOT NULL,
  PRIMARY KEY (`PK_ID_ROL`)
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Volcando datos para la tabla abastecete.rol: ~5 rows (aproximadamente)
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

-- Volcando estructura para tabla abastecete.suscripcion
CREATE TABLE IF NOT EXISTS `suscripcion` (
  `PK_ID_SUSCRIPCION` int NOT NULL AUTO_INCREMENT,
  `FK_ID_LOCAL` int NOT NULL,
  `FK_ID_TIPO_MEMBRESIA` int NOT NULL,
  `ESTADO` tinyint NOT NULL DEFAULT '1' COMMENT '1=Activa, 0=Inactiva, 2=Cancelada, 3=Vencida',
  `FECHA_INICIO` datetime NOT NULL,
  `FECHA_FIN` datetime NOT NULL,
  `FECHA_CREACION` datetime DEFAULT CURRENT_TIMESTAMP,
  `MONTO_PAGADO` decimal(10,2) DEFAULT NULL,
  `METODO_PAGO` varchar(50) DEFAULT NULL,
  `PERIODO` enum('MENSUAL','TRIMESTRAL','SEMESTRAL','ANUAL') DEFAULT 'MENSUAL',
  `NOTAS` text,
  PRIMARY KEY (`PK_ID_SUSCRIPCION`),
  KEY `FK_suscripcion_tipo` (`FK_ID_TIPO_MEMBRESIA`),
  KEY `IDX_suscripcion_local` (`FK_ID_LOCAL`),
  KEY `IDX_suscripcion_estado` (`ESTADO`),
  KEY `IDX_suscripcion_fecha_fin` (`FECHA_FIN`),
  CONSTRAINT `FK_suscripcion_local` FOREIGN KEY (`FK_ID_LOCAL`) REFERENCES `local` (`PK_ID_LOCAL`) ON DELETE CASCADE,
  CONSTRAINT `FK_suscripcion_tipo` FOREIGN KEY (`FK_ID_TIPO_MEMBRESIA`) REFERENCES `tipo_membresia` (`PK_ID_TIPO_MEMBRESIA`)
) ENGINE=InnoDB AUTO_INCREMENT=17 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Volcando datos para la tabla abastecete.suscripcion: ~25 rows (aproximadamente)
INSERT INTO `suscripcion` (`PK_ID_SUSCRIPCION`, `FK_ID_LOCAL`, `FK_ID_TIPO_MEMBRESIA`, `ESTADO`, `FECHA_INICIO`, `FECHA_FIN`, `FECHA_CREACION`, `MONTO_PAGADO`, `METODO_PAGO`, `PERIODO`, `NOTAS`) VALUES
	(1, 1, 12, 0, '2025-02-20 10:05:41', '2025-03-20 10:05:41', '2025-12-19 05:42:03', NULL, NULL, 'MENSUAL', 'Migrado automáticamente desde membresia_local'),
	(2, 3, 18, 0, '2025-02-20 10:43:17', '2025-03-20 10:43:17', '2025-12-19 05:42:03', NULL, NULL, 'MENSUAL', 'Migrado automáticamente desde membresia_local'),
	(3, 21, 17, 0, '2025-03-22 11:18:16', '2025-04-22 11:18:16', '2025-12-19 05:42:03', NULL, NULL, 'MENSUAL', 'Migrado automáticamente desde membresia_local'),
	(4, 23, 13, 0, '2025-03-31 20:15:55', '2025-04-30 20:15:55', '2025-12-19 05:42:03', NULL, NULL, 'MENSUAL', 'Migrado automáticamente desde membresia_local'),
	(5, 24, 16, 0, '2025-04-01 15:31:50', '2025-05-01 15:31:50', '2025-12-19 05:42:03', NULL, NULL, 'MENSUAL', 'Migrado automáticamente desde membresia_local'),
	(6, 26, 16, 0, '2025-04-02 20:33:17', '2025-05-02 20:33:17', '2025-12-19 05:42:03', NULL, NULL, 'MENSUAL', 'Migrado automáticamente desde membresia_local'),
	(7, 27, 13, 0, '2025-04-10 03:18:21', '2025-05-10 03:18:21', '2025-12-19 05:42:03', NULL, NULL, 'MENSUAL', 'Migrado automáticamente desde membresia_local'),
	(8, 28, 11, 0, '2025-04-21 15:28:29', '2025-05-21 15:28:29', '2025-12-19 05:42:03', NULL, NULL, 'MENSUAL', 'Migrado automáticamente desde membresia_local'),
	(9, 29, 19, 0, '2025-04-26 09:25:06', '2025-05-26 09:25:06', '2025-12-19 05:42:03', NULL, NULL, 'MENSUAL', 'Migrado automáticamente desde membresia_local'),
	(10, 34, 11, 0, '2025-06-16 23:43:32', '2025-07-16 23:43:32', '2025-12-19 05:42:03', NULL, NULL, 'MENSUAL', 'Migrado automáticamente desde membresia_local'),
	(11, 35, 11, 0, '2025-07-22 01:28:20', '2025-08-22 01:28:20', '2025-12-19 05:42:03', NULL, NULL, 'MENSUAL', 'Migrado automáticamente desde membresia_local'),
	(12, 36, 13, 0, '2025-08-20 22:11:19', '2025-09-20 22:11:19', '2025-12-19 05:42:03', NULL, NULL, 'MENSUAL', 'Migrado automáticamente desde membresia_local'),
	(13, 37, 11, 0, '2025-08-21 01:20:45', '2025-09-21 01:20:45', '2025-12-19 05:42:03', NULL, NULL, 'MENSUAL', 'Migrado automáticamente desde membresia_local'),
	(16, 36, 11, 1, '2025-12-20 13:19:13', '2026-01-20 13:19:13', '2025-12-20 13:19:13', 0.00, 'Admin - Cambio Manual', 'MENSUAL', 'Cambio de membresía desde panel de administración'),
	(17, 23, 13, 0, '2025-12-21 19:26:58', '2026-01-21 19:26:58', '2025-12-21 19:26:58', 0.00, 'ePayco - Ref: FREE', 'MENSUAL', 'Cambio de plan desde Mi Membresía'),
	(18, 23, 13, 0, '2025-12-21 19:29:16', '2026-01-21 19:29:16', '2025-12-21 19:29:16', 0.00, 'ePayco - Ref: FREE', 'MENSUAL', 'Cambio de plan desde Mi Membresía'),
	(19, 23, 11, 0, '2025-12-21 19:34:10', '2026-01-21 19:34:10', '2025-12-21 19:34:10', 0.00, 'ePayco - Ref: FREE', 'MENSUAL', 'Cambio de plan desde Mi Membresía'),
	(20, 23, 13, 0, '2025-12-21 19:37:44', '2026-01-21 19:37:44', '2025-12-21 19:37:44', 0.00, 'ePayco - Ref: FREE', 'MENSUAL', 'Cambio de plan desde Mi Membresía'),
	(21, 23, 13, 0, '2025-12-21 19:38:13', '2026-01-21 19:38:13', '2025-12-21 19:38:13', 0.00, 'ePayco - Ref: FREE', 'MENSUAL', 'Cambio de plan desde Mi Membresía'),
	(22, 23, 13, 0, '2025-12-21 21:17:35', '2026-01-21 21:17:35', '2025-12-21 21:17:35', 0.00, 'ePayco - Ref: GRATIS', 'MENSUAL', 'Cambio de plan desde Mi Membresía'),
	(23, 23, 12, 1, '2025-12-21 21:21:37', '2026-01-21 21:21:37', '2025-12-21 21:21:37', 0.00, 'ePayco - Ref: GRATIS', 'MENSUAL', 'Cambio de plan desde Mi Membresía'),
	(24, 28, 13, 0, '2025-12-21 21:53:49', '2026-01-21 21:53:49', '2025-12-21 21:53:49', 0.00, 'ePayco - Ref: GRATIS', 'MENSUAL', 'Cambio de plan desde Mi Membresía'),
	(25, 28, 12, 0, '2025-12-21 21:54:12', '2026-01-21 21:54:12', '2025-12-21 21:54:12', 0.00, 'ePayco - Ref: GRATIS', 'MENSUAL', 'Cambio de plan desde Mi Membresía'),
	(26, 28, 13, 0, '2025-12-21 22:32:49', '2026-01-21 22:32:49', '2025-12-21 22:32:49', 0.00, 'ePayco - Ref: GRATIS', 'MENSUAL', 'Cambio de plan desde Mi Membresía'),
	(28, 28, 13, 1, '2025-12-21 22:51:01', '2026-01-21 22:51:01', '2025-12-21 22:51:01', 0.00, 'ePayco - Ref: GRATIS', 'MENSUAL', 'Cambio de plan desde Mi Membresía');

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
  `COSTO` int NOT NULL DEFAULT '0',
  `ESTADO` tinyint DEFAULT '1',
  `DURACION_OFERTA` int DEFAULT '0',
  `COSTO_TRIMESTRAL` int DEFAULT '0',
  `COSTO_SEMESTRAL` int DEFAULT '0',
  `COSTO_ANUAL` int DEFAULT '0',
  `CANTIDAD_PRODUCTOS` varchar(50) DEFAULT NULL,
  `OFERTAS_FLASH_SIMULTANEAS` int NOT NULL DEFAULT '1' COMMENT 'Cantidad de ofertas flash activas al mismo tiempo',
  `OFERTAS_FLASH_TOTAL` int NOT NULL DEFAULT '0' COMMENT 'Total de ofertas flash permitidas en la suscripción (0=ilimitado)',
  PRIMARY KEY (`PK_ID_TIPO_MEMBRESIA`)
) ENGINE=InnoDB AUTO_INCREMENT=20 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Volcando datos para la tabla abastecete.tipo_membresia: ~9 rows (aproximadamente)
INSERT INTO `tipo_membresia` (`PK_ID_TIPO_MEMBRESIA`, `NOMBRE`, `COSTO`, `ESTADO`, `DURACION_OFERTA`, `COSTO_TRIMESTRAL`, `COSTO_SEMESTRAL`, `COSTO_ANUAL`, `CANTIDAD_PRODUCTOS`, `OFERTAS_FLASH_SIMULTANEAS`, `OFERTAS_FLASH_TOTAL`) VALUES
	(11, 'Plan Proveedor Básico', 0, 1, 6, 0, 0, 0, '10', 3, 15),
	(12, 'Plan Cultivador Básico', 0, 1, 6, 0, 0, 0, '1', 1, 5),
	(13, 'Plan Empresa Básico', 0, 1, 6, 0, 0, 0, '50', 1, 5),
	(14, 'Plan Proveedor Pro ', 50000, 1, 12, 135000, 255000, 480000, '30', 3, 15),
	(15, 'Plan Cultivador Pro ', 50000, 1, 12, 135000, 255000, 480000, '3', 3, 15),
	(16, 'Plan Empresa Pro', 150000, 1, 12, 405000, 765000, 1440000, '150', 3, 15),
	(17, 'Plan Proveedor Premium ', 100000, 1, 24, 270000, 510000, 960000, '0', 10, 0),
	(18, 'Plan Cultivador Premium ', 100000, 1, 24, 270000, 510000, 960000, '0', 10, 0),
	(19, 'Plan Empresa Premium ', 300000, 1, 24, 810000, 1530000, 2880000, '0', 10, 0);

-- Volcando estructura para tabla abastecete.tipo_unidad
CREATE TABLE IF NOT EXISTS `tipo_unidad` (
  `ID_TIPOUNIDAD` int NOT NULL AUTO_INCREMENT,
  `NOMBRE_TIPOUNIDAD` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`ID_TIPOUNIDAD`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Volcando datos para la tabla abastecete.tipo_unidad: ~3 rows (aproximadamente)
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
  KEY `FK_usuario_tipo_autenticacion` (`TIPO_AUTENTICACION`),
  KEY `idx_usuario_nombre_usuario` (`NOMBRE_USUARIO`),
  KEY `idx_usuario_token` (`TOKEN_RECUPERACION`),
  KEY `idx_usuario_bloqueo` (`ESTADO`,`FECHA_BLOQUEO`),
  CONSTRAINT `FK_usuario_persona` FOREIGN KEY (`FK_ID_PERSONA`) REFERENCES `persona` (`PK_ID_PERSONA`),
  CONSTRAINT `FK_usuario_rol` FOREIGN KEY (`FK_ID_ROL`) REFERENCES `rol` (`PK_ID_ROL`),
  CONSTRAINT `FK_usuario_tipo_autenticacion` FOREIGN KEY (`TIPO_AUTENTICACION`) REFERENCES `metodo_autenticacion` (`PK_ID_METODO_AUTENTICACION`)
) ENGINE=InnoDB AUTO_INCREMENT=53 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Volcando datos para la tabla abastecete.usuario: ~27 rows (aproximadamente)
INSERT INTO `usuario` (`PK_ID_USUARIO`, `FK_ID_PERSONA`, `FK_ID_ROL`, `NOMBRE_USUARIO`, `CONTRASENIA`, `TOKEN_RECUPERACION`, `FECHA_EXPIRACION_TOKEN`, `TIPO_AUTENTICACION`, `INTENTOS_FALLIDOS`, `FECHA_BLOQUEO`, `CORREO_VERIFICADO`, `ESTADO`, `CLIENTES_REFERIDOS_TOTAL`, `INTENTOS_RECUPERACION`, `FECHA_ULTIMO_INTENTO_RECUPERACION`) VALUES
	(2, 2, 1, 'kevin12@gmail.com', 'stCAUXlvlTCDOFCW3+AFGw==', NULL, NULL, 1, 0, NULL, 0, 1, 0, 0, NULL),
	(4, 4, 1, 'sebastian@gmail.com', 'MApNL/Xu9KjSguqWMlk1aA==', NULL, NULL, 1, 0, NULL, 0, 1, 0, 0, NULL),
	(5, 5, 3, 'yoiner@gmail.com', 'k61Us9qfNYtvCy6F/XOgoA==', NULL, NULL, 1, 0, NULL, 0, 1, 0, 0, NULL),
	(6, 6, 3, 'ledes@gmail.com', 'urhs6MFsrUJFRJwthrYYcQ==', NULL, NULL, 1, 0, NULL, 0, 1, 0, 0, NULL),
	(7, 7, 1, 'andres@gmail.com', 'kzWvH2roKKCxJWi2nOZhvQ==', NULL, NULL, 1, 0, NULL, 0, 1, 0, 0, NULL),
	(12, 12, 2, 'yoiner.mh04@gmail.com', 'xOBcl5JnPT+4p9sI5fpiGQ==', 'f7917a01-efcf-11ef-8a42-00155d007000', '2025-02-20 16:21:36', 2, 0, NULL, 0, 1, 0, 0, NULL),
	(23, 23, 1, 'johans.ramirez@udla.edu.co', 'BGpwluhHTW0TzB09JfYwqw==', NULL, NULL, 1, 0, NULL, 0, 1, 0, 0, NULL),
	(24, 24, 3, 'da.navia@udla.edu.co', 'BGpwluhHTW0TzB09JfYwqw==', 'dc9ff21a-0687-11f0-806b-d843ae9e6717', '2025-03-21 14:13:24', 1, 0, NULL, 0, 1, 0, 0, NULL),
	(25, 25, 2, 'johan05182002.com@gmail.com', 'y3rFyft55CWVYwszuPNHUA==', NULL, NULL, 1, 0, NULL, 0, 1, 0, 0, '2025-12-21 17:58:01'),
	(26, 26, 3, 'armuca@gmail.com', 'BGpwluhHTW0TzB09JfYwqw==', NULL, NULL, 1, 0, NULL, 0, 1, 0, 0, NULL),
	(27, 27, 3, 'c@gmail.com', 'BGpwluhHTW0TzB09JfYwqw==', NULL, NULL, 1, 0, NULL, 0, 1, 0, 0, NULL),
	(30, 30, 2, 'may13xd@gmail.com', 'zTLp/d8kn9F+qgWExhUrfA==', NULL, NULL, 1, 0, NULL, 0, 1, 0, 0, NULL),
	(31, 31, 3, 'juandavidloquendero@gmail.com', 'QhuouUOvL0DiHxB8XrQeUg==', NULL, NULL, 1, 0, NULL, 0, 1, 0, 0, NULL),
	(32, 32, 3, 'h@gmail.com', 'zTLp/d8kn9F+qgWExhUrfA==', NULL, NULL, 1, 0, NULL, 0, 1, 0, 0, NULL),
	(33, 33, 3, 'osnidio@yopmail.com', 'HJjNmQMNUaeX2PxRK2lTPg==', '6964cb39-15b9-11f0-9953-e688b28ab077', '2025-04-10 03:15:52', 1, 0, NULL, 0, 1, 0, 0, NULL),
	(34, 34, 2, 'l@gmail.com', 'zTLp/d8kn9F+qgWExhUrfA==', NULL, NULL, 1, 0, NULL, 0, 1, 0, 0, NULL),
	(35, 35, 3, 'sdfdsfsdf@d', 'bzmmZWxCrQlFMzRWXnqfTA==', '781dfc63-1026-11f0-9953-e688b28ab077', '2025-04-03 01:01:25', 1, 0, NULL, 0, 1, 0, 0, NULL),
	(36, 36, 2, 'andrestrujillo20166@gmail.com', '7CP2YJdKY1Z9UU+Bb+ESMQ==', NULL, NULL, 1, 0, NULL, 0, 1, 0, 0, NULL),
	(37, 37, 2, 'hola@gmail.com', 'y3rFyft55CWVYwszuPNHUA==', NULL, NULL, 1, 0, NULL, 0, 1, 0, 0, NULL),
	(38, 38, 2, 'hola1@gmail.com', 'y3rFyft55CWVYwszuPNHUA==', NULL, NULL, 1, 0, NULL, 0, 1, 0, 0, NULL),
	(39, 39, 3, 'hola2@gmail.com', 'y3rFyft55CWVYwszuPNHUA==', NULL, NULL, 1, 0, NULL, 0, 1, 0, 0, NULL),
	(40, 40, 2, 'hola4@gmail.com', 'YQn/NzNFobs1CxYU0g9iTQ==', NULL, NULL, 1, 0, NULL, 0, 1, 0, 0, NULL),
	(49, 49, 3, 'atekegran@gmail.com', 'stCAUXlvlTCDOFCW3+AFGw==', NULL, NULL, 2, 0, NULL, 0, 1, 0, 0, NULL),
	(50, 50, 2, 'sebsirra13@gmail.com', 'stCAUXlvlTCDOFCW3+AFGw==', NULL, NULL, 2, 0, NULL, 0, 1, 0, 0, NULL),
	(51, 51, 2, 'websencol@gmail.com', 'stCAUXlvlTCDOFCW3+AFGw==', NULL, NULL, 2, 0, NULL, 0, 1, 0, 0, NULL),
	(52, 52, 3, 'dananabia2000@gmail.com', 'stCAUXlvlTCDOFCW3+AFGw==', NULL, NULL, 2, 0, NULL, 0, 1, 0, 0, NULL),
	(54, 56, 3, 'prueba123@gmail.com', 'y3rFyft55CWVYwszuPNHUA==', NULL, NULL, 1, 0, NULL, 0, 1, 0, 0, NULL);

-- Volcando estructura para procedimiento abastecete.validar_limite_ofertas_flash
DELIMITER //
CREATE PROCEDURE `validar_limite_ofertas_flash`(
    IN p_id_local INT,
    OUT p_puede_crear TINYINT,
    OUT p_mensaje VARCHAR(200)
)
BEGIN
    DECLARE v_max_simultaneas INT DEFAULT 1;
    DECLARE v_max_total INT DEFAULT 0;
    DECLARE v_activas_ahora INT DEFAULT 0;
    DECLARE v_usadas_suscripcion INT DEFAULT 0;
    DECLARE v_id_suscripcion INT DEFAULT 0;
    DECLARE v_fecha_inicio_suscripcion DATETIME;

    -- Obtener límites de la membresía activa
    SELECT
        COALESCE(tm.OFERTAS_FLASH_SIMULTANEAS, 1),
        COALESCE(tm.OFERTAS_FLASH_TOTAL, 0),
        s.PK_ID_SUSCRIPCION,
        s.FECHA_INICIO
    INTO v_max_simultaneas, v_max_total, v_id_suscripcion, v_fecha_inicio_suscripcion
    FROM local l
    LEFT JOIN suscripcion s ON l.FK_ID_SUSCRIPCION_ACTIVA = s.PK_ID_SUSCRIPCION AND s.ESTADO = 1
    LEFT JOIN tipo_membresia tm ON s.FK_ID_TIPO_MEMBRESIA = tm.PK_ID_TIPO_MEMBRESIA
    WHERE l.PK_ID_LOCAL = p_id_local;

    -- Contar ofertas activas ahora
    SELECT COUNT(*) INTO v_activas_ahora
    FROM oferta_flash
    WHERE FK_ID_LOCAL = p_id_local
      AND ESTADO = 1
      AND FECHA_EXPIRACION > NOW();

    -- Verificar límite de simultáneas
    IF v_activas_ahora >= v_max_simultaneas THEN
        SET p_puede_crear = 0;
        SET p_mensaje = CONCAT('Ya tienes ', v_activas_ahora, ' ofertas activas. Tu plan permite máximo ', v_max_simultaneas);
    -- Verificar límite total (si aplica)
    ELSEIF v_max_total > 0 THEN
        -- Contar ofertas creadas desde inicio de suscripción
        SELECT COUNT(*) INTO v_usadas_suscripcion
        FROM oferta_flash
        WHERE FK_ID_LOCAL = p_id_local
          AND FECHA_CREACION >= v_fecha_inicio_suscripcion;

        IF v_usadas_suscripcion >= v_max_total THEN
            SET p_puede_crear = 0;
            SET p_mensaje = CONCAT('Has usado ', v_usadas_suscripcion, ' de ', v_max_total, ' ofertas permitidas en tu suscripción');
        ELSE
            SET p_puede_crear = 1;
            SET p_mensaje = CONCAT('Puedes crear oferta. Usadas: ', v_usadas_suscripcion, '/', v_max_total);
        END IF;
    ELSE
        SET p_puede_crear = 1;
        SET p_mensaje = 'OK';
    END IF;
END//
DELIMITER ;

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

-- Volcando estructura para procedimiento abastecete.verificar_suscripciones_vencidas
DELIMITER //
CREATE PROCEDURE `verificar_suscripciones_vencidas`()
BEGIN
    -- Marcar como vencidas las suscripciones activas cuya fecha fin ya pasó
    UPDATE suscripcion s
    INNER JOIN local l ON s.PK_ID_SUSCRIPCION = l.FK_ID_SUSCRIPCION_ACTIVA
    SET s.ESTADO = 3,
        l.FK_ID_SUSCRIPCION_ACTIVA = NULL
    WHERE s.ESTADO = 1
        AND s.FECHA_FIN < NOW();

    -- Registrar en historial los vencimientos
    INSERT INTO historial_membresia (
        FK_ID_LOCAL,
        FK_ID_SUSCRIPCION,
        FK_ID_TIPO_ANTERIOR,
        FK_ID_TIPO_NUEVO,
        TIPO_CAMBIO,
        FECHA_INICIO_PERIODO,
        FECHA_FIN_PERIODO,
        NOTAS
    )
    SELECT
        FK_ID_LOCAL,
        PK_ID_SUSCRIPCION,
        FK_ID_TIPO_MEMBRESIA,
        FK_ID_TIPO_MEMBRESIA,
        'VENCIMIENTO',
        FECHA_INICIO,
        FECHA_FIN,
        'Suscripción vencida automáticamente'
    FROM suscripcion
    WHERE ESTADO = 3
        AND NOT EXISTS (
            SELECT 1 FROM historial_membresia hm
            WHERE hm.FK_ID_SUSCRIPCION = suscripcion.PK_ID_SUSCRIPCION
                AND hm.TIPO_CAMBIO = 'VENCIMIENTO'
        );

    SELECT ROW_COUNT() AS SuscripcionesVencidas;
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
