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
             Procedures de ABM - Módulo 5: Incidencias del Partido
             Matriz de Cobertura de Pruebas por SP:
             1. Caso 1 (Alta Exitosa): Inserción con datos válidos y completos.
             2. Caso 2 (Alta Fallida): Validación de PK duplicada, campos nulos y dominios.
             3. Caso 3 (Modificación Exitosa): Actualización de atributos sobre registros existentes.
             4. Caso 4 (Modificación Fallida): Error por intento de modificación de PK inexistente.
             5. Caso 5 (Baja Rechazada): Bloqueo de eliminación por restricciones de Clave Foránea (FK).
             6. Caso 6 (Baja Exitosa): Eliminación limpia de registros sin dependencias.
             
---------------------------------------------------------
*/

USE DB_Mundial2026_Grupo10;
GO

PRINT '         INICIO DE PRUEBAS: MÓDULO 5 (INCIDENCIAS DEL PARTIDO)  ';
GO

-- 5.0 PREPARACIÓN DE DATOS AUXILIARES (Sin usar stored procedures de otros módulos)
--------------------------------------------------------------------------------
PRINT '5.0 Preparación de datos auxiliares (país, confederación, selecciones, jugadores, convocatorias)';

INSERT INTO geografia.PAIS (id_pais, nombre_pais, moneda_pais, pbi_per_capita_actual)
VALUES ('AAA', 'País Test Módulo 5', 'Peso argentino', 10000.00);
 
INSERT INTO geografia.CONFEDERACION (id_confederacion, nombre_confederacion, sigla)
VALUES (1000, 'Confederación Test Módulo 5', 'CTM5');
 
INSERT INTO torneo.SELECCION (id_seleccion, id_pais, id_confederacion, nombre_seleccion, grupo_asignado)
VALUES (1001, 'AAA', 1000, 'Selección Test Local', 'A');
 
INSERT INTO torneo.SELECCION (id_seleccion, id_pais, id_confederacion, nombre_seleccion, grupo_asignado)
VALUES (1002, 'AAA', 1000, 'Selección Test Visitante', 'A');
 
INSERT INTO torneo.SELECCION (id_seleccion, id_pais, id_confederacion, nombre_seleccion, grupo_asignado)
VALUES (1003, 'AAA', 1000, 'Selección Test Extra', 'A');
 
INSERT INTO persona.PERSONA (nro_doc, tipo_doc, id_nacionalidad_pais, nombre, apellido, fecha_nacimiento, tipo_persona)
VALUES ('10000001', 'DNI', 'AAA', 'Nombre local 1', 'Apellido local 1', '2000-01-01', 'JUGADOR');
INSERT INTO persona.JUGADOR (nro_doc, tipo_doc, posicion_habitual, club_origen, peso_kg, altura_cm)
VALUES ('10000001', 'DNI', 'DELANTERO', 'Club test local', 80, 180);
 
INSERT INTO persona.PERSONA (nro_doc, tipo_doc, id_nacionalidad_pais, nombre, apellido, fecha_nacimiento, tipo_persona)
VALUES ('10000002', 'DNI', 'AAA', 'Nombre local 2', 'Apellido local 2', '1999-01-01', 'JUGADOR');
INSERT INTO persona.JUGADOR (nro_doc, tipo_doc, posicion_habitual, club_origen, peso_kg, altura_cm)
VALUES ('10000002', 'DNI', 'MEDIOCAMPISTA', 'Club test local', 75, 175);
 
INSERT INTO persona.PERSONA (nro_doc, tipo_doc, id_nacionalidad_pais, nombre, apellido, fecha_nacimiento, tipo_persona)
VALUES ('10000003', 'DNI', 'AAA', 'Nombre visitante 1', 'Apellido visitante 1', '2000-02-02', 'JUGADOR');
INSERT INTO persona.JUGADOR (nro_doc, tipo_doc, posicion_habitual, club_origen, peso_kg, altura_cm)
VALUES ('10000003', 'DNI', 'DELANTERO', 'Club test visitante', 80, 185);
 
INSERT INTO persona.PERSONA (nro_doc, tipo_doc, id_nacionalidad_pais, nombre, apellido, fecha_nacimiento, tipo_persona)
VALUES ('10000004', 'DNI', 'AAA', 'Nombre visitante 2', 'Apellido visitante 2', '1999-02-02', 'JUGADOR');
INSERT INTO persona.JUGADOR (nro_doc, tipo_doc, posicion_habitual, club_origen, peso_kg, altura_cm)
VALUES ('10000004', 'DNI', 'DEFENSOR', 'Club test visitante', 85, 180);
 
INSERT INTO torneo.CONVOCATORIA (id_seleccion, dorsal_oficial, nro_doc, tipo_doc, estado_convocatoria)
VALUES (1001, 10, '10000001', 'DNI', 'ACTIVO');
INSERT INTO torneo.CONVOCATORIA (id_seleccion, dorsal_oficial, nro_doc, tipo_doc, estado_convocatoria)
VALUES (1001, 11, '10000002', 'DNI', 'ACTIVO');
INSERT INTO torneo.CONVOCATORIA (id_seleccion, dorsal_oficial, nro_doc, tipo_doc, estado_convocatoria)
VALUES (1002, 20, '10000003', 'DNI', 'ACTIVO');
INSERT INTO torneo.CONVOCATORIA (id_seleccion, dorsal_oficial, nro_doc, tipo_doc, estado_convocatoria)
VALUES (1002, 21, '10000004', 'DNI', 'ACTIVO');
 
PRINT '5.0 Datos auxiliares de base creados exitosamente';
GO
 
 
-- 5.1 SP: torneo.sp_ROL_ARBITRAL_ABM
--------------------------------------------------------------------------------
PRINT '5.1 Test: torneo.sp_ROL_ARBITRAL_ABM';
 
EXEC torneo.sp_ROL_ARBITRAL_ABM @Accion = 'A', @id_rol = 1000, @rol_descripcion = 'Árbitro Principal (Test)'; -- Queda para más adelante
 
