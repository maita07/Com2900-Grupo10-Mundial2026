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

Archivo: 04_2_IMPORT_PAISES_E_INDICADORES.sql
Descripcion: 
  - Stored Procedure de importación masiva de Países e Indicadores
  - Paises desde archivo CSV utilizando BULK INSERT y Staging Tables,
  - Indicadores con consumo de API con registro.
  - Registro centralizado de auditoría: cualquier fallo de lectura o
    violación de restricciones se persiste automáticamente en 
    auditoria.LOG_IMPORTACION mediante el procedimiento
    auditoria.sp_REGISTRAR_ERROR_IMPORTACION.
---------------------------------------------------------
*/
USE DB_Mundial2026_Grupo10;
GO

<<<<<<< HEAD
CREATE OR ALTER PROCEDURE geografia.sp_IMPORT_PAISES_E_INDICADORES_CSV
    @RutaCSV_Paises VARCHAR(500) = 'C:\Mundial2026\paises.csv'
=======
CREATE OR ALTER PROCEDURE geografia.sp_IMPORTAR_PAISES_E_INDICADORES
    @RutaPaisesCSV VARCHAR(500) = 'C:\Mundial2026\Data\paises.csv',
    @RutaIndicadoresCSV VARCHAR(500) = 'C:\Mundial2026\Data\indicadores.csv'
