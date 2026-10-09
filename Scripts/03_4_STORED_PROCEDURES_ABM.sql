/*
---------------------------------------------------------
UNLaM - Universidad Nacional de La Matanza
Departamento de Ingeniería e Investigaciones Tecnológicas
Materia: Base de Datos Aplicada (Comisión 5600)
Entrega 5 - Base de Datos T-SQL
2026 - 2C
Grupo 10

Integrantes:
-Monasterio Erik: MonasteryEr
-Arena Ariel Ignacio: arielarena
-Castillo Gabriela Florencia: ItsFlorencia
-Maita Pitado Jose Gregorio: maita07

Descripcion: Script T-SQL de creación e implementación de los Stored Procedures 
             de Alta, Baja y Modificación (ABM) para la base de datos 
             DB_Mundial2026_Grupo10 - Módulo 4 - Convocatorias             
             Características principales:
             - Encapsulamiento total de operaciones DML (INSERT, UPDATE, DELETE).
             - Validaciones de formato, dominio e integridad referencial.
             - Estrategia de acumulación de observaciones con mensaje consolidado (THROW 50000).
             - Control transaccional completo (BEGIN TRANSACTION / COMMIT / ROLLBACK) 
               y manejo de excepciones con TRY...CATCH.
             - Gestión de la jerarquía de tablas PERSONA (JUGADOR, CUERPO_TECNICO, ARBITRO).
---------------------------------------------------------
*/

USE DB_Mundial2026_Grupo10;
GO

CREATE OR ALTER PROCEDURE torneo.sp_CONVOCATORIA_ABM (@Accion CHAR(1),
                                                      @id_seleccion INT,
                                                      @dorsal_oficial INT,
                                                      @nro_doc VARCHAR(20) = NULL,
                                                      @tipo_doc VARCHAR(10) = NULL,
                                                      @estado_convocatoria VARCHAR(20) = NULL) AS

BEGIN

DECLARE @ErroresAcumulados VARCHAR(MAX) =''; --'acumulador de mensajes de error'

SET NOCOUNT ON;

    IF @Accion NOT IN ('A', 'M', 'B') OR @Accion IS NULL
        SET @ErroresAcumulados += '- La acción es obligatoria y debe ser A (Alta), M (Modificación) o B (Baja).' + CHAR(13);

    IF @id_seleccion IS NULL
        SET @ErroresAcumulados += '- La selección es obligatoria.' + CHAR(13);
    ELSE IF @id_seleccion NOT IN (SELECT id_seleccion FROM torneo.SELECCION)
        SET @ErroresAcumulados += '- La selección indicada no existe en la base de datos.' + CHAR(13);

    IF @dorsal_oficial NOT BETWEEN 1 AND 99
        SET @ErroresAcumulados += '- El dorsal oficial debe estar entre 1 y 99.' + CHAR(13);

    IF @nro_doc NOT IN (SELECT 1 FROM persona.JUGADOR WHERE nro_doc = @nro_doc AND tipo_doc = @tipo_doc)
        SET @ErroresAcumulados += '- La persona indicada no existe en la base de datos.' + CHAR(13);

    IF @estado_convocatoria IS NULL
        SET @ErroresAcumulados += '- El estado de la convocatoria no puede ser nulo.' + CHAR(13);

    IF @Accion = 'A' AND @nro_doc IN (SELECT 1 FROM torneo.CONVOCATORIA WHERE nro_doc = @nro_doc AND @id_seleccion != id_seleccion)
        SET @ErroresAcumulados += '- La misma persona no puede ser convocada para dos selecciones.' + CHAR(13);

    IF @Accion = 'B' AND @nro_doc IN (SELECT 1 FROM torneo.INCIDENCIA_CONVOCATORIA WHERE id_seleccion = @id_seleccion AND dorsal_oficial = @dorsal_oficial )
        SET @ErroresAcumulados += '- No se puede dar de baja si el jugadorse encuentra lesionado.'

    IF LEN(@ErroresAcumulados) > 0
    BEGIN;
        THROW 50000, @ErroresAcumulados, 1;
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @Accion = 'A'
        BEGIN
            UPDATE persona.JUGADOR
                    SET es_convocado = 1
            WHERE nro_doc = @nro_doc AND tipo_doc = @tipo_doc;

            INSERT INTO torneo.CONVOCATORIA (id_seleccion,dorsal_oficial, nro_doc, tipo_doc, estado_convocatoria)
            VALUES (@id_seleccion, @dorsal_oficial,@nro_doc, @tipo_doc, @estado_convocatoria)
        END

        IF @Accion = 'M'
        BEGIN
            UPDATE torneo.CONVOCATORIA 
            SET 
                nro_doc = @nro_doc,
                tipo_doc = @tipo_doc,
                estado_convocatoria = @estado_convocatoria
            WHERE id_seleccion = @id_seleccion AND dorsal_oficial = @dorsal_oficial

        END;

        IF @Accion = 'B'
        BEGIN
            DELETE FROM torneo.CONVOCATORIA
            WHERE id_seleccion = @id_seleccion AND dorsal_oficial = @dorsal_oficial

            UPDATE persona.JUGADOR
               SET es_convocado = 0
            WHERE nro_doc = @nro_doc AND tipo_doc = @tipo_doc;
        END;
        
        COMMIT TRAN
    END TRY

    BEGIN CATCH
        IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
      
      DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
      THROW 50000,@ErrorMessage, 1;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE torneo.sp_INCIDENCIA_CONVOCATORIA_ABM (@Accion CHAR(1),
                                                                 @id_seleccion INT,
                                                                 @dorsal_oficial INT,
                                                                 @fecha_incidencia DATE,
                                                                 @motivo_baja_lesion VARCHAR(100) = NULL,
                                                                 @es_baja_definitiva BIT)AS
