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
             DB_Mundial2026_Grupo10 - Módulo 5: Incidencias del partido
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

--5 Módulo Incidencias del Partido: torneo.sp_ROL_ARBITRAL_ABM
 
CREATE OR ALTER PROCEDURE torneo.sp_ROL_ARBITRAL_ABM (@Accion CHAR(1), -- 'A' (Alta), 'M' (Modificación), 'B' (Baja)
                                                       @id_rol INT = NULL,
                                                       @rol_descripcion VARCHAR(40) = NULL) AS
BEGIN
 
DECLARE @ErroresAcumulados VARCHAR(MAX) =''; --'acumulador de mensajes de error'
 
SET NOCOUNT ON;
 
    -- Validar Acción
    IF @Accion NOT IN ('A', 'M', 'B') OR @Accion IS NULL
        SET @ErroresAcumulados += '- La acción es obligatoria y debe ser A (Alta), M (Modificación) o B (Baja).' + CHAR(13);
 
    -- Validar ID de Rol
    IF @id_rol IS NULL OR @id_rol <= 0
        SET @ErroresAcumulados += '- El ID de rol arbitral es obligatorio y debe ser un valor positivo.' + CHAR(13);
 
    -- Validar Existencia
    IF @Accion = 'A' AND EXISTS (
        SELECT id_rol FROM torneo.ROL_ARBITRAL WHERE id_rol = @id_rol
    )
        SET @ErroresAcumulados += '- El ID de rol arbitral especificado ya existe.' + CHAR(13);
 
    IF @Accion IN ('M', 'B') AND NOT EXISTS (
        SELECT id_rol FROM torneo.ROL_ARBITRAL WHERE id_rol = @id_rol
    )
        SET @ErroresAcumulados += '- El rol arbitral ingresado no existe.' + CHAR(13);
 
    -- Restricción de Baja: no debe tener árbitros ni designaciones con este rol
    IF @Accion = 'B' AND EXISTS (
        SELECT id_rol FROM persona.ARBITRO WHERE id_rol = @id_rol
    )
        SET @ErroresAcumulados += '- No se puede eliminar el rol porque existen árbitros registrados con dicho rol.' + CHAR(13);
 
    IF @Accion = 'B' AND EXISTS (
        SELECT id_rol FROM torneo.DESIGNACION_ARBITRAL WHERE id_rol = @id_rol
    )
        SET @ErroresAcumulados += '- No se puede eliminar el rol porque existen designaciones arbitrales registradas con dicho rol.' + CHAR(13);
 
    -- Validaciones de atributos para Alta y Modificación
    IF @Accion IN ('A', 'M')
    BEGIN
        IF @rol_descripcion IS NULL OR TRIM(@rol_descripcion) = ''
            SET @ErroresAcumulados += '- La descripción del rol es obligatoria.' + CHAR(13);
    END;
 
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
            INSERT INTO torneo.ROL_ARBITRAL (id_rol, rol_descripcion)
            VALUES (@id_rol, TRIM(@rol_descripcion));
            PRINT 'Rol arbitral registrado exitosamente.';
        END;
 
        -- Modificaciones
        IF @Accion = 'M'
        BEGIN
            UPDATE torneo.ROL_ARBITRAL
            SET rol_descripcion = TRIM(@rol_descripcion)
            WHERE id_rol = @id_rol;
            PRINT 'Rol arbitral modificado exitosamente.';
        END;
 
        -- Baja
        IF @Accion = 'B'
        BEGIN
            DELETE FROM torneo.ROL_ARBITRAL WHERE id_rol = @id_rol;
            PRINT 'Rol arbitral eliminado exitosamente.';
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
 
--5 Módulo Incidencias del Partido: torneo.sp_SEDE_ABM
 
CREATE OR ALTER PROCEDURE torneo.sp_SEDE_ABM (@Accion CHAR(1), -- 'A', 'M', 'B'
                                              @id_sede INT = NULL,
                                              @id_pais CHAR(3) = NULL,
                                              @nombre_estadio VARCHAR(50) = NULL,
                                              @ciudad VARCHAR(50) = NULL,
                                              @capacidad INT = NULL,
                                              @huso_horario_utc VARCHAR(10) = NULL) AS
BEGIN
 
DECLARE @ErroresAcumulados VARCHAR(MAX) =''; --'acumulador de mensajes de error'
 
SET NOCOUNT ON;
 
    -- Validar Acción
    IF @Accion NOT IN ('A', 'M', 'B') OR @Accion IS NULL
        SET @ErroresAcumulados += '- La acción es obligatoria y debe ser A (Alta), M (Modificación) o B (Baja).' + CHAR(13);
 
    -- Validar ID de Sede
    IF @id_sede IS NULL OR @id_sede <= 0
        SET @ErroresAcumulados += '- El ID de sede es obligatorio y debe ser un valor positivo.' + CHAR(13);
 
    -- Validar Existencia
    IF @Accion = 'A' AND EXISTS (SELECT id_sede FROM torneo.SEDE WHERE id_sede = @id_sede)
        SET @ErroresAcumulados += '- El ID de sede especificado ya existe.' + CHAR(13);
 
    IF @Accion IN ('M', 'B') AND NOT EXISTS (SELECT id_sede FROM torneo.SEDE WHERE id_sede = @id_sede)
        SET @ErroresAcumulados += '- La sede ingresada no existe.' + CHAR(13);
 
    -- Restricción de Baja: no debe tener partidos asignados
    IF @Accion = 'B' AND EXISTS (SELECT id_sede FROM torneo.PARTIDO WHERE id_sede = @id_sede)
        SET @ErroresAcumulados += '- No se puede eliminar la sede porque tiene partidos asignados.' + CHAR(13);
 
    -- Validaciones de atributos para Alta y Modificación
    IF @Accion IN ('A', 'M')
    BEGIN
        IF @id_pais IS NULL OR LEN(TRIM(@id_pais)) <> 3
            SET @ErroresAcumulados += '- El código de país debe tener 3 caracteres.' + CHAR(13);
        ELSE IF NOT EXISTS (SELECT id_pais FROM geografia.PAIS WHERE id_pais = UPPER(TRIM(@id_pais)))
            SET @ErroresAcumulados += '- El país especificado no existe en la base de datos.' + CHAR(13);
 
        IF @nombre_estadio IS NULL OR TRIM(@nombre_estadio) = ''
            SET @ErroresAcumulados += '- El nombre del estadio es obligatorio.' + CHAR(13);
 
        IF @ciudad IS NULL OR TRIM(@ciudad) = ''
            SET @ErroresAcumulados += '- La ciudad es obligatoria.' + CHAR(13);
 
        IF @capacidad IS NULL OR @capacidad <= 0
            SET @ErroresAcumulados += '- La capacidad debe ser un valor positivo mayor a 0.' + CHAR(13);
 
        IF @huso_horario_utc IS NULL OR TRIM(@huso_horario_utc) = ''
            SET @ErroresAcumulados += '- El huso horario UTC es obligatorio.' + CHAR(13);
    END;
 
    -- Control Errores Acumulados
    IF LEN(@ErroresAcumulados) > 0
    BEGIN
        SET @ErroresAcumulados = 'Se encontraron los siguientes errores de validación:'
                                 + CHAR(13) + @ErroresAcumulados;
        THROW 50000, @ErroresAcumulados, 1;
        RETURN;
    END;
 
    BEGIN TRY
        BEGIN TRANSACTION;
 
        -- Alta
        IF @Accion = 'A'
        BEGIN
            INSERT INTO torneo.SEDE (id_sede, id_pais, nombre_estadio, ciudad, capacidad, huso_horario_utc)
            VALUES (@id_sede, UPPER(TRIM(@id_pais)), TRIM(@nombre_estadio), TRIM(@ciudad), @capacidad, TRIM(@huso_horario_utc));
            PRINT 'Sede registrada exitosamente.';
        END;
 
        -- Modificaciones
        IF @Accion = 'M'
        BEGIN
            UPDATE torneo.SEDE
            SET id_pais = UPPER(TRIM(@id_pais)),
                nombre_estadio = TRIM(@nombre_estadio),
                ciudad = TRIM(@ciudad),
                capacidad = @capacidad,
                huso_horario_utc = TRIM(@huso_horario_utc)
            WHERE id_sede = @id_sede;
            PRINT 'Sede modificada exitosamente.';
        END;
 
        -- Baja
        IF @Accion = 'B'
        BEGIN
            DELETE FROM torneo.SEDE WHERE id_sede = @id_sede;
            PRINT 'Sede eliminada exitosamente.';
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
 
