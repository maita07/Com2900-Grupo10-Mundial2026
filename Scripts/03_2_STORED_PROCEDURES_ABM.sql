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
             DB_Mundial2026_Grupo10 - Módulo 2 - Personas y Jugadores             
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

--2 Módulo Personas y Jugadores: persona.sp_JUGADOR_ABM

CREATE OR ALTER PROCEDURE persona.sp_JUGADOR_ABM (@Accion CHAR(1), -- 'A' (Alta),'M'(Modificacion), 'B' (Baja)
												 @nro_doc VARCHAR(20), -- Clave Compuesta 
												 @tipo_doc VARCHAR(10),
												 @id_nacionalidad_pais CHAR(3) = NULL, -- Atributos de Persona
												 @nombre VARCHAR(50) = NULL,
												 @apellido VARCHAR(50) = NULL,
												 @fecha_nacimiento DATE = NULL,
												 @posicion_habitual VARCHAR(30) = NULL, -- Atributos de Jugador
												 @club_origen VARCHAR(50) = NULL,
												 @peso_kg DECIMAL(5,2) = NULL,
												 @altura_cm DECIMAL(5,2) = NULL,
												 @es_convocado BIT = 0	) AS
BEGIN

DECLARE @ErroresAcumulados VARCHAR(MAX) =''; --'acumulador de mensajes de error'

SET NOCOUNT ON;
  -- Validaciones Generales

  -- Validar Acción
    IF @Accion NOT IN ('A', 'M', 'B') OR @Accion IS NULL
        SET @ErroresAcumulados += '- La acción es obligatoria y debe ser A (Alta), M (Modificación) o B (Baja).' + CHAR(13);
  
  -- Validar Tipo de Doc
	IF @tipo_doc IS NULL OR TRIM(@tipo_doc) = ''
        SET @ErroresAcumulados += '- El tipo de documento es obligatorio.' + CHAR(13);
    ELSE IF UPPER(TRIM(@tipo_doc)) NOT IN ('DNI', 'PASAPORTE', 'CI', 'LE', 'LC')
        SET @ErroresAcumulados += '- El tipo de documento no es válido (Debe ser DNI, PASAPORTE, CI, LE o LC).' + CHAR(13);
 
 -- Validar Nro de Doc
	IF @nro_doc IS NULL OR TRIM(@nro_doc) = ''
        SET @ErroresAcumulados += '- El Numero de documento es obligatorio.' + CHAR(13);
 
 -- Validaciones de Existencia de Persona/Jugador
	IF @Accion = 'A' AND EXISTS (
        SELECT nro_doc 
        FROM persona.PERSONA 
        WHERE nro_doc = TRIM(@nro_doc) AND tipo_doc = UPPER(TRIM(@tipo_doc))
    )
        SET @ErroresAcumulados += '- El número y tipo de documento ya pertenecen a una persona registrada.' + CHAR(13);

    IF @Accion IN ('M', 'B') AND NOT EXISTS (
        SELECT nro_doc 
        FROM persona.JUGADOR 
        WHERE nro_doc = TRIM(@nro_doc) AND tipo_doc = UPPER(TRIM(@tipo_doc))
    )
        SET @ErroresAcumulados += '- El jugador ingresado no existe para ser modificado o eliminado.' + CHAR(13);

