/*
---------------------------------------------------------
UNLaM - Universidad Nacional de La Matanza
Departamento de Ingeniería e Investigaciones Tecnológicas
Materia: Base de Datos Aplicada (Comisión 5600)
Entrega 5 - Base de Datos T-SQL
Fecha: 15/10/2026 - 2C
Grupo 10

Integrantes:
- Monasterio Erik: MonasteryEr
- Arena Ariel Ignacio: arielarena
- Castillo Gabriela Florencia: ItsFlorencia
- Maita Pitado Jose Gregorio: maita07

Descripcion: Script T-SQL de creación de Stored Procedures de ABM 
             para el Módulo 6: Disciplinario y Control.
             Procedimientos incluidos:
             - torneo.sp_SANCION_TARJETA_ABM
             - torneo.sp_CONTROL_SUSPENSION_ABM
---------------------------------------------------------
*/

USE DB_Mundial2026_Grupo10;
GO

-- ============================================================================
-- 1. torneo.sp_SANCION_TARJETA_ABM
-- Tabla: torneo.SANCION_TARJETA
-- PK Compuesta: (id_fase, nro_partido_fase, id_tarjeta)
-- ============================================================================
CREATE OR ALTER PROCEDURE torneo.sp_SANCION_TARJETA_ABM
    @Accion                CHAR(1),
    @id_fase               INT          = NULL,
    @nro_partido_fase      INT          = NULL,
    @id_tarjeta            INT          = NULL,
    @id_seleccion          INT          = NULL,
    @dorsal_sancionado     INT          = NULL,
    @minuto_sancion        INT          = NULL,
    @minuto_sancion_extra  INT          = NULL,
    @tipo_tarjeta          VARCHAR(20)  = NULL,
    @motivo                VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ErroresAcumulados NVARCHAR(MAX) = N'';
    DECLARE @SaltoLinea NVARCHAR(2) = CHAR(13) + CHAR(10);

    -- 1. Validación de Acción
    IF @Accion NOT IN ('A', 'M', 'B') OR @Accion IS NULL
        SET @ErroresAcumulados += N'- La acción es obligatoria y debe ser A (Alta), M (Modificación) o B (Baja).' + @SaltoLinea;

    -- 2. Validación de PK Compuesta en todas las operaciones
    IF @id_fase IS NULL
        SET @ErroresAcumulados += N'- El id_fase es obligatorio.' + @SaltoLinea;

    IF @nro_partido_fase IS NULL
        SET @ErroresAcumulados += N'- El nro_partido_fase es obligatorio.' + @SaltoLinea;

    IF @id_tarjeta IS NULL
        SET @ErroresAcumulados += N'- El id_tarjeta es obligatorio.' + @SaltoLinea;

    -- 3. Existencia / Duplicidad de PK
    IF @id_fase IS NOT NULL AND @nro_partido_fase IS NOT NULL AND @id_tarjeta IS NOT NULL
    BEGIN
        IF @Accion = 'A' AND EXISTS (
            SELECT 1 
            FROM torneo.SANCION_TARJETA 
            WHERE id_fase = @id_fase 
              AND nro_partido_fase = @nro_partido_fase 
              AND id_tarjeta = @id_tarjeta
        )
            SET @ErroresAcumulados += N'- La sanción con tarjeta ya existe en la base de datos (PK duplicada).' + @SaltoLinea;

        IF @Accion IN ('M', 'B') AND NOT EXISTS (
            SELECT 1 
            FROM torneo.SANCION_TARJETA 
            WHERE id_fase = @id_fase 
              AND nro_partido_fase = @nro_partido_fase 
              AND id_tarjeta = @id_tarjeta
        )
            SET @ErroresAcumulados += N'- La sanción con tarjeta indicada no existe en la base de datos.' + @SaltoLinea;
    END;

    -- 4. Validaciones de integridad y dominio para Alta y Modificación
    IF @Accion IN ('A', 'M')
    BEGIN
        -- Partido en PARTIDO
        IF @id_fase IS NOT NULL AND @nro_partido_fase IS NOT NULL
        BEGIN
            IF NOT EXISTS (
                SELECT 1 
                FROM torneo.PARTIDO 
                WHERE id_fase = @id_fase 
                  AND nro_partido_fase = @nro_partido_fase
            )
                SET @ErroresAcumulados += N'- El partido especificado (id_fase, nro_partido_fase) no existe en la tabla PARTIDO.' + @SaltoLinea;
        END;

        -- Sancionado en CONVOCATORIA
        IF @id_seleccion IS NULL OR @dorsal_sancionado IS NULL
            SET @ErroresAcumulados += N'- Los datos del sancionado (id_seleccion y dorsal_sancionado) son obligatorios.' + @SaltoLinea;
        ELSE IF NOT EXISTS (
            SELECT 1 
            FROM torneo.CONVOCATORIA 
            WHERE id_seleccion = @id_seleccion 
              AND dorsal_oficial = @dorsal_sancionado
        )
            SET @ErroresAcumulados += N'- El jugador sancionado no se encuentra registrado en CONVOCATORIA.' + @SaltoLinea;

        -- minuto_sancion BETWEEN 1 AND 120
        IF @minuto_sancion IS NULL OR @minuto_sancion < 1 OR @minuto_sancion > 120
            SET @ErroresAcumulados += N'- El minuto_sancion debe estar comprendido entre 1 y 120.' + @SaltoLinea;

        -- minuto_sancion_extra > 0 (si se informa)
        IF @minuto_sancion_extra IS NOT NULL AND @minuto_sancion_extra <= 0
            SET @ErroresAcumulados += N'- El minuto_sancion_extra, en caso de informarse, debe ser mayor a 0.' + @SaltoLinea;

        -- tipo_tarjeta IN ('AMARILLA', 'ROJA_DIRECTA', 'DOBLE_AMARILLA')
        IF @tipo_tarjeta IS NULL OR UPPER(TRIM(@tipo_tarjeta)) NOT IN ('AMARILLA', 'ROJA_DIRECTA', 'DOBLE_AMARILLA')
            SET @ErroresAcumulados += N'- El tipo_tarjeta debe ser AMARILLA, ROJA_DIRECTA o DOBLE_AMARILLA.' + @SaltoLinea;

        -- motivo no nulo ni vacío
        IF @motivo IS NULL OR TRIM(@motivo) = ''
            SET @ErroresAcumulados += N'- El motivo de la sanción es obligatorio y no puede quedar vacío.' + @SaltoLinea;
    END;

    -- Consolidación de errores
    IF LEN(@ErroresAcumulados) > 0
    BEGIN
        SET @ErroresAcumulados = N'Se encontraron los siguientes errores en torneo.sp_SANCION_TARJETA_ABM (Acción: ' + ISNULL(@Accion, 'NULL') + N'):' 
                                 + @SaltoLinea + @ErroresAcumulados;
        THROW 50000, @ErroresAcumulados, 1;
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @Accion = 'A'
        BEGIN
            INSERT INTO torneo.SANCION_TARJETA (
                id_fase, nro_partido_fase, id_tarjeta, 
                minuto_sancion, minuto_sancion_extra, tipo_tarjeta, motivo,
                id_seleccion, dorsal_sancionado
            )
            VALUES (
                @id_fase, @nro_partido_fase, @id_tarjeta,
                @minuto_sancion, @minuto_sancion_extra, UPPER(TRIM(@tipo_tarjeta)), TRIM(@motivo),
                @id_seleccion, @dorsal_sancionado
            );
        END
        ELSE IF @Accion = 'M'
        BEGIN
            UPDATE torneo.SANCION_TARJETA
            SET minuto_sancion       = @minuto_sancion,
                minuto_sancion_extra = @minuto_sancion_extra,
                tipo_tarjeta         = UPPER(TRIM(@tipo_tarjeta)),
                motivo               = TRIM(@motivo),
                id_seleccion         = @id_seleccion,
                dorsal_sancionado    = @dorsal_sancionado
            WHERE id_fase = @id_fase 
              AND nro_partido_fase = @nro_partido_fase 
              AND id_tarjeta = @id_tarjeta;
        END
        ELSE IF @Accion = 'B'
        BEGIN
            DELETE FROM torneo.SANCION_TARJETA
            WHERE id_fase = @id_fase 
              AND nro_partido_fase = @nro_partido_fase 
              AND id_tarjeta = @id_tarjeta;
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrMsgTarjetas NVARCHAR(4000) = ERROR_MESSAGE();
        THROW 50001, @ErrMsgTarjetas, 1;
    END CATCH;
