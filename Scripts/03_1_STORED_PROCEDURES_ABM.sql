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
             DB_Mundial2026_Grupo10 - Módulo 1 - Geografia y Economia             
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
--1 Módulo Geografia y Economia: geografia.sp_PAIS_ABM

CREATE OR ALTER PROCEDURE geografia.sp_PAIS_ABM (@Accion CHAR(1), -- 'A' (Alta),'M'(Modificacion), 'B' (Baja)
												 @id_pais CHAR(3),
												 @nombre_pais VARCHAR(50) = NULL,
												 @moneda_pais VARCHAR(30) = NULL,
												 @pbi_per_capita_actual DECIMAL(18,2)=NULL) AS
BEGIN

DECLARE @ErroresAcumulados VARCHAR(MAX) =''; --'acumulador de mensajes de error'

SET NOCOUNT ON;

  -- Validar Acción
    IF @Accion NOT IN ('A', 'M', 'B') OR @Accion IS NULL
        SET @ErroresAcumulados += '- La acción es obligatoria y debe ser A (Alta), M (Modificación) o B (Baja).' + CHAR(13);
  
  -- Validar Codigo Pais
	IF @id_pais IS NULL
		SET @ErroresAcumulados += '- El codigo de pais no puede ser NULO.' + CHAR(13);
	ELSE IF LEN(TRIM(@id_pais)) <> 3
		SET @ErroresAcumulados += '- El codigo de pais debe ser de 3 caracteres.' + CHAR(13);
 
 -- Control Errores Acumulados
	IF LEN(@ErroresAcumulados) > 0
    BEGIN
        SET @ErroresAcumulados = 'Se encontraron los siguientes errores de validación:' 
                                 + CHAR(13) + @ErroresAcumulados;
        THROW 50000, @ErroresAcumulados, 1;
        RETURN; -- Corta la ejecución antes de entrar a la transacción
    END;

	BEGIN TRY
		BEGIN TRANSACTION;

  -- Alta
		IF @Accion = 'A'
		BEGIN
			INSERT INTO geografia.PAIS (id_pais, nombre_pais, moneda_pais, pbi_per_capita_actual)
			VALUES (UPPER(TRIM(@id_pais)), TRIM(@nombre_pais), TRIM(@moneda_pais), @pbi_per_capita_actual);

		END;

  -- Modificaciones
		IF @Accion = 'M'
		BEGIN
			UPDATE geografia.PAIS
			SET nombre_pais = TRIM(@nombre_pais),
				moneda_pais = TRIM(@moneda_pais),
				pbi_per_capita_actual = @pbi_per_capita_actual
			WHERE id_pais = UPPER(TRIM(@id_pais));
		END;

   -- Baja
		IF @Accion = 'B'
		BEGIN
			DELETE FROM geografia.PAIS WHERE id_pais = UPPER(TRIM(@id_pais));
		END;

		COMMIT TRANSACTION;
	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0
			ROLLBACK TRANSACTION;

		DECLARE @MensajeSQL NVARCHAR(4000) = ERROR_MESSAGE();
		THROW 50001, @MensajeSQL, 1;
	END CATCH;
END;
GO

--1 Módulo Geografia y Economia: geografia.sp_CONFEDERACION_ABM

CREATE OR ALTER PROCEDURE geografia.sp_CONFEDERACION_ABM (@Accion CHAR(1), -- 'A', 'M', 'B'
                                                          @id_confederacion INT = NULL,
                                                          @nombre_confederacion VARCHAR(50) = NULL,
                                                          @sigla VARCHAR(10) = NULL) AS