--5 Módulo Incidencias del Partido: torneo.sp_FASE_TORNEO_ABM
 
CREATE OR ALTER PROCEDURE torneo.sp_FASE_TORNEO_ABM (@Accion CHAR(1), -- 'A', 'M', 'B'
                                                      @id_fase INT = NULL,
                                                      @nombre_fase VARCHAR(40) = NULL,
                                                      @orden_secuencia INT = NULL) AS
BEGIN
 
DECLARE @ErroresAcumulados VARCHAR(MAX) =''; --'acumulador de mensajes de error'
 
SET NOCOUNT ON;
 
    -- Validar Acción
    IF @Accion NOT IN ('A', 'M', 'B') OR @Accion IS NULL
        SET @ErroresAcumulados += '- La acción es obligatoria y debe ser A (Alta), M (Modificación) o B (Baja).' + CHAR(13);
 
    -- Validar ID de Fase
    IF @id_fase IS NULL OR @id_fase <= 0
        SET @ErroresAcumulados += '- El ID de fase es obligatorio y debe ser un valor positivo.' + CHAR(13);
 
    -- Validar Existencia
    IF @Accion = 'A' AND EXISTS (SELECT id_fase FROM torneo.FASE_TORNEO WHERE id_fase = @id_fase)
        SET @ErroresAcumulados += '- El ID de fase especificado ya existe.' + CHAR(13);
 
    IF @Accion IN ('M', 'B') AND NOT EXISTS (SELECT id_fase FROM torneo.FASE_TORNEO WHERE id_fase = @id_fase)
        SET @ErroresAcumulados += '- La fase del torneo ingresada no existe.' + CHAR(13);
 
    -- Restricción de Baja: no debe tener partidos registrados en esa fase
    IF @Accion = 'B' AND EXISTS (SELECT id_fase FROM torneo.PARTIDO WHERE id_fase = @id_fase)
        SET @ErroresAcumulados += '- No se puede eliminar la fase porque existen partidos registrados en ella.' + CHAR(13);
 
    -- Validaciones de atributos para Alta y Modificación
    IF @Accion IN ('A', 'M')
    BEGIN
        IF @nombre_fase IS NULL OR TRIM(@nombre_fase) = ''
            SET @ErroresAcumulados += '- El nombre de la fase es obligatorio.' + CHAR(13);
 
        IF @orden_secuencia IS NULL OR @orden_secuencia <= 0
            SET @ErroresAcumulados += '- El orden de secuencia debe ser un valor positivo mayor a 0.' + CHAR(13);
    END;
 
    -- Control Errores Acumulados
    IF LEN(@ErroresAcumulados) > 0
    BEGIN
        SET @ErroresAcumulados = 'Se encontraron los siguientes errores de validación:'
                                 + CHAR(13) + @ErroresAcumulados;
        THROW 50000, @ErroresAcumulados, 1;
        RETURN;
    END;
 
    BEGIN TRY
        BEGIN TRANSACTION;
 
        -- Alta
        IF @Accion = 'A'
        BEGIN
            INSERT INTO torneo.FASE_TORNEO (id_fase, nombre_fase, orden_secuencia)
            VALUES (@id_fase, TRIM(@nombre_fase), @orden_secuencia);
            PRINT 'Fase del torneo registrada exitosamente.';
        END;
 
        -- Modificaciones
        IF @Accion = 'M'
        BEGIN
            UPDATE torneo.FASE_TORNEO
            SET nombre_fase = TRIM(@nombre_fase),
                orden_secuencia = @orden_secuencia
            WHERE id_fase = @id_fase;
            PRINT 'Fase del torneo modificada exitosamente.';
        END;
 
        -- Baja
        IF @Accion = 'B'
        BEGIN
            DELETE FROM torneo.FASE_TORNEO WHERE id_fase = @id_fase;
            PRINT 'Fase del torneo eliminada exitosamente.';
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
 
--5 Módulo Incidencias del Partido: torneo.sp_PARTIDO_ABM
 
CREATE OR ALTER PROCEDURE torneo.sp_PARTIDO_ABM (@Accion CHAR(1), -- 'A', 'M', 'B'
                                                 @id_fase INT = NULL, -- Clave Primaria Compuesta
                                                 @nro_partido_fase INT = NULL,
                                                 @id_sede INT = NULL,
                                                 @id_seleccion_local INT = NULL,
                                                 @id_seleccion_visitante INT = NULL,
                                                 @fecha_hora_utc DATETIME2 = NULL,
                                                 @fecha_hora_local DATETIME2 = NULL,
                                                 @goles_local INT = NULL,
                                                 @goles_visitante INT = NULL,
                                                 @asistencia_oficial INT = NULL) AS
BEGIN
 
DECLARE @ErroresAcumulados VARCHAR(MAX) =''; --'acumulador de mensajes de error'
 
