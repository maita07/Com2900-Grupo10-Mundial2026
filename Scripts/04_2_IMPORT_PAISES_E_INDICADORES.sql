/*
---------------------------------------------------------
UNLaM - Universidad Nacional de La Matanza
Departamento de Ingeniería e Investigaciones Tecnológicas
Materia: Base de Datos Aplicada (Comisión 5600)
Entrega 6 - Importación de Países e Indicadores Económicos (CSV / BULK INSERT)
2026 - 2C
Grupo 10

Integrantes:
- Monasterio Erik: MonasteryEr
- Arena Ariel Ignacio: arielarena
- Castillo Gabriela Florencia: ItsFlorencia
- Maita Pitado Jose Gregorio: maita07

Descripcion: Stored Procedure de importación masiva de Países e Indicadores
             Económicos desde archivos CSV utilizando BULK INSERT y Staging Tables,
             con registro de errores en auditoria.LOG_IMPORTACION.
---------------------------------------------------------
*/

USE DB_Mundial2026_Grupo10;
GO

CREATE OR ALTER PROCEDURE geografia.sp_IMPORTAR_PAISES_E_INDICADORES
    @RutaPaisesCSV VARCHAR(500) = 'C:\Mundial2026\Data\paises.csv',
    @RutaIndicadoresCSV VARCHAR(500) = 'C:\Mundial2026\Data\indicadores.csv'
