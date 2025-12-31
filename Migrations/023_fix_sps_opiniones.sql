-- =====================================================
-- Migración 023: Corregir SPs de opiniones y agregar foto de perfil
-- Fecha: 2025-12-31
-- Problema: La tabla usuario tiene NOMBRES (no NOMBRE) y no tiene FOTO_PERFIL
-- Solución: Agregar FOTO_PERFIL para guardar foto de Google OAuth
-- =====================================================

-- 0. Agregar columna FOTO_PERFIL a usuario (para Google OAuth)
ALTER TABLE usuario ADD COLUMN FOTO_PERFIL VARCHAR(500) NULL AFTER APELLIDOS;

-- 1. Corregir SP sp_obtener_opiniones_local
DROP PROCEDURE IF EXISTS sp_obtener_opiniones_local;

DELIMITER //
CREATE PROCEDURE sp_obtener_opiniones_local(
    IN p_id_local INT,
    IN p_pagina INT,
    IN p_cantidad INT
)
BEGIN
    DECLARE v_offset INT;
    SET v_offset = (p_pagina - 1) * p_cantidad;

    SELECT
        o.PK_ID_OPINION AS Id,
        o.FK_ID_LOCAL AS IdLocal,
        o.FK_ID_USUARIO AS IdUsuario,
        CONCAT(u.NOMBRES, ' ', u.APELLIDOS) AS NombreUsuario,
        COALESCE(u.FOTO_PERFIL, '') AS FotoUsuario,
        o.CALIFICACION AS Calificacion,
        o.COMENTARIO AS Comentario,
        o.FECHA_OPINION AS FechaOpinion,
        o.RESPUESTA_DUENO AS RespuestaDueno,
        o.FECHA_RESPUESTA AS FechaRespuesta,
        o.ESTADO AS Estado,
        (SELECT COUNT(*) FROM opinion r WHERE r.FK_ID_OPINION_PADRE = o.PK_ID_OPINION AND r.ESTADO = 1) AS CantidadRespuestas
    FROM opinion o
    INNER JOIN usuario u ON o.FK_ID_USUARIO = u.PK_ID_USUARIO
    WHERE o.FK_ID_LOCAL = p_id_local
      AND o.ESTADO = 1
      AND o.FK_ID_OPINION_PADRE IS NULL
    ORDER BY o.FECHA_OPINION DESC
    LIMIT p_cantidad OFFSET v_offset;
END//
DELIMITER ;

-- 2. Corregir SP sp_obtener_respuestas_opinion
DROP PROCEDURE IF EXISTS sp_obtener_respuestas_opinion;

DELIMITER //
CREATE PROCEDURE sp_obtener_respuestas_opinion(
    IN p_id_opinion_padre INT
)
BEGIN
    SELECT
        o.PK_ID_OPINION AS Id,
        o.FK_ID_LOCAL AS IdLocal,
        o.FK_ID_USUARIO AS IdUsuario,
        o.FK_ID_OPINION_PADRE AS IdOpinionPadre,
        CONCAT(u.NOMBRES, ' ', u.APELLIDOS) AS NombreUsuario,
        COALESCE(u.FOTO_PERFIL, '') AS FotoUsuario,
        o.COMENTARIO AS Comentario,
        o.FECHA_OPINION AS FechaOpinion,
        o.ESTADO AS Estado
    FROM opinion o
    INNER JOIN usuario u ON o.FK_ID_USUARIO = u.PK_ID_USUARIO
    WHERE o.FK_ID_OPINION_PADRE = p_id_opinion_padre
      AND o.ESTADO = 1
    ORDER BY o.FECHA_OPINION ASC;
END//
DELIMITER ;

-- 3. Corregir SP sp_obtener_resumen_opiniones (manejar NULL cuando no hay datos)
DROP PROCEDURE IF EXISTS sp_obtener_resumen_opiniones;

