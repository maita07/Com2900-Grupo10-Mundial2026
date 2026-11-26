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
- persona.sp_API_FIFA_GET: realiza un GET HTTP a la API REST de la FIFA
  (https://api.fifa.com/api/v3) vía MSXML2.ServerXMLHTTP y devuelve el JSON.
- persona.sp_IMPORTAR_CUERPO_TECNICO_API: importa el cuerpo técnico oficial
  (Director Técnico y Asistentes) de cada selección del Mundial 2026:
  1. GET /competitions/teams/17?idSeason=285023 -> selecciones del torneo
     (IdTeam de la FIFA + código FIFA de la asociación, ej. ARG, GER, ENG).
  2. GET /teams/{IdTeam}/squad?idCompetition=17&idSeason=285023 -> por cada
     selección, el array "Officials" (Role 0 = Director Técnico, 1 = Asistente).
- Los códigos de la API ya son códigos FIFA, iguales a los de geografia.PAIS y
  torneo.SELECCION. Si la nacionalidad de un integrante no existe en
  geografia.PAIS, se usa el país de la selección (fallback por FK_PERSONA_PAIS).
- Reutiliza persona.sp_CUERPO_TECNICO_ABM (Entrega 5) con lógica de Upsert
  ('A' = Alta / 'M' = Modificación).
- Tolerancia a fallos parciales: si falla la descarga de una selección o el ABM
  rechaza una fila, se registra en auditoria.LOG_IMPORTACION y se continúa.
================================================================================
*/

USE DB_Mundial2026_Grupo10;
GO

EXEC sp_configure 'show advanced options', 1;
RECONFIGURE WITH OVERRIDE;
EXEC sp_configure 'Ole Automation Procedures', 1;
RECONFIGURE WITH OVERRIDE;
GO

-- ============================================================================
-- 1. PROCEDIMIENTO AUXILIAR: GET HTTP A LA API REST DE LA FIFA
-- ============================================================================
CREATE OR ALTER PROCEDURE persona.sp_API_FIFA_GET
    @Url  VARCHAR(500),
    @Json NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Object  INT = NULL;
    DECLARE @HResult INT;
    DECLARE @Status  INT;
    DECLARE @Msg     NVARCHAR(4000);
    DECLARE @ErrSrc  VARCHAR(255);
    DECLARE @ErrDesc VARCHAR(2000);

    DECLARE @ResponseTable TABLE (JsonText NVARCHAR(MAX));

    SET @Json = NULL;

    BEGIN TRY
        EXEC @HResult = sp_OACreate 'MSXML2.ServerXMLHTTP.6.0', @Object OUT;
        IF @HResult <> 0
            THROW 50020, 'No se pudo inicializar MSXML2.ServerXMLHTTP.6.0.', 1;

        -- Timeouts en ms: resolve (15s), connect (15s), send (30s), receive (60s)
        EXEC sp_OAMethod @Object, 'setTimeouts', NULL, 15000, 15000, 30000, 60000;

        EXEC @HResult = sp_OAMethod @Object, 'open', NULL, 'GET', @Url, 'false';
        IF @HResult <> 0
            THROW 50021, 'Error al abrir conexión HTTP con la API de la FIFA.', 1;

        EXEC sp_OAMethod @Object, 'setRequestHeader', NULL, 'Accept', 'application/json';
        EXEC sp_OAMethod @Object, 'setRequestHeader', NULL, 'User-Agent', 'UNLaM-Mundial2026-Grupo10/1.0 (https://unlam.edu.ar)';

        EXEC @HResult = sp_OAMethod @Object, 'send';
        IF @HResult <> 0
        BEGIN
            EXEC sp_OAGetErrorInfo @Object, @ErrSrc OUT, @ErrDesc OUT;
            SET @Msg = CONCAT('Error al enviar solicitud HTTP a la API de la FIFA (', ISNULL(@ErrSrc, 'OLE'), '): ', ISNULL(@ErrDesc, 'Sin detalle'));
            THROW 50022, @Msg, 1;
        END;

        EXEC sp_OAGetProperty @Object, 'status', @Status OUT;
        IF @Status <> 200
        BEGIN
            SET @Msg = CONCAT('La API de la FIFA devolvió HTTP ', ISNULL(@Status, 0), ' para ', @Url);
            THROW 50023, @Msg, 1;
        END;

        INSERT INTO @ResponseTable (JsonText)
        EXEC sp_OAGetProperty @Object, 'responseText';

        EXEC sp_OADestroy @Object;
        SET @Object = NULL;

        SELECT TOP 1 @Json = JsonText FROM @ResponseTable;

        IF @Json IS NULL OR ISJSON(@Json) = 0
            THROW 50024, 'La respuesta JSON de la API fue truncada o inválida.', 1;
    END TRY
    BEGIN CATCH
        IF @Object IS NOT NULL
        BEGIN
            EXEC sp_OADestroy @Object;
            SET @Object = NULL;
        END;

        THROW;
    END CATCH;
END;
GO

-- ============================================================================
-- 2. PROCEDIMIENTO: IMPORTACIÓN DE CUERPOS TÉCNICOS DESDE LA API DE LA FIFA
-- ============================================================================
CREATE OR ALTER PROCEDURE persona.sp_IMPORTAR_CUERPO_TECNICO_API
    @SoloSeleccionesEnBD BIT = 1,
    @IdTemporada         VARCHAR(20) = '285023'   -- Copa Mundial de la FIFA 2026 (idCompetition = 17)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Proceso      VARCHAR(100) = 'persona.sp_IMPORTAR_CUERPO_TECNICO_API';
    DECLARE @UrlBase      VARCHAR(100) = 'https://api.fifa.com/api/v3';
    DECLARE @Url          VARCHAR(500);
    DECLARE @JsonResponse NVARCHAR(MAX);
    DECLARE @Msg          NVARCHAR(4000);

    DECLARE @Equipos TABLE (
        nro_fila     INT IDENTITY(1,1) PRIMARY KEY,
        id_team_fifa VARCHAR(20),
        codigo_fifa  CHAR(3)
    );

    DECLARE @ApiStaging TABLE (
        codigo_fifa      CHAR(3),
        id_coach         VARCHAR(20),
        nombre_completo  NVARCHAR(200),
        fecha_nacimiento VARCHAR(30),
        id_pais_nac      VARCHAR(3),
        rol              INT
    );

    DECLARE @CuerpoTecnico TABLE (
        nro_fila             INT IDENTITY(1,1) PRIMARY KEY,
        nro_doc              VARCHAR(20),
        id_nacionalidad_pais CHAR(3),
        entrenadorLabel      NVARCHAR(200),
        fecha_nacimiento     VARCHAR(30),
        codigo_fifa          CHAR(3),
        id_seleccion         INT,
        cargo_tecnico        VARCHAR(40)
    );

    PRINT '  INICIO CONSUMO DE API REST FIFA PARA CUERPOS TÉCNICOS                 ';

    -- 0. Validación: sin selecciones cargadas no hay a quién asignar el cuerpo técnico
    IF @SoloSeleccionesEnBD = 1 AND NOT EXISTS (SELECT 1 FROM torneo.SELECCION)
    BEGIN
        SET @Msg = N'No hay selecciones cargadas en torneo.SELECCION. Ejecute antes la importación de selecciones.';
        INSERT INTO auditoria.LOG_IMPORTACION (proceso_origen, nro_fila, clave_registro, mensaje_error, linea_error)
        VALUES (@Proceso, NULL, 'SIN_SELECCIONES', @Msg, NULL);
        THROW 50019, @Msg, 1;
    END;

    -- 1. Selecciones del torneo
    BEGIN TRY
        SET @Url = CONCAT(@UrlBase, '/competitions/teams/17?idSeason=', @IdTemporada, '&language=es');
        PRINT '  Endpoint API: ' + @Url;

        EXEC persona.sp_API_FIFA_GET @Url = @Url, @Json = @JsonResponse OUTPUT;

        INSERT INTO @Equipos (id_team_fifa, codigo_fifa)
        SELECT E.IdTeam, E.IdAssociation
        FROM OPENJSON(@JsonResponse, '$.Results')
        WITH (
            IdTeam        VARCHAR(20) '$.IdTeam',
            IdAssociation CHAR(3)     '$.IdAssociation'
        ) E
        WHERE @SoloSeleccionesEnBD = 0
           OR EXISTS (SELECT 1 FROM torneo.SELECCION S WHERE S.id_pais = E.IdAssociation)
        ORDER BY E.IdAssociation;

        PRINT CONCAT('--> [OK] Selecciones descargadas desde la API REST de la FIFA: ', @@ROWCOUNT);
    END TRY
    BEGIN CATCH
        SET @Msg = CONCAT('Error al descargar las selecciones desde la API REST de la FIFA: ', ERROR_MESSAGE());
        INSERT INTO auditoria.LOG_IMPORTACION (proceso_origen, nro_fila, clave_registro, mensaje_error, linea_error)
        VALUES (@Proceso, NULL, 'API_HTTP_ERROR', @Msg, ERROR_LINE());
        THROW 50025, @Msg, 1;
    END CATCH;

    IF NOT EXISTS (SELECT 1 FROM @Equipos)
    BEGIN
        SET @Msg = N'La API REST de la FIFA no devolvió selecciones para importar.';
        INSERT INTO auditoria.LOG_IMPORTACION (proceso_origen, nro_fila, clave_registro, mensaje_error, linea_error)
        VALUES (@Proceso, NULL, 'API_SIN_DATOS', @Msg, NULL);
        THROW 50026, @Msg, 1;
    END;

    -- 2. Cuerpo técnico de cada selección
    DECLARE @FilaEq INT = 1, @TotalEq INT = (SELECT COUNT(*) FROM @Equipos);
    DECLARE @IdTeam VARCHAR(20), @CodEq CHAR(3), @ErrEq INT = 0;

    WHILE @FilaEq <= @TotalEq
    BEGIN
        SELECT @IdTeam = id_team_fifa, @CodEq = codigo_fifa
        FROM @Equipos
        WHERE nro_fila = @FilaEq;

        BEGIN TRY
            SET @Url = CONCAT(@UrlBase, '/teams/', @IdTeam, '/squad?idCompetition=17&idSeason=', @IdTemporada, '&language=es');

            EXEC persona.sp_API_FIFA_GET @Url = @Url, @Json = @JsonResponse OUTPUT;

            INSERT INTO @ApiStaging (codigo_fifa, id_coach, nombre_completo, fecha_nacimiento, id_pais_nac, rol)
            SELECT @CodEq, O.IdCoach, O.Nombre, O.BirthDate, O.IdCountry, O.Role
            FROM OPENJSON(@JsonResponse, '$.Officials')
            WITH (
                IdCoach   VARCHAR(20)   '$.IdCoach',
                Nombre    NVARCHAR(200) '$.Name[0].Description',
                BirthDate VARCHAR(30)   '$.BirthDate',
                IdCountry VARCHAR(3)    '$.IdCountry',
                Role      INT           '$.Role'
            ) O;
        END TRY
        BEGIN CATCH
            SET @ErrEq += 1;
            INSERT INTO auditoria.LOG_IMPORTACION (proceso_origen, nro_fila, clave_registro, mensaje_error, linea_error)
            VALUES (@Proceso, @FilaEq, LEFT(CONCAT('API_HTTP_ERROR - ', @CodEq, ' (IdTeam ', @IdTeam, ')'), 100), ERROR_MESSAGE(), ERROR_LINE());
        END CATCH;

        SET @FilaEq += 1;
    END;

    IF NOT EXISTS (SELECT 1 FROM @ApiStaging)
    BEGIN
        SET @Msg = N'La API REST de la FIFA no devolvió registros de cuerpo técnico para importar.';
        INSERT INTO auditoria.LOG_IMPORTACION (proceso_origen, nro_fila, clave_registro, mensaje_error, linea_error)
        VALUES (@Proceso, NULL, 'API_SIN_DATOS', @Msg, NULL);
        THROW 50026, @Msg, 1;
    END;

    -- 3. Depuración
    INSERT INTO @CuerpoTecnico (nro_doc, id_nacionalidad_pais, entrenadorLabel, fecha_nacimiento,
                                codigo_fifa, id_seleccion, cargo_tecnico)
    SELECT
        LEFT('FIFA' + A.id_coach, 20),
        CASE WHEN EXISTS (SELECT 1 FROM geografia.PAIS P WHERE P.id_pais = A.id_pais_nac)
             THEN A.id_pais_nac
             ELSE A.codigo_fifa
        END,
        A.nombre_completo,
        A.fecha_nacimiento,
        A.codigo_fifa,
        S.id_seleccion,
        CASE A.rol
            WHEN 0 THEN 'Director Técnico'
            WHEN 1 THEN 'Asistente Técnico'
            ELSE 'Integrante del Cuerpo Técnico'
        END
    FROM (
        SELECT ST.*,
               ROW_NUMBER() OVER (PARTITION BY ST.id_coach ORDER BY ST.rol, ST.codigo_fifa) AS rn
        FROM @ApiStaging ST
        WHERE ST.id_coach IS NOT NULL
    ) A
    LEFT JOIN torneo.SELECCION S ON S.id_pais = A.codigo_fifa
    WHERE A.rn = 1
    ORDER BY A.codigo_fifa, A.rol;

    -- 4. Alta / Modificación fila por fila con persona.sp_CUERPO_TECNICO_ABM
    DECLARE @FilaAPI INT = 1, @TotalAPI INT = (SELECT COUNT(*) FROM @CuerpoTecnico);
    DECLARE @AltasAPI INT = 0, @ModAPI INT = 0, @ErrAPI INT = 0, @SinDT INT = 0;
    DECLARE @DocAPI VARCHAR(20), @PaisNacAPI CHAR(3), @LabelAPI NVARCHAR(200),
            @FechaTxtAPI VARCHAR(30), @FechaAPI DATE, @PaisSelAPI CHAR(3),
            @CargoAPI VARCHAR(40), @NombreAPI VARCHAR(50), @ApellidoAPI VARCHAR(50),
            @IdSelAPI INT, @AccionAPI CHAR(1), @PosAPI INT;

    WHILE @FilaAPI <= @TotalAPI
    BEGIN
        SELECT
            @DocAPI      = nro_doc,
            @PaisNacAPI  = id_nacionalidad_pais,
            @LabelAPI    = entrenadorLabel,
            @FechaTxtAPI = fecha_nacimiento,
            @PaisSelAPI  = codigo_fifa,
            @IdSelAPI    = id_seleccion,
            @CargoAPI    = cargo_tecnico
        FROM @CuerpoTecnico
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

    -- 5. Auditoría de selecciones
    INSERT INTO auditoria.LOG_IMPORTACION (proceso_origen, nro_fila, clave_registro, mensaje_error, linea_error)
    SELECT
        @Proceso,
        NULL,
        LEFT(CONCAT('SIN_DT - ', S.id_pais, ' ', S.nombre_seleccion), 100),
        'La API de la FIFA no devolvió un Director Técnico para esta selección.',
        NULL
    FROM torneo.SELECCION S
    WHERE NOT EXISTS (SELECT 1
                      FROM @CuerpoTecnico C
                      WHERE C.id_seleccion = S.id_seleccion
                        AND C.cargo_tecnico = 'Director Técnico');

    SET @SinDT = @@ROWCOUNT;

    DECLARE @CantDT INT = (SELECT COUNT(*) FROM @CuerpoTecnico WHERE cargo_tecnico = 'Director Técnico');
    DECLARE @CantAT INT = (SELECT COUNT(*) FROM @CuerpoTecnico WHERE cargo_tecnico = 'Asistente Técnico');

    PRINT CONCAT('--> Origen: API_REST_FIFA',
                 ' | Selecciones: ', @TotalEq,
                 ' | Selecciones con error HTTP: ', @ErrEq,
                 ' | DTs: ', @CantDT,
                 ' | Asistentes: ', @CantAT,
                 ' | Altas: ', @AltasAPI,
                 ' | Modificados (Upsert): ', @ModAPI,
                 ' | Con error (Auditoría): ', @ErrAPI,
                 ' | Selecciones sin DT: ', @SinDT);
END;
GO