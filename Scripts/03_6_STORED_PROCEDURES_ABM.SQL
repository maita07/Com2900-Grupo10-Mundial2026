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

Descripcion: Script T-SQL de creación e implementación de los Stored Procedures 
             de Alta, Baja y Modificación (ABM) para la base de datos 
             DB_Mundial2026_Grupo10.             
             Características principales:
             - Encapsulamiento total de operaciones DML (INSERT, UPDATE, DELETE).
             - Validaciones de formato, dominio e integridad referencial.
             - Estrategia de acumulación de observaciones con mensaje consolidado (THROW 50000).
             - Control transaccional completo (BEGIN TRANSACTION / COMMIT / ROLLBACK) 
               y manejo de excepciones con TRY...CATCH.
             - Módulo Publicidad: comerciales.sp_ANUNCIANTE_ABM, 
               comerciales.sp_CAMPANIA_PUBLICITARIA_ABM.
---------------------------------------------------------
*/

USE DB_Mundial2026_Grupo10;
GO

--7 Módulo Publicidad: comercial.sp_ANUNCIANTE_ABM

CREATE OR ALTER PROCEDURE comercial.sp_ANUNCIANTE_ABM (@Accion CHAR(1), -- 'A' (Alta),'M'(Modificacion), 'B' (Baja)
														@id_anunciante INT = NULL,
														@razon_social VARCHAR(100) = NULL,
														@marca_comercial VARCHAR(100) = NULL,
														@rubro VARCHAR(50) = NULL,
														@id_pais_origen CHAR(3) = NULL) AS
BEGIN

DECLARE @ErroresAcumulados VARCHAR(MAX) = ''; --'acumulador de mensajes de error'

SET NOCOUNT ON;

-- Validar Acción
IF @Accion NOT IN ('A', 'M', 'B') OR @Accion IS NULL
	SET @ErroresAcumulados += '- La acción es obligatoria y debe ser A (Alta), M (Modificación) o B (Baja).' + CHAR(13);

-- Validar id_pais_origen
IF @id_pais_origen IS NULL
	SET @ErroresAcumulados += '- El id_pais_origen no puede ser NULO.' + CHAR(13);
ELSE IF LEN(TRIM(@id_pais_origen)) <> 3
	SET @ErroresAcumulados += '- El id_pais_origen debe ser de 3 caracteres.' + CHAR(13);
ELSE IF NOT EXISTS (SELECT id_pais FROM geografia.PAIS WHERE id_pais = UPPER(TRIM(@id_pais_origen)))
	SET @ErroresAcumulados += '- El país de origen especificado no existe en la base de datos.' + CHAR(13);

-- Validar razon_social no nulo ni vacío
IF @razon_social IS NULL OR TRIM(@razon_social) = ''
	SET @ErroresAcumulados += '- La razón social es obligatoria.' + CHAR(13);

-- Validar marca_comercial no nulo ni vacío
IF @marca_comercial IS NULL OR TRIM(@marca_comercial) = ''
	SET @ErroresAcumulados += '- La marca comercial es obligatoria.' + CHAR(13);

-- Validar rubro no nulo ni vacío
IF @rubro IS NULL OR TRIM(@rubro) = ''
	SET @ErroresAcumulados += '- El rubro es obligatorio.' + CHAR(13);

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
		INSERT INTO comercial.ANUNCIANTE (id_anunciante, razon_social, marca_comercial, rubro, id_pais_origen)
		VALUES (@id_anunciante, UPPER(TRIM(@razon_social)), UPPER(TRIM(@marca_comercial)), UPPER(TRIM(@rubro)), UPPER(TRIM(@id_pais_origen)));
	END;

  -- Modificaciones
	IF @Accion = 'M'
	BEGIN
		UPDATE comercial.ANUNCIANTE
		SET razon_social = UPPER(TRIM(@razon_social)),
			marca_comercial = UPPER(TRIM(@marca_comercial)),
			rubro = UPPER(TRIM(@rubro)),
			id_pais_origen = UPPER(TRIM(@id_pais_origen))
		WHERE id_anunciante = @id_anunciante;
	END;

   -- Baja
	IF @Accion = 'B'
	BEGIN
		-- Restricción 'B': No eliminar si tiene campañas registradas en CAMPANIA_PUBLICITARIA
		IF EXISTS (SELECT id_campania FROM comercial.CAMPANIA_PUBLICITARIA WHERE id_anunciante = @id_anunciante)
		BEGIN
			SET @ErroresAcumulados = '- No se puede eliminar el anunciante porque tiene campañas registradas en CAMPANIA_PUBLICITARIA.' + CHAR(13);
			THROW 50001, @ErroresAcumulados, 1;
			ROLLBACK TRANSACTION;
			RETURN;
		END;
		DELETE FROM comercial.ANUNCIANTE WHERE id_anunciante = @id_anunciante;
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

