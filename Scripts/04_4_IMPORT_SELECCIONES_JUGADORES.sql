/*
--------------------------------------------------------------------------------
UNLaM - Universidad Nacional de La Matanza
Departamento de Ingeniería e Investigaciones Tecnológicas
Materia: Base de Datos Aplicada (Comisión 5600)
Entrega 6 - Script 04_03: Importacion de Sedes, Estadios y Fixture Oficial (XML)
2026 - 2C
Grupo 10

Archivo: 04_3_IMPORT_SEDES_Y_FIXTURE.sql
Descripcion:
Procedimiento que se encarga de leer la lista confederaciones, estadios y el calendario de 
partidos del Mundial 2026 desde un archivo .XML y .CSV. Se registra errores en auditoria.
  - Importación de Confederaciones desde archivo XML.
  - Sincronización de Fases oficiales del Torneo (Fase de Grupos a Final).
  - Carga masiva de Selecciones participantes desde archivo CSV con validación FIFA.
  - Carga de Sedes/Estadios y Fixture de Partidos desde archivo XML, calculando
    las fechas y horarios tanto en estándar internacional (UTC) como en hora local
  - Registro centralizado de auditoría: cualquier fallo de lectura o violación de
  restricciones se persiste automáticamente en auditoria.LOG_IMPORTACION mediante el
  procedimiento auditoria.sp_REGISTRAR_ERROR_IMPORTACION.

================================================================================
*/

USE DB_Mundial2026_Grupo10;
GO

-- 1. IMPORTAR CONFEDERACIONES (XML)
CREATE OR ALTER PROCEDURE geografia.sp_IMPORTAR_CONFEDERACIONES_XML
    @XmlData XML
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NombreProc VARCHAR(100) = 'geografia.sp_IMPORTAR_CONFEDERACIONES_XML';
    DECLARE @ErrLinea   INT;
    DECLARE @ErrMensaje NVARCHAR(4000);

    PRINT '  INICIAO IMPORTACIÓN DE CONFEDERACIONES (XML)            ';

    BEGIN TRY
        -- 1. VALIDACIÓN PREVIA DE ENTRADA
        IF @XmlData IS NULL
            THROW 50001, 'El parámetro XML de confederaciones no puede ser nulo.', 1;

        -- 2. TABLA TEMPORAL DE PROCESAMIENTO
        DECLARE @Datos TABLE (
            id_confederacion     INT PRIMARY KEY,
            sigla                VARCHAR(20),
            nombre_confederacion VARCHAR(150)
        );

        INSERT INTO @Datos (id_confederacion, sigla, nombre_confederacion)
        SELECT
            X.N.value('@id', 'INT'),
            UPPER(LTRIM(RTRIM(X.N.value('@sigla', 'VARCHAR(20)')))),
            LTRIM(RTRIM(X.N.value('@nombre', 'VARCHAR(150)')))
        FROM @XmlData.nodes('/Confederaciones/Confederacion') X(N);

        IF NOT EXISTS (SELECT 1 FROM @Datos)
            THROW 50002, 'El documento XML no contiene etiquetas de confederaciones válidas.', 1;

        -- 3. VALIDACIONES DE INTEGRIDAD
        IF EXISTS (SELECT sigla FROM @Datos GROUP BY sigla HAVING COUNT(*) > 1)
            THROW 50003, 'Se detectaron siglas de confederaciones duplicadas en el archivo XML.', 1;

        -- 4. UPSERT TRANSACCIONAL EN BASE DE DATOS
        BEGIN TRANSACTION;

        -- Actualización de confederaciones existentes
        UPDATE C
        SET C.sigla = D.sigla,
            C.nombre_confederacion = D.nombre_confederacion
        FROM geografia.CONFEDERACION C
        INNER JOIN @Datos D ON C.id_confederacion = D.id_confederacion;

        -- Inserción de confederaciones nuevas
        INSERT INTO geografia.CONFEDERACION (id_confederacion, sigla, nombre_confederacion)
        SELECT D.id_confederacion, D.sigla, D.nombre_confederacion
        FROM @Datos D
        WHERE NOT EXISTS (
            SELECT 1 FROM geografia.CONFEDERACION C 
            WHERE C.id_confederacion = D.id_confederacion
        );

        COMMIT TRANSACTION;
        PRINT '--> [OK] Confederaciones sincronizadas correctamente.';

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @ErrLinea   = ERROR_LINE();
        SET @ErrMensaje = 'Error al importar confederaciones XML: ' + ERROR_MESSAGE();

        EXEC auditoria.sp_REGISTRAR_ERROR_IMPORTACION
            @proceso_origen = @NombreProc,
            @clave_registro = 'XML_CONFEDERACIONES',
            @mensaje_error  = @ErrMensaje,
            @linea_error    = @ErrLinea;

        PRINT '--> ERROR REGISTRADO EN AUDITORÍA: ' + @ErrMensaje;
        THROW 50004, @ErrMensaje, 1;
    END CATCH;