-- Esto está fuera del modulo 5, por lo que se inserta sin sp
INSERT INTO persona.PERSONA (nro_doc, tipo_doc, id_nacionalidad_pais, nombre, apellido, fecha_nacimiento, tipo_persona)
VALUES ('10000099', 'DNI', 'AAA', 'Nombre arbitro', 'Apellido arbitro', '1990-01-01', 'ARBITRO');
INSERT INTO persona.ARBITRO (nro_doc, tipo_doc, id_rol, categoria_fifa, anios_experiencia)
VALUES ('10000099', 'DNI', 1000, 'FIFA ELITE', 10);
 
-- Caso 1: Alta Exitosa
PRINT '--> Caso 1: Insertando rol arbitral de prueba (999)...';
EXEC torneo.sp_ROL_ARBITRAL_ABM @Accion = 'A', @id_rol = 999, @rol_descripcion = 'Rol de prueba';
 
-- Verificación de inserción
SELECT id_rol, rol_descripcion 
FROM torneo.ROL_ARBITRAL 
WHERE id_rol = 999;
 
-- Caso 2: Alta Fallida (PK duplicada y descripción vacía)
PRINT '--> Caso 2: Provocando errores de validación (PK duplicada y descripción vacía)...';
BEGIN TRY
    EXEC torneo.sp_ROL_ARBITRAL_ABM @Accion = 'A', @id_rol = 999, @rol_descripcion = '';
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Mensaje capturado]: ' + ERROR_MESSAGE();
END CATCH;
 
-- Caso 3: Modificación Exitosa
PRINT '--> Caso 3: Modificando descripción del rol de prueba (999)...';
EXEC torneo.sp_ROL_ARBITRAL_ABM @Accion = 'M', @id_rol = 999, @rol_descripcion = 'Rol de prueba modificado';

-- Verificación de modificación
SELECT id_rol, rol_descripcion 
FROM torneo.ROL_ARBITRAL 
WHERE id_rol = 999;
 
-- Caso 4: Modificación Fallida (PK Inexistente)
PRINT '--> Caso 4: Intentando modificar rol inexistente (888)...';
BEGIN TRY
    EXEC torneo.sp_ROL_ARBITRAL_ABM @Accion = 'M', @id_rol = 888, @rol_descripcion = 'No existe';
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Error capturado]: ' + ERROR_MESSAGE();
END CATCH;
 
-- Caso 5: Baja Rechazada por FK (rol en uso por el árbitro auxiliar)
PRINT '--> Caso 5: Intentando eliminar el rol 1000 referenciado por un árbitro existente...';
BEGIN TRY
    EXEC torneo.sp_ROL_ARBITRAL_ABM @Accion = 'B', @id_rol = 1000;
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Bloqueo de eliminación por FK]: ' + ERROR_MESSAGE();
END CATCH;
 
-- Caso 6: Baja Exitosa
PRINT '--> Caso 6: Eliminando rol de prueba (999)...';
EXEC torneo.sp_ROL_ARBITRAL_ABM @Accion = 'B', @id_rol = 999;
 
SELECT COUNT(*) AS Existe_Rol_999 FROM torneo.ROL_ARBITRAL WHERE id_rol = 999;
GO
 
 
-- 5.2 SP: torneo.sp_SEDE_ABM
PRINT '5.2 Test: torneo.sp_SEDE_ABM';
 
EXEC torneo.sp_SEDE_ABM 
    @Accion = 'A', @id_sede = 1000, @id_pais = 'AAA', @nombre_estadio = 'Estadio test base',
    @ciudad = 'Ciudad test', @capacidad = 50000, @huso_horario_utc = '-03:00';                  -- Queda para más adelante
 
-- Caso 1: Alta Exitosa
PRINT '--> Caso 1: Insertando sede de prueba (999)...';
EXEC torneo.sp_SEDE_ABM
    @Accion = 'A', @id_sede = 999, @id_pais = 'AAA', @nombre_estadio = 'Estadio test nuevo',
    @ciudad = 'Ciudad test', @capacidad = 40000, @huso_horario_utc = '-03:00';
 
-- Verificación de inserción
SELECT id_sede, nombre_estadio, ciudad, capacidad 
FROM torneo.SEDE 
WHERE id_sede = 999;
 
-- Caso 2: Alta Fallida (PK duplicada, país inexistente y capacidad negativa)
PRINT '--> Caso 2: Provocando errores de validación en Sede...';
BEGIN TRY
    EXEC torneo.sp_SEDE_ABM
        @Accion = 'A', @id_sede = 999, @id_pais = 'BBB', @nombre_estadio = 'Estadio test alta fallida',
        @ciudad = 'Ciudad test', @capacidad = -100, @huso_horario_utc = '-03:00';
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Error capturado]: ' + ERROR_MESSAGE();
END CATCH;
 
-- Caso 3: Modificación Exitosa
PRINT '--> Caso 3: Modificando capacidad de la sede de prueba (999)...';
EXEC torneo.sp_SEDE_ABM
    @Accion = 'M', @id_sede = 999, @id_pais = 'AAA', @nombre_estadio = 'Estadio test nuevo modificado',
    @ciudad = 'Ciudad test', @capacidad = 41000, @huso_horario_utc = '-03:00';

-- Verificación de modificación
SELECT id_sede, nombre_estadio, ciudad, capacidad 
FROM torneo.SEDE 
WHERE id_sede = 999;
 
-- Caso 4: Modificación Fallida (PK Inexistente)
PRINT '--> Caso 4: Intentando modificar sede inexistente (888)...';
BEGIN TRY
    EXEC torneo.sp_SEDE_ABM
        @Accion = 'M', @id_sede = 888, @id_pais = 'AAA', @nombre_estadio = 'No existe',
        @ciudad = 'N/A', @capacidad = 1000, @huso_horario_utc = '+00:00';
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Error capturado]: ' + ERROR_MESSAGE();
END CATCH;
 
-- Caso 5: Baja Rechazada por FK (sede en uso por el partido base).
-- El partido base se crea en 5.4, asi que ahi se va a ejecutar esta parte
 
-- Caso 6: Baja Exitosa
PRINT '--> Caso 6: Eliminando sede de prueba (999)...';
EXEC torneo.sp_SEDE_ABM @Accion = 'B', @id_sede = 999;
 
