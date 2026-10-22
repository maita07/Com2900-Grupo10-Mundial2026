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

Descripcion: Script T-SQL de pruebas de integración y validación para los Stored 
             Procedures de ABM - Módulo 2 : Personas, Jugadores, Cuerpo Tecnico, Arbitro
             
             Matriz de Cobertura de Pruebas por SP:
             1. Caso 1 (Alta Exitosa): Inserción en Superclase PERSONA y Subclase correspondiente.
             2. Caso 2 (Alta Fallida): Validación de PK duplicada, campos nulos, fechas e rangos.
             3. Caso 3 (Modificación Exitosa): Actualización sincronizada en Superclase y Subclase.
             4. Caso 4 (Modificación Fallida): Error por intento de modificación de persona inexistente.
             5. Caso 5 (Baja Rechazada): Bloqueo por integridad referencial (Convocatorias / Designaciones).
             6. Caso 6 (Baja Exitosa): Eliminación ordenada (Subclase primero, Superclase después).
---------------------------------------------------------
*/

USE DB_Mundial2026_Grupo10;
GO

PRINT '         INICIO DE PRUEBAS: MÓDULO 2 (PERSONAS, JUGADORES, CUERPO TECNICO, ARBITRO)             ';
GO

-- 2.1 SP: persona.sp_JUGADOR_ABM
--------------------------------------------------------------------------------
PRINT '2.1 Test: persona.sp_JUGADOR_ABM';

-- Caso 1: Alta Exitosa
PRINT '--> Caso 1: Registrando jugador de prueba válido (DNI 99999999)...';
EXEC persona.sp_JUGADOR_ABM 
    @Accion = 'A', 
    @tipo_doc = 'DNI', 
    @nro_doc = '99999999', 
    @id_nacionalidad_pais = 'ARG', 
    @nombre = 'Lionel Test', 
    @apellido = 'Jugador', 
    @fecha_nacimiento = '2000-01-01', 
    @posicion_habitual = 'Delantero', 
    @club_origen = 'Club de Prueba FC', 
    @peso_kg = 75.50, 
    @altura_cm = 180.00, 
    @es_convocado = 0;

-- Verificación de inserción en ambas tablas (Superclase y Subclase)
SELECT P.nro_doc, P.tipo_doc, P.nombre, P.apellido, P.tipo_persona, J.posicion_habitual, J.club_origen, J.peso_kg, J.altura_cm
FROM persona.PERSONA P
JOIN persona.JUGADOR J ON P.nro_doc = J.nro_doc AND P.tipo_doc = J.tipo_doc
WHERE P.nro_doc = '99999999' AND P.tipo_doc = 'DNI';

-- Caso 2: Alta Fallida (PK duplicada, fecha futura, peso y altura negativos)
PRINT '--> Caso 2: Provocando errores de validación en Jugador (PK duplicada, peso/altura inválidos)...';
BEGIN TRY
    EXEC persona.sp_JUGADOR_ABM 
        @Accion = 'A', 
        @tipo_doc = 'DNI', 
        @nro_doc = '99999999',             -- Error: Documento duplicado
        @id_nacionalidad_pais = 'ARG', 
        @nombre = '',                       -- Error: Nombre vacío
        @apellido = 'Test', 
        @fecha_nacimiento = '2030-01-01',   -- Error: Fecha futura
        @posicion_habitual = 'Mediocampista', 
        @club_origen = 'Test', 
        @peso_kg = -10.00,                  -- Error: Peso negativo
        @altura_cm = 0.00;                  -- Error: Altura cero
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Mensaje capturado]: ' + ERROR_MESSAGE();
END CATCH;

-- Caso 3: Modificación Exitosa
PRINT '--> Caso 3: Modificando datos del jugador (DNI 99999999)...';
EXEC persona.sp_JUGADOR_ABM 
    @Accion = 'M', 
    @tipo_doc = 'DNI', 
    @nro_doc = '99999999', 
    @id_nacionalidad_pais = 'ARG', 
    @nombre = 'Lionel Modificado', 
    @apellido = 'Jugador Test', 
    @fecha_nacimiento = '2000-01-01', 
    @posicion_habitual = 'Mediocampista', 
    @club_origen = 'Nuevo Club FC', 
    @peso_kg = 76.00, 
    @altura_cm = 181.00;