--7 Módulo Publicidad: comercial.sp_CAMPANIA_PUBLICITARIA_ABM

CREATE OR ALTER PROCEDURE comercial.sp_CAMPANIA_PUBLICITARIA_ABM (@Accion CHAR(1), -- 'A', 'M', 'B'
																@id_campania INT = NULL,
																@id_anunciante INT = NULL,
																@nombre_campania VARCHAR(100) = NULL,
																@presupuesto_max_usd DECIMAL(18,2) = NULL,
																@fecha_inicio DATE = NULL,
																@fecha_fin DATE = NULL) AS
BEGIN

DECLARE @ErroresAcumulados VARCHAR(MAX) = ''; --'acumulador de mensajes de error'

SET NOCOUNT ON;

-- Validar Acción
IF @Accion NOT IN ('A', 'M', 'B') OR @Accion IS NULL
	SET @ErroresAcumulados += '- La acción es obligatoria (A, M o B).' + CHAR(13);

-- Validar id_anunciante en ANUNCIANTE
IF @id_anunciante IS NULL
	SET @ErroresAcumulados += '- El id_anunciante es obligatorio.' + CHAR(13);
ELSE IF NOT EXISTS (SELECT id_anunciante FROM comercial.ANUNCIANTE WHERE id_anunciante = @id_anunciante)
	SET @ErroresAcumulados += '- El id_anunciante especificado no existe en la tabla ANUNCIANTE.' + CHAR(13);

-- Validar nombre_campania no nulo
IF @nombre_campania IS NULL OR TRIM(@nombre_campania) = ''
	SET @ErroresAcumulados += '- El nombre de la campaña es obligatorio.' + CHAR(13);

-- Validar presupuesto_max_usd > 0
IF @presupuesto_max_usd IS NULL OR @presupuesto_max_usd <= 0
	SET @ErroresAcumulados += '- El presupuesto máximo en USD debe ser mayor a 0.' + CHAR(13);

-- Validar fecha_fin >= fecha_inicio
IF @fecha_inicio IS NULL OR @fecha_fin IS NULL
	SET @ErroresAcumulados += '- Tanto la fecha de inicio como la fecha de fin son obligatorias.' + CHAR(13);
ELSE IF @fecha_fin < @fecha_inicio
	SET @ErroresAcumulados += '- La fecha de fin debe ser mayor o igual a la fecha de inicio.' + CHAR(13);

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
		INSERT INTO comercial.CAMPANIA_PUBLICITARIA (id_campania, id_anunciante, nombre_campania, presupuesto_max_usd, fecha_inicio, fecha_fin)
		VALUES (@id_campania, @id_anunciante, UPPER(TRIM(@nombre_campania)), @presupuesto_max_usd, @fecha_inicio, @fecha_fin);
	END;

  -- Modificaciones
	IF @Accion = 'M'
	BEGIN
		UPDATE comercial.CAMPANIA_PUBLICITARIA
		SET id_anunciante = @id_anunciante,
			nombre_campania = UPPER(TRIM(@nombre_campania)),
			presupuesto_max_usd = @presupuesto_max_usd,
			fecha_inicio = @fecha_inicio,
			fecha_fin = @fecha_fin
		WHERE id_campania = @id_campania;
	END;

   -- Baja
	IF @Accion = 'B'
	BEGIN
		-- Restricción 'B': No eliminar si tiene piezas publicitarias o exhibiciones vinculadas
		IF EXISTS (SELECT id_pieza FROM comercial.PIEZA_PUBLICITARIA WHERE id_campania = @id_campania)
		BEGIN
			SET @ErroresAcumulados = '- No se puede eliminar la campaña porque tiene piezas publicitarias vinculadas.' + CHAR(13);
			THROW 50001, @ErroresAcumulados, 1;
			ROLLBACK TRANSACTION;
			RETURN;
		END;
		IF EXISTS (SELECT id_exhibicion FROM comercial.EXHIBICION_PUBLICITARIA WHERE id_campania = @id_campania)
		BEGIN
			SET @ErroresAcumulados = '- No se puede eliminar la campaña porque tiene exhibiciones publicitarias vinculadas.' + CHAR(13);
			THROW 50001, @ErroresAcumulados, 1;
			ROLLBACK TRANSACTION;
			RETURN;
		END;
		DELETE FROM comercial.CAMPANIA_PUBLICITARIA WHERE id_campania = @id_campania;
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