DELIMITER //
CREATE PROCEDURE sp_obtener_resumen_opiniones(
    IN p_id_local INT
)
BEGIN
    SELECT
        COALESCE(COUNT(*), 0) AS TotalOpiniones,
        COALESCE(ROUND(AVG(CASE WHEN CALIFICACION > 0 THEN CALIFICACION END), 1), 0) AS PromedioCalificacion,
        COALESCE(SUM(CASE WHEN CALIFICACION = 5 THEN 1 ELSE 0 END), 0) AS Estrellas5,
        COALESCE(SUM(CASE WHEN CALIFICACION = 4 THEN 1 ELSE 0 END), 0) AS Estrellas4,
        COALESCE(SUM(CASE WHEN CALIFICACION = 3 THEN 1 ELSE 0 END), 0) AS Estrellas3,
        COALESCE(SUM(CASE WHEN CALIFICACION = 2 THEN 1 ELSE 0 END), 0) AS Estrellas2,
        COALESCE(SUM(CASE WHEN CALIFICACION = 1 THEN 1 ELSE 0 END), 0) AS Estrellas1,
        COALESCE(SUM(CASE WHEN CALIFICACION > 0 THEN 1 ELSE 0 END), 0) AS TotalConCalificacion
    FROM opinion
    WHERE FK_ID_LOCAL = p_id_local
      AND ESTADO = 1
      AND FK_ID_OPINION_PADRE IS NULL;
END//
DELIMITER ;

-- 4. SP para actualizar foto de perfil (usado por Google OAuth)
DROP PROCEDURE IF EXISTS sp_actualizar_foto_perfil;

DELIMITER //
CREATE PROCEDURE sp_actualizar_foto_perfil(
    IN p_id_usuario INT,
    IN p_foto_url VARCHAR(500)
)
BEGIN
    UPDATE usuario
    SET FOTO_PERFIL = p_foto_url
    WHERE PK_ID_USUARIO = p_id_usuario;

    SELECT ROW_COUNT() AS Actualizado;
END//
DELIMITER ;

-- 5. SP para registrar usuario con Google (incluye foto)
DROP PROCEDURE IF EXISTS sp_registrar_usuario_google;

DELIMITER //
CREATE PROCEDURE sp_registrar_usuario_google(
    IN p_email VARCHAR(100),
    IN p_nombre VARCHAR(100),
    IN p_foto_url VARCHAR(500)
)
BEGIN
    DECLARE v_nombres VARCHAR(50);
    DECLARE v_apellidos VARCHAR(50);
    DECLARE v_id_usuario INT;
    DECLARE v_codigo_referido VARCHAR(20);

    -- Separar nombre completo en nombres y apellidos
    SET v_nombres = SUBSTRING_INDEX(p_nombre, ' ', 1);
    SET v_apellidos = TRIM(SUBSTRING(p_nombre, LENGTH(v_nombres) + 2));

    IF v_apellidos = '' OR v_apellidos IS NULL THEN
        SET v_apellidos = v_nombres;
    END IF;

    -- Generar código de referido único
    SET v_codigo_referido = UPPER(SUBSTRING(MD5(RAND()), 1, 8));

    INSERT INTO usuario (
        NOMBRES,
        APELLIDOS,
        FOTO_PERFIL,
        NOMBRE_USUARIO,
        CONTRASENIA,
        CODIGO_REFERIDO,
        TIPO_AUTENTICACION,
        CORREO_VERIFICADO,
        ESTADO
    )
    VALUES (
        v_nombres,
        v_apellidos,
        p_foto_url,
        p_email,
        '',
        v_codigo_referido,
        'GOOGLE',
        1,
        1
    );

    SET v_id_usuario = LAST_INSERT_ID();

    SELECT v_id_usuario AS IdUsuario;
END//
DELIMITER ;

-- =====================================================
SELECT 'Migración 023 completada - SPs de opiniones corregidos + foto de perfil' AS Mensaje;
-- =====================================================