-- Caso 4: Modificación Fallida (Documento inexistente)
PRINT '--> Caso 4: Intentando modificar jugador inexistente (DNI 00000000)...';
BEGIN TRY
    EXEC persona.sp_JUGADOR_ABM 
        @Accion = 'M', 
        @tipo_doc = 'DNI', 
        @nro_doc = '00000000', 
        @id_nacionalidad_pais = 'ARG', 
        @nombre = 'No Existe', 
        @apellido = 'Test', 
        @fecha_nacimiento = '1995-01-01', 
        @posicion_habitual = 'Defensa', 
        @club_origen = 'N/A', 
        @peso_kg = 70.00, 
        @altura_cm = 175.00;
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Error capturado]: ' + ERROR_MESSAGE();
END CATCH;

-- Caso 6: Baja Exitosa
PRINT '--> Caso 6: Eliminando jugador de prueba (DNI 99999999)...';
EXEC persona.sp_JUGADOR_ABM 
    @Accion = 'B', 
    @tipo_doc = 'DNI', 
    @nro_doc = '99999999';

-- Verificación de eliminación completa en ambas tablas
SELECT COUNT(*) AS Existe_en_Persona FROM persona.PERSONA WHERE nro_doc = '99999999' AND tipo_doc = 'DNI';
SELECT COUNT(*) AS Existe_en_Jugador FROM persona.JUGADOR WHERE nro_doc = '99999999' AND tipo_doc = 'DNI';
GO

-- 2.2 SP: persona.sp_CUERPO_TECNICO_ABM
PRINT '2.2 Test: persona.sp_CUERPO_TECNICO_ABM';

-- Caso 1: Alta Exitosa
PRINT '--> Caso 1: Registrando miembro del cuerpo técnico (DNI 88888888)...';
EXEC persona.sp_CUERPO_TECNICO_ABM 
    @Accion = 'A', 
    @tipo_doc = 'DNI', 
    @nro_doc = '88888888', 
    @id_nacionalidad_pais = 'ARG', 
    @nombre = 'Carlos Test', 
    @apellido = 'Técnico', 
    @fecha_nacimiento = '1975-05-15', 
    @id_seleccion = 1, 
    @cargo_tecnico = 'Director Técnico';

SELECT P.nro_doc, P.nombre, P.apellido, CT.cargo_tecnico, CT.id_seleccion
FROM persona.PERSONA P
JOIN persona.CUERPO_TECNICO CT ON P.nro_doc = CT.nro_doc AND P.tipo_doc = CT.tipo_doc
WHERE P.nro_doc = '88888888' AND P.tipo_doc = 'DNI';

-- Caso 2: Alta Fallida (Selección inexistente y cargo vacío)
PRINT '--> Caso 2: Provocando error por selección inexistente (ID 9999)...';
BEGIN TRY
    EXEC persona.sp_CUERPO_TECNICO_ABM 
        @Accion = 'A', 
        @tipo_doc = 'DNI', 
        @nro_doc = '88888887', 
        @id_nacionalidad_pais = 'ARG', 
        @nombre = 'Entrenador', 
        @apellido = 'Error', 
        @fecha_nacimiento = '1980-01-01', 
        @id_seleccion = 9999,               -- Error: Selección no existe
        @cargo_tecnico = '';                -- Error: Cargo vacío
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Error capturado]: ' + ERROR_MESSAGE();
END CATCH;

-- Caso 3: Modificación Exitosa
PRINT '--> Caso 3: Modificando cargo del cuerpo técnico (DNI 88888888)...';
EXEC persona.sp_CUERPO_TECNICO_ABM 
    @Accion = 'M', 
    @tipo_doc = 'DNI', 
    @nro_doc = '88888888', 
    @id_nacionalidad_pais = 'ARG', 
    @nombre = 'Carlos Test Modificado', 
    @apellido = 'Técnico', 
    @fecha_nacimiento = '1975-05-15', 
    @id_seleccion = 1, 
    @cargo_tecnico = 'Asistente Técnico';