BEGIN
    DECLARE @ErroresAcumulados VARCHAR(MAX) =''; --'acumulador de mensajes de error'
    SET NOCOUNT ON;

    -- Validaciones Generales

    -- Validar Acción
    IF @Accion NOT IN ('A', 'M', 'B') OR @Accion IS NULL
        SET @ErroresAcumulados += '- La acción es obligatoria (A, M o B).' + CHAR(13);

    -- Validar codigo confederacion
    IF @id_confederacion IS NULL OR @id_confederacion <= 0
        SET @ErroresAcumulados += '- El ID de confederación es obligatorio y debe ser positivo.' + CHAR(13);

    -- Validar existencia para Alta / Modificación / Baja
    IF @Accion = 'A' AND EXISTS (
        SELECT id_confederacion 
        FROM geografia.CONFEDERACION 
        WHERE id_confederacion = @id_confederacion
    )
        SET @ErroresAcumulados += '- El ID de confederación especificado ya existe.' + CHAR(13);

    IF @Accion IN ('M', 'B') AND NOT EXISTS (
        SELECT id_confederacion 
        FROM geografia.CONFEDERACION 
        WHERE id_confederacion = @id_confederacion
    )
        SET @ErroresAcumulados += '- La confederación ingresada no existe.' + CHAR(13);

    -- Validar que no tenga selecciones asociadas antes de dar la Baja
    IF @Accion = 'B' AND EXISTS (
        SELECT id_confederacion 
        FROM torneo.SELECCION 
        WHERE id_confederacion = @id_confederacion
    )
        SET @ErroresAcumulados += '- No se puede eliminar la confederación porque tiene selecciones asociadas.' + CHAR(13);

    -- Validaciones de atributos para Alta y Modificación
    IF @Accion IN ('A', 'M')
    BEGIN
        IF @nombre_confederacion IS NULL OR TRIM(@nombre_confederacion) = ''
            SET @ErroresAcumulados += '- El nombre de la confederación es obligatorio.' + CHAR(13);

        IF @sigla IS NULL OR TRIM(@sigla) = ''
            SET @ErroresAcumulados += '- La sigla es obligatoria.' + CHAR(13);
        ELSE IF EXISTS (
            SELECT id_confederacion 
            FROM geografia.CONFEDERACION 
            WHERE sigla = UPPER(TRIM(@sigla)) 
              AND id_confederacion <> ISNULL(@id_confederacion, 0)
        )
            SET @ErroresAcumulados += '- La sigla ingresada ya pertenece a otra confederación.' + CHAR(13);
    END; 

    -- Control de Errores Acumulados
    IF LEN(@ErroresAcumulados) > 0
    BEGIN
        SET @ErroresAcumulados = 'Se encontraron las siguientes observaciones:' + CHAR(13) + @ErroresAcumulados;
        THROW 50000, @ErroresAcumulados, 1;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @Accion = 'A'
        BEGIN
            INSERT INTO geografia.CONFEDERACION (id_confederacion, nombre_confederacion, sigla)
            VALUES (@id_confederacion, TRIM(@nombre_confederacion), UPPER(TRIM(@sigla)));
            PRINT 'Confederación registrada exitosamente.';
        END;

        IF @Accion = 'M'
        BEGIN
            UPDATE geografia.CONFEDERACION
            SET nombre_confederacion = TRIM(@nombre_confederacion),
                sigla = UPPER(TRIM(@sigla))
            WHERE id_confederacion = @id_confederacion;
            PRINT 'Confederación modificada exitosamente.';
        END;

        IF @Accion = 'B'
        BEGIN
            DELETE FROM geografia.CONFEDERACION
            WHERE id_confederacion = @id_confederacion;
            PRINT 'Confederación eliminada exitosamente.';
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @ErrorMsg NVARCHAR(4000) = ERROR_MESSAGE();
        THROW 50001, @ErrorMsg, 1;
    END CATCH;
END;
GO

--1 Módulo Geografia y Economia: geografia.sp_INDICADOR_ECONOMICO_PAIS_ABM

CREATE OR ALTER PROCEDURE geografia.sp_INDICADOR_ECONOMICO_PAIS_ABM (@Accion CHAR(1), -- 'A', 'M', 'B'
                                                                     @id_pais CHAR(3) = NULL,
                                                                     @periodo_anio INT = NULL,
                                                                     @pbi_per_capita_usd DECIMAL(18,2) = NULL,
                                                                     @poblacion_total BIGINT = NULL,
                                                                     @indice_inflacion DECIMAL(5,2) = NULL) AS