END;
GO

-- 2. IMPORTAR FASES DEL TORNEO (CATÁLOGO OFICIAL)
CREATE OR ALTER PROCEDURE torneo.sp_IMPORTAR_FASES
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @NombreProc VARCHAR(100) = 'torneo.sp_IMPORTAR_FASES';
    DECLARE @ErrLinea   INT;
    DECLARE @ErrMensaje NVARCHAR(4000);

    PRINT '  SINCRONIZANDO FASES OFICIALES DEL TORNEO                  ';

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. ACTUALIZAR FASES PREEXISTENTES
        UPDATE F
        SET F.nombre_fase     = V.nombre_fase,
            F.orden_secuencia = V.orden_secuencia
        FROM torneo.FASE_TORNEO F
        INNER JOIN (
            VALUES
                (1, 'Fase de grupos', 1),
                (2, 'Dieciseisavos de final', 2),
                (3, 'Octavos de final', 3),
                (4, 'Cuartos de final', 4),
                (5, 'Semifinal', 5),
                (6, 'Tercer puesto', 6),
                (7, 'Final', 7)
        ) V(id_fase, nombre_fase, orden_secuencia) ON F.id_fase = V.id_fase;

        -- 2. INSERTAR FASES FALTANTES
        INSERT INTO torneo.FASE_TORNEO (id_fase, nombre_fase, orden_secuencia)
        SELECT V.id_fase, V.nombre_fase, V.orden_secuencia
        FROM (
            VALUES
                (1, 'Fase de grupos', 1),
                (2, 'Dieciseisavos de final', 2),
                (3, 'Octavos de final', 3),
                (4, 'Cuartos de final', 4),
                (5, 'Semifinal', 5),
                (6, 'Tercer puesto', 6),
                (7, 'Final', 7)
        ) V(id_fase, nombre_fase, orden_secuencia)
        WHERE NOT EXISTS (
            SELECT 1 FROM torneo.FASE_TORNEO F 
            WHERE F.id_fase = V.id_fase
        );

        COMMIT TRANSACTION;
        PRINT '--> [OK] Fases oficiales del torneo sincronizadas exitosamente.';

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @ErrLinea   = ERROR_LINE();
        SET @ErrMensaje = 'Error al sincronizar fases del torneo: ' + ERROR_MESSAGE();

        EXEC auditoria.sp_REGISTRAR_ERROR_IMPORTACION
            @proceso_origen = @NombreProc,
            @clave_registro = 'FASE_TORNEO',
            @mensaje_error  = @ErrMensaje,
            @linea_error    = @ErrLinea;

        PRINT '--> ERROR REGISTRADO EN AUDITORÍA: ' + @ErrMensaje;
        THROW 50005, @ErrMensaje, 1;
    END CATCH;
END;
GO

