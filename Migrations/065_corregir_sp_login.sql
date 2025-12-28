-- Migración 065: Corregir SP login_usuario
-- ============================================================
-- El SP de login debe recibir p_nombre_usuario y p_contrasenia
-- para mantener compatibilidad con el código existente
-- ============================================================

-- SP: Login con verificación de contraseña y bloqueo
DROP PROCEDURE IF EXISTS login_usuario;
DELIMITER //
CREATE PROCEDURE login_usuario(
    IN p_nombre_usuario VARCHAR(100),
    IN p_contrasenia VARCHAR(255)
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
        SELECT 98 AS FK_ID_ROL; -- Código: usuario no encontrado

    -- Si la cuenta está inhabilitada
    ELSEIF v_estado = 0 THEN
        SELECT 97 AS FK_ID_ROL; -- Código: cuenta inhabilitada

    -- Si está bloqueada por intentos fallidos (verificar si pasó 1 hora)
    ELSEIF v_intentos >= 5 AND v_fecha_bloqueo IS NOT NULL AND v_fecha_bloqueo > DATE_SUB(NOW(), INTERVAL 1 HOUR) THEN
        SELECT 0 AS FK_ID_ROL; -- Código: cuenta bloqueada

    -- Verificar contraseña
    ELSEIF v_contrasenia_db = p_contrasenia THEN
        -- Contraseña correcta: resetear intentos fallidos
        UPDATE usuario
        SET INTENTOS_FALLIDOS = 0, FECHA_BLOQUEO = NULL
        WHERE PK_ID_USUARIO = v_id_usuario;

        -- Devolver datos del usuario con información de membresía
        SELECT
            u.PK_ID_USUARIO,
            u.NOMBRES,
            u.APELLIDOS,
            u.NOMBRE_USUARIO AS CORREO,
            u.FK_ID_ROL,
            u.ESTADO,
            l.PK_ID_LOCAL AS ID_LOCAL,
            l.NOMBRE AS NOMBRE_LOCAL,
            s.FK_ID_TIPO_MEMBRESIA AS FK_ID_TIPOMEMBRESIA,
            tm.NOMBRE AS NOMBRE_MEMBRESIA,
            CASE WHEN s.PK_ID_SUSCRIPCION IS NOT NULL AND s.ESTADO = 1 THEN 1 ELSE 0 END AS TIENE_MEMBRESIA_ACTIVA
        FROM usuario u
        LEFT JOIN local l ON l.FK_ID_USUARIO = u.PK_ID_USUARIO
        LEFT JOIN suscripcion s ON s.FK_ID_LOCAL = l.PK_ID_LOCAL AND s.ESTADO = 1
        LEFT JOIN tipo_membresia tm ON s.FK_ID_TIPO_MEMBRESIA = tm.PK_ID_TIPO_MEMBRESIA
        WHERE u.PK_ID_USUARIO = v_id_usuario;

    ELSE
        -- Contraseña incorrecta: incrementar intentos
        UPDATE usuario
        SET
            INTENTOS_FALLIDOS = COALESCE(INTENTOS_FALLIDOS, 0) + 1,
            FECHA_BLOQUEO = CASE WHEN COALESCE(INTENTOS_FALLIDOS, 0) + 1 >= 5 THEN NOW() ELSE FECHA_BLOQUEO END
        WHERE PK_ID_USUARIO = v_id_usuario;

        SELECT 99 AS FK_ID_ROL; -- Código: contraseña incorrecta
    END IF;
END//
DELIMITER ;

-- SP: Login con Google (sin contraseña)
DROP PROCEDURE IF EXISTS login_usuario_google;
DELIMITER //
CREATE PROCEDURE login_usuario_google(
    IN p_correo VARCHAR(100)
)
BEGIN
    SELECT
        u.PK_ID_USUARIO,
        u.NOMBRES,
        u.APELLIDOS,
        u.NOMBRE_USUARIO AS CORREO,
        u.FK_ID_ROL,
        u.ESTADO,
        l.PK_ID_LOCAL AS ID_LOCAL,
        l.NOMBRE AS NOMBRE_LOCAL,
        s.FK_ID_TIPO_MEMBRESIA AS FK_ID_TIPOMEMBRESIA,
        tm.NOMBRE AS NOMBRE_MEMBRESIA,
        CASE WHEN s.PK_ID_SUSCRIPCION IS NOT NULL AND s.ESTADO = 1 THEN 1 ELSE 0 END AS TIENE_MEMBRESIA_ACTIVA
    FROM usuario u
    LEFT JOIN local l ON l.FK_ID_USUARIO = u.PK_ID_USUARIO
    LEFT JOIN suscripcion s ON s.FK_ID_LOCAL = l.PK_ID_LOCAL AND s.ESTADO = 1
    LEFT JOIN tipo_membresia tm ON s.FK_ID_TIPO_MEMBRESIA = tm.PK_ID_TIPO_MEMBRESIA
    WHERE LOWER(u.NOMBRE_USUARIO) = LOWER(TRIM(p_correo))
    LIMIT 1;
END//
DELIMITER ;
