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
             Procedures de ABM - Módulo 3 : Seleccion
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

SET NOCOUNT ON;

PRINT '         INICIO DE PRUEBAS: MÓDULO 3 (Selecciones)  ';
GO

-- 3.0 Preparacion de datos para test (Incercion manual)
--------------------------------------------------------------------------------

INSERT INTO geografia.CONFEDERACION (id_confederacion, nombre_confederacion, sigla)
VALUES (1001, 'Confederacion Prueba Mod 3', 'CPM3'),
       (1002, 'Confederacion Prueba Mod 3.1', 'CPM3.1');

INSERT INTO geografia.PAIS (id_pais, moneda_pais, nombre_pais, pbi_per_capita_actual)
VALUES ('ARG', 'Pesos', 'Argentina Prueba', 100000.00),
       ('BRZ', 'Reales', 'Brasil Prueba', 100000.00);

INSERT INTO torneo.FASE_TORNEO (id_fase, nombre_fase, orden_secuencia)
VALUES (123, 'CUARTOS', 1);

INSERT INTO torneo.SEDE (id_sede, id_pais, nombre_estadio, ciudad, capacidad, huso_horario_utc)
VALUES (20, 'ARG', 'Sede de Prueba 1', 'Ciudad Prueba', 50000, '-03:00');

INSERT INTO persona.PERSONA (nro_doc, tipo_doc, id_nacionalidad_pais, nombre, apellido, fecha_nacimiento, tipo_persona)
VALUES ('1111111', 'Prueba', 'ARG', 'Carlos', 'Jugador', '2001-10-02', 'JUGADOR'),
       ('1111113', 'Prueba', 'BRZ', 'Pedro', 'Tecnico', '1980-05-10', 'CUERPO_TECNICO');
GO

-- 3.1 Test: Alta Exitosa
--------------------------------------------------------------------------------
PRINT '3.1 Test: Alta exitosa de Selección';
BEGIN TRY
    EXEC torneo.sp_SELECCION_ABM 
        @Accion = 'A',
        @Id_Seleccion = 1001,
        @Id_Confederacion = 1001,
        @Id_Pais = 'BRZ',
        @Nombre_Seleccion = 'Seleccion Test 1001',
        @Grupo = 'B';

    PRINT '    [OK] Selección 1001 dada de alta correctamente.';
END TRY
BEGIN CATCH
    PRINT '    [FALLO INESPERADO] ' + ERROR_MESSAGE();
END CATCH;
GO

-- 3.2 Test: Alta Fallida (PK repetida, Confederación inexistente y Grupo fuera de dominio)
--------------------------------------------------------------------------------
PRINT '3.2 Test: Bloqueo de alta por PK repetida y dominios erróneos';
BEGIN TRY
    EXEC torneo.sp_SELECCION_ABM 
        @Accion = 'A',
        @Id_Seleccion = 1001,      -- PK repetida
        @Id_Confederacion = 9999,  -- Confederación inexistente
        @Id_Pais = 'ARG',
        @Nombre_Seleccion = 'Seleccion Fallida',
        @Grupo = 'Z';              -- Grupo fuera del rango A-L

    PRINT '    [FALLO] No debió permitir la inserción.';
END TRY
BEGIN CATCH
    PRINT '    [OK - RESULTADO ESPERADO]: ' + ERROR_MESSAGE();
END CATCH;
GO

-- 3.3 Test: Modificación Exitosa
--------------------------------------------------------------------------------
PRINT '3.3 Test: Modificación Exitosa de atributos';
BEGIN TRY
    EXEC torneo.sp_SELECCION_ABM 
        @Accion = 'M',
        @Id_Seleccion = 1001,
        @Id_Confederacion = 1002,
        @Id_Pais = 'ARG',
        @Nombre_Seleccion = 'Seleccion Modificada',
        @Grupo = 'C';

    PRINT '    [OK] Selección 1001 modificada correctamente.';
END TRY
BEGIN CATCH
    PRINT '    [FALLO INESPERADO] ' + ERROR_MESSAGE();
END CATCH;
GO

-- 3.4 Test: Modificación Fallida (PK Inexistente)
--------------------------------------------------------------------------------
PRINT '3.4 Test: Bloqueo de modificación por PK inexistente';
BEGIN TRY
    EXEC torneo.sp_SELECCION_ABM 
        @Accion = 'M',
        @Id_Seleccion = 99999,     -- ID inexistente
        @Id_Confederacion = 1002,
        @Id_Pais = 'ARG',
        @Nombre_Seleccion = 'Seleccion Inexistente',
        @Grupo = 'C';

    PRINT '    [FALLO] No debió permitir modificar un ID inexistente.';
