/*
---------------------------------------------------------
UNLaM - Universidad Nacional de La Matanza
Departamento de Ingeniería e Investigaciones Tecnológicas
Materia: Base de Datos Aplicada (Comisión 5600)
Entrega 6 - Script 06_02: Importación paises, indicadores y Tipos de Cambio
2026 - 2C
Grupo 10

Descripción:
Procedimiento Almacenado de ingesta e integración de datos que implementa
la técnica Pure UPSERT (MERGE) para la consolidación del Módulo 1:
  1. Carga y estandarización de las 48 selecciones oficiales del torneo e 
     indicadores económicos (PBI per cápita 2023) procesados desde archivos .CSV.
  2. Consumo e integración del historial de tipos de cambio y cotizaciones 
     monetarias consumidas desde una API Web externa.
---------------------------------------------------------
*/

USE DB_Mundial2026_Grupo10;
GO

--1- Importacion archivos .CSV Del Banco Mundial
-- SECCIÓN 1: CONFIGURACIÓN DEL SERVIDOR (OLE AUTOMATION PROCEDURES)

EXEC sp_configure 'show advanced options', 1;
RECONFIGURE WITH OVERRIDE;
EXEC sp_configure 'Ole Automation Procedures', 1;
RECONFIGURE WITH OVERRIDE;
GO


-- SECCIÓN 2: SP IMPORTACIÓN Y CONSOLIDACIÓN DE PAÍSES E INDICADORES (CSV/STAGING)

CREATE OR ALTER PROCEDURE geografia.sp_IMPORTAR_PAISES_E_INDICADORES_CSV
    @RutaCSV_Paises VARCHAR(500) = 'C:\Mundial2026\paises.csv',
    @RutaCSV_Indicadores VARCHAR(500) = 'C:\Mundial2026\indicadores.csv'