SELECT COUNT(*) AS Existe_Sede_999 FROM torneo.SEDE WHERE id_sede = 999;
GO
 
 
-- 5.3 SP: torneo.sp_FASE_TORNEO_ABM
PRINT '5.3 Test: torneo.sp_FASE_TORNEO_ABM';
 
EXEC torneo.sp_FASE_TORNEO_ABM @Accion = 'A', @id_fase = 1000, @nombre_fase = 'Fase de Grupos (test)', @orden_secuencia = 1; -- Queda para más adelante
 
-- Caso 1: Alta Exitosa
PRINT '--> Caso 1: Insertando fase de prueba (999)...';
EXEC torneo.sp_FASE_TORNEO_ABM @Accion = 'A', @id_fase = 999, @nombre_fase = 'Fase de prueba', @orden_secuencia = 50;
 
-- Verificación de inserción
SELECT id_fase, nombre_fase, orden_secuencia 
FROM torneo.FASE_TORNEO 
WHERE id_fase = 999;
 
-- Caso 2: Alta Fallida (PK duplicada y orden de secuencia inválido)
PRINT '--> Caso 2: Provocando errores de validación en Fase del Torneo...';
BEGIN TRY
    EXEC torneo.sp_FASE_TORNEO_ABM @Accion = 'A', @id_fase = 999, @nombre_fase = '', @orden_secuencia = -5;
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Error capturado]: ' + ERROR_MESSAGE();
END CATCH;
 
-- Caso 3: Modificación Exitosa
PRINT '--> Caso 3: Modificando fase de prueba (999)...';
EXEC torneo.sp_FASE_TORNEO_ABM @Accion = 'M', @id_fase = 999, @nombre_fase = 'Fase de prueba modificada', @orden_secuencia = 51;
 
-- Verificación de modificación
SELECT id_fase, nombre_fase, orden_secuencia 
FROM torneo.FASE_TORNEO 
WHERE id_fase = 999;

-- Caso 4: Modificación Fallida (PK Inexistente)
PRINT '--> Caso 4: Intentando modificar fase inexistente (888)...';
BEGIN TRY
    EXEC torneo.sp_FASE_TORNEO_ABM @Accion = 'M', @id_fase = 888, @nombre_fase = 'No existe', @orden_secuencia = 1;
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Error capturado]: ' + ERROR_MESSAGE();
END CATCH;
 
-- Caso 5: Baja Rechazada por FK (fase en uso por el partido base).
-- El partido base se crea en 5.4, asi que ahi se va a ejecutar esta parte
 
-- Caso 6: Baja Exitosa
PRINT '--> Caso 6: Eliminando fase de prueba (999)...';
EXEC torneo.sp_FASE_TORNEO_ABM @Accion = 'B', @id_fase = 999;
 
SELECT COUNT(*) AS Existe_Fase_999 FROM torneo.FASE_TORNEO WHERE id_fase = 999;
GO
 
 
-- 5.4 SP: torneo.sp_PARTIDO_ABM
PRINT '5.4 Test: torneo.sp_PARTIDO_ABM';
 
-- Acá se crea el partido base y luego validamos las bajas rechazadas pendientes
EXEC torneo.sp_PARTIDO_ABM
    @Accion = 'A', @id_fase = 1000, @nro_partido_fase = 1, @id_sede = 1000,
    @id_seleccion_local = 1001, @id_seleccion_visitante = 1002,
    @fecha_hora_utc = '2026-06-15T18:00:00', @fecha_hora_local = '2026-06-15T15:00:00';
 
SELECT id_fase, nro_partido_fase, id_sede, id_seleccion_local, id_seleccion_visitante, goles_local, goles_visitante
FROM torneo.PARTIDO 
WHERE id_fase = 1000 AND nro_partido_fase = 1;
 
-- Validación del caso 5 de 5.2
PRINT '--> (5.2 Caso 5) Intentando eliminar la sede auxiliar (1000) con un partido asignado...';
BEGIN TRY
    EXEC torneo.sp_SEDE_ABM @Accion = 'B', @id_sede = 1000;
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Bloqueo de eliminación por FK]: ' + ERROR_MESSAGE();
END CATCH;
 
-- Validación del caso 5 de 5.3
PRINT '--> (5.3 Caso 5) Intentando eliminar la fase auxiliar (1000) con un partido registrado...';
BEGIN TRY
    EXEC torneo.sp_FASE_TORNEO_ABM @Accion = 'B', @id_fase = 1000;
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Bloqueo de eliminación por FK]: ' + ERROR_MESSAGE();
END CATCH;
 
-- Caso 1: Alta Exitosa
PRINT '--> Caso 1: Insertando partido de prueba (1000, 999)...';
EXEC torneo.sp_PARTIDO_ABM
    @Accion = 'A', @id_fase = 1000, @nro_partido_fase = 999, @id_sede = 1000,
    @id_seleccion_local = 1001, @id_seleccion_visitante = 1002,
    @fecha_hora_utc = '2026-06-20T18:00:00', @fecha_hora_local = '2026-06-20T15:00:00';
 
-- Verificación de inserción
SELECT id_fase, nro_partido_fase 
FROM torneo.PARTIDO 
WHERE id_fase = 1000 AND nro_partido_fase = 999;
 
-- Caso 2: Alta Fallida (PK duplicada, selecciones iguales y sede inexistente)
PRINT '--> Caso 2: Provocando errores de validación en Partido...';
BEGIN TRY
    EXEC torneo.sp_PARTIDO_ABM
        @Accion = 'A', @id_fase = 1000, @nro_partido_fase = 999, @id_sede = 777,
        @id_seleccion_local = 1001, @id_seleccion_visitante = 1001,
        @fecha_hora_utc = '2026-06-20T18:00:00', @fecha_hora_local = '2026-06-20T15:00:00';
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Error capturado]: ' + ERROR_MESSAGE();
END CATCH;
 
