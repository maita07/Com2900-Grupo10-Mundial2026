/*
================================================================================
UNLaM - Universidad Nacional de La Matanza
Departamento de Ingeniería e Investigaciones Tecnológicas
Materia: Base de Datos Aplicada (Comisión 5600)
Entrega 6 - Importación de Cuerpos Técnicos (CSV / JSON / API REST Wikidata)
2026 - 2C
Grupo 10

Integrantes:
- Monasterio Erik: MonasteryEr
- Arena Ariel Ignacio: arielarena
- Castillo Gabriela Florencia: ItsFlorencia
- Maita Pitado Jose Gregorio: maita07

Archivo: prueba_04_7_IMPORT_CUERPO_TECNICO.sql
Descripcion:
- Módulo de importación masiva de Cuerpos Técnicos de las Selecciones:
  1. persona.sp_IMPORTAR_CUERPO_TECNICO_CSV: Importación desde archivo CSV o JSON
     descargado de Wikidata Query Service (parámetro @RutaArchivo).
  2. persona.sp_IMPORTAR_CUERPO_TECNICO_API: Consumo directo de la API REST SPARQL
     de Wikidata (https://query.wikidata.org/sparql) vía MSXML2.ServerXMLHTTP y OPENJSON
     (lanza error y registra en auditoría si no logra descargar datos).
- Reutilización del Stored Procedure de Entrega 5 (persona.sp_CUERPO_TECNICO_ABM)
  implementando lógica de Upsert ('A' = Alta / 'M' = Modificación) sin duplicados.
- Homologación de códigos ISO-3 de Wikidata a códigos FIFA de geografia.PAIS y torneo.SELECCION,
  incluyendo fallback de nacionalidad para entrenadores extranjeros cuyo país no esté en PAIS.
- Tolerancia a fallos parciales: importa todos los registros válidos y registra los
  rechazados fila por fila en auditoria.LOG_IMPORTACION.
================================================================================
*/

USE DB_Mundial2026_Grupo10;
GO

-- Habilitación de OLE Automation Procedures para consumo directo de API REST HTTP
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE WITH OVERRIDE;
EXEC sp_configure 'Ole Automation Procedures', 1;
RECONFIGURE WITH OVERRIDE;
GO

