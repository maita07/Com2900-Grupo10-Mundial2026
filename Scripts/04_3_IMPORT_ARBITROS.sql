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
    @RutaArchivoCSV     VARCHAR(500) = NULL,                -- Info de los arbitros
    @RutaArchivoHTML    VARCHAR(500) = NULL,                -- HTML para deducir el rol
    @IdRolPrincipal     INT          = 1,
    @IdRolAsistente     INT          = 2,
    @IdRolCuarto        INT          = 3,
    @IdRolVAR           INT          = 4,
    @CategoriaFifa      VARCHAR(50)  = 'FIFA',              -- El CSV no dice
    @AniosExperiencia   INT          = 0,                   -- El CSV no dice
    @TipoDoc            VARCHAR(10)  = 'PASAPORTE'          -- Tipo de documento generico
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Proceso VARCHAR(100) = 'persona.sp_IMPORTAR_ARBITROS';
    DECLARE @Sql NVARCHAR(MAX);
    DECLARE @Msg NVARCHAR(4000);
    DECLARE @Total INT = 0, @Fila INT = 1;
    DECLARE @Altas INT = 0, @Modificados INT = 0, @Errores INT = 0;

    -- Variables para el HTML
    DECLARE @Html VARCHAR(MAX), @SeccionVAR VARCHAR(MAX);
    DECLARE @P1 INT, @P2 INT, @P3 INT;

    -- Variables de trabajo por fila
    DECLARE @NroDoc VARCHAR(20), @Apellido VARCHAR(50), @Nombre VARCHAR(50),
            @FechaTxt VARCHAR(30), @IdPais VARCHAR(10), @IdRol INT;
    DECLARE @IdRolAux INT, @DescRolAux VARCHAR(40);
    DECLARE @Fecha DATE, @Accion CHAR(1), @Pos INT;
    DECLARE @NombreCompleto VARCHAR(200), @Articulo VARCHAR(500);
    DECLARE @ErroresFila NVARCHAR(MAX);

    PRINT '     IMPORTACIÓN MASIVA: ÁRBITROS (CSV WIKIDATA + HTML WIKIPEDIA)          ';

    -- 0. Validación de parámetros
    IF @RutaArchivoCSV IS NULL OR TRIM(@RutaArchivoCSV) = ''
        THROW 50010, 'Debe indicar la ruta del archivo CSV de árbitros (@RutaArchivoCSV).', 1;

    -- 1. Tablas temporales de staging
    CREATE TABLE #RawArbitro (
        articulo VARCHAR(500), itemLabel VARCHAR(200), fecha_nacimiento VARCHAR(50),
        paisLabel VARCHAR(200), codigo_pais VARCHAR(50)
    );

    CREATE TABLE #Arbitro (
        nro_fila INT NOT NULL PRIMARY KEY,
        articulo VARCHAR(500), slug VARCHAR(500) NULL, nro_doc VARCHAR(20) NULL,
        nombre_completo VARCHAR(200), fecha_nacimiento VARCHAR(50), codigo_pais VARCHAR(50),
        id_rol INT NULL
    );

    -- 2. Carga del CSV (SQL dinámico necesario para BULK INSERT)
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

    -- 3a. Lectura del HTML
    IF @RutaArchivoHTML IS NOT NULL AND TRIM(@RutaArchivoHTML) <> ''
    BEGIN
        BEGIN TRY
            -- SQL dinámico necesario para OPENROWSET(BULK)
            SET @Sql = N'SELECT @H = BulkColumn
                         FROM OPENROWSET(BULK ''' + REPLACE(@RutaArchivoHTML, '''', '''''') + N''', SINGLE_CLOB) AS T;';
            EXEC sp_executesql @Sql, N'@H VARCHAR(MAX) OUTPUT', @H = @Html OUTPUT;

            SET @P1 = CHARINDEX('<table class="wikitable', @Html);
            SET @P2 = CASE WHEN @P1 > 0 THEN CHARINDEX('<table class="wikitable', @Html, @P1 + 1) ELSE 0 END;

            IF @P2 = 0
                THROW 50016, 'No se encontró la tabla de árbitros de VAR en el HTML.', 1;

            SET @P3 = CHARINDEX('</table>', @Html, @P2);
            SET @SeccionVAR = SUBSTRING(@Html, @P2, @P3 - @P2);
        END TRY
        BEGIN CATCH
            SET @Msg = CONCAT('No se pudo procesar el HTML "', @RutaArchivoHTML, '": ', ERROR_MESSAGE());

            INSERT INTO auditoria.LOG_IMPORTACION (proceso_origen, nro_fila, clave_registro, mensaje_error, linea_error)
            VALUES (@Proceso, NULL, NULL, @Msg, ERROR_LINE());

            THROW 50015, @Msg, 1;
        END CATCH;
    END;

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

    -- 4. Normalización
    WITH Limpio AS (
        SELECT TRIM(R.articulo) AS articulo,
               TRIM(R.itemLabel) AS nombre_completo,
               TRIM(R.fecha_nacimiento) AS fecha_nacimiento,
               CASE WHEN UPPER(TRIM(REPLACE(R.codigo_pais, CHAR(13), ''))) = 'GBR' THEN 'ENG'
                    ELSE UPPER(TRIM(REPLACE(R.codigo_pais, CHAR(13), ''))) END AS codigo_pais
        FROM #RawArbitro R
        WHERE R.articulo IS NOT NULL AND TRIM(R.articulo) <> ''
    ),
    Depurado AS (
        SELECT L.*,
               ROW_NUMBER() OVER (
                   PARTITION BY L.articulo
                   ORDER BY CASE WHEN EXISTS (SELECT 1 FROM geografia.PAIS P WHERE P.id_pais = L.codigo_pais)
                                 THEN 0 ELSE 1 END,
                            L.codigo_pais
               ) AS rn
        FROM Limpio L
    )
    INSERT INTO #Arbitro (nro_fila, articulo, nombre_completo, fecha_nacimiento, codigo_pais)
    SELECT ROW_NUMBER() OVER (ORDER BY articulo), articulo, nombre_completo, fecha_nacimiento, codigo_pais
    FROM Depurado
    WHERE rn = 1;

    SELECT @Total = COUNT(*) FROM #Arbitro;

    IF @Total = 0
    BEGIN
        INSERT INTO auditoria.LOG_IMPORTACION (proceso_origen, nro_fila, clave_registro, mensaje_error, linea_error)
        VALUES (@Proceso, NULL, NULL, 'El archivo no contiene registros para importar.', NULL);

        THROW 50012, 'El archivo no contiene registros para importar.', 1;
    END;

    -- 5. Documento generico y rol
    UPDATE #Arbitro
    SET slug   = SUBSTRING(articulo, CHARINDEX('/wiki/', articulo) + 6, 500),
        nro_doc = 'WD-' + LEFT(CONVERT(VARCHAR(34), HASHBYTES('MD5', articulo), 2), 16)
    WHERE CHARINDEX('/wiki/', articulo) > 0;

    UPDATE #Arbitro
    SET id_rol = CASE WHEN @SeccionVAR IS NOT NULL
                       AND CHARINDEX('href="https://en.wikipedia.org/wiki/' + slug + '"', @SeccionVAR) > 0
                      THEN @IdRolVAR
                      ELSE @IdRolPrincipal END;

    -- 6. Procesamiento
    WHILE @Fila <= @Total
    BEGIN
        SELECT @Articulo = articulo, @NroDoc = nro_doc, @NombreCompleto = nombre_completo,
               @FechaTxt = fecha_nacimiento, @IdPais = codigo_pais, @IdRol = id_rol
        FROM #Arbitro
        WHERE nro_fila = @Fila;

        BEGIN TRY
            SET @ErroresFila = N'';

            SET @Fecha = TRY_CONVERT(DATE, LEFT(@FechaTxt, 10), 23);

            SET @Pos = CHARINDEX(' ', ISNULL(@NombreCompleto, ''));
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
            IF @NroDoc IS NULL
                SET @ErroresFila += N'- link del artículo inválido (no se pudo generar el documento). ';
            IF @NombreCompleto IS NULL OR @NombreCompleto = ''
                SET @ErroresFila += N'- itemLabel (nombre) vacío. ';
            IF @Fecha IS NULL
                SET @ErroresFila += N'- fecha_nacimiento inválida o vacía. ';
            IF @IdPais IS NULL OR LEN(@IdPais) <> 3
                SET @ErroresFila += N'- codigo_pais vacío o distinto de 3 caracteres. ';

            IF LEN(@ErroresFila) > 0
            BEGIN
                SET @Msg = N'Error de formato en la fila ' + CAST(@Fila AS NVARCHAR(10)) + N': ' + @ErroresFila;
                THROW 50013, @Msg, 1;
            END;

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
                 @anios_experiencia    = @AniosExperiencia;

            IF @Accion = 'A' SET @Altas += 1; ELSE SET @Modificados += 1;
        END TRY
        BEGIN CATCH
            SET @Errores += 1;

            INSERT INTO auditoria.LOG_IMPORTACION (proceso_origen, nro_fila, clave_registro, mensaje_error, linea_error)
            VALUES (@Proceso, @Fila, LEFT(CONCAT(@NombreCompleto, ' (', @Articulo, ')'), 100), ERROR_MESSAGE(), ERROR_LINE());
        END CATCH;

        SET @Fila += 1;
    END;

    -- 7. Resumen
    PRINT CONCAT('--> Árbitros leídos: ', @Total, ' | Altas: ', @Altas, ' | Modificaciones: ', @Modificados, ' | Con error: ', @Errores);

    IF @Errores > 0
        PRINT '--> Hay registros rechazados. Ver auditoria.LOG_IMPORTACION (proceso_origen = ''persona.sp_IMPORTAR_ARBITROS'').';

    -- Si no se pudo importar ningún registro se informa como excepción
    IF @Errores = @Total
    BEGIN
        SET @Msg = N'No se pudo importar ningún registro del archivo. Revise auditoria.LOG_IMPORTACION.';
        THROW 50014, @Msg, 1;
    END;

    PRINT '             PROCESO DE IMPORTACIÓN FINALIZADO                          ';
END;
GO