-- Caso 3: Modificación Exitosa
PRINT '--> Caso 3: Modificando goles del partido de prueba (1000, 999)...';
EXEC torneo.sp_PARTIDO_ABM
    @Accion = 'M', @id_fase = 1000, @nro_partido_fase = 999, @id_sede = 1000,
    @id_seleccion_local = 1001, @id_seleccion_visitante = 1002,
    @fecha_hora_utc = '2026-06-20T18:00:00', @fecha_hora_local = '2026-06-20T15:00:00',
    @goles_local = 2, @goles_visitante = 1;

-- Verificación de modificación
SELECT id_fase, nro_partido_fase 
FROM torneo.PARTIDO 
WHERE id_fase = 1000 AND nro_partido_fase = 999;
 
-- Caso 4: Modificación Fallida (PK Inexistente)
PRINT '--> Caso 4: Intentando modificar partido inexistente (1000, 888)...';
BEGIN TRY
    EXEC torneo.sp_PARTIDO_ABM @Accion = 'M', @id_fase = 1000, @nro_partido_fase = 888, @id_sede = 1000,
        @id_seleccion_local = 1001, @id_seleccion_visitante = 1002,
        @fecha_hora_utc = '2026-06-20T18:00:00', @fecha_hora_local = '2026-06-20T15:00:00';
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Error capturado]: ' + ERROR_MESSAGE();
END CATCH;
 
-- Caso 5: Baja Rechazada por FK (partido base en uso por designación/alineaciones).
-- Las designaciones se crean en 5.5 y las alineaciones en 5.6, asi que en el 5.6 se va a ejecutar esta parte
 
-- Caso 6: Baja Exitosa
PRINT '--> Caso 6: Eliminando partido de prueba (1000, 999)...';
EXEC torneo.sp_PARTIDO_ABM @Accion = 'B', @id_fase = 1000, @nro_partido_fase = 999;
 
SELECT COUNT(*) AS Existe_Partido_999 FROM torneo.PARTIDO WHERE id_fase = 1000 AND nro_partido_fase = 999;
GO
 
 
-- 5.5 SP: torneo.sp_DESIGNACION_ARBITRAL_ABM
PRINT '5.5 Test: torneo.sp_DESIGNACION_ARBITRAL_ABM';
 
EXEC torneo.sp_DESIGNACION_ARBITRAL_ABM
    @Accion = 'A', @id_fase = 1000, @nro_partido_fase = 1, @nro_doc = '10000099', @tipo_doc = 'DNI', @id_rol = 1000;
 
SELECT id_fase, nro_partido_fase, nro_doc, tipo_doc, id_rol
FROM torneo.DESIGNACION_ARBITRAL 
WHERE id_fase = 1000 AND nro_partido_fase = 1 AND nro_doc = '10000099';
 
INSERT INTO persona.PERSONA (nro_doc, tipo_doc, id_nacionalidad_pais, nombre, apellido, fecha_nacimiento, tipo_persona)
VALUES ('10000098', 'DNI', 'AAA', 'Nombre arbitro asistente', 'Apellido arbitro asistente', '1990-01-01', 'ARBITRO');
INSERT INTO persona.ARBITRO (nro_doc, tipo_doc, id_rol, categoria_fifa, anios_experiencia)
VALUES ('10000098', 'DNI', 1000, 'FIFA ELITE', 5);
 
-- Caso 1: Alta Exitosa
PRINT '--> Caso 1: Designando árbitro auxiliar (10000098) en el partido base...';
EXEC torneo.sp_DESIGNACION_ARBITRAL_ABM
    @Accion = 'A', @id_fase = 1000, @nro_partido_fase = 1, @nro_doc = '10000098', @tipo_doc = 'DNI', @id_rol = 1000;
 
-- Verificación de inserción
SELECT id_fase, nro_partido_fase, nro_doc, tipo_doc, id_rol
FROM torneo.DESIGNACION_ARBITRAL 
WHERE id_fase = 1000 AND nro_partido_fase = 1 AND nro_doc = '10000098';
 
-- Caso 2: Alta Fallida (PK duplicada: designación ya existente para el árbitro principal)
PRINT '--> Caso 2: Provocando error de PK duplicada en Designación Arbitral...';
BEGIN TRY
    EXEC torneo.sp_DESIGNACION_ARBITRAL_ABM
        @Accion = 'A', @id_fase = 1000, @nro_partido_fase = 1, @nro_doc = '10000099', @tipo_doc = 'DNI', @id_rol = 1000;
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Error capturado]: ' + ERROR_MESSAGE();
END CATCH;
 
-- Caso 3: Modificación Exitosa
PRINT '--> Caso 3: Modificando la designación del árbitro auxiliar (10000098)...';
EXEC torneo.sp_DESIGNACION_ARBITRAL_ABM
    @Accion = 'M', @id_fase = 1000, @nro_partido_fase = 1, @nro_doc = '10000098', @tipo_doc = 'DNI', @id_rol = 1000;

-- Verificación de modificación
SELECT id_fase, nro_partido_fase, nro_doc, tipo_doc, id_rol
FROM torneo.DESIGNACION_ARBITRAL 
WHERE id_fase = 1000 AND nro_partido_fase = 1 AND nro_doc = '10000098';
 
-- Caso 4: Modificación Fallida (designación inexistente)
PRINT '--> Caso 4: Intentando modificar una designación inexistente...';
BEGIN TRY
    EXEC torneo.sp_DESIGNACION_ARBITRAL_ABM
        @Accion = 'M', @id_fase = 1000, @nro_partido_fase = 1, @nro_doc = '11111111', @tipo_doc = 'DNI', @id_rol = 1000;
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Error capturado]: ' + ERROR_MESSAGE();
END CATCH;
 
-- Caso 5 no aplica

-- Caso 6: Baja Exitosa (y limpieza del árbitro auxiliar)
PRINT '--> Caso 6: Eliminando la designación del árbitro auxiliar (10000098)...';
EXEC torneo.sp_DESIGNACION_ARBITRAL_ABM
    @Accion = 'B', @id_fase = 1000, @nro_partido_fase = 1, @nro_doc = '10000098', @tipo_doc = 'DNI';
 

DELETE FROM persona.ARBITRO WHERE nro_doc = '10000098' AND tipo_doc = 'DNI';
DELETE FROM persona.PERSONA WHERE nro_doc = '10000098' AND tipo_doc = 'DNI';
 