AS
BEGIN
    SET NOCOUNT ON;

    PRINT '     IMPORTACIÓN MASIVA: PAÍSES E INDICADORES ECONÓMICOS (CSV)          ';

    -- 1. IMPORTACIÓN DE PAÍSES DESDE CSV
    BEGIN TRY
        -- Crear Tabla de Staging para Países
        IF OBJECT_ID('tempdb..#StagingPais') IS NOT NULL DROP TABLE #StagingPais;
        CREATE TABLE #StagingPais (
            id_pais VARCHAR(10),
            nombre_pais VARCHAR(100),
            moneda_pais VARCHAR(50),
            pbi_per_capita VARCHAR(50)
        );

        -- Intentar BULK INSERT desde archivo CSV
        DECLARE @SqlPaises NVARCHAR(MAX) = '
            BULK INSERT #StagingPais
            FROM ''' + @RutaPaisesCSV + '''
            WITH (
                FIRSTROW = 2,
                FIELDTERMINATOR = '';'',
                ROWTERMINATOR = ''\n'',
                CODEPAGE = ''65001'',
                TABLOCK
            );';

        BEGIN TRY
            EXEC sp_executesql @SqlPaises;
            PRINT '--> Archivo de países procesado correctamente con BULK INSERT.';
        END TRY
        BEGIN CATCH
            PRINT '--> Alerta: No se encontró el archivo ' + @RutaPaisesCSV + '. Cargando datos iniciales por defecto...';
            
            -- Datos de muestra por defecto si no existe el CSV en disco
            INSERT INTO #StagingPais (id_pais, nombre_pais, moneda_pais, pbi_per_capita) VALUES
            ('ARG', 'Argentina', 'ARS', '13650.00'),
            ('BRA', 'Brasil', 'BRL', '8910.00'),
            ('USA', 'Estados Unidos', 'USD', '76398.00'),
            ('CAN', 'Canadá', 'CAD', '51980.00'),
            ('MEX', 'México', 'MXN', '11060.00'),
            ('DEU', 'Alemania', 'EUR', '48718.00'),
            ('FRA', 'Francia', 'EUR', '40886.00'),
            ('ESP', 'España', 'EUR', '29350.00'),
            ('ENG', 'Inglaterra', 'GBP', '46125.00'),
            ('JPN', 'Japón', 'JPY', '33815.00');
        END CATCH;

        -- Insertar datos limpios en la tabla definitiva geografia.PAIS
        INSERT INTO geografia.PAIS (id_pais, nombre_pais, moneda_pais, pbi_per_capita_actual)
        SELECT 
            UPPER(TRIM(S.id_pais)),
            TRIM(S.nombre_pais),
            UPPER(TRIM(S.moneda_pais)),
            CAST(REPLACE(S.pbi_per_capita, ',', '.') AS DECIMAL(18,2))
        FROM #StagingPais S
        WHERE NOT EXISTS (
            SELECT 1 FROM geografia.PAIS P WHERE P.id_pais = UPPER(TRIM(S.id_pais))
        )
        AND LEN(TRIM(S.id_pais)) = 3;

        PRINT '--> Tabla geografia.PAIS actualizada exitosamente.';
    END TRY
    BEGIN CATCH
        INSERT INTO auditoria.LOG_IMPORTACION (proceso_origen, mensaje_error, linea_error)
        VALUES ('geografia.sp_IMPORTAR_PAISES_E_INDICADORES [Países]', ERROR_MESSAGE(), ERROR_LINE());

        PRINT '--> Error en importación de Países. Registrado en auditoría.';
    END CATCH;


    -- 2. IMPORTACIÓN DE INDICADORES ECONÓMICOS DESDE CSV
    BEGIN TRY
        -- Crear Tabla de Staging para Indicadores
        IF OBJECT_ID('tempdb..#StagingIndicadores') IS NOT NULL DROP TABLE #StagingIndicadores;
        CREATE TABLE #StagingIndicadores (
            id_pais VARCHAR(10),
            periodo_anio VARCHAR(10),
            pbi_per_capita_usd VARCHAR(50),
            poblacion_total VARCHAR(50),
            indice_inflacion VARCHAR(50)
        );

        -- Intentar BULK INSERT desde archivo CSV
        DECLARE @SqlIndicadores NVARCHAR(MAX) = '
            BULK INSERT #StagingIndicadores
            FROM ''' + @RutaIndicadoresCSV + '''
            WITH (
                FIRSTROW = 2,
                FIELDTERMINATOR = '';'',
                ROWTERMINATOR = ''\n'',
                CODEPAGE = ''65001'',
                TABLOCK
            );';

        BEGIN TRY
            EXEC sp_executesql @SqlIndicadores;
            PRINT '--> Archivo de indicadores procesado correctamente con BULK INSERT.';
        END TRY
        BEGIN CATCH
            PRINT '--> Alerta: No se encontró el archivo ' + @RutaIndicadoresCSV + '. Cargando datos iniciales por defecto...';

            -- Datos de muestra por defecto si no existe el CSV en disco
            INSERT INTO #StagingIndicadores (id_pais, periodo_anio, pbi_per_capita_usd, poblacion_total, indice_inflacion) VALUES
            ('ARG', '2025', '13650.00', '46044703', '120.50'),
            ('BRA', '2025', '8910.00', '215313498', '4.50'),
            ('USA', '2025', '76398.00', '333287557', '3.10'),
            ('CAN', '2025', '51980.00', '38929902', '2.80'),
            ('MEX', '2025', '11060.00', '127504125', '4.70');
        END CATCH;

        -- Insertar datos limpios en geografia.INDICADOR_ECONOMICO_PAIS
        INSERT INTO geografia.INDICADOR_ECONOMICO_PAIS (id_pais, periodo_anio, pbi_per_capita_usd, poblacion_total, indice_inflacion)
        SELECT 
            UPPER(TRIM(I.id_pais)),
            CAST(I.periodo_anio AS INT),
            CAST(REPLACE(I.pbi_per_capita_usd, ',', '.') AS DECIMAL(18,2)),
            CAST(I.poblacion_total AS BIGINT),
            CAST(REPLACE(I.indice_inflacion, ',', '.') AS DECIMAL(5,2))
        FROM #StagingIndicadores I
        INNER JOIN geografia.PAIS P ON P.id_pais = UPPER(TRIM(I.id_pais))
        WHERE NOT EXISTS (
            SELECT 1 FROM geografia.INDICADOR_ECONOMICO_PAIS IND
            WHERE IND.id_pais = UPPER(TRIM(I.id_pais)) 
              AND IND.periodo_anio = CAST(I.periodo_anio AS INT)
        );

        PRINT '--> Tabla geografia.INDICADOR_ECONOMICO_PAIS actualizada exitosamente.';
    END TRY
    BEGIN CATCH
        INSERT INTO auditoria.LOG_IMPORTACION (proceso_origen, mensaje_error, linea_error)
        VALUES ('geografia.sp_IMPORTAR_PAISES_E_INDICADORES [Indicadores]', ERROR_MESSAGE(), ERROR_LINE());

        PRINT '--> Error en importación de Indicadores. Registrado en auditoría.';
    END CATCH;

    PRINT '             PROCESO DE IMPORTACIÓN FINALIZADO                          ';
END;
GO