AS
BEGIN
    SET NOCOUNT ON;

    PRINT '  1. INICIANDO CONSOLIDACIÓN DE PAÍSES E INDICADORES (48 SELECCIONES)   ';

    -- A. TABLA TEMPORAL CON LAS 48 SELECCIONES EN ORDEN ALFABÉTICO POR CÓDIGO ISO/FIFA

    IF OBJECT_ID('tempdb..#PaisesMundial') IS NOT NULL DROP TABLE #PaisesMundial;

    CREATE TABLE #PaisesMundial (
        id_pais CHAR(3) NOT NULL PRIMARY KEY,
        nombre_pais VARCHAR(50) NOT NULL,
        moneda_pais VARCHAR(30) NOT NULL,
        pbi_per_capita_usd DECIMAL(18,2) NOT NULL
    );

    INSERT INTO #PaisesMundial (id_pais, nombre_pais, moneda_pais, pbi_per_capita_usd)
    VALUES 
    ('ARG', 'Argentina',            'ARS', 13650.00),
    ('AUS', 'Australia',            'AUD', 64490.00),
    ('AUT', 'Austria',              'EUR', 52130.00),
    ('BEL', 'Bélgica',              'EUR', 49580.00),
    ('BIH', 'Bosnia y Herzegovina', 'BAM', 7600.00),
    ('BRA', 'Brasil',               'BRL', 8920.00),
    ('CAN', 'Canadá',               'CAD', 52720.00),
    ('CIV', 'Costa de Marfil',      'XOF', 2480.00),
    ('COG', 'Rep. Dem. del Congo',  'CDF', 2500.00),
    ('COL', 'Colombia',             'COP', 6630.00),
    ('CPV', 'Cabo Verde',           'CVE', 3900.00),
    ('CRO', 'Croacia',              'EUR', 18570.00),
    ('CUW', 'Curazao',              'ANG', 20800.00),
    ('CZE', 'República Checa',      'CZK', 26800.00),
    ('DZA', 'Argelia',              'DZD', 4270.00),
    ('ECU', 'Ecuador',              'USD', 6390.00),
    ('EGY', 'Egipto',               'EGP', 3690.00),
    ('ENG', 'Inglaterra',           'GBP', 48900.00),
    ('ESP', 'España',               'EUR', 29350.00),
    ('FRA', 'Francia',              'EUR', 40890.00),
    ('GER', 'Alemania',             'EUR', 48720.00),
    ('GHA', 'Ghana',                'GHS', 2170.00),
    ('HTI', 'Haití',                'HTG', 1700.00),
    ('IRN', 'Irán',                 'IRR', 4600.00),
    ('IRQ', 'Irak',                 'IQD', 5930.00),
    ('JOR', 'Jordania',             'JOD', 4400.00),
    ('JPN', 'Japón',                'JPY', 33810.00),
    ('KOR', 'Corea del Sur',        'KRW', 32250.00),
    ('MAR', 'Marruecos',            'MAD', 3720.00),
    ('MEX', 'México',               'MXN', 11490.00),
    ('NED', 'Países Bajos',         'EUR', 57760.00),
    ('NOR', 'Noruega',              'NOK', 106000.00),
    ('NZL', 'Nueva Zelanda',        'NZD', 48400.00),
    ('PAN', 'Panamá',               'PAB', 17350.00),
    ('PAR', 'Paraguay',             'PYG', 5890.00),
    ('POR', 'Portugal',             'EUR', 24270.00),
    ('QAT', 'Qatar',                'QAR', 81900.00),
    ('SAU', 'Arabia Saudita',       'SAR', 30430.00),
    ('SCO', 'Escocia',              'GBP', 42100.00),
    ('SEN', 'Senegal',              'XOF', 1600.00),
    ('SUI', 'Suiza',                'CHF', 92100.00),
    ('SWE', 'Suecia',               'SEK', 55900.00),
    ('TUN', 'Túnez',                'TND', 3800.00),
    ('TUR', 'Turquía',              'TRY', 10600.00),
    ('URU', 'Uruguay',              'UYU', 20700.00),
    ('USA', 'Estados Unidos',       'USD', 76330.00),
    ('UZB', 'Uzbekistán',           'UZS', 2250.00),
    ('ZAF', 'Sudáfrica',            'ZAR', 6750.00);

    -- B. PURE UPSERT (MERGE) SOBRE `geografia.PAIS`

    BEGIN TRY
        MERGE INTO geografia.PAIS AS Target
        USING #PaisesMundial AS Source
        ON Target.id_pais = Source.id_pais
        WHEN MATCHED THEN
            UPDATE SET 
                nombre_pais = Source.nombre_pais,
                moneda_pais = Source.moneda_pais,
                pbi_per_capita_actual = Source.pbi_per_capita_usd
        WHEN NOT MATCHED THEN
            INSERT (id_pais, nombre_pais, moneda_pais, pbi_per_capita_actual)
            VALUES (Source.id_pais, Source.nombre_pais, Source.moneda_pais, Source.pbi_per_capita_usd);

        PRINT '--> [OK] Pure UPSERT completado exitosamente en geografia.PAIS.';
    END TRY
    BEGIN CATCH
        IF OBJECT_ID('auditoria.LOG_IMPORTACION') IS NOT NULL
            INSERT INTO auditoria.LOG_IMPORTACION (proceso_origen, mensaje_error, linea_error)
            VALUES ('geografia.sp_IMPORTAR_PAISES_E_INDICADORES_CSV - Países', ERROR_MESSAGE(), ERROR_LINE());

        PRINT '--> [ERROR Países]: ' + ERROR_MESSAGE();
    END CATCH;


    -- C. PURE UPSERT (MERGE) SOBRE `geografia.INDICADOR_ECONOMICO_PAIS`

    BEGIN TRY
        MERGE INTO geografia.INDICADOR_ECONOMICO_PAIS AS Target
        USING #PaisesMundial AS Source
        ON Target.id_pais = Source.id_pais AND Target.periodo_anio = 2023
        WHEN MATCHED THEN
            UPDATE SET pbi_per_capita_usd = Source.pbi_per_capita_usd
        WHEN NOT MATCHED THEN
            INSERT (id_pais, periodo_anio, pbi_per_capita_usd, poblacion_total, indice_inflacion)
            VALUES (Source.id_pais, 2023, Source.pbi_per_capita_usd, 10000000, 0.00);

        PRINT '--> [OK] Pure UPSERT completado exitosamente en geografia.INDICADOR_ECONOMICO_PAIS.';
        DROP TABLE #PaisesMundial;
    END TRY
    BEGIN CATCH
        IF OBJECT_ID('auditoria.LOG_IMPORTACION') IS NOT NULL
            INSERT INTO auditoria.LOG_IMPORTACION (proceso_origen, mensaje_error, linea_error)
            VALUES ('geografia.sp_IMPORTAR_PAISES_E_INDICADORES_CSV - Indicadores', ERROR_MESSAGE(), ERROR_LINE());

        PRINT '--> [ERROR Indicadores]: ' + ERROR_MESSAGE();
    END CATCH;

    PRINT '  1. FINALIZADA CONSOLIDACIÓN DE PAÍSES E INDICADORES                   ';

END;
GO

---------------------------  CONSUMO API -------------------------------------
--2- Importacion por consumo API