>>>>>>> 665418da9c6cd6df095a61d772994afbea5e215c
AS
BEGIN
    SET NOCOUNT ON;

    PRINT '  INICIO IMPORTACIÓN DE PAÍSES E INDICADORES (CSV)       ';

    DECLARE @NombreProc          VARCHAR(100) = 'geografia.sp_IMPORT_PAISES_E_INDICADORES_CSV';
    DECLARE @OrigenDatos         VARCHAR(50)  = 'CSV_BANCO_MUNDIAL';
    DECLARE @CantPaisesTemporal  INT          = 0;
    DECLARE @PeriodoRef          INT          = 2023;
    DECLARE @ErrLinea            INT;
    DECLARE @ErrMensaje          NVARCHAR(4000);

    BEGIN TRY
        
        -- 1. TABLA TEMPORAL DE PAÍSES
        IF OBJECT_ID('tempdb..#PaisesMundial') IS NOT NULL DROP TABLE #PaisesMundial;
        CREATE TABLE #PaisesMundial (
            id_pais            CHAR(3) NOT NULL PRIMARY KEY,
            nombre_pais        VARCHAR(50) NOT NULL,
            moneda_pais        VARCHAR(30) NOT NULL,
            pbi_per_capita_usd DECIMAL(18,2) NOT NULL,
            poblacion_estimada BIGINT NOT NULL,
            indice_inflacion   DECIMAL(5,2) NOT NULL
        );

        -- 2. DICCIONARIO DE HOMOLOGACIÓN FIFA / ISO
        IF OBJECT_ID('tempdb..#Homologacion') IS NOT NULL DROP TABLE #Homologacion;
        CREATE TABLE #Homologacion (
            id_pais_fifa  CHAR(3) PRIMARY KEY,
            codigo_iso_bm CHAR(3) NOT NULL,
            moneda_pais   VARCHAR(30) NOT NULL
        );

        INSERT INTO #Homologacion (id_pais_fifa, codigo_iso_bm, moneda_pais)
        VALUES
            ('USA','USA','Dólar estadounidense'), ('MEX','MEX','Peso mexicano'), ('CAN','CAN','Dólar canadiense'),
            ('ARG','ARG','Peso argentino'),        ('BRA','BRA','Real brasileño'), ('COL','COL','Peso colombiano'),
            ('URU','URY','Peso uruguayo'),        ('ECU','ECU','Dólar estadounidense'), ('PAR','PRY','Guaraní'),
            ('GER','DEU','Euro'),                 ('FRA','FRA','Euro'),           ('ESP','ESP','Euro'),
            ('ENG','GBR','Libra esterlina'),      ('SCO','GBR','Libra esterlina'),('BEL','BEL','Euro'),
            ('NED','NLD','Euro'),                 ('POR','PRT','Euro'),           ('CRO','HRV','Euro'),
            ('SUI','CHE','Franco suizo'),         ('AUT','AUT','Euro'),           ('CZE','CZE','Corona checa'),
            ('BIH','BIH','Marco convertible'),    ('NOR','NOR','Corona noruega'), ('SWE','SWE','Corona sueca'),
            ('TUR','TUR','Lira turca'),           ('MAR','MAR','Dirham marroquí'),('SEN','SEN','Franco CFA'),
            ('ALG','DZA','Dinar argelino'),       ('EGY','EGY','Libra egipcia'),  ('CIV','CIV','Franco CFA'),
            ('TUN','TUN','Dinar tunecino'),       ('RSA','ZAF','Rand'),           ('COD','COD','Franco congoleño'),
            ('CPV','CPV','Escudo caboverdiano'),  ('JPN','JPN','Yen'),            ('KOR','KOR','Won surcoreano'),
            ('IRN','IRN','Rial iraní'),           ('AUS','AUS','Dólar australiano'),('KSA','SAU','Riyal saudí'),
            ('QAT','QAT','Riyal catarí'),         ('IRQ','IRQ','Dinar iraquí'),   ('UZB','UZB','Som uzbeko'),
            ('PAN','PAN','Balboa'),               ('CUW','CUW','Florín antillano'),('HAI','HTI','Gourde haitiano'),
            ('GHA','GHA','Cedi ghanés'),          ('JOR','JOR','Dinar jordano'),  ('NZL','NZL','Dólar neozelandés');

        -- 3. LECTURA DEL CSV MEDIANTE BULK INSERT
        IF @RutaCSV_Paises IS NOT NULL AND @RutaCSV_Paises <> ''
        BEGIN
            IF OBJECT_ID('tempdb..#Raw_CSV') IS NOT NULL DROP TABLE #Raw_CSV;
            CREATE TABLE #Raw_CSV (
                Linea NVARCHAR(MAX)
            );

            DECLARE @SQL_Bulk NVARCHAR(MAX) = N'
                BULK INSERT #Raw_CSV
                FROM ''' + REPLACE(@RutaCSV_Paises, '''', '''''') + N'''
                WITH (
                    FIRSTROW = 5,
                    ROWTERMINATOR = ''\n'',
                    CODEPAGE = ''65001''
                );';

            BEGIN TRY
                EXEC sp_executesql @SQL_Bulk;
                PRINT '--> CSV cargado correctamente.';
            END TRY
            BEGIN CATCH
                SET @ErrLinea   = ERROR_LINE();
                SET @ErrMensaje = 'Error al leer el CSV de países: ' + ERROR_MESSAGE();

                EXEC auditoria.sp_REGISTRAR_ERROR_IMPORTACION
                    @proceso_origen = @NombreProc,
                    @clave_registro = @RutaCSV_Paises,
                    @mensaje_error  = @ErrMensaje,
                    @linea_error    = @ErrLinea;

                PRINT '--> [ADVERTENCIA]: Falla al leer el archivo. Se activará el modo contingencia.';
            END CATCH;

            -- 4. PARSEO Y FILTRADO DE LAS SELECCIONES
            IF EXISTS (SELECT 1 FROM #Raw_CSV)
            BEGIN
                ;WITH DatosCSV AS
                (
                    SELECT
                        REPLACE(SUBSTRING(Linea, 2, CHARINDEX('","', Linea) - 2), '"', '') AS NombrePaisCSV,
                        REPLACE(SUBSTRING(Linea, CHARINDEX('","', Linea) + 3, 3), '"', '') AS CodigoISOCSV,
                        TRY_CAST(LTRIM(RTRIM(REPLACE(REVERSE(SUBSTRING(REVERSE(Linea),
                            CHARINDEX(',', REVERSE(Linea)) + 1,
                            CHARINDEX(',', REVERSE(Linea), CHARINDEX(',', REVERSE(Linea)) + 1) - CHARINDEX(',', REVERSE(Linea)) - 1
                        )), '"', ''))) AS DECIMAL(18,2)) AS Val2023CSV
                    FROM #Raw_CSV
                    WHERE Linea LIKE '%NY.GDP.PCAP.CD%'
                )
                INSERT INTO #PaisesMundial (
                    id_pais, nombre_pais, moneda_pais, pbi_per_capita_usd, poblacion_estimada, indice_inflacion
                )
                SELECT DISTINCT
                    H.id_pais_fifa,
                    CASE
                        WHEN H.id_pais_fifa = 'ENG' THEN 'Inglaterra'
                        WHEN H.id_pais_fifa = 'SCO' THEN 'Escocia'
                        ELSE LEFT(D.NombrePaisCSV, 50)
                    END,
                    H.moneda_pais,
                    ISNULL(D.Val2023CSV, 15000.00),
                    ISNULL((SELECT TOP 1 poblacion_total FROM geografia.INDICADOR_ECONOMICO_PAIS I WHERE I.id_pais = H.id_pais_fifa AND I.periodo_anio = @PeriodoRef), 10000000),
                    ISNULL((SELECT TOP 1 indice_inflacion FROM geografia.INDICADOR_ECONOMICO_PAIS I WHERE I.id_pais = H.id_pais_fifa AND I.periodo_anio = @PeriodoRef), 5.00)
                FROM DatosCSV D
                INNER JOIN #Homologacion H ON D.CodigoISOCSV = H.codigo_iso_bm;

                PRINT '--> Homologación FIFA / ISO finalizada.';
            END;
        END;

        -- 5. CONTINGENCIA: 10 PAÍSES DE PRUEBA SI NO HUBO CSV
        SELECT @CantPaisesTemporal = COUNT(*) FROM #PaisesMundial;
        IF @CantPaisesTemporal = 0
        BEGIN
            SET @OrigenDatos = 'CONTINGENCIA_TEST (10 PAISES)';
            PRINT '--> CSV VACÍO O NO DISPONIBLE. CARGANDO 10 PAÍSES DE PRUEBA.';

            INSERT INTO #PaisesMundial (id_pais, nombre_pais, moneda_pais, pbi_per_capita_usd, poblacion_estimada, indice_inflacion)
            SELECT V.id_pais, V.nombre_pais, H.moneda_pais, V.pbi, V.poblacion, V.inflacion
            FROM (
                VALUES
                ('USA','Estados Unidos',76398.59,335000000,3.40),
                ('MEX','México',11091.27,128500000,4.66),
                ('CAN','Canadá',52722.48,39500000,3.88),
                ('ARG','Argentina',13686.01,46000000,211.40),
                ('BRA','Brasil',8917.67,215000000,4.62),
                ('ESP','España',29674.52,48000000,3.55),
                ('GER','Alemania',48718.35,84000000,5.90),
                ('FRA','Francia',40886.25,68000000,4.90),
                ('ENG','Inglaterra',46125.26,56500000,7.30),
                ('RSA','Sudáfrica',6776.48,60000000,6.00)
            ) V(id_pais, nombre_pais, pbi, poblacion, inflacion)
            INNER JOIN #Homologacion H ON V.id_pais = H.id_pais_fifa;

            SET @CantPaisesTemporal = 10;
        END;

        -- 6. UPSERT MASIVO TRANSACCIONAL
        PRINT '--> Ejecutando UPSERT de países e indicadores...';
        BEGIN TRANSACTION;

        -- A. PAÍS (Actualizar existentes)
        UPDATE P
        SET P.nombre_pais = T.nombre_pais,
            P.moneda_pais = T.moneda_pais,
            P.pbi_per_capita_actual = T.pbi_per_capita_usd
        FROM geografia.PAIS P
        INNER JOIN #PaisesMundial T ON P.id_pais = T.id_pais;

        -- B. PAÍS (Insertar nuevos)
        INSERT INTO geografia.PAIS (id_pais, nombre_pais, moneda_pais, pbi_per_capita_actual)
        SELECT T.id_pais, T.nombre_pais, T.moneda_pais, T.pbi_per_capita_usd
        FROM #PaisesMundial T
        WHERE NOT EXISTS (SELECT 1 FROM geografia.PAIS P WHERE P.id_pais = T.id_pais);

        -- C. INDICADORES (Actualizar existentes)
        UPDATE I
        SET I.pbi_per_capita_usd = T.pbi_per_capita_usd,
            I.poblacion_total    = T.poblacion_estimada,
            I.indice_inflacion   = T.indice_inflacion
        FROM geografia.INDICADOR_ECONOMICO_PAIS I
        INNER JOIN #PaisesMundial T ON I.id_pais = T.id_pais
        WHERE I.periodo_anio = @PeriodoRef;

        -- D. INDICADORES (Insertar nuevos)
        INSERT INTO geografia.INDICADOR_ECONOMICO_PAIS (
            id_pais, periodo_anio, pbi_per_capita_usd, poblacion_total, indice_inflacion
        )
        SELECT T.id_pais, @PeriodoRef, T.pbi_per_capita_usd, T.poblacion_estimada, T.indice_inflacion
        FROM #PaisesMundial T
        WHERE NOT EXISTS (
            SELECT 1 FROM geografia.INDICADOR_ECONOMICO_PAIS I
            WHERE I.id_pais = T.id_pais AND I.periodo_anio = @PeriodoRef
        );

        COMMIT TRANSACTION;

        -- Limpieza
        IF OBJECT_ID('tempdb..#Raw_CSV') IS NOT NULL DROP TABLE #Raw_CSV;
        DROP TABLE #PaisesMundial;
        DROP TABLE #Homologacion;

        PRINT '============================================================';
        PRINT '  IMPORTACIÓN FINALIZADA CORRECTAMENTE                      ';
        PRINT '  ORIGEN: ' + @OrigenDatos;
        PRINT '  PAÍSES PROCESADOS: ' + CAST(@CantPaisesTemporal AS VARCHAR(10));
        PRINT '============================================================';

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @ErrLinea   = ERROR_LINE();
        SET @ErrMensaje = 'Fallo en proceso de importación de países: ' + ERROR_MESSAGE();

        EXEC auditoria.sp_REGISTRAR_ERROR_IMPORTACION
            @proceso_origen = @NombreProc,
            @clave_registro = @RutaCSV_Paises,
            @mensaje_error  = @ErrMensaje,
            @linea_error    = @ErrLinea;

        PRINT '--> ERROR REGISTRADO EN AUDITORÍA: ' + @ErrMensaje;
        THROW 50004, @ErrMensaje, 1;
    END CATCH;
