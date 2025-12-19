-- =============================================
-- Migración 024: Corregir SPs que usan FK_ID_TIPOMEMBRESIA de local
-- Descripción: La columna FK_ID_TIPOMEMBRESIA fue eliminada de la tabla local
--              en la migración 020. Ahora se debe obtener el tipo de membresía
--              desde la tabla suscripcion.
-- =============================================

DELIMITER //

-- 1. Corregir ObtenerLocalesAleatorios (usado en página Principal)
DROP PROCEDURE IF EXISTS `ObtenerLocalesAleatorios`//

CREATE PROCEDURE `ObtenerLocalesAleatorios`()
BEGIN
    -- Obtener locales aleatorios priorizando por tipo de membresía de su suscripción activa
    SELECT
        PK_ID_LOCAL,
        NOMBRE_LOCAL,
        FOTOS_LOCAL,
        COALESCE(FK_ID_TIPO_MEMBRESIA, 0) AS FK_ID_TIPOMEMBRESIA
    FROM (
        (
            -- Locales con membresías premium (IDs 19, 18, 17)
            SELECT l.PK_ID_LOCAL, l.NOMBRE_LOCAL, l.FOTOS_LOCAL, s.FK_ID_TIPO_MEMBRESIA
            FROM local l
            LEFT JOIN suscripcion s ON l.FK_ID_SUSCRIPCION_ACTIVA = s.PK_ID_SUSCRIPCION AND s.ESTADO = 1
            WHERE s.FK_ID_TIPO_MEMBRESIA IN (19, 18, 17)
            ORDER BY RAND()
            LIMIT 6
        )
        UNION ALL
        (
            -- Locales con membresías estándar (IDs 16, 15, 14)
            SELECT l.PK_ID_LOCAL, l.NOMBRE_LOCAL, l.FOTOS_LOCAL, s.FK_ID_TIPO_MEMBRESIA
            FROM local l
            LEFT JOIN suscripcion s ON l.FK_ID_SUSCRIPCION_ACTIVA = s.PK_ID_SUSCRIPCION AND s.ESTADO = 1
            WHERE s.FK_ID_TIPO_MEMBRESIA IN (16, 15, 14)
            ORDER BY RAND()
            LIMIT 6
        )
    ) AS locales_priorizados
    LIMIT 6;
END//

-- 2. Corregir agregar_productos_local (verifica límite de productos por membresía)
DROP PROCEDURE IF EXISTS `agregar_productos_local`//

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

-- 3. Corregir aprobar_ofertas_flash (obtiene duración de oferta según membresía)
DROP PROCEDURE IF EXISTS `aprobar_ofertas_flash`//

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

-- 4. Corregir obtener_duracion_oferta (usado para mostrar tiempo de ofertas)
DROP PROCEDURE IF EXISTS `obtener_duracion_oferta`//

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

-- 5. Corregir consultar_locales_por_categoria (filtra locales por categoría y membresía)
DROP PROCEDURE IF EXISTS `consultar_locales_por_categoria`//

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

-- 6. Corregir login_google (retorna FK_ID_TIPOMEMBRESIA desde suscripción)
DROP PROCEDURE IF EXISTS `login_google`//

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