SET NOCOUNT ON;
 
    -- Validar Acción
    IF @Accion NOT IN ('A', 'M', 'B') OR @Accion IS NULL
        SET @ErroresAcumulados += '- La acción es obligatoria y debe ser A (Alta), M (Modificación) o B (Baja).' + CHAR(13);
 
    -- Validar Clave Compuesta
    IF @id_fase IS NULL OR @id_fase <= 0
        SET @ErroresAcumulados += '- El ID de fase es obligatorio y debe ser un valor positivo.' + CHAR(13);
 
    IF @nro_partido_fase IS NULL OR @nro_partido_fase <= 0
        SET @ErroresAcumulados += '- El número de partido dentro de la fase es obligatorio y debe ser un valor positivo.' + CHAR(13);
 
    -- Validar Existencia
    IF @Accion = 'A' AND EXISTS (
        SELECT id_fase FROM torneo.PARTIDO WHERE id_fase = @id_fase AND nro_partido_fase = @nro_partido_fase
    )
        SET @ErroresAcumulados += '- Ya existe un partido registrado con esa fase y número de partido.' + CHAR(13);
 
    IF @Accion IN ('M', 'B') AND NOT EXISTS (
        SELECT id_fase FROM torneo.PARTIDO WHERE id_fase = @id_fase AND nro_partido_fase = @nro_partido_fase
    )
        SET @ErroresAcumulados += '- El partido especificado no existe.' + CHAR(13);
 
    -- Restricción de Baja: no debe tener goles, tarjetas, alineaciones ni designaciones arbitrales vinculadas
    IF @Accion = 'B' AND EXISTS (
        SELECT id_fase FROM torneo.GOL WHERE id_fase = @id_fase AND nro_partido_fase = @nro_partido_fase
    )
        SET @ErroresAcumulados += '- No se puede eliminar el partido porque tiene goles registrados.' + CHAR(13);
 
    IF @Accion = 'B' AND EXISTS (
        SELECT id_fase FROM torneo.SANCION_TARJETA WHERE id_fase = @id_fase AND nro_partido_fase = @nro_partido_fase
    )
        SET @ErroresAcumulados += '- No se puede eliminar el partido porque tiene tarjetas/sanciones registradas.' + CHAR(13);
 
    IF @Accion = 'B' AND EXISTS (
        SELECT id_fase FROM torneo.ALINEACION_PARTIDO WHERE id_fase = @id_fase AND nro_partido_fase = @nro_partido_fase
    )
        SET @ErroresAcumulados += '- No se puede eliminar el partido porque tiene alineaciones registradas.' + CHAR(13);
 
    IF @Accion = 'B' AND EXISTS (
        SELECT id_fase FROM torneo.DESIGNACION_ARBITRAL WHERE id_fase = @id_fase AND nro_partido_fase = @nro_partido_fase
    )
        SET @ErroresAcumulados += '- No se puede eliminar el partido porque tiene designaciones arbitrales registradas.' + CHAR(13);
 
    -- Validaciones de Claves Foráneas, dominio y negocio para Alta y Modificación
    IF @Accion IN ('A', 'M')
    BEGIN
        IF NOT EXISTS (SELECT id_fase FROM torneo.FASE_TORNEO WHERE id_fase = @id_fase)
            SET @ErroresAcumulados += '- La fase del torneo especificada no existe.' + CHAR(13);
 
        IF @id_sede IS NULL OR @id_sede <= 0
            SET @ErroresAcumulados += '- La sede es obligatoria.' + CHAR(13);
        ELSE IF NOT EXISTS (SELECT id_sede FROM torneo.SEDE WHERE id_sede = @id_sede)
            SET @ErroresAcumulados += '- La sede especificada no existe.' + CHAR(13);
 
        IF @id_seleccion_local IS NULL OR @id_seleccion_local <= 0
            SET @ErroresAcumulados += '- La selección local es obligatoria.' + CHAR(13);
        ELSE IF NOT EXISTS (SELECT id_seleccion FROM torneo.SELECCION WHERE id_seleccion = @id_seleccion_local)
            SET @ErroresAcumulados += '- La selección local especificada no existe.' + CHAR(13);
 
        IF @id_seleccion_visitante IS NULL OR @id_seleccion_visitante <= 0
            SET @ErroresAcumulados += '- La selección visitante es obligatoria.' + CHAR(13);
        ELSE IF NOT EXISTS (SELECT id_seleccion FROM torneo.SELECCION WHERE id_seleccion = @id_seleccion_visitante)
            SET @ErroresAcumulados += '- La selección visitante especificada no existe.' + CHAR(13);
 
        IF @id_seleccion_local IS NOT NULL AND @id_seleccion_visitante IS NOT NULL AND @id_seleccion_local = @id_seleccion_visitante
            SET @ErroresAcumulados += '- Una selección no puede jugar contra sí misma.' + CHAR(13);
 
        IF @fecha_hora_utc IS NULL
            SET @ErroresAcumulados += '- La fecha y hora UTC del partido es obligatoria.' + CHAR(13);
 
        IF @fecha_hora_local IS NULL
            SET @ErroresAcumulados += '- La fecha y hora local del partido es obligatoria.' + CHAR(13);
 
        IF @goles_local IS NOT NULL AND @goles_local < 0
            SET @ErroresAcumulados += '- Los goles del equipo local no pueden ser negativos.' + CHAR(13);
 
        IF @goles_visitante IS NOT NULL AND @goles_visitante < 0
            SET @ErroresAcumulados += '- Los goles del equipo visitante no pueden ser negativos.' + CHAR(13);
 
        IF @asistencia_oficial IS NOT NULL AND @asistencia_oficial < 0
            SET @ErroresAcumulados += '- La asistencia oficial no puede ser negativa.' + CHAR(13);
    END;
 
    -- Control Errores Acumulados
    IF LEN(@ErroresAcumulados) > 0
    BEGIN
        SET @ErroresAcumulados = 'Se encontraron los siguientes errores de validación:'
                                 + CHAR(13) + @ErroresAcumulados;
        THROW 50000, @ErroresAcumulados, 1;
        RETURN;
    END;
 
    BEGIN TRY
        BEGIN TRANSACTION;
 
        -- Alta (goles/asistencia quedan en 0 por defecto si el partido aún no se jugó)
        IF @Accion = 'A'
        BEGIN
            INSERT INTO torneo.PARTIDO (
                id_fase, nro_partido_fase, id_sede, id_seleccion_local, id_seleccion_visitante,
                fecha_hora_utc, fecha_hora_local, goles_local, goles_visitante, asistencia_oficial
            )
            VALUES (
                @id_fase, @nro_partido_fase, @id_sede, @id_seleccion_local, @id_seleccion_visitante,
                @fecha_hora_utc, @fecha_hora_local, ISNULL(@goles_local, 0), ISNULL(@goles_visitante, 0), ISNULL(@asistencia_oficial, 0)
            );
            PRINT 'Partido registrado exitosamente.';
        END;
 
        -- Modificaciones (si no se envía un valor, se conserva el que ya tenía)
        IF @Accion = 'M'
        BEGIN
            UPDATE torneo.PARTIDO
            SET id_sede = @id_sede,
                id_seleccion_local = @id_seleccion_local,
                id_seleccion_visitante = @id_seleccion_visitante,
                fecha_hora_utc = @fecha_hora_utc,
                fecha_hora_local = @fecha_hora_local,
                goles_local = ISNULL(@goles_local, goles_local),
                goles_visitante = ISNULL(@goles_visitante, goles_visitante),
                asistencia_oficial = ISNULL(@asistencia_oficial, asistencia_oficial)
            WHERE id_fase = @id_fase AND nro_partido_fase = @nro_partido_fase;
            PRINT 'Partido modificado exitosamente.';
        END;
 
        -- Baja
        IF @Accion = 'B'
        BEGIN
            DELETE FROM torneo.PARTIDO WHERE id_fase = @id_fase AND nro_partido_fase = @nro_partido_fase;
            PRINT 'Partido eliminado exitosamente.';
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
 
--5 Módulo Incidencias del Partido: torneo.sp_DESIGNACION_ARBITRAL_ABM
 
CREATE OR ALTER PROCEDURE torneo.sp_DESIGNACION_ARBITRAL_ABM (@Accion CHAR(1), -- 'A', 'M', 'B'
                                                               @id_fase INT = NULL, -- Clave Primaria Compuesta
                                                               @nro_partido_fase INT = NULL,
                                                               @nro_doc VARCHAR(20) = NULL,
                                                               @tipo_doc VARCHAR(10) = NULL,
                                                               @id_rol INT = NULL) AS
BEGIN
 
DECLARE @ErroresAcumulados VARCHAR(MAX) =''; --'acumulador de mensajes de error'
 