SELECT COUNT(*) AS Existe_Designacion_10000098 FROM torneo.DESIGNACION_ARBITRAL WHERE id_fase = 1000 AND nro_partido_fase = 1 AND nro_doc = '10000098';
GO
 
 
-- 5.6 SP: torneo.sp_ALINEACION_PARTIDO_ABM
PRINT '5.6 Test: torneo.sp_ALINEACION_PARTIDO_ABM';
 
EXEC torneo.sp_ALINEACION_PARTIDO_ABM @Accion = 'A', @id_fase = 1000, @nro_partido_fase = 1, @id_seleccion = 1001, @esquema_tactico = '4-4-2';
EXEC torneo.sp_ALINEACION_PARTIDO_ABM @Accion = 'A', @id_fase = 1000, @nro_partido_fase = 1, @id_seleccion = 1002, @esquema_tactico = '4-3-3';
 
SELECT id_fase, nro_partido_fase, id_seleccion, esquema_tactico
FROM torneo.ALINEACION_PARTIDO 
WHERE id_fase = 1000 AND nro_partido_fase = 1;
 
-- Validación del caso 5 de 5.4
PRINT '--> (5.4 Caso 5) Intentando eliminar el partido base (1000,1) con designación y alineaciones...';
BEGIN TRY
    EXEC torneo.sp_PARTIDO_ABM @Accion = 'B', @id_fase = 1000, @nro_partido_fase = 1;
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Bloqueo de eliminación por FK]: ' + ERROR_MESSAGE();
END CATCH;
 

EXEC torneo.sp_PARTIDO_ABM
    @Accion = 'A', @id_fase = 1000, @nro_partido_fase = 998, @id_sede = 1000,
    @id_seleccion_local = 1001, @id_seleccion_visitante = 1002,
    @fecha_hora_utc = '2026-06-25T18:00:00', @fecha_hora_local = '2026-06-25T15:00:00';
 
-- Caso 1: Alta Exitosa
PRINT '--> Caso 1: Insertando alineación de prueba (1000, 998, 1001)...';
EXEC torneo.sp_ALINEACION_PARTIDO_ABM @Accion = 'A', @id_fase = 1000, @nro_partido_fase = 998, @id_seleccion = 1001, @esquema_tactico = '4-4-2';
 
-- Verificación de inserción
SELECT id_fase, nro_partido_fase, id_seleccion, esquema_tactico
FROM torneo.ALINEACION_PARTIDO 
WHERE id_fase = 1000 AND nro_partido_fase = 998 AND id_seleccion = 1001;
 
-- Caso 2a: Alta Fallida (PK duplicada y esquema táctico vacío)
PRINT '--> Caso 2a: Provocando errores de validación (PK duplicada y esquema vacío)...';
BEGIN TRY
    EXEC torneo.sp_ALINEACION_PARTIDO_ABM @Accion = 'A', @id_fase = 1000, @nro_partido_fase = 998, @id_seleccion = 1001, @esquema_tactico = '';
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Error capturado]: ' + ERROR_MESSAGE();
END CATCH;
 
-- Caso 2b: Alta Fallida (la selección existe pero no participa en el partido indicado)
PRINT '--> Caso 2b: Provocando error de "selección no participa en el partido"...';
BEGIN TRY
    EXEC torneo.sp_ALINEACION_PARTIDO_ABM @Accion = 'A', @id_fase = 1000, @nro_partido_fase = 998, @id_seleccion = 1003, @esquema_tactico = '4-4-2';
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Error capturado]: ' + ERROR_MESSAGE();
END CATCH;
 
-- Caso 3: Modificación Exitosa
PRINT '--> Caso 3: Modificando esquema táctico de la alineación de prueba...';
EXEC torneo.sp_ALINEACION_PARTIDO_ABM @Accion = 'M', @id_fase = 1000, @nro_partido_fase = 998, @id_seleccion = 1001, @esquema_tactico = '4-3-3';

-- Verificación de modificación
SELECT id_fase, nro_partido_fase, id_seleccion, esquema_tactico
FROM torneo.ALINEACION_PARTIDO 
WHERE id_fase = 1000 AND nro_partido_fase = 998 AND id_seleccion = 1001;
 
-- Caso 4: Modificación Fallida (PK Inexistente)
PRINT '--> Caso 4: Intentando modificar una alineación inexistente...';
BEGIN TRY
    EXEC torneo.sp_ALINEACION_PARTIDO_ABM @Accion = 'M', @id_fase = 1000, @nro_partido_fase = 998, @id_seleccion = 9999, @esquema_tactico = '4-4-2';
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Error capturado]: ' + ERROR_MESSAGE();
END CATCH;
 
-- Caso 5: Baja Rechazada por FK (alineación base en uso por un jugador cargado).
-- El jugador en la alineacion se carga en 5.7, asi que ahi se va a ejecutar esta parte
 
-- Caso 6: Baja Exitosa (y limpieza del partido auxiliar)
PRINT '--> Caso 6: Eliminando alineación de prueba (1000, 998, 1001) y partido auxiliar...';
EXEC torneo.sp_ALINEACION_PARTIDO_ABM @Accion = 'B', @id_fase = 1000, @nro_partido_fase = 998, @id_seleccion = 1001;
EXEC torneo.sp_PARTIDO_ABM @Accion = 'B', @id_fase = 1000, @nro_partido_fase = 998;
 
SELECT COUNT(*) AS Existe_Alineacion_998 FROM torneo.ALINEACION_PARTIDO WHERE id_fase = 1000 AND nro_partido_fase = 998;
GO
 
 
-- 5.7 SP: torneo.sp_JUGADOR_ALINEACION_ABM
PRINT '5.7 Test: torneo.sp_JUGADOR_ALINEACION_ABM';
 
EXEC torneo.sp_JUGADOR_ALINEACION_ABM
    @Accion = 'A', @id_fase = 1000, @nro_partido_fase = 1, @id_seleccion = 1001, @dorsal_oficial = 10,
    @es_titular = 1, @posicion_campo = 'DELANTERO';
 
