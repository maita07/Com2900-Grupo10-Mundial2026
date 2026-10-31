/*
--------------------------------------------------------------------------------
UNLaM - Base de Datos Aplicada
Entrega 6 - Script 4_4: Importacion de Jugadores y Plantillas (CSV / Pure UPSERT)
Grupo 10

Integrantes:
- Monasterio Erik: MonasteryEr
- Arena Ariel Ignacio: arielarena
- Castillo Gabriela Florencia: ItsFlorencia
- Maita Pitado Jose Gregorio: maita07

Archivo: 04_4_IMPORT_SELECCIONES_JUGADORES.sql
Descripcion:
Carga e integración masiva de las plantillas oficiales de las 48 selecciones del 
Mundial 2026 (26 jugadores por país, 1.248 futbolistas en total), a partir del 
dataset descargado de Kaggle en formato CSV.
--------------------------------------------------------------------------------
*/

USE DB_Mundial2026_Grupo10;
GO

CREATE OR ALTER PROCEDURE torneo.sp_IMPORTAR_JUGADORES_CSV
    @RutaArchivo VARCHAR(260) = 'C:\Mundial2026\SquadLists.csv'
AS
BEGIN
    SET NOCOUNT ON;


    PRINT '  INICIO IMPORTACIÓN DE PLANTILLAS MUNDIALISTAS (KAGGLE CSV / UPSERT)';


    IF OBJECT_ID('tempdb..#StagingKaggle') IS NOT NULL 
        DROP TABLE #StagingKaggle;

    CREATE TABLE #StagingKaggle (
        team_raw          VARCHAR(100),
        team_code_raw     VARCHAR(10),
        number_raw        VARCHAR(10),
        position_raw      VARCHAR(50),
        player_name_raw   VARCHAR(100),
        first_name_raw    VARCHAR(100),
        last_name_raw     VARCHAR(100),
        name_on_shirt_raw VARCHAR(100),
        dob_raw           VARCHAR(50),
        club_raw          VARCHAR(100),
        height_cm_raw     VARCHAR(20),
        caps_raw          VARCHAR(20),
        goals_raw         VARCHAR(20)
    );

    BEGIN TRY
        DECLARE @SQL NVARCHAR(MAX);
        SET @SQL = N'
            BULK INSERT #StagingKaggle
            FROM ''' + @RutaArchivo + '''
            WITH (
                FIRSTROW = 2,
                FIELDTERMINATOR = '','',
                ROWTERMINATOR = ''\n'',
                CODEPAGE = ''65001'',
                TABLOCK
            );';

        EXEC sp_executesql @SQL;
        PRINT '--> [OK] Archivo CSV cargado en Staging exitosamente.';
    END TRY
    BEGIN CATCH
        PRINT '--> [ERROR BULK INSERT]: No se pudo leer el archivo en ' + @RutaArchivo;
        PRINT '    Detalle: ' + ERROR_MESSAGE();
        RETURN;
    END CATCH;

    IF OBJECT_ID('tempdb..#JugadoresLimpios') IS NOT NULL 
        DROP TABLE #JugadoresLimpios;

    SELECT 
        SEL.id_seleccion,
        P.id_pais,
        'PASAPORTE' AS tipo_doc,
        UPPER(P.id_pais) + RIGHT('000' + CAST(ISNULL(TRY_CAST(LTRIM(RTRIM(K.number_raw)) AS INT), ROW_NUMBER() OVER (PARTITION BY P.id_pais ORDER BY K.player_name_raw)) AS VARCHAR(3)), 3) AS nro_doc,
        COALESCE(NULLIF(LTRIM(RTRIM(K.first_name_raw)), ''), LTRIM(RTRIM(K.player_name_raw)), 'Sin Nombre') AS nombre,
        COALESCE(NULLIF(LTRIM(RTRIM(K.last_name_raw)), ''), 'Sin Apellido') AS apellido,
        COALESCE(
            TRY_CAST(LTRIM(RTRIM(K.dob_raw)) AS DATE),
            TRY_CONVERT(DATE, LTRIM(RTRIM(K.dob_raw)), 103),
            TRY_CONVERT(DATE, LTRIM(RTRIM(K.dob_raw)), 101),
            TRY_CONVERT(DATE, LTRIM(RTRIM(K.dob_raw)), 120),
            TRY_CONVERT(DATE, LTRIM(RTRIM(K.dob_raw)), 111),
            CAST('2000-01-01' AS DATE)
        ) AS fecha_nacimiento,
        ISNULL(NULLIF(LTRIM(RTRIM(K.position_raw)), ''), 'Mediocampista') AS posicion_habitual,
        ISNULL(NULLIF(LTRIM(RTRIM(K.club_raw)), ''), 'Agente Libre') AS club_origen,
        ISNULL(TRY_CAST(REPLACE(LTRIM(RTRIM(K.height_cm_raw)), ',', '.') AS DECIMAL(5,2)), 180.00) AS altura_cm,
        ROUND(
            CASE 
                WHEN TRY_CAST(REPLACE(LTRIM(RTRIM(K.height_cm_raw)), ',', '.') AS DECIMAL(5,2)) > 140
                    THEN (TRY_CAST(REPLACE(LTRIM(RTRIM(K.height_cm_raw)), ',', '.') AS DECIMAL(5,2)) - 100.0) * 0.90
                ELSE 75.00
            END, 2
        ) AS peso_kg,
        ISNULL(TRY_CAST(LTRIM(RTRIM(K.number_raw)) AS INT), ROW_NUMBER() OVER (PARTITION BY P.id_pais ORDER BY K.player_name_raw)) AS dorsal_oficial
    INTO #JugadoresLimpios
    FROM #StagingKaggle K
    -- Mapeo con traducción de códigos FIFA vs ISO
    INNER JOIN geografia.PAIS P ON P.id_pais = 
        CASE UPPER(LTRIM(RTRIM(K.team_code_raw)))
            WHEN 'ALG' THEN 'DZA' -- Argelia
            WHEN 'CRC' THEN 'CRI' -- Costa Rica
            WHEN 'HAI' THEN 'HTI' -- Haití
            WHEN 'KSA' THEN 'SAU' -- Arabia Saudita
            WHEN 'SUI' THEN 'SUI'
            WHEN 'NED' THEN 'NED'
            ELSE UPPER(LTRIM(RTRIM(K.team_code_raw)))
        END
    INNER JOIN torneo.SELECCION SEL ON SEL.id_pais = P.id_pais
    WHERE K.player_name_raw IS NOT NULL 
      AND K.player_name_raw <> '';

    -- 3. Superclase persona.PERSONA
    BEGIN TRY
        MERGE INTO persona.PERSONA AS Target
        USING (
            SELECT DISTINCT 
                nro_doc, tipo_doc, id_pais AS id_nacionalidad_pais, 
                nombre, apellido, fecha_nacimiento, 'JUGADOR' AS tipo_persona
            FROM #JugadoresLimpios
        ) AS Source
        ON Target.nro_doc = Source.nro_doc AND Target.tipo_doc = Source.tipo_doc
        WHEN MATCHED THEN
            UPDATE SET 
                nombre = Source.nombre,
                apellido = Source.apellido,
                fecha_nacimiento = Source.fecha_nacimiento,
                id_nacionalidad_pais = Source.id_nacionalidad_pais
        WHEN NOT MATCHED THEN
            INSERT (nro_doc, tipo_doc, id_nacionalidad_pais, nombre, apellido, fecha_nacimiento, tipo_persona)
            VALUES (Source.nro_doc, Source.tipo_doc, Source.id_nacionalidad_pais, Source.nombre, Source.apellido, Source.fecha_nacimiento, Source.tipo_persona);

        PRINT '--> [OK] Superclase persona.PERSONA sincronizada exitosamente.';
    END TRY
    BEGIN CATCH
        PRINT '--> [ERROR persona.PERSONA]: ' + ERROR_MESSAGE();
    END CATCH;

    -- 4. Subclase persona.JUGADOR
    BEGIN TRY
        MERGE INTO persona.JUGADOR AS Target
        USING (
            SELECT DISTINCT 
                nro_doc, tipo_doc, posicion_habitual, club_origen, 
                peso_kg, altura_cm, 1 AS es_convocado
            FROM #JugadoresLimpios
        ) AS Source
        ON Target.nro_doc = Source.nro_doc AND Target.tipo_doc = Source.tipo_doc
        WHEN MATCHED THEN
            UPDATE SET 
                posicion_habitual = Source.posicion_habitual,
                club_origen = Source.club_origen,
                peso_kg = Source.peso_kg,
                altura_cm = Source.altura_cm,
                es_convocado = 1
        WHEN NOT MATCHED THEN
            INSERT (nro_doc, tipo_doc, posicion_habitual, club_origen, peso_kg, altura_cm, es_convocado)
            VALUES (Source.nro_doc, Source.tipo_doc, Source.posicion_habitual, Source.club_origen, Source.peso_kg, Source.altura_cm, Source.es_convocado);

        PRINT '--> [OK] Subclase persona.JUGADOR sincronizada exitosamente.';
    END TRY
    BEGIN CATCH
        PRINT '--> [ERROR persona.JUGADOR]: ' + ERROR_MESSAGE();
    END CATCH;

    -- 5. torneo.CONVOCATORIA
    BEGIN TRY
        MERGE INTO torneo.CONVOCATORIA AS Target
        USING (
            SELECT 
                id_seleccion, dorsal_oficial, nro_doc, tipo_doc, 'ACTIVO' AS estado_convocatoria
            FROM #JugadoresLimpios
            WHERE dorsal_oficial BETWEEN 1 AND 99
        ) AS Source
        ON Target.id_seleccion = Source.id_seleccion 
       AND Target.dorsal_oficial = Source.dorsal_oficial
        WHEN MATCHED THEN
            UPDATE SET 
                nro_doc = Source.nro_doc,
                tipo_doc = Source.tipo_doc,
                estado_convocatoria = Source.estado_convocatoria
        WHEN NOT MATCHED THEN
            INSERT (id_seleccion, dorsal_oficial, nro_doc, tipo_doc, estado_convocatoria)
            VALUES (Source.id_seleccion, Source.dorsal_oficial, Source.nro_doc, Source.tipo_doc, Source.estado_convocatoria);

        PRINT '--> [OK] torneo.CONVOCATORIA sincronizada exitosamente.';
    END TRY
    BEGIN CATCH
        PRINT '--> [ERROR torneo.CONVOCATORIA]: ' + ERROR_MESSAGE();
    END CATCH;

    DROP TABLE #StagingKaggle;
    DROP TABLE #JugadoresLimpios;


    PRINT '  IMPORTACIÓN DE PLANTILLAS FINALIZADA CON ÉXITO                        ';
  
END;
GO