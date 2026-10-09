/*
---------------------------------------------------------
UNLaM - Universidad Nacional de La Matanza
Departamento de Ingeniería e Investigaciones Tecnológicas
Materia: Base de Datos Aplicada (Comisión 5600)
Entrega 5 - Base de Datos T-SQL
2026 - 2C
Grupo 10

Integrantes:
- Monasterio Erik: MonasteryEr
- Arena Ariel Ignacio: arielarena
- Castillo Gabriela Florencia: ItsFlorencia
- Maita Pitado Jose Gregorio: maita07

Descripcion: Script T-SQL de creación de Stored Procedures de ABM 
             para el Módulo 7: Publicidad y Comercial.
             Procedimientos incluidos:
             - comercial.sp_ANUNCIANTE_ABM
             - comercial.sp_CAMPANIA_PUBLICITARIA_ABM
             - comercial.sp_PIEZA_PUBLICITARIA_ABM
             - comercial.sp_EXHIBICION_PUBLICITARIA_ABM
---------------------------------------------------------
*/

USE DB_Mundial2026_Grupo10;
GO

-- ============================================================================
-- 1. comercial.sp_ANUNCIANTE_ABM
-- Tabla: comercial.ANUNCIANTE
-- PK: id_anunciante INT
-- ============================================================================
CREATE OR ALTER PROCEDURE comercial.sp_ANUNCIANTE_ABM
    @Accion           CHAR(1),
    @id_anunciante    INT          = NULL,
    @id_pais_origen   CHAR(3)      = NULL,
    @razon_social     VARCHAR(120) = NULL,
    @marca_comercial  VARCHAR(80)  = NULL,
    @rubro            VARCHAR(50)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ErroresAcumulados NVARCHAR(MAX) = N'';

    -- 1. Validación de Acción
    IF @Accion NOT IN ('A', 'M', 'B') OR @Accion IS NULL
        SET @ErroresAcumulados += N'- La acción es obligatoria y debe ser A (Alta), M (Modificación) o B (Baja).' + CHAR(13);

    -- 2. Validación de Clave Primaria
    IF @id_anunciante IS NULL
        SET @ErroresAcumulados += N'- El id_anunciante es obligatorio.' + CHAR(13);

    -- 3. Existencia / Duplicidad de PK
    IF @id_anunciante IS NOT NULL
    BEGIN
        IF @Accion = 'A' AND EXISTS (SELECT 1 FROM comercial.ANUNCIANTE WHERE id_anunciante = @id_anunciante)
            SET @ErroresAcumulados += N'- El anunciante ya existe en la base de datos (PK duplicada).' + CHAR(13);

        IF @Accion IN ('M', 'B') AND NOT EXISTS (SELECT 1 FROM comercial.ANUNCIANTE WHERE id_anunciante = @id_anunciante)
            SET @ErroresAcumulados += N'- El anunciante indicado no existe en la base de datos.' + CHAR(13);
    END;

    -- 4. Validaciones de dominio e integridad para Alta y Modificación
    IF @Accion IN ('A', 'M')
    BEGIN
        IF @id_pais_origen IS NULL OR TRIM(@id_pais_origen) = ''
            SET @ErroresAcumulados += N'- El id_pais_origen es obligatorio.' + CHAR(13);
        ELSE IF NOT EXISTS (SELECT 1 FROM geografia.PAIS WHERE id_pais = UPPER(TRIM(@id_pais_origen)))
            SET @ErroresAcumulados += N'- El id_pais_origen especificado no existe en la tabla PAIS.' + CHAR(13);

        IF @razon_social IS NULL OR TRIM(@razon_social) = N''
            SET @ErroresAcumulados += N'- La razon_social es obligatoria y no puede quedar vacía.' + CHAR(13);

        IF @marca_comercial IS NULL OR TRIM(@marca_comercial) = N''
            SET @ErroresAcumulados += N'- La marca_comercial es obligatoria y no puede quedar vacía.' + CHAR(13);

        IF @rubro IS NULL OR TRIM(@rubro) = N''
            SET @ErroresAcumulados += N'- El rubro es obligatorio y no puede quedar vacío.' + CHAR(13);
    END;

    -- 5. Restricción de Baja ('B'): No eliminar si posee campañas
    IF @Accion = 'B' AND @id_anunciante IS NOT NULL
    BEGIN
        IF EXISTS (SELECT 1 FROM comercial.CAMPANIA_PUBLICITARIA WHERE id_anunciante = @id_anunciante)
            SET @ErroresAcumulados += N'- No se puede eliminar el anunciante porque posee campañas publicitarias registradas.' + CHAR(13);
    END;

    -- Consolidación de errores
    IF LEN(@ErroresAcumulados) > 0
    BEGIN
        SET @ErroresAcumulados = N'Se encontraron los siguientes errores en comercial.sp_ANUNCIANTE_ABM:' 
                                 + CHAR(13) + @ErroresAcumulados;
        THROW 50000, @ErroresAcumulados, 1;
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @Accion = 'A'
        BEGIN
            INSERT INTO comercial.ANUNCIANTE (id_anunciante, id_pais_origen, razon_social, marca_comercial, rubro)
            VALUES (@id_anunciante, UPPER(TRIM(@id_pais_origen)), TRIM(@razon_social), TRIM(@marca_comercial), TRIM(@rubro));
        END
        ELSE IF @Accion = 'M'
        BEGIN
            UPDATE comercial.ANUNCIANTE
            SET id_pais_origen  = UPPER(TRIM(@id_pais_origen)),
                razon_social    = TRIM(@razon_social),
                marca_comercial = TRIM(@marca_comercial),
                rubro           = TRIM(@rubro)
            WHERE id_anunciante = @id_anunciante;
        END
        ELSE IF @Accion = 'B'
        BEGIN
            DELETE FROM comercial.ANUNCIANTE 
            WHERE id_anunciante = @id_anunciante;
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrMsgAnunciante NVARCHAR(4000) = ERROR_MESSAGE();
        THROW 50001, @ErrMsgAnunciante, 1;
    END CATCH;