BEGIN

    DECLARE @ErroresAcumulados VARCHAR(MAX) =''; --'acumulador de mensajes de error'
    SET NOCOUNT ON;

    -- Validaciones generales
    IF @Accion NOT IN ('A', 'M', 'B') OR @Accion IS NULL
        SET @ErroresAcumulados += '- La acción es obligatoria (A, M o B).' + CHAR(13);

    -- Validacion pais
    IF @id_pais IS NULL OR LEN(TRIM(@id_pais)) <> 3
        SET @ErroresAcumulados += '- El código de país debe tener 3 caracteres.' + CHAR(13);
    ELSE IF NOT EXISTS (SELECT id_pais FROM geografia.PAIS WHERE id_pais = UPPER(TRIM(@id_pais)))
        SET @ErroresAcumulados += '- El país especificado no existe en la base de datos.' + CHAR(13);

    -- Validacion periodo año
    IF @periodo_anio IS NULL OR @periodo_anio < 1900 OR @periodo_anio > YEAR(GETDATE())
        SET @ErroresAcumulados += '- El período (año) debe ser un año válido.' + CHAR(13);

    -- Validar Existencia
    IF @Accion = 'A' AND EXISTS (
        SELECT id_pais 
        FROM geografia.INDICADOR_ECONOMICO_PAIS 
        WHERE id_pais = UPPER(TRIM(@id_pais)) AND periodo_anio = @periodo_anio
    )
        SET @ErroresAcumulados += '- Ya existe un indicador económico para ese país y período.' + CHAR(13);

    IF @Accion IN ('M', 'B') AND NOT EXISTS (
        SELECT id_pais 
        FROM geografia.INDICADOR_ECONOMICO_PAIS 
        WHERE id_pais = UPPER(TRIM(@id_pais)) AND periodo_anio = @periodo_anio
    )
        SET @ErroresAcumulados += '- No existe un indicador económico para el país y período especificados.' + CHAR(13);

    -- Validaciones de Atributos para Alta y Modificación
    IF @Accion IN ('A', 'M')
    BEGIN
        IF @pbi_per_capita_usd IS NULL OR @pbi_per_capita_usd < 0
            SET @ErroresAcumulados += '- El PBI per cápita debe ser mayor o igual a 0.' + CHAR(13);

        IF @poblacion_total IS NULL OR @poblacion_total < 0
            SET @ErroresAcumulados += '- La población total debe ser mayor o igual a 0.' + CHAR(13);

        IF @indice_inflacion IS NULL
            SET @ErroresAcumulados += '- El índice de inflación es obligatorio.' + CHAR(13);
    END;

    IF LEN(@ErroresAcumulados) > 0
    BEGIN
        SET @ErroresAcumulados = 'Se encontraron las siguientes observaciones:' + CHAR(13) + @ErroresAcumulados;
        THROW 50000, @ErroresAcumulados, 1;
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @Accion = 'A'
        BEGIN
            INSERT INTO geografia.INDICADOR_ECONOMICO_PAIS (
                id_pais, periodo_anio, pbi_per_capita_usd, poblacion_total, indice_inflacion
            )
            VALUES (
                UPPER(TRIM(@id_pais)), @periodo_anio, @pbi_per_capita_usd, @poblacion_total, @indice_inflacion
            );
            PRINT 'Indicador económico registrado exitosamente.';
        END;

        IF @Accion = 'M'
        BEGIN
            UPDATE geografia.INDICADOR_ECONOMICO_PAIS
            SET pbi_per_capita_usd = @pbi_per_capita_usd,
                poblacion_total = @poblacion_total,
                indice_inflacion = @indice_inflacion
            WHERE id_pais = UPPER(TRIM(@id_pais)) AND periodo_anio = @periodo_anio;
            PRINT 'Indicador económico modificado exitosamente.';
        END;

        IF @Accion = 'B'
        BEGIN
            DELETE FROM geografia.INDICADOR_ECONOMICO_PAIS
            WHERE id_pais = UPPER(TRIM(@id_pais)) AND periodo_anio = @periodo_anio;
            PRINT 'Indicador económico eliminado exitosamente.';
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @ErrorMsg2 NVARCHAR(4000) = ERROR_MESSAGE();
        THROW 50001, @ErrorMsg2, 1;
    END CATCH;
END;
GO

--1 Módulo Geografia y Economia: geografia.sp_HISTORIAL_TIPO_CAMBIO_ABM

CREATE OR ALTER PROCEDURE geografia.sp_HISTORIAL_TIPO_CAMBIO_ABM (@Accion CHAR(1), -- 'A', 'M', 'B'
                                                                  @id_pais CHAR(3) = NULL,
                                                                  @fecha_cotizacion DATE = NULL,
                                                                  @valor_cotizacion DECIMAL(12,4) = NULL,
                                                                  @codigo_moneda VARCHAR(5) = NULL) AS
