/*
--------------------------------------------------------------------------------
UNLaM - Universidad Nacional de La Matanza
Departamento de Ingeniería e Investigaciones Tecnológicas
Materia: Base de Datos Aplicada (Comisión 5600)
Entrega 6 - Script 06_03: Importacion de Sedes, Estadios y Fixture Oficial (XML)
2026 - 2C
Grupo 10

Descripcion:
Procedimiento que se encarga de leer la lista de estadios y el calendario de 
partidos del Mundial 2026 desde un archivo XML. 
Revisa cada cancha y cada partido:
  - Si no existe en la base de datos, lo agrega por primera vez.
  - Si ya estaba cargado, actualiza sus datos (capacidad, horarios, sede) 
    sin borrar nada ni crear partidos repetidos.
Además, guarda la hora exacta de cada partido tanto en horario internacional (UTC) 
como en la hora local del país donde se juega.

--------------------------------------------------------------------------------
*/

CREATE OR ALTER PROCEDURE torneo.sp_IMPORTAR_SEDES_Y_FIXTURE_XML
    @XmlData XML = NULL
AS
BEGIN
    SET NOCOUNT ON;

    PRINT '========================================================================';
    PRINT '  INICIANDO IMPORTACIÓN DE 16 SEDES Y 104 PARTIDOS (XML / PURE UPSERT)  ';
    PRINT '========================================================================';

    ----------------------------------------------------------------------------
    -- 0. PREPARACIÓN DE ENTIDADES PADRE REQUERIDAS
    ----------------------------------------------------------------------------
    -- A. Fases del Torneo
    MERGE INTO torneo.FASE_TORNEO AS Target
    USING (
        VALUES 
            (1, 'Fase de Grupos', 1),
            (2, 'Dieciseisavos de Final', 2),
            (3, 'Octavos de Final', 3),
            (4, 'Cuartos de Final', 4),
            (5, 'Semifinal', 5),
            (6, 'Tercer Puesto', 6),
            (7, 'Final', 7)
    ) AS Source (id_fase, nombre_fase, orden_secuencia)
    ON Target.id_fase = Source.id_fase
    WHEN MATCHED THEN
        UPDATE SET nombre_fase = Source.nombre_fase, orden_secuencia = Source.orden_secuencia
    WHEN NOT MATCHED THEN
        INSERT (id_fase, nombre_fase, orden_secuencia)
        VALUES (Source.id_fase, Source.nombre_fase, Source.orden_secuencia);

    -- B. Confederaciones Base
    MERGE INTO geografia.CONFEDERACION AS Target
    USING (
        VALUES 
            (1, 'CONMEBOL', 'CONMEBOL'),
            (2, 'UEFA', 'UEFA'),
            (3, 'CONCACAF', 'CONCACAF'),
            (4, 'AFC', 'AFC'),
            (5, 'CAF', 'CAF'),
            (6, 'OFC', 'OFC')
    ) AS Source (id_confederacion, nombre_confederacion, sigla)
    ON Target.id_confederacion = Source.id_confederacion
    WHEN MATCHED THEN
        UPDATE SET nombre_confederacion = Source.nombre_confederacion, sigla = Source.sigla
    WHEN NOT MATCHED THEN
        INSERT (id_confederacion, nombre_confederacion, sigla)
        VALUES (Source.id_confederacion, Source.nombre_confederacion, Source.sigla);

    -- C. Asegurar que los Países de las 48 selecciones existan en geografia.PAIS
    MERGE INTO geografia.PAIS AS Target
    USING (
        VALUES 
            ('MEX','México','MXN',10000.00), ('RSA','Sudáfrica','ZAR',6000.00), ('KOR','Corea del Sur','KRW',32000.00),
            ('CZE','República Checa','CZK',27000.00), ('CAN','Canadá','CAD',52000.00), ('BIH','Bosnia y Herzegovina','BAM',7500.00),
            ('USA','Estados Unidos','USD',76000.00), ('PAR','Paraguay','PYG',5800.00), ('QAT','Catar','QAR',62000.00),
            ('SUI','Suiza','CHF',93000.00), ('BRA','Brasil','BRL',8900.00), ('MAR','Marruecos','MAD',3700.00),
            ('HTI','Haití','HTG',1700.00), ('SCO','Escocia','GBP',42000.00), ('AUS','Australia','AUD',65000.00),
            ('TUR','Turquía','TRY',10600.00), ('GER','Alemania','EUR',48000.00), ('CUW','Curazao','ANG',16000.00),
            ('NED','Países Bajos','EUR',56000.00), ('JPN','Japón','JPY',34000.00), ('CIV','Costa de Marfil','XOF',2500.00),
            ('ECU','Ecuador','USD',6300.00), ('SWE','Suecia','SEK',55000.00), ('TUN','Túnez','TND',3800.00),
            ('ESP','España','EUR',30000.00), ('CPV','Cabo Verde','CVE',3900.00), ('BEL','Bélgica','EUR',49000.00),
            ('EGY','Egipto','EGP',3700.00), ('SAU','Arabia Saudita','SAR',28000.00), ('URU','Uruguay','UYU',20000.00),
            ('IRN','Irán','IRR',4700.00), ('NZL','Nueva Zelanda','NZD',48000.00), ('FRA','Francia','EUR',42000.00),
            ('SEN','Senegal','XOF',1600.00), ('IRQ','Irak','IQD',5000.00), ('NOR','Noruega','NOK',106000.00),
            ('ARG','Argentina','ARS',13600.00), ('DZA','Argelia','DZD',4300.00), ('AUT','Austria','EUR',5300.00),
            ('JOR','Jordania','JOD',4200.00), ('POR','Portugal','EUR',24000.00), ('COD','R.D. del Congo','CDF',600.00),
            ('ENG','Inglaterra','GBP',46000.00), ('CRO','Croacia','EUR',18000.00), ('GHA','Ghana','GHS',2200.00),
            ('PAN','Panamá','PAB',17000.00), ('UZB','Uzbekistán','UZS',2200.00), ('COL','Colombia','COP',6600.00)
    ) AS Source (id_pais, nombre_pais, moneda_pais, pbi_per_capita_actual)
    ON Target.id_pais = Source.id_pais
    WHEN NOT MATCHED THEN
        INSERT (id_pais, nombre_pais, moneda_pais, pbi_per_capita_actual)
        VALUES (Source.id_pais, Source.nombre_pais, Source.moneda_pais, Source.pbi_per_capita_actual);

    -- D. Sincronizar las 48 Selecciones en torneo.SELECCION garantizando id_seleccion NOT NULL
    DECLARE @MaxId INT = ISNULL((SELECT MAX(id_seleccion) FROM torneo.SELECCION), 0);

    CREATE TABLE #TempSelecciones (
        id_pais CHAR(3),
        id_confederacion INT,
        nombre_seleccion VARCHAR(50),
        grupo_asignado CHAR(1)
    );

    INSERT INTO #TempSelecciones (id_pais, id_confederacion, nombre_seleccion, grupo_asignado)
    VALUES 
        ('MEX',3,'México','A'), ('RSA',5,'Sudáfrica','A'), ('KOR',4,'Corea del Sur','A'), ('CZE',2,'República Checa','A'),
        ('CAN',3,'Canadá','B'), ('BIH',2,'Bosnia y Herzegovina','B'), ('QAT',4,'Catar','B'), ('SUI',2,'Suiza','B'),
        ('BRA',1,'Brasil','C'), ('MAR',5,'Marruecos','C'), ('HTI',3,'Haití','C'), ('SCO',2,'Escocia','C'),
        ('USA',3,'Estados Unidos','D'), ('PAR',1,'Paraguay','D'), ('AUS',4,'Australia','D'), ('TUR',2,'Turquía','D'),
        ('GER',2,'Alemania','E'), ('CUW',3,'Curazao','E'), ('CIV',5,'Costa de Marfil','E'), ('ECU',1,'Ecuador','E'),
        ('NED',2,'Países Bajos','F'), ('JPN',4,'Japón','F'), ('SWE',2,'Suecia','F'), ('TUN',5,'Túnez','F'),
        ('BEL',2,'Bélgica','G'), ('EGY',5,'Egipto','G'), ('IRN',4,'Irán','G'), ('NZL',6,'Nueva Zelanda','G'),
        ('ESP',2,'España','H'), ('CPV',5,'Cabo Verde','H'), ('SAU',4,'Arabia Saudita','H'), ('URU',1,'Uruguay','H'),
        ('FRA',2,'Francia','I'), ('SEN',5,'Senegal','I'), ('IRQ',4,'Irak','I'), ('NOR',2,'Noruega','I'),
        ('ARG',1,'Argentina','J'), ('DZA',5,'Argelia','J'), ('AUT',2,'Austria','J'), ('JOR',4,'Jordania','J'),
        ('POR',2,'Portugal','K'), ('COD',5,'R.D. del Congo','K'), ('UZB',4,'Uzbekistán','K'), ('COL',1,'Colombia','K'),
        ('ENG',2,'Inglaterra','L'), ('CRO',2,'Croacia','L'), ('GHA',5,'Ghana','L'), ('PAN',3,'Panamá','L');

    -- Insertamos únicamente las selecciones que no existan previamente, asignándoles IDs correlativos seguros
    INSERT INTO torneo.SELECCION (id_seleccion, id_pais, id_confederacion, nombre_seleccion, grupo_asignado)
    SELECT 
        @MaxId + ROW_NUMBER() OVER (ORDER BY T.id_pais) AS id_seleccion,
        T.id_pais,
        T.id_confederacion,
        T.nombre_seleccion,
        T.grupo_asignado
    FROM #TempSelecciones T
    WHERE NOT EXISTS (
        SELECT 1 FROM torneo.SELECCION S WHERE S.id_pais = T.id_pais
    );

    -- Actualizamos los nombres y grupos de las selecciones que ya existían
    UPDATE S
    SET S.nombre_seleccion = T.nombre_seleccion,
        S.grupo_asignado = T.grupo_asignado
    FROM torneo.SELECCION S
    INNER JOIN #TempSelecciones T ON S.id_pais = T.id_pais;

    DROP TABLE #TempSelecciones;

    ----------------------------------------------------------------------------
    -- 1. PURE UPSERT EN `torneo.SEDE` (16 Sedes Oficiales)
    ----------------------------------------------------------------------------
    BEGIN TRY
        MERGE INTO torneo.SEDE AS Target
        USING (
            SELECT 
                S.node.value('@id', 'INT') AS id_sede,
                UPPER(LTRIM(RTRIM(S.node.value('@pais', 'VARCHAR(10)')))) AS id_pais,
                COALESCE(S.node.value('@estadioNombre', 'VARCHAR(50)'), S.node.value('@estadio', 'VARCHAR(50)')) AS nombre_estadio,
                S.node.value('@ciudad', 'VARCHAR(50)') AS ciudad,
                S.node.value('@capacidad', 'INT') AS capacidad,
                S.node.value('@huso', 'VARCHAR(10)') AS huso_horario_utc
            FROM @XmlData.nodes('/Mundial2026/Sedes/Sede') AS S(node)
        ) AS Source
        ON Target.id_sede = Source.id_sede
        WHEN MATCHED THEN
            UPDATE SET 
                id_pais = Source.id_pais,
                nombre_estadio = Source.nombre_estadio,
                ciudad = Source.ciudad,
                capacidad = Source.capacidad,
                huso_horario_utc = Source.huso_horario_utc
        WHEN NOT MATCHED THEN
            INSERT (id_sede, id_pais, nombre_estadio, ciudad, capacidad, huso_horario_utc)
            VALUES (Source.id_sede, Source.id_pais, Source.nombre_estadio, Source.ciudad, Source.capacidad, Source.huso_horario_utc);

        PRINT '--> [OK] 16 Sedes oficiales procesadas exitosamente en torneo.SEDE.';
    END TRY
    BEGIN CATCH
        PRINT '--> [ERROR Sedes]: ' + ERROR_MESSAGE();
    END CATCH;

    ----------------------------------------------------------------------------
    -- 2. PURE UPSERT EN `torneo.PARTIDO` (104 Encuentros Traducidos)
    ----------------------------------------------------------------------------
    BEGIN TRY
        WITH XML_Partidos AS (
            SELECT 
                P.node.value('@fase', 'INT') AS id_fase,
                P.node.value('@nro', 'INT') AS nro_partido_fase,
                P.node.value('@sede', 'INT') AS id_sede,
                UPPER(LTRIM(RTRIM(P.node.value('@local', 'VARCHAR(10)')))) AS local_raw,
                UPPER(LTRIM(RTRIM(P.node.value('@visitante', 'VARCHAR(10)')))) AS visitante_raw,
                P.node.value('@fechaUtc', 'DATETIME2') AS fecha_hora_utc,
                P.node.value('@fechaLocal', 'DATETIME2') AS fecha_hora_local
            FROM @XmlData.nodes('/Mundial2026/Partidos/Partido') AS P(node)
        ),
        Partidos_Normalizados AS (
            SELECT 
                X.id_fase,
                X.nro_partido_fase,
                X.id_sede,
                COALESCE(SL.id_seleccion, TRY_CAST(X.local_raw AS INT)) AS id_seleccion_local,
                COALESCE(SV.id_seleccion, TRY_CAST(X.visitante_raw AS INT)) AS id_seleccion_visitante,
                X.fecha_hora_utc,
                X.fecha_hora_local
            FROM XML_Partidos X
            LEFT JOIN torneo.SELECCION SL ON SL.id_pais = X.local_raw
            LEFT JOIN torneo.SELECCION SV ON SV.id_pais = X.visitante_raw
        )
        MERGE INTO torneo.PARTIDO AS Target
        USING Partidos_Normalizados AS Source
        ON Target.id_fase = Source.id_fase 
       AND Target.nro_partido_fase = Source.nro_partido_fase
        WHEN MATCHED THEN
            UPDATE SET 
                id_sede = Source.id_sede,
                id_seleccion_local = Source.id_seleccion_local,
                id_seleccion_visitante = Source.id_seleccion_visitante,
                fecha_hora_utc = Source.fecha_hora_utc,
                fecha_hora_local = Source.fecha_hora_local
        WHEN NOT MATCHED THEN
            INSERT (id_fase, nro_partido_fase, id_sede, id_seleccion_local, id_seleccion_visitante, fecha_hora_utc, fecha_hora_local, asistencia_oficial, goles_local, goles_visitante)
            VALUES (Source.id_fase, Source.nro_partido_fase, Source.id_sede, Source.id_seleccion_local, Source.id_seleccion_visitante, Source.fecha_hora_utc, Source.fecha_hora_local, 0, 0, 0);

        PRINT '--> [OK] 104 Partidos procesados exitosamente en torneo.PARTIDO.';
    END TRY
    BEGIN CATCH
        PRINT '--> [ERROR Partidos]: ' + ERROR_MESSAGE();
    END CATCH;

    PRINT '========================================================================';
    PRINT '  IMPORTACIÓN DE FIXTURE COMPLETO FINALIZADA CON ÉXITO                  ';
    PRINT '========================================================================';
END;
GO