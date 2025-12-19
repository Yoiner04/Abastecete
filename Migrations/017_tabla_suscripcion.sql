-- =============================================
-- Migración 017: Crear tablas suscripcion e historial_membresia
-- Descripción: Nueva estructura para manejo de membresías por local
-- =============================================

-- Tabla de suscripciones (una por local, reemplaza membresia_local)
CREATE TABLE IF NOT EXISTS suscripcion (
    PK_ID_SUSCRIPCION INT AUTO_INCREMENT PRIMARY KEY,
    FK_ID_LOCAL INT NOT NULL,
    FK_ID_TIPO_MEMBRESIA INT NOT NULL,
    ESTADO TINYINT NOT NULL DEFAULT 1 COMMENT '1=Activa, 0=Inactiva, 2=Cancelada, 3=Vencida',
    FECHA_INICIO DATETIME NOT NULL,
    FECHA_FIN DATETIME NOT NULL,
    FECHA_CREACION DATETIME DEFAULT CURRENT_TIMESTAMP,
    MONTO_PAGADO DECIMAL(10,2) NULL,
    METODO_PAGO VARCHAR(50) NULL,
    PERIODO ENUM('MENSUAL','TRIMESTRAL','SEMESTRAL','ANUAL') DEFAULT 'MENSUAL',
    NOTAS TEXT NULL,
    CONSTRAINT FK_suscripcion_local FOREIGN KEY (FK_ID_LOCAL)
        REFERENCES local(PK_ID_LOCAL) ON DELETE CASCADE,
    CONSTRAINT FK_suscripcion_tipo FOREIGN KEY (FK_ID_TIPO_MEMBRESIA)
        REFERENCES tipo_membresia(PK_ID_TIPO_MEMBRESIA),
    INDEX IDX_suscripcion_local (FK_ID_LOCAL),
    INDEX IDX_suscripcion_estado (ESTADO),
    INDEX IDX_suscripcion_fecha_fin (FECHA_FIN)
);

-- Tabla de historial de cambios de membresía
CREATE TABLE IF NOT EXISTS historial_membresia (
    PK_ID_HISTORIAL INT AUTO_INCREMENT PRIMARY KEY,
    FK_ID_LOCAL INT NOT NULL,
    FK_ID_SUSCRIPCION INT NULL,
    FK_ID_TIPO_ANTERIOR INT NULL,
    FK_ID_TIPO_NUEVO INT NOT NULL,
    TIPO_CAMBIO ENUM('ALTA','UPGRADE','DOWNGRADE','RENOVACION','CANCELACION','VENCIMIENTO','MIGRACION') NOT NULL,
    FECHA_CAMBIO DATETIME DEFAULT CURRENT_TIMESTAMP,
    FECHA_INICIO_PERIODO DATETIME NOT NULL,
    FECHA_FIN_PERIODO DATETIME NOT NULL,
    MONTO DECIMAL(10,2) NULL,
    PERIODO ENUM('MENSUAL','TRIMESTRAL','SEMESTRAL','ANUAL') NULL,
    NOTAS TEXT NULL,
    CONSTRAINT FK_historial_local FOREIGN KEY (FK_ID_LOCAL)
        REFERENCES local(PK_ID_LOCAL) ON DELETE CASCADE,
    INDEX IDX_historial_local (FK_ID_LOCAL),
    INDEX IDX_historial_fecha (FECHA_CAMBIO)
);

-- Agregar columna FK_ID_SUSCRIPCION_ACTIVA a la tabla local
-- Nota: MySQL no soporta IF NOT EXISTS en ADD COLUMN, usamos procedimiento
DROP PROCEDURE IF EXISTS agregar_columna_suscripcion;

DELIMITER //
CREATE PROCEDURE agregar_columna_suscripcion()
BEGIN
    IF NOT EXISTS (
        SELECT * FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME = 'local'
        AND COLUMN_NAME = 'FK_ID_SUSCRIPCION_ACTIVA'
    ) THEN
        ALTER TABLE local ADD COLUMN FK_ID_SUSCRIPCION_ACTIVA INT NULL;
    END IF;
END //
DELIMITER ;

CALL agregar_columna_suscripcion();
DROP PROCEDURE IF EXISTS agregar_columna_suscripcion;