SET NOCOUNT ON;
 
    -- Validar Acción
    IF @Accion NOT IN ('A', 'M', 'B') OR @Accion IS NULL
        SET @ErroresAcumulados += '- La acción es obligatoria y debe ser A (Alta), M (Modificación) o B (Baja).' + CHAR(13);
 
    -- Validar Clave Compuesta
    IF @id_fase IS NULL OR @id_fase <= 0
        SET @ErroresAcumulados += '- El ID de fase es obligatorio y debe ser un valor positivo.' + CHAR(13);
 
    IF @nro_partido_fase IS NULL OR @nro_partido_fase <= 0
        SET @ErroresAcumulados += '- El número de partido dentro de la fase es obligatorio y debe ser un valor positivo.' + CHAR(13);
 
    IF @tipo_doc IS NULL OR TRIM(@tipo_doc) = ''
        SET @ErroresAcumulados += '- El tipo de documento del árbitro es obligatorio.' + CHAR(13);
    ELSE IF UPPER(TRIM(@tipo_doc)) NOT IN ('DNI', 'PASAPORTE', 'CI', 'LE', 'LC')
        SET @ErroresAcumulados += '- El tipo de documento ingresado no es válido.' + CHAR(13);
 
    IF @nro_doc IS NULL OR TRIM(@nro_doc) = ''
        SET @ErroresAcumulados += '- El número de documento del árbitro es obligatorio.' + CHAR(13);
 
    -- Validar Existencia
    IF @Accion = 'A' AND EXISTS (
        SELECT id_fase FROM torneo.DESIGNACION_ARBITRAL
        WHERE id_fase = @id_fase AND nro_partido_fase = @nro_partido_fase
          AND nro_doc = TRIM(@nro_doc) AND tipo_doc = UPPER(TRIM(@tipo_doc))
    )
        SET @ErroresAcumulados += '- Ya existe una designación arbitral registrada para ese partido y árbitro.' + CHAR(13);
 
    IF @Accion IN ('M', 'B') AND NOT EXISTS (
        SELECT id_fase FROM torneo.DESIGNACION_ARBITRAL
        WHERE id_fase = @id_fase AND nro_partido_fase = @nro_partido_fase
          AND nro_doc = TRIM(@nro_doc) AND tipo_doc = UPPER(TRIM(@tipo_doc))
    )
        SET @ErroresAcumulados += '- La designación arbitral especificada no existe.' + CHAR(13);
 
    -- Validaciones de Claves Foráneas para Alta y Modificación
    IF @Accion IN ('A', 'M')
    BEGIN
        IF NOT EXISTS (
            SELECT id_fase FROM torneo.PARTIDO WHERE id_fase = @id_fase AND nro_partido_fase = @nro_partido_fase
        )
            SET @ErroresAcumulados += '- El partido especificado no existe.' + CHAR(13);
 
        IF NOT EXISTS (
            SELECT nro_doc FROM persona.ARBITRO WHERE nro_doc = TRIM(@nro_doc) AND tipo_doc = UPPER(TRIM(@tipo_doc))
        )
            SET @ErroresAcumulados += '- El árbitro especificado no existe.' + CHAR(13);
 
        IF @id_rol IS NULL OR @id_rol <= 0
            SET @ErroresAcumulados += '- El rol arbitral es obligatorio.' + CHAR(13);
        ELSE IF NOT EXISTS (SELECT id_rol FROM torneo.ROL_ARBITRAL WHERE id_rol = @id_rol)
            SET @ErroresAcumulados += '- El rol arbitral especificado no existe.' + CHAR(13);
    END;
 
    -- Control Errores Acumulados
    IF LEN(@ErroresAcumulados) > 0
    BEGIN
        SET @ErroresAcumulados = 'Se encontraron los siguientes errores de validación:'
                                 + CHAR(13) + @ErroresAcumulados;
        THROW 50000, @ErroresAcumulados, 1;
        RETURN;
    END;
 
    BEGIN TRY
        BEGIN TRANSACTION;
 
        -- Alta
        IF @Accion = 'A'
        BEGIN
            INSERT INTO torneo.DESIGNACION_ARBITRAL (id_fase, nro_partido_fase, nro_doc, tipo_doc, id_rol)
            VALUES (@id_fase, @nro_partido_fase, TRIM(@nro_doc), UPPER(TRIM(@tipo_doc)), @id_rol);
            PRINT 'Designación arbitral registrada exitosamente.';
        END;
 
        -- Modificaciones
        IF @Accion = 'M'
        BEGIN
            UPDATE torneo.DESIGNACION_ARBITRAL
            SET id_rol = @id_rol
            WHERE id_fase = @id_fase AND nro_partido_fase = @nro_partido_fase
              AND nro_doc = TRIM(@nro_doc) AND tipo_doc = UPPER(TRIM(@tipo_doc));
            PRINT 'Designación arbitral modificada exitosamente.';
        END;
 
        -- Baja
        IF @Accion = 'B'
        BEGIN
            DELETE FROM torneo.DESIGNACION_ARBITRAL
            WHERE id_fase = @id_fase AND nro_partido_fase = @nro_partido_fase
              AND nro_doc = TRIM(@nro_doc) AND tipo_doc = UPPER(TRIM(@tipo_doc));
            PRINT 'Designación arbitral eliminada exitosamente.';
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
 
--5 Módulo Incidencias del Partido: torneo.sp_ALINEACION_PARTIDO_ABM
 
CREATE OR ALTER PROCEDURE torneo.sp_ALINEACION_PARTIDO_ABM (@Accion CHAR(1), -- 'A', 'M', 'B'
                                                             @id_fase INT = NULL, -- Clave Primaria Compuesta
                                                             @nro_partido_fase INT = NULL,
                                                             @id_seleccion INT = NULL,
                                                             @esquema_tactico VARCHAR(10) = NULL) AS
BEGIN
 
DECLARE @ErroresAcumulados VARCHAR(MAX) =''; --'acumulador de mensajes de error'
 
