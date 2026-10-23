/*
---------------------------------------------------------
UNLaM - Universidad Nacional de La Matanza
Departamento de Ingeniería e Investigaciones Tecnológicas
Materia: Base de Datos Aplicada (Comisión 5600)
Entrega 6 - Procesos de Importación Masiva
2026 - 2C
Grupo 10

Integrantes:
- Monasterio Erik: MonasteryEr
- Arena Ariel Ignacio: arielarena
- Castillo Gabriela Florencia: ItsFlorencia
- Maita Pitado Jose Gregorio: maita07

Archivo: 04_1_CREATE_TABLE_SCHEMA_AUDITORIA.sql
Descripcion: Creación del esquema auditoria y la tabla LOG_IMPORTACION
             para la captura de errores en importaciones parciales.
---------------------------------------------------------
*/

USE DB_Mundial2026_Grupo10;
GO

-- 1. Creación del Esquema auditoria (si no existe)
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'auditoria')
BEGIN
    EXEC('CREATE SCHEMA auditoria;');
    PRINT '--> Esquema "auditoria" creado exitosamente.';
END
ELSE
BEGIN
    PRINT '--> El esquema "auditoria" ya existe.';
END;
GO

-- 2. Creación de la Tabla LOG_IMPORTACION
IF OBJECT_ID('auditoria.LOG_IMPORTACION', 'U') IS NULL
BEGIN
    CREATE TABLE auditoria.LOG_IMPORTACION (
        id_log INT IDENTITY(1,1) NOT NULL,
        proceso_origen VARCHAR(100) NOT NULL,
        fecha_hora DATETIME2 DEFAULT SYSDATETIME() NOT NULL,
        nro_fila INT NULL,
        clave_registro VARCHAR(100) NULL,
        mensaje_error VARCHAR(MAX) NOT NULL,
        linea_error INT NULL,
        CONSTRAINT PK_LOG_IMPORTACION PRIMARY KEY (id_log)
    );
    PRINT '--> Tabla "auditoria.LOG_IMPORTACION" creada exitosamente.';
END
ELSE
BEGIN
    PRINT '--> La tabla "auditoria.LOG_IMPORTACION" ya existe.';
END;
GO

-- 3. Verificación de la estructura creada
PRINT '--> Verificando la estructura de la tabla de auditoría...';
SELECT 
    COLUMN_NAME AS Columna, 
    DATA_TYPE AS TipoDato, 
    CHARACTER_MAXIMUM_LENGTH AS Longitud, 
    IS_NULLABLE AS PermiteNull
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'auditoria' AND TABLE_NAME = 'LOG_IMPORTACION';
GO