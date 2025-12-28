-- Migración 066: Corregir SP login_usuario para BCrypt
-- ============================================================
-- El SP no puede verificar BCrypt directamente porque genera
-- diferentes hashes. Debe retornar el hash para que C# verifique.
-- ============================================================

-- SP: Login - Retorna datos del usuario para verificar contraseña en C#
DROP PROCEDURE IF EXISTS login_usuario;
DELIMITER //
CREATE PROCEDURE login_usuario(
    IN p_nombre_usuario VARCHAR(100),
    IN p_contrasenia VARCHAR(255)  -- No se usa, pero se mantiene por compatibilidad
)
BEGIN
    DECLARE v_id_usuario INT DEFAULT 0;
    DECLARE v_contrasenia_db VARCHAR(255);
    DECLARE v_estado INT DEFAULT 1;
    DECLARE v_intentos INT DEFAULT 0;
    DECLARE v_fecha_bloqueo DATETIME;
    DECLARE v_id_rol INT DEFAULT 0;

    -- Buscar usuario por correo/nombre_usuario
    SELECT
        PK_ID_USUARIO,
        CONTRASENIA,
        ESTADO,
        COALESCE(INTENTOS_FALLIDOS, 0),
        FECHA_BLOQUEO,
        COALESCE(FK_ID_ROL, 3)
    INTO v_id_usuario, v_contrasenia_db, v_estado, v_intentos, v_fecha_bloqueo, v_id_rol
    FROM usuario
    WHERE LOWER(NOMBRE_USUARIO) = LOWER(TRIM(p_nombre_usuario))
    LIMIT 1;

    -- Si no existe el usuario
    IF v_id_usuario = 0 THEN
        SELECT 98 AS FK_ID_ROL, NULL AS CONTRASENIA_HASH, 0 AS PK_ID_USUARIO;

    -- Si la cuenta está inhabilitada
    ELSEIF v_estado = 0 THEN
        SELECT 97 AS FK_ID_ROL, NULL AS CONTRASENIA_HASH, v_id_usuario AS PK_ID_USUARIO;

    -- Si está bloqueada por intentos fallidos (verificar si pasó 1 hora)
    ELSEIF v_intentos >= 5 AND v_fecha_bloqueo IS NOT NULL AND v_fecha_bloqueo > DATE_SUB(NOW(), INTERVAL 1 HOUR) THEN
        SELECT 0 AS FK_ID_ROL, NULL AS CONTRASENIA_HASH, v_id_usuario AS PK_ID_USUARIO;

    ELSE
        -- Retornar datos del usuario incluyendo el hash para verificación en C#
        SELECT
            u.PK_ID_USUARIO,
            u.NOMBRES,
            u.APELLIDOS,
            u.NOMBRE_USUARIO AS CORREO,
            u.FK_ID_ROL,
            u.ESTADO,
            u.CONTRASENIA AS CONTRASENIA_HASH,
            l.PK_ID_LOCAL AS ID_LOCAL,
            l.NOMBRE_LOCAL AS NOMBRE_LOCAL,
            s.FK_ID_TIPO_MEMBRESIA AS FK_ID_TIPOMEMBRESIA,
            tm.NOMBRE AS NOMBRE_MEMBRESIA,
            CASE WHEN s.PK_ID_SUSCRIPCION IS NOT NULL AND s.ESTADO = 1 THEN 1 ELSE 0 END AS TIENE_MEMBRESIA_ACTIVA
        FROM usuario u
        LEFT JOIN local l ON l.FK_ID_USUARIO = u.PK_ID_USUARIO
        LEFT JOIN suscripcion s ON s.FK_ID_LOCAL = l.PK_ID_LOCAL AND s.ESTADO = 1
        LEFT JOIN tipo_membresia tm ON s.FK_ID_TIPO_MEMBRESIA = tm.PK_ID_TIPO_MEMBRESIA
        WHERE u.PK_ID_USUARIO = v_id_usuario;
    END IF;
END//
DELIMITER ;

-- SP: Registrar intento fallido de login
DROP PROCEDURE IF EXISTS registrar_intento_fallido;
DELIMITER //
CREATE PROCEDURE registrar_intento_fallido(
    IN p_id_usuario INT
)
BEGIN
    UPDATE usuario
    SET
        INTENTOS_FALLIDOS = COALESCE(INTENTOS_FALLIDOS, 0) + 1,
        FECHA_BLOQUEO = CASE WHEN COALESCE(INTENTOS_FALLIDOS, 0) + 1 >= 5 THEN NOW() ELSE FECHA_BLOQUEO END
    WHERE PK_ID_USUARIO = p_id_usuario;
END//
DELIMITER ;

-- SP: Limpiar intentos fallidos después de login exitoso
DROP PROCEDURE IF EXISTS limpiar_intentos_fallidos;
DELIMITER //
CREATE PROCEDURE limpiar_intentos_fallidos(
    IN p_id_usuario INT
)
BEGIN
    UPDATE usuario
    SET INTENTOS_FALLIDOS = 0, FECHA_BLOQUEO = NULL
    WHERE PK_ID_USUARIO = p_id_usuario;
END//
DELIMITER ;