BEGIN
    DECLARE @ErroresAcumulados VARCHAR(MAX) =''; --'acumulador de mensajes de error'
    SET NOCOUNT ON;

    -- Validaciones generales
    IF @Accion NOT IN ('A', 'M', 'B') OR @Accion IS NULL
        SET @ErroresAcumulados += '- La acción es obligatoria (A, M o B).' + CHAR(13);
    
    -- Validacion pais
    IF @id_pais IS NULL OR LEN(TRIM(@id_pais)) <> 3
        SET @ErroresAcumulados += '- El código de país debe tener 3 caracteres.' + CHAR(13);
    ELSE IF NOT EXISTS (SELECT id_pais FROM geografia.PAIS WHERE id_pais = UPPER(TRIM(@id_pais)))
        SET @ErroresAcumulados += '- El país especificado no existe en la base de datos.' + CHAR(13);
    
    -- Validacion fecha cotizacion
    IF @fecha_cotizacion IS NULL
        SET @ErroresAcumulados += '- La fecha de cotización es obligatoria.' + CHAR(13);

    -- Validar Existencia
    IF @Accion = 'A' AND EXISTS (
        SELECT id_pais 
        FROM geografia.HISTORIAL_TIPO_CAMBIO 
        WHERE id_pais = UPPER(TRIM(@id_pais)) AND fecha_cotizacion = @fecha_cotizacion
    )
        SET @ErroresAcumulados += '- Ya existe un registro de tipo de cambio para ese país y fecha.' + CHAR(13);

    IF @Accion IN ('M', 'B') AND NOT EXISTS (
        SELECT id_pais 
        FROM geografia.HISTORIAL_TIPO_CAMBIO 
        WHERE id_pais = UPPER(TRIM(@id_pais)) AND fecha_cotizacion = @fecha_cotizacion
    )
        SET @ErroresAcumulados += '- No existe cotización registrada para ese país y fecha.' + CHAR(13);

    -- Validaciones para Alta y Modificación
    IF @Accion IN ('A', 'M')
    BEGIN
        IF @valor_cotizacion IS NULL OR @valor_cotizacion <= 0
            SET @ErroresAcumulados += '- El valor de la cotización debe ser un número positivo mayor a 0.' + CHAR(13);

        IF @codigo_moneda IS NULL OR TRIM(@codigo_moneda) = ''
            SET @ErroresAcumulados += '- El código de moneda es obligatorio.' + CHAR(13);
    END;

    IF LEN(@ErroresAcumulados) > 0
    BEGIN
        SET @ErroresAcumulados = 'Se encontraron las siguientes observaciones:' + CHAR(13) + @ErroresAcumulados;
        THROW 50000, @ErroresAcumulados, 1;
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @Accion = 'A'
        BEGIN
            INSERT INTO geografia.HISTORIAL_TIPO_CAMBIO (
                id_pais, fecha_cotizacion, valor_cotizacion, codigo_moneda
            )
            VALUES (
                UPPER(TRIM(@id_pais)), @fecha_cotizacion, @valor_cotizacion, UPPER(TRIM(@codigo_moneda))
            );
            PRINT 'Tipo de cambio registrado exitosamente.';
        END;

        IF @Accion = 'M'
        BEGIN
            UPDATE geografia.HISTORIAL_TIPO_CAMBIO
            SET valor_cotizacion = @valor_cotizacion,
                codigo_moneda = UPPER(TRIM(@codigo_moneda))
            WHERE id_pais = UPPER(TRIM(@id_pais)) AND fecha_cotizacion = @fecha_cotizacion;
            PRINT 'Tipo de cambio modificado exitosamente.';
        END;

        IF @Accion = 'B'
        BEGIN
            DELETE FROM geografia.HISTORIAL_TIPO_CAMBIO
            WHERE id_pais = UPPER(TRIM(@id_pais)) AND fecha_cotizacion = @fecha_cotizacion;
            PRINT 'Tipo de cambio eliminado exitosamente.';
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @ErrorMsg3 NVARCHAR(4000) = ERROR_MESSAGE();
        THROW 50001, @ErrorMsg3, 1;
    END CATCH;
END;
GO