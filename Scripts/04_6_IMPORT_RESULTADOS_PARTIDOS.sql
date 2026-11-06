/*
================================================================================
UNLaM - Base de Datos Aplicada (Comisión 5600)
Entrega 6 - Script 04_6: Importación masiva de Resultados y Goles
2026 - 2C
Grupo 10

Integrantes:
- Monasterio Erik: MonasteryEr
- Arena Ariel Ignacio: arielarena
- Castillo Gabriela Florencia: ItsFlorencia
- Maita Pitado Jose Gregorio: maita07

Archivo: 04_6_IMPORT_RESULTADOS_PARTIDOS.sql
Descripcion: Módulo unificado de importación, actualización de resultados y goles:
- Rutas recibidas obligatoriamente por parámetro (sin valores fijos ni defaults).
- Carga masiva de resultados finales de los 104 encuentros desde matches_detailed.csv.
- Carga e importación masiva de eventos de gol desde archivo.json (OPENJSON).
- Homologación relacional con torneo.PARTIDO y torneo.CONVOCATORIA resolviendo collations.
- Auditoría centralizada de errores en auditoria.LOG_IMPORTACION.
================================================================================
*/
USE DB_Mundial2026_Grupo10;
GO

CREATE OR ALTER PROCEDURE torneo.sp_IMPORTAR_PARTIDOS_Y_GOLES_CSV
    @RutaMatches VARCHAR(500), -- Parámetro obligatorio sin default
    @RutaGoles   VARCHAR(500)  -- Parámetro obligatorio sin default
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NombreProc VARCHAR(100) = 'torneo.sp_IMPORTAR_PARTIDOS_Y_GOLES_CSV';
    DECLARE @ErrLinea   INT;
    DECLARE @ErrMensaje NVARCHAR(4000);

    PRINT '  INICIO IMPORTACIÓN OFICIAL DE PARTIDOS Y GOLES                        ';
    PRINT '  Ruta Partidos (CSV): ' + ISNULL(@RutaMatches, 'NULL');
    PRINT '  Ruta Goles (JSON):   ' + ISNULL(@RutaGoles, 'NULL');

    -- 0. VALIDACIÓN DEFENSIVA DE PARÁMETROS DE ENTRADA
    IF @RutaMatches IS NULL OR LTRIM(RTRIM(@RutaMatches)) = ''
    BEGIN
        SET @ErrMensaje = 'Debe especificar obligatoriamente la ruta del archivo CSV de partidos (@RutaMatches).';
        EXEC auditoria.sp_REGISTRAR_ERROR_IMPORTACION
            @proceso_origen = @NombreProc,
            @clave_registro = 'PARAMETRO_NULL',
            @mensaje_error  = @ErrMensaje,
            @linea_error    = 1;
        THROW 50001, @ErrMensaje, 1;
    END;

    IF @RutaGoles IS NULL OR LTRIM(RTRIM(@RutaGoles)) = ''
    BEGIN
        SET @ErrMensaje = 'Debe especificar obligatoriamente la ruta del archivo JSON de goles (@RutaGoles).';
        EXEC auditoria.sp_REGISTRAR_ERROR_IMPORTACION
            @proceso_origen = @NombreProc,
            @clave_registro = 'PARAMETRO_NULL',
            @mensaje_error  = @ErrMensaje,
            @linea_error    = 2;
        THROW 50002, @ErrMensaje, 1;
    END;

    -- 1. TABLA TEMPORAL DE STAGING PARA PARTIDOS (CSV)
    IF OBJECT_ID('tempdb..#StagingMatches') IS NOT NULL DROP TABLE #StagingMatches;
    CREATE TABLE #StagingMatches (
        match_id_raw             VARCHAR(50),
        date_raw                 VARCHAR(50),
        kickoff_time_utc_raw     VARCHAR(50),
        stage_name_raw           VARCHAR(100),
        stadium_name_raw         VARCHAR(150),
        city_raw                 VARCHAR(100),
        country_raw              VARCHAR(100),
        home_team_name_raw       VARCHAR(100),
        home_fifa_code_raw       VARCHAR(10),
        away_team_name_raw       VARCHAR(100),
        away_fifa_code_raw       VARCHAR(10),
        home_score_raw           VARCHAR(50),
        away_score_raw           VARCHAR(50),
        home_penalty_score_raw   VARCHAR(50),
        away_penalty_score_raw   VARCHAR(50),
        status_raw               VARCHAR(50),
        result_type_raw          VARCHAR(50),
        home_xg_raw              VARCHAR(50),
        away_xg_raw              VARCHAR(50),
        home_goalkeeper_raw      VARCHAR(100),
        away_goalkeeper_raw      VARCHAR(100),
        player_of_the_match_raw  VARCHAR(100),
        referee_name_raw         VARCHAR(100)
    );

    -- 2. CARGA DEL CSV DE PARTIDOS (BULK INSERT DINÁMICO)
    BEGIN TRY
        DECLARE @SQLMatches NVARCHAR(MAX) = N'
        BULK INSERT #StagingMatches
        FROM ''' + REPLACE(@RutaMatches, '''', '''''') + N'''
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = '','',
            ROWTERMINATOR = ''0x0a'',
            CODEPAGE = ''65001'',
            TABLOCK
        );';
        EXEC sys.sp_executesql @SQLMatches;
        PRINT '--> [OK] matches_detailed.csv leído en Staging (formato \n).';
    END TRY
    BEGIN CATCH
        BEGIN TRY
            SET @SQLMatches = REPLACE(@SQLMatches, '''0x0a''', '''\r\n''');
            EXEC sys.sp_executesql @SQLMatches;
            PRINT '--> [OK] matches_detailed.csv leído en Staging (modo \r\n).';
        END TRY
        BEGIN CATCH
            SET @ErrLinea   = ERROR_LINE();
            SET @ErrMensaje = 'Fallo en lectura de matches_detailed.csv en ' + @RutaMatches + ': ' + ERROR_MESSAGE();
            EXEC auditoria.sp_REGISTRAR_ERROR_IMPORTACION
                @proceso_origen = @NombreProc,
                @clave_registro = @RutaMatches,
                @mensaje_error  = @ErrMensaje,
                @linea_error    = @ErrLinea;
            PRINT '--> ERROR REGISTRADO EN AUDITORÍA: ' + @ErrMensaje;
            THROW 50003, @ErrMensaje, 1;
        END CATCH;
    END CATCH;

    -- 3. ACTUALIZACIÓN MASIVA DE RESULTADOS EN torneo.PARTIDO
    BEGIN TRANSACTION;
    BEGIN TRY
        UPDATE P
        SET
            P.goles_local        = ISNULL(TRY_CAST(LTRIM(RTRIM(SM.home_score_raw)) AS INT), 0),
            P.goles_visitante    = ISNULL(TRY_CAST(LTRIM(RTRIM(SM.away_score_raw)) AS INT), 0),
            P.penales_local      = TRY_CAST(NULLIF(LTRIM(RTRIM(SM.home_penalty_score_raw)), '') AS INT),
            P.penales_visitante  = TRY_CAST(NULLIF(LTRIM(RTRIM(SM.away_penalty_score_raw)), '') AS INT),
            P.id_ganador_penales = CASE
                WHEN TRY_CAST(NULLIF(LTRIM(RTRIM(SM.home_penalty_score_raw)), '') AS INT) > TRY_CAST(NULLIF(LTRIM(RTRIM(SM.away_penalty_score_raw)), '') AS INT)
                    THEN P.id_seleccion_local
                WHEN TRY_CAST(NULLIF(LTRIM(RTRIM(SM.away_penalty_score_raw)), '') AS INT) > TRY_CAST(NULLIF(LTRIM(RTRIM(SM.home_penalty_score_raw)), '') AS INT)
                    THEN P.id_seleccion_visitante
                ELSE NULL
            END
        FROM torneo.PARTIDO P
        INNER JOIN torneo.SELECCION SL ON P.id_seleccion_local = SL.id_seleccion
        INNER JOIN torneo.SELECCION SV ON P.id_seleccion_visitante = SV.id_seleccion
        INNER JOIN #StagingMatches SM  ON SL.id_pais = LTRIM(RTRIM(SM.home_fifa_code_raw))
                                      AND SV.id_pais = LTRIM(RTRIM(SM.away_fifa_code_raw));

        DECLARE @PartidosActualizados INT = @@ROWCOUNT;
        PRINT '--> [OK] Partidos actualizados con resultado oficial: ' + CAST(@PartidosActualizados AS VARCHAR(10));
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @ErrLinea   = ERROR_LINE();
        SET @ErrMensaje = 'Error al actualizar resultados en torneo.PARTIDO: ' + ERROR_MESSAGE();
        EXEC auditoria.sp_REGISTRAR_ERROR_IMPORTACION
            @proceso_origen = @NombreProc,
            @clave_registro = 'torneo.PARTIDO',
            @mensaje_error  = @ErrMensaje,
            @linea_error    = @ErrLinea;
        PRINT '--> ERROR REGISTRADO EN AUDITORÍA: ' + @ErrMensaje;
        THROW 50004, @ErrMensaje, 1;
    END CATCH;

    -- 4. CARGA E IMPORTACIÓN MASIVA DE GOLES DESDE archivo.json
    DECLARE @JsonData NVARCHAR(MAX);
    DECLARE @SQLJson  NVARCHAR(MAX);

    BEGIN TRY
        SET @SQLJson = N'SELECT @DataOut = BulkColumn
                        FROM OPENROWSET(BULK ''' + REPLACE(@RutaGoles, '''', '''''') + N''', SINGLE_CLOB) AS J;';
        EXEC sys.sp_executesql @SQLJson, N'@DataOut NVARCHAR(MAX) OUTPUT', @DataOut = @JsonData OUTPUT;

        SET @JsonData = LTRIM(RTRIM(@JsonData));
        IF LEFT(@JsonData, 1) = '\' OR LEFT(@JsonData, 1) = '"'
        BEGIN
            SET @JsonData = REPLACE(@JsonData, '\"', '"');
            SET @JsonData = REPLACE(@JsonData, '\\', '\');
            IF LEFT(@JsonData, 1) = '"' AND RIGHT(@JsonData, 1) = '"'
                SET @JsonData = SUBSTRING(@JsonData, 2, LEN(@JsonData) - 2);
        END;

        IF ISJSON(@JsonData) = 0
            THROW 50005, 'El archivo leído no contiene una estructura JSON válida.', 1;

        PRINT '--> [OK] archivo.json leído y validado sintácticamente.';
    END TRY
    BEGIN CATCH
        SET @ErrLinea   = ERROR_LINE();
        SET @ErrMensaje = 'Fallo al leer o validar archivo.json en ' + @RutaGoles + ': ' + ERROR_MESSAGE();
        EXEC auditoria.sp_REGISTRAR_ERROR_IMPORTACION
            @proceso_origen = @NombreProc,
            @clave_registro = @RutaGoles,
            @mensaje_error  = @ErrMensaje,
            @linea_error    = @ErrLinea;
        PRINT '--> ERROR REGISTRADO EN AUDITORÍA: ' + @ErrMensaje;
        THROW 50006, @ErrMensaje, 1;
    END CATCH;

    -- Procesamiento e inserción en torneo.GOL
    BEGIN TRANSACTION;
    BEGIN TRY
        DELETE FROM torneo.GOL;

        ;WITH GolesExtraidos AS (
            -- Goles del Equipo 1 (goals1)
            SELECT
                M.team1 COLLATE DATABASE_DEFAULT AS EquipoAnotador,
                M.team2 COLLATE DATABASE_DEFAULT AS EquipoRival,
                G.name  COLLATE DATABASE_DEFAULT AS Goleador,
                G.minute COLLATE DATABASE_DEFAULT AS MinutoRaw,
                ISNULL(G.penalty, 0) AS EsPenal,
                ISNULL(G.owngoal, 0) AS EsAutoGol
            FROM OPENJSON(@JsonData, '$.matches')
            WITH (
                team1 NVARCHAR(100) '$.team1',
                team2 NVARCHAR(100) '$.team2',
                goals1 NVARCHAR(MAX) '$.goals1' AS JSON
            ) M
            CROSS APPLY OPENJSON(M.goals1)
            WITH (
                name NVARCHAR(100) '$.name',
                minute NVARCHAR(20) '$.minute',
                penalty BIT '$.penalty',
                owngoal BIT '$.owngoal'
            ) G

            UNION ALL

            -- Goles del Equipo 2 (goals2)
            SELECT
                M.team2 COLLATE DATABASE_DEFAULT AS EquipoAnotador,
                M.team1 COLLATE DATABASE_DEFAULT AS EquipoRival,
                G.name  COLLATE DATABASE_DEFAULT AS Goleador,
                G.minute COLLATE DATABASE_DEFAULT AS MinutoRaw,
                ISNULL(G.penalty, 0) AS EsPenal,
                ISNULL(G.owngoal, 0) AS EsAutoGol
            FROM OPENJSON(@JsonData, '$.matches')
            WITH (
                team1 NVARCHAR(100) '$.team1',
                team2 NVARCHAR(100) '$.team2',
                goals2 NVARCHAR(MAX) '$.goals2' AS JSON
            ) M
            CROSS APPLY OPENJSON(M.goals2)
            WITH (
                name NVARCHAR(100) '$.name',
                minute NVARCHAR(20) '$.minute',
                penalty BIT '$.penalty',
                owngoal BIT '$.owngoal'
            ) G
        ),
        GolesNormalizados AS (
            SELECT
                P.id_fase,
                P.nro_partido_fase,
                S_Score.id_seleccion,
                CASE
                    WHEN CHARINDEX('+', GE.MinutoRaw) > 0
                        THEN TRY_CAST(SUBSTRING(GE.MinutoRaw, 1, CHARINDEX('+', GE.MinutoRaw) - 1) AS INT)
                    ELSE TRY_CAST(GE.MinutoRaw AS INT)
                END AS MinutoGol,
                CASE
                    WHEN CHARINDEX('+', GE.MinutoRaw) > 0
                        THEN TRY_CAST(SUBSTRING(GE.MinutoRaw, CHARINDEX('+', GE.MinutoRaw) + 1, 10) AS INT)
                    ELSE NULL
                END AS MinutoExtra,
                CASE
                    WHEN GE.EsAutoGol = 1 THEN 'AUTOGOL'
                    WHEN GE.EsPenal = 1   THEN 'PENAL'
                    ELSE 'JUGADA'
                END AS TipoGol,
                GE.Goleador,
                ROW_NUMBER() OVER (
                    PARTITION BY P.id_fase, P.nro_partido_fase
                    ORDER BY CASE
                        WHEN CHARINDEX('+', GE.MinutoRaw) > 0
                            THEN TRY_CAST(SUBSTRING(GE.MinutoRaw, 1, CHARINDEX('+', GE.MinutoRaw) - 1) AS INT)
                        ELSE TRY_CAST(GE.MinutoRaw AS INT)
                    END
                ) AS NroGol
            FROM GolesExtraidos GE
            INNER JOIN torneo.SELECCION S_Score
                ON UPPER(LTRIM(RTRIM(S_Score.nombre_seleccion))) LIKE '%' + UPPER(LTRIM(RTRIM(GE.EquipoAnotador))) + '%'
                OR UPPER(LTRIM(RTRIM(GE.EquipoAnotador))) LIKE '%' + UPPER(LTRIM(RTRIM(S_Score.nombre_seleccion))) + '%'
            INNER JOIN torneo.SELECCION S_Conc
                ON UPPER(LTRIM(RTRIM(S_Conc.nombre_seleccion)))  LIKE '%' + UPPER(LTRIM(RTRIM(GE.EquipoRival))) + '%'
                OR UPPER(LTRIM(RTRIM(GE.EquipoRival))) LIKE '%' + UPPER(LTRIM(RTRIM(S_Conc.nombre_seleccion))) + '%'
            INNER JOIN torneo.PARTIDO P
                ON (P.id_seleccion_local = S_Score.id_seleccion AND P.id_seleccion_visitante = S_Conc.id_seleccion)
                OR (P.id_seleccion_local = S_Conc.id_seleccion  AND P.id_seleccion_visitante = S_Score.id_seleccion)
        )
        INSERT INTO torneo.GOL (
            id_fase,
            nro_partido_fase,
            id_gol,
            minuto_gol,
            minuto_gol_extra,
            tipo_gol,
            id_seleccion,
            dorsal_autor,
            dorsal_asistente
        )
        SELECT
            GN.id_fase,
            GN.nro_partido_fase,
            GN.NroGol,
            CASE WHEN GN.MinutoGol BETWEEN 1 AND 120 THEN GN.MinutoGol ELSE 45 END,
            GN.MinutoExtra,
            GN.TipoGol,
            GN.id_seleccion,
            ISNULL(
                (
                    SELECT TOP 1 C.dorsal_oficial
                    FROM torneo.CONVOCATORIA C
                    INNER JOIN persona.PERSONA PER
                        ON C.tipo_doc = PER.tipo_doc AND C.nro_doc = PER.nro_doc
                    WHERE C.id_seleccion = GN.id_seleccion
                      AND (
                          GN.Goleador COLLATE Modern_Spanish_CI_AI LIKE '%' + PER.apellido COLLATE Modern_Spanish_CI_AI + '%'
                          OR GN.Goleador COLLATE Modern_Spanish_CI_AI LIKE '%' + SUBSTRING(PER.nombre COLLATE Modern_Spanish_CI_AI, 1, CHARINDEX(' ', PER.nombre + ' ') - 1) + '%'
                          OR (PER.nombre + ' ' + PER.apellido) COLLATE Modern_Spanish_CI_AI LIKE '%' + GN.Goleador COLLATE Modern_Spanish_CI_AI + '%'
                      )
                    ORDER BY
                        CASE
                            WHEN GN.Goleador COLLATE Modern_Spanish_CI_AI LIKE '%' + SUBSTRING(PER.nombre COLLATE Modern_Spanish_CI_AI, 1, CHARINDEX(' ', PER.nombre + ' ') - 1) + '%'
                             AND GN.Goleador COLLATE Modern_Spanish_CI_AI LIKE '%' + PER.apellido COLLATE Modern_Spanish_CI_AI + '%' THEN 1
                            WHEN GN.Goleador COLLATE Modern_Spanish_CI_AI LIKE '%' + PER.apellido COLLATE Modern_Spanish_CI_AI + '%' THEN 2
                            ELSE 3
                        END,
                        C.dorsal_oficial
                ),
                (
                    SELECT TOP 1 C2.dorsal_oficial
                    FROM torneo.CONVOCATORIA C2
                    WHERE C2.id_seleccion = GN.id_seleccion
                    ORDER BY C2.dorsal_oficial DESC
                )
            ) AS dorsal_autor,
            NULL
        FROM GolesNormalizados GN;

        DECLARE @TotalGolesCargados INT = @@ROWCOUNT;
        PRINT '--> [OK] Goles cargados en torneo.GOL: ' + CAST(@TotalGolesCargados AS VARCHAR(10));
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @ErrLinea   = ERROR_LINE();
        SET @ErrMensaje = 'Error al registrar eventos en torneo.GOL: ' + ERROR_MESSAGE();
        EXEC auditoria.sp_REGISTRAR_ERROR_IMPORTACION
            @proceso_origen = @NombreProc,
            @clave_registro = 'torneo.GOL',
            @mensaje_error  = @ErrMensaje,
            @linea_error    = @ErrLinea;
        PRINT '--> ERROR REGISTRADO EN AUDITORÍA: ' + @ErrMensaje;
        THROW 50007, @ErrMensaje, 1;
    END CATCH;

    -- 5. LIMPIEZA DE TABLAS TEMPORALES
    DROP TABLE #StagingMatches;

    PRINT '  CARGA DE PARTIDOS Y GOLES FINALIZADA EXITOSAMENTE                     ';

END;
GO