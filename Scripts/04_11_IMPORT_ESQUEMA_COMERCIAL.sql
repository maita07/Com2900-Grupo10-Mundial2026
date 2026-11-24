/*
================================================================================
UNLaM - Universidad Nacional de La Matanza
Departamento de Ingeniería e Investigaciones Tecnológicas
Materia: Base de Datos Aplicada (Comisión 5600)
Entrega 6 - Script 04_10: Importación de ANUNCIANTE, CAMPANIA_PUBLICITARIA,
PIEZA_PUBLICITARIA y PIEZA_MERCADO
Creacion de los datos de EXHIBICION_PUBLICITARIA 
2026 - 2C
Grupo 10

Integrantes:
- Monasterio Erik: MonasteryEr
- Arena Ariel Ignacio: arielarena
- Castillo Gabriela Florencia: ItsFlorencia
- Maita Pitado Jose Gregorio: maita07

Archivo: 04_10_IMPORT_ESQUEMA_COMERCIAL.sql
Descripcion:
	Se realizara la importacion de los datos de anunciante, campania_publicita-
	ria, pieza_publicitaria y pieza_mercado mediante el uso de una
	API falsa creada especificamente con los datos necesarios para este TP.
	Cabe aclarar que esta opcion fue tomada debido a que no encontramos el recurso
	en ningun lado. Por lo que se crearon datos con publicitantes reales, sus productos
	y algunas campañas existentes y luego se subieron a la api creada en "supabase". 

================================================================================
*/
USE DB_Mundial2026_Grupo10;
GO

EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'Ole Automation Procedures', 1;
RECONFIGURE;
GO

CREATE OR ALTER PROCEDURE comercial.sp_IMPORT_ESQUEMA_COMERCIAL
	@Url VARCHAR(100) = 'https://bbapjinjuidnaezbiiyu.supabase.co/rest/v1/',
	@ApiKey VARCHAR(100) = 'sb_publishable_2YiO3JS7iFIMrJioGpbxoA_v1z3jqga'
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @Proceso VARCHAR(100) = 'comercial.sp_IMPORT_ESQUEMA_COMERCIAL';
    DECLARE @Fila INT, @Total INT, @Accion CHAR(1), @Altas INT, @Mod INT, @Err INT;
    DECLARE @Sql VARCHAR(MAX), @Msg VARCHAR(4000), @Bin VARBINARY(MAX);
    DECLARE @JsonAnunciante VARCHAR(MAX), @JsonCampania VARCHAR(MAX), 
            @JsonPieza VARCHAR(MAX), @JsonMercado VARCHAR(MAX);
    DECLARE @UrlActual VARCHAR(1000), @Paso INT = 1;
    DECLARE @Obj INT, @HResult INT, @Status INT;
    DECLARE @Respuesta TABLE (txt VARCHAR(MAX));

    PRINT '     IMPORTACIÓN: PUBLICIDAD Y EXHIBICIONES    ';