BEGIN
    DECLARE @ErroresAcumulados VARCHAR(MAX) =''; --'acumulador de mensajes de error'

SET NOCOUNT ON;

    IF @Accion NOT IN ('A', 'M', 'B') OR @Accion IS NULL
        SET @ErroresAcumulados += '- La acción es obligatoria y debe ser A (Alta), M (Modificación) o B (Baja).' + CHAR(13);

    IF @id_seleccion IS NULL
        SET @ErroresAcumulados += '- La selección es obligatoria.' + CHAR(13);
    ELSE IF NOT EXISTS (SELECT 1 FROM torneo.SELECCION WHERE id_seleccion = @id_seleccion)
        SET @ErroresAcumulados += '- La selección indicada no existe en la base de datos.' + CHAR(13);

    IF NOT EXISTS (SELECT 1 FROM torneo.CONVOCATORIA WHERE dorsal_oficial = @dorsal_oficial AND id_seleccion = @id_seleccion)
        SET @ErroresAcumulados += '- El dorsal indicado no pertenece a la seleccion indicada.' + CHAR(13);
    
    IF @fecha_incidencia IS NULL
        SET @ErroresAcumulados += '- La fecha de lesion no puede ser nula'

    IF LEN(@motivo_baja_lesion) < 10 OR @motivo_baja_lesion IS NULL
        SET @ErroresAcumulados += '- El motivo de incidencia debe de ser expresado correctamente.'
    
    IF @es_baja_definitiva NOT IN (0,1)
        SET @ErroresAcumulados += '- La baja definitiva de expresarse, ya sea por si (1) o por no (0).'

    IF LEN(@ErroresAcumulados) > 0
    BEGIN;
        THROW 50000, @ErroresAcumulados, 1;
        RETURN;
    END

    BEGIN TRY
        BEGIN TRAN

        IF @es_baja_definitiva = 1
        BEGIN
            UPDATE torneo.CONVOCATORIA
            SET estado_convocatoria = 'BAJA'
            WHERE id_seleccion = @id_seleccion AND dorsal_oficial = @dorsal_oficial
        END
            
        IF @Accion = 'A'
        BEGIN
           INSERT INTO torneo.INCIDENCIA_CONVOCATORIA (id_seleccion,dorsal_oficial,fecha_incidencia,motivo_baja_lesion,es_baja_definitiva)
           VALUES (@id_seleccion, @dorsal_oficial, @fecha_incidencia, @motivo_baja_lesion, @es_baja_definitiva)
        END

        IF @Accion = 'M'
        BEGIN
            UPDATE torneo.INCIDENCIA_CONVOCATORIA
            SET motivo_baja_lesion = @motivo_baja_lesion,
                es_baja_definitiva = @es_baja_definitiva
            WHERE id_seleccion = @id_seleccion AND dorsal_oficial = @dorsal_oficial
        END

        IF @Accion = 'B'
        BEGIN
            DELETE FROM torneo.INCIDENCIA_CONVOCATORIA
            WHERE id_seleccion = @id_seleccion AND
                  dorsal_oficial = @dorsal_oficial AND
                  fecha_incidencia = @fecha_incidencia
        END
        COMMIT TRAN;
    END TRY

    BEGIN CATCH    
      IF @@TRANCOUNT > 0
      ROLLBACK TRANSACTION;
      
      DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
      THROW 50000,@ErrorMessage, 1;
    END CATCH

END;
GO