END;
GO

-- ============================================================================
-- 2. comercial.sp_CAMPANIA_PUBLICITARIA_ABM
-- Tabla: comercial.CAMPANIA_PUBLICITARIA
-- PK: id_campania INT
-- ============================================================================
CREATE OR ALTER PROCEDURE comercial.sp_CAMPANIA_PUBLICITARIA_ABM
    @Accion              CHAR(1),
    @id_campania         INT             = NULL,
    @id_anunciante       INT             = NULL,
    @nombre_campania     VARCHAR(100)    = NULL,
    @presupuesto_max_usd DECIMAL(18,2)   = NULL,
    @fecha_inicio        DATE            = NULL,
    @fecha_fin           DATE            = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ErroresAcumulados NVARCHAR(MAX) = N'';

    -- 1. Validación de Acción
    IF @Accion NOT IN ('A', 'M', 'B') OR @Accion IS NULL
        SET @ErroresAcumulados += N'- La acción es obligatoria y debe ser A (Alta), M (Modificación) o B (Baja).' + CHAR(13);

    -- 2. Validación de Clave Primaria
    IF @id_campania IS NULL
        SET @ErroresAcumulados += N'- El id_campania es obligatorio.' + CHAR(13);

    -- 3. Existencia / Duplicidad de PK
    IF @id_campania IS NOT NULL
    BEGIN
        IF @Accion = 'A' AND EXISTS (SELECT 1 FROM comercial.CAMPANIA_PUBLICITARIA WHERE id_campania = @id_campania)
            SET @ErroresAcumulados += N'- La campaña publicitaria ya existe en la base de datos (PK duplicada).' + CHAR(13);

        IF @Accion IN ('M', 'B') AND NOT EXISTS (SELECT 1 FROM comercial.CAMPANIA_PUBLICITARIA WHERE id_campania = @id_campania)
            SET @ErroresAcumulados += N'- La campaña publicitaria indicada no existe en la base de datos.' + CHAR(13);
    END;

    -- 4. Validaciones de dominio e integridad para Alta y Modificación
    IF @Accion IN ('A', 'M')
    BEGIN
        IF @id_anunciante IS NULL
            SET @ErroresAcumulados += N'- El id_anunciante es obligatorio.' + CHAR(13);
        ELSE IF NOT EXISTS (SELECT 1 FROM comercial.ANUNCIANTE WHERE id_anunciante = @id_anunciante)
            SET @ErroresAcumulados += N'- El id_anunciante especificado no existe en la tabla ANUNCIANTE.' + CHAR(13);

        IF @nombre_campania IS NULL OR TRIM(@nombre_campania) = N''
            SET @ErroresAcumulados += N'- El nombre_campania es obligatorio y no puede quedar vacío.' + CHAR(13);

        IF @presupuesto_max_usd IS NULL OR @presupuesto_max_usd <= 0
            SET @ErroresAcumulados += N'- El presupuesto_max_usd debe ser estrictamente mayor a 0.' + CHAR(13);

        IF @fecha_inicio IS NULL OR @fecha_fin IS NULL
            SET @ErroresAcumulados += N'- Las fechas de inicio y fin son obligatorias.' + CHAR(13);
        ELSE IF @fecha_fin < @fecha_inicio
            SET @ErroresAcumulados += N'- La fecha_fin debe ser mayor o igual a la fecha_inicio.' + CHAR(13);
    END;

    -- 5. Restricción de Baja ('B'): Sin piezas ni exhibiciones vinculadas
    IF @Accion = 'B' AND @id_campania IS NOT NULL
    BEGIN
        IF EXISTS (SELECT 1 FROM comercial.PIEZA_PUBLICITARIA WHERE id_campania = @id_campania)
            SET @ErroresAcumulados += N'- No se puede eliminar la campaña porque posee piezas publicitarias vinculadas.' + CHAR(13);

        IF EXISTS (SELECT 1 FROM comercial.EXHIBICION_PUBLICITARIA WHERE id_campania = @id_campania)
            SET @ErroresAcumulados += N'- No se puede eliminar la campaña porque posee exhibiciones registradas.' + CHAR(13);
    END;

    -- Consolidación de errores
    IF LEN(@ErroresAcumulados) > 0
    BEGIN
        SET @ErroresAcumulados = N'Se encontraron los siguientes errores en comercial.sp_CAMPANIA_PUBLICITARIA_ABM:' 
                                 + CHAR(13) + @ErroresAcumulados;
        THROW 50000, @ErroresAcumulados, 1;
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @Accion = 'A'
        BEGIN
            INSERT INTO comercial.CAMPANIA_PUBLICITARIA (
                id_campania, id_anunciante, nombre_campania, presupuesto_max_usd, fecha_inicio, fecha_fin
            )
            VALUES (
                @id_campania, @id_anunciante, TRIM(@nombre_campania), @presupuesto_max_usd, @fecha_inicio, @fecha_fin
            );
        END
        ELSE IF @Accion = 'M'
        BEGIN
            UPDATE comercial.CAMPANIA_PUBLICITARIA
            SET id_anunciante       = @id_anunciante,
                nombre_campania     = TRIM(@nombre_campania),
                presupuesto_max_usd = @presupuesto_max_usd,
                fecha_inicio        = @fecha_inicio,
                fecha_fin           = @fecha_fin
            WHERE id_campania = @id_campania;
        END
        ELSE IF @Accion = 'B'
        BEGIN
            DELETE FROM comercial.CAMPANIA_PUBLICITARIA 
            WHERE id_campania = @id_campania;
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrMsgCampania NVARCHAR(4000) = ERROR_MESSAGE();
        THROW 50001, @ErrMsgCampania, 1;
    END CATCH;
