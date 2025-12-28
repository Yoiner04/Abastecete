-- Migración 067: Optimizar índices para login y permisos
-- ============================================================
-- Agregar índices para mejorar rendimiento de consultas frecuentes
-- Ejecutar cada CREATE INDEX por separado. Ignorar errores "Duplicate key name"
-- ============================================================

-- Índice para buscar usuario por NOMBRE_USUARIO (login)
CREATE INDEX idx_usuario_nombre_usuario ON usuario(NOMBRE_USUARIO);

-- Índice para buscar local por FK_ID_USUARIO
CREATE INDEX idx_local_fk_usuario ON local(FK_ID_USUARIO);

-- Índice para buscar suscripción activa por local
CREATE INDEX idx_suscripcion_local_estado ON suscripcion(FK_ID_LOCAL, ESTADO);

-- Índice para buscar permisos de usuario
CREATE INDEX idx_usuario_permiso_usuario ON usuario_permiso(FK_ID_USUARIO, ESTADO);

-- Índice para buscar permisos de membresía
CREATE INDEX idx_tipo_membresia_permiso ON tipo_membresia_permiso(FK_ID_TIPO_MEMBRESIA);

-- Índice para permiso_sistema por estado
CREATE INDEX idx_permiso_sistema_estado ON permiso_sistema(ESTADO);
