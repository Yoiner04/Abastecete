-- Migration 046: Crear SP para cambiar contraseña verificando la actual
-- Este SP se usa cuando el usuario está autenticado y quiere cambiar su contraseña

DELIMITER //

DROP PROCEDURE IF EXISTS `cambiar_contrasenia_verificada`//

CREATE PROCEDURE `cambiar_contrasenia_verificada`(
    IN `p_id_usuario` INT,
    IN `p_contrasenia_actual` MEDIUMTEXT,
    IN `p_nueva_contrasenia` MEDIUMTEXT
)
BEGIN
    DECLARE v_resultado INT DEFAULT 0;
    DECLARE v_mensaje VARCHAR(255);
    DECLARE v_contrasenia_almacenada MEDIUMTEXT;

    -- Obtener la contraseña actual del usuario
    SELECT CONTRASENIA INTO v_contrasenia_almacenada
    FROM usuario
    WHERE PK_ID_USUARIO = p_id_usuario;

    -- Verificar si el usuario existe
    IF v_contrasenia_almacenada IS NULL THEN
        SET v_resultado = -1;
        SET v_mensaje = 'Usuario no encontrado.';
    -- Verificar que la contraseña actual sea correcta
    ELSEIF v_contrasenia_almacenada != p_contrasenia_actual THEN
        SET v_resultado = -2;
        SET v_mensaje = 'La contraseña actual es incorrecta.';
    -- Verificar longitud de nueva contraseña
    ELSEIF p_nueva_contrasenia IS NULL OR LENGTH(p_nueva_contrasenia) < 8 THEN
        SET v_resultado = -3;
        SET v_mensaje = 'La nueva contraseña debe tener al menos 8 caracteres.';
    -- Verificar que la nueva contraseña sea diferente
    ELSEIF p_contrasenia_actual = p_nueva_contrasenia THEN
        SET v_resultado = -4;
        SET v_mensaje = 'La nueva contraseña debe ser diferente a la actual.';
    ELSE
        -- Actualizar la contraseña
        UPDATE usuario
        SET CONTRASENIA = p_nueva_contrasenia
        WHERE PK_ID_USUARIO = p_id_usuario;

        SET v_resultado = 1;
        SET v_mensaje = 'Contraseña actualizada exitosamente.';
    END IF;

    SELECT v_resultado AS resultado, v_mensaje AS mensaje;
END//

DELIMITER ;