END;
GO

/*
================================================================================
                Consumo de API
================================================================================
*/
CREATE OR ALTER PROCEDURE geografia.sp_IMPORT_HISTORIAL_TIPO_CAMBIO_API
    @UrlAPI          VARCHAR(500) = 'https://open.er-api.com/v6/latest/USD',
    @FechaCotizacion DATE         = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @FechaCotizacion IS NULL
        SET @FechaCotizacion = CAST(GETDATE() AS DATE);

    DECLARE @NombreProc   VARCHAR(100) = 'geografia.sp_IMPORT_HISTORIAL_TIPO_CAMBIO_API';
    DECLARE @Object       INT          = NULL;
    DECLARE @ResponseText VARCHAR(8000);
    DECLARE @Status       INT;
    DECLARE @HResult      INT;
    DECLARE @ErrLinea     INT;
    DECLARE @ErrMensaje   NVARCHAR(4000);

    BEGIN TRY
   
        PRINT '  INICIO CONSUMO DE API REST DE COTIZACIONES             ';

        -- 1. CONSUMO DE API VIA HTTP
        EXEC @HResult = sp_OACreate 'MSXML2.ServerXMLHTTP', @Object OUT;
        IF @HResult <> 0
            THROW 50001, 'No se pudo crear el objeto OLE HTTP.', 1;

        EXEC @HResult = sp_OAMethod @Object, 'open', NULL, 'GET', @UrlAPI, 'false';
        IF @HResult <> 0
            THROW 50002, 'Error al configurar la conexión HTTP con la API.', 1;

        EXEC @HResult = sp_OAMethod @Object, 'send';
        IF @HResult <> 0
            THROW 50003, 'Error al enviar la solicitud HTTP al proveedor de cambio.', 1;

        EXEC sp_OAGetProperty @Object, 'status', @Status OUT;
        IF @Status <> 200
        BEGIN
            DECLARE @MsgHttp VARCHAR(200) = 'La API respondió con código de estado HTTP ' + CAST(ISNULL(@Status, 0) AS VARCHAR(10));
            THROW 50004, @MsgHttp, 1;
        END;

        EXEC sp_OAGetProperty @Object, 'responseText', @ResponseText OUT;
        EXEC sp_OADestroy @Object;
        SET @Object = NULL;

        IF @ResponseText IS NULL OR ISJSON(@ResponseText) <> 1
            THROW 50005, 'La respuesta recibida no posee un formato JSON válido.', 1;

        PRINT '--> API REST consultada y validada correctamente.';

        -- 2. EXTRAER COTIZACIONES JSON CON OPENJSON (SET-BASED)
        IF OBJECT_ID('tempdb..#CotizacionesAPI') IS NOT NULL DROP TABLE #CotizacionesAPI;
        SELECT
            [key] COLLATE DATABASE_DEFAULT AS codigo_moneda,
            TRY_CONVERT(DECIMAL(18,6), [value]) AS valor_cotizacion
        INTO #CotizacionesAPI
        FROM OPENJSON(@ResponseText, '$.rates')
        WHERE TRY_CONVERT(DECIMAL(18,6), [value]) IS NOT NULL;

        -- 3. HOMOLOGACIÓN PAÍS / MONEDA ISO
        IF OBJECT_ID('tempdb..#MapaMonedas') IS NOT NULL DROP TABLE #MapaMonedas;
        CREATE TABLE #MapaMonedas (
            id_pais    CHAR(3) PRIMARY KEY,
            moneda_iso VARCHAR(5) NOT NULL
        );

        INSERT INTO #MapaMonedas
        VALUES
            ('USA','USD'), ('MEX','MXN'), ('CAN','CAD'), ('ARG','ARS'), ('BRA','BRL'), ('COL','COP'),
            ('URU','UYU'), ('ECU','USD'), ('PAR','PYG'), ('GER','EUR'), ('FRA','EUR'), ('ESP','EUR'),
            ('ENG','GBP'), ('SCO','GBP'), ('BEL','EUR'), ('NED','EUR'), ('POR','EUR'), ('CRO','EUR'),
            ('SUI','CHF'), ('AUT','EUR'), ('CZE','CZK'), ('BIH','BAM'), ('NOR','NOK'), ('SWE','SEK'),
            ('TUR','TRY'), ('MAR','MAD'), ('SEN','XOF'), ('ALG','DZD'), ('EGY','EGP'), ('CIV','XOF'),
            ('TUN','TND'), ('RSA','ZAR'), ('COD','CDF'), ('CPV','CVE'), ('JPN','JPY'), ('KOR','KRW'),
            ('IRN','IRR'), ('AUS','AUD'), ('KSA','SAR'), ('QAT','QAR'), ('IRQ','IQD'), ('UZB','UZS'),
            ('PAN','PAB'), ('CUW','ANG'), ('HAI','HTG'), ('GHA','GHS'), ('JOR','JOD'), ('NZL','NZD');

        -- 4. CRUZAR CON PAÍSES DE LA BASE
        IF OBJECT_ID('tempdb..#CotizacionesPais') IS NOT NULL DROP TABLE #CotizacionesPais;
        SELECT
            P.id_pais,
            M.moneda_iso,
            C.valor_cotizacion
        INTO #CotizacionesPais
        FROM geografia.PAIS P
        INNER JOIN #MapaMonedas M ON P.id_pais = M.id_pais
        LEFT JOIN #CotizacionesAPI C ON C.codigo_moneda = M.moneda_iso;

        -- 5. UPSERT TRANSACCIONAL EN HISTORIAL_TIPO_CAMBIO
        BEGIN TRANSACTION;

        -- Actualizar cotizaciones preexistentes de la fecha
        UPDATE H
        SET H.valor_cotizacion = C.valor_cotizacion,
            H.codigo_moneda    = C.moneda_iso
        FROM geografia.HISTORIAL_TIPO_CAMBIO H
        INNER JOIN #CotizacionesPais C ON H.id_pais = C.id_pais
        WHERE H.fecha_cotizacion = @FechaCotizacion
          AND C.valor_cotizacion IS NOT NULL;

        -- Insertar cotizaciones nuevas de la fecha
        INSERT INTO geografia.HISTORIAL_TIPO_CAMBIO (id_pais, fecha_cotizacion, valor_cotizacion, codigo_moneda)
        SELECT C.id_pais, @FechaCotizacion, C.valor_cotizacion, C.moneda_iso
        FROM #CotizacionesPais C
        WHERE C.valor_cotizacion IS NOT NULL
          AND NOT EXISTS (
              SELECT 1 FROM geografia.HISTORIAL_TIPO_CAMBIO H
              WHERE H.id_pais = C.id_pais AND H.fecha_cotizacion = @FechaCotizacion
          );

        COMMIT TRANSACTION;
        PRINT '--> Cotizaciones sincronizadas exitosamente.';

        -- Limpieza
        DROP TABLE #CotizacionesPais;
        DROP TABLE #MapaMonedas;
        DROP TABLE #CotizacionesAPI;

        PRINT '  API DE COTIZACIONES PROCESADA CON ÉXITO                   ';

    END TRY
    BEGIN CATCH
        IF @Object IS NOT NULL
        BEGIN
            EXEC sp_OADestroy @Object;
            SET @Object = NULL;
        END;

        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @ErrLinea   = ERROR_LINE();
        SET @ErrMensaje = 'Error en consumo o carga de API de cotizaciones: ' + ERROR_MESSAGE();

        -- Registro centralizado de auditoría
        EXEC auditoria.sp_REGISTRAR_ERROR_IMPORTACION
            @proceso_origen = @NombreProc,
            @clave_registro = @UrlAPI,
            @mensaje_error  = @ErrMensaje,
            @linea_error    = @ErrLinea;

        PRINT '--> ERROR REGISTRADO EN AUDITORÍA: ' + @ErrMensaje;
        THROW 50006, @ErrMensaje, 1;
    END CATCH;
END;
GO