SELECT id_fase, nro_partido_fase, id_seleccion, dorsal_oficial, es_titular, minuto_ingreso
FROM torneo.JUGADOR_ALINEACION 
WHERE id_fase = 1000 AND nro_partido_fase = 1 AND id_seleccion = 1001 AND dorsal_oficial = 10;
 
-- Caso 1: Alta Exitosa
PRINT '--> Caso 1: Cargando jugador suplente (dorsal 11) sin minuto de ingreso informado...';
EXEC torneo.sp_JUGADOR_ALINEACION_ABM
    @Accion = 'A', @id_fase = 1000, @nro_partido_fase = 1, @id_seleccion = 1001, @dorsal_oficial = 11,
    @es_titular = 0, @posicion_campo = 'SUPLENTE';
 
-- Verificación de inserción
SELECT id_fase, nro_partido_fase, id_seleccion, dorsal_oficial, es_titular, minuto_ingreso
FROM torneo.JUGADOR_ALINEACION 
WHERE id_fase = 1000 AND nro_partido_fase = 1 AND id_seleccion = 1001 AND dorsal_oficial = 11;
 
-- Caso 2: Alta Fallida (PK duplicada y minuto de ingreso negativo)
PRINT '--> Caso 2: Provocando errores de validación (PK duplicada y minuto de ingreso negativo)...';
BEGIN TRY
    EXEC torneo.sp_JUGADOR_ALINEACION_ABM
        @Accion = 'A', @id_fase = 1000, @nro_partido_fase = 1, @id_seleccion = 1001, @dorsal_oficial = 11,
        @es_titular = 0, @posicion_campo = 'SUPLENTE', @minuto_ingreso = -10;
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Error capturado]: ' + ERROR_MESSAGE();
END CATCH;
 
-- Caso 3: Modificación Exitosa (el suplente ingresa efectivamente en el minuto 70)
PRINT '--> Caso 3: Modificando jugador suplente (dorsal 11): ingresa en el minuto 70...';
EXEC torneo.sp_JUGADOR_ALINEACION_ABM
    @Accion = 'M', @id_fase = 1000, @nro_partido_fase = 1, @id_seleccion = 1001, @dorsal_oficial = 11,
    @es_titular = 0, @posicion_campo = 'MEDIOCAMPISTA', @minuto_ingreso = 70;
 
-- Verificación de modificación
SELECT id_fase, nro_partido_fase, id_seleccion, dorsal_oficial, es_titular, minuto_ingreso
FROM torneo.JUGADOR_ALINEACION 
WHERE id_fase = 1000 AND nro_partido_fase = 1 AND id_seleccion = 1001 AND dorsal_oficial = 11;
 
-- Caso 4: Modificación Fallida (PK Inexistente)
PRINT '--> Caso 4: Intentando modificar un jugador en alineación inexistente (dorsal 77)...';
BEGIN TRY
    EXEC torneo.sp_JUGADOR_ALINEACION_ABM
        @Accion = 'M', @id_fase = 1000, @nro_partido_fase = 1, @id_seleccion = 1001, @dorsal_oficial = 77,
        @es_titular = 0, @posicion_campo = 'SUPLENTE', @minuto_ingreso = 60;
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Error capturado]: ' + ERROR_MESSAGE();
END CATCH;
 
-- Caso 5 no aplica
 
-- Caso 6: Baja Exitosa
PRINT '--> Caso 6: Eliminando jugador suplente (dorsal 11) de la alineación...';
EXEC torneo.sp_JUGADOR_ALINEACION_ABM @Accion = 'B', @id_fase = 1000, @nro_partido_fase = 1, @id_seleccion = 1001, @dorsal_oficial = 11;
 
SELECT COUNT(*) AS Existe_JugadorAlineacion_11
FROM torneo.JUGADOR_ALINEACION WHERE id_fase = 1000 AND nro_partido_fase = 1 AND id_seleccion = 1001 AND dorsal_oficial = 11;
 
-- Validación del caso 5 de 5.6
PRINT '--> (5.6 Caso 5) Intentando eliminar la alineación base (1000,1,1001) con un jugador cargado...';
BEGIN TRY
    EXEC torneo.sp_ALINEACION_PARTIDO_ABM @Accion = 'B', @id_fase = 1000, @nro_partido_fase = 1, @id_seleccion = 1001;
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Bloqueo de eliminación por FK]: ' + ERROR_MESSAGE();
END CATCH;
GO
 
 
-- 5.8 SP: torneo.sp_SUSTITUCION_ABM
PRINT '5.8 Test: torneo.sp_SUSTITUCION_ABM';
 
-- Caso 1: Alta Exitosa (sale dorsal 10, entra dorsal 11, minuto 60)
PRINT '--> Caso 1: Registrando sustitución de prueba (sale 10, entra 11, minuto 60)...';
EXEC torneo.sp_SUSTITUCION_ABM
    @Accion = 'A', @id_fase = 1000, @nro_partido_fase = 1, @id_secuencia = 1, @id_seleccion = 1001,
    @dorsal_sale = 10, @dorsal_entra = 11, @minuto_cambio = 60, @ventana_numero = 1;
 
-- Verificación de inserción
SELECT id_fase, nro_partido_fase, id_secuencia, id_seleccion, dorsal_sale, dorsal_entra, minuto_cambio
FROM torneo.SUSTITUCION 
WHERE id_fase = 1000 AND nro_partido_fase = 1 AND id_secuencia = 1;
 
-- Caso 2: Alta Fallida (PK duplicada, mismo dorsal entra/sale y minuto fuera de rango)
PRINT '--> Caso 2: Provocando errores de validación en Sustitución...';
BEGIN TRY
    EXEC torneo.sp_SUSTITUCION_ABM
        @Accion = 'A', @id_fase = 1000, @nro_partido_fase = 1, @id_secuencia = 1, @id_seleccion = 1001,
        @dorsal_sale = 10, @dorsal_entra = 10, @minuto_cambio = 200, @ventana_numero = 1;
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Error capturado]: ' + ERROR_MESSAGE();
END CATCH;
 
