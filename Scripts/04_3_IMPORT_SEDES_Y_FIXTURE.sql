/*
================================================================================
UNLaM - Universidad Nacional de La Matanza
Departamento de Ingeniería e Investigaciones Tecnológicas
Materia: Base de Datos Aplicada (Comisión 5600)
Entrega 6 - Script 04_3: Importación de Sedes, Estadios y Fixture Oficial
2026 - 2C
Grupo 10

Integrantes:
- Monasterio Erik: MonasteryEr
- Arena Ariel Ignacio: arielarena
- Castillo Gabriela Florencia: ItsFlorencia
- Maita Pitado Jose Gregorio: maita07

Archivo: 04_3_IMPORT_SEDES_Y_FIXTURE.sql
Descripcion:
- Rutas recibidas obligatoriamente por parámetro (sin rutas fijas ni defaults).
- geografia.sp_IMPORTAR_CONFEDERACIONES_XML: Carga de confederaciones desde XML.
- torneo.sp_IMPORTAR_FASES: Sincronización del catálogo oficial de fases.
- torneo.sp_IMPORTAR_SEDES_Y_FIXTURE_XML: Carga de Sedes, Estadios y Fixture (XML).
- Registro centralizado de auditoría en auditoria.LOG_IMPORTACION.
================================================================================
*/
USE DB_Mundial2026_Grupo10;
GO

-- 1. IMPORTAR CONFEDERACIONES (XML)
CREATE OR ALTER PROCEDURE geografia.sp_IMPORTAR_CONFEDERACIONES_XML
    @RutaArchivo VARCHAR(500) -- Parámetro obligatorio por parámetro
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NombreProc VARCHAR(100) = 'geografia.sp_IMPORTAR_CONFEDERACIONES_XML';
    DECLARE @ErrLinea   INT;
    DECLARE @ErrMensaje NVARCHAR(4000);

    PRINT '  INICIANDO IMPORTACIÓN DE CONFEDERACIONES (XML)                        ';
    PRINT '  Archivo recibido: ' + ISNULL(@RutaArchivo, 'NULL');

    -- 1. VALIDACIÓN PREVIA DEL PARÁMETRO
    IF @RutaArchivo IS NULL OR LTRIM(RTRIM(@RutaArchivo)) = ''
    BEGIN
        SET @ErrMensaje = 'Debe indicar obligatoriamente la ruta del archivo XML de confederaciones (@RutaArchivo).';
        EXEC auditoria.sp_REGISTRAR_ERROR_IMPORTACION
            @proceso_origen = @NombreProc,
            @clave_registro = 'PARAMETRO_NULL',
            @mensaje_error  = @ErrMensaje,
            @linea_error    = 1;
        THROW 50020, @ErrMensaje, 1;
    END;

    BEGIN TRY
        DECLARE @XmlData XML;
        DECLARE @SQL NVARCHAR(MAX);

        SET @SQL = N'
        SELECT @XML = CAST(BulkColumn AS XML)
        FROM OPENROWSET(
            BULK ''' + REPLACE(@RutaArchivo, '''', '''''') + N''',
            SINGLE_BLOB
        ) AS X;';

        EXEC sys.sp_executesql
            @SQL,
            N'@XML XML OUTPUT',
            @XML = @XmlData OUTPUT;

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

        -- 4. UPSERT TRANSACCIONAL
        BEGIN TRANSACTION;

        UPDATE C
        SET C.sigla = D.sigla,
            C.nombre_confederacion = D.nombre_confederacion
        FROM geografia.CONFEDERACION C
        INNER JOIN @Datos D ON C.id_confederacion = D.id_confederacion;

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
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        SET @ErrLinea   = ERROR_LINE();
        SET @ErrMensaje = 'Error al importar confederaciones XML: ' + ERROR_MESSAGE();

        EXEC auditoria.sp_REGISTRAR_ERROR_IMPORTACION
            @proceso_origen = @NombreProc,
            @clave_registro = @RutaArchivo,
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

    PRINT '  SINCRONIZANDO FASES OFICIALES DEL TORNEO                              ';

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Actualizar fases preexistentes
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

        -- Insertar fases faltantes
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
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

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