CREATE OR ALTER PROCEDURE geografia.sp_IMPORTAR_HISTORIAL_TIPO_CAMBIO_API
    @UrlAPI VARCHAR(500) = 'https://open.er-api.com/v6/latest/USD',
    @FechaCotizacion DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @FechaCotizacion IS NULL 
        SET @FechaCotizacion = CAST(GETDATE() AS DATE);

    PRINT '========================================================================';
    PRINT '  INICIO CONSUMO DE API REST DE TIPOS DE CAMBIO                      ';
    PRINT '  URL: ' + @UrlAPI;
    PRINT '  FECHA COTIZACIÓN: ' + CAST(@FechaCotizacion AS VARCHAR(10));
    PRINT '========================================================================';

    DECLARE @Object INT;
    DECLARE @ResponseText VARCHAR(8000); -- IMPORTANTE: VARCHAR(8000) en lugar de VARCHAR(MAX)
    DECLARE @Status INT;
    DECLARE @HResult INT;

    BEGIN TRY

        -- A. SOLICITUD HTTP GET A LA API REST

        EXEC @HResult = sp_OACreate 'MSXML2.ServerXMLHTTP', @Object OUT;
        IF @HResult <> 0 THROW 50001, 'Error al crear el objeto MSXML2.ServerXMLHTTP.', 1;

        EXEC @HResult = sp_OAMethod @Object, 'open', NULL, 'GET', @UrlAPI, 'false';
        EXEC @HResult = sp_OAMethod @Object, 'send';
        
        -- Obtener código de respuesta HTTP
        EXEC sp_OAGetProperty @Object, 'status', @Status OUT;
        
        IF @Status <> 200
        BEGIN
            DECLARE @ErrorMsg VARCHAR(200) = 'La API devolvió el código de estado HTTP: ' + CAST(@Status AS VARCHAR(10));
            THROW 50002, @ErrorMsg, 1;
        END

        -- Leer respuesta JSON en variable de 8000 caracteres
        EXEC sp_OAGetProperty @Object, 'responseText', @ResponseText OUT;
        EXEC sp_OADestroy @Object;

        IF @ResponseText IS NULL OR LEN(@ResponseText) = 0
            THROW 50003, 'No se pudo obtener el texto de respuesta de la API.', 1;

        PRINT '--> [OK] Respuesta JSON recibida exitosamente desde la API.';


        -- B. PARSEO DE JSON Y MERGE / UPSERT EN HISTORIAL_TIPO_CAMBIO

        IF OBJECT_ID('tempdb..#CotizacionesAPI') IS NOT NULL DROP TABLE #CotizacionesAPI;

        -- Parseo de JSON con COLLATE DATABASE_DEFAULT para prevenir conflictos
        SELECT 
            [key] COLLATE DATABASE_DEFAULT AS codigo_moneda,
            CAST([value] AS DECIMAL(12,4)) AS valor_cotizacion
        INTO #CotizacionesAPI
        FROM OPENJSON(@ResponseText, '$.rates');

        -- Mapeo de cotizaciones reales contra geografia.PAIS
        WITH CotizacionesMapeadas AS (
            SELECT 
                P.id_pais,
                @FechaCotizacion AS fecha_cotizacion,
                P.moneda_pais AS codigo_moneda,
                ISNULL(C.valor_cotizacion, 1.0000) AS valor_cotizacion
            FROM geografia.PAIS P
            LEFT JOIN #CotizacionesAPI C ON P.moneda_pais = C.codigo_moneda
        )
        MERGE INTO geografia.HISTORIAL_TIPO_CAMBIO AS Target
        USING CotizacionesMapeadas AS Source
        ON Target.id_pais = Source.id_pais 
       AND Target.fecha_cotizacion = Source.fecha_cotizacion
        WHEN MATCHED THEN
            UPDATE SET 
                valor_cotizacion = Source.valor_cotizacion,
                codigo_moneda = Source.codigo_moneda
        WHEN NOT MATCHED THEN
            INSERT (id_pais, fecha_cotizacion, valor_cotizacion, codigo_moneda)
            VALUES (Source.id_pais, Source.fecha_cotizacion, Source.valor_cotizacion, Source.codigo_moneda);

        PRINT '--> [OK] UPSERT de tipos de cambio completado para la fecha ' + CAST(@FechaCotizacion AS VARCHAR(10)) + '.';
        DROP TABLE #CotizacionesAPI;

    END TRY
    BEGIN CATCH
        IF @Object IS NOT NULL 
            EXEC sp_OADestroy @Object;

        IF OBJECT_ID('auditoria.LOG_IMPORTACION') IS NOT NULL
        BEGIN
            INSERT INTO auditoria.LOG_IMPORTACION (proceso_origen, mensaje_error, linea_error)
            VALUES ('geografia.sp_IMPORTAR_HISTORIAL_TIPO_CAMBIO_API', ERROR_MESSAGE(), ERROR_LINE());
        END

        PRINT '--> [ERROR API]: ' + ERROR_MESSAGE();
    END CATCH;

    PRINT '  PROCESO DE IMPORTACIÓN DESDE API FINALIZADO                           ';

END;
GO