SET NOCOUNT ON;
 
    -- Validar Acción
    IF @Accion NOT IN ('A', 'M', 'B') OR @Accion IS NULL
        SET @ErroresAcumulados += '- La acción es obligatoria y debe ser A (Alta), M (Modificación) o B (Baja).' + CHAR(13);
 
    -- Validar Clave Compuesta
    IF @id_fase IS NULL OR @id_fase <= 0
        SET @ErroresAcumulados += '- El ID de fase es obligatorio y debe ser un valor positivo.' + CHAR(13);
 
    IF @nro_partido_fase IS NULL OR @nro_partido_fase <= 0
        SET @ErroresAcumulados += '- El número de partido dentro de la fase es obligatorio y debe ser un valor positivo.' + CHAR(13);
 
    IF @id_seleccion IS NULL OR @id_seleccion <= 0
        SET @ErroresAcumulados += '- La selección es obligatoria y debe ser un valor positivo.' + CHAR(13);
 
    -- Validar Existencia
    IF @Accion = 'A' AND EXISTS (
        SELECT id_fase FROM torneo.ALINEACION_PARTIDO
        WHERE id_fase = @id_fase AND nro_partido_fase = @nro_partido_fase AND id_seleccion = @id_seleccion
    )
        SET @ErroresAcumulados += '- Ya existe una alineación registrada para esa selección en ese partido.' + CHAR(13);
 
    IF @Accion IN ('M', 'B') AND NOT EXISTS (
        SELECT id_fase FROM torneo.ALINEACION_PARTIDO
        WHERE id_fase = @id_fase AND nro_partido_fase = @nro_partido_fase AND id_seleccion = @id_seleccion
    )
        SET @ErroresAcumulados += '- La alineación especificada no existe.' + CHAR(13);
 
    -- Restricción de Baja: no debe tener jugadores cargados
    IF @Accion = 'B' AND EXISTS (
        SELECT id_fase FROM torneo.JUGADOR_ALINEACION
        WHERE id_fase = @id_fase AND nro_partido_fase = @nro_partido_fase AND id_seleccion = @id_seleccion
    )
        SET @ErroresAcumulados += '- No se puede eliminar la alineación porque tiene jugadores cargados.' + CHAR(13);
 
    -- Validaciones de Claves Foráneas y negocio para Alta y Modificación
    IF @Accion IN ('A', 'M')
    BEGIN
        IF NOT EXISTS (
            SELECT id_fase FROM torneo.PARTIDO WHERE id_fase = @id_fase AND nro_partido_fase = @nro_partido_fase
        )
            SET @ErroresAcumulados += '- El partido especificado no existe.' + CHAR(13);
        ELSE IF NOT EXISTS (
            SELECT id_fase FROM torneo.PARTIDO
            WHERE id_fase = @id_fase AND nro_partido_fase = @nro_partido_fase
              AND (id_seleccion_local = @id_seleccion OR id_seleccion_visitante = @id_seleccion)
        )
            SET @ErroresAcumulados += '- La selección especificada no participa en el partido indicado.' + CHAR(13);
 
        IF @esquema_tactico IS NULL OR TRIM(@esquema_tactico) = ''
            SET @ErroresAcumulados += '- El esquema táctico es obligatorio.' + CHAR(13);
    END;
 
    -- Control Errores Acumulados
    IF LEN(@ErroresAcumulados) > 0
    BEGIN
        SET @ErroresAcumulados = 'Se encontraron los siguientes errores de validación:'
                                 + CHAR(13) + @ErroresAcumulados;
        THROW 50000, @ErroresAcumulados, 1;
        RETURN;
    END;
 
    BEGIN TRY
        BEGIN TRANSACTION;
 
        -- Alta
        IF @Accion = 'A'
        BEGIN
            INSERT INTO torneo.ALINEACION_PARTIDO (id_fase, nro_partido_fase, id_seleccion, esquema_tactico)
            VALUES (@id_fase, @nro_partido_fase, @id_seleccion, TRIM(@esquema_tactico));
            PRINT 'Alineación registrada exitosamente.';
        END;
 
        -- Modificaciones
        IF @Accion = 'M'
        BEGIN
            UPDATE torneo.ALINEACION_PARTIDO
            SET esquema_tactico = TRIM(@esquema_tactico)
            WHERE id_fase = @id_fase AND nro_partido_fase = @nro_partido_fase AND id_seleccion = @id_seleccion;
            PRINT 'Alineación modificada exitosamente.';
        END;
 
        -- Baja
        IF @Accion = 'B'
        BEGIN
            DELETE FROM torneo.ALINEACION_PARTIDO
            WHERE id_fase = @id_fase AND nro_partido_fase = @nro_partido_fase AND id_seleccion = @id_seleccion;
            PRINT 'Alineación eliminada exitosamente.';
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
 
--5 Módulo Incidencias del Partido: torneo.sp_JUGADOR_ALINEACION_ABM
 
CREATE OR ALTER PROCEDURE torneo.sp_JUGADOR_ALINEACION_ABM (@Accion CHAR(1), -- 'A', 'M', 'B'
                                                            @id_fase INT = NULL, -- Clave Primaria Compuesta
                                                            @nro_partido_fase INT = NULL,
                                                            @id_seleccion INT = NULL,
                                                            @dorsal_oficial INT = NULL,
                                                            @es_titular BIT = NULL,
                                                            @posicion_campo VARCHAR(30) = NULL,
                                                            @minuto_ingreso INT = NULL,
                                                            @minuto_ingreso_extra INT = NULL,
                                                            @minuto_salida INT = NULL,
                                                            @minuto_salida_extra INT = NULL) AS
BEGIN
 
DECLARE @ErroresAcumulados VARCHAR(MAX) =''; --'acumulador de mensajes de error'
 
SET NOCOUNT ON;
 
    -- Validar Acción
    IF @Accion NOT IN ('A', 'M', 'B') OR @Accion IS NULL
        SET @ErroresAcumulados += '- La acción es obligatoria y debe ser A (Alta), M (Modificación) o B (Baja).' + CHAR(13);
 
    -- Validar Clave Compuesta
    IF @id_fase IS NULL OR @id_fase <= 0
        SET @ErroresAcumulados += '- El ID de fase es obligatorio y debe ser un valor positivo.' + CHAR(13);
 
    IF @nro_partido_fase IS NULL OR @nro_partido_fase <= 0
        SET @ErroresAcumulados += '- El número de partido dentro de la fase es obligatorio y debe ser un valor positivo.' + CHAR(13);
 
    IF @id_seleccion IS NULL OR @id_seleccion <= 0
        SET @ErroresAcumulados += '- La selección es obligatoria y debe ser un valor positivo.' + CHAR(13);
 
    IF @dorsal_oficial IS NULL OR @dorsal_oficial <= 0
        SET @ErroresAcumulados += '- El dorsal oficial es obligatorio y debe ser un valor positivo.' + CHAR(13);
 
    -- Validar Existencia
    IF @Accion = 'A' AND EXISTS (
        SELECT id_fase FROM torneo.JUGADOR_ALINEACION
        WHERE id_fase = @id_fase AND nro_partido_fase = @nro_partido_fase
          AND id_seleccion = @id_seleccion AND dorsal_oficial = @dorsal_oficial
    )
        SET @ErroresAcumulados += '- Ya existe un registro de alineación para ese jugador en ese partido.' + CHAR(13);
 
    IF @Accion IN ('M', 'B') AND NOT EXISTS (
        SELECT id_fase FROM torneo.JUGADOR_ALINEACION
        WHERE id_fase = @id_fase AND nro_partido_fase = @nro_partido_fase
          AND id_seleccion = @id_seleccion AND dorsal_oficial = @dorsal_oficial
    )
        SET @ErroresAcumulados += '- El jugador en la alineación especificado no existe.' + CHAR(13);
 
    -- Validaciones de Claves Foráneas y negocio para Alta y Modificación
    IF @Accion IN ('A', 'M')
    BEGIN
        IF NOT EXISTS (
            SELECT id_fase FROM torneo.ALINEACION_PARTIDO
            WHERE id_fase = @id_fase AND nro_partido_fase = @nro_partido_fase AND id_seleccion = @id_seleccion
        )
            SET @ErroresAcumulados += '- La alineación especificada no existe.' + CHAR(13);
 
        IF NOT EXISTS (
            SELECT id_seleccion FROM torneo.CONVOCATORIA
            WHERE id_seleccion = @id_seleccion AND dorsal_oficial = @dorsal_oficial
        )
            SET @ErroresAcumulados += '- El jugador no se encuentra convocado con ese dorsal para esa selección.' + CHAR(13);
 
        IF @es_titular IS NULL
            SET @ErroresAcumulados += '- El indicador de titularidad (es_titular) es obligatorio.' + CHAR(13);
 
        IF @posicion_campo IS NULL OR TRIM(@posicion_campo) = ''
            SET @ErroresAcumulados += '- La posición de campo es obligatoria.' + CHAR(13);
 
        IF @minuto_ingreso IS NOT NULL OR @minuto_ingreso < 0
            SET @ErroresAcumulados += '- El minuto de ingreso debe ser mayor o igual a 0.' + CHAR(13);
 
        IF @minuto_ingreso_extra IS NOT NULL AND @minuto_ingreso_extra <= 0
            SET @ErroresAcumulados += '- El minuto de ingreso en tiempo extra debe ser mayor a 0.' + CHAR(13);
 
        IF @minuto_salida IS NOT NULL AND @minuto_ingreso IS NOT NULL AND @minuto_salida < @minuto_ingreso
            SET @ErroresAcumulados += '- El minuto de salida no puede ser menor al minuto de ingreso.' + CHAR(13);
 
        IF @minuto_salida_extra IS NOT NULL AND @minuto_salida_extra <= 0
            SET @ErroresAcumulados += '- El minuto de salida en tiempo extra debe ser mayor a 0.' + CHAR(13);
    END;
 
    -- Control Errores Acumulados
    IF LEN(@ErroresAcumulados) > 0
    BEGIN
        SET @ErroresAcumulados = 'Se encontraron los siguientes errores de validación:'
                                 + CHAR(13) + @ErroresAcumulados;
        THROW 50000, @ErroresAcumulados, 1;
        RETURN;
    END;
 
    BEGIN TRY
        BEGIN TRANSACTION;
 
        -- Alta
        IF @Accion = 'A'
        BEGIN
            INSERT INTO torneo.JUGADOR_ALINEACION (
                id_fase, nro_partido_fase, id_seleccion, dorsal_oficial, es_titular,
                posicion_campo, minuto_ingreso, minuto_ingreso_extra, minuto_salida, minuto_salida_extra
            )
            VALUES (
                @id_fase, @nro_partido_fase, @id_seleccion, @dorsal_oficial, @es_titular,
                TRIM(@posicion_campo), ISNULL(@minuto_ingreso, 0), @minuto_ingreso_extra, @minuto_salida, @minuto_salida_extra
            );
            PRINT 'Jugador en alineación registrado exitosamente.';
        END;
 
        -- Modificaciones
        IF @Accion = 'M'
        BEGIN
            UPDATE torneo.JUGADOR_ALINEACION
            SET es_titular = @es_titular,
                posicion_campo = TRIM(@posicion_campo),
                minuto_ingreso = ISNULL(@minuto_ingreso, minuto_ingreso),
                minuto_ingreso_extra = @minuto_ingreso_extra,
                minuto_salida = @minuto_salida,
                minuto_salida_extra = @minuto_salida_extra
            WHERE id_fase = @id_fase AND nro_partido_fase = @nro_partido_fase
              AND id_seleccion = @id_seleccion AND dorsal_oficial = @dorsal_oficial;
            PRINT 'Jugador en alineación modificado exitosamente.';
        END;
 
        -- Baja
        IF @Accion = 'B'
        BEGIN
            DELETE FROM torneo.JUGADOR_ALINEACION
            WHERE id_fase = @id_fase AND nro_partido_fase = @nro_partido_fase
              AND id_seleccion = @id_seleccion AND dorsal_oficial = @dorsal_oficial;
            PRINT 'Jugador en alineación eliminado exitosamente.';
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
 