-- 3. IMPORTAR SEDES, ESTADIOS Y FIXTURE DE PARTIDOS (XML)
CREATE OR ALTER PROCEDURE torneo.sp_IMPORTAR_SEDES_Y_FIXTURE_XML
    @RutaArchivo VARCHAR(500) -- Parámetro obligatorio por parámetro
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NombreProc VARCHAR(100) = 'torneo.sp_IMPORTAR_SEDES_Y_FIXTURE_XML';
    DECLARE @ErrLinea   INT;
    DECLARE @ErrMensaje NVARCHAR(4000);

    PRINT '  INICIO IMPORTACIÓN DE SEDES Y FIXTURE (XML)                           ';
    PRINT '  Archivo recibido: ' + ISNULL(@RutaArchivo, 'NULL');
  
    -- 1. VALIDACIÓN PREVIA DEL PARÁMETRO
    IF @RutaArchivo IS NULL OR LTRIM(RTRIM(@RutaArchivo)) = ''
    BEGIN
        SET @ErrMensaje = 'Debe indicar obligatoriamente la ruta del archivo XML de sedes y fixture (@RutaArchivo).';
        EXEC auditoria.sp_REGISTRAR_ERROR_IMPORTACION
            @proceso_origen = @NombreProc,
            @clave_registro = 'PARAMETRO_NULL',
            @mensaje_error  = @ErrMensaje,
            @linea_error    = 1;
        THROW 50020, @ErrMensaje, 1;
    END;

    -- 2. TABLAS TEMPORALES DE PROCESAMIENTO
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
        -- 3. LECTURA DEL ARCHIVO XML DINÁMICO
        DECLARE @XmlData XML;
        DECLARE @SQL NVARCHAR(MAX);

        SET @SQL = N'
        SELECT @XML = CAST(BulkColumn AS XML)
        FROM OPENROWSET(
            BULK ''' + REPLACE(@RutaArchivo, '''', '''''') + N''',
            SINGLE_BLOB
        ) AS X;';

        EXEC sys.sp_executesql
            @SQL,
            N'@XML XML OUTPUT',
            @XML = @XmlData OUTPUT;

        -- 4. LEER SEDES DESDE XML
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

        IF EXISTS (
            SELECT 1 FROM #Sedes S
            LEFT JOIN geografia.PAIS P ON P.id_pais = S.id_pais
            WHERE P.id_pais IS NULL
        )
            THROW 50022, 'Existen sedes asociadas a países no registrados en geografia.PAIS.', 1;

        -- 5. LEER PARTIDOS DESDE XML
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

        -- 6. VALIDACIONES DE NEGOCIO
        IF EXISTS (
            SELECT 1 FROM #Partidos P
            LEFT JOIN torneo.FASE_TORNEO F ON F.id_fase = P.id_fase
            WHERE F.id_fase IS NULL
        )
            THROW 50024, 'Existen partidos asociados a fases inexistentes en torneo.FASE_TORNEO.', 1;

        IF EXISTS (
            SELECT 1 FROM #Partidos P
            LEFT JOIN #Sedes S ON S.id_sede = P.id_sede
            WHERE S.id_sede IS NULL
        )
            THROW 50025, 'Existen partidos asociados a sedes no definidas en el XML.', 1;

        IF EXISTS (
            SELECT 1 FROM #Partidos P
            LEFT JOIN geografia.PAIS PL ON PL.id_pais = P.codigo_local
            LEFT JOIN torneo.SELECCION SL ON SL.id_pais = PL.id_pais
            LEFT JOIN geografia.PAIS PV ON PV.id_pais = P.codigo_visitante
            LEFT JOIN torneo.SELECCION SV ON SV.id_pais = PV.id_pais
            WHERE SL.id_seleccion IS NULL OR SV.id_seleccion IS NULL
        )
            THROW 50026, 'Existen partidos con selecciones locales o visitantes que no fueron importadas.', 1;

        IF EXISTS (
            SELECT 1 FROM #Partidos P
            INNER JOIN torneo.SELECCION SL ON SL.id_pais = P.codigo_local
            INNER JOIN torneo.SELECCION SV ON SV.id_pais = P.codigo_visitante
            WHERE SL.id_seleccion = SV.id_seleccion
        )
            THROW 50027, 'Regla violada: una selección no puede disputar un partido contra sí misma.', 1;

        -- 7. UPSERT TRANSACCIONAL DE SEDES
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

        -- 8. CARGA LIMPIA DE PARTIDOS
        INSERT INTO torneo.PARTIDO (
            id_fase,
            nro_partido_fase,
            id_sede,
            id_seleccion_local,
            id_seleccion_visitante,
            fecha_hora_utc,
            fecha_hora_local,
            asistencia_oficial,
            goles_local,
            goles_visitante,
            penales_local,
            penales_visitante,
            id_ganador_penales
        )
        SELECT
            P.id_fase,
            P.nro_partido_fase,
            P.id_sede,
            SL.id_seleccion,
            SV.id_seleccion,
            P.fecha_hora_utc,
            P.fecha_hora_local,
            CAST(S.capacidad * (0.92 + ((P.nro_partido_fase % 6) * 0.01)) AS INT),
            0,
            0,
            NULL,
            NULL,
            NULL
        FROM #Partidos P
        INNER JOIN torneo.SELECCION SL ON SL.id_pais = P.codigo_local
        INNER JOIN torneo.SELECCION SV ON SV.id_pais = P.codigo_visitante
        INNER JOIN #Sedes S            ON P.id_sede = S.id_sede
        WHERE NOT EXISTS (
            SELECT 1 FROM torneo.PARTIDO D
            WHERE D.id_fase = P.id_fase AND D.nro_partido_fase = P.nro_partido_fase
        );

        COMMIT TRANSACTION;

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
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF OBJECT_ID('tempdb..#Sedes') IS NOT NULL DROP TABLE #Sedes;
        IF OBJECT_ID('tempdb..#Partidos') IS NOT NULL DROP TABLE #Partidos;

        SET @ErrLinea   = ERROR_LINE();
        SET @ErrMensaje = 'Error al procesar sedes y fixture XML: ' + ERROR_MESSAGE();

        EXEC auditoria.sp_REGISTRAR_ERROR_IMPORTACION
            @proceso_origen = @NombreProc,
            @clave_registro = @RutaArchivo,
            @mensaje_error  = @ErrMensaje,
            @linea_error    = @ErrLinea;

        PRINT '--> ERROR REGISTRADO EN AUDITORÍA: ' + @ErrMensaje;
        THROW 50028, @ErrMensaje, 1;
    END CATCH;
END;
GO