-- 3. IMPORTAR SELECCIONES PARTICIPANTES (CSV)
CREATE OR ALTER PROCEDURE torneo.sp_IMPORTAR_SELECCIONES_CSV
    @RutaArchivo VARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NombreProc VARCHAR(100) = 'torneo.sp_IMPORTAR_SELECCIONES_CSV';
    DECLARE @ErrLinea   INT;
    DECLARE @ErrMensaje NVARCHAR(4000);

    PRINT '  INICIO IMPORTACIÓN DE SELECCIONES (CSV)                ';
    PRINT '  Archivo: ' + @RutaArchivo;

    -- 1. TABLA TEMPORAL DE STAGING
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
        -- 2. BULK INSERT DEL ARCHIVO CSV
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
            -- Fallback a CRLF de Windows si falló con Unix 0x0a
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

        -- 3. VALIDACIONES DE INTEGRIDAD
        IF NOT EXISTS (SELECT 1 FROM #Teams)
            THROW 50010, 'El archivo CSV no contiene registros de selecciones.', 1;

        IF EXISTS (
            SELECT 1 FROM #Teams
            WHERE team_id IS NULL OR team_name IS NULL OR fifa_code IS NULL 
               OR group_letter IS NULL OR confederation IS NULL
        )
            THROW 50011, 'El CSV contiene campos obligatorios vacíos o nulos.', 1;

        IF EXISTS (SELECT team_id FROM #Teams GROUP BY team_id HAVING COUNT(*) > 1)
            THROW 50012, 'Existen identificadores (team_id) duplicados en el archivo.', 1;

        IF EXISTS (SELECT fifa_code FROM #Teams GROUP BY fifa_code HAVING COUNT(*) > 1)
            THROW 50013, 'Existen códigos FIFA duplicados en el archivo.', 1;

        -- Validar existencia previa de Países y Confederaciones
        IF EXISTS (
            SELECT 1 FROM #Teams T
            LEFT JOIN geografia.PAIS P ON P.id_pais = UPPER(LTRIM(RTRIM(T.fifa_code)))
            LEFT JOIN geografia.CONFEDERACION C ON C.sigla = UPPER(LTRIM(RTRIM(T.confederation)))
            WHERE P.id_pais IS NULL OR C.id_confederacion IS NULL
        )
            THROW 50014, 'Existen selecciones asociadas a países o confederaciones no registrados en la base.', 1;

        -- 4. UPSERT TRANSACCIONAL EN SELECCION
        BEGIN TRANSACTION;

        -- Actualizar selecciones existentes
        UPDATE S
        SET S.id_pais          = P.id_pais,
            S.id_confederacion = C.id_confederacion,
            S.nombre_seleccion = LTRIM(RTRIM(T.team_name)),
            S.grupo_asignado   = UPPER(LTRIM(RTRIM(T.group_letter)))
        FROM torneo.SELECCION S
        INNER JOIN #Teams T ON S.id_seleccion = T.team_id
        INNER JOIN geografia.PAIS P ON P.id_pais = UPPER(LTRIM(RTRIM(T.fifa_code)))
        INNER JOIN geografia.CONFEDERACION C ON C.sigla = UPPER(LTRIM(RTRIM(T.confederation)));

        -- Insertar selecciones nuevas
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
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        IF OBJECT_ID('tempdb..#Teams') IS NOT NULL DROP TABLE #Teams;

        SET @ErrLinea   = ERROR_LINE();
        SET @ErrMensaje = 'Fallo en importación de selecciones CSV: ' + ERROR_MESSAGE();

        EXEC auditoria.sp_REGISTRAR_ERROR_IMPORTACION
            @proceso_origen = @NombreProc,
            @clave_registro = @RutaArchivo,
            @mensaje_error  = @ErrMensaje,
            @linea_error    = @ErrLinea;

        PRINT '--> ERROR REGISTRADO EN AUDITORÍA: ' + @ErrMensaje;
        THROW 50015, @ErrMensaje, 1;
    END CATCH;
END;
GO

-- 4. IMPORTAR SEDES, ESTADIOS Y FIXTURE DE PARTIDOS (XML)
CREATE OR ALTER PROCEDURE torneo.sp_IMPORTAR_SEDES_Y_FIXTURE_XML
    @XmlData XML
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NombreProc VARCHAR(100) = 'torneo.sp_IMPORTAR_SEDES_Y_FIXTURE_XML';
    DECLARE @ErrLinea   INT;
    DECLARE @ErrMensaje NVARCHAR(4000);

    PRINT '  INICIO IMPORTACIÓN DE SEDES Y FIXTURE (XML)            ';
 
    IF @XmlData IS NULL
    BEGIN
        SET @ErrLinea   = 290;
        SET @ErrMensaje = 'El parámetro XML de fixture y sedes no puede ser nulo.';

        EXEC auditoria.sp_REGISTRAR_ERROR_IMPORTACION
            @proceso_origen = @NombreProc,
            @clave_registro = 'XML_FIXTURE',
            @mensaje_error  = @ErrMensaje,
            @linea_error    = @ErrLinea;

        THROW 50020, @ErrMensaje, 1;
    END;

    -- 1. TABLAS TEMPORALES DE PROCESAMIENTO
    IF OBJECT_ID('tempdb..#Sedes') IS NOT NULL DROP TABLE #Sedes;
    CREATE TABLE #Sedes (
        id_sede          INT PRIMARY KEY,
        id_pais          CHAR(3),
        nombre_estadio   VARCHAR(100),
        ciudad           VARCHAR(100),
        capacidad        INT,
        huso_horario_utc VARCHAR(10)
    );

    IF OBJECT_ID('tempdb..#Partidos') IS NOT NULL DROP TABLE #Partidos;
    CREATE TABLE #Partidos (
        id_fase             INT,
        nro_partido_fase    INT,
        id_sede             INT,
        codigo_local        CHAR(3),
        codigo_visitante    CHAR(3),
        fecha_hora_utc      DATETIME2,
        fecha_hora_local    DATETIME2,
        PRIMARY KEY (id_fase, nro_partido_fase)
    );

    BEGIN TRY
        -- 2. LEER SEDES DEL DOCUMENTO XML
        INSERT INTO #Sedes (id_sede, id_pais, nombre_estadio, ciudad, capacidad, huso_horario_utc)
        SELECT
            X.N.value('@id', 'INT'),
            X.N.value('@pais', 'CHAR(3)'),
            X.N.value('@estadioNombre', 'VARCHAR(100)'),
            X.N.value('@ciudad', 'VARCHAR(100)'),
            X.N.value('@capacidad', 'INT'),
            X.N.value('@huso', 'VARCHAR(10)')
        FROM @XmlData.nodes('/Mundial2026/Sedes/Sede') X(N);

        IF NOT EXISTS (SELECT 1 FROM #Sedes)
            THROW 50021, 'El XML no contiene elementos de sedes válidos.', 1;

        -- Validar que los países de las sedes existan
        IF EXISTS (
            SELECT 1 FROM #Sedes S
            LEFT JOIN geografia.PAIS P ON P.id_pais = S.id_pais
            WHERE P.id_pais IS NULL
        )
            THROW 50022, 'Existen sedes asociadas a países no registrados en geografia.PAIS.', 1;

        -- 3. LEER PARTIDOS DEL DOCUMENTO XML
        INSERT INTO #Partidos (
            id_fase, nro_partido_fase, id_sede, codigo_local, codigo_visitante, fecha_hora_utc, fecha_hora_local
        )
        SELECT
            X.N.value('@fase', 'INT'),
            X.N.value('@nro', 'INT'),
            X.N.value('@sede', 'INT'),
            X.N.value('@local', 'CHAR(3)'),
            X.N.value('@visitante', 'CHAR(3)'),
            X.N.value('@fechaUtc', 'DATETIME2'),
            X.N.value('@fechaLocal', 'DATETIME2')
        FROM @XmlData.nodes('/Mundial2026/Partidos/Partido') X(N);

        IF NOT EXISTS (SELECT 1 FROM #Partidos)
            THROW 50023, 'El XML no contiene información de partidos en el fixture.', 1;

        -- 4. VALIDACIONES DE REGLAS DE NEGOCIO
        -- Validar Fases
        IF EXISTS (
            SELECT 1 FROM #Partidos P
            LEFT JOIN torneo.FASE_TORNEO F ON F.id_fase = P.id_fase
            WHERE F.id_fase IS NULL
        )
            THROW 50024, 'Existen partidos asociados a fases inexistentes en torneo.FASE_TORNEO.', 1;

        -- Validar Sedes
        IF EXISTS (
            SELECT 1 FROM #Partidos P
            LEFT JOIN #Sedes S ON S.id_sede = P.id_sede
            WHERE S.id_sede IS NULL
        )
            THROW 50025, 'Existen partidos asociados a sedes no definidas en el XML.', 1;

        -- Validar que las selecciones intervinientes existan
        IF EXISTS (
            SELECT 1 FROM #Partidos P
            LEFT JOIN geografia.PAIS PL ON PL.id_pais = P.codigo_local
            LEFT JOIN torneo.SELECCION SL ON SL.id_pais = PL.id_pais
            LEFT JOIN geografia.PAIS PV ON PV.id_pais = P.codigo_visitante
            LEFT JOIN torneo.SELECCION SV ON SV.id_pais = PV.id_pais
            WHERE SL.id_seleccion IS NULL OR SV.id_seleccion IS NULL
        )
            THROW 50026, 'Existen partidos con selecciones locales o visitantes que no fueron importadas.', 1;

        -- Validar que un equipo no juegue contra sí mismo
        IF EXISTS (
            SELECT 1 FROM #Partidos P
            INNER JOIN torneo.SELECCION SL ON SL.id_pais = P.codigo_local
            INNER JOIN torneo.SELECCION SV ON SV.id_pais = P.codigo_visitante
            WHERE SL.id_seleccion = SV.id_seleccion
        )
            THROW 50027, 'Regla violada: una selección no puede disputar un partido contra sí misma.', 1;

        -- 5. UPSERT TRANSACCIONAL: SEDES
        BEGIN TRANSACTION;

        UPDATE D
        SET D.id_pais          = O.id_pais,
            D.nombre_estadio   = O.nombre_estadio,
            D.ciudad           = O.ciudad,
            D.capacidad        = O.capacidad,
            D.huso_horario_utc = O.huso_horario_utc
        FROM torneo.SEDE D
        INNER JOIN #Sedes O ON D.id_sede = O.id_sede;

        INSERT INTO torneo.SEDE (id_sede, id_pais, nombre_estadio, ciudad, capacidad, huso_horario_utc)
        SELECT O.id_sede, O.id_pais, O.nombre_estadio, O.ciudad, O.capacidad, O.huso_horario_utc
        FROM #Sedes O
        WHERE NOT EXISTS (
            SELECT 1 FROM torneo.SEDE D 
            WHERE D.id_sede = O.id_sede
        );

        -- 6. UPSERT TRANSACCIONAL: PARTIDOS
        -- Actualizar partidos existentes manteniendo inalterados goles y asistencia
        UPDATE D
        SET D.id_sede                = P.id_sede,
            D.id_seleccion_local     = SL.id_seleccion,
            D.id_seleccion_visitante = SV.id_seleccion,
            D.fecha_hora_utc         = P.fecha_hora_utc,
            D.fecha_hora_local       = P.fecha_hora_local
        FROM torneo.PARTIDO D
        INNER JOIN #Partidos P ON D.id_fase = P.id_fase AND D.nro_partido_fase = P.nro_partido_fase
        INNER JOIN torneo.SELECCION SL ON SL.id_pais = P.codigo_local
        INNER JOIN torneo.SELECCION SV ON SV.id_pais = P.codigo_visitante;

        -- Insertar partidos nuevos
        INSERT INTO torneo.PARTIDO (
            id_fase, nro_partido_fase, id_sede, id_seleccion_local, id_seleccion_visitante,
            fecha_hora_utc, fecha_hora_local, asistencia_oficial, goles_local, goles_visitante,
            penales_local, penales_visitante, id_ganador_penales
        )
        SELECT
            P.id_fase,
            P.nro_partido_fase,
            P.id_sede,
            SL.id_seleccion,
            SV.id_seleccion,
            P.fecha_hora_utc,
            P.fecha_hora_local,
            0,
            0,
            0,
            NULL,
            NULL,
            NULL
        FROM #Partidos P
        INNER JOIN torneo.SELECCION SL ON SL.id_pais = P.codigo_local
        INNER JOIN torneo.SELECCION SV ON SV.id_pais = P.codigo_visitante
        WHERE NOT EXISTS (
            SELECT 1 FROM torneo.PARTIDO D 
            WHERE D.id_fase = P.id_fase AND D.nro_partido_fase = P.nro_partido_fase
        );

        COMMIT TRANSACTION;

        -- 7. REPORTE DE RESULTADOS DE PROCESAMIENTO
        PRINT '--> [OK] Sedes y fixture de partidos sincronizados correctamente.';
        SELECT
            (SELECT COUNT(*) FROM #Sedes)          AS Sedes_En_XML,
            (SELECT COUNT(*) FROM #Partidos)       AS Partidos_En_XML,
            (SELECT COUNT(*) FROM torneo.SEDE)     AS Total_Sedes_DB,
            (SELECT COUNT(*) FROM torneo.PARTIDO)  AS Total_Partidos_DB;

        DROP TABLE #Sedes;
        DROP TABLE #Partidos;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        IF OBJECT_ID('tempdb..#Sedes') IS NOT NULL DROP TABLE #Sedes;
        IF OBJECT_ID('tempdb..#Partidos') IS NOT NULL DROP TABLE #Partidos;

        SET @ErrLinea   = ERROR_LINE();
        SET @ErrMensaje = 'Error al procesar sedes y fixture XML: ' + ERROR_MESSAGE();

        -- Registro centralizado de auditoría
        EXEC auditoria.sp_REGISTRAR_ERROR_IMPORTACION
            @proceso_origen = @NombreProc,
            @clave_registro = 'XML_SEDES_FIXTURE',
            @mensaje_error  = @ErrMensaje,
            @linea_error    = @ErrLinea;

        PRINT '--> ERROR REGISTRADO EN AUDITORÍA: ' + @ErrMensaje;
        THROW 50028, @ErrMensaje, 1;
    END CATCH;
END;
GO