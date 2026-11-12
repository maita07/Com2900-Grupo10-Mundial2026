/*
---------------------------------------------------------
UNLaM - Universidad Nacional de La Matanza
Departamento de Ingeniería e Investigaciones Tecnológicas
Materia: Base de Datos Aplicada (Comisión 5600)
Entrega 6 - Importación de Arbitros (CSV / BULK INSERT)
2026 - 2C
Grupo 10

Integrantes:
- Monasterio Erik: MonasteryEr
- Arena Ariel Ignacio: arielarena
- Castillo Gabriela Florencia: ItsFlorencia
- Maita Pitado Jose Gregorio: maita07

Descripcion: Stored Procedure de importación masiva de Arbitros
             desde archivos CSV y HTML (scraping) utilizando BULK INSERT y Staging Tables,
             con registro de errores en auditoria.LOG_IMPORTACION.
---------------------------------------------------------
*/

USE DB_Mundial2026_Grupo10;
GO
 
CREATE OR ALTER PROCEDURE persona.sp_IMPORTAR_ARBITROS
    @RutaArchivoCSV      VARCHAR(500),               -- Info de los arbitros (Wikidata)
    @RutaArchivoHTML     VARCHAR(500),               -- HTML para obtener el rol (Wikipedia)
    @RutaCSV_Paises      VARCHAR(500) = NULL,        -- Para los paises que faltan
    @UrlApiFifa          VARCHAR(500) = 'https://api.fifa.com/api/v3/calendar/matches?idCompetition=17&idSeason=285023&count=500&language=en',
    @RutaArchivoJSON     VARCHAR(500) = NULL,        -- Alternativa a la API: la respuesta guardada como archivo
    @IdRolPrincipal      INT          = 1,
    @IdRolAsistente      INT          = 2,
    @IdRolCuarto         INT          = 3,
    @IdRolVAR            INT          = 4,
    @CategoriaFifa       VARCHAR(50)  = 'FIFA',      -- Las fuentes no lo dicen
    @AniosExperiencia    INT          = NULL,        -- NULL = se genera entre @AniosMin y @AniosMax
    @AniosMin            INT          = 5,
    @AniosMax            INT          = 20,
    @TipoDoc             VARCHAR(10)  = 'PASAPORTE', -- Tipo de documento generico
    @FechaNacDesconocida DATE         = '1900-01-01'