-- OBTENCION DE LOS 4 JSON A TRAVEZ DE ENDPOINT

    WHILE @Paso <= 4
     BEGIN
         SET @UrlActual = CONCAT(@Url, 
             CASE @Paso 
                 WHEN 1 THEN 'anunciante'
                 WHEN 2 THEN 'campania_publicitaria'
                 WHEN 3 THEN 'pieza_publicitaria'
                 WHEN 4 THEN 'pieza_mercado'
             END);

         BEGIN TRY
             DELETE FROM @Respuesta;

             EXEC @HResult = sp_OACreate 'MSXML2.ServerXMLHTTP.6.0', @Obj OUT;
             IF @HResult = 0 EXEC @HResult = sp_OAMethod @Obj, 'open', NULL, 'GET', @UrlActual, 'false';
             -- Headers específicos de API
             IF @HResult = 0 EXEC @HResult = sp_OAMethod @Obj, 'setRequestHeader', NULL, 'apikey', @ApiKey;
             IF @HResult = 0 EXEC @HResult = sp_OAMethod @Obj, 'setRequestHeader', NULL, 'Accept-Profile', 'comercial';
             IF @HResult = 0 EXEC @HResult = sp_OAMethod @Obj, 'setRequestHeader', NULL, 'Accept', 'application/json';
             IF @HResult = 0 EXEC @HResult = sp_OAMethod @Obj, 'send';
             IF @HResult <> 0 THROW 50212, 'Error en la conexión HTTP con Supabase.', 1;

             EXEC sp_OAGetProperty @Obj, 'status', @Status OUT;
             IF @Status <> 200
             BEGIN
                 SET @Msg = CONCAT('Supabase respondió con HTTP ', ISNULL(@Status, 0), ' en ', @UrlActual);
                 THROW 50213, @Msg, 1;
             END;

             INSERT INTO @Respuesta (txt) EXEC sp_OAGetProperty @Obj, 'responseText';
             EXEC sp_OADestroy @Obj;
             SET @Obj = NULL;

             IF @Paso = 1 SELECT TOP 1 @JsonAnunciante = txt FROM @Respuesta;
             IF @Paso = 2 SELECT TOP 1 @JsonCampania   = txt FROM @Respuesta;
             IF @Paso = 3 SELECT TOP 1 @JsonPieza      = txt FROM @Respuesta;
             IF @Paso = 4 SELECT TOP 1 @JsonMercado    = txt FROM @Respuesta;
         END TRY
         BEGIN CATCH
             IF @Obj IS NOT NULL EXEC sp_OADestroy @Obj;
             SET @Obj = NULL;
             SET @Msg = CONCAT('Error descargando endpoint ', @UrlActual, ': ', ERROR_MESSAGE());
             INSERT INTO auditoria.LOG_IMPORTACION (proceso_origen, nro_fila, clave_registro, mensaje_error, linea_error)
             VALUES (@Proceso, @Paso, LEFT(@UrlActual, 100), @Msg, ERROR_LINE());
             THROW 50214, @Msg, 1;
         END CATCH;

         SET @Paso += 1;
     END;


    -- Declaracion de variables reutilizadas en cada insercion
        DECLARE @IdAnun INT, @IdCamp INT,@IdPieza INT,@IdEx INT

        DECLARE @MapeoPais TABLE (
            codigo_entrada CHAR(3) PRIMARY KEY,
            codigo_local CHAR(3) NOT NULL
        );

        INSERT INTO @MapeoPais (codigo_entrada, codigo_local) VALUES
        ('DEU', 'GER'), ('GBR', 'ENG'), ('NLD', 'NED'), 
        ('CHE', 'SUI'), ('URY', 'URU'), ('PRY', 'PAR'), 
        ('HRV', 'CRO'), ('ZAF', 'RSA'), ('DZA', 'ALG'), 
        ('SAU', 'KSA'), ('PRT', 'POR'), ('BIH', 'BIH'), 
        ('CUW', 'CUW'), ('HTI', 'HAI'); 

    -- Incercion 1 (Tabla ANUNCIANTE)

    SELECT ROW_NUMBER() OVER (ORDER BY id_anunciante) AS nro_fila,
           id_anunciante, id_pais_origen, razon_social, marca_comercial, rubro
    INTO #StgAnunciante
    FROM OPENJSON(@JsonAnunciante)
    WITH (
        id_anunciante   INT          '$.id_anunciante',
        id_pais_origen  CHAR(3)  '$.id_pais_origen',
        razon_social    VARCHAR(150) '$.razon_social',
        marca_comercial VARCHAR(150) '$.marca_comercial',
        rubro           VARCHAR(100) '$.rubro'
    );

    SELECT @Fila = 1, @Total = COUNT(*), @Altas = 0, @Mod = 0, @Err = 0 FROM #StgAnunciante;

    DECLARE @Pais CHAR(3), @Razon VARCHAR(150), @Marca VARCHAR(150), @Rubro VARCHAR(100);

    WHILE @Fila <= @Total
    BEGIN
        SELECT @IdAnun = id_anunciante, @Pais = id_pais_origen, @Razon = razon_social, 
               @Marca = marca_comercial, @Rubro = rubro
        FROM #StgAnunciante WHERE nro_fila = @Fila;

        BEGIN TRY
            SET @Accion = CASE WHEN EXISTS (SELECT 1 FROM comercial.ANUNCIANTE WHERE id_anunciante = @IdAnun) 
                               THEN 'M' ELSE 'A' END;

            SET @Pais = UPPER(TRIM(@Pais));

            SELECT @Pais = ISNULL(
                (SELECT codigo_local FROM @MapeoPais WHERE codigo_entrada = @Pais),
                @Pais
            );

            EXEC comercial.sp_ANUNCIANTE_ABM
                 @Accion          = @Accion,
                 @id_anunciante   = @IdAnun,
                 @id_pais_origen  = @Pais,
                 @razon_social    = @Razon,
                 @marca_comercial = @Marca,
                 @rubro           = @Rubro;

            IF @Accion = 'A' SET @Altas += 1; ELSE SET @Mod += 1;
        END TRY
        BEGIN CATCH
            SET @Err += 1;
            INSERT INTO auditoria.LOG_IMPORTACION (proceso_origen, nro_fila, clave_registro, mensaje_error, linea_error)
            VALUES (@Proceso, @Fila, CONCAT('Anunciante ID ', @IdAnun, ' - ', @Marca), ERROR_MESSAGE(), ERROR_LINE());
        END CATCH;

        SET @Fila += 1;
    END;
    PRINT CONCAT('--> Anunciantes: ', @Total, ' | Altas: ', @Altas, ' | Mod: ', @Mod, ' | Error: ', @Err);

    -- Incercion 2 (Tabla CAMPANIA_PUBLICITARIA)
    
    SELECT ROW_NUMBER() OVER (ORDER BY id_campania) AS nro_fila,
           id_campania,id_anunciante, nombre_campania, presupuesto_max_usd, fecha_inicio, fecha_fin
    INTO #StgCampania
    FROM OPENJSON(@JsonCampania)
    WITH (
        id_campania INT                     '$.id_campania',
        id_anunciante INT                   '$.id_anunciante',
        nombre_campania VARCHAR(100)        '$.nombre_campania',
        presupuesto_max_usd DECIMAL(18,2)   '$.presupuesto_max_usd',
        fecha_inicio DATE                   '$.fecha_inicio',
        fecha_fin DATE                      '$.fecha_fin'
    );

    SELECT @Fila = 1, @Total = COUNT(*), @Altas = 0, @Mod = 0, @Err = 0 FROM #StgCampania;

    DECLARE @NombreCamp VARCHAR(100), @MaxUsd DECIMAL(18,2), @Ini DATE, @Fin DATE;

    WHILE @Fila <= @Total
    BEGIN
        SELECT @IdCamp = id_campania, @IdAnun = id_anunciante, @NombreCamp = nombre_campania, @MaxUsd = presupuesto_max_usd, @Ini = fecha_inicio, @Fin = fecha_fin
        FROM #StgCampania WHERE nro_fila = @Fila;

        BEGIN TRY
            SET @Accion = CASE WHEN EXISTS (SELECT 1 FROM comercial.CAMPANIA_PUBLICITARIA WHERE id_campania = @IdCamp) 
                               THEN 'M' ELSE 'A' END;

            EXEC comercial.sp_CAMPANIA_PUBLICITARIA_ABM
                @Accion              = @Accion,
                @id_campania         = @IdCamp,
                @id_anunciante       = @IdAnun,
                @nombre_campania     = @NombreCamp,
                @presupuesto_max_usd = @MaxUsd,
                @fecha_inicio        = @Ini,
                @fecha_fin           = @Fin;

            IF @Accion = 'A' SET @Altas += 1; ELSE SET @Mod += 1;
        END TRY
        BEGIN CATCH
            SET @Err +=1;
            INSERT INTO auditoria.LOG_IMPORTACION (proceso_origen, nro_fila, clave_registro, mensaje_error, linea_error)
            VALUES (@Proceso, @Fila, CONCAT('CAMPANIA ID ', @IdCamp, ' - ', @NombreCamp), ERROR_MESSAGE(), ERROR_LINE());
        END CATCH

        SET @Fila += 1;
    END;
    PRINT CONCAT('--> Campanias: ', @Total, ' | Altas: ', @Altas, ' | Mod: ', @Mod, ' | Error: ', @Err);
    -- Incercion 3 (Tabla PIEZA_PUBLICITARIA)

    SELECT ROW_NUMBER() OVER (ORDER BY id_pieza) AS nro_fila,
           id_pieza,id_campania, url_contenido, duracion_segundos, idioma, descripcion_pieza
    INTO #StgPieza
    FROM OPENJSON(@JsonPieza)
    WITH (
        id_pieza INT                    '$.id_pieza',
        id_campania INT                 '$.id_campania',
        url_contenido VARCHAR(255)      '$.url_contenido',
        duracion_segundos INT           '$.duracion_segundos',
        idioma VARCHAR(20)              '$.idioma',
        descripcion_pieza VARCHAR(100)  '$.descripcion_pieza'
    );

    SELECT @Fila = 1, @Total = COUNT(*), @Altas = 0, @Mod = 0, @Err = 0 FROM #StgPieza;

    DECLARE @UrlCont VARCHAR(255),@Duracion INT , @Idioma varchar(20),@DescPieza varchar(100);

    WHILE @Fila <= @Total
    BEGIN
        SELECT @IdPieza = id_pieza, @IdCamp = id_campania, @UrlCont = url_contenido, @Duracion = duracion_segundos, @Idioma = idioma, @DescPieza = descripcion_pieza
        FROM #StgPieza WHERE nro_fila = @Fila

        BEGIN TRY 
            SET @Accion = CASE WHEN EXISTS (SELECT 1 FROM comercial.PIEZA_PUBLICITARIA WHERE id_pieza = @IdPieza) 
                               THEN 'M' ELSE 'A' END;

            EXEC comercial.sp_PIEZA_PUBLICITARIA_ABM
                    @Accion            = @Accion,
                    @id_pieza          = @IdPieza,
                    @id_campania       = @IdCamp,
                    @url_contenido     = @UrlCont,
                    @duracion_segundos = @Duracion,
                    @idioma            = @Idioma,
                    @descripcion_pieza = @DescPieza;

           IF @Accion = 'A' SET @Altas += 1; ELSE SET @Mod += 1;
        END TRY
        BEGIN CATCH
            SET @Err +=1;
            INSERT INTO auditoria.LOG_IMPORTACION (proceso_origen, nro_fila, clave_registro, mensaje_error, linea_error)
            VALUES (@Proceso, @Fila, CONCAT('Pieza ID ', @IdAnun, ' - ID Campania', @IdCamp), ERROR_MESSAGE(), ERROR_LINE());
        END CATCH

        SET @Fila += 1;
    END;
    PRINT CONCAT('--> Piezas Publicitarias: ', @Total, ' | Altas: ', @Altas, ' | Mod: ', @Mod, ' | Error: ', @Err);

    -- Incercion 4 (Tabla PIEZA_MERCADO)

    SELECT ROW_NUMBER() OVER (ORDER BY id_pieza) AS nro_fila,
           id_pieza,id_pais
    INTO #StgMercado
    FROM OPENJSON(@JsonMercado)
    WITH(
        id_pieza INT    '$.id_pieza',
        id_pais CHAR(3) '$.id_pais'
    );

    SELECT @Fila = 1, @Total = COUNT(*), @Altas = 0, @Mod = 0, @Err = 0 FROM #StgMercado;

    DECLARE @Pieza INT, @IdPais CHAR(3);

    WHILE @Fila <= @Total
    BEGIN
        SELECT @Pieza = id_pieza, @IdPais = id_pais 
        FROM #StgMercado WHERE nro_fila = @Fila;

        BEGIN TRY

            SET @IdPais = UPPER(TRIM(@IdPais));

            SELECT @IdPais = ISNULL(
                (SELECT codigo_local FROM @MapeoPais WHERE codigo_entrada = @IdPais),
                @IdPais
            );


            SET @Accion = CASE WHEN EXISTS (SELECT 1 FROM comercial.PIEZA_MERCADO WHERE id_pieza = @Pieza AND id_pais = @IdPais) 
                               THEN 'M' ELSE 'A' END;

            EXEC comercial.sp_PIEZA_MERCADO_ABM
                @Accion     =     @Accion,
                @id_pieza   =     @Pieza,
                @id_pais    =     @IdPais;

            IF @Accion = 'A' SET @Altas += 1; ELSE SET @Mod += 1;

        END TRY
        BEGIN CATCH
            SET @Err +=1;
            INSERT INTO auditoria.LOG_IMPORTACION (proceso_origen, nro_fila, clave_registro, mensaje_error, linea_error)
            VALUES (@Proceso, @Fila, CONCAT('Pieza ID ', @IdAnun, ' - Pais ID ', @Pais), ERROR_MESSAGE(), ERROR_LINE());
        END CATCH;

        SET @Fila += 1;
    END;
    PRINT CONCAT('--> Relaciones de mercado: ', @Total, ' | Altas: ', @Altas, ' | Mod: ', @Mod, ' | Error: ', @Err);
END;