END TRY
BEGIN CATCH
    PRINT '    [OK - RESULTADO ESPERADO]: ' + ERROR_MESSAGE();
END CATCH;
GO

-- 3.5.0 Carga de datos dependientes para probar bloqueo de baja
--------------------------------------------------------------------------------
-- Selección secundaria y asignación de dependencias
INSERT INTO torneo.SELECCION (id_seleccion, id_pais, id_confederacion, nombre_seleccion, grupo_asignado)
VALUES (1000, 'ARG', 1001, 'Seleccion Base 1000', 'G');

INSERT INTO persona.JUGADOR (nro_doc, tipo_doc, posicion_habitual, club_origen, peso_kg, altura_cm, es_convocado)
VALUES ('1111111', 'Prueba', 'Delantero', 'Club Prueba', 79.24, 181.0, 1);

INSERT INTO torneo.CONVOCATORIA (id_seleccion, dorsal_oficial, nro_doc, tipo_doc, estado_convocatoria)
VALUES (1001, 10, '1111111', 'Prueba', 'Activo');

INSERT INTO torneo.PARTIDO (id_fase, nro_partido_fase, id_sede, id_seleccion_local, id_seleccion_visitante, fecha_hora_utc, fecha_hora_local, asistencia_oficial, goles_local, goles_visitante)
VALUES (123, 2, 20, 1001, 1000, '2026-10-18 10:00:00', '2026-10-18 10:00:00', 1, 0, 0);

INSERT INTO persona.CUERPO_TECNICO (nro_doc, tipo_doc, id_seleccion, cargo_tecnico)
VALUES ('1111113', 'Prueba', 1000, 'Entrenador');
GO

-- 3.5 Test: Baja Rechazada por Restricciones de Integridad / FK
--------------------------------------------------------------------------------
PRINT '3.5 Test: Bloqueo de eliminación por FKs dependientes (Partidos y Convocatorias)';
BEGIN TRY
    -- Intentamos borrar la selección 1001 que tiene Convocatoria y Partido
    EXEC torneo.sp_SELECCION_ABM 
        @Accion = 'B',
        @Id_Seleccion = 1001,
        @Id_Confederacion = 1002,
        @Id_Pais = 'ARG',
        @Nombre_Seleccion = 'Seleccion Test',
        @Grupo = 'C';

    PRINT '    [FALLO] No debió permitir eliminar una selección con registros dependientes.';
END TRY
BEGIN CATCH
    PRINT '    [OK - RESULTADO ESPERADO]: ' + ERROR_MESSAGE();
END CATCH;
GO

-- 3.6 Test: Baja Exitosa (Eliminación limpia sin dependencias)
--------------------------------------------------------------------------------
PRINT '3.6 Test: Baja Exitosa tras retirar dependencias';
-- Retiramos primero los registros hijos asociados a la selección 1001
DELETE FROM torneo.PARTIDO WHERE id_fase = 123;
DELETE FROM torneo.CONVOCATORIA WHERE id_seleccion = 1001 AND dorsal_oficial = 10;

BEGIN TRY
    EXEC torneo.sp_SELECCION_ABM 
        @Accion = 'B',
        @Id_Seleccion = 1001,
        @Id_Confederacion = 1002,
        @Id_Pais = 'ARG',
        @Nombre_Seleccion = 'Seleccion Test',
        @Grupo = 'C';

    PRINT '    [OK] Selección 1001 eliminada exitosamente sin dependencias.';
END TRY
BEGIN CATCH
    PRINT '    [FALLO INESPERADO] ' + ERROR_MESSAGE();
END CATCH;
GO

-- 3.7 Limpieza final de datos de prueba en orden estricto de integridad
--------------------------------------------------------------------------------
PRINT 'Limpiando datos de prueba...';

DELETE FROM torneo.PARTIDO WHERE id_fase = 123;
DELETE FROM torneo.CONVOCATORIA WHERE id_seleccion IN (1000, 1001);
DELETE FROM persona.CUERPO_TECNICO WHERE nro_doc = '1111113';
DELETE FROM persona.JUGADOR WHERE nro_doc = '1111111';

DELETE FROM persona.PERSONA WHERE nro_doc IN ('1111111', '1111113');
DELETE FROM torneo.SELECCION WHERE id_seleccion IN (1000, 1001);
DELETE FROM torneo.SEDE WHERE id_sede = 20;
DELETE FROM torneo.FASE_TORNEO WHERE id_fase = 123;

DELETE FROM geografia.PAIS WHERE id_pais IN ('ARG', 'BRZ');
DELETE FROM geografia.CONFEDERACION WHERE id_confederacion IN (1001, 1002);