AS
BEGIN
    SET NOCOUNT ON;
 
    DECLARE @Proceso VARCHAR(100) = 'persona.sp_IMPORTAR_ARBITROS';
    DECLARE @Sql NVARCHAR(MAX);
    DECLARE @Msg NVARCHAR(4000);
    DECLARE @Total INT = 0, @Fila INT = 1;
    DECLARE @Altas INT = 0, @Modificados INT = 0, @Errores INT = 0;
    DECLARE @TotalD INT = 0, @AltasD INT = 0, @ModificadosD INT = 0, @ErroresD INT = 0;
 
    -- Variables para el HTML y la API
    DECLARE @Bin VARBINARY(MAX), @Html NVARCHAR(MAX), @Json NVARCHAR(MAX);
    DECLARE @T1 NVARCHAR(MAX), @T2 NVARCHAR(MAX), @P1 INT, @P2 INT;
    DECLARE @Obj INT, @HResult INT, @Status INT;
    DECLARE @Respuesta TABLE (txt NVARCHAR(MAX));
 
    -- Variables de trabajo por fila
    DECLARE @NroDoc VARCHAR(20), @Apellido VARCHAR(50), @Nombre VARCHAR(50),
            @NombreCompleto NVARCHAR(200), @IdPais CHAR(3), @IdRol INT, @ClaveLog NVARCHAR(300);
    DECLARE @IdRolAux INT, @DescRolAux VARCHAR(40);
    DECLARE @Fecha DATE, @Accion CHAR(1), @Pos INT;
    DECLARE @ErroresFila NVARCHAR(MAX);
    DECLARE @AniosFila INT;
    DECLARE @IdFase INT, @NroPartido INT;
 
    PRINT '     IMPORTACIÓN: ÁRBITROS Y DESIGNACIONES (API FIFA + WIKIPEDIA + WIKIDATA)     ';
 
    -- 0. Validacion de parametros
    IF @RutaArchivoCSV IS NULL OR TRIM(@RutaArchivoCSV) = ''
        THROW 50010, 'Debe indicar la ruta del archivo CSV de árbitros (@RutaArchivoCSV).', 1;
    IF @RutaArchivoHTML IS NULL OR TRIM(@RutaArchivoHTML) = ''
        THROW 50019, 'Debe indicar la ruta del HTML de Wikipedia (@RutaArchivoHTML).', 1;
    IF (@UrlApiFifa IS NULL OR TRIM(@UrlApiFifa) = '') AND (@RutaArchivoJSON IS NULL OR TRIM(@RutaArchivoJSON) = '')
        THROW 50020, 'Debe indicar la URL de la API de FIFA (@UrlApiFifa) o un archivo JSON (@RutaArchivoJSON).', 1;
 
    -- 1. Tablas temporales de staging
    CREATE TABLE #RawArbitro (
        articulo VARCHAR(500), itemLabel VARCHAR(200), fecha_nacimiento VARCHAR(50),
        paisLabel VARCHAR(200), codigo_pais VARCHAR(50)
    );
 
    CREATE TABLE #Wiki (
        id_wiki  INT IDENTITY(1,1) PRIMARY KEY,
        nombre   NVARCHAR(200) COLLATE DATABASE_DEFAULT,
        apellido NVARCHAR(100) COLLATE DATABASE_DEFAULT,
        id_pais  CHAR(3)       COLLATE DATABASE_DEFAULT NULL,
        id_rol   INT,
        articulo NVARCHAR(500) COLLATE DATABASE_DEFAULT NULL
    );
 
    CREATE TABLE #FifaDesig (
        nro_partido   INT,
        id_fase       INT NULL,
        cod_local     CHAR(3)       COLLATE DATABASE_DEFAULT,
        cod_visitante CHAR(3)       COLLATE DATABASE_DEFAULT,
        id_oficial    VARCHAR(12)   COLLATE DATABASE_DEFAULT,
        tipo          INT,
        id_pais       CHAR(3)       COLLATE DATABASE_DEFAULT,
        nombre        NVARCHAR(200) COLLATE DATABASE_DEFAULT,
        nombre_corto  NVARCHAR(200) COLLATE DATABASE_DEFAULT
    );
 
    CREATE TABLE #Oficial (
        id_oficial     VARCHAR(12)   COLLATE DATABASE_DEFAULT PRIMARY KEY,
        id_pais        CHAR(3)       COLLATE DATABASE_DEFAULT,
        nombre         NVARCHAR(200) COLLATE DATABASE_DEFAULT,
        apellido_corto NVARCHAR(100) COLLATE DATABASE_DEFAULT,
        apellido_largo NVARCHAR(100) COLLATE DATABASE_DEFAULT,
        id_rol_fifa    INT
    );
 
    CREATE TABLE #Match (id_oficial VARCHAR(12) COLLATE DATABASE_DEFAULT, id_wiki INT);
 
    CREATE TABLE #Arbitro (
        nro_fila         INT NOT NULL PRIMARY KEY,
        nro_doc          VARCHAR(20)   COLLATE DATABASE_DEFAULT,
        nombre_completo  NVARCHAR(200) COLLATE DATABASE_DEFAULT,
        fecha_nacimiento DATE,
        id_pais          CHAR(3)       COLLATE DATABASE_DEFAULT,
        id_rol           INT,
        clave_log        NVARCHAR(300) COLLATE DATABASE_DEFAULT
    );
 
    CREATE TABLE #Designacion (
        nro_fila    INT NOT NULL PRIMARY KEY,
        id_fase     INT NULL,
        nro_partido INT NULL,
        nro_doc     VARCHAR(20)   COLLATE DATABASE_DEFAULT,
        id_rol      INT,
        detalle     NVARCHAR(300) COLLATE DATABASE_DEFAULT
    );
 
    -- 2. Carga del CSV (SQL dinamico necesario para BULK INSERT)
    BEGIN TRY
        SET @Sql = N'BULK INSERT #RawArbitro FROM ''' + REPLACE(@RutaArchivoCSV, '''', '''''') + N'''
                     WITH (FORMAT = ''CSV'',
                           FIELDQUOTE = ''"'',
                           FIELDTERMINATOR = '','',
                           FIRSTROW = 2,
                           CODEPAGE = ''65001'',
                           TABLOCK);';
        EXEC sp_executesql @Sql;
    END TRY
    BEGIN CATCH
        SET @Msg = CONCAT('No se pudo leer el archivo "', @RutaArchivoCSV, '": ', ERROR_MESSAGE());
 
        INSERT INTO auditoria.LOG_IMPORTACION (proceso_origen, nro_fila, clave_registro, mensaje_error, linea_error)
        VALUES (@Proceso, NULL, NULL, @Msg, ERROR_LINE());
 
        THROW 50011, @Msg, 1;
    END CATCH;
 
    -- 3a. Lectura del HTML (tabla 1: arbitros y asistentes, tabla 2: VAR)
    BEGIN TRY
        -- SQL dinamico necesario para OPENROWSET(BULK)
        SET @Sql = N'SELECT @B = BulkColumn
                     FROM OPENROWSET(BULK ''' + REPLACE(@RutaArchivoHTML, '''', '''''') + N''', SINGLE_BLOB) AS T;';
        EXEC sp_executesql @Sql, N'@B VARBINARY(MAX) OUTPUT', @B = @Bin OUTPUT;
 
        -- Conversion UTF-8 a NVARCHAR para conservar los acentos
        SET @Html = CAST(CAST('<?xml version="1.0" encoding="UTF-8"?><r><![CDATA[' AS VARBINARY(MAX)) + @Bin
                         + CAST(']]></r>' AS VARBINARY(MAX)) AS XML).value('(/r)[1]', 'NVARCHAR(MAX)');
 
        SET @P1 = CHARINDEX(N'<table class="wikitable', @Html);
        SET @P2 = CASE WHEN @P1 > 0 THEN CHARINDEX(N'<table class="wikitable', @Html, @P1 + 1) ELSE 0 END;
 
        IF @P1 = 0 OR @P2 = 0
            THROW 50016, 'No se encontraron las tablas de árbitros y de VAR en el HTML.', 1;
 
        SET @T1 = SUBSTRING(@Html, @P1, CHARINDEX(N'</table>', @Html, @P1) - @P1);
        SET @T2 = SUBSTRING(@Html, @P2, CHARINDEX(N'</table>', @Html, @P2) - @P2);
    END TRY
    BEGIN CATCH
        SET @Msg = CONCAT('No se pudo procesar el HTML "', @RutaArchivoHTML, '": ', ERROR_MESSAGE());
 
        INSERT INTO auditoria.LOG_IMPORTACION (proceso_origen, nro_fila, clave_registro, mensaje_error, linea_error)
        VALUES (@Proceso, NULL, NULL, @Msg, ERROR_LINE());
 
        THROW 50015, @Msg, 1;
    END CATCH;
 
    -- 3b. Carga de roles arbitrales (Upsert sp_ROL_ARBITRAL_ABM)
    DECLARE @Roles TABLE (id_rol INT PRIMARY KEY, descripcion VARCHAR(40));
 
    INSERT INTO @Roles (id_rol, descripcion)
    VALUES (@IdRolPrincipal, 'Árbitro principal'),
           (@IdRolAsistente, 'Árbitro asistente'),
           (@IdRolCuarto,    'Cuarto árbitro'),
           (@IdRolVAR,       'Árbitro de VAR');
 
    BEGIN TRY
        SELECT @IdRolAux = MIN(id_rol) FROM @Roles;
 
        WHILE @IdRolAux IS NOT NULL
        BEGIN
            SELECT @DescRolAux = descripcion FROM @Roles WHERE id_rol = @IdRolAux;
 
            IF NOT EXISTS (SELECT 1 FROM torneo.ROL_ARBITRAL WHERE id_rol = @IdRolAux)
                EXEC torneo.sp_ROL_ARBITRAL_ABM @Accion = 'A', @id_rol = @IdRolAux, @rol_descripcion = @DescRolAux;
            ELSE IF EXISTS (SELECT 1 FROM torneo.ROL_ARBITRAL
                            WHERE id_rol = @IdRolAux AND rol_descripcion <> @DescRolAux)
                EXEC torneo.sp_ROL_ARBITRAL_ABM @Accion = 'M', @id_rol = @IdRolAux, @rol_descripcion = @DescRolAux;
 
            SELECT @IdRolAux = MIN(id_rol) FROM @Roles WHERE id_rol > @IdRolAux;
        END;
    END TRY
    BEGIN CATCH
        SET @Msg = CONCAT('No se pudieron cargar los roles arbitrales: ', ERROR_MESSAGE());
 
        INSERT INTO auditoria.LOG_IMPORTACION (proceso_origen, nro_fila, clave_registro, mensaje_error, linea_error)
        VALUES (@Proceso, NULL, NULL, @Msg, ERROR_LINE());
 
        THROW 50017, @Msg, 1;
    END CATCH;
 
    -- 3c. Paises de arbitros/asistentes que no participan del torneo (PBI 2023 desde el CSV del Banco Mundial)
    DECLARE @PaisesExtra TABLE (n INT IDENTITY(1,1) PRIMARY KEY, id_pais CHAR(3), iso CHAR(3),
                                nombre VARCHAR(50), moneda VARCHAR(30), pbi DECIMAL(18,2) NULL);
    DECLARE @nPais INT = 1, @MaxPais INT, @CodPais CHAR(3), @NomPais VARCHAR(50),
            @MonPais VARCHAR(30), @PbiPais DECIMAL(18,2);
 
    INSERT INTO @PaisesExtra (id_pais, iso, nombre, moneda)
    VALUES ('ANG','AGO','Angola','Kwanza'),                     ('CMR','CMR','Camerún','Franco CFA'),
           ('CHI','CHL','Chile','Peso chileno'),                ('CHN','CHN','China','Yuan'),
           ('CRC','CRI','Costa Rica','Colón costarricense'),    ('SLV','SLV','El Salvador','Dólar estadounidense'),
           ('GAB','GAB','Gabón','Franco CFA'),                  ('HON','HND','Honduras','Lempira'),
           ('ITA','ITA','Italia','Euro'),                       ('NCA','NIC','Nicaragua','Córdoba'),
           ('PER','PER','Perú','Sol'),                          ('POL','POL','Polonia','Zloty'),
           ('ROU','ROU','Rumania','Leu rumano'),                ('SVN','SVN','Eslovenia','Euro'),
           ('TRI','TTO','Trinidad y Tobago','Dólar trinitense'),('UAE','ARE','Emiratos Árabes Unidos','Dirham'),
           ('VEN','VEN','Venezuela','Bolívar'),
           ('HUN','HUN','Hungría','Forint'),
           ('JAM','JAM','Jamaica','Dólar jamaiquino'),
           ('MTN','MRT','Mauritania','Uguiya');
 
    -- Lectura opcional del CSV. El PBI 2023 se toma contando campos desde el final de cada linea
    IF @RutaCSV_Paises IS NOT NULL AND TRIM(@RutaCSV_Paises) <> ''
    BEGIN
        BEGIN TRY
            CREATE TABLE #RawPaises (Linea NVARCHAR(MAX));
 
            SET @Sql = N'BULK INSERT #RawPaises FROM ''' + REPLACE(@RutaCSV_Paises, '''', '''''') + N'''
                         WITH (FIRSTROW = 5, ROWTERMINATOR = ''\n'', CODEPAGE = ''65001'');';
            EXEC sp_executesql @Sql;
 
            ;WITH L AS (
                SELECT X.n,
                       REVERSE(CASE WHEN RIGHT(T.s, 1) = ',' THEN LEFT(T.s, LEN(T.s) - 1) ELSE T.s END) AS rv,
                       SUBSTRING(T.s, 2, CHARINDEX('","', T.s) - 2) AS nom
                FROM @PaisesExtra X
                CROSS APPLY (SELECT TOP 1 RTRIM(REPLACE(Linea, CHAR(13), '')) AS s
                             FROM #RawPaises
                             WHERE Linea LIKE '%","' + X.iso + '","%NY.GDP.PCAP.CD%') T
            ),
            P AS (   -- rv empieza por el campo 2025; el siguiente es 2024 y el tercero 2023
                SELECT n, nom, rv, CHARINDEX(',', rv, CHARINDEX(',', rv) + 1) AS p2 FROM L
            ),
            Q AS (SELECT n, nom, rv, p2, CHARINDEX(',', rv, p2 + 1) AS p3 FROM P)
            UPDATE X
            SET nombre = LEFT(Q.nom, 50),
                pbi    = TRY_CAST(NULLIF(REPLACE(REVERSE(SUBSTRING(Q.rv, Q.p2 + 1, Q.p3 - Q.p2 - 1)), '"', ''), '') AS DECIMAL(18,2))
            FROM @PaisesExtra X
            INNER JOIN Q ON Q.n = X.n;
 
            DROP TABLE #RawPaises;
        END TRY
        BEGIN CATCH
            IF OBJECT_ID('tempdb..#RawPaises') IS NOT NULL DROP TABLE #RawPaises;
            -- los países se cargan igual con PBI = 0
            SET @Msg = CONCAT('No se pudo leer el CSV de países "', @RutaCSV_Paises, '": ', ERROR_MESSAGE());
            INSERT INTO auditoria.LOG_IMPORTACION (proceso_origen, nro_fila, clave_registro, mensaje_error, linea_error)
            VALUES (@Proceso, NULL, NULL, @Msg, ERROR_LINE());
        END CATCH;
    END;
 
    BEGIN TRY
        SELECT @MaxPais = MAX(n) FROM @PaisesExtra;
 
        WHILE @nPais <= @MaxPais
        BEGIN
            SELECT @CodPais = id_pais, @NomPais = nombre, @MonPais = moneda, @PbiPais = ISNULL(pbi, 0)
            FROM @PaisesExtra WHERE n = @nPais;
 
            IF NOT EXISTS (SELECT 1 FROM geografia.PAIS WHERE id_pais = @CodPais)
                EXEC geografia.sp_PAIS_ABM @Accion = 'A', @id_pais = @CodPais, @nombre_pais = @NomPais,
                                           @moneda_pais = @MonPais, @pbi_per_capita_actual = @PbiPais;
 
            SET @nPais += 1;
        END;
    END TRY
    BEGIN CATCH
        SET @Msg = CONCAT('No se pudieron cargar los países de árbitros: ', ERROR_MESSAGE());
 
        INSERT INTO auditoria.LOG_IMPORTACION (proceso_origen, nro_fila, clave_registro, mensaje_error, linea_error)
        VALUES (@Proceso, NULL, @CodPais, @Msg, ERROR_LINE());
 
        THROW 50018, @Msg, 1;
    END CATCH;
 
    -- 4. Personas de Wikipedia
    -- de aca sale nombre, pais, rol y link al articulo
    WITH Filas AS (
        SELECT T.tabla, SUBSTRING(F.value, CHARINDEX(N'<td', F.value), LEN(F.value)) AS r0
        FROM (VALUES (1, @T1), (2, @T2)) T(tabla, html)
        CROSS APPLY STRING_SPLIT(REPLACE(T.html, N'<tr', NCHAR(1)), NCHAR(1)) F
        WHERE CHARINDEX(N'<td', F.value) > 0
    ),
    Fila2 AS (   -- saltea la celda de confederacion (5 celdas en la tabla 1, 2 en la tabla 2)
        SELECT tabla,
               CASE WHEN (tabla = 1 AND LEN(r0) - LEN(REPLACE(r0, N'</td>', N'')) = 25)
                      OR (tabla = 2 AND LEN(r0) - LEN(REPLACE(r0, N'</td>', N'')) = 10)
                    THEN SUBSTRING(r0, CHARINDEX(N'</td>', r0) + 5, LEN(r0))
                    ELSE r0 END AS r1
        FROM Filas
    ),
    Celda1 AS (  -- td = primera celda (arbitro o VAR), resto = desde la segunda celda (asistentes)
        SELECT tabla,
               LEFT(r1, CHARINDEX(N'</td>', r1) - 1) AS td,
               SUBSTRING(r1, CHARINDEX(N'</td>', r1) + 5, LEN(r1)) AS resto
        FROM Fila2
    ),
    Celdas AS (
        SELECT CASE WHEN tabla = 1 THEN @IdRolPrincipal ELSE @IdRolVAR END AS id_rol,
               SUBSTRING(td, CHARINDEX(N'>', td) + 1, LEN(td)) AS contenido
        FROM Celda1
        UNION ALL
        SELECT @IdRolAsistente,
               CASE WHEN CHARINDEX(N'</td>', resto) > CHARINDEX(N'>', resto)
                    THEN SUBSTRING(resto, CHARINDEX(N'>', resto) + 1, CHARINDEX(N'</td>', resto) - CHARINDEX(N'>', resto) - 1)
                    ELSE N'' END
        FROM Celda1
        WHERE tabla = 1
    ),
    Partes AS (  -- una persona por <br>
        SELECT C.id_rol,
               CASE WHEN LTRIM(P.value) LIKE N'id=%' OR LTRIM(P.value) LIKE N'[/>]%'
                    THEN SUBSTRING(P.value, CHARINDEX(N'>', P.value) + 1, LEN(P.value))
                    ELSE P.value END AS parte
        FROM Celdas C
        CROSS APPLY STRING_SPLIT(REPLACE(C.contenido, N'<br', NCHAR(2)), NCHAR(2)) P
    ),
    UltParen AS (
        SELECT id_rol, parte, LEN(parte + N'x') - CHARINDEX(N'(', REVERSE(parte)) AS pp
        FROM Partes
        WHERE CHARINDEX(N'(', parte) > 0
    ),
    Segs AS (    -- seg = nombre, tail = (país)
        SELECT id_rol, LEFT(parte, pp - 1) AS seg, SUBSTRING(parte, pp, LEN(parte)) AS tail
        FROM UltParen
    ),
    Pos AS (
        SELECT id_rol, seg, tail,
               CHARINDEX(N'<a', seg) AS a1,
               CHARINDEX(N'>', seg, NULLIF(CHARINDEX(N'<a', seg), 0)) AS a2,
               CHARINDEX(N'href="', seg) AS h1,
               CHARINDEX(N'>', tail) AS t2,
               CHARINDEX(N'</a>', tail) AS t3
        FROM Segs
    ),
    Pers AS (
        SELECT id_rol,
               LTRIM(RTRIM(CASE WHEN a1 > 0 AND CHARINDEX(N'</a>', seg, a2) > a2
                                THEN SUBSTRING(seg, a2 + 1, CHARINDEX(N'</a>', seg, a2) - a2 - 1)
                                ELSE seg END)) AS nombre,
               LTRIM(RTRIM(CASE WHEN t3 > t2 THEN SUBSTRING(tail, t2 + 1, t3 - t2 - 1) ELSE N'' END)) AS pais,
               CASE WHEN a1 > 0 AND h1 > 0
                    THEN SUBSTRING(seg, h1 + 6, CHARINDEX(N'"', seg, h1 + 6) - h1 - 6) END AS href
        FROM Pos
    )
    INSERT INTO #Wiki (nombre, apellido, id_pais, id_rol, articulo)
    SELECT P.nombre,
           REPLACE(RIGHT(P.nombre, CHARINDEX(N' ', REVERSE(N' ' + P.nombre)) - 1), N'-', N''),   -- última palabra, sin guiones
           M.codigo,
           P.id_rol,
           LEFT(P.href, CHARINDEX(N'?', P.href + N'?') - 1)                                       -- link sin parámetros
    FROM Pers P
    LEFT JOIN (VALUES
        ('Algeria','ALG'), ('Angola','ANG'), ('Argentina','ARG'), ('Australia','AUS'), ('Belgium','BEL'),
        ('Brazil','BRA'), ('Cameroon','CMR'), ('Canada','CAN'), ('Chile','CHI'), ('China','CHN'),
        ('Colombia','COL'), ('Costa Rica','CRC'), ('Croatia','CRO'), ('Egypt','EGY'), ('El Salvador','SLV'),
        ('England','ENG'), ('France','FRA'), ('Gabon','GAB'), ('Germany','GER'), ('Honduras','HON'),
        ('Hungary','HUN'), ('Italy','ITA'), ('Jamaica','JAM'), ('Japan','JPN'), ('Jordan','JOR'),
        ('Mauritania','MTN'), ('Mexico','MEX'), ('Morocco','MAR'), ('Netherlands','NED'), ('New Zealand','NZL'),
        ('Nicaragua','NCA'), ('Norway','NOR'), ('Paraguay','PAR'), ('Peru','PER'), ('Poland','POL'),
        ('Portugal','POR'), ('Qatar','QAT'), ('Romania','ROU'), ('Saudi Arabia','KSA'), ('Slovenia','SVN'),
        ('South Africa','RSA'), ('Spain','ESP'), ('Sweden','SWE'), ('Switzerland','SUI'),
        ('Trinidad and Tobago','TRI'), ('United Arab Emirates','UAE'), ('United States','USA'),
        ('Uruguay','URU'), ('Uzbekistan','UZB'), ('Venezuela','VEN')
    ) M(pais, codigo) ON M.pais = P.pais COLLATE DATABASE_DEFAULT
    WHERE P.nombre <> N'';
 
    -- 5. API de FIFA (o la misma respuesta guardada como archivo)
    BEGIN TRY
        IF @RutaArchivoJSON IS NOT NULL AND TRIM(@RutaArchivoJSON) <> ''
        BEGIN
            SET @Sql = N'SELECT @B = BulkColumn
                         FROM OPENROWSET(BULK ''' + REPLACE(@RutaArchivoJSON, '''', '''''') + N''', SINGLE_BLOB) AS T;';
            EXEC sp_executesql @Sql, N'@B VARBINARY(MAX) OUTPUT', @B = @Bin OUTPUT;
 
            SET @Json = CAST(CAST('<?xml version="1.0" encoding="UTF-8"?><r><![CDATA[' AS VARBINARY(MAX)) + @Bin
                             + CAST(']]></r>' AS VARBINARY(MAX)) AS XML).value('(/r)[1]', 'NVARCHAR(MAX)');
        END
        ELSE
        BEGIN
            EXEC @HResult = sp_OACreate 'MSXML2.ServerXMLHTTP', @Obj OUT;
            IF @HResult <> 0 THROW 50021, 'No se pudo crear el objeto OLE HTTP.', 1;
 
            EXEC @HResult = sp_OAMethod @Obj, 'open', NULL, 'GET', @UrlApiFifa, 'false';
            IF @HResult <> 0 THROW 50022, 'Error al configurar la conexión HTTP con la API de FIFA.', 1;
 
            EXEC @HResult = sp_OAMethod @Obj, 'send';
            IF @HResult <> 0 THROW 50023, 'Error al enviar la solicitud HTTP a la API de FIFA.', 1;
 
            EXEC sp_OAGetProperty @Obj, 'status', @Status OUT;
            IF @Status <> 200
            BEGIN
                SET @Msg = CONCAT('La API de FIFA respondió con código HTTP ', ISNULL(@Status, 0), '.');
                THROW 50024, @Msg, 1;
            END;
 
            -- La respuesta supera los 8000 caracteres: se captura como resultado en una tabla
            INSERT INTO @Respuesta (txt) EXEC sp_OAGetProperty @Obj, 'responseText';
            EXEC sp_OADestroy @Obj;
            SET @Obj = NULL;
 
            SELECT TOP 1 @Json = txt FROM @Respuesta;
        END;
 
        IF @Json IS NULL OR ISJSON(@Json) <> 1
            THROW 50025, 'La respuesta de FIFA no es un JSON válido. Pruebe con @RutaArchivoJSON.', 1;
 
        INSERT INTO #FifaDesig (nro_partido, id_fase, cod_local, cod_visitante, id_oficial, tipo, id_pais, nombre, nombre_corto)
        SELECT M.MatchNumber,
               CASE M.Etapa WHEN 'First Stage'   THEN 1
                            WHEN 'Round of 32'   THEN 2
                            WHEN 'Round of 16'   THEN 3
                            WHEN 'Quarter-final' THEN 4
                            WHEN 'Semi-final'    THEN 5
                            WHEN 'Bronze final'  THEN 6
                            WHEN 'Final'         THEN 7 END,
               M.CodLocal, M.CodVisitante,
               O.OfficialId, O.OfficialType, O.IdCountry,
               LTRIM(RTRIM(O.Nombre)), LTRIM(RTRIM(O.NombreCorto))
        FROM OPENJSON(@Json, '$.Results')
             WITH (MatchNumber  INT           '$.MatchNumber',
                   Etapa        NVARCHAR(50)  '$.StageName[0].Description',
                   CodLocal     NVARCHAR(3)   '$.Home.Abbreviation',
                   CodVisitante NVARCHAR(3)   '$.Away.Abbreviation',
                   Officials    NVARCHAR(MAX) '$.Officials' AS JSON) M
        CROSS APPLY OPENJSON(M.Officials)
             WITH (OfficialId   NVARCHAR(12)  '$.OfficialId',
                   OfficialType INT           '$.OfficialType',
                   IdCountry    NVARCHAR(3)   '$.IdCountry',
                   Nombre       NVARCHAR(200) '$.Name[0].Description',
                   NombreCorto  NVARCHAR(200) '$.NameShort[0].Description') O;
 
        IF NOT EXISTS (SELECT 1 FROM #FifaDesig)
            THROW 50026, 'La respuesta de FIFA no contiene designaciones arbitrales.', 1;
    END TRY
    BEGIN CATCH
        IF @Obj IS NOT NULL EXEC sp_OADestroy @Obj;
        SET @Msg = CONCAT('No se pudo obtener la información de FIFA: ', ERROR_MESSAGE());
 
        INSERT INTO auditoria.LOG_IMPORTACION (proceso_origen, nro_fila, clave_registro, mensaje_error, linea_error)
        VALUES (@Proceso, NULL, LEFT(ISNULL(@RutaArchivoJSON, @UrlApiFifa), 100), @Msg, ERROR_LINE());
 
        THROW 50027, @Msg, 1;
    END CATCH;
 
    -- Un registro por arbitro de FIFA. El rol de FIFA se usa si no se encuentra en Wikipedia
    -- (tipos FIFA: 1 principal, 2-3 asistentes, 4 cuarto, 5 VAR, 6 asistente de reserva, 8-9 asistentes de VAR)
    INSERT INTO #Oficial (id_oficial, id_pais, nombre, apellido_corto, apellido_largo, id_rol_fifa)
    SELECT id_oficial, MAX(id_pais), MAX(nombre),
           REPLACE(RIGHT(MAX(nombre_corto), CHARINDEX(N' ', REVERSE(N' ' + MAX(nombre_corto))) - 1), N'-', N''),
           REPLACE(RIGHT(MAX(nombre),       CHARINDEX(N' ', REVERSE(N' ' + MAX(nombre)))       - 1), N'-', N''),
           CASE MIN(tipo) WHEN 1 THEN @IdRolPrincipal
                          WHEN 2 THEN @IdRolAsistente
                          WHEN 3 THEN @IdRolAsistente
                          WHEN 4 THEN @IdRolCuarto
                          WHEN 6 THEN @IdRolAsistente
                          ELSE @IdRolVAR END
    FROM #FifaDesig
    WHERE id_oficial IS NOT NULL
    GROUP BY id_oficial;
 
    -- 6. FIFA y Wikipedia
    -- mismo país y mismo apellido (no distingue acentos ni mayusculas)
    INSERT INTO #Match (id_oficial, id_wiki)
    SELECT O.id_oficial, W.id_wiki
    FROM #Oficial O
    INNER JOIN #Wiki W
            ON W.id_pais = O.id_pais
           AND (W.apellido COLLATE Latin1_General_CI_AI = O.apellido_corto COLLATE Latin1_General_CI_AI
             OR W.apellido COLLATE Latin1_General_CI_AI = O.apellido_largo COLLATE Latin1_General_CI_AI);
 
    -- Se descartan casos ambiguos
    DELETE M
    FROM #Match M
    WHERE EXISTS (SELECT 1 FROM #Match X WHERE X.id_oficial = M.id_oficial AND X.id_wiki <> M.id_wiki)
       OR EXISTS (SELECT 1 FROM #Match X WHERE X.id_wiki = M.id_wiki AND X.id_oficial <> M.id_oficial);
 
    -- 7. Arbitros a importar
    -- se importa principalmente de FIFA
    -- con rol y su articulo de Wikipedia y fecha de Wikidata cuando hay cruce
    INSERT INTO #Arbitro (nro_fila, nro_doc, nombre_completo, fecha_nacimiento, id_pais, id_rol, clave_log)
    SELECT ROW_NUMBER() OVER (ORDER BY O.id_oficial),
           'FIFA-' + O.id_oficial,
           ISNULL(W.nombre, O.nombre),
           ISNULL((SELECT MIN(TRY_CONVERT(DATE, LEFT(TRIM(R.fecha_nacimiento), 10), 23))
                   FROM #RawArbitro R
                   WHERE TRIM(R.articulo) COLLATE DATABASE_DEFAULT = W.articulo), @FechaNacDesconocida),
           O.id_pais,
           ISNULL(W.id_rol, O.id_rol_fifa),
           CONCAT(N'FIFA ', O.id_oficial, N' - ', O.nombre)
    FROM #Oficial O
    LEFT JOIN #Match M ON M.id_oficial = O.id_oficial
    LEFT JOIN #Wiki W  ON W.id_wiki = M.id_wiki;
 
    SELECT @Total = COUNT(*) FROM #Arbitro;
 
    IF @Total = 0
    BEGIN
        INSERT INTO auditoria.LOG_IMPORTACION (proceso_origen, nro_fila, clave_registro, mensaje_error, linea_error)
        VALUES (@Proceso, NULL, NULL, 'No hay árbitros para importar.', NULL);
 
        THROW 50012, 'No hay árbitros para importar.', 1;
    END;
 
    -- 8. Procesamiento de arbitros
    WHILE @Fila <= @Total
    BEGIN
        SELECT @NroDoc = nro_doc, @NombreCompleto = nombre_completo, @Fecha = fecha_nacimiento,
               @IdPais = id_pais, @IdRol = id_rol, @ClaveLog = clave_log
        FROM #Arbitro
        WHERE nro_fila = @Fila;
 
        BEGIN TRY
            SET @ErroresFila = N'';
 
            SET @Pos = CHARINDEX(N' ', ISNULL(@NombreCompleto, N''));
            IF @Pos > 0
            BEGIN
                SET @Nombre   = LEFT(LEFT(@NombreCompleto, @Pos - 1), 50);
                SET @Apellido = LEFT(SUBSTRING(@NombreCompleto, @Pos + 1, 200), 50);
            END
            ELSE
            BEGIN
                SET @Nombre   = LEFT(@NombreCompleto, 50);
                SET @Apellido = LEFT(@NombreCompleto, 50);
            END;
 
            -- Errores de formato/datos incompletos
            IF @NombreCompleto IS NULL OR @NombreCompleto = N''
                SET @ErroresFila += N'- nombre vacío. ';
            IF @IdPais IS NULL OR LEN(@IdPais) <> 3
                SET @ErroresFila += N'- país vacío o distinto de 3 caracteres. ';
            IF @IdRol IS NULL
                SET @ErroresFila += N'- no se pudo determinar el rol. ';
 
            IF LEN(@ErroresFila) > 0
            BEGIN
                SET @Msg = N'Error de formato en la fila ' + CAST(@Fila AS NVARCHAR(10)) + N': ' + @ErroresFila;
                THROW 50013, @Msg, 1;
            END;
 
            SET @AniosFila = ISNULL(@AniosExperiencia,
                                    @AniosMin + FLOOR(RAND(CAST(HASHBYTES('MD5', @NroDoc) AS INT)) * (@AniosMax - @AniosMin + 1)));
 
            -- Upsert
            IF EXISTS (SELECT 1 FROM persona.ARBITRO WHERE nro_doc = @NroDoc AND tipo_doc = UPPER(@TipoDoc))
                SET @Accion = 'M';
            ELSE
                SET @Accion = 'A';
 
            EXEC persona.sp_ARBITRO_ABM
                 @Accion               = @Accion,
                 @nro_doc              = @NroDoc,
                 @tipo_doc             = @TipoDoc,
                 @id_nacionalidad_pais = @IdPais,
                 @nombre               = @Nombre,
                 @apellido             = @Apellido,
                 @fecha_nacimiento     = @Fecha,
                 @id_rol               = @IdRol,
                 @categoria_fifa       = @CategoriaFifa,
                 @anios_experiencia    = @AniosFila;
 
            IF @Accion = 'A' SET @Altas += 1; ELSE SET @Modificados += 1;
        END TRY
        BEGIN CATCH
            SET @Errores += 1;
 
            INSERT INTO auditoria.LOG_IMPORTACION (proceso_origen, nro_fila, clave_registro, mensaje_error, linea_error)
            VALUES (@Proceso, @Fila, LEFT(@ClaveLog, 100), ERROR_MESSAGE(), ERROR_LINE());
        END CATCH;
 
        SET @Fila += 1;
    END;
 
    PRINT CONCAT('--> Árbitros leídos: ', @Total, ' | Altas: ', @Altas, ' | Modificaciones: ', @Modificados, ' | Con error: ', @Errores);
 
    -- 9. Designaciones por partido (FIFA: 1 principal, 2-3 asistentes, 4 cuarto, 5 VAR)
    --    se busca el numero de partido de FIFA por fase y selecciones porque no coincide con el del fixture
    INSERT INTO #Designacion (nro_fila, id_fase, nro_partido, nro_doc, id_rol, detalle)
    SELECT ROW_NUMBER() OVER (ORDER BY F.nro_partido, F.tipo),
           P.id_fase,
           P.nro_partido_fase,
           'FIFA-' + F.id_oficial,
           CASE F.tipo WHEN 1 THEN @IdRolPrincipal
                       WHEN 2 THEN @IdRolAsistente
                       WHEN 3 THEN @IdRolAsistente
                       WHEN 4 THEN @IdRolCuarto
                       ELSE @IdRolVAR END,
           CONCAT(N'FIFA n.', F.nro_partido, N' ', F.cod_local, N'-', F.cod_visitante, N' | ', F.nombre)
    FROM #FifaDesig F
    LEFT JOIN (torneo.PARTIDO P
               INNER JOIN torneo.SELECCION SL ON SL.id_seleccion = P.id_seleccion_local
               INNER JOIN torneo.SELECCION SV ON SV.id_seleccion = P.id_seleccion_visitante)
           ON P.id_fase = F.id_fase
          AND ((SL.id_pais = F.cod_local AND SV.id_pais = F.cod_visitante)
            OR (SL.id_pais = F.cod_visitante AND SV.id_pais = F.cod_local))
    WHERE F.tipo IN (1, 2, 3, 4, 5);
 
    SELECT @TotalD = COUNT(*) FROM #Designacion;
    SET @Fila = 1;
 
    WHILE @Fila <= @TotalD
    BEGIN
        SELECT @IdFase = id_fase, @NroPartido = nro_partido, @NroDoc = nro_doc,
               @IdRol = id_rol, @ClaveLog = detalle
        FROM #Designacion
        WHERE nro_fila = @Fila;
 
        BEGIN TRY
            IF @IdFase IS NULL OR @NroPartido IS NULL
                THROW 50028, 'El partido no existe en torneo.PARTIDO o sus selecciones no coinciden con las de FIFA.', 1;
 
            IF NOT EXISTS (SELECT 1 FROM persona.ARBITRO WHERE nro_doc = @NroDoc AND tipo_doc = UPPER(@TipoDoc))
                THROW 50029, 'El árbitro no se pudo importar (ver los errores de la etapa de árbitros).', 1;
 
            -- Upsert
            IF EXISTS (SELECT 1 FROM torneo.DESIGNACION_ARBITRAL
                       WHERE id_fase = @IdFase AND nro_partido_fase = @NroPartido
                         AND nro_doc = @NroDoc AND tipo_doc = UPPER(@TipoDoc))
                SET @Accion = 'M';
            ELSE
                SET @Accion = 'A';
 
            EXEC torneo.sp_DESIGNACION_ARBITRAL_ABM
                 @Accion           = @Accion,
                 @id_fase          = @IdFase,
                 @nro_partido_fase = @NroPartido,
                 @nro_doc          = @NroDoc,
                 @tipo_doc         = @TipoDoc,
                 @id_rol           = @IdRol;
 
            IF @Accion = 'A' SET @AltasD += 1; ELSE SET @ModificadosD += 1;
        END TRY
        BEGIN CATCH
            SET @ErroresD += 1;
 
            INSERT INTO auditoria.LOG_IMPORTACION (proceso_origen, nro_fila, clave_registro, mensaje_error, linea_error)
            VALUES (@Proceso, @Fila, LEFT(CONCAT(@ClaveLog, N' | rol ', @IdRol), 100), ERROR_MESSAGE(), ERROR_LINE());
        END CATCH;
 
        SET @Fila += 1;
    END;
 
    -- 10. Resumen
    PRINT CONCAT('--> Designaciones: ', @TotalD, ' | Altas: ', @AltasD, ' | Modificaciones: ', @ModificadosD, ' | Con error: ', @ErroresD);
 
    IF @Errores > 0 OR @ErroresD > 0
        PRINT '--> Hay registros rechazados. Ver auditoria.LOG_IMPORTACION (proceso_origen = ''persona.sp_IMPORTAR_ARBITROS'').';
 
    -- Si no se pudo importar ningun registro se informa como excepcion
    IF @Errores = @Total AND (@TotalD = 0 OR @ErroresD = @TotalD)
    BEGIN
        SET @Msg = N'No se pudo importar ningún árbitro ni designación. Revise auditoria.LOG_IMPORTACION.';
        THROW 50014, @Msg, 1;
    END;
 
    PRINT '             PROCESO DE IMPORTACIÓN FINALIZADO                          ';
END;
GO