-- Validaciones para Alta y Modificacion
	IF @Accion IN ('A', 'M')
    BEGIN
        IF @nombre IS NULL OR TRIM(@nombre) = ''
            SET @ErroresAcumulados += '- El nombre es obligatorio.' + CHAR(13);

        IF @apellido IS NULL OR TRIM(@apellido) = ''
            SET @ErroresAcumulados += '- El apellido es obligatorio.' + CHAR(13);

        IF @fecha_nacimiento IS NULL
            SET @ErroresAcumulados += '- La fecha de nacimiento es obligatoria.' + CHAR(13);
        ELSE IF @fecha_nacimiento >= GETDATE()
            SET @ErroresAcumulados += '- La fecha de nacimiento debe ser en el pasado.' + CHAR(13);

        IF @id_nacionalidad_pais IS NULL OR LEN(TRIM(@id_nacionalidad_pais)) <> 3
            SET @ErroresAcumulados += '- El código de país de nacionalidad debe tener 3 caracteres.' + CHAR(13);
        ELSE IF NOT EXISTS (
            SELECT id_pais 
            FROM geografia.PAIS 
            WHERE id_pais = UPPER(TRIM(@id_nacionalidad_pais))
        )
            SET @ErroresAcumulados += '- El país de nacionalidad especificado no existe en la base de datos.' + CHAR(13);

        IF @posicion_habitual IS NULL OR TRIM(@posicion_habitual) = ''
            SET @ErroresAcumulados += '- La posición habitual es obligatoria.' + CHAR(13);

        IF @club_origen IS NULL OR TRIM(@club_origen) = ''
            SET @ErroresAcumulados += '- El club de origen es obligatorio.' + CHAR(13);

        IF @peso_kg IS NULL OR @peso_kg <= 0
            SET @ErroresAcumulados += '- El peso debe ser un valor positivo mayor a 0.' + CHAR(13);

        IF @altura_cm IS NULL OR @altura_cm <= 0
            SET @ErroresAcumulados += '- La altura debe ser un valor positivo mayor a 0.' + CHAR(13);
    END;

-- Validar que no esté convocado antes de dar Baja
    IF @Accion = 'B' AND EXISTS (
        SELECT nro_doc 
        FROM torneo.CONVOCATORIA 
        WHERE nro_doc = TRIM(@nro_doc) 
          AND tipo_doc = UPPER(TRIM(@tipo_doc))
    )
        SET @ErroresAcumulados += '- No se puede eliminar el jugador porque tiene una convocatoria activa registrada en el torneo.' + CHAR(13);

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
            -- 1. Insertar primero en la Superclase
            INSERT INTO persona.PERSONA (nro_doc, tipo_doc, id_nacionalidad_pais, nombre, apellido, fecha_nacimiento, tipo_persona)
            VALUES (TRIM(@nro_doc), UPPER(TRIM(@tipo_doc)), UPPER(TRIM(@id_nacionalidad_pais)), TRIM(@nombre), TRIM(@apellido), @fecha_nacimiento, 'JUGADOR');

            -- 2. Insertar después en la Subclase
            INSERT INTO persona.JUGADOR (nro_doc, tipo_doc, posicion_habitual, club_origen, peso_kg, altura_cm, es_convocado)
            VALUES (TRIM(@nro_doc), UPPER(TRIM(@tipo_doc)), TRIM(@posicion_habitual), TRIM(@club_origen), @peso_kg, @altura_cm, ISNULL(@es_convocado, 0));

            PRINT 'Jugador registrado exitosamente.';
        END;

-- Modificaciones
	IF @Accion = 'M'
		BEGIN
			 -- 1. Modificar en la Superclase
            UPDATE persona.PERSONA
          	SET id_nacionalidad_pais = TRIM(@id_nacionalidad_pais),
			nombre = TRIM(@nombre),
			apellido = TRIM(@apellido),
			fecha_nacimiento = (@fecha_nacimiento)
			WHERE nro_doc = TRIM(@nro_doc) AND tipo_doc = TRIM(@tipo_doc);

            -- 2. Modificar en la Subclase
            UPDATE persona.JUGADOR
			SET posicion_habitual = TRIM(@posicion_habitual),
			club_origen = TRIM(@club_origen),
			peso_kg = (@peso_kg),
			altura_cm = (@altura_cm),
			es_convocado = ISNULL(@es_convocado, es_convocado) -- mantiene el valor que ya tenia 
			WHERE nro_doc = TRIM(@nro_doc) AND tipo_doc = UPPER(TRIM(@tipo_doc));
            
            PRINT 'Jugador modificado exitosamente.';
        END;