--5 Módulo Incidencias del Partido: torneo.sp_SUSTITUCION_ABM
 
CREATE OR ALTER PROCEDURE torneo.sp_SUSTITUCION_ABM (@Accion CHAR(1), -- 'A', 'M', 'B'
                                                     @id_fase INT = NULL, -- Clave Primaria Compuesta
                                                     @nro_partido_fase INT = NULL,
                                                     @id_secuencia INT = NULL,
                                                     @id_seleccion INT = NULL,
                                                     @dorsal_sale INT = NULL,
                                                     @dorsal_entra INT = NULL,
                                                     @minuto_cambio INT = NULL,
                                                     @minuto_cambio_extra INT = NULL,
                                                     @ventana_numero INT = NULL) AS
BEGIN
 
DECLARE @ErroresAcumulados VARCHAR(MAX) =''; --'acumulador de mensajes de error'
 
SET NOCOUNT ON;
 
    -- Validar Acción
    IF @Accion NOT IN ('A', 'M', 'B') OR @Accion IS NULL
        SET @ErroresAcumulados += '- La acción es obligatoria y debe ser A (Alta), M (Modificación) o B (Baja).' + CHAR(13);
 
    -- Validar Clave Compuesta
    IF @id_fase IS NULL OR @id_fase <= 0
        SET @ErroresAcumulados += '- El ID de fase es obligatorio y debe ser un valor positivo.' + CHAR(13);
 
    IF @nro_partido_fase IS NULL OR @nro_partido_fase <= 0
        SET @ErroresAcumulados += '- El número de partido dentro de la fase es obligatorio y debe ser un valor positivo.' + CHAR(13);
 
    IF @id_secuencia IS NULL OR @id_secuencia <= 0
        SET @ErroresAcumulados += '- El número de secuencia de la sustitución es obligatorio y debe ser un valor positivo.' + CHAR(13);
 
    -- Validar Existencia
    IF @Accion = 'A' AND EXISTS (
        SELECT id_fase FROM torneo.SUSTITUCION
        WHERE id_fase = @id_fase AND nro_partido_fase = @nro_partido_fase AND id_secuencia = @id_secuencia
    )
        SET @ErroresAcumulados += '- Ya existe una sustitución registrada con esa secuencia para ese partido.' + CHAR(13);
 
    IF @Accion IN ('M', 'B') AND NOT EXISTS (
        SELECT id_fase FROM torneo.SUSTITUCION
        WHERE id_fase = @id_fase AND nro_partido_fase = @nro_partido_fase AND id_secuencia = @id_secuencia
    )
        SET @ErroresAcumulados += '- La sustitución especificada no existe.' + CHAR(13);
 
    -- Validaciones de Claves Foráneas, dominio y negocio para Alta y Modificación
    IF @Accion IN ('A', 'M')
    BEGIN
        IF NOT EXISTS (
            SELECT id_fase FROM torneo.PARTIDO WHERE id_fase = @id_fase AND nro_partido_fase = @nro_partido_fase
        )
            SET @ErroresAcumulados += '- El partido especificado no existe.' + CHAR(13);
 
        IF @id_seleccion IS NULL OR @id_seleccion <= 0
            SET @ErroresAcumulados += '- La selección es obligatoria y debe ser un valor positivo.' + CHAR(13);
        ELSE IF NOT EXISTS (SELECT id_seleccion FROM torneo.SELECCION WHERE id_seleccion = @id_seleccion)
            SET @ErroresAcumulados += '- La selección especificada no existe.' + CHAR(13);
        ELSE IF NOT EXISTS (                                                              -- ← nuevo
            SELECT id_fase FROM torneo.PARTIDO
            WHERE id_fase = @id_fase AND nro_partido_fase = @nro_partido_fase
              AND (id_seleccion_local = @id_seleccion OR id_seleccion_visitante = @id_seleccion)
        )
            SET @ErroresAcumulados += '- La selección especificada no participó en el partido indicado.' + CHAR(13);

        IF @dorsal_sale IS NULL
            SET @ErroresAcumulados += '- El dorsal del jugador que sale es obligatorio.' + CHAR(13);
        ELSE IF @id_seleccion IS NOT NULL AND NOT EXISTS (
            SELECT id_seleccion FROM torneo.CONVOCATORIA WHERE id_seleccion = @id_seleccion AND dorsal_oficial = @dorsal_sale
        )
            SET @ErroresAcumulados += '- El dorsal del jugador que sale no se encuentra convocado en esa selección.' + CHAR(13);

        IF @dorsal_entra IS NULL
            SET @ErroresAcumulados += '- El dorsal del jugador que entra es obligatorio.' + CHAR(13);
        ELSE IF @id_seleccion IS NOT NULL AND NOT EXISTS (
            SELECT id_seleccion FROM torneo.CONVOCATORIA WHERE id_seleccion = @id_seleccion AND dorsal_oficial = @dorsal_entra
        )
            SET @ErroresAcumulados += '- El dorsal del jugador que entra no se encuentra convocado en esa selección.' + CHAR(13);
 
        IF @dorsal_sale IS NOT NULL AND @dorsal_entra IS NOT NULL AND @dorsal_sale = @dorsal_entra
            SET @ErroresAcumulados += '- El dorsal del jugador que sale no puede ser igual al del jugador que entra.' + CHAR(13);
 
        IF @minuto_cambio IS NULL OR @minuto_cambio < 1 OR @minuto_cambio > 120
            SET @ErroresAcumulados += '- El minuto del cambio debe estar entre 1 y 120.' + CHAR(13);
 
        IF @minuto_cambio_extra IS NOT NULL AND @minuto_cambio_extra <= 0
            SET @ErroresAcumulados += '- El minuto de cambio en tiempo extra debe ser mayor a 0.' + CHAR(13);
 
        IF @ventana_numero IS NULL OR @ventana_numero < 1 OR @ventana_numero > 4
            SET @ErroresAcumulados += '- El número de ventana de cambio debe estar entre 1 y 4.' + CHAR(13);
    
         -- Restricción Disciplinaria. No puede salir ni entrar un jugador ya expulsado antes de ese minuto
        IF @dorsal_sale IS NOT NULL AND @minuto_cambio IS NOT NULL AND EXISTS (
            SELECT id_tarjeta FROM torneo.SANCION_TARJETA
            WHERE id_fase = @id_fase AND nro_partido_fase = @nro_partido_fase
              AND id_seleccion = @id_seleccion AND dorsal_sancionado = @dorsal_sale
              AND tipo_tarjeta IN ('ROJA_DIRECTA', 'DOBLE_AMARILLA')
              AND (minuto_sancion < @minuto_cambio
                   OR (minuto_sancion = @minuto_cambio AND ISNULL(minuto_sancion_extra, 0) <= ISNULL(@minuto_cambio_extra, 0)))
        )
            SET @ErroresAcumulados += '- El jugador que sale ya había sido expulsado (tarjeta roja) antes de ese minuto del partido.' + CHAR(13);
 
        IF @dorsal_entra IS NOT NULL AND @minuto_cambio IS NOT NULL AND EXISTS (
            SELECT id_tarjeta FROM torneo.SANCION_TARJETA
            WHERE id_fase = @id_fase AND nro_partido_fase = @nro_partido_fase
              AND id_seleccion = @id_seleccion AND dorsal_sancionado = @dorsal_entra
              AND tipo_tarjeta IN ('ROJA_DIRECTA', 'DOBLE_AMARILLA')
              AND (minuto_sancion < @minuto_cambio
                   OR (minuto_sancion = @minuto_cambio AND ISNULL(minuto_sancion_extra, 0) <= ISNULL(@minuto_cambio_extra, 0)))
        )
            SET @ErroresAcumulados += '- El jugador que entra ya había sido expulsado (tarjeta roja) antes de ese minuto del partido.' + CHAR(13);
    END;
 
    -- Control Errores Acumulados
    IF LEN(@ErroresAcumulados) > 0
    BEGIN
        SET @ErroresAcumulados = 'Se encontraron los siguientes errores de validación:'
                                 + CHAR(13) + @ErroresAcumulados;
        THROW 50000, @ErroresAcumulados, 1;
        RETURN;
    END;
 
    BEGIN TRY
        BEGIN TRANSACTION;
 
        -- Alta
        IF @Accion = 'A'
        BEGIN
            INSERT INTO torneo.SUSTITUCION (
                id_fase, nro_partido_fase, id_secuencia, id_seleccion, dorsal_sale, dorsal_entra,
                minuto_cambio, minuto_cambio_extra, ventana_numero
            )
            VALUES (
                @id_fase, @nro_partido_fase, @id_secuencia, @id_seleccion, @dorsal_sale, @dorsal_entra,
                @minuto_cambio, @minuto_cambio_extra, @ventana_numero
            );
            PRINT 'Sustitución registrada exitosamente.';
        END;
 
        -- Modificaciones
        IF @Accion = 'M'
        BEGIN
            UPDATE torneo.SUSTITUCION
            SET id_seleccion = @id_seleccion,
                dorsal_sale = @dorsal_sale,
                dorsal_entra = @dorsal_entra,
                minuto_cambio = @minuto_cambio,
                minuto_cambio_extra = @minuto_cambio_extra,
                ventana_numero = @ventana_numero
            WHERE id_fase = @id_fase AND nro_partido_fase = @nro_partido_fase AND id_secuencia = @id_secuencia;
            PRINT 'Sustitución modificada exitosamente.';
        END;
 
        -- Baja
        IF @Accion = 'B'
        BEGIN
            DELETE FROM torneo.SUSTITUCION
            WHERE id_fase = @id_fase AND nro_partido_fase = @nro_partido_fase AND id_secuencia = @id_secuencia;
            PRINT 'Sustitución eliminada exitosamente.';
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
 