-- ============================================================================
-- 1. PROCEDIMIENTO: IMPORTACIÓN DE CUERPO TÉCNICO DESDE ARCHIVO (CSV / JSON)
-- ============================================================================
CREATE OR ALTER PROCEDURE persona.sp_IMPORTAR_CUERPO_TECNICO_CSV
    @RutaArchivo VARCHAR(500) = 'C:\Mundial2026\Data\cuerpos_tecnicos.csv'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Proceso     VARCHAR(100) = 'persona.sp_IMPORTAR_CUERPO_TECNICO_CSV';
    DECLARE @Sql         NVARCHAR(MAX);
    DECLARE @JsonRaw     NVARCHAR(MAX);
    DECLARE @Msg         NVARCHAR(4000);
    DECLARE @Total       INT = 0, @Fila INT = 1;
    DECLARE @Altas       INT = 0, @Modificados INT = 0, @Errores INT = 0;

    -- Variables de trabajo por fila
    DECLARE @NroDoc            VARCHAR(20),
            @TipoDoc           VARCHAR(10),
            @IdPaisNac         CHAR(3),
            @Nombre            VARCHAR(50),
            @Apellido          VARCHAR(50),
            @EntrenadorLabel   VARCHAR(200),
            @FechaTxt          VARCHAR(30),
            @FechaNac          DATE,
            @CodPaisSel        CHAR(3),
            @SeleccionLabel    VARCHAR(100),
            @CargoTecnico      VARCHAR(40),
            @IdSeleccion       INT,
            @Accion            CHAR(1),
            @PosEspacio        INT;

    PRINT '  INICIO IMPORTACIÓN MASIVA DE CUERPOS TÉCNICOS (ARCHIVO WIKIDATA)      ';
    PRINT '  Archivo recibido por parámetro: ' + ISNULL(@RutaArchivo, 'NULL');

    -- 0. Validación defensiva del parámetro obligatorio
    IF @RutaArchivo IS NULL OR LTRIM(RTRIM(@RutaArchivo)) = ''
    BEGIN
        SET @Msg = N'Debe indicar obligatoriamente la ruta del archivo de cuerpos técnicos (@RutaArchivo).';
        INSERT INTO auditoria.LOG_IMPORTACION (proceso_origen, nro_fila, clave_registro, mensaje_error, linea_error)
        VALUES (@Proceso, NULL, 'PARAMETRO_NULL', @Msg, ERROR_LINE());
        THROW 50010, @Msg, 1;
    END;

    -- 1. Tabla de Homologación ISO-3 (Wikidata) -> Código FIFA (Base de Datos)
    IF OBJECT_ID('tempdb..#HomologacionISO_FIFA') IS NOT NULL DROP TABLE #HomologacionISO_FIFA;
    CREATE TABLE #HomologacionISO_FIFA (
        codigo_iso  CHAR(3) PRIMARY KEY,
        codigo_fifa CHAR(3) NOT NULL
    );

    INSERT INTO #HomologacionISO_FIFA (codigo_iso, codigo_fifa)
    VALUES
        ('DEU', 'GER'), ('GBR', 'ENG'), ('NLD', 'NED'), ('PRT', 'POR'),
        ('HRV', 'CRO'), ('CHE', 'SUI'), ('URY', 'URU'), ('PRY', 'PAR'),
        ('DZA', 'ALG'), ('ZAF', 'RSA'), ('SAU', 'KSA'), ('HTI', 'HAI'),
        ('IRN', 'IRN'), ('USA', 'USA'), ('MEX', 'MEX'), ('CAN', 'CAN'),
        ('ARG', 'ARG'), ('BRA', 'BRA'), ('COL', 'COL'), ('ECU', 'ECU'),
        ('FRA', 'FRA'), ('ESP', 'ESP'), ('BEL', 'BEL'), ('AUT', 'AUT'),
        ('CZE', 'CZE'), ('BIH', 'BIH'), ('NOR', 'NOR'), ('SWE', 'SWE'),
        ('TUR', 'TUR'), ('MAR', 'MAR'), ('SEN', 'SEN'), ('EGY', 'EGY'),
        ('CIV', 'CIV'), ('TUN', 'TUN'), ('COD', 'COD'), ('CPV', 'CPV'),
        ('JPN', 'JPN'), ('KOR', 'KOR'), ('AUS', 'AUS'), ('QAT', 'QAT'),
        ('IRQ', 'IRQ'), ('UZB', 'UZB'), ('PAN', 'PAN'), ('CUW', 'CUW'),
        ('GHA', 'GHA'), ('JOR', 'JOR'), ('NZL', 'NZL'), ('ITA', 'ITA');

    -- 2. Tablas temporales de Staging y Normalización
    IF OBJECT_ID('tempdb..#RawCuerpoTecnico') IS NOT NULL DROP TABLE #RawCuerpoTecnico;
    CREATE TABLE #RawCuerpoTecnico (
        nro_doc                NVARCHAR(100),
        tipo_doc               NVARCHAR(50),
        id_nacionalidad_pais   NVARCHAR(50),
        nombre                 NVARCHAR(200),
        apellido               NVARCHAR(200),
        entrenadorLabel        NVARCHAR(200),
        fecha_nacimiento       NVARCHAR(100),
        codigo_pais_seleccion  NVARCHAR(50),
        seleccionLabel         NVARCHAR(200),
        cargo_tecnico          NVARCHAR(100)
    );

    IF OBJECT_ID('tempdb..#CuerpoTecnicoNormalizado') IS NOT NULL DROP TABLE #CuerpoTecnicoNormalizado;
    CREATE TABLE #CuerpoTecnicoNormalizado (
        nro_fila               INT NOT NULL PRIMARY KEY,
        nro_doc                VARCHAR(20),
        tipo_doc               VARCHAR(10),
        id_nacionalidad_pais   CHAR(3),
        nombre                 VARCHAR(50),
        apellido               VARCHAR(50),
        entrenadorLabel        VARCHAR(200),
        fecha_nacimiento       VARCHAR(30),
        codigo_pais_seleccion  CHAR(3),
        seleccionLabel         VARCHAR(100),
        cargo_tecnico          VARCHAR(40)
    );

    -- 3. Lectura dinámica del archivo (Soporta JSON o CSV con fin de línea Unix/Windows)
    BEGIN TRY
        IF RIGHT(LOWER(LTRIM(RTRIM(@RutaArchivo))), 5) = '.json'
        BEGIN
            SET @Sql = N'SELECT @DataOut = BulkColumn
                         FROM OPENROWSET(BULK ''' + REPLACE(@RutaArchivo, '''', '''''') + N''', SINGLE_CLOB) AS J;';
            EXEC sys.sp_executesql @Sql, N'@DataOut NVARCHAR(MAX) OUTPUT', @DataOut = @JsonRaw OUTPUT;

            IF ISJSON(@JsonRaw) = 0
                THROW 50011, 'El archivo JSON indicado no tiene una estructura JSON válida.', 1;

            IF JSON_QUERY(@JsonRaw, '$.results.bindings') IS NOT NULL
            BEGIN
                INSERT INTO #RawCuerpoTecnico (
                    nro_doc, tipo_doc, id_nacionalidad_pais, nombre, apellido,
                    entrenadorLabel, fecha_nacimiento, codigo_pais_seleccion, seleccionLabel, cargo_tecnico
                )
                SELECT
                    JSON_VALUE(B.value, '$.nro_doc.value'),
                    JSON_VALUE(B.value, '$.tipo_doc.value'),
                    JSON_VALUE(B.value, '$.id_nacionalidad_pais.value'),
                    JSON_VALUE(B.value, '$.nombre.value'),
                    JSON_VALUE(B.value, '$.apellido.value'),
                    JSON_VALUE(B.value, '$.entrenadorLabel.value'),
                    JSON_VALUE(B.value, '$.fecha_nacimiento.value'),
                    JSON_VALUE(B.value, '$.codigo_pais_seleccion.value'),
                    JSON_VALUE(B.value, '$.seleccionLabel.value'),
                    JSON_VALUE(B.value, '$.cargo_tecnico.value')
                FROM OPENJSON(@JsonRaw, '$.results.bindings') AS B;
            END
            ELSE
            BEGIN
                INSERT INTO #RawCuerpoTecnico (
                    nro_doc, tipo_doc, id_nacionalidad_pais, nombre, apellido,
                    entrenadorLabel, fecha_nacimiento, codigo_pais_seleccion, seleccionLabel, cargo_tecnico
                )
                SELECT
                    nro_doc, tipo_doc, id_nacionalidad_pais, nombre, apellido,
                    entrenadorLabel, fecha_nacimiento, codigo_pais_seleccion, seleccionLabel, cargo_tecnico
                FROM OPENJSON(@JsonRaw)
                WITH (
                    nro_doc               NVARCHAR(100) '$.nro_doc',
                    tipo_doc              NVARCHAR(50)  '$.tipo_doc',
                    id_nacionalidad_pais  NVARCHAR(50)  '$.id_nacionalidad_pais',
                    nombre                NVARCHAR(200) '$.nombre',
                    apellido              NVARCHAR(200) '$.apellido',
                    entrenadorLabel       NVARCHAR(200) '$.entrenadorLabel',
                    fecha_nacimiento      NVARCHAR(100) '$.fecha_nacimiento',
                    codigo_pais_seleccion NVARCHAR(50)  '$.codigo_pais_seleccion',
                    seleccionLabel        NVARCHAR(200) '$.seleccionLabel',
                    cargo_tecnico         NVARCHAR(100) '$.cargo_tecnico'
                );
            END;
            PRINT '--> [OK] Archivo JSON de cuerpos técnicos leído exitosamente.';
        END
        ELSE
        BEGIN
            BEGIN TRY
                SET @Sql = N'
                BULK INSERT #RawCuerpoTecnico
                FROM ''' + REPLACE(@RutaArchivo, '''', '''''') + N'''
                WITH (
                    FORMAT = ''CSV'',
                    FIELDQUOTE = ''"'',
                    FIELDTERMINATOR = '','',
                    FIRSTROW = 2,
                    CODEPAGE = ''65001'',
                    ROWTERMINATOR = ''0x0a'',
                    TABLOCK
                );';
                EXEC sys.sp_executesql @Sql;
                PRINT '--> [OK] Archivo CSV leído en formato Unix (0x0a).';
            END TRY
            BEGIN CATCH
                SET @Sql = N'
                BULK INSERT #RawCuerpoTecnico
                FROM ''' + REPLACE(@RutaArchivo, '''', '''''') + N'''
                WITH (
                    FORMAT = ''CSV'',
                    FIELDQUOTE = ''"'',
                    FIELDTERMINATOR = '','',
                    FIRSTROW = 2,
                    CODEPAGE = ''65001'',
                    ROWTERMINATOR = ''\r\n'',
                    TABLOCK
                );';
                EXEC sys.sp_executesql @Sql;
                PRINT '--> [OK] Archivo CSV leído en formato Windows (CRLF).';
            END CATCH;
        END;
    END TRY
    BEGIN CATCH
        SET @Msg = CONCAT('No se pudo leer el archivo "', @RutaArchivo, '": ', ERROR_MESSAGE());
        INSERT INTO auditoria.LOG_IMPORTACION (proceso_origen, nro_fila, clave_registro, mensaje_error, linea_error)
        VALUES (@Proceso, NULL, @RutaArchivo, @Msg, ERROR_LINE());
        THROW 50011, @Msg, 1;
    END CATCH;

    -- 4. Depuración, deduplicación por documento y homologación de códigos ISO -> FIFA
    ;WITH Limpio AS (
        SELECT
            LEFT(LTRIM(RTRIM(REPLACE(R.nro_doc, CHAR(13), ''))), 20) AS nro_doc,
            UPPER(LEFT(ISNULL(NULLIF(LTRIM(RTRIM(REPLACE(R.tipo_doc, CHAR(13), ''))), ''), 'PASAPORTE'), 10)) AS tipo_doc,
            UPPER(LEFT(LTRIM(RTRIM(REPLACE(R.id_nacionalidad_pais, CHAR(13), ''))), 3)) AS iso_nac,
            LTRIM(RTRIM(REPLACE(R.nombre, CHAR(13), ''))) AS nombre_raw,
            LTRIM(RTRIM(REPLACE(R.apellido, CHAR(13), ''))) AS apellido_raw,
            LTRIM(RTRIM(REPLACE(R.entrenadorLabel, CHAR(13), ''))) AS entrenadorLabel,
            LTRIM(RTRIM(REPLACE(R.fecha_nacimiento, CHAR(13), ''))) AS fecha_nacimiento,
            UPPER(LEFT(LTRIM(RTRIM(REPLACE(R.codigo_pais_seleccion, CHAR(13), ''))), 3)) AS iso_sel,
            LEFT(LTRIM(RTRIM(REPLACE(R.seleccionLabel, CHAR(13), ''))), 100) AS seleccionLabel,
            LEFT(ISNULL(NULLIF(LTRIM(RTRIM(REPLACE(R.cargo_tecnico, CHAR(13), ''))), ''), 'Director Técnico'), 40) AS cargo_tecnico
        FROM #RawCuerpoTecnico R
        WHERE R.nro_doc IS NOT NULL AND LTRIM(RTRIM(R.nro_doc)) <> ''
    ),
    Homologado AS (
        SELECT
            L.nro_doc,
            L.tipo_doc,
            ISNULL(H_Nac.codigo_fifa, L.iso_nac) AS id_nacionalidad_pais,
            L.nombre_raw,
            L.apellido_raw,
            L.entrenadorLabel,
            L.fecha_nacimiento,
            CASE
                WHEN L.seleccionLabel LIKE '%Inglaterra%' OR L.seleccionLabel LIKE '%England%' THEN 'ENG'
                WHEN L.seleccionLabel LIKE '%Escocia%'    OR L.seleccionLabel LIKE '%Scotland%' THEN 'SCO'
                ELSE ISNULL(H_Sel.codigo_fifa, L.iso_sel)
            END AS codigo_pais_seleccion,
            L.seleccionLabel,
            L.cargo_tecnico,
            ROW_NUMBER() OVER (
                PARTITION BY L.nro_doc, L.tipo_doc
                ORDER BY
                    CASE WHEN EXISTS (
                        SELECT 1 FROM torneo.SELECCION S
                        WHERE S.id_pais = ISNULL(H_Sel.codigo_fifa, L.iso_sel)
                    ) THEN 0 ELSE 1 END,
                    L.seleccionLabel
            ) AS rn
        FROM Limpio L
        LEFT JOIN #HomologacionISO_FIFA H_Nac ON H_Nac.codigo_iso = L.iso_nac
        LEFT JOIN #HomologacionISO_FIFA H_Sel ON H_Sel.codigo_iso = L.iso_sel
    )
    INSERT INTO #CuerpoTecnicoNormalizado (
        nro_fila, nro_doc, tipo_doc, id_nacionalidad_pais, nombre, apellido,
        entrenadorLabel, fecha_nacimiento, codigo_pais_seleccion, seleccionLabel, cargo_tecnico
    )
    SELECT
        ROW_NUMBER() OVER (ORDER BY codigo_pais_seleccion, nro_doc),
        nro_doc,
        tipo_doc,
        id_nacionalidad_pais,
        LEFT(nombre_raw, 50),
        LEFT(apellido_raw, 50),
        entrenadorLabel,
        fecha_nacimiento,
        codigo_pais_seleccion,
        seleccionLabel,
        cargo_tecnico
    FROM Homologado
    WHERE rn = 1;

    SELECT @Total = COUNT(*) FROM #CuerpoTecnicoNormalizado;

    IF @Total = 0
    BEGIN
        SET @Msg = N'El archivo no contiene registros de cuerpo técnico para importar.';
        INSERT INTO auditoria.LOG_IMPORTACION (proceso_origen, nro_fila, clave_registro, mensaje_error, linea_error)
        VALUES (@Proceso, NULL, @RutaArchivo, @Msg, ERROR_LINE());
        THROW 50012, @Msg, 1;
    END;

    -- 5. Procesamiento fila por fila con Upsert invocando persona.sp_CUERPO_TECNICO_ABM (Entrega 5)
    WHILE @Fila <= @Total
    BEGIN
        SELECT
            @NroDoc          = nro_doc,
            @TipoDoc         = tipo_doc,
            @IdPaisNac       = id_nacionalidad_pais,
            @Nombre          = nombre,
            @Apellido        = apellido,
            @EntrenadorLabel = entrenadorLabel,
            @FechaTxt        = fecha_nacimiento,
            @CodPaisSel      = codigo_pais_seleccion,
            @SeleccionLabel  = seleccionLabel,
            @CargoTecnico    = cargo_tecnico
        FROM #CuerpoTecnicoNormalizado
        WHERE nro_fila = @Fila;

        BEGIN TRY
            SET @IdSeleccion = NULL;
            SET @FechaNac    = TRY_CONVERT(DATE, LEFT(@FechaTxt, 10), 23);

            -- Si Wikidata no trajo nombre o apellido separado, lo desglosamos desde entrenadorLabel
            IF (@Nombre IS NULL OR @Nombre = '' OR @Apellido IS NULL OR @Apellido = '')
               AND @EntrenadorLabel IS NOT NULL AND @EntrenadorLabel <> ''
            BEGIN
                SET @PosEspacio = CHARINDEX(' ', @EntrenadorLabel);
                IF @PosEspacio > 0
                BEGIN
                    IF @Nombre IS NULL OR @Nombre = ''
                        SET @Nombre = LEFT(LEFT(@EntrenadorLabel, @PosEspacio - 1), 50);
                    IF @Apellido IS NULL OR @Apellido = ''
                        SET @Apellido = LEFT(SUBSTRING(@EntrenadorLabel, @PosEspacio + 1, 200), 50);
                END
                ELSE
                BEGIN
                    SET @Nombre   = ISNULL(NULLIF(@Nombre, ''), LEFT(@EntrenadorLabel, 50));
                    SET @Apellido = ISNULL(NULLIF(@Apellido, ''), LEFT(@EntrenadorLabel, 50));
                END;
            END;

            -- Si la nacionalidad del DT no existe en geografia.PAIS (ej. DT italiano como Ancelotti y 'ITA' no está cargado),
            -- usamos como fallback el código de país de la selección que dirige (que sí está en geografia.PAIS)
            IF @IdPaisNac IS NULL OR LEN(LTRIM(RTRIM(@IdPaisNac))) <> 3
               OR NOT EXISTS (SELECT 1 FROM geografia.PAIS WHERE id_pais = @IdPaisNac)
            BEGIN
                SET @IdPaisNac = @CodPaisSel;
            END;

            -- Búsqueda de id_seleccion en torneo.SELECCION
            SELECT TOP 1 @IdSeleccion = S.id_seleccion
            FROM torneo.SELECCION S
            WHERE S.id_pais = @CodPaisSel;

            -- Lógica de Upsert: 'M' si ya existe en persona.CUERPO_TECNICO, 'A' si es nuevo
            IF EXISTS (
                SELECT 1 FROM persona.CUERPO_TECNICO
                WHERE nro_doc = @NroDoc AND tipo_doc = @TipoDoc
            )
                SET @Accion = 'M';
            ELSE
                SET @Accion = 'A';

            -- Invocación al SP de Entrega 5 (realiza todas las validaciones y el control transaccional)
            EXEC persona.sp_CUERPO_TECNICO_ABM
                @Accion               = @Accion,
                @nro_doc              = @NroDoc,
                @tipo_doc             = @TipoDoc,
                @id_nacionalidad_pais = @IdPaisNac,
                @nombre               = @Nombre,
                @apellido             = @Apellido,
                @fecha_nacimiento     = @FechaNac,
                @id_seleccion         = @IdSeleccion,
                @cargo_tecnico        = @CargoTecnico;

            IF @Accion = 'A'
                SET @Altas += 1;
            ELSE
                SET @Modificados += 1;

        END TRY
        BEGIN CATCH
            SET @Errores += 1;

            INSERT INTO auditoria.LOG_IMPORTACION (
                proceso_origen, nro_fila, clave_registro, mensaje_error, linea_error
            )
            VALUES (
                @Proceso,
                @Fila,
                LEFT(CONCAT(ISNULL(@NroDoc, 'SIN_DOC'), ' - ', ISNULL(@EntrenadorLabel, ''), ' (', ISNULL(@CodPaisSel, '???'), ')'), 100),
                ERROR_MESSAGE(),
                ERROR_LINE()
            );
        END CATCH;

        SET @Fila += 1;
    END;

    -- 6. Resumen de Ejecución
    PRINT CONCAT('--> Cuerpos Técnicos leídos: ', @Total,
                 ' | Altas: ', @Altas,
                 ' | Modificaciones (Upsert): ', @Modificados,
                 ' | Rechazados (Log Auditoría): ', @Errores);

    IF @Errores > 0
        PRINT '--> Se registraron rechazos parciales en auditoria.LOG_IMPORTACION (por ej. selecciones no clasificadas al Mundial).';

    IF @Errores = @Total
    BEGIN
        SET @Msg = N'No se pudo importar ningún registro válido del archivo. Revise auditoria.LOG_IMPORTACION.';
        THROW 50014, @Msg, 1;
    END;

    PRINT '  FIN DE IMPORTACIÓN DE CUERPOS TÉCNICOS (ARCHIVO)                      ';
