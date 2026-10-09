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
             - Módulo Publicidad: comerciales.sp_PIEZA_PUBLICITARIA_ABM, 
               comerciales.sp_EXHIBICION_PUBLICITARIA_ABM.
---------------------------------------------------------
*/

USE DB_Mundial2026_Grupo10;
GO

--7 Módulo Publicidad: comercial.sp_PIEZA_PUBLICITARIA_ABM

CREATE OR ALTER PROCEDURE comercial.sp_PIEZA_PUBLICITARIA_ABM (@Accion CHAR(1), -- 'A' (Alta),'M'(Modificacion), 'B' (Baja)
															@id_pieza INT = NULL,
															@id_campania INT = NULL,
															@duracion_segundos INT = NULL,
															@url_contenido VARCHAR(200) = NULL,
															@idioma VARCHAR(20) = NULL) AS
BEGIN

DECLARE @ErroresAcumulados VARCHAR(MAX) = ''; --'acumulador de mensajes de error'

SET NOCOUNT ON;

-- Validar Acción
IF @Accion NOT IN ('A', 'M', 'B') OR @Accion IS NULL
	SET @ErroresAcumulados += '- La acción es obligatoria y debe ser A (Alta), M (Modificación) o B (Baja).' + CHAR(13);

-- Validar id_campania en CAMPANIA_PUBLICITARIA
IF @id_campania IS NULL
	SET @ErroresAcumulados += '- El id_campania es obligatorio.' + CHAR(13);
ELSE IF NOT EXISTS (SELECT id_campania FROM comercial.CAMPANIA_PUBLICITARIA WHERE id_campania = @id_campania)
	SET @ErroresAcumulados += '- El id_campania especificado no existe en la tabla CAMPANIA_PUBLICITARIA.' + CHAR(13);

-- Validar duracion_segundos > 0
IF @duracion_segundos IS NULL OR @duracion_segundos <= 0
	SET @ErroresAcumulados += '- La duración en segundos debe ser mayor a 0.' + CHAR(13);

-- Validar url_contenido no nulo
IF @url_contenido IS NULL OR TRIM(@url_contenido) = ''
	SET @ErroresAcumulados += '- La url del contenido es obligatoria.' + CHAR(13);

-- Validar idioma no nulo
IF @idioma IS NULL OR TRIM(@idioma) = ''
	SET @ErroresAcumulados += '- El idioma es obligatorio.' + CHAR(13);

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
		INSERT INTO comercial.PIEZA_PUBLICITARIA (id_pieza, id_campania, duracion_segundos, url_contenido, idioma)
		VALUES (@id_pieza, @id_campania, @duracion_segundos, UPPER(TRIM(@url_contenido)), UPPER(TRIM(@idioma)));
	END;

  -- Modificaciones
	IF @Accion = 'M'
	BEGIN
		UPDATE comercial.PIEZA_PUBLICITARIA
		SET id_campania = @id_campania,
			duracion_segundos = @duracion_segundos,
			url_contenido = UPPER(TRIM(@url_contenido)),
			idioma = UPPER(TRIM(@idioma))
		WHERE id_pieza = @id_pieza;
	END;

   -- Baja
	IF @Accion = 'B'
	BEGIN
		-- Restricción 'B': No eliminar si posee exhibiciones registradas
		IF EXISTS (SELECT id_exhibicion FROM comercial.EXHIBICION_PUBLICITARIA WHERE id_pieza = @id_pieza)
		BEGIN
			SET @ErroresAcumulados = '- No se puede eliminar la pieza publicitaria porque posee exhibiciones registradas.' + CHAR(13);
			THROW 50001, @ErroresAcumulados, 1;
			ROLLBACK TRANSACTION;
			RETURN;
		END;
		DELETE FROM comercial.PIEZA_PUBLICITARIA WHERE id_pieza = @id_pieza;
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

--7 Módulo Publicidad: comercial.sp_EXHIBICION_PUBLICITARIA_ABM

CREATE OR ALTER PROCEDURE comercial.sp_EXHIBICION_PUBLICITARIA_ABM (@Accion CHAR(1), -- 'A' (Alta),'M'(Modificacion), 'B' (Baja)
																@id_exhibicion INT = NULL,
																@id_partido INT = NULL,
																@id_anunciante INT = NULL,
																@id_campania INT = NULL,
																@id_pieza INT = NULL,
																@letrero_posicion INT = NULL,
																@minuto_inicio INT = NULL,
																@minuto_fin INT = NULL,
																@costo_calculado_usd DECIMAL(18,2) = NULL) AS
BEGIN

