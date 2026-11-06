/*
================================================================================
UNLaM - Base de Datos Aplicada (Comisión 5600)
Entrega 6 - Script 04_4: Importación masiva de Selecciones, Jugadores y Plantillas
2026 - 2C
Grupo 10

Integrantes:
- Monasterio Erik: MonasteryEr
- Arena Ariel Ignacio: arielarena
- Castillo Gabriela Florencia: ItsFlorencia
- Maita Pitado Jose Gregorio: maita07

Archivo: 04_4_IMPORT_SELECCIONES_JUGADORES.sql
Descripcion: 
- Módulo unificado de importación con rutas parametrizadas:
- torneo.sp_IMPORTAR_SELECCIONES_CSV: Carga y Upsert de Selecciones participantes.
- persona.sp_IMPORTAR_JUGADORES_CSV: Carga masiva de Jugadores y Convocatorias,
   cálculo de peso por IMC (22.0), generación de documento único y registro oficial.
- Rutas recibidas obligatoriamente por parámetro (sin rutas fijas ni defaults).
- Auditoría centralizada de errores en auditoria.LOG_IMPORTACION.
================================================================================
*/
USE DB_Mundial2026_Grupo10;
GO

-- 1. PROCEDIMIENTO: IMPORTACIÓN DE SELECCIONES (CSV)
CREATE OR ALTER PROCEDURE torneo.sp_IMPORTAR_SELECCIONES_CSV
    @RutaArchivo VARCHAR(500) -- Parámetro obligatorio sin default
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NombreProc VARCHAR(100) = 'torneo.sp_IMPORTAR_SELECCIONES_CSV';
    DECLARE @ErrLinea   INT;
    DECLARE @ErrMensaje NVARCHAR(4000);

    PRINT '  INICIO IMPORTACIÓN DE SELECCIONES (CSV)                               ';
    PRINT '  Archivo recibido por parámetro: ' + ISNULL(@RutaArchivo, 'NULL');

    -- Validación previa del parámetro obligatorio
    IF @RutaArchivo IS NULL OR LTRIM(RTRIM(@RutaArchivo)) = ''
    BEGIN
        SET @ErrMensaje = 'Debe indicar obligatoriamente la ruta del archivo CSV de selecciones (@RutaArchivo).';
        EXEC auditoria.sp_REGISTRAR_ERROR_IMPORTACION
            @proceso_origen = @NombreProc,
            @clave_registro = 'PARAMETRO_NULL',
            @mensaje_error  = @ErrMensaje,
            @linea_error    = 1;
        THROW 50010, @ErrMensaje, 1;
    END;

    -- 1. Tabla temporal de Staging
    IF OBJECT_ID('tempdb..#Teams') IS NOT NULL DROP TABLE #Teams;
    CREATE TABLE #Teams (
        team_id                     INT,
        team_name                   VARCHAR(100),
        fifa_code                   CHAR(3),
        group_letter                CHAR(1),
        confederation               VARCHAR(20),
        fifa_ranking_pre_tournament INT,
        elo_rating                  INT,
        manager_name                VARCHAR(100)
    );

    BEGIN TRY
        -- 2. Bulk Insert dinámico con soporte Unix (0x0a) y Windows (\r\n)
        DECLARE @SQL NVARCHAR(MAX) = N'
        BULK INSERT #Teams
        FROM ''' + REPLACE(@RutaArchivo, '''', '''''') + N'''
        WITH (
            FORMAT = ''CSV'',
            FIRSTROW = 2,
            CODEPAGE = ''65001'',
            ROWTERMINATOR = ''0x0a'',
            TABLOCK
        );';

        BEGIN TRY
            EXEC sys.sp_executesql @SQL;
        END TRY
        BEGIN CATCH
            SET @SQL = N'
            BULK INSERT #Teams
            FROM ''' + REPLACE(@RutaArchivo, '''', '''''') + N'''
            WITH (
                FIRSTROW = 2,
                FIELDTERMINATOR = '','',
                ROWTERMINATOR = ''\r\n'',
                CODEPAGE = ''65001'',
                TABLOCK
            );';
            EXEC sys.sp_executesql @SQL;
        END CATCH;

        -- 3. Validaciones de integridad
        IF NOT EXISTS (SELECT 1 FROM #Teams)
            THROW 50011, 'El archivo CSV no contiene registros de selecciones.', 1;

        IF EXISTS (
            SELECT 1 FROM #Teams
            WHERE team_id IS NULL OR team_name IS NULL OR fifa_code IS NULL
               OR group_letter IS NULL OR confederation IS NULL
        )
            THROW 50012, 'El CSV contiene campos obligatorios vacíos o nulos.', 1;

        IF EXISTS (SELECT team_id FROM #Teams GROUP BY team_id HAVING COUNT(*) > 1)
            THROW 50013, 'Existen identificadores (team_id) duplicados en el archivo.', 1;

        IF EXISTS (SELECT fifa_code FROM #Teams GROUP BY fifa_code HAVING COUNT(*) > 1)
            THROW 50014, 'Existen códigos FIFA duplicados en el archivo.', 1;

        IF EXISTS (
            SELECT 1 FROM #Teams T
            LEFT JOIN geografia.PAIS P ON P.id_pais = UPPER(LTRIM(RTRIM(T.fifa_code)))
            LEFT JOIN geografia.CONFEDERACION C ON C.sigla = UPPER(LTRIM(RTRIM(T.confederation)))
            WHERE P.id_pais IS NULL OR C.id_confederacion IS NULL
        )
            THROW 50015, 'Existen selecciones asociadas a países o confederaciones no registrados en la base.', 1;

        -- 4. Upsert transaccional en torneo.SELECCION
        BEGIN TRANSACTION;

        UPDATE S
        SET S.id_pais          = P.id_pais,
            S.id_confederacion = C.id_confederacion,
            S.nombre_seleccion = LTRIM(RTRIM(T.team_name)),
            S.grupo_asignado   = UPPER(LTRIM(RTRIM(T.group_letter)))
        FROM torneo.SELECCION S
        INNER JOIN #Teams T ON S.id_seleccion = T.team_id
        INNER JOIN geografia.PAIS P ON P.id_pais = UPPER(LTRIM(RTRIM(T.fifa_code)))
        INNER JOIN geografia.CONFEDERACION C ON C.sigla = UPPER(LTRIM(RTRIM(T.confederation)));

        INSERT INTO torneo.SELECCION (id_seleccion, id_confederacion, id_pais, nombre_seleccion, grupo_asignado)
        SELECT 
            T.team_id,
            C.id_confederacion,
            P.id_pais,
            LTRIM(RTRIM(T.team_name)),
            UPPER(LTRIM(RTRIM(T.group_letter)))
        FROM #Teams T
        INNER JOIN geografia.PAIS P ON P.id_pais = UPPER(LTRIM(RTRIM(T.fifa_code)))
        INNER JOIN geografia.CONFEDERACION C ON C.sigla = UPPER(LTRIM(RTRIM(T.confederation)))
        WHERE NOT EXISTS (
            SELECT 1 FROM torneo.SELECCION S
            WHERE S.id_seleccion = T.team_id
        );

        COMMIT TRANSACTION;

        DECLARE @CantSelecciones INT = (SELECT COUNT(*) FROM #Teams);
        PRINT '--> [OK] Selecciones importadas y actualizadas correctamente: ' + CAST(@CantSelecciones AS VARCHAR(10));

        DROP TABLE #Teams;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF OBJECT_ID('tempdb..#Teams') IS NOT NULL DROP TABLE #Teams;

        SET @ErrLinea   = ERROR_LINE();
        SET @ErrMensaje = 'Fallo en importación de selecciones CSV: ' + ERROR_MESSAGE();

        EXEC auditoria.sp_REGISTRAR_ERROR_IMPORTACION
            @proceso_origen = @NombreProc,
            @clave_registro = @RutaArchivo,
            @mensaje_error  = @ErrMensaje,
            @linea_error    = @ErrLinea;

        PRINT '--> ERROR REGISTRADO EN AUDITORÍA: ' + @ErrMensaje;
        THROW 50016, @ErrMensaje, 1;
    END CATCH;
END;
GO


-- 2. PROCEDIMIENTO: IMPORTACIÓN DE JUGADORES Y PLANTILLAS (CSV)
CREATE OR ALTER PROCEDURE persona.sp_IMPORTAR_JUGADORES_CSV
    @RutaCSV VARCHAR(500) -- Parámetro obligatorio sin default
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NombreProc VARCHAR(100) = 'persona.sp_IMPORTAR_JUGADORES_CSV';
    DECLARE @ErrLinea   INT;
    DECLARE @ErrMensaje NVARCHAR(4000);

    PRINT '  INICIO IMPORTACIÓN DE JUGADORES Y CONVOCATORIAS OFICIALES            ';
    PRINT '  Archivo recibido por parámetro: ' + ISNULL(@RutaCSV, 'NULL');
 
    -- Validación previa del parámetro obligatorio
    IF @RutaCSV IS NULL OR LTRIM(RTRIM(@RutaCSV)) = ''
    BEGIN
        SET @ErrMensaje = 'Debe indicar obligatoriamente la ruta del archivo CSV de jugadores (@RutaCSV).';
        EXEC auditoria.sp_REGISTRAR_ERROR_IMPORTACION
            @proceso_origen = @NombreProc,
            @clave_registro = 'PARAMETRO_NULL',
            @mensaje_error  = @ErrMensaje,
            @linea_error    = 1;
        THROW 50001, @ErrMensaje, 1;
    END;

    -- 1. Staging Temporal
    IF OBJECT_ID('tempdb..#STG_JUGADORES') IS NOT NULL DROP TABLE #STG_JUGADORES;
    CREATE TABLE #STG_JUGADORES (
        Team           NVARCHAR(200),
        Team_Code      NVARCHAR(20),
        Number         NVARCHAR(50),
        Position       NVARCHAR(100),
        Player_Name    NVARCHAR(200),
        First_Names    NVARCHAR(200),
        Last_Name      NVARCHAR(200),
        Name_on_Shirt  NVARCHAR(200),
        DOB            NVARCHAR(50),
        Club           NVARCHAR(200),
        Height_cm      NVARCHAR(50),
        Caps           NVARCHAR(50),
        Goals          NVARCHAR(50)
    );

    -- 2. Bulk Insert dinámico con fallback de formato
    DECLARE @SQL NVARCHAR(MAX) = N'
    BULK INSERT #STG_JUGADORES
    FROM ''' + REPLACE(@RutaCSV, '''', '''''') + N'''
    WITH (
        FORMAT = ''CSV'',
        FIRSTROW = 2,
        FIELDQUOTE = ''"'',
        CODEPAGE = ''65001'',
        ROWTERMINATOR = ''0x0a'',
        TABLOCK
    );';

    BEGIN TRY
        EXEC sp_executesql @SQL;
        PRINT '--> [OK] Archivo CSV leído en formato Unix (0x0a).';
    END TRY
    BEGIN CATCH
        SET @SQL = N'
        BULK INSERT #STG_JUGADORES
        FROM ''' + REPLACE(@RutaCSV, '''', '''''') + N'''
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = '','',
            ROWTERMINATOR = ''\r\n'',
            CODEPAGE = ''65001'',
            TABLOCK
        );';
        BEGIN TRY
            EXEC sp_executesql @SQL;
            PRINT '--> [OK] Archivo CSV leído en formato Windows (CRLF).';
        END TRY
        BEGIN CATCH
            SET @ErrLinea   = ERROR_LINE();
            SET @ErrMensaje = 'Fallo en lectura de archivo CSV en ' + @RutaCSV + ': ' + ERROR_MESSAGE();
            EXEC auditoria.sp_REGISTRAR_ERROR_IMPORTACION
                @proceso_origen = @NombreProc,
                @clave_registro = @RutaCSV,
                @mensaje_error  = @ErrMensaje,
                @linea_error    = @ErrLinea;
            THROW 50002, @ErrMensaje, 1;
        END CATCH;
    END CATCH;

    -- 3. Normalización y Homologación de Selecciones
    IF OBJECT_ID('tempdb..#JUGADORES_VALIDOS') IS NOT NULL DROP TABLE #JUGADORES_VALIDOS;
    CREATE TABLE #JUGADORES_VALIDOS (
        Team             VARCHAR(100),
        Team_Code        CHAR(3),
        Dorsal           INT,
        Posicion         VARCHAR(50),
        Nombres          VARCHAR(50),
        Apellidos        VARCHAR(50),
        FechaNacimiento  DATE,
        Club             VARCHAR(50),
        Altura           DECIMAL(5,2)
    );

    INSERT INTO #JUGADORES_VALIDOS (
        Team, Team_Code, Dorsal, Posicion, Nombres, Apellidos, FechaNacimiento, Club, Altura
    )
    SELECT 
        CASE 
            WHEN LTRIM(RTRIM(Team)) IN ('Korea Republic', 'Korea, Republic of', 'Korea') THEN 'South Korea'
            WHEN LTRIM(RTRIM(Team)) = 'Iran' THEN 'IR Iran'
            WHEN LTRIM(RTRIM(Team)) = 'Turkey' THEN 'Türkiye'
            WHEN LTRIM(RTRIM(Team)) = 'United States' THEN 'USA'
            ELSE LTRIM(RTRIM(Team))
        END,
        UPPER(LTRIM(RTRIM(Team_Code))),
        TRY_CONVERT(INT, Number),
        LTRIM(RTRIM(Position)),
        LEFT(LTRIM(RTRIM(First_Names)), 50),
        LEFT(LTRIM(RTRIM(Last_Name)), 50),
        TRY_CONVERT(DATE, DOB, 103),
        LEFT(LTRIM(RTRIM(Club)), 50),
        TRY_CONVERT(DECIMAL(5,2), Height_cm)
    FROM #STG_JUGADORES;

    -- 4. Validaciones de Integridad
    IF EXISTS (
        SELECT 1 FROM #JUGADORES_VALIDOS
        WHERE Team IS NULL OR Team = ''
           OR Nombres IS NULL OR Nombres = ''
           OR Apellidos IS NULL OR Apellidos = ''
           OR FechaNacimiento IS NULL
           OR Dorsal IS NULL OR Dorsal NOT BETWEEN 1 AND 99
           OR Posicion IS NULL OR Posicion = ''
           OR Club IS NULL OR Club = ''
           OR Altura IS NULL OR Altura <= 0
    )
    BEGIN
        SET @ErrLinea   = ERROR_LINE();
        SET @ErrMensaje = 'El archivo contiene registros con campos obligatorios vacíos o inconsistentes.';
        EXEC auditoria.sp_REGISTRAR_ERROR_IMPORTACION
            @proceso_origen = @NombreProc,
            @clave_registro = @RutaCSV,
            @mensaje_error  = @ErrMensaje,
            @linea_error    = @ErrLinea;
        THROW 50003, @ErrMensaje, 1;
    END;

    IF EXISTS (
        SELECT Team, Dorsal FROM #JUGADORES_VALIDOS
        GROUP BY Team, Dorsal HAVING COUNT(*) > 1
    )
    BEGIN
        SET @ErrLinea   = ERROR_LINE();
        SET @ErrMensaje = 'Se detectaron dorsales duplicados dentro de una misma selección en el archivo.';
        EXEC auditoria.sp_REGISTRAR_ERROR_IMPORTACION
            @proceso_origen = @NombreProc,
            @clave_registro = @RutaCSV,
            @mensaje_error  = @ErrMensaje,
            @linea_error    = @ErrLinea;
        THROW 50004, @ErrMensaje, 1;
    END;

    -- 5. Mapeo con DNI secuencial y Peso calculado por IMC (22.0)
    IF OBJECT_ID('tempdb..#MAPA_JUGADORES') IS NOT NULL DROP TABLE #MAPA_JUGADORES;
    CREATE TABLE #MAPA_JUGADORES (
        id_seleccion    INT,
        tipo_doc        VARCHAR(10),
        nro_doc         VARCHAR(20),
        Team_Code       CHAR(3),
        Nombres         VARCHAR(50),
        Apellidos       VARCHAR(50),
        FechaNacimiento DATE,
        Posicion        VARCHAR(30),
        Club            VARCHAR(50),
        Altura          DECIMAL(5,2),
        Peso            DECIMAL(5,2),
        Dorsal          INT
    );

    INSERT INTO #MAPA_JUGADORES (
        id_seleccion, tipo_doc, nro_doc, Team_Code, Nombres, Apellidos,
        FechaNacimiento, Posicion, Club, Altura, Peso, Dorsal
    )
    SELECT 
        s.id_seleccion,
        'DNI' AS tipo_doc,
        CAST(90000000 + ROW_NUMBER() OVER (
            ORDER BY j.Team_Code, j.Nombres, j.Apellidos, j.FechaNacimiento, j.Dorsal
        ) AS VARCHAR(20)) AS nro_doc,
        j.Team_Code,
        j.Nombres,
        j.Apellidos,
        j.FechaNacimiento,
        LEFT(j.Posicion, 30),
        j.Club,
        j.Altura,
        CAST(22.0 * POWER(j.Altura / 100.0, 2) AS DECIMAL(5,2)) AS Peso,
        j.Dorsal
    FROM #JUGADORES_VALIDOS j
    INNER JOIN torneo.SELECCION s ON s.nombre_seleccion = j.Team;

    DECLARE @TotalLeidos INT = (SELECT COUNT(*) FROM #MAPA_JUGADORES);
    PRINT '--> Total de jugadores a procesar: ' + CAST(@TotalLeidos AS VARCHAR(10));

    -- 6. Carga Transaccional
    BEGIN TRANSACTION;
    BEGIN TRY
        -- A. Superclase PERSONA
        UPDATE P
        SET P.nombre               = M.Nombres,
            P.apellido             = M.Apellidos,
            P.fecha_nacimiento     = M.FechaNacimiento,
            P.id_nacionalidad_pais = M.Team_Code
        FROM persona.PERSONA P
        INNER JOIN #MAPA_JUGADORES M 
            ON P.tipo_doc = M.tipo_doc AND P.nro_doc = M.nro_doc;

        INSERT INTO persona.PERSONA (
            tipo_doc, nro_doc, id_nacionalidad_pais, nombre, apellido, fecha_nacimiento, tipo_persona
        )
        SELECT 
            M.tipo_doc,
            M.nro_doc,
            M.Team_Code,
            M.Nombres,
            M.Apellidos,
            M.FechaNacimiento,
            'JUGADOR'
        FROM #MAPA_JUGADORES M
        WHERE NOT EXISTS (
            SELECT 1 FROM persona.PERSONA P 
            WHERE P.tipo_doc = M.tipo_doc AND P.nro_doc = M.nro_doc
        );

        -- B. Subclase JUGADOR
        UPDATE J
        SET J.posicion_habitual = M.Posicion,
            J.club_origen       = M.Club,
            J.peso_kg           = M.Peso,
            J.altura_cm         = M.Altura,
            J.es_convocado      = 1
        FROM persona.JUGADOR J
        INNER JOIN #MAPA_JUGADORES M 
            ON J.tipo_doc = M.tipo_doc AND J.nro_doc = M.nro_doc;

        INSERT INTO persona.JUGADOR (
            tipo_doc, nro_doc, posicion_habitual, club_origen, peso_kg, altura_cm, es_convocado
        )
        SELECT 
            M.tipo_doc,
            M.nro_doc,
            M.Posicion,
            M.Club,
            M.Peso,
            M.Altura,
            1
        FROM #MAPA_JUGADORES M
        WHERE NOT EXISTS (
            SELECT 1 FROM persona.JUGADOR J 
            WHERE J.tipo_doc = M.tipo_doc AND J.nro_doc = M.nro_doc
        );

        -- C. Convocatorias Oficiales
        UPDATE C
        SET C.tipo_doc            = M.tipo_doc,
            C.nro_doc             = M.nro_doc,
            C.estado_convocatoria = 'ACTIVO'
        FROM torneo.CONVOCATORIA C
        INNER JOIN #MAPA_JUGADORES M 
            ON C.id_seleccion = M.id_seleccion AND C.dorsal_oficial = M.Dorsal;

        INSERT INTO torneo.CONVOCATORIA (
            id_seleccion, dorsal_oficial, nro_doc, tipo_doc, estado_convocatoria
        )
        SELECT 
            M.id_seleccion,
            M.Dorsal,
            M.nro_doc,
            M.tipo_doc,
            'ACTIVO'
        FROM #MAPA_JUGADORES M
        WHERE NOT EXISTS (
            SELECT 1 FROM torneo.CONVOCATORIA C 
            WHERE C.id_seleccion = M.id_seleccion AND C.dorsal_oficial = M.Dorsal
        );

        COMMIT TRANSACTION;
        PRINT '--> [ÉXITO]: Jugadores y plantillas procesados correctamente.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        SET @ErrLinea   = ERROR_LINE();
        SET @ErrMensaje = 'Fallo en la transacción de carga de jugadores: ' + ERROR_MESSAGE();

        EXEC auditoria.sp_REGISTRAR_ERROR_IMPORTACION
            @proceso_origen = @NombreProc,
            @clave_registro = @RutaCSV,
            @mensaje_error  = @ErrMensaje,
            @linea_error    = @ErrLinea;

        THROW 50005, @ErrMensaje, 1;
    END CATCH;

    -- Limpieza de recursos temporales
    DROP TABLE #STG_JUGADORES;
    DROP TABLE #JUGADORES_VALIDOS;
    DROP TABLE #MAPA_JUGADORES;

    PRINT '  PROCESO DE IMPORTACIÓN FINALIZADO EXITOSAMENTE                        ';

END;
GO