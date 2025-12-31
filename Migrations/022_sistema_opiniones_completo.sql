-- =====================================================
-- Migración 022: Sistema completo de Opiniones/Reseñas
-- Fecha: 2025-12-31
-- Funcionalidad:
--   - Usuario puede comentar múltiples veces
--   - Usuario solo puede puntuar 1 vez por local
--   - Dueño puede responder opiniones
--   - Usuarios pueden responder a comentarios (hilos)
-- =====================================================

-- 1. Agregar columnas faltantes a la tabla opinion (una por una para evitar errores de sintaxis)
ALTER TABLE opinion ADD COLUMN FK_ID_OPINION_PADRE INT NULL AFTER FK_ID_USUARIO;
ALTER TABLE opinion ADD COLUMN RESPUESTA_DUENO TEXT NULL AFTER COMENTARIO;
ALTER TABLE opinion ADD COLUMN FECHA_RESPUESTA DATETIME NULL AFTER RESPUESTA_DUENO;
ALTER TABLE opinion ADD COLUMN ESTADO TINYINT NOT NULL DEFAULT 1 AFTER FECHA_RESPUESTA;

-- 2. FK para comentarios padre
ALTER TABLE opinion
ADD CONSTRAINT FK_opinion_padre FOREIGN KEY (FK_ID_OPINION_PADRE)
REFERENCES opinion(PK_ID_OPINION) ON DELETE CASCADE;

-- 3. Índice para mejorar consultas de hilos
ALTER TABLE opinion
ADD INDEX idx_opinion_padre (FK_ID_OPINION_PADRE);

-- =====================================================
-- 4. SP para crear opinión (con soporte para respuestas)
-- =====================================================
DROP PROCEDURE IF EXISTS sp_crear_opinion;

DELIMITER //
CREATE PROCEDURE sp_crear_opinion(
    IN p_id_local INT,
    IN p_id_usuario INT,
    IN p_calificacion TINYINT,
    IN p_comentario TEXT,
    IN p_id_opinion_padre INT
)
BEGIN
    DECLARE v_ya_puntuo INT DEFAULT 0;
    DECLARE v_id_opinion INT DEFAULT 0;

    -- Si es respuesta a otro comentario, calificación debe ser 0
    IF p_id_opinion_padre IS NOT NULL AND p_id_opinion_padre > 0 THEN
        SET p_calificacion = 0;
    END IF;

    -- Verificar si el usuario ya puntuó este local (calificación > 0)
    IF p_calificacion > 0 THEN
        SELECT COUNT(*) INTO v_ya_puntuo
        FROM opinion
        WHERE FK_ID_LOCAL = p_id_local
          AND FK_ID_USUARIO = p_id_usuario
          AND CALIFICACION > 0;

        IF v_ya_puntuo > 0 THEN
            SELECT 0 AS Id, 'Ya has puntuado este local. Solo puedes agregar comentarios adicionales.' AS Mensaje, 0 AS Exito;
        ELSE
            -- Insertar opinión con calificación
            INSERT INTO opinion (FK_ID_LOCAL, FK_ID_USUARIO, FK_ID_OPINION_PADRE, CALIFICACION, COMENTARIO, FECHA_OPINION, ESTADO)
            VALUES (p_id_local, p_id_usuario, NULL, p_calificacion, p_comentario, NOW(), 1);

            SET v_id_opinion = LAST_INSERT_ID();
            SELECT v_id_opinion AS Id, 'Opinión registrada correctamente' AS Mensaje, 1 AS Exito;
        END IF;
    ELSE
        -- Insertar comentario (puede ser respuesta a otro)
        INSERT INTO opinion (FK_ID_LOCAL, FK_ID_USUARIO, FK_ID_OPINION_PADRE, CALIFICACION, COMENTARIO, FECHA_OPINION, ESTADO)
        VALUES (p_id_local, p_id_usuario,
                CASE WHEN p_id_opinion_padre > 0 THEN p_id_opinion_padre ELSE NULL END,
                0, p_comentario, NOW(), 1);

        SET v_id_opinion = LAST_INSERT_ID();
        SELECT v_id_opinion AS Id,
               CASE WHEN p_id_opinion_padre > 0 THEN 'Respuesta registrada correctamente' ELSE 'Comentario registrado correctamente' END AS Mensaje,
               1 AS Exito;
    END IF;
END//
DELIMITER ;

-- =====================================================
-- 5. SP para obtener opiniones principales de un local (no respuestas)
-- =====================================================
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

    -- Solo opiniones principales (sin padre)
    SELECT
        o.PK_ID_OPINION AS Id,
        o.FK_ID_LOCAL AS IdLocal,
        o.FK_ID_USUARIO AS IdUsuario,
        u.NOMBRE AS NombreUsuario,
        u.FOTO_PERFIL AS FotoUsuario,
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

-- =====================================================
-- 6. SP para obtener respuestas a una opinión
-- =====================================================
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
        u.NOMBRE AS NombreUsuario,
        u.FOTO_PERFIL AS FotoUsuario,
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

-- =====================================================
-- 7. SP para obtener resumen de calificaciones de un local
-- =====================================================
DROP PROCEDURE IF EXISTS sp_obtener_resumen_opiniones;