DECLARE @ErroresAcumulados VARCHAR(MAX) = ''; --'acumulador de mensajes de error'

SET NOCOUNT ON;

-- Validar Acción
IF @Accion NOT IN ('A', 'M', 'B') OR @Accion IS NULL
	SET @ErroresAcumulados += '- La acción es obligatoria y debe ser A (Alta), M (Modificación) o B (Baja).' + CHAR(13);

-- Validar Partido en PARTIDO
IF @id_partido IS NULL
	SET @ErroresAcumulados += '- El id_partido es obligatorio.' + CHAR(13);
ELSE IF NOT EXISTS (SELECT id_partido FROM torneo.PARTIDO WHERE id_partido = @id_partido)
	SET @ErroresAcumulados += '- El id_partido especificado no existe en la tabla PARTIDO.' + CHAR(13);

-- Validar anunciante en ANUNCIANTE
IF @id_anunciante IS NULL
	SET @ErroresAcumulados += '- El id_anunciante es obligatorio.' + CHAR(13);
ELSE IF NOT EXISTS (SELECT id_anunciante FROM comercial.ANUNCIANTE WHERE id_anunciante = @id_anunciante)
	SET @ErroresAcumulados += '- El id_anunciante especificado no existe en la tabla ANUNCIANTE.' + CHAR(13);

-- Validar campaña en CAMPANIA_PUBLICITARIA
IF @id_campania IS NULL
	SET @ErroresAcumulados += '- El id_campania es obligatorio.' + CHAR(13);
ELSE IF NOT EXISTS (SELECT id_campania FROM comercial.CAMPANIA_PUBLICITARIA WHERE id_campania = @id_campania)
	SET @ErroresAcumulados += '- El id_campania especificado no existe en la tabla CAMPANIA_PUBLICITARIA.' + CHAR(13);

-- Validar pieza en PIEZA_PUBLICITARIA
IF @id_pieza IS NULL
	SET @ErroresAcumulados += '- El id_pieza es obligatorio.' + CHAR(13);
ELSE IF NOT EXISTS (SELECT id_pieza FROM comercial.PIEZA_PUBLICITARIA WHERE id_pieza = @id_pieza)
	SET @ErroresAcumulados += '- El id_pieza especificado no existe en la tabla PIEZA_PUBLICITARIA.' + CHAR(13);

-- Validar letrero_posicion BETWEEN 1 AND 4
IF @letrero_posicion IS NULL OR @letrero_posicion < 1 OR @letrero_posicion > 4
	SET @ErroresAcumulados += '- El letrero_posicion debe estar entre 1 y 4.' + CHAR(13);

-- Validar minuto_inicio >= 0 y minuto_fin > minuto_inicio
IF @minuto_inicio IS NULL OR @minuto_inicio < 0
	SET @ErroresAcumulados += '- El minuto_inicio debe ser mayor o igual a 0.' + CHAR(13);
ELSE IF @minuto_fin IS NULL OR @minuto_fin <= @minuto_inicio
	SET @ErroresAcumulados += '- El minuto_fin debe ser mayor que el minuto_inicio.' + CHAR(13);

-- Validar costo_calculado_usd >= 0
IF @costo_calculado_usd IS NULL OR @costo_calculado_usd < 0
	SET @ErroresAcumulados += '- El costo calculado en USD debe ser mayor o igual a 0.' + CHAR(13);

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
		INSERT INTO comercial.EXHIBICION_PUBLICITARIA (id_exhibicion, id_partido, id_anunciante, id_campania, id_pieza, letrero_posicion, minuto_inicio, minuto_fin, costo_calculado_usd)
		VALUES (@id_exhibicion, @id_partido, @id_anunciante, @id_campania, @id_pieza, @letrero_posicion, @minuto_inicio, @minuto_fin, @costo_calculado_usd);
	END;

  -- Modificaciones
	IF @Accion = 'M'
	BEGIN
		UPDATE comercial.EXHIBICION_PUBLICITARIA
		SET id_partido = @id_partido,
			id_anunciante = @id_anunciante,
			id_campania = @id_campania,
			id_pieza = @id_pieza,
			lettero_posicion = @letrero_posicion,
			minuto_inicio = @minuto_inicio,
			minuto_fin = @minuto_fin,
			costo_calculado_usd = @costo_calculado_usd
		WHERE id_exhibicion = @id_exhibicion;
	END;

   -- Baja
	IF @Accion = 'B'
	BEGIN
		DELETE FROM comercial.EXHIBICION_PUBLICITARIA WHERE id_exhibicion = @id_exhibicion;
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