END;
GO


-- ============================================================================
-- 2. PROCEDIMIENTO: CONSUMO DIRECTO DE API REST DE WIKIDATA (SPARQL -> JSON)
-- ============================================================================
CREATE OR ALTER PROCEDURE persona.sp_IMPORTAR_CUERPO_TECNICO_API
    @RutaArchivoCSV      VARCHAR(500) = NULL,
    @SoloSeleccionesEnBD BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Proceso      VARCHAR(100) = 'persona.sp_IMPORTAR_CUERPO_TECNICO_API';
    DECLARE @Object       INT          = NULL;
    DECLARE @Status       INT;
    DECLARE @HResult      INT;
    DECLARE @UrlAPI       VARCHAR(8000);
    DECLARE @SparqlQuery  VARCHAR(4000);
    DECLARE @SparqlValues VARCHAR(1000) = '';
    DECLARE @Msg          NVARCHAR(4000);
    DECLARE @ErrSrc       VARCHAR(255);
    DECLARE @ErrDesc      VARCHAR(2000);
    DECLARE @Origen       VARCHAR(50)  = 'API_REST_WIKIDATA';

    DECLARE @ResponseTable TABLE (JsonText NVARCHAR(MAX));
    DECLARE @JsonResponse  NVARCHAR(MAX);

    -- Tabla staging donde se vuelcan los resultados de la API
    DECLARE @ApiStaging TABLE (
        nro_fila              INT IDENTITY(1,1) PRIMARY KEY,
        nro_doc               VARCHAR(20),
        id_nacionalidad_pais  CHAR(3),
        entrenadorLabel       VARCHAR(200),
        fecha_nacimiento      VARCHAR(30),
        codigo_pais_seleccion CHAR(3),
        seleccionLabel        VARCHAR(100),
        cargo_tecnico         VARCHAR(40)
    );

    PRINT '  INICIO CONSUMO DE API REST WIKIDATA PARA CUERPOS TÉCNICOS             ';

    -- 1. Intentar consultar en vivo la API REST de Wikidata (https://query.wikidata.org/sparql)
    BEGIN TRY
        IF @SoloSeleccionesEnBD = 1 AND EXISTS (SELECT 1 FROM torneo.SELECCION)
        BEGIN
            SELECT @SparqlValues = STRING_AGG(CAST('"' + V.iso_code + '"' AS VARCHAR(MAX)), ' ')
            FROM (
                SELECT DISTINCT
                    CASE S.id_pais
                        WHEN 'GER' THEN 'DEU' WHEN 'ENG' THEN 'GBR' WHEN 'SCO' THEN 'GBR'
                        WHEN 'NED' THEN 'NLD' WHEN 'POR' THEN 'PRT' WHEN 'CRO' THEN 'HRV'
                        WHEN 'SUI' THEN 'CHE' WHEN 'URU' THEN 'URY' WHEN 'PAR' THEN 'PRY'
                        WHEN 'ALG' THEN 'DZA' WHEN 'RSA' THEN 'ZAF' WHEN 'KSA' THEN 'SAU'
                        WHEN 'HAI' THEN 'HTI' ELSE S.id_pais
                    END AS iso_code
                FROM torneo.SELECCION S
            ) V;
        END;

        IF @SparqlValues IS NULL OR @SparqlValues = ''
            SET @SparqlValues = '"ARG" "BRA" "USA" "MEX" "CAN" "FRA" "ESP" "DEU" "GBR" "URY" "COL" "JPN" "MAR"';

        SET @SparqlQuery =
            'SELECT ?nro_doc ?id_nacionalidad_pais ?eLabel ?fecha_nacimiento ?codigo_pais_seleccion ?sLabel ?cargo ' +
            'WHERE { { ' +
            'SELECT ?e ' +
            '(REPLACE(STR(?e),"http://www.wikidata.org/entity/Q","CT") AS ?nro_doc) ' +
            '(SAMPLE(?in) AS ?id_nacionalidad_pais) ' +
            '(SAMPLE(SUBSTR(STR(?fn),1,10)) AS ?fecha_nacimiento) ' +
            '(SAMPLE(?is) AS ?codigo_pais_seleccion) ' +
            '(SAMPLE(?s) AS ?s) ' +
            '(SAMPLE(?c) AS ?cargo) ' +
            'WHERE { ' +
            'hint:Query hint:optimizer "None" . ' +
            'VALUES ?is { ' + @SparqlValues + ' } ' +
            '?ps wdt:P298 ?is . ' +
            '?s wdt:P31 wd:Q6979593 . ' +
            '?s wdt:P17 ?ps . ' +
            'FILTER NOT EXISTS { ?s wdt:P31 wd:Q23847779 } ' +
            'FILTER NOT EXISTS { ?s wdt:P2094 wd:Q6581072 } ' +
            '{ ?s wdt:P286 ?e . BIND("Director Técnico" AS ?c) } ' +
            'UNION ' +
            '{ ?st ps:P6087 ?s . ?e p:P6087 ?st . FILTER NOT EXISTS { ?st pq:P582 ?fin } FILTER NOT EXISTS { ?s wdt:P286 ?e } BIND("Asistente Técnico" AS ?c) } ' +
            'OPTIONAL { ?e wdt:P569 ?fn } ' +
            'OPTIONAL { ?e wdt:P27 ?pn . ?pn wdt:P298 ?in } ' +
            '} GROUP BY ?e } ' +
            'SERVICE wikibase:label { bd:serviceParam wikibase:language "es,en". } }';

        SET @UrlAPI = 'https://query.wikidata.org/sparql';

        PRINT '  Endpoint API: https://query.wikidata.org/sparql (POST - Formato: SPARQL JSON)';

        EXEC @HResult = sp_OACreate 'MSXML2.ServerXMLHTTP.6.0', @Object OUT;
        IF @HResult <> 0
            THROW 50020, 'No se pudo inicializar MSXML2.ServerXMLHTTP.6.0.', 1;

        -- Timeouts en ms: resolve (15s), connect (15s), send (30s), receive (90s)
        EXEC sp_OAMethod @Object, 'setTimeouts', NULL, 15000, 15000, 30000, 90000;

        EXEC @HResult = sp_OAMethod @Object, 'open', NULL, 'POST', @UrlAPI, 'false';
        IF @HResult <> 0
            THROW 50021, 'Error al abrir conexión HTTP con Wikidata.', 1;

        EXEC sp_OAMethod @Object, 'setRequestHeader', NULL, 'Content-Type', 'application/sparql-query; charset=utf-8';
        EXEC sp_OAMethod @Object, 'setRequestHeader', NULL, 'Accept', 'application/sparql-results+json';
        EXEC sp_OAMethod @Object, 'setRequestHeader', NULL, 'User-Agent', 'UNLaM-Mundial2026-Grupo10/1.0 (https://unlam.edu.ar)';

        EXEC @HResult = sp_OAMethod @Object, 'send', NULL, @SparqlQuery;
        IF @HResult <> 0
        BEGIN
            EXEC sp_OAGetErrorInfo @Object, @ErrSrc OUT, @ErrDesc OUT;
            SET @Msg = CONCAT('Error al enviar solicitud HTTP a Wikidata (', ISNULL(@ErrSrc, 'OLE'), '): ', ISNULL(@ErrDesc, 'Sin detalle'));
            THROW 50022, @Msg, 1;
        END;

        EXEC sp_OAGetProperty @Object, 'status', @Status OUT;
        IF @Status <> 200
        BEGIN
            SET @Msg = CONCAT('La API de Wikidata devolvió HTTP ', ISNULL(@Status, 0));
            THROW 50023, @Msg, 1;
        END;

        INSERT INTO @ResponseTable (JsonText)
        EXEC sp_OAGetProperty @Object, 'responseText';

        EXEC sp_OADestroy @Object;
        SET @Object = NULL;

        SELECT TOP 1 @JsonResponse = JsonText FROM @ResponseTable;

        IF @JsonResponse IS NULL OR ISJSON(@JsonResponse) = 0
            THROW 50024, 'La respuesta JSON de la API fue truncada o inválida.', 1;

        INSERT INTO @ApiStaging (nro_doc, id_nacionalidad_pais, entrenadorLabel, fecha_nacimiento, codigo_pais_seleccion, seleccionLabel, cargo_tecnico)
        SELECT
            LEFT(JSON_VALUE(B.value, '$.nro_doc.value'), 20),
            UPPER(LEFT(JSON_VALUE(B.value, '$.id_nacionalidad_pais.value'), 3)),
            JSON_VALUE(B.value, '$.eLabel.value'),
            JSON_VALUE(B.value, '$.fecha_nacimiento.value'),
            UPPER(LEFT(JSON_VALUE(B.value, '$.codigo_pais_seleccion.value'), 3)),
            LEFT(JSON_VALUE(B.value, '$.sLabel.value'), 100),
            ISNULL(LEFT(JSON_VALUE(B.value, '$.cargo.value'), 40), 'Director Técnico')
        FROM OPENJSON(@JsonResponse, '$.results.bindings') AS B;

        PRINT '--> [OK] Datos descargados en vivo desde la API REST de Wikidata.';
    END TRY
    BEGIN CATCH
        IF @Object IS NOT NULL
        BEGIN
            EXEC sp_OADestroy @Object;
            SET @Object = NULL;
        END;

        SET @Msg = CONCAT('Error al descargar datos desde la API REST de Wikidata: ', ERROR_MESSAGE());
        INSERT INTO auditoria.LOG_IMPORTACION (proceso_origen, nro_fila, clave_registro, mensaje_error, linea_error)
        VALUES (@Proceso, NULL, 'API_HTTP_ERROR', @Msg, ERROR_LINE());
        THROW 50025, @Msg, 1;
    END CATCH;

    IF NOT EXISTS (SELECT 1 FROM @ApiStaging)
    BEGIN
        SET @Msg = N'La API REST de Wikidata no devolvió registros de cuerpo técnico para importar.';
        INSERT INTO auditoria.LOG_IMPORTACION (proceso_origen, nro_fila, clave_registro, mensaje_error, linea_error)
        VALUES (@Proceso, NULL, 'API_SIN_DATOS', @Msg, ERROR_LINE());
        THROW 50026, @Msg, 1;
    END;

    -- 2. Procesar @ApiStaging fila por fila invocando persona.sp_CUERPO_TECNICO_ABM
    DECLARE @FilaAPI INT = 1, @TotalAPI INT = (SELECT COUNT(*) FROM @ApiStaging);
    DECLARE @AltasAPI INT = 0, @ModAPI INT = 0, @ErrAPI INT = 0;
    DECLARE @DocAPI VARCHAR(20), @PaisNacAPI CHAR(3), @LabelAPI VARCHAR(200),
            @FechaTxtAPI VARCHAR(30), @FechaAPI DATE, @PaisSelAPI CHAR(3),
            @CargoAPI VARCHAR(40), @NombreAPI VARCHAR(50), @ApellidoAPI VARCHAR(50),
            @IdSelAPI INT, @AccionAPI CHAR(1), @PosAPI INT;

    WHILE @FilaAPI <= @TotalAPI
    BEGIN
        SELECT
            @DocAPI      = nro_doc,
            @PaisNacAPI  = CASE id_nacionalidad_pais
                               WHEN 'DEU' THEN 'GER' WHEN 'GBR' THEN 'ENG' WHEN 'NLD' THEN 'NED'
                               WHEN 'PRT' THEN 'POR' WHEN 'HRV' THEN 'CRO' WHEN 'CHE' THEN 'SUI'
                               WHEN 'URY' THEN 'URU' WHEN 'PRY' THEN 'PAR' WHEN 'DZA' THEN 'ALG'
                               WHEN 'ZAF' THEN 'RSA' WHEN 'SAU' THEN 'KSA' WHEN 'HTI' THEN 'HAI'
                               ELSE id_nacionalidad_pais END,
            @LabelAPI    = entrenadorLabel,
            @FechaTxtAPI = fecha_nacimiento,
            @PaisSelAPI  = CASE
                               WHEN seleccionLabel LIKE '%Inglaterra%' OR seleccionLabel LIKE '%England%' THEN 'ENG'
                               WHEN seleccionLabel LIKE '%Escocia%'    OR seleccionLabel LIKE '%Scotland%' THEN 'SCO'
                               ELSE CASE codigo_pais_seleccion
                                   WHEN 'DEU' THEN 'GER' WHEN 'GBR' THEN 'ENG' WHEN 'NLD' THEN 'NED'
                                   WHEN 'PRT' THEN 'POR' WHEN 'HRV' THEN 'CRO' WHEN 'CHE' THEN 'SUI'
                                   WHEN 'URY' THEN 'URU' WHEN 'PRY' THEN 'PAR' WHEN 'DZA' THEN 'ALG'
                                   WHEN 'ZAF' THEN 'RSA' WHEN 'SAU' THEN 'KSA' WHEN 'HTI' THEN 'HAI'
                                   ELSE codigo_pais_seleccion END
                           END,
            @CargoAPI    = ISNULL(cargo_tecnico, 'Director Técnico')
        FROM @ApiStaging
        WHERE nro_fila = @FilaAPI;

        BEGIN TRY
            SET @FechaAPI = TRY_CONVERT(DATE, LEFT(@FechaTxtAPI, 10), 23);
            SET @PosAPI   = CHARINDEX(' ', ISNULL(@LabelAPI, ''));

            IF @PosAPI > 0
            BEGIN
                SET @NombreAPI   = LEFT(LEFT(@LabelAPI, @PosAPI - 1), 50);
                SET @ApellidoAPI = LEFT(SUBSTRING(@LabelAPI, @PosAPI + 1, 200), 50);
            END
            ELSE
            BEGIN
                SET @NombreAPI   = LEFT(@LabelAPI, 50);
                SET @ApellidoAPI = LEFT(@LabelAPI, 50);
            END;

            -- Si el país de nacionalidad del DT no está en geografia.PAIS (ej. 'ITA' o 'DEN'),
            -- usamos el país de la selección que dirige como fallback para respetar FK_PERSONA_PAIS
            IF @PaisNacAPI IS NULL OR LEN(@PaisNacAPI) <> 3
               OR NOT EXISTS (SELECT 1 FROM geografia.PAIS WHERE id_pais = @PaisNacAPI)
            BEGIN
                SET @PaisNacAPI = @PaisSelAPI;
            END;

            SET @IdSelAPI = NULL;
            SELECT TOP 1 @IdSelAPI = id_seleccion FROM torneo.SELECCION WHERE id_pais = @PaisSelAPI;

            IF EXISTS (SELECT 1 FROM persona.CUERPO_TECNICO WHERE nro_doc = @DocAPI AND tipo_doc = 'PASAPORTE')
                SET @AccionAPI = 'M';
            ELSE
                SET @AccionAPI = 'A';

            EXEC persona.sp_CUERPO_TECNICO_ABM
                @Accion               = @AccionAPI,
                @nro_doc              = @DocAPI,
                @tipo_doc             = 'PASAPORTE',
                @id_nacionalidad_pais = @PaisNacAPI,
                @nombre               = @NombreAPI,
                @apellido             = @ApellidoAPI,
                @fecha_nacimiento     = @FechaAPI,
                @id_seleccion         = @IdSelAPI,
                @cargo_tecnico        = @CargoAPI;

            IF @AccionAPI = 'A' SET @AltasAPI += 1; ELSE SET @ModAPI += 1;
        END TRY
        BEGIN CATCH
            SET @ErrAPI += 1;
            INSERT INTO auditoria.LOG_IMPORTACION (proceso_origen, nro_fila, clave_registro, mensaje_error, linea_error)
            VALUES (@Proceso, @FilaAPI, LEFT(CONCAT(@DocAPI, ' - ', @LabelAPI, ' (', @PaisSelAPI, ')'), 100), ERROR_MESSAGE(), ERROR_LINE());
        END CATCH;

        SET @FilaAPI += 1;
    END;

    PRINT CONCAT('--> Origen: ', @Origen,
                 ' | Leídos: ', @TotalAPI,
                 ' | Altas: ', @AltasAPI,
                 ' | Modificados (Upsert): ', @ModAPI,
                 ' | Con error (Auditoría): ', @ErrAPI);

    -- 3. Carga complementaria desde CSV (asistentes técnicos / resto del cuerpo técnico)
    IF @RutaArchivoCSV IS NOT NULL AND LTRIM(RTRIM(@RutaArchivoCSV)) <> ''
    BEGIN
        PRINT '--> Iniciando carga complementaria de asistentes desde CSV...';
        EXEC persona.sp_IMPORTAR_CUERPO_TECNICO_CSV @RutaArchivo = @RutaArchivoCSV;
    END;
END;
GO