DELIMITER //
CREATE PROCEDURE sp_obtener_resumen_opiniones(
    IN p_id_local INT
)
BEGIN
    SELECT
        COUNT(*) AS TotalOpiniones,
        COALESCE(ROUND(AVG(CASE WHEN CALIFICACION > 0 THEN CALIFICACION END), 1), 0) AS PromedioCalificacion,
        SUM(CASE WHEN CALIFICACION = 5 THEN 1 ELSE 0 END) AS Estrellas5,
        SUM(CASE WHEN CALIFICACION = 4 THEN 1 ELSE 0 END) AS Estrellas4,
        SUM(CASE WHEN CALIFICACION = 3 THEN 1 ELSE 0 END) AS Estrellas3,
        SUM(CASE WHEN CALIFICACION = 2 THEN 1 ELSE 0 END) AS Estrellas2,
        SUM(CASE WHEN CALIFICACION = 1 THEN 1 ELSE 0 END) AS Estrellas1,
        SUM(CASE WHEN CALIFICACION > 0 THEN 1 ELSE 0 END) AS TotalConCalificacion
    FROM opinion
    WHERE FK_ID_LOCAL = p_id_local
      AND ESTADO = 1
      AND FK_ID_OPINION_PADRE IS NULL;
END//
DELIMITER ;

-- =====================================================
-- 8. SP para que el dueño responda una opinión
-- =====================================================
DROP PROCEDURE IF EXISTS sp_responder_opinion_dueno;

DELIMITER //
CREATE PROCEDURE sp_responder_opinion_dueno(
    IN p_id_opinion INT,
    IN p_id_local INT,
    IN p_respuesta TEXT
)
BEGIN
    DECLARE v_opinion_local INT DEFAULT 0;

    -- Verificar que la opinión pertenece al local
    SELECT FK_ID_LOCAL INTO v_opinion_local
    FROM opinion
    WHERE PK_ID_OPINION = p_id_opinion;

    IF v_opinion_local = p_id_local THEN
        UPDATE opinion
        SET RESPUESTA_DUENO = p_respuesta,
            FECHA_RESPUESTA = NOW()
        WHERE PK_ID_OPINION = p_id_opinion;

        SELECT p_id_opinion AS Id, 'Respuesta guardada correctamente' AS Mensaje, 1 AS Exito;
    ELSE
        SELECT 0 AS Id, 'No tienes permiso para responder esta opinión' AS Mensaje, 0 AS Exito;
    END IF;
END//
DELIMITER ;

-- =====================================================
-- 9. SP para verificar si usuario ya puntuó
-- =====================================================
DROP PROCEDURE IF EXISTS sp_verificar_puntuacion_usuario;

DELIMITER //
CREATE PROCEDURE sp_verificar_puntuacion_usuario(
    IN p_id_local INT,
    IN p_id_usuario INT
)
BEGIN
    SELECT
        CASE WHEN COUNT(*) > 0 THEN 1 ELSE 0 END AS YaPuntuo,
        COALESCE(MAX(CALIFICACION), 0) AS CalificacionDada
    FROM opinion
    WHERE FK_ID_LOCAL = p_id_local
      AND FK_ID_USUARIO = p_id_usuario
      AND CALIFICACION > 0;
END//
DELIMITER ;

-- =====================================================
-- 10. SP para eliminar opinión (solo el usuario que la creó)
-- =====================================================
DROP PROCEDURE IF EXISTS sp_eliminar_opinion;

DELIMITER //
CREATE PROCEDURE sp_eliminar_opinion(
    IN p_id_opinion INT,
    IN p_id_usuario INT
)
BEGIN
    DECLARE v_opinion_usuario INT DEFAULT 0;

    SELECT FK_ID_USUARIO INTO v_opinion_usuario
    FROM opinion
    WHERE PK_ID_OPINION = p_id_opinion;

    IF v_opinion_usuario = p_id_usuario THEN
        -- CASCADE eliminará las respuestas hijas automáticamente
        DELETE FROM opinion WHERE PK_ID_OPINION = p_id_opinion;
        SELECT p_id_opinion AS Id, 'Opinión eliminada correctamente' AS Mensaje, 1 AS Exito;
    ELSE
        SELECT 0 AS Id, 'No tienes permiso para eliminar esta opinión' AS Mensaje, 0 AS Exito;
    END IF;
END//
DELIMITER ;

-- =====================================================
-- 11. SP para obtener opiniones del usuario (mis opiniones)
-- =====================================================
DROP PROCEDURE IF EXISTS sp_obtener_mis_opiniones;

DELIMITER //
CREATE PROCEDURE sp_obtener_mis_opiniones(
    IN p_id_usuario INT
)
BEGIN
    SELECT
        o.PK_ID_OPINION AS Id,
        o.FK_ID_LOCAL AS IdLocal,
        l.NOMBRE_LOCAL AS NombreLocal,
        l.FOTOS_LOCAL AS FotoLocal,
        o.CALIFICACION AS Calificacion,
        o.COMENTARIO AS Comentario,
        o.FECHA_OPINION AS FechaOpinion,
        o.RESPUESTA_DUENO AS RespuestaDueno,
        o.FECHA_RESPUESTA AS FechaRespuesta,
        o.FK_ID_OPINION_PADRE AS IdOpinionPadre
    FROM opinion o
    INNER JOIN `local` l ON o.FK_ID_LOCAL = l.PK_ID_LOCAL
    WHERE o.FK_ID_USUARIO = p_id_usuario
      AND o.ESTADO = 1
    ORDER BY o.FECHA_OPINION DESC;
END//
DELIMITER ;

-- =====================================================
-- 12. SP para contar total de opiniones (para paginación)
-- =====================================================
DROP PROCEDURE IF EXISTS sp_contar_opiniones_local;

DELIMITER //
CREATE PROCEDURE sp_contar_opiniones_local(
    IN p_id_local INT
)
BEGIN
    SELECT COUNT(*) AS Total
    FROM opinion
    WHERE FK_ID_LOCAL = p_id_local
      AND ESTADO = 1
      AND FK_ID_OPINION_PADRE IS NULL;
END//
DELIMITER ;

-- =====================================================
SELECT 'Migración 022 completada - Sistema de opiniones con hilos implementado' AS Mensaje;
-- =====================================================