-- Baja
    IF @Accion = 'B'
        BEGIN
            -- 1. Eliminar PRIMERO de la Subclase
            DELETE FROM persona.JUGADOR
            WHERE nro_doc = TRIM(@nro_doc) AND tipo_doc = UPPER(TRIM(@tipo_doc));

            -- 2. Eliminar DESPUÉS de la Superclase
            DELETE FROM persona.PERSONA
            WHERE nro_doc = TRIM(@nro_doc) AND tipo_doc = UPPER(TRIM(@tipo_doc));

            PRINT 'Jugador eliminado exitosamente.';
        END;

 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @MensajeSQL NVARCHAR(4000) = ERROR_MESSAGE();
        THROW 50001, @MensajeSQL, 1;
    END CATCH;
GO

--2 Módulo Personas y Jugadores: persona.sp_CUERPO_TECNICO_ABM

CREATE OR ALTER PROCEDURE persona.sp_CUERPO_TECNICO_ABM (@Accion CHAR(1), -- 'A' (Alta), 'M' (Modificación), 'B' (Baja)
                                                         @nro_doc VARCHAR(20), -- Clave Primaria Compuesta
                                                         @tipo_doc VARCHAR(10),
                                                         @id_nacionalidad_pais CHAR(3) = NULL, -- Atributos de PERSONA (Superclase)
                                                         @nombre VARCHAR(50) = NULL,
                                                         @apellido VARCHAR(50) = NULL,
                                                         @fecha_nacimiento DATE = NULL,
                                                         @id_seleccion INT = NULL, -- Atributos de CUERPO_TECNICO (Subclase)
                                                         @cargo_tecnico VARCHAR(40) = NULL) AS
BEGIN

DECLARE @ErroresAcumulados VARCHAR(MAX) =''; --'acumulador de mensajes de error'

