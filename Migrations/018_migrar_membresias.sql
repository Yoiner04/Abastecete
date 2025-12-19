-- =============================================
-- Migración 018: Migrar datos de membresia_local a suscripcion
-- Descripción: Preserva datos existentes en la nueva estructura
-- IMPORTANTE: Ejecutar después de 017_tabla_suscripcion.sql
-- =============================================

-- Migrar datos existentes de membresia_local a suscripcion
INSERT INTO suscripcion (FK_ID_LOCAL, FK_ID_TIPO_MEMBRESIA, ESTADO, FECHA_INICIO, FECHA_FIN, PERIODO, NOTAS)
SELECT
    ml.FK_ID_LOCAL,
    l.FK_ID_TIPOMEMBRESIA,
    ml.ESTADO,
    ml.FECHA_INICIO,
    COALESCE(ml.FECHA_FIN, DATE_ADD(ml.FECHA_INICIO, INTERVAL 30 DAY)),
    'MENSUAL',
    'Migrado automáticamente desde membresia_local'
FROM membresia_local ml
INNER JOIN local l ON ml.FK_ID_LOCAL = l.PK_ID_LOCAL
WHERE l.FK_ID_TIPOMEMBRESIA IS NOT NULL;

-- Actualizar la tabla local con la suscripcion activa correspondiente
UPDATE local l
INNER JOIN suscripcion s ON l.PK_ID_LOCAL = s.FK_ID_LOCAL AND s.ESTADO = 1
SET l.FK_ID_SUSCRIPCION_ACTIVA = s.PK_ID_SUSCRIPCION;

-- Crear registros en historial_membresia para todas las suscripciones migradas
INSERT INTO historial_membresia (
    FK_ID_LOCAL,
    FK_ID_SUSCRIPCION,
    FK_ID_TIPO_NUEVO,
    TIPO_CAMBIO,
    FECHA_CAMBIO,
    FECHA_INICIO_PERIODO,
    FECHA_FIN_PERIODO,
    NOTAS
)
SELECT
    FK_ID_LOCAL,
    PK_ID_SUSCRIPCION,
    FK_ID_TIPO_MEMBRESIA,
    'MIGRACION',
    FECHA_CREACION,
    FECHA_INICIO,
    FECHA_FIN,
    'Registro inicial migrado automáticamente'
FROM suscripcion;

-- Agregar constraint de FK después de que los datos estén migrados
ALTER TABLE local
ADD CONSTRAINT FK_local_suscripcion_activa
    FOREIGN KEY (FK_ID_SUSCRIPCION_ACTIVA)
    REFERENCES suscripcion(PK_ID_SUSCRIPCION)
    ON DELETE SET NULL;
