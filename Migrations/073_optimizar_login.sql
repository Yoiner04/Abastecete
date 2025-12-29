-- Migración 073: Optimizar login
-- ============================================================
-- Agrega índices para acelerar las consultas de login
-- ============================================================

-- Índice para búsqueda por NOMBRE_USUARIO (login)
-- Si ya existe el índice, esta línea dará error (ignorar)
CREATE INDEX idx_usuario_nombre_usuario ON usuario(NOMBRE_USUARIO);

-- Verificar índices existentes
SHOW INDEX FROM usuario;