SET NOCOUNT ON;
    
    -- Validaciones Generales
    -- Validar Acción
   IF @Accion NOT IN ('A', 'M', 'B') OR @Accion IS NULL
        SET @ErroresAcumulados += '- La acción es obligatoria y debe ser "A", "M" o "B".' + CHAR(13);
    
    -- Validacion tipo de documento
    IF @tipo_doc IS NULL OR TRIM(@tipo_doc) = ''
        SET @ErroresAcumulados += '- El tipo de documento es obligatorio.' + CHAR(13);
    ELSE IF UPPER(TRIM(@tipo_doc)) NOT IN ('DNI', 'PASAPORTE', 'CI', 'LE', 'LC')
        SET @ErroresAcumulados += '- El tipo de documento ingresado no es válido.' + CHAR(13);

    -- Validacion numero de documento
    IF @nro_doc IS NULL OR TRIM(@nro_doc) = ''
        SET @ErroresAcumulados += '- El número de documento es obligatorio.' + CHAR(13);

    IF @Accion = 'A' AND EXISTS (
        SELECT nro_doc 
        FROM persona.PERSONA 
        WHERE nro_doc = TRIM(@nro_doc) AND tipo_doc = UPPER(TRIM(@tipo_doc))
    )
        SET @ErroresAcumulados += '- El documento especificado ya se encuentra registrado para otra persona.' + CHAR(13);

    IF @Accion IN ('M', 'B') AND NOT EXISTS (
        SELECT nro_doc 
        FROM persona.CUERPO_TECNICO 
        WHERE nro_doc = TRIM(@nro_doc) AND tipo_doc = UPPER(TRIM(@tipo_doc))
    )
        SET @ErroresAcumulados += '- El miembro del cuerpo técnico especificado no existe en el sistema.' + CHAR(13);

    -- Validaciones para Alta y Modificacion
    IF @Accion IN ('A', 'M')
    BEGIN
        IF @nombre IS NULL OR TRIM(@nombre) = ''
            SET @ErroresAcumulados += '- El nombre es obligatorio.' + CHAR(13);

        IF @apellido IS NULL OR TRIM(@apellido) = ''
            SET @ErroresAcumulados += '- El apellido es obligatorio.' + CHAR(13);

        IF @fecha_nacimiento IS NULL
            SET @ErroresAcumulados += '- La fecha de nacimiento es obligatoria.' + CHAR(13);
        ELSE IF @fecha_nacimiento >= GETDATE()
            SET @ErroresAcumulados += '- La fecha de nacimiento debe ser una fecha pasada.' + CHAR(13);

        IF @id_nacionalidad_pais IS NULL OR LEN(TRIM(@id_nacionalidad_pais)) <> 3
            SET @ErroresAcumulados += '- El código de país de nacionalidad debe tener 3 caracteres.' + CHAR(13);
        ELSE IF NOT EXISTS (
            SELECT id_pais 
            FROM geografia.PAIS 
            WHERE id_pais = UPPER(TRIM(@id_nacionalidad_pais))
        )
            SET @ErroresAcumulados += '- El país de nacionalidad especificado no existe en la base de datos.' + CHAR(13);

        IF @id_seleccion IS NULL OR @id_seleccion <= 0
            SET @ErroresAcumulados += '- La selección es obligatoria.' + CHAR(13);
        ELSE IF NOT EXISTS (
            SELECT id_seleccion 
            FROM torneo.SELECCION 
            WHERE id_seleccion = @id_seleccion
        )
            SET @ErroresAcumulados += '- La selección especificada no existe en la base de datos.' + CHAR(13);

        IF @cargo_tecnico IS NULL OR TRIM(@cargo_tecnico) = ''
            SET @ErroresAcumulados += '- El cargo técnico es obligatorio.' + CHAR(13);
    END;

    -- Control Errores Acumulados
    IF LEN(@ErroresAcumulados) > 0
    BEGIN
        SET @ErroresAcumulados = 'Se encontraron las siguientes observaciones:' + CHAR(13) + @ErroresAcumulados;
        THROW 50000, @ErroresAcumulados, 1;
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

    -- Alta
        IF @Accion = 'A'
        BEGIN
            INSERT INTO persona.PERSONA (
                nro_doc, tipo_doc, id_nacionalidad_pais, nombre, apellido, fecha_nacimiento, tipo_persona
            )
            VALUES (
                TRIM(@nro_doc), UPPER(TRIM(@tipo_doc)), UPPER(TRIM(@id_nacionalidad_pais)), 
                TRIM(@nombre), TRIM(@apellido), @fecha_nacimiento, 'CUERPO_TECNICO'
            );

            INSERT INTO persona.CUERPO_TECNICO (
                nro_doc, tipo_doc, id_seleccion, cargo_tecnico
            )
            VALUES (
                TRIM(@nro_doc), UPPER(TRIM(@tipo_doc)), @id_seleccion, TRIM(@cargo_tecnico)
            );

            PRINT 'Miembro del cuerpo técnico registrado exitosamente.';
        END;

    -- Modificaciones
        IF @Accion = 'M'
        BEGIN
            UPDATE persona.PERSONA
            SET id_nacionalidad_pais = UPPER(TRIM(@id_nacionalidad_pais)),
                nombre = TRIM(@nombre),
                apellido = TRIM(@apellido),
                fecha_nacimiento = @fecha_nacimiento
            WHERE nro_doc = TRIM(@nro_doc) 
              AND tipo_doc = UPPER(TRIM(@tipo_doc));

            UPDATE persona.CUERPO_TECNICO
            SET id_seleccion = @id_seleccion,
                cargo_tecnico = TRIM(@cargo_tecnico)
            WHERE nro_doc = TRIM(@nro_doc) 
              AND tipo_doc = UPPER(TRIM(@tipo_doc));

            PRINT 'Miembro del cuerpo técnico modificado exitosamente.';
        END;

    -- Baja
        IF @Accion = 'B'
        BEGIN
            DELETE FROM persona.CUERPO_TECNICO
            WHERE nro_doc = TRIM(@nro_doc) 
              AND tipo_doc = UPPER(TRIM(@tipo_doc));

            DELETE FROM persona.PERSONA
            WHERE nro_doc = TRIM(@nro_doc) 
              AND tipo_doc = UPPER(TRIM(@tipo_doc));

            PRINT 'Miembro del cuerpo técnico eliminado exitosamente.';
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

--2 Módulo Personas y Jugadores: persona.sp_ARBITRO_ABM

