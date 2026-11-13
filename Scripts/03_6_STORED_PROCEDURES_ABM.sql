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
-- 1. torneo.sp_RECALCULAR_SUSPENSION_JUGADOR
-- Recorre en orden los partidos de la seleccion del jugador
-- deja en CONTROL_SUSPENSION las amarillas acumuladas, los partidos de suspension u si se cumplio
-- ============================================================================


CREATE OR ALTER PROCEDURE torneo.sp_RECALCULAR_SUSPENSION_JUGADOR
    @id_seleccion             INT,
    @dorsal_oficial           INT,
    @AmarillasParaSuspension  INT         = 2,      -- amarillas en partidos distintos que generan suspension
    @PartidosPorAcumulacion   INT         = 1,      -- fechas por acumulación
    @PartidosPorRojaDirecta   INT         = 1,      -- fechas por roja directa (minimo automatico)
    @PartidosPorDobleAmarilla INT         = 1,      -- fechas por expulsion con doble amarilla
    @FasesLimpiezaAmarillas   VARCHAR(50) = '1,4'   -- al terminar estas fases se borran las amarillas
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Partidos TABLE (n INT PRIMARY KEY, id_fase INT, nro_partido_fase INT);
    DECLARE @FasesLimpieza TABLE (id_fase INT PRIMARY KEY);
    DECLARE @n INT = 1, @Total INT = 0, @IdFase INT, @NroPartido INT;
    DECLARE @Amarillas INT = 0, @Pendientes INT = 0, @TuvoSuspension BIT = 0, @UltimaFase INT = 0;
    DECLARE @AmarillasPartido INT, @DobleAmarilla INT, @RojaDirecta INT;
    DECLARE @Accion CHAR(1), @Cumplida BIT;

    INSERT INTO @FasesLimpieza (id_fase)
    SELECT DISTINCT TRY_CAST(TRIM(value) AS INT)
    FROM STRING_SPLIT(ISNULL(@FasesLimpiezaAmarillas, ''), ',')
    WHERE TRIM(value) <> '' AND TRY_CAST(TRIM(value) AS INT) IS NOT NULL;

    -- Partidos de la selección ya jugados (o con tarjetas del jugador) en orden
    INSERT INTO @Partidos (n, id_fase, nro_partido_fase)
    SELECT ROW_NUMBER() OVER (ORDER BY P.fecha_hora_utc, P.id_fase, P.nro_partido_fase),
           P.id_fase, P.nro_partido_fase
    FROM torneo.PARTIDO P
    WHERE (P.id_seleccion_local = @id_seleccion OR P.id_seleccion_visitante = @id_seleccion)
      AND (P.fecha_hora_utc <= SYSDATETIME()
           OR EXISTS (SELECT 1 FROM torneo.SANCION_TARJETA T
                      WHERE T.id_fase = P.id_fase AND T.nro_partido_fase = P.nro_partido_fase
                        AND T.id_seleccion = @id_seleccion AND T.dorsal_sancionado = @dorsal_oficial));

    SELECT @Total = COUNT(*) FROM @Partidos;

    WHILE @n <= @Total
    BEGIN
        SELECT @IdFase = id_fase, @NroPartido = nro_partido_fase
        FROM @Partidos
        WHERE n = @n;

        -- a) si entre el partido anterior y este terminó una fase de limpieza, se borran las amarillas
        IF EXISTS (SELECT 1 FROM @FasesLimpieza WHERE id_fase >= @UltimaFase AND id_fase < @IdFase)
            SET @Amarillas = 0;

        -- b) si tenía suspensión pendiente, la cumple con este partido
        IF @Pendientes > 0
        BEGIN
            IF EXISTS (SELECT 1 FROM torneo.JUGADOR_ALINEACION
                       WHERE id_fase = @IdFase AND nro_partido_fase = @NroPartido
                         AND id_seleccion = @id_seleccion AND dorsal_oficial = @dorsal_oficial)
                PRINT CONCAT('ADVERTENCIA: el jugador #', @dorsal_oficial, ' (selección ', @id_seleccion,
                             ') tenía que cumplir suspensión en el partido ', @IdFase, '-', @NroPartido,
                             ' y figura en la planilla.');

            SET @Pendientes -= 1;
        END;

        -- c) tarjetas del jugador en este partido
        SELECT @AmarillasPartido = ISNULL(SUM(CASE WHEN tipo_tarjeta = 'AMARILLA' THEN 1 ELSE 0 END), 0),
               @DobleAmarilla    = ISNULL(MAX(CASE WHEN tipo_tarjeta = 'DOBLE_AMARILLA' THEN 1 ELSE 0 END), 0),
               @RojaDirecta      = ISNULL(MAX(CASE WHEN tipo_tarjeta = 'ROJA_DIRECTA' THEN 1 ELSE 0 END), 0)
        FROM torneo.SANCION_TARJETA
        WHERE id_fase = @IdFase AND nro_partido_fase = @NroPartido
          AND id_seleccion = @id_seleccion AND dorsal_sancionado = @dorsal_oficial;

        IF @DobleAmarilla = 1
        BEGIN
            -- las dos amarillas de la expulsión no suman para la acumulación
            SET @Pendientes += @PartidosPorDobleAmarilla;
            IF @PartidosPorDobleAmarilla > 0 SET @TuvoSuspension = 1;
        END
        ELSE IF @AmarillasPartido > 0
            SET @Amarillas += 1;   -- una amarilla antes de una roja directa sí suma

        IF @RojaDirecta = 1
        BEGIN
            SET @Pendientes += @PartidosPorRojaDirecta;
            IF @PartidosPorRojaDirecta > 0 SET @TuvoSuspension = 1;
        END;

        -- d) acumulación
        IF @Amarillas >= @AmarillasParaSuspension
        BEGIN
            SET @Pendientes += @PartidosPorAcumulacion;
            SET @Amarillas  -= @AmarillasParaSuspension;
            IF @PartidosPorAcumulacion > 0 SET @TuvoSuspension = 1;
        END;

        SET @UltimaFase = @IdFase;
        SET @n += 1;
    END;

    SET @Cumplida = CASE WHEN @Pendientes = 0 AND @TuvoSuspension = 1 THEN 1 ELSE 0 END;
    SET @Accion = CASE WHEN EXISTS (SELECT 1 FROM torneo.CONTROL_SUSPENSION
                                    WHERE id_seleccion = @id_seleccion AND dorsal_oficial = @dorsal_oficial)
                       THEN 'M' ELSE 'A' END;

    EXEC torneo.sp_CONTROL_SUSPENSION_ABM
         @Accion               = @Accion,
         @id_seleccion         = @id_seleccion,
         @dorsal_oficial       = @dorsal_oficial,
         @amarillas_acumuladas = @Amarillas,
         @partidos_suspension  = @Pendientes,
         @cumplida             = @Cumplida;

    IF @Pendientes > 0
        PRINT CONCAT('Jugador #', @dorsal_oficial, ' (selección ', @id_seleccion, '): ',
                     @Pendientes, ' partido(s) de suspensión pendiente(s).');