--5 Módulo Incidencias del Partido: torneo.sp_GOL_ABM
 
CREATE OR ALTER PROCEDURE torneo.sp_GOL_ABM (@Accion CHAR(1), -- 'A', 'M', 'B'
                                             @id_fase INT = NULL, -- Clave Primaria Compuesta
                                             @nro_partido_fase INT = NULL,
                                             @id_gol INT = NULL,
                                             @minuto_gol INT = NULL,
                                             @minuto_gol_extra INT = NULL,
                                             @tipo_gol VARCHAR(20) = NULL,
                                             @id_seleccion INT = NULL,
                                             @dorsal_autor INT = NULL,
                                             @dorsal_asistente INT = NULL) AS
BEGIN
 
DECLARE @ErroresAcumulados VARCHAR(MAX) =''; --'acumulador de mensajes de error'
 
SET NOCOUNT ON;
 
    -- Validar Acción
    IF @Accion NOT IN ('A', 'M', 'B') OR @Accion IS NULL
        SET @ErroresAcumulados += '- La acción es obligatoria y debe ser A (Alta), M (Modificación) o B (Baja).' + CHAR(13);
 
    -- Validar Clave Compuesta
    IF @id_fase IS NULL OR @id_fase <= 0
        SET @ErroresAcumulados += '- El ID de fase es obligatorio y debe ser un valor positivo.' + CHAR(13);
 
    IF @nro_partido_fase IS NULL OR @nro_partido_fase <= 0
        SET @ErroresAcumulados += '- El número de partido dentro de la fase es obligatorio y debe ser un valor positivo.' + CHAR(13);
 
    IF @id_gol IS NULL OR @id_gol <= 0
        SET @ErroresAcumulados += '- El ID de gol es obligatorio y debe ser un valor positivo.' + CHAR(13);
 
    -- Validar Existencia
    IF @Accion = 'A' AND EXISTS (
        SELECT id_fase FROM torneo.GOL
        WHERE id_fase = @id_fase AND nro_partido_fase = @nro_partido_fase AND id_gol = @id_gol
    )
        SET @ErroresAcumulados += '- Ya existe un gol registrado con ese ID para ese partido.' + CHAR(13);
 
    IF @Accion IN ('M', 'B') AND NOT EXISTS (
        SELECT id_fase FROM torneo.GOL
        WHERE id_fase = @id_fase AND nro_partido_fase = @nro_partido_fase AND id_gol = @id_gol
    )
        SET @ErroresAcumulados += '- El gol especificado no existe.' + CHAR(13);
 
    -- Validaciones de Claves Foráneas, dominio y negocio para Alta y Modificación
    IF @Accion IN ('A', 'M')
    BEGIN
        IF NOT EXISTS (
            SELECT id_fase FROM torneo.PARTIDO WHERE id_fase = @id_fase AND nro_partido_fase = @nro_partido_fase
        )
            SET @ErroresAcumulados += '- El partido especificado no existe.' + CHAR(13);
 
        IF @id_seleccion IS NULL OR @id_seleccion <= 0
            SET @ErroresAcumulados += '- La selección es obligatoria y debe ser un valor positivo.' + CHAR(13);
        ELSE IF NOT EXISTS (SELECT id_seleccion FROM torneo.SELECCION WHERE id_seleccion = @id_seleccion)
            SET @ErroresAcumulados += '- La selección especificada no existe.' + CHAR(13);
        ELSE IF NOT EXISTS (
            SELECT id_fase FROM torneo.PARTIDO
            WHERE id_fase = @id_fase AND nro_partido_fase = @nro_partido_fase
              AND (id_seleccion_local = @id_seleccion OR id_seleccion_visitante = @id_seleccion)
        )
            SET @ErroresAcumulados += '- La selección especificada no participó en el partido indicado.' + CHAR(13);

        IF @dorsal_autor IS NULL
            SET @ErroresAcumulados += '- El dorsal del autor del gol es obligatorio.' + CHAR(13);
        ELSE IF @id_seleccion IS NOT NULL AND NOT EXISTS (
            SELECT id_seleccion FROM torneo.CONVOCATORIA WHERE id_seleccion = @id_seleccion AND dorsal_oficial = @dorsal_autor
        )
            SET @ErroresAcumulados += '- El dorsal del autor no se encuentra convocado en esa selección.' + CHAR(13);
 
        IF @dorsal_asistente IS NOT NULL
        BEGIN
            IF @id_seleccion IS NOT NULL AND NOT EXISTS (
                SELECT id_seleccion FROM torneo.CONVOCATORIA WHERE id_seleccion = @id_seleccion AND dorsal_oficial = @dorsal_asistente
            )
                SET @ErroresAcumulados += '- El dorsal del asistente no se encuentra convocado en esa selección.' + CHAR(13);
 
            IF @dorsal_autor IS NOT NULL AND @dorsal_autor = @dorsal_asistente
                SET @ErroresAcumulados += '- El dorsal del autor no puede ser igual al del asistente.' + CHAR(13);
        END;
 
        IF @minuto_gol IS NULL OR @minuto_gol < 1 OR @minuto_gol > 120
            SET @ErroresAcumulados += '- El minuto del gol debe estar entre 1 y 120.' + CHAR(13);
 
        IF @minuto_gol_extra IS NOT NULL AND @minuto_gol_extra <= 0
            SET @ErroresAcumulados += '- El minuto de gol en tiempo extra debe ser mayor a 0.' + CHAR(13);
 
        IF @tipo_gol IS NULL OR TRIM(@tipo_gol) = ''
            SET @ErroresAcumulados += '- El tipo de gol es obligatorio.' + CHAR(13);
        ELSE IF UPPER(TRIM(@tipo_gol)) NOT IN ('JUGADA', 'CABEZA', 'PENAL', 'TIRO_LIBRE', 'AUTOGOL')
            SET @ErroresAcumulados += '- El tipo de gol no es válido (Debe ser JUGADA, CABEZA, PENAL, TIRO_LIBRE o AUTOGOL).' + CHAR(13);
    
        -- Restricción Disciplinaria. No puede convertir ni asistir un jugador ya expulsado antes de ese minuto
        IF @dorsal_autor IS NOT NULL AND @minuto_gol IS NOT NULL AND EXISTS (
            SELECT id_tarjeta FROM torneo.SANCION_TARJETA
            WHERE id_fase = @id_fase AND nro_partido_fase = @nro_partido_fase
              AND id_seleccion = @id_seleccion AND dorsal_sancionado = @dorsal_autor
              AND tipo_tarjeta IN ('ROJA_DIRECTA', 'DOBLE_AMARILLA')
              AND (minuto_sancion < @minuto_gol
                   OR (minuto_sancion = @minuto_gol AND ISNULL(minuto_sancion_extra, 0) <= ISNULL(@minuto_gol_extra, 0)))
        )
            SET @ErroresAcumulados += '- El autor del gol ya había sido expulsado (tarjeta roja) antes de ese minuto del partido.' + CHAR(13);
 
        IF @dorsal_asistente IS NOT NULL AND @minuto_gol IS NOT NULL AND EXISTS (
            SELECT id_tarjeta FROM torneo.SANCION_TARJETA
            WHERE id_fase = @id_fase AND nro_partido_fase = @nro_partido_fase
              AND id_seleccion = @id_seleccion AND dorsal_sancionado = @dorsal_asistente
              AND tipo_tarjeta IN ('ROJA_DIRECTA', 'DOBLE_AMARILLA')
              AND (minuto_sancion < @minuto_gol
                   OR (minuto_sancion = @minuto_gol AND ISNULL(minuto_sancion_extra, 0) <= ISNULL(@minuto_gol_extra, 0)))
        )
            SET @ErroresAcumulados += '- El asistente ya había sido expulsado (tarjeta roja) antes de ese minuto del partido.' + CHAR(13);
    
    END;
 
    -- Control Errores Acumulados
    IF LEN(@ErroresAcumulados) > 0
    BEGIN
        SET @ErroresAcumulados = 'Se encontraron los siguientes errores de validación:'
                                 + CHAR(13) + @ErroresAcumulados;
        THROW 50000, @ErroresAcumulados, 1;
        RETURN;
    END;
 
    BEGIN TRY
        BEGIN TRANSACTION;
 
        -- Alta
        IF @Accion = 'A'
        BEGIN
            INSERT INTO torneo.GOL (
                id_fase, nro_partido_fase, id_gol, minuto_gol, minuto_gol_extra, tipo_gol,
                id_seleccion, dorsal_autor, dorsal_asistente
            )
            VALUES (
                @id_fase, @nro_partido_fase, @id_gol, @minuto_gol, @minuto_gol_extra, UPPER(TRIM(@tipo_gol)),
                @id_seleccion, @dorsal_autor, @dorsal_asistente
            );
            PRINT 'Gol registrado exitosamente.';
        END;
 
        -- Modificaciones
        IF @Accion = 'M'
        BEGIN
            UPDATE torneo.GOL
            SET minuto_gol = @minuto_gol,
                minuto_gol_extra = @minuto_gol_extra,
                tipo_gol = UPPER(TRIM(@tipo_gol)),
                id_seleccion = @id_seleccion,
                dorsal_autor = @dorsal_autor,
                dorsal_asistente = @dorsal_asistente
            WHERE id_fase = @id_fase AND nro_partido_fase = @nro_partido_fase AND id_gol = @id_gol;
            PRINT 'Gol modificado exitosamente.';
        END;
 
        -- Baja
        IF @Accion = 'B'
        BEGIN
            DELETE FROM torneo.GOL
            WHERE id_fase = @id_fase AND nro_partido_fase = @nro_partido_fase AND id_gol = @id_gol;
            PRINT 'Gol eliminado exitosamente.';
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
 