CREATE OR ALTER PROCEDURE persona.sp_ARBITRO_ABM (@Accion CHAR(1), -- 'A' (Alta), 'M' (Modificación), 'B' (Baja)
                                                  @nro_doc VARCHAR(20), -- Clave Primaria Compuesta
                                                  @tipo_doc VARCHAR(10),
                                                  @id_nacionalidad_pais CHAR(3) = NULL, -- Atributos de PERSONA (Superclase)
                                                  @nombre VARCHAR(50) = NULL,
                                                  @apellido VARCHAR(50) = NULL,
                                                  @fecha_nacimiento DATE = NULL,
                                                  @id_rol INT = NULL, -- Atributos de ARBITRO (Subclase)
                                                  @categoria_fifa VARCHAR(50) = NULL,
                                                  @anios_experiencia INT = NULL) AS
BEGIN

DECLARE @ErroresAcumulados VARCHAR(MAX) =''; --'acumulador de mensajes de error'

SET NOCOUNT ON;
    
    -- Validaciones Generales
    -- Validar Acción
    IF @Accion NOT IN ('A', 'M', 'B') OR @Accion IS NULL
        SET @ErroresAcumulados += '- La acción es obligatoria y debe ser "A", "M" o "B".' + CHAR(13);
    
    -- Validacion tipo de documento
    IF @tipo_doc IS NULL OR TRIM(@tipo_doc) = ''
        SET @ErroresAcumulados += '- El tipo de documento es obligatorio.' + CHAR(13);
    ELSE IF UPPER(TRIM(@tipo_doc)) NOT IN ('DNI', 'PASAPORTE', 'CI', 'LE', 'LC')
        SET @ErroresAcumulados += '- El tipo de documento ingresado no es válido.' + CHAR(13);

    -- Validacion numero de documento
    IF @nro_doc IS NULL OR TRIM(@nro_doc) = ''
        SET @ErroresAcumulados += '- El número de documento es obligatorio.' + CHAR(13);

    -- Validaciones para Alta, Modificacion y Baja
    IF @Accion = 'A' AND EXISTS (
        SELECT nro_doc 
        FROM persona.PERSONA 
        WHERE nro_doc = TRIM(@nro_doc) AND tipo_doc = UPPER(TRIM(@tipo_doc))
    )
        SET @ErroresAcumulados += '- El documento ingresado ya se encuentra registrado para otra persona.' + CHAR(13);

    IF @Accion IN ('M', 'B') AND NOT EXISTS (
        SELECT nro_doc 
        FROM persona.ARBITRO 
        WHERE nro_doc = TRIM(@nro_doc) AND tipo_doc = UPPER(TRIM(@tipo_doc))
    )
        SET @ErroresAcumulados += '- El árbitro ingresado no existe en el sistema.' + CHAR(13);

    -- Validar que no tenga partidas o designaciones arbitrales asignadas antes de borrar
    IF @Accion = 'B' AND EXISTS (
        SELECT nro_doc 
        FROM torneo.DESIGNACION_ARBITRAL 
        WHERE nro_doc = TRIM(@nro_doc) 
          AND tipo_doc = UPPER(TRIM(@tipo_doc))
    )
        SET @ErroresAcumulados += '- No se puede eliminar el árbitro porque tiene designaciones arbitrales registradas en el torneo.' + CHAR(13);

    IF @Accion IN ('A', 'M')
    BEGIN
        IF @nombre IS NULL OR TRIM(@nombre) = ''
            SET @ErroresAcumulados += '- El nombre es obligatorio.' + CHAR(13);

        IF @apellido IS NULL OR TRIM(@apellido) = ''
            SET @ErroresAcumulados += '- El apellido es obligatorio.' + CHAR(13);

        IF @fecha_nacimiento IS NULL
            SET @ErroresAcumulados += '- La fecha de nacimiento es obligatoria.' + CHAR(13);
        ELSE IF @fecha_nacimiento >= GETDATE()
            SET @ErroresAcumulados += '- La fecha de nacimiento debe ser una fecha pasada.' + CHAR(13);

        IF @id_nacionalidad_pais IS NULL OR LEN(TRIM(@id_nacionalidad_pais)) <> 3
            SET @ErroresAcumulados += '- El código de país de nacionalidad debe tener 3 caracteres.' + CHAR(13);
        ELSE IF NOT EXISTS (
            SELECT id_pais 
            FROM geografia.PAIS 
            WHERE id_pais = UPPER(TRIM(@id_nacionalidad_pais))
        )
            SET @ErroresAcumulados += '- El país de nacionalidad ingresado no existe en la base de datos.' + CHAR(13);

        IF @id_rol IS NULL OR @id_rol <= 0
            SET @ErroresAcumulados += '- El rol arbitral es obligatorio.' + CHAR(13);
        ELSE IF NOT EXISTS (
            SELECT id_rol 
            FROM torneo.ROL_ARBITRAL 
            WHERE id_rol = @id_rol
        )
            SET @ErroresAcumulados += '- El rol arbitral ingresado no existe en la base de datos.' + CHAR(13);

        IF @categoria_fifa IS NULL OR TRIM(@categoria_fifa) = ''
            SET @ErroresAcumulados += '- La categoría FIFA es obligatoria.' + CHAR(13);

        IF @anios_experiencia IS NULL OR @anios_experiencia < 0
            SET @ErroresAcumulados += '- Los años de experiencia son obligatorios y deben ser un número mayor o igual a 0.' + CHAR(13);
    END;

    -- Control Errores Acumulados
    IF LEN(@ErroresAcumulados) > 0
    BEGIN
        SET @ErroresAcumulados = 'Se encontraron las siguientes observaciones:' + CHAR(13) + @ErroresAcumulados;
        THROW 50000, @ErroresAcumulados, 1;
        RETURN;
    END;


    BEGIN TRY
        BEGIN TRANSACTION;

     -- Alta
        IF @Accion = 'A'
        BEGIN
            INSERT INTO persona.PERSONA (
                nro_doc, tipo_doc, id_nacionalidad_pais, nombre, apellido, fecha_nacimiento, tipo_persona
            )
            VALUES (
                TRIM(@nro_doc), UPPER(TRIM(@tipo_doc)), UPPER(TRIM(@id_nacionalidad_pais)), 
                TRIM(@nombre), TRIM(@apellido), @fecha_nacimiento, 'ARBITRO'
            );

            INSERT INTO persona.ARBITRO (
                nro_doc, tipo_doc, id_rol, categoria_fifa, anios_experiencia
            )
            VALUES (
                TRIM(@nro_doc), UPPER(TRIM(@tipo_doc)), @id_rol, TRIM(@categoria_fifa), @anios_experiencia
            );

            PRINT 'Árbitro registrado exitosamente.';
        END;
        
     -- Modificaciones
        IF @Accion = 'M'
        BEGIN
            UPDATE persona.PERSONA
            SET id_nacionalidad_pais = UPPER(TRIM(@id_nacionalidad_pais)),
                nombre = TRIM(@nombre),
                apellido = TRIM(@apellido),
                fecha_nacimiento = @fecha_nacimiento
            WHERE nro_doc = TRIM(@nro_doc) 
              AND tipo_doc = UPPER(TRIM(@tipo_doc));

            UPDATE persona.ARBITRO
            SET id_rol = @id_rol,
                categoria_fifa = TRIM(@categoria_fifa),
                anios_experiencia = @anios_experiencia
            WHERE nro_doc = TRIM(@nro_doc) 
              AND tipo_doc = UPPER(TRIM(@tipo_doc));

            PRINT 'Árbitro modificado exitosamente.';
        END;
    
     -- Baja
        IF @Accion = 'B'
        BEGIN
            DELETE FROM persona.ARBITRO
            WHERE nro_doc = TRIM(@nro_doc) 
              AND tipo_doc = UPPER(TRIM(@tipo_doc));

            DELETE FROM persona.PERSONA
            WHERE nro_doc = TRIM(@nro_doc) 
              AND tipo_doc = UPPER(TRIM(@tipo_doc));

            PRINT 'Árbitro eliminado exitosamente.';
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