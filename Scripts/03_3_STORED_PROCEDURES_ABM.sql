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
             DB_Mundial2026_Grupo10 - Modulo 3 - Selección.             
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

CREATE OR ALTER PROCEDURE torneo.sp_SELECCION_ABM (@Accion CHAR(1), -- 'A' (Alta),'M'(Modificacion), 'B' (Baja)
                                                   @Id_Seleccion CHAR(3),
                                                   @Id_Confederacion INT,
                                                   @Id_Pais CHAR(3) = NULL,
                                                   @Nombre_Seleccion VARCHAR(50) = NULL,
                                                   @Grupo CHAR(1) = NULL) AS
BEGIN
    DECLARE @ErroresAcumulados VARCHAR(MAX) =''; --'acumulador de mensajes de error'
    SET NOCOUNT ON;

    IF @Accion NOT IN ('A', 'M', 'B') OR @Accion IS NULL
        SET @ErroresAcumulados += '- La acción es obligatoria (A, M o B).' + CHAR(13);

    IF @Id_Seleccion IS NULL OR LEN(@Id_Seleccion) <> 3
        SET @ErroresAcumulados += '- El ID de la selección es obligatorio y debe tener 3 caracteres.' + CHAR(13);

    IF @Id_Confederacion NOT IN (SELECT id_confederacion FROM geografia.CONFEDERACION)
        SET @ErroresAcumulados += '- La confederacion indicada no existe.' + CHAR(13);

    IF @Id_Pais NOT IN (SELECT id_pais FROM geografia.PAIS)
      SET @ErroresAcumulados += '- El país indicado no existe.' + CHAR(13);

    IF @Grupo NOT BETWEEN 'A' AND 'L'
      SET @ErroresAcumulados += '- El grupo indicado no es válido (A-L).' + CHAR(13);

    IF @Nombre_Seleccion IS NULL OR LEN(@Nombre_Seleccion) <= 0
      SET @ErroresAcumulados += '- El nombre de la selección es obligatorio y no puede estar vacío.' + CHAR(13);

    IF @Accion = 'B'
    BEGIN
      IF EXISTS (SELECT 1 FROM torneo.CONVOCATORIA WHERE id_seleccion = @Id_Seleccion)
        SET @ErroresAcumulados += '- La selección no se puede eliminar porque tiene convocatorias asociadas.' + CHAR(13);

      IF EXISTS (SELECT 1 FROM torneo.PARTIDO WHERE id_seleccion_local = @Id_Seleccion OR id_seleccion_visitante = @Id_Seleccion)
        SET @ErroresAcumulados += '- La selección no se puede eliminar porque tiene partidos asociados.' + CHAR(13);

      IF EXISTS (SELECT 1 FROM persona.CUERPO_TECNICO WHERE id_seleccion = @Id_Seleccion)
        SET @ErroresAcumulados += '- La selección no se puede eliminar porque tiene cuerpo técnico asociado.' + CHAR(13);
    END;

    IF LEN(@ErroresAcumulados)> 0
    BEGIN;
      THROW 50000, @ErroresAcumulados, 1;
      RETURN;
    END;

    BEGIN TRY
      BEGIN TRANSACTION;

      --ALTA
      IF @Accion = 'A'
      BEGIN
        INSERT INTO torneo.SELECCION (id_seleccion, id_confederacion, id_pais, nombre_seleccion, grupo_asignado)
        VALUES (@Id_Seleccion, @Id_Confederacion, @Id_Pais, @Nombre_Seleccion, @Grupo);
      END;

      --MODIFICACION
      IF @Accion = 'M'
      BEGIN
        UPDATE torneo.SELECCION
        SET id_confederacion = @Id_Confederacion,
            id_pais = @Id_Pais,
            nombre_seleccion = @Nombre_Seleccion,
            grupo_asignado = @Grupo
        WHERE id_seleccion = @Id_Seleccion;
      END;

      --BAJA
      IF @Accion = 'B'
      BEGIN
        DELETE FROM torneo.SELECCION
        WHERE id_seleccion = @Id_Seleccion;
      END;

      COMMIT TRANSACTION;
    END TRY

    BEGIN CATCH
      IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
      
      DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
      THROW 50000,@ErrorMessage, 1;
    END CATCH;
END;
GO