END;
GO

-- ============================================================================
-- 2. torneo.sp_CONTROL_SUSPENSION_ABM
-- Tabla: torneo.CONTROL_SUSPENSION
-- PK Compuesta: (id_seleccion, dorsal_oficial)
-- ============================================================================
CREATE OR ALTER PROCEDURE torneo.sp_CONTROL_SUSPENSION_ABM
    @Accion               CHAR(1),
    @id_seleccion         INT     = NULL,
    @dorsal_oficial       INT     = NULL,
    @amarillas_acumuladas INT     = NULL,
    @partidos_suspension  INT     = NULL,
    @cumplida             BIT     = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ErroresAcumulados NVARCHAR(MAX) = N'';
    DECLARE @SaltoLinea NVARCHAR(2) = CHAR(13) + CHAR(10);

    -- 1. Validación de Acción
    IF @Accion NOT IN ('A', 'M', 'B') OR @Accion IS NULL
        SET @ErroresAcumulados += N'- La acción es obligatoria y debe ser A (Alta), M (Modificación) o B (Baja).' + @SaltoLinea;

    -- 2. Validación de PK Compuesta
    IF @id_seleccion IS NULL
        SET @ErroresAcumulados += N'- El id_seleccion es obligatorio.' + @SaltoLinea;

    IF @dorsal_oficial IS NULL
        SET @ErroresAcumulados += N'- El dorsal_oficial es obligatorio.' + @SaltoLinea;

    -- 3. Existencia de Convocado y Existencia/Duplicidad de PK
    IF @id_seleccion IS NOT NULL AND @dorsal_oficial IS NOT NULL
    BEGIN
        IF @Accion IN ('A', 'M') AND NOT EXISTS (
            SELECT 1 
            FROM torneo.CONVOCATORIA 
            WHERE id_seleccion = @id_seleccion 
              AND dorsal_oficial = @dorsal_oficial
        )
            SET @ErroresAcumulados += N'- El jugador convocado no existe en la nómina de CONVOCATORIA.' + @SaltoLinea;

        IF @Accion = 'A' AND EXISTS (
            SELECT 1 
            FROM torneo.CONTROL_SUSPENSION 
            WHERE id_seleccion = @id_seleccion 
              AND dorsal_oficial = @dorsal_oficial
        )
            SET @ErroresAcumulados += N'- El registro de control de suspensión ya existe (PK duplicada).' + @SaltoLinea;

        IF @Accion IN ('M', 'B') AND NOT EXISTS (
            SELECT 1 
            FROM torneo.CONTROL_SUSPENSION 
            WHERE id_seleccion = @id_seleccion 
              AND dorsal_oficial = @dorsal_oficial
        )
            SET @ErroresAcumulados += N'- El registro de control de suspensión no existe en la base de datos.' + @SaltoLinea;
    END;

    -- 4. Validaciones de dominio para Alta y Modificación
    IF @Accion IN ('A', 'M')
    BEGIN
        IF @amarillas_acumuladas IS NULL OR @amarillas_acumuladas < 0
            SET @ErroresAcumulados += N'- Las amarillas_acumuladas deben ser mayores o iguales a 0.' + @SaltoLinea;

        IF @partidos_suspension IS NULL OR @partidos_suspension < 0
            SET @ErroresAcumulados += N'- Los partidos_suspension deben ser mayores o iguales a 0.' + @SaltoLinea;

        IF @cumplida IS NULL
            SET @ErroresAcumulados += N'- El campo cumplida es obligatorio y debe ser 0 o 1.' + @SaltoLinea;
    END;

    -- Consolidación de errores
    IF LEN(@ErroresAcumulados) > 0
    BEGIN
        SET @ErroresAcumulados = N'Se encontraron los siguientes errores en torneo.sp_CONTROL_SUSPENSION_ABM (Acción: ' + ISNULL(@Accion, 'NULL') + N'):' 
                                 + @SaltoLinea + @ErroresAcumulados;
        THROW 50000, @ErroresAcumulados, 1;
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @Accion = 'A'
        BEGIN
            INSERT INTO torneo.CONTROL_SUSPENSION (
                id_seleccion, dorsal_oficial, amarillas_acumuladas, partidos_suspension, cumplida
            )
            VALUES (
                @id_seleccion, @dorsal_oficial, @amarillas_acumuladas, @partidos_suspension, @cumplida
            );
        END
        ELSE IF @Accion = 'M'
        BEGIN
            UPDATE torneo.CONTROL_SUSPENSION
            SET amarillas_acumuladas = @amarillas_acumuladas,
                partidos_suspension  = @partidos_suspension,
                cumplida             = @cumplida
            WHERE id_seleccion = @id_seleccion 
              AND dorsal_oficial = @dorsal_oficial;
        END
        ELSE IF @Accion = 'B'
        BEGIN
            DELETE FROM torneo.CONTROL_SUSPENSION
            WHERE id_seleccion = @id_seleccion 
              AND dorsal_oficial = @dorsal_oficial;
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrMsgSuspension NVARCHAR(4000) = ERROR_MESSAGE();
        THROW 50001, @ErrMsgSuspension, 1;
    END CATCH;
END;
GO