END;
GO

-- ============================================================================
-- 3. comercial.sp_PIEZA_PUBLICITARIA_ABM
-- Tabla: comercial.PIEZA_PUBLICITARIA
-- PK: id_pieza INT
-- ============================================================================
CREATE OR ALTER PROCEDURE comercial.sp_PIEZA_PUBLICITARIA_ABM
    @Accion            CHAR(1),
    @id_pieza          INT          = NULL,
    @id_campania       INT          = NULL,
    @duracion_segundos INT          = NULL,
    @url_contenido     VARCHAR(200) = NULL,
    @idioma            VARCHAR(20)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ErroresAcumulados NVARCHAR(MAX) = N'';

    -- 1. Validación de Acción
    IF @Accion NOT IN ('A', 'M', 'B') OR @Accion IS NULL
        SET @ErroresAcumulados += N'- La acción es obligatoria y debe ser A (Alta), M (Modificación) o B (Baja).' + CHAR(13);

    -- 2. Validación de Clave Primaria
    IF @id_pieza IS NULL
        SET @ErroresAcumulados += N'- El id_pieza es obligatorio.' + CHAR(13);

    -- 3. Existencia / Duplicidad de PK
    IF @id_pieza IS NOT NULL
    BEGIN
        IF @Accion = 'A' AND EXISTS (SELECT 1 FROM comercial.PIEZA_PUBLICITARIA WHERE id_pieza = @id_pieza)
            SET @ErroresAcumulados += N'- La pieza publicitaria ya existe en la base de datos (PK duplicada).' + CHAR(13);

        IF @Accion IN ('M', 'B') AND NOT EXISTS (SELECT 1 FROM comercial.PIEZA_PUBLICITARIA WHERE id_pieza = @id_pieza)
            SET @ErroresAcumulados += N'- La pieza publicitaria indicada no existe en la base de datos.' + CHAR(13);
    END;

    -- 4. Validaciones de dominio e integridad para Alta y Modificación
    IF @Accion IN ('A', 'M')
    BEGIN
        IF @id_campania IS NULL
            SET @ErroresAcumulados += N'- El id_campania es obligatorio.' + CHAR(13);
        ELSE IF NOT EXISTS (SELECT 1 FROM comercial.CAMPANIA_PUBLICITARIA WHERE id_campania = @id_campania)
            SET @ErroresAcumulados += N'- El id_campania especificado no existe en la tabla CAMPANIA_PUBLICITARIA.' + CHAR(13);

        IF @duracion_segundos IS NULL OR @duracion_segundos <= 0
            SET @ErroresAcumulados += N'- La duración en segundos debe ser mayor a 0.' + CHAR(13);

        IF @url_contenido IS NULL OR TRIM(@url_contenido) = N''
            SET @ErroresAcumulados += N'- La url del contenido es obligatoria y no puede quedar vacía.' + CHAR(13);

        IF @idioma IS NULL OR TRIM(@idioma) = N''
            SET @ErroresAcumulados += N'- El idioma es obligatorio y no puede quedar vacío.' + CHAR(13);
    END;

    -- 5. Restricción de Baja ('B'): No eliminar si posee exhibiciones
    IF @Accion = 'B' AND @id_pieza IS NOT NULL
    BEGIN
        IF EXISTS (SELECT 1 FROM comercial.EXHIBICION_PUBLICITARIA WHERE id_pieza = @id_pieza)
            SET @ErroresAcumulados += N'- No se puede eliminar la pieza publicitaria porque posee exhibiciones registradas.' + CHAR(13);
    END;

    -- Consolidación de errores
    IF LEN(@ErroresAcumulados) > 0
    BEGIN
        SET @ErroresAcumulados = N'Se encontraron los siguientes errores en comercial.sp_PIEZA_PUBLICITARIA_ABM:' 
                                 + CHAR(13) + @ErroresAcumulados;
        THROW 50000, @ErroresAcumulados, 1;
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @Accion = 'A'
        BEGIN
            INSERT INTO comercial.PIEZA_PUBLICITARIA (id_pieza, id_campania, duracion_segundos, url_contenido, idioma)
            VALUES (@id_pieza, @id_campania, @duracion_segundos, UPPER(TRIM(@url_contenido)), UPPER(TRIM(@idioma)));
        END
        ELSE IF @Accion = 'M'
        BEGIN
            UPDATE comercial.PIEZA_PUBLICITARIA
            SET id_campania       = @id_campania,
                duracion_segundos = @duracion_segundos,
                url_contenido     = UPPER(TRIM(@url_contenido)),
                idioma            = UPPER(TRIM(@idioma))
            WHERE id_pieza = @id_pieza;
        END
        ELSE IF @Accion = 'B'
        BEGIN
            DELETE FROM comercial.PIEZA_PUBLICITARIA 
            WHERE id_pieza = @id_pieza;
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrMsgPieza NVARCHAR(4000) = ERROR_MESSAGE();
        THROW 50001, @ErrMsgPieza, 1;
    END CATCH;
