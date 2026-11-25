/*
================================================================================
UNLaM - Universidad Nacional de La Matanza
Departamento de Ingeniería e Investigaciones Tecnológicas
Materia: Base de Datos Aplicada (Comisión 5600)
Entrega 6 - Importación de Cuerpos Técnicos (API REST Wikidata)
2026 - 2C
Grupo 10

Integrantes:
- Monasterio Erik: MonasteryEr
- Arena Ariel Ignacio: arielarena
- Castillo Gabriela Florencia: ItsFlorencia
- Maita Pitado Jose Gregorio: maita07

Archivo: 04_7_IMPORT_CUERPO_TECNICO.sql
Descripcion:
- Módulo de importación masiva de Cuerpos Técnicos de las Selecciones:
  persona.sp_IMPORTAR_CUERPO_TECNICO_API: Consumo directo de la API REST SPARQL
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
-- 1. PROCEDIMIENTO: CONSUMO DIRECTO DE API REST DE WIKIDATA (SPARQL -> JSON)
-- ============================================================================
CREATE OR ALTER PROCEDURE persona.sp_IMPORTAR_CUERPO_TECNICO_API
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
            '?s wdt:P31 wd:Q135408445 . ' +
            '{ ?s wdt:P1532 ?ps } UNION { ?s wdt:P17 ?ps } UNION { ?s wdt:P1532 ?ps2 . ?ps wdt:P150 ?ps2 . FILTER NOT EXISTS { ?ps2 wdt:P298 ?anyIso } } ' +
            'FILTER NOT EXISTS { ?s wdt:P31 wd:Q23847779 } ' +
            '{ ?s p:P286 ?st2 . ?st2 ps:P286 ?e . FILTER(?e != wd:Q50081643) OPTIONAL { ?st2 pq:P580 ?i2 } OPTIONAL { ?st2 pq:P582 ?f2 } FILTER(!BOUND(?i2) || ?i2 <= "2026-07-19"^^xsd:dateTime) FILTER(!BOUND(?f2) || ?f2 >= "2026-06-11"^^xsd:dateTime) BIND("Director Técnico" AS ?c) } ' +
            'UNION ' +
            '{ ?st ps:P6087 ?s . ?e p:P6087 ?st . OPTIONAL { ?st pq:P580 ?i1 } OPTIONAL { ?st pq:P582 ?f1 } FILTER(!BOUND(?i1) || ?i1 <= "2026-07-19"^^xsd:dateTime) FILTER(!BOUND(?f1) || ?f1 >= "2026-06-11"^^xsd:dateTime) FILTER NOT EXISTS { ?s p:P286 [ ps:P286 ?e ] } BIND("Asistente Técnico" AS ?c) } ' +
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
END;
GO