-- Caso 3: Modificación Exitosa
PRINT '--> Caso 3: Modificando minuto de la sustitución de prueba...';
EXEC torneo.sp_SUSTITUCION_ABM
    @Accion = 'M', @id_fase = 1000, @nro_partido_fase = 1, @id_secuencia = 1, @id_seleccion = 1001,
    @dorsal_sale = 10, @dorsal_entra = 11, @minuto_cambio = 65, @ventana_numero = 1;

-- Verificación de modificación
SELECT id_fase, nro_partido_fase, id_secuencia, id_seleccion, dorsal_sale, dorsal_entra, minuto_cambio
FROM torneo.SUSTITUCION 
WHERE id_fase = 1000 AND nro_partido_fase = 1 AND id_secuencia = 1;
 
-- Caso 4: Modificación Fallida (PK Inexistente)
PRINT '--> Caso 4: Intentando modificar una sustitución inexistente (secuencia 777)...';
BEGIN TRY
    EXEC torneo.sp_SUSTITUCION_ABM
        @Accion = 'M', @id_fase = 1000, @nro_partido_fase = 1, @id_secuencia = 777, @id_seleccion = 1001,
        @dorsal_sale = 10, @dorsal_entra = 11, @minuto_cambio = 65, @ventana_numero = 1;
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Error capturado]: ' + ERROR_MESSAGE();
END CATCH;
 
-- Caso 5 no aplica
 
-- Caso 6: Baja Exitosa
PRINT '--> Caso 6: Eliminando sustitución de prueba (secuencia 1)...';
EXEC torneo.sp_SUSTITUCION_ABM @Accion = 'B', @id_fase = 1000, @nro_partido_fase = 1, @id_secuencia = 1;
 
SELECT COUNT(*) AS Existe_Sustitucion_1 FROM torneo.SUSTITUCION WHERE id_fase = 1000 AND nro_partido_fase = 1 AND id_secuencia = 1;
 
-- Caso adicional: Validación disciplinaria (jugador ya expulsado)
PRINT '--> Caso adicional: dorsal 10 recibe tarjeta roja directa en el minuto 50...';

INSERT INTO torneo.SANCION_TARJETA (id_fase, nro_partido_fase, id_tarjeta, minuto_sancion, tipo_tarjeta, motivo, id_seleccion, dorsal_sancionado)
VALUES (1000, 1, 1, 50, 'ROJA_DIRECTA', 'Test expulsión directa', 1001, 10);
 
PRINT '--> Caso adicional: intentando sustituir (minuto 60) a un jugador ya expulsado (minuto 50)...';
BEGIN TRY
    EXEC torneo.sp_SUSTITUCION_ABM
        @Accion = 'A', @id_fase = 1000, @nro_partido_fase = 1, @id_secuencia = 2, @id_seleccion = 1001,
        @dorsal_sale = 10, @dorsal_entra = 11, @minuto_cambio = 60, @ventana_numero = 1;
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Jugador ya expulsado]: ' + ERROR_MESSAGE();
END CATCH;
-- Es identico tanto para dorsal_entra como para dorsal_sale
 
DELETE FROM torneo.SANCION_TARJETA WHERE id_fase = 1000 AND nro_partido_fase = 1 AND id_tarjeta = 1;
GO
 
 
-- 5.9 SP: torneo.sp_GOL_ABM
PRINT '5.9 Test: torneo.sp_GOL_ABM';
 
-- Caso 1: Alta Exitosa (gol del visitante, autor dorsal 20, asistencia dorsal 21)
PRINT '--> Caso 1: Registrando gol de prueba (autor 20, asistencia 21, minuto 30)...';
EXEC torneo.sp_GOL_ABM
    @Accion = 'A', @id_fase = 1000, @nro_partido_fase = 1, @id_gol = 1, @minuto_gol = 30,
    @tipo_gol = 'JUGADA', @id_seleccion = 1002, @dorsal_autor = 20, @dorsal_asistente = 21;
 
-- Verificación de inserción
SELECT id_fase, nro_partido_fase, id_gol, minuto_gol, tipo_gol, id_seleccion, dorsal_autor, dorsal_asistente
FROM torneo.GOL 
WHERE id_fase = 1000 AND nro_partido_fase = 1 AND id_gol = 1;
 
-- Caso 2a: Alta Fallida (PK duplicada, autor = asistente, tipo de gol inválido y minuto fuera de rango)
PRINT '--> Caso 2a: Provocando errores de validación en Gol...';
BEGIN TRY
    EXEC torneo.sp_GOL_ABM
        @Accion = 'A', @id_fase = 1000, @nro_partido_fase = 1, @id_gol = 1, @minuto_gol = 200,
        @tipo_gol = 'GOLAZO', @id_seleccion = 1002, @dorsal_autor = 20, @dorsal_asistente = 20;
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Error capturado]: ' + ERROR_MESSAGE();
END CATCH;
 
-- Caso 2b: Alta Fallida (la selección existe pero no participó en el partido indicado)
PRINT '--> Caso 2b: Provocando error de "selección no participó en el partido"...';
BEGIN TRY
    EXEC torneo.sp_GOL_ABM
        @Accion = 'A', @id_fase = 1000, @nro_partido_fase = 1, @id_gol = 2, @minuto_gol = 10,
        @tipo_gol = 'JUGADA', @id_seleccion = 1003, @dorsal_autor = 1;
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Error capturado]: ' + ERROR_MESSAGE();
END CATCH;
 
-- Caso 3: Modificación Exitosa
PRINT '--> Caso 3: Modificando el minuto del gol de prueba...';
EXEC torneo.sp_GOL_ABM
    @Accion = 'M', @id_fase = 1000, @nro_partido_fase = 1, @id_gol = 1, @minuto_gol = 35,
    @tipo_gol = 'JUGADA', @id_seleccion = 1002, @dorsal_autor = 20, @dorsal_asistente = 21;

-- Verificación de modificación
SELECT id_fase, nro_partido_fase, id_gol, minuto_gol, tipo_gol, id_seleccion, dorsal_autor, dorsal_asistente
FROM torneo.GOL 
WHERE id_fase = 1000 AND nro_partido_fase = 1 AND id_gol = 1;
 