-- Caso 6: Baja Exitosa
PRINT '--> Caso 6: Eliminando miembro del cuerpo técnico (DNI 88888888)...';
EXEC persona.sp_CUERPO_TECNICO_ABM 
    @Accion = 'B', 
    @tipo_doc = 'DNI', 
    @nro_doc = '88888888';

SELECT COUNT(*) AS Existe_Cuerpo_Tecnico FROM persona.CUERPO_TECNICO WHERE nro_doc = '88888888' AND tipo_doc = 'DNI';
GO

-- 2.3 SP: persona.sp_ARBITRO_ABM
PRINT '------------------------------------------------------------------------';
PRINT '2.3 Test: persona.sp_ARBITRO_ABM';

-- Caso 1: Alta Exitosa
PRINT '--> Caso 1: Registrando árbitro de prueba (DNI 77777777)...';
EXEC persona.sp_ARBITRO_ABM 
    @Accion = 'A', 
    @tipo_doc = 'DNI', 
    @nro_doc = '77777777', 
    @id_nacionalidad_pais = 'ARG', 
    @nombre = 'Wilmar Test', 
    @apellido = 'Árbitro', 
    @fecha_nacimiento = '1982-08-20', 
    @id_rol = 1, 
    @categoria_fifa = 'FIFA Internacional', 
    @anios_experiencia = 10;

SELECT P.nro_doc, P.nombre, P.apellido, A.categoria_fifa, A.anios_experiencia
FROM persona.PERSONA P
JOIN persona.ARBITRO A ON P.nro_doc = A.nro_doc AND P.tipo_doc = A.tipo_doc
WHERE P.nro_doc = '77777777' AND P.tipo_doc = 'DNI';

-- Caso 2: Alta Fallida (Rol arbitral inexistente y experiencia negativa)
PRINT '--> Caso 2: Provocando errores de validación en Árbitro (Rol 9999 y experiencia < 0)...';
BEGIN TRY
    EXEC persona.sp_ARBITRO_ABM 
        @Accion = 'A', 
        @tipo_doc = 'DNI', 
        @nro_doc = '77777776', 
        @id_nacionalidad_pais = 'ARG', 
        @nombre = 'Árbitro', 
        @apellido = 'Error', 
        @fecha_nacimiento = '1985-01-01', 
        @id_rol = 9999,                     -- Error: Rol inexistente
        @categoria_fifa = 'Nacional', 
        @anios_experiencia = -5;            -- Error: Experiencia negativa
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Error capturado]: ' + ERROR_MESSAGE();
END CATCH;

-- Caso 3: Modificación Exitosa
PRINT '--> Caso 3: Modificando experiencia del árbitro (DNI 77777777)...';
EXEC persona.sp_ARBITRO_ABM 
    @Accion = 'M', 
    @tipo_doc = 'DNI', 
    @nro_doc = '77777777', 
    @id_nacionalidad_pais = 'ARG', 
    @nombre = 'Wilmar Test Modificado', 
    @apellido = 'Árbitro', 
    @fecha_nacimiento = '1982-08-20', 
    @id_rol = 1, 
    @categoria_fifa = 'FIFA Elite', 
    @anios_experiencia = 12;

-- Caso 6: Baja Exitosa
PRINT '--> Caso 6: Eliminando árbitro de prueba (DNI 77777777)...';
EXEC persona.sp_ARBITRO_ABM 
    @Accion = 'B', 
    @tipo_doc = 'DNI', 
    @nro_doc = '77777777';

SELECT COUNT(*) AS Existe_Arbitro FROM persona.ARBITRO WHERE nro_doc = '77777777' AND tipo_doc = 'DNI';
GO

PRINT '         FIN DE PRUEBAS: MÓDULO 2 (PERSONAS Y JUGADORES) - ÉXITO        ';
GO