END;
GO

-- ============================================================================
-- 2. torneo.sp_SANCION_TARJETA_ABM
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
    @motivo                VARCHAR(100) = NULL,
    -- Criterios de suspensión
    @AmarillasParaSuspension  INT          = 2,
    @PartidosPorAcumulacion   INT          = 1,
    @PartidosPorRojaDirecta   INT          = 1,
    @PartidosPorDobleAmarilla INT          = 1,
    @FasesLimpiezaAmarillas   VARCHAR(50)  = '1,4'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ErroresAcumulados NVARCHAR(MAX) = N'';
    DECLARE @SaltoLinea NVARCHAR(2) = CHAR(13) + CHAR(10);
    DECLARE @OrdenTarjeta INT = @minuto_sancion * 100 + ISNULL(@minuto_sancion_extra, 0);   -- 45+2 -> 4502
    DECLARE @Afectados TABLE (n INT IDENTITY(1,1) PRIMARY KEY, id_seleccion INT, dorsal_oficial INT);
    DECLARE @i INT = 1, @SelAfectada INT, @DorsalAfectado INT;

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

        -- 5. las otras tarjetas del jugador en el partido
    IF @Accion IN ('A', 'M') AND @id_seleccion IS NOT NULL AND @dorsal_sancionado IS NOT NULL AND @minuto_sancion IS NOT NULL
    BEGIN
        IF EXISTS (
            SELECT 1
            FROM torneo.SANCION_TARJETA
            WHERE id_fase = @id_fase AND nro_partido_fase = @nro_partido_fase
              AND id_tarjeta <> ISNULL(@id_tarjeta, -1)
              AND id_seleccion = @id_seleccion AND dorsal_sancionado = @dorsal_sancionado
              AND tipo_tarjeta IN ('ROJA_DIRECTA', 'DOBLE_AMARILLA')
              AND minuto_sancion * 100 + ISNULL(minuto_sancion_extra, 0) < @OrdenTarjeta
        )
            SET @ErroresAcumulados += N'- El jugador ya había sido expulsado en este partido antes de ese minuto.' + @SaltoLinea;

        IF UPPER(TRIM(ISNULL(@tipo_tarjeta, ''))) = 'AMARILLA' AND EXISTS (
            SELECT 1
            FROM torneo.SANCION_TARJETA
            WHERE id_fase = @id_fase AND nro_partido_fase = @nro_partido_fase
              AND id_tarjeta <> ISNULL(@id_tarjeta, -1)
              AND id_seleccion = @id_seleccion AND dorsal_sancionado = @dorsal_sancionado
              AND tipo_tarjeta = 'AMARILLA'
        )
            SET @ErroresAcumulados += N'- El jugador ya tiene una amarilla en este partido: la segunda se registra como DOBLE_AMARILLA.' + @SaltoLinea;

        IF UPPER(TRIM(ISNULL(@tipo_tarjeta, ''))) IN ('ROJA_DIRECTA', 'DOBLE_AMARILLA') AND EXISTS (
            SELECT 1
            FROM torneo.SANCION_TARJETA
            WHERE id_fase = @id_fase AND nro_partido_fase = @nro_partido_fase
              AND id_tarjeta <> ISNULL(@id_tarjeta, -1)
              AND id_seleccion = @id_seleccion AND dorsal_sancionado = @dorsal_sancionado
              AND tipo_tarjeta IN ('ROJA_DIRECTA', 'DOBLE_AMARILLA')
        )
            SET @ErroresAcumulados += N'- El jugador ya tiene una expulsión registrada en este partido.' + @SaltoLinea;

        IF UPPER(TRIM(ISNULL(@tipo_tarjeta, ''))) = 'DOBLE_AMARILLA' AND NOT EXISTS (
            SELECT 1
            FROM torneo.SANCION_TARJETA
            WHERE id_fase = @id_fase AND nro_partido_fase = @nro_partido_fase
              AND id_tarjeta <> ISNULL(@id_tarjeta, -1)
              AND id_seleccion = @id_seleccion AND dorsal_sancionado = @dorsal_sancionado
              AND tipo_tarjeta = 'AMARILLA'
              AND minuto_sancion * 100 + ISNULL(minuto_sancion_extra, 0) <= @OrdenTarjeta
        )
            SET @ErroresAcumulados += N'- Para una expulsión por doble amarilla el jugador tiene que tener antes una amarilla en el mismo partido.' + @SaltoLinea;
    END;

    -- 6. Criterios de suspension
    IF @AmarillasParaSuspension IS NULL OR @AmarillasParaSuspension < 1
        SET @ErroresAcumulados += N'- La cantidad de amarillas para suspensión debe ser mayor a 0.' + @SaltoLinea;

    IF @PartidosPorAcumulacion IS NULL OR @PartidosPorAcumulacion < 0
       OR @PartidosPorRojaDirecta IS NULL OR @PartidosPorRojaDirecta < 0
       OR @PartidosPorDobleAmarilla IS NULL OR @PartidosPorDobleAmarilla < 0
        SET @ErroresAcumulados += N'- Los partidos de suspensión no pueden ser nulos ni negativos.' + @SaltoLinea;

    IF EXISTS (SELECT 1 FROM STRING_SPLIT(ISNULL(@FasesLimpiezaAmarillas, ''), ',')
               WHERE TRIM(value) <> ''
                 AND (TRY_CAST(TRIM(value) AS INT) IS NULL
                      OR NOT EXISTS (SELECT 1 FROM torneo.FASE_TORNEO F WHERE F.id_fase = TRY_CAST(TRIM(value) AS INT))))
        SET @ErroresAcumulados += N'- @FasesLimpiezaAmarillas debe ser una lista de fases existentes separadas por coma (ej: ''1,4'').' + @SaltoLinea;

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

        -- jugador que tenía la tarjeta antes del cambio (también hay que recalcularlo si cambia el sancionado)
        IF @Accion IN ('M', 'B')
            INSERT INTO @Afectados (id_seleccion, dorsal_oficial)
            SELECT id_seleccion, dorsal_sancionado
            FROM torneo.SANCION_TARJETA
            WHERE id_fase = @id_fase AND nro_partido_fase = @nro_partido_fase AND id_tarjeta = @id_tarjeta;

        IF @Accion IN ('A', 'M') AND NOT EXISTS (SELECT 1 FROM @Afectados
                                                 WHERE id_seleccion = @id_seleccion AND dorsal_oficial = @dorsal_sancionado)
            INSERT INTO @Afectados (id_seleccion, dorsal_oficial)
            VALUES (@id_seleccion, @dorsal_sancionado);

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

        -- Recalculo de la suspensión de los jugadores afectados
        WHILE @i <= (SELECT COUNT(*) FROM @Afectados)
        BEGIN
            SELECT @SelAfectada = id_seleccion, @DorsalAfectado = dorsal_oficial
            FROM @Afectados
            WHERE n = @i;

            EXEC torneo.sp_RECALCULAR_SUSPENSION_JUGADOR
                 @id_seleccion             = @SelAfectada,
                 @dorsal_oficial           = @DorsalAfectado,
                 @AmarillasParaSuspension  = @AmarillasParaSuspension,
                 @PartidosPorAcumulacion   = @PartidosPorAcumulacion,
                 @PartidosPorRojaDirecta   = @PartidosPorRojaDirecta,
                 @PartidosPorDobleAmarilla = @PartidosPorDobleAmarilla,
                 @FasesLimpiezaAmarillas   = @FasesLimpiezaAmarillas;

            SET @i += 1;
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
-- 3. torneo.sp_CONTROL_SUSPENSION_ABM
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