END;
GO

-- ============================================================================
-- 4. comercial.sp_EXHIBICION_PUBLICITARIA_ABM
-- Tabla: comercial.EXHIBICION_PUBLICITARIA
-- PK: id_exhibicion INT
-- ============================================================================
CREATE OR ALTER PROCEDURE comercial.sp_EXHIBICION_PUBLICITARIA_ABM
    @Accion              CHAR(1),
    @id_exhibicion       INT             = NULL,
    @id_partido          INT             = NULL,
    @id_anunciante       INT             = NULL,
    @id_campania         INT             = NULL,
    @id_pieza            INT             = NULL,
    @letrero_posicion    INT             = NULL,
    @minuto_inicio       INT             = NULL,
    @minuto_fin          INT             = NULL,
    @costo_calculado_usd DECIMAL(18,2)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ErroresAcumulados NVARCHAR(MAX) = N'';

    -- 1. Validación de Acción
    IF @Accion NOT IN ('A', 'M', 'B') OR @Accion IS NULL
        SET @ErroresAcumulados += N'- La acción es obligatoria y debe ser A (Alta), M (Modificación) o B (Baja).' + CHAR(13);

    -- 2. Validación de Clave Primaria
    IF @id_exhibicion IS NULL
        SET @ErroresAcumulados += N'- El id_exhibicion es obligatorio.' + CHAR(13);

    -- 3. Existencia / Duplicidad de PK
    IF @id_exhibicion IS NOT NULL
    BEGIN
        IF @Accion = 'A' AND EXISTS (SELECT 1 FROM comercial.EXHIBICION_PUBLICITARIA WHERE id_exhibicion = @id_exhibicion)
            SET @ErroresAcumulados += N'- La exhibición publicitaria ya existe en la base de datos (PK duplicada).' + CHAR(13);

        IF @Accion IN ('M', 'B') AND NOT EXISTS (SELECT 1 FROM comercial.EXHIBICION_PUBLICITARIA WHERE id_exhibicion = @id_exhibicion)
            SET @ErroresAcumulados += N'- La exhibición publicitaria indicada no existe en la base de datos.' + CHAR(13);
    END;

    -- 4. Validaciones de dominio e integridad para Alta y Modificación
    IF @Accion IN ('A', 'M')
    BEGIN
        -- Partido en PARTIDO
        IF @id_partido IS NULL
            SET @ErroresAcumulados += N'- El id_partido es obligatorio.' + CHAR(13);
        ELSE IF NOT EXISTS (SELECT 1 FROM torneo.PARTIDO WHERE id_partido = @id_partido)
            SET @ErroresAcumulados += N'- El id_partido especificado no existe en la tabla PARTIDO.' + CHAR(13);

        -- Anunciante en ANUNCIANTE
        IF @id_anunciante IS NULL
            SET @ErroresAcumulados += N'- El id_anunciante es obligatorio.' + CHAR(13);
        ELSE IF NOT EXISTS (SELECT 1 FROM comercial.ANUNCIANTE WHERE id_anunciante = @id_anunciante)
            SET @ErroresAcumulados += N'- El id_anunciante especificado no existe en la tabla ANUNCIANTE.' + CHAR(13);

        -- Campaña en CAMPANIA_PUBLICITARIA
        IF @id_campania IS NULL
            SET @ErroresAcumulados += N'- El id_campania es obligatorio.' + CHAR(13);
        ELSE IF NOT EXISTS (SELECT 1 FROM comercial.CAMPANIA_PUBLICITARIA WHERE id_campania = @id_campania)
            SET @ErroresAcumulados += N'- El id_campania especificado no existe en la tabla CAMPANIA_PUBLICITARIA.' + CHAR(13);

        -- Pieza en PIEZA_PUBLICITARIA
        IF @id_pieza IS NULL
            SET @ErroresAcumulados += N'- El id_pieza es obligatorio.' + CHAR(13);
        ELSE IF NOT EXISTS (SELECT 1 FROM comercial.PIEZA_PUBLICITARIA WHERE id_pieza = @id_pieza)
            SET @ErroresAcumulados += N'- El id_pieza especificado no existe en la tabla PIEZA_PUBLICITARIA.' + CHAR(13);

        -- Posición de letrero BETWEEN 1 AND 4
        IF @letrero_posicion IS NULL OR @letrero_posicion < 1 OR @letrero_posicion > 4
            SET @ErroresAcumulados += N'- El letrero_posicion debe estar comprendido entre 1 y 4.' + CHAR(13);

        -- Minutos de exhibición
        IF @minuto_inicio IS NULL OR @minuto_inicio < 0
            SET @ErroresAcumulados += N'- El minuto_inicio debe ser mayor o igual a 0.' + CHAR(13);

        IF @minuto_fin IS NULL OR @minuto_fin <= @minuto_inicio
            SET @ErroresAcumulados += N'- El minuto_fin debe ser estrictamente mayor al minuto_inicio.' + CHAR(13);

        -- Costo calculado USD >= 0
        IF @costo_calculado_usd IS NULL OR @costo_calculado_usd < 0
            SET @ErroresAcumulados += N'- El costo calculado en USD debe ser mayor o igual a 0.' + CHAR(13);
    END;

    -- Consolidación de errores
    IF LEN(@ErroresAcumulados) > 0
    BEGIN
        SET @ErroresAcumulados = N'Se encontraron los siguientes errores en comercial.sp_EXHIBICION_PUBLICITARIA_ABM:' 
                                 + CHAR(13) + @ErroresAcumulados;
        THROW 50000, @ErroresAcumulados, 1;
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @Accion = 'A'
        BEGIN
            INSERT INTO comercial.EXHIBICION_PUBLICITARIA (
                id_exhibicion, id_partido, id_anunciante, id_campania, id_pieza, 
                letrero_posicion, minuto_inicio, minuto_fin, costo_calculado_usd
            )
            VALUES (
                @id_exhibicion, @id_partido, @id_anunciante, @id_campania, @id_pieza, 
                @letrero_posicion, @minuto_inicio, @minuto_fin, @costo_calculado_usd
            );
        END
        ELSE IF @Accion = 'M'
        BEGIN
            UPDATE comercial.EXHIBICION_PUBLICITARIA
            SET id_partido          = @id_partido,
                id_anunciante       = @id_anunciante,
                id_campania         = @id_campania,
                id_pieza            = @id_pieza,
                letrero_posicion    = @letrero_posicion,
                minuto_inicio       = @minuto_inicio,
                minuto_fin          = @minuto_fin,
                costo_calculado_usd = @costo_calculado_usd
            WHERE id_exhibicion = @id_exhibicion;
        END
        ELSE IF @Accion = 'B'
        BEGIN
            DELETE FROM comercial.EXHIBICION_PUBLICITARIA 
            WHERE id_exhibicion = @id_exhibicion;
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrMsgExhibicion NVARCHAR(4000) = ERROR_MESSAGE();
        THROW 50001, @ErrMsgExhibicion, 1;
    END CATCH;
END;
GO