-- Caso 4: Modificación Fallida (PK Inexistente)
PRINT '--> Caso 4: Intentando modificar un gol inexistente (id_gol 777)...';
BEGIN TRY
    EXEC torneo.sp_GOL_ABM
        @Accion = 'M', @id_fase = 1000, @nro_partido_fase = 1, @id_gol = 777, @minuto_gol = 35,
        @tipo_gol = 'JUGADA', @id_seleccion = 1002, @dorsal_autor = 20;
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Error capturado]: ' + ERROR_MESSAGE();
END CATCH;
 
-- Caso 5 no aplica
 
-- Caso 6: Baja Exitosa
PRINT '--> Caso 6: Eliminando gol de prueba (id_gol 1)...';
EXEC torneo.sp_GOL_ABM @Accion = 'B', @id_fase = 1000, @nro_partido_fase = 1, @id_gol = 1;
 
SELECT COUNT(*) AS Existe_Gol_1 FROM torneo.GOL WHERE id_fase = 1000 AND nro_partido_fase = 1 AND id_gol = 1;
 
-- Caso adicional: Validación disciplinaria (jugador ya expulsado)
PRINT '--> Caso adicional: dorsal 20 recibe doble amarilla en el minuto 40...';

INSERT INTO torneo.SANCION_TARJETA (id_fase, nro_partido_fase, id_tarjeta, minuto_sancion, tipo_tarjeta, motivo, id_seleccion, dorsal_sancionado)
VALUES (1000, 1, 2, 40, 'DOBLE_AMARILLA', 'Test doble amonestación', 1002, 20);
 
PRINT '--> Caso adicional: intentando acreditar un gol (minuto 45) a un autor ya expulsado (minuto 40)...';
BEGIN TRY
    EXEC torneo.sp_GOL_ABM
        @Accion = 'A', @id_fase = 1000, @nro_partido_fase = 1, @id_gol = 3, @minuto_gol = 45,
        @tipo_gol = 'JUGADA', @id_seleccion = 1002, @dorsal_autor = 20;
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Autor ya expulsado]: ' + ERROR_MESSAGE();
END CATCH;
-- Es identico tanto para asistente como para autor
 
DELETE FROM torneo.SANCION_TARJETA WHERE id_fase = 1000 AND nro_partido_fase = 1 AND id_tarjeta = 2;
GO
 

-- 5.10 Limpieza
PRINT '5.10 Limpieza general de todo lo auxiliar del Módulo 5...';
 
EXEC torneo.sp_JUGADOR_ALINEACION_ABM @Accion = 'B', @id_fase = 1000, @nro_partido_fase = 1, @id_seleccion = 1001, @dorsal_oficial = 10;
EXEC torneo.sp_ALINEACION_PARTIDO_ABM @Accion = 'B', @id_fase = 1000, @nro_partido_fase = 1, @id_seleccion = 1001;
EXEC torneo.sp_ALINEACION_PARTIDO_ABM @Accion = 'B', @id_fase = 1000, @nro_partido_fase = 1, @id_seleccion = 1002;
EXEC torneo.sp_DESIGNACION_ARBITRAL_ABM @Accion = 'B', @id_fase = 1000, @nro_partido_fase = 1, @nro_doc = '10000099', @tipo_doc = 'DNI';
EXEC torneo.sp_PARTIDO_ABM @Accion = 'B', @id_fase = 1000, @nro_partido_fase = 1;
 
-- (fixture fuera de Módulo 5)
DELETE FROM persona.ARBITRO WHERE nro_doc = '10000099' AND tipo_doc = 'DNI';
DELETE FROM persona.PERSONA WHERE nro_doc = '10000099' AND tipo_doc = 'DNI';
 
EXEC torneo.sp_ROL_ARBITRAL_ABM @Accion = 'B', @id_rol = 1000;
EXEC torneo.sp_SEDE_ABM @Accion = 'B', @id_sede = 1000;
EXEC torneo.sp_FASE_TORNEO_ABM @Accion = 'B', @id_fase = 1000;
 
-- (fixture fuera de Módulo 5)
DELETE FROM torneo.CONVOCATORIA WHERE id_seleccion = 1001 AND dorsal_oficial = 10;
DELETE FROM torneo.CONVOCATORIA WHERE id_seleccion = 1001 AND dorsal_oficial = 11;
DELETE FROM torneo.CONVOCATORIA WHERE id_seleccion = 1002 AND dorsal_oficial = 20;
DELETE FROM torneo.CONVOCATORIA WHERE id_seleccion = 1002 AND dorsal_oficial = 21;
DELETE FROM persona.JUGADOR WHERE nro_doc = '10000001' AND tipo_doc = 'DNI';
DELETE FROM persona.JUGADOR WHERE nro_doc = '10000002' AND tipo_doc = 'DNI';
DELETE FROM persona.JUGADOR WHERE nro_doc = '10000003' AND tipo_doc = 'DNI';
DELETE FROM persona.JUGADOR WHERE nro_doc = '10000004' AND tipo_doc = 'DNI';
DELETE FROM persona.PERSONA WHERE nro_doc = '10000001' AND tipo_doc = 'DNI';
DELETE FROM persona.PERSONA WHERE nro_doc = '10000002' AND tipo_doc = 'DNI';
DELETE FROM persona.PERSONA WHERE nro_doc = '10000003' AND tipo_doc = 'DNI';
DELETE FROM persona.PERSONA WHERE nro_doc = '10000004' AND tipo_doc = 'DNI';
DELETE FROM torneo.SELECCION WHERE id_seleccion = 1001;
DELETE FROM torneo.SELECCION WHERE id_seleccion = 1002;
DELETE FROM torneo.SELECCION WHERE id_seleccion = 1003;
DELETE FROM geografia.CONFEDERACION WHERE id_confederacion = 1000;
DELETE FROM geografia.PAIS WHERE id_pais = 'AAA';
 
SELECT COUNT(*) AS Filas_Residuales_AAA FROM geografia.PAIS WHERE id_pais = 'AAA';
GO
 
PRINT '         FIN DE PRUEBAS: MÓDULO 5 (INCIDENCIAS DEL PARTIDO) - ÉXITO        ';
GO