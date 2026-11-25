/*
================================================================================
UNLaM - Universidad Nacional de La Matanza
Departamento de Ingeniería e Investigaciones Tecnológicas
Materia: Base de Datos Aplicada (Comisión 5600)
Entrega 6 - Script 04_10: Creacion de la tabla PIEZA_MERCADO y su correspondiente ABM
2026 - 2C
Grupo 10

Integrantes:
- Monasterio Erik: MonasteryEr
- Arena Ariel Ignacio: arielarena
- Castillo Gabriela Florencia: ItsFlorencia
- Maita Pitado Jose Gregorio: maita07

Archivo: 04_10_1_CREATE_TABLE_PIEZA_MERCADO.sql
Descripcion:
	Se realizara la creacion de la tabla de PIEZA_MERCADO, la cual se utilizara para determinar a que paises
	esta dirigido cada pieza publicitaria y su sp de manejo de datos.
	A partir de esta tabla se podra calcular cuales son las piezas mas convenientes para cada partido.

================================================================================
*/

USE DB_Mundial2026_Grupo10
GO

IF OBJECT_ID('comercial.PIEZA_MERCADO', 'U') IS NULL
BEGIN
	CREATE TABLE comercial.PIEZA_MERCADO(
		id_pieza INT NOT NULL,
		id_pais CHAR(3) NOT NULL,
		CONSTRAINT PK_PIEZA_MERCADO PRIMARY KEY (id_pieza, id_pais),
		CONSTRAINT FK_PIEZA_MERCADO_PIEZA FOREIGN KEY (id_pieza) REFERENCES comercial.PIEZA_PUBLICITARIA (id_pieza),
		CONSTRAINT FK_PAIZ_PERCADO_PAIS FOREIGN KEY (id_pais) REFERENCES geografia.PAIS(id_pais)
	);
	PRINT '--> Tabla "comercial.PIEZA_MERCADO" creada con exito.';
END
ELSE
BEGIN
	PRINT 'La tabla "comercial.PIEZA_MERCADO" ya existe.';
END;
GO

CREATE OR ALTER PROCEDURE comercial.sp_PIEZA_MERCADO_ABM (
	@Accion CHAR(1),
	@id_pieza INT NULL,
	@id_pais CHAR(3) NULL) as

BEGIN

DECLARE @ErroresAcumulados VARCHAR(MAX) ='';

SET NOCOUNT ON;

	IF @Accion NOT IN ('A', 'B', 'M') OR @Accion IS NULL
		SET @ErroresAcumulados += '- La acción es obligatoria y debe ser A (Alta), M(Modificacion) o B (Baja).' + CHAR(13);

	IF @id_pieza IS NULL OR NOT EXISTS (SELECT id_pieza FROM comercial.PIEZA_PUBLICITARIA WHERE id_pieza = @id_pieza)
		SET @ErroresAcumulados += '- El ID de pieza publicitaria indicado no pertenece a ninguna pieza existente.' + CHAR(13);
	
	IF @id_pais IS NULL OR NOT EXISTS (SELECT id_pais FROM geografia.PAIS WHERE id_pais = @id_pais)
		SET @ErroresAcumulados += '- El ID de pais indicado no pertenece a ninguna pieza existente.' + CHAR(13);

	IF @Accion = 'A'
	BEGIN
		IF EXISTS (SELECT 1 FROM comercial.PIEZA_MERCADO WHERE id_pais = @id_pais AND id_pieza = @id_pieza)
			SET @ErroresAcumulados += '- La pieza comercial ya se encuentra asociada a ese mercado en concreto.' + CHAR(13);
	END;

	IF @Accion = 'B'
	BEGIN
		IF NOT EXISTS (SELECT 1 FROM comercial.PIEZA_MERCADO WHERE id_pais = @id_pais AND id_pieza = @id_pieza)
			SET @ErroresAcumulados += '- No se puede eliminar una relacion que no existe.' + CHAR(13);
	END;

	IF @Accion = 'M'
	BEGIN
		IF NOT EXISTS (SELECT 1 FROM comercial.PIEZA_MERCADO WHERE id_pais = @id_pais AND id_pieza = @id_pieza)
			SET @ErroresAcumulados += '- No se puede modificar una relacion que no existe.' + CHAR(13);
	END;

	IF LEN(@ErroresAcumulados) > 0
    BEGIN;
        THROW 50000, @ErroresAcumulados, 1;
        RETURN;
    END;

	BEGIN TRY
		BEGIN TRANSACTION;

		IF @Accion = 'A'
		BEGIN
			INSERT INTO comercial.PIEZA_MERCADO (id_pieza,id_pais)
			VALUES (@id_pieza, @id_pais)
		END;

		IF @Accion = 'M'
		BEGIN
			UPDATE comercial.PIEZA_MERCADO 
			SET
				id_pieza = @id_pieza,
				id_pais = @id_pais
			WHERE id_pais = @id_pais AND id_pieza = @id_pieza

		END;

		IF @Accion = 'B'
		BEGIN
			DELETE FROM comercial.PIEZA_MERCADO 
			WHERE id_pais = @id_pais AND id_pieza = @id_pieza
		END;

		COMMIT TRAN

	END TRY

	BEGIN CATCH
		IF @@TRANCOUNT > 0
		ROLLBACK TRANSACTION;

		DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
		THROW 50000, @ErrorMessage, 1;
	END CATCH;
END;
GO
