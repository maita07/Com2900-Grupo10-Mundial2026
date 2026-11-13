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

Archivo: 04_8_IMPORT_ALINEACIONES_SUSTITUCIONES.sql
Descripcion: Importa el esquema táctico, los titulares, el banco de suplentes y los cambios
             de cada partido desde la API oficial de FIFA
================================================================================
*/
USE DB_Mundial2026_Grupo10;
GO

EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'Ole Automation Procedures', 1;
RECONFIGURE;
GO


-- ============================================================================
-- torneo.sp_IMPORTAR_ALINEACIONES_Y_SUSTITUCIONES_FIFA
--
-- JUGADOR_ALINEACION:
--   - Titular: minuto_ingreso = 0. minuto_salida = minuto en que lo cambian o lo expulsan (NULL si terminó).
--   - Suplente que entró: minuto_ingreso = minuto del cambio. Salida idem.
--   - Suplente que no entró: minuto_ingreso = 0 y minuto_salida = 0.
--   En cancha en el minuto M: minuto_ingreso <= M AND (minuto_salida IS NULL OR minuto_salida > M).
--
-- Reglamento (por defecto el existente): 5 cambios en 3 ventanas en los 90', +1 cambio y +1 ventana en el alargue.
-- Los cambios del entretiempo, antes del alargue y en el entretiempo del alargue no consumen ventana;
-- se registran con el número de la última ventana usada (mínimo 1).
-- ============================================================================
CREATE OR ALTER PROCEDURE torneo.sp_IMPORTAR_ALINEACIONES_Y_SUSTITUCIONES_FIFA
    @RutaArchivoJSON      VARCHAR(500) = NULL,   -- Detalle del partido guardado como archivo (alternativa a la API)
    @UrlCalendarioFifa    VARCHAR(500) = 'https://api.fifa.com/api/v3/calendar/matches?idCompetition=17&idSeason=285023&count=500&language=en',
    @UrlLiveFifa          VARCHAR(500) = 'https://api.fifa.com/api/v3/live/football/',
    @MatchNumberFifa      INT          = NULL,   -- Para importar un solo partido (número de partido de FIFA)
    @MaxCambios           INT          = 5,
    @CambiosExtraAlargue  INT          = 1,
    @MaxVentanas          INT          = 3,
    @VentanasExtraAlargue INT          = 1
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Proceso VARCHAR(100) = 'torneo.sp_IMPORTAR_ALINEACIONES_Y_SUSTITUCIONES_FIFA';
    DECLARE @Fila INT, @Total INT, @Accion CHAR(1), @Altas INT, @Mod INT, @Err INT;
    DECLARE @IdFase INT, @NroPartido INT, @IdSeleccion INT, @Esquema VARCHAR(10), @Dorsal INT, @EsTitular BIT,
            @Posicion VARCHAR(30), @MinIng INT, @MinIngExtra INT, @MinSal INT, @MinSalExtra INT,
            @IdSecuencia INT, @DorsalSale INT, @DorsalEntra INT, @Ventana INT, @Errores NVARCHAR(400);

    -- Descarga y staging
    DECLARE @Sql NVARCHAR(MAX), @Msg NVARCHAR(4000), @Bin VARBINARY(MAX), @Json NVARCHAR(MAX), @UrlActual VARCHAR(1000);
    DECLARE @Obj INT, @HResult INT, @Status INT;
    DECLARE @Respuesta TABLE (txt NVARCHAR(MAX));
    DECLARE @Url TABLE (n INT PRIMARY KEY, url VARCHAR(1000));
    DECLARE @Doc TABLE (id_doc INT IDENTITY(1,1) PRIMARY KEY, origen NVARCHAR(600), json NVARCHAR(MAX) COLLATE DATABASE_DEFAULT);
    DECLARE @Partido TABLE (id_doc INT PRIMARY KEY, id_fase INT, nro_partido_fase INT, id_sel_local INT, id_sel_visitante INT);
    DECLARE @Equipo TABLE (id_fase INT, nro_partido_fase INT, lado CHAR(1), id_seleccion INT, json NVARCHAR(MAX) COLLATE DATABASE_DEFAULT);

    PRINT '     IMPORTACIÓN: FORMACIONES, ALINEACIONES Y SUSTITUCIONES (API FIFA)     ';

    -- Staging
    CREATE TABLE #STG_FIFA_EQUIPO (
        id_fase          INT NOT NULL,
        nro_partido_fase INT NOT NULL,
        lado             CHAR(1) COLLATE DATABASE_DEFAULT NOT NULL,   -- L = HomeTeam, V = AwayTeam
        id_seleccion     INT NOT NULL,
        esquema_tactico  VARCHAR(10) COLLATE DATABASE_DEFAULT NULL
    );

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

    -- C. Equipos, jugadores, cambios y expulsiones (para saber cuándo sale el jugador)

    INSERT INTO @Equipo (id_fase, nro_partido_fase, lado, id_seleccion, json)
    SELECT P.id_fase, P.nro_partido_fase, L.lado, L.id_seleccion, L.json
    FROM @Partido P
    INNER JOIN @Doc D ON D.id_doc = P.id_doc
    CROSS APPLY (VALUES ('L', P.id_sel_local,     JSON_QUERY(D.json, '$.HomeTeam')),
                        ('V', P.id_sel_visitante, JSON_QUERY(D.json, '$.AwayTeam'))) L(lado, id_seleccion, json);

    INSERT INTO #STG_FIFA_EQUIPO (id_fase, nro_partido_fase, lado, id_seleccion, esquema_tactico)
    SELECT id_fase, nro_partido_fase, lado, id_seleccion, LEFT(JSON_VALUE(json, '$.Tactics'), 10)
    FROM @Equipo;

    INSERT INTO #STG_FIFA_JUGADOR (id_fase, nro_partido_fase, lado, id_seleccion, id_player, nombre, dorsal, estado, posicion)
    SELECT E.id_fase, E.nro_partido_fase, E.lado, E.id_seleccion, J.IdPlayer, J.Nombre, J.ShirtNumber, J.Status, J.Position
    FROM @Equipo E
    CROSS APPLY OPENJSON(E.json, '$.Players')
         WITH (IdPlayer NVARCHAR(50), Nombre NVARCHAR(200) '$.PlayerName[0].Description',
               ShirtNumber INT, Status INT, Position INT) J;

    INSERT INTO #STG_FIFA_EVENTO (id_fase, nro_partido_fase, lado, id_seleccion, tipo, card,
                                           id_player, id_player_entra, motivo, periodo, minuto_raw)
    SELECT E.id_fase, E.nro_partido_fase, E.lado, E.id_seleccion, 'CAMBIO', NULL,
           S.IdPlayerOff, S.IdPlayerOn, NULL, S.Period, S.Minute
    FROM @Equipo E
    CROSS APPLY OPENJSON(E.json, '$.Substitutions')
         WITH (IdPlayerOff NVARCHAR(50), IdPlayerOn NVARCHAR(50), Period INT, Minute NVARCHAR(30)) S
    UNION ALL
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

    -- D. Formaciones (sp_ALINEACION_PARTIDO_ABM)
    SELECT ROW_NUMBER() OVER (ORDER BY id_fase, nro_partido_fase, lado) AS nro_fila,
           id_fase, nro_partido_fase, id_seleccion,
           ISNULL(NULLIF(TRIM(esquema_tactico), ''), 'S/D') AS esquema
    INTO #Equipo
    FROM #STG_FIFA_EQUIPO;

    SELECT @Fila = 1, @Total = COUNT(*), @Altas = 0, @Mod = 0, @Err = 0 FROM #Equipo;

    WHILE @Fila <= @Total
    BEGIN
        SELECT @IdFase = id_fase, @NroPartido = nro_partido_fase, @IdSeleccion = id_seleccion, @Esquema = esquema
        FROM #Equipo
        WHERE nro_fila = @Fila;

        BEGIN TRY
            SET @Accion = CASE WHEN EXISTS (SELECT 1 FROM torneo.ALINEACION_PARTIDO
                                            WHERE id_fase = @IdFase AND nro_partido_fase = @NroPartido
                                              AND id_seleccion = @IdSeleccion)
                               THEN 'M' ELSE 'A' END;

            EXEC torneo.sp_ALINEACION_PARTIDO_ABM
                 @Accion           = @Accion,
                 @id_fase          = @IdFase,
                 @nro_partido_fase = @NroPartido,
                 @id_seleccion     = @IdSeleccion,
                 @esquema_tactico  = @Esquema;

            IF @Accion = 'A' SET @Altas += 1; ELSE SET @Mod += 1;
        END TRY
        BEGIN CATCH
            SET @Err += 1;
            INSERT INTO auditoria.LOG_IMPORTACION (proceso_origen, nro_fila, clave_registro, mensaje_error, linea_error)
            VALUES (@Proceso, @Fila, CONCAT('Formación partido ', @IdFase, '-', @NroPartido, ' selección ', @IdSeleccion),
                    ERROR_MESSAGE(), ERROR_LINE());
        END CATCH;

        SET @Fila += 1;
    END;

    PRINT CONCAT('--> Formaciones: ', @Total, ' | Altas: ', @Altas, ' | Modificaciones: ', @Mod, ' | Con error: ', @Err);

    -- E. Titulares y suplentes (sp_JUGADOR_ALINEACION_ABM). La salida es por cambio o por expulsión.
    SELECT ROW_NUMBER() OVER (ORDER BY J.id_fase, J.nro_partido_fase, J.lado, J.dorsal) AS nro_fila,
           J.id_fase, J.nro_partido_fase, J.id_seleccion, J.dorsal,
           CAST(CASE WHEN J.estado = 1 THEN 1 ELSE 0 END AS BIT) AS es_titular,
           ISNULL(CASE J.posicion WHEN 0 THEN 'GK' WHEN 1 THEN 'DF' WHEN 2 THEN 'MF' WHEN 3 THEN 'FW' END, 'S/D') AS posicion,
           CASE WHEN J.estado = 1 THEN 0 ELSE ISNULL(ENT.minuto, 0) END              AS minuto_ingreso,
           CASE WHEN J.estado = 1 THEN NULL ELSE ENT.minuto_extra END                AS minuto_ingreso_extra,
           CASE WHEN J.estado <> 1 AND ENT.minuto IS NULL THEN 0 ELSE SAL.minuto END AS minuto_salida,
           CASE WHEN J.estado <> 1 AND ENT.minuto IS NULL THEN NULL ELSE SAL.minuto_extra END AS minuto_salida_extra
    INTO #Jugador
    FROM #STG_FIFA_JUGADOR J
    OUTER APPLY (SELECT TOP 1 E.minuto, E.minuto_extra
                 FROM #STG_FIFA_EVENTO E
                 WHERE E.id_fase = J.id_fase AND E.nro_partido_fase = J.nro_partido_fase AND E.lado = J.lado
                   AND E.tipo = 'CAMBIO' AND E.id_player_entra = J.id_player
                 ORDER BY E.orden) ENT
    OUTER APPLY (SELECT TOP 1 E.minuto, E.minuto_extra
                 FROM #STG_FIFA_EVENTO E
                 WHERE E.id_fase = J.id_fase AND E.nro_partido_fase = J.nro_partido_fase AND E.lado = J.lado
                   AND E.id_player = J.id_player
                   AND (E.tipo = 'CAMBIO' OR E.card IN (2, 3))
                 ORDER BY E.orden) SAL;

    SELECT @Fila = 1, @Total = COUNT(*), @Altas = 0, @Mod = 0, @Err = 0 FROM #Jugador;

    WHILE @Fila <= @Total
    BEGIN
        SELECT @IdFase = id_fase, @NroPartido = nro_partido_fase, @IdSeleccion = id_seleccion, @Dorsal = dorsal,
               @EsTitular = es_titular, @Posicion = posicion,
               @MinIng = minuto_ingreso, @MinIngExtra = minuto_ingreso_extra,
               @MinSal = minuto_salida, @MinSalExtra = minuto_salida_extra
        FROM #Jugador
        WHERE nro_fila = @Fila;

        BEGIN TRY
            SET @Accion = CASE WHEN EXISTS (SELECT 1 FROM torneo.JUGADOR_ALINEACION
                                            WHERE id_fase = @IdFase AND nro_partido_fase = @NroPartido
                                              AND id_seleccion = @IdSeleccion AND dorsal_oficial = @Dorsal)
                               THEN 'M' ELSE 'A' END;

            EXEC torneo.sp_JUGADOR_ALINEACION_ABM
                 @Accion               = @Accion,
                 @id_fase              = @IdFase,
                 @nro_partido_fase     = @NroPartido,
                 @id_seleccion         = @IdSeleccion,
                 @dorsal_oficial       = @Dorsal,
                 @es_titular           = @EsTitular,
                 @posicion_campo       = @Posicion,
                 @minuto_ingreso       = @MinIng,
                 @minuto_ingreso_extra = @MinIngExtra,
                 @minuto_salida        = @MinSal,
                 @minuto_salida_extra  = @MinSalExtra;

            IF @Accion = 'A' SET @Altas += 1; ELSE SET @Mod += 1;
        END TRY
        BEGIN CATCH
            SET @Err += 1;
            INSERT INTO auditoria.LOG_IMPORTACION (proceso_origen, nro_fila, clave_registro, mensaje_error, linea_error)
            VALUES (@Proceso, @Fila, CONCAT('Alineación partido ', @IdFase, '-', @NroPartido, ' selección ', @IdSeleccion, ' #', @Dorsal),
                    ERROR_MESSAGE(), ERROR_LINE());
        END CATCH;

        SET @Fila += 1;
    END;

    PRINT CONCAT('--> Jugadores en alineaciones: ', @Total, ' | Altas: ', @Altas, ' | Modificaciones: ', @Mod, ' | Con error: ', @Err);

    -- F. Sustituciones (sp_SUSTITUCION_ABM) con control de cambios y ventanas
    SELECT ROW_NUMBER() OVER (ORDER BY E.id_fase, E.nro_partido_fase, E.orden, E.id_evento) AS nro_fila,
           E.id_fase, E.nro_partido_fase, E.lado, E.id_seleccion,
           ROW_NUMBER() OVER (PARTITION BY E.id_fase, E.nro_partido_fase ORDER BY E.orden, E.id_evento) AS id_secuencia,
           ROW_NUMBER() OVER (PARTITION BY E.id_fase, E.nro_partido_fase, E.lado ORDER BY E.orden, E.id_evento) AS nro_cambio,
           JS.dorsal AS dorsal_sale, JE.dorsal AS dorsal_entra, E.minuto, E.minuto_extra, E.orden,
           -- entretiempo, inicio del alargue y entretiempo del alargue
           CASE WHEN E.periodo IN (4, 6, 8) OR E.periodo >= 10 OR (E.minuto_extra IS NULL AND E.minuto IN (46, 91, 106)) THEN 1 ELSE 0 END AS libre,
           CASE WHEN E.periodo >= 6 OR E.minuto > 90 THEN 1 ELSE 0 END AS en_alargue,
           CAST(NULL AS INT) AS ventana,
           CAST(NULL AS NVARCHAR(400)) AS errores
    INTO #Sust
    FROM #STG_FIFA_EVENTO E
    LEFT JOIN #STG_FIFA_JUGADOR JS
           ON JS.id_fase = E.id_fase AND JS.nro_partido_fase = E.nro_partido_fase AND JS.lado = E.lado AND JS.id_player = E.id_player
    LEFT JOIN #STG_FIFA_JUGADOR JE
           ON JE.id_fase = E.id_fase AND JE.nro_partido_fase = E.nro_partido_fase AND JE.lado = E.lado AND JE.id_player = E.id_player_entra
    WHERE E.tipo = 'CAMBIO';

    -- ventanas usadas = momentos distintos en que la selección cambió con el partido en juego
    UPDATE S
    SET ventana = CASE WHEN S.libre = 0 THEN V.previas + 1
                       WHEN V.previas = 0 THEN 1
                       ELSE V.previas END,
        errores = CONCAT(
            CASE WHEN S.nro_cambio > @MaxCambios + @CambiosExtraAlargue
                      OR (S.nro_cambio > @MaxCambios AND S.en_alargue = 0)
                 THEN CONCAT(N'Supera los ', @MaxCambios, N' cambios permitidos (', @MaxCambios + @CambiosExtraAlargue, N' con alargue). ') END,
            CASE WHEN S.libre = 0
                      AND (V.previas + 1 > @MaxVentanas + @VentanasExtraAlargue
                           OR (V.previas + 1 > @MaxVentanas AND S.en_alargue = 0))
                 THEN CONCAT(N'Supera las ', @MaxVentanas, N' ventanas permitidas (', @MaxVentanas + @VentanasExtraAlargue, N' con alargue). ') END)
    FROM #Sust S
    CROSS APPLY (SELECT COUNT(DISTINCT S2.orden) AS previas
                 FROM #Sust S2
                 WHERE S2.id_fase = S.id_fase AND S2.nro_partido_fase = S.nro_partido_fase AND S2.lado = S.lado
                   AND S2.libre = 0 AND S2.orden < S.orden) V;

    SELECT @Fila = 1, @Total = COUNT(*), @Altas = 0, @Mod = 0, @Err = 0 FROM #Sust;

    WHILE @Fila <= @Total
    BEGIN
        SELECT @IdFase = id_fase, @NroPartido = nro_partido_fase, @IdSecuencia = id_secuencia, @IdSeleccion = id_seleccion,
               @DorsalSale = dorsal_sale, @DorsalEntra = dorsal_entra, @MinIng = minuto, @MinIngExtra = minuto_extra,
               @Ventana = ventana, @Errores = errores
        FROM #Sust
        WHERE nro_fila = @Fila;

        BEGIN TRY
            IF @Errores <> '' THROW 50120, @Errores, 1;

            SET @Accion = CASE WHEN EXISTS (SELECT 1 FROM torneo.SUSTITUCION
                                            WHERE id_fase = @IdFase AND nro_partido_fase = @NroPartido
                                              AND id_secuencia = @IdSecuencia)
                               THEN 'M' ELSE 'A' END;

            EXEC torneo.sp_SUSTITUCION_ABM
                 @Accion              = @Accion,
                 @id_fase             = @IdFase,
                 @nro_partido_fase    = @NroPartido,
                 @id_secuencia        = @IdSecuencia,
                 @id_seleccion        = @IdSeleccion,
                 @dorsal_sale         = @DorsalSale,
                 @dorsal_entra        = @DorsalEntra,
                 @minuto_cambio       = @MinIng,
                 @minuto_cambio_extra = @MinIngExtra,
                 @ventana_numero      = @Ventana;

            IF @Accion = 'A' SET @Altas += 1; ELSE SET @Mod += 1;
        END TRY
        BEGIN CATCH
            SET @Err += 1;
            INSERT INTO auditoria.LOG_IMPORTACION (proceso_origen, nro_fila, clave_registro, mensaje_error, linea_error)
            VALUES (@Proceso, @Fila,
                    CONCAT('Cambio ', @IdSecuencia, ' partido ', @IdFase, '-', @NroPartido, ' selección ', @IdSeleccion,
                           ' (sale #', @DorsalSale, ', entra #', @DorsalEntra, ')'),
                    ERROR_MESSAGE(), ERROR_LINE());
        END CATCH;

        SET @Fila += 1;
    END;

    PRINT CONCAT('--> Sustituciones: ', @Total, ' | Altas: ', @Altas, ' | Modificaciones: ', @Mod, ' | Con error: ', @Err);
    PRINT '--> Los registros rechazados quedan en auditoria.LOG_IMPORTACION.';
END;
GO