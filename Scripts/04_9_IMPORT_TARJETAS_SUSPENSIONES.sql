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

Archivo: 04_9_IMPORT_TARJETAS_Y_SUSPENSIONES.sql
Descripcion: Importa las tarjetas amarillas y rojas de cada partido jugado, distinguiendo la
             expulsión por doble amarilla de la roja directa (FIFA Card: 1 amarilla, 2 roja directa,
             3 doble amarilla). Descarga el detalle de cada partido de la API oficial de FIFA (igual
             que 04_8) o lo lee de un archivo .json con la respuesta de la API guardada.
================================================================================
*/
USE DB_Mundial2026_Grupo10;
GO

CREATE OR ALTER PROCEDURE torneo.sp_IMPORTAR_TARJETAS_FIFA
    @RutaArchivoJSON          VARCHAR(500) = NULL,   -- Detalle de partido guardado como archivo (alternativa a la API)
    @UrlCalendarioFifa        VARCHAR(500) = 'https://api.fifa.com/api/v3/calendar/matches?idCompetition=17&idSeason=285023&count=500&language=en',
    @UrlLiveFifa              VARCHAR(500) = 'https://api.fifa.com/api/v3/live/football/',
    @MatchNumberFifa          INT          = NULL,   -- Para importar un solo partido (número de partido de FIFA)
    @MotivoNoInformado        VARCHAR(100) = 'Motivo no informado por FIFA',
    -- Criterios de suspensión (por defecto, reglas de FIFA para el Mundial 2026)
    @AmarillasParaSuspension  INT          = 2,
    @PartidosPorAcumulacion   INT          = 1,
    @PartidosPorRojaDirecta   INT          = 1,
    @PartidosPorDobleAmarilla INT          = 1,
    @FasesLimpiezaAmarillas   VARCHAR(50)  = '1,4'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Proceso VARCHAR(100) = 'torneo.sp_IMPORTAR_TARJETAS_FIFA';
    DECLARE @Fila INT, @Total INT, @Accion CHAR(1), @Altas INT = 0, @Mod INT = 0, @Err INT = 0;
    DECLARE @IdFase INT, @NroPartido INT, @IdTarjeta INT, @IdSeleccion INT, @Dorsal INT,
            @Minuto INT, @MinutoExtra INT, @Tipo VARCHAR(20), @Motivo VARCHAR(100);

    -- Descarga y staging
    DECLARE @Sql NVARCHAR(MAX), @Msg NVARCHAR(4000), @Bin VARBINARY(MAX), @Json NVARCHAR(MAX), @UrlActual VARCHAR(1000);
    DECLARE @Obj INT, @HResult INT, @Status INT;
    DECLARE @Respuesta TABLE (txt NVARCHAR(MAX));
    DECLARE @Url TABLE (n INT PRIMARY KEY, url VARCHAR(1000));
    DECLARE @Doc TABLE (id_doc INT IDENTITY(1,1) PRIMARY KEY, origen NVARCHAR(600), json NVARCHAR(MAX) COLLATE DATABASE_DEFAULT);
    DECLARE @Partido TABLE (id_doc INT PRIMARY KEY, id_fase INT, nro_partido_fase INT, id_sel_local INT, id_sel_visitante INT);
    DECLARE @Equipo TABLE (id_fase INT, nro_partido_fase INT, lado CHAR(1), id_seleccion INT, json NVARCHAR(MAX) COLLATE DATABASE_DEFAULT);


    PRINT '     IMPORTACIÓN: AMONESTACIONES Y EXPULSIONES (API FIFA)     ';

    -- Jugadores y tarjetas de cada partido (Staging)
    CREATE TABLE #STG_FIFA_JUGADOR (
        id_fase          INT NOT NULL,
        nro_partido_fase INT NOT NULL,
        lado             CHAR(1) COLLATE DATABASE_DEFAULT NOT NULL,
        id_seleccion     INT NOT NULL,
        id_player        NVARCHAR(50) COLLATE DATABASE_DEFAULT NULL,
        nombre           NVARCHAR(200) COLLATE DATABASE_DEFAULT NULL,
        dorsal           INT NULL,
        estado           INT NULL,                  -- 1 titular, 2 suplente
        posicion         INT NULL                   -- 0 arquero, 1 defensor, 2 mediocampista, 3 delantero
    );

    CREATE TABLE #STG_FIFA_EVENTO (
        id_evento        INT IDENTITY(1,1) PRIMARY KEY,
        id_fase          INT NOT NULL,
        nro_partido_fase INT NOT NULL,
        lado             CHAR(1) COLLATE DATABASE_DEFAULT NOT NULL,
        id_seleccion     INT NOT NULL,
        tipo             VARCHAR(10) COLLATE DATABASE_DEFAULT NOT NULL,   -- CAMBIO / TARJETA
        card             INT NULL,                  -- 1 amarilla, 2 roja directa, 3 doble amarilla
        id_player        NVARCHAR(50) COLLATE DATABASE_DEFAULT NULL,      -- el que sale o el sancionado
        id_player_entra  NVARCHAR(50) COLLATE DATABASE_DEFAULT NULL,
        motivo           NVARCHAR(200) COLLATE DATABASE_DEFAULT NULL,
        periodo          INT NULL,                  -- 3 1T, 4 entretiempo, 5 2T, 6 a 9 alargue
        minuto_raw       NVARCHAR(30) COLLATE DATABASE_DEFAULT NULL,      -- "64'" o "45'+2'"
        minuto           INT NULL,
        minuto_extra     INT NULL,
        orden            INT NULL                   -- minuto * 100 + adición
    );

    -- A. Entrada: archivo, o calendario + detalle de cada partido desde la API
    --    En modo API, la vuelta 0 del loop es el calendario (de ahí salen la etapa y el id de cada
    --    partido terminado) y las vueltas 1..N son los partidos. Si un partido falla se sigue con el resto.
    IF @RutaArchivoJSON IS NOT NULL AND TRIM(@RutaArchivoJSON) <> ''
    BEGIN
        BEGIN TRY
            -- SQL dinamico necesario para OPENROWSET(BULK)
            SET @Sql = N'SELECT @B = BulkColumn
                         FROM OPENROWSET(BULK ''' + REPLACE(@RutaArchivoJSON, '''', '''''') + N''', SINGLE_BLOB) AS T;';
            EXEC sp_executesql @Sql, N'@B VARBINARY(MAX) OUTPUT', @B = @Bin OUTPUT;

            -- Conversion UTF-8 a NVARCHAR para conservar los acentos
            SET @Json = CAST(CAST('<?xml version="1.0" encoding="UTF-8"?><r><![CDATA[' AS VARBINARY(MAX)) + @Bin
                             + CAST(']]></r>' AS VARBINARY(MAX)) AS XML).value('(/r)[1]', 'NVARCHAR(MAX)');

            IF ISNULL(ISJSON(@Json), 0) <> 1
                THROW 50110, 'El archivo no contiene un JSON válido.', 1;

            -- un partido (objeto) o varios (array)
            IF LEFT(LTRIM(@Json), 1) = '['
                INSERT INTO @Doc (origen, json)
                SELECT CONCAT(@RutaArchivoJSON, N' [', [key], N']'), value FROM OPENJSON(@Json) WHERE [type] = 5;
            ELSE
                INSERT INTO @Doc (origen, json) VALUES (@RutaArchivoJSON, @Json);
        END TRY
        BEGIN CATCH
            SET @Msg = CONCAT('No se pudo leer el archivo "', @RutaArchivoJSON, '": ', ERROR_MESSAGE());
            INSERT INTO auditoria.LOG_IMPORTACION (proceso_origen, nro_fila, clave_registro, mensaje_error, linea_error)
            VALUES (@Proceso, NULL, LEFT(@RutaArchivoJSON, 100), @Msg, ERROR_LINE());
            THROW 50111, @Msg, 1;
        END CATCH;
    END
    ELSE
    BEGIN
        INSERT INTO @Url (n, url) VALUES (0, @UrlCalendarioFifa);
        SET @Fila = 0;
        SET @Total = 0;

        WHILE @Fila <= @Total
        BEGIN
            SELECT @UrlActual = url FROM @Url WHERE n = @Fila;

            BEGIN TRY
                DELETE FROM @Respuesta;

                EXEC @HResult = sp_OACreate 'MSXML2.ServerXMLHTTP', @Obj OUT;
                IF @HResult = 0 EXEC @HResult = sp_OAMethod @Obj, 'open', NULL, 'GET', @UrlActual, 'false';
                IF @HResult = 0 EXEC @HResult = sp_OAMethod @Obj, 'send';
                IF @HResult <> 0 THROW 50112, 'Error en la conexión HTTP con la API de FIFA.', 1;

                EXEC sp_OAGetProperty @Obj, 'status', @Status OUT;
                IF @Status <> 200
                BEGIN
                    SET @Msg = CONCAT('La API respondió con código HTTP ', ISNULL(@Status, 0), '.');
                    THROW 50113, @Msg, 1;
                END;

                -- La respuesta supera los 8000 caracteres: se captura como resultado en una tabla
                INSERT INTO @Respuesta (txt) EXEC sp_OAGetProperty @Obj, 'responseText';
                EXEC sp_OADestroy @Obj;
                SET @Obj = NULL;

                SELECT TOP 1 @Json = txt FROM @Respuesta;
                IF ISNULL(ISJSON(@Json), 0) <> 1
                    THROW 50114, 'La respuesta no es un JSON válido.', 1;

                IF @Fila = 0
                BEGIN
                    INSERT INTO @Url (n, url)
                    SELECT ROW_NUMBER() OVER (ORDER BY C.MatchNumber),
                           CONCAT(@UrlLiveFifa, CASE WHEN RIGHT(@UrlLiveFifa, 1) = '/' THEN '' ELSE '/' END,
                                  C.IdCompetition, '/', C.IdSeason, '/', C.IdStage, '/', C.IdMatch, '?language=en')
                    FROM OPENJSON(@Json, '$.Results')
                         WITH (IdCompetition VARCHAR(50), IdSeason VARCHAR(50), IdStage VARCHAR(50), IdMatch VARCHAR(50),
                               MatchNumber INT, MatchStatus INT) C
                    WHERE C.MatchStatus = 0   -- 0 = terminado
                      AND (@MatchNumberFifa IS NULL OR C.MatchNumber = @MatchNumberFifa);

                    SET @Total = (SELECT COUNT(*) FROM @Url) - 1;
                END
                ELSE
                    INSERT INTO @Doc (origen, json) VALUES (@UrlActual, @Json);
            END TRY
            BEGIN CATCH
                IF @Obj IS NOT NULL EXEC sp_OADestroy @Obj;
                SET @Obj = NULL;
                SET @Msg = CONCAT(CASE WHEN @Fila = 0 THEN 'No se pudo obtener el calendario de FIFA: '
                                       ELSE 'No se pudo descargar el partido: ' END, ERROR_MESSAGE());

                INSERT INTO auditoria.LOG_IMPORTACION (proceso_origen, nro_fila, clave_registro, mensaje_error, linea_error)
                VALUES (@Proceso, @Fila, LEFT(@UrlActual, 100), @Msg, ERROR_LINE());

                IF @Fila = 0 THROW 50115, @Msg, 1;   -- sin calendario no hay nada que importar
            END CATCH;

            SET @Fila += 1;
        END;
    END;

    -- B. Partido de torneo.PARTIDO por fase y selecciones porque el número de FIFA no coincide con el del fixture
    INSERT INTO @Partido (id_doc, id_fase, nro_partido_fase, id_sel_local, id_sel_visitante)
    SELECT D.id_doc, MIN(P.id_fase), MIN(P.nro_partido_fase), SL.id_seleccion, SV.id_seleccion
    FROM @Doc D
    CROSS APPLY (SELECT JSON_VALUE(D.json, '$.StageName[0].Description') AS etapa) E
    INNER JOIN torneo.SELECCION SL ON SL.id_pais = JSON_VALUE(D.json, '$.HomeTeam.Abbreviation')
    INNER JOIN torneo.SELECCION SV ON SV.id_pais = JSON_VALUE(D.json, '$.AwayTeam.Abbreviation')
    INNER JOIN torneo.PARTIDO P
            ON ((P.id_seleccion_local = SL.id_seleccion AND P.id_seleccion_visitante = SV.id_seleccion)
             OR (P.id_seleccion_local = SV.id_seleccion AND P.id_seleccion_visitante = SL.id_seleccion))
           AND P.id_fase = CASE WHEN E.etapa LIKE N'%First%' OR E.etapa LIKE N'%Group%'   THEN 1
                                WHEN E.etapa LIKE N'%32%'                                 THEN 2
                                WHEN E.etapa LIKE N'%16%'                                 THEN 3
                                WHEN E.etapa LIKE N'%Quarter%'                            THEN 4
                                WHEN E.etapa LIKE N'%Semi%'                               THEN 5
                                WHEN E.etapa LIKE N'%third%' OR E.etapa LIKE N'%Bronze%'  THEN 6
                                WHEN E.etapa LIKE N'%Final%'                              THEN 7 END
    GROUP BY D.id_doc, SL.id_seleccion, SV.id_seleccion
    HAVING COUNT(*) = 1;

    -- el mismo partido repetido en la entrada se procesa una vez
    DELETE P FROM @Partido P
    WHERE EXISTS (SELECT 1 FROM @Partido X
                  WHERE X.id_fase = P.id_fase AND X.nro_partido_fase = P.nro_partido_fase AND X.id_doc < P.id_doc);

    INSERT INTO auditoria.LOG_IMPORTACION (proceso_origen, nro_fila, clave_registro, mensaje_error, linea_error)
    SELECT @Proceso, D.id_doc, LEFT(D.origen, 100),
           'No se pudo asociar con torneo.PARTIDO (selecciones o fase no encontradas, o partido repetido).', NULL
    FROM @Doc D
    WHERE NOT EXISTS (SELECT 1 FROM @Partido P WHERE P.id_doc = D.id_doc);

    IF NOT EXISTS (SELECT 1 FROM @Partido)
        THROW 50116, 'Ningún partido de la entrada se pudo asociar con torneo.PARTIDO. Revise auditoria.LOG_IMPORTACION.', 1;

    SET @Fila = (SELECT COUNT(*) FROM @Doc);
    SET @Total = (SELECT COUNT(*) FROM @Partido);
    PRINT CONCAT('--> Partidos leídos: ', @Fila, ' | Asociados a torneo.PARTIDO: ', @Total);

    -- C. Jugadores (para el dorsal) y tarjetas

    INSERT INTO @Equipo (id_fase, nro_partido_fase, lado, id_seleccion, json)
    SELECT P.id_fase, P.nro_partido_fase, L.lado, L.id_seleccion, L.json
    FROM @Partido P
    INNER JOIN @Doc D ON D.id_doc = P.id_doc
    CROSS APPLY (VALUES ('L', P.id_sel_local,     JSON_QUERY(D.json, '$.HomeTeam')),
                        ('V', P.id_sel_visitante, JSON_QUERY(D.json, '$.AwayTeam'))) L(lado, id_seleccion, json);

    INSERT INTO #STG_FIFA_JUGADOR (id_fase, nro_partido_fase, lado, id_seleccion, id_player, nombre, dorsal, estado, posicion)
    SELECT E.id_fase, E.nro_partido_fase, E.lado, E.id_seleccion, J.IdPlayer, J.Nombre, J.ShirtNumber, J.Status, J.Position
    FROM @Equipo E
    CROSS APPLY OPENJSON(E.json, '$.Players')
         WITH (IdPlayer NVARCHAR(50), Nombre NVARCHAR(200) '$.PlayerName[0].Description',
               ShirtNumber INT, Status INT, Position INT) J;

    INSERT INTO #STG_FIFA_EVENTO (id_fase, nro_partido_fase, lado, id_seleccion, tipo, card,
                                           id_player, id_player_entra, motivo, periodo, minuto_raw)
    SELECT E.id_fase, E.nro_partido_fase, E.lado, E.id_seleccion, 'TARJETA', B.Card,
           B.IdPlayer, NULL, B.Reason, B.Period, B.Minute
    FROM @Equipo E
    CROSS APPLY OPENJSON(E.json, '$.Bookings')
         WITH (Card INT, IdPlayer NVARCHAR(50), Reason NVARCHAR(200), Period INT, Minute NVARCHAR(30)) B;

    -- minutos: "64'" -> 64 / "45'+2'" -> 45 y 2
    UPDATE E
    SET minuto       = TRY_CAST(LEFT(M.m, CHARINDEX('+', M.m + '+') - 1) AS INT),
        minuto_extra = NULLIF(TRY_CAST(SUBSTRING(M.m, CHARINDEX('+', M.m + '+') + 1, 10) AS INT), 0)
    FROM #STG_FIFA_EVENTO E
    CROSS APPLY (SELECT REPLACE(REPLACE(ISNULL(E.minuto_raw, N''), N'''', N''), N' ', N'') AS m) M;

    -- eventos en un descanso (entretiempo, antes del alargue o entretiempo del alargue)
    -- FIFA los registra como minuto 0. Se toma el comienzo del periodo siguiente
    UPDATE #STG_FIFA_EVENTO
    SET minuto       = CASE WHEN periodo IN (4, 5) THEN 46 WHEN periodo IN (6, 7) THEN 91 WHEN periodo IN (8, 9) THEN 106 WHEN periodo >= 10 THEN 120 END,
        minuto_extra = NULL
    WHERE ISNULL(minuto, 0) = 0;


    UPDATE #STG_FIFA_EVENTO
    SET orden = minuto * 100 + ISNULL(minuto_extra, 0);

    -- Se cargan en orden, o sea que la primera amarilla tiene que estar antes que la doble amarilla
    SELECT ROW_NUMBER() OVER (ORDER BY E.id_fase, E.nro_partido_fase, E.orden, E.id_evento) AS nro_fila,
           E.id_fase, E.nro_partido_fase, E.id_seleccion,
           ROW_NUMBER() OVER (PARTITION BY E.id_fase, E.nro_partido_fase ORDER BY E.orden, E.id_evento) AS id_tarjeta,
           J.dorsal, E.minuto, E.minuto_extra,
           CASE E.card WHEN 1 THEN 'AMARILLA' WHEN 2 THEN 'ROJA_DIRECTA' WHEN 3 THEN 'DOBLE_AMARILLA' END AS tipo,
           LEFT(COALESCE(NULLIF(TRIM(E.motivo), ''),
                         CASE WHEN E.card = 3 THEN 'Segunda amonestación en el partido' END,
                         @MotivoNoInformado), 100) AS motivo
    INTO #Tarjeta
    FROM #STG_FIFA_EVENTO E
    LEFT JOIN #STG_FIFA_JUGADOR J
           ON J.id_fase = E.id_fase AND J.nro_partido_fase = E.nro_partido_fase AND J.lado = E.lado AND J.id_player = E.id_player
    WHERE E.tipo = 'TARJETA';

    SELECT @Fila = 1, @Total = COUNT(*) FROM #Tarjeta;

    -- Carga con sp_SANCION_TARJETA_ABM
    WHILE @Fila <= @Total
    BEGIN
        SELECT @IdFase = id_fase, @NroPartido = nro_partido_fase, @IdTarjeta = id_tarjeta, @IdSeleccion = id_seleccion,
               @Dorsal = dorsal, @Minuto = minuto, @MinutoExtra = minuto_extra, @Tipo = tipo, @Motivo = motivo
        FROM #Tarjeta
        WHERE nro_fila = @Fila;

        BEGIN TRY
            SET @Accion = CASE WHEN EXISTS (SELECT 1 FROM torneo.SANCION_TARJETA
                                            WHERE id_fase = @IdFase AND nro_partido_fase = @NroPartido
                                              AND id_tarjeta = @IdTarjeta)
                               THEN 'M' ELSE 'A' END;

            EXEC torneo.sp_SANCION_TARJETA_ABM
                 @Accion                   = @Accion,
                 @id_fase                  = @IdFase,
                 @nro_partido_fase         = @NroPartido,
                 @id_tarjeta               = @IdTarjeta,
                 @id_seleccion             = @IdSeleccion,
                 @dorsal_sancionado        = @Dorsal,
                 @minuto_sancion           = @Minuto,
                 @minuto_sancion_extra     = @MinutoExtra,
                 @tipo_tarjeta             = @Tipo,
                 @motivo                   = @Motivo,
                 @AmarillasParaSuspension  = @AmarillasParaSuspension,
                 @PartidosPorAcumulacion   = @PartidosPorAcumulacion,
                 @PartidosPorRojaDirecta   = @PartidosPorRojaDirecta,
                 @PartidosPorDobleAmarilla = @PartidosPorDobleAmarilla,
                 @FasesLimpiezaAmarillas   = @FasesLimpiezaAmarillas;

            IF @Accion = 'A' SET @Altas += 1; ELSE SET @Mod += 1;
        END TRY
        BEGIN CATCH
            SET @Err += 1;
            INSERT INTO auditoria.LOG_IMPORTACION (proceso_origen, nro_fila, clave_registro, mensaje_error, linea_error)
            VALUES (@Proceso, @Fila,
                    CONCAT('Tarjeta ', @IdTarjeta, ' partido ', @IdFase, '-', @NroPartido, ' selección ', @IdSeleccion,
                           ' #', @Dorsal, ' ', @Tipo, ' ', @Minuto),
                    ERROR_MESSAGE(), ERROR_LINE());
        END CATCH;

        SET @Fila += 1;
    END;

    PRINT CONCAT('--> Tarjetas: ', @Total, ' | Altas: ', @Altas, ' | Modificaciones: ', @Mod, ' | Con error: ', @Err);
    SET @Total = (SELECT COUNT(*) FROM torneo.CONTROL_SUSPENSION WHERE partidos_suspension > 0);
    PRINT CONCAT('--> Jugadores con suspensión pendiente: ', @Total);
    PRINT '--> Los registros rechazados quedan en auditoria.LOG_IMPORTACION.';
END;
GO