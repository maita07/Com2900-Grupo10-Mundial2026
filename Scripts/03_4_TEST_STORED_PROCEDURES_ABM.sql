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

PRINT '         INICIO DE PRUEBAS: MÓDULO 4 (CONVOCATORIAS E INCIDENCIAS)  ';
GO

-- 4.0 Preparacion de datos para test (Incercion manual)
--------------------------------------------------------------------------------
INSERT INTO geografia.CONFEDERACION (id_confederacion, nombre_confederacion, sigla)
VALUES (999, 'Confederacion Test', 'CTST');

INSERT INTO geografia.PAIS (id_pais, nombre_pais, moneda_pais, pbi_per_capita_actual)
VALUES ('TST', 'Pais Test', 'Pesos', 15000.00);

INSERT INTO torneo.SELECCION (id_seleccion, id_pais, id_confederacion, nombre_seleccion, grupo_asignado)
VALUES (999, 'TST', 999, 'Seleccion Test', 'A');

INSERT INTO persona.PERSONA (nro_doc, tipo_doc, id_nacionalidad_pais, nombre, apellido, fecha_nacimiento, tipo_persona)
VALUES ('TEST_JUG1', 'DNI', 'TST', 'Lionel', 'Test', '2000-01-01', 'JUGADOR'),
       ('TEST_JUG2', 'DNI', 'TST', 'Angel', 'Test', '2000-05-15', 'JUGADOR');

INSERT INTO persona.JUGADOR (nro_doc, tipo_doc, posicion_habitual, club_origen, peso_kg, altura_cm, es_convocado)
VALUES ('TEST_JUG1', 'DNI', 'Delantero', 'Club Test', 72.0, 170.0, 0),
       ('TEST_JUG2', 'DNI', 'Extremo', 'Club Test', 75.0, 180.0, 0);

-- CASO 1: Alta Exitosa (Inserción con datos válidos y completos)
--------------------------------------------------------------------------------
BEGIN TRY
    EXEC torneo.sp_CONVOCATORIA_ABM 
        @Accion = 'A',
        @id_seleccion = 999,
        @dorsal_oficial = 10,
        @nro_doc = 'TEST_JUG1',
        @tipo_doc = 'DNI',
        @estado_convocatoria = 'ACTIVO';

    PRINT 'CASO 1: OK - Alta exitosa registrada correctamente.';
END TRY
BEGIN CATCH
    PRINT 'CASO 1: FALLO INESPERADO - ' + ERROR_MESSAGE();
END CATCH;

-- CASO 2: Alta Fallida (Validación de PK duplicada, campos nulos y dominios)
--------------------------------------------------------------------------------
-- 2.1 PK Duplicada
BEGIN TRY
    EXEC torneo.sp_CONVOCATORIA_ABM 
        @Accion = 'A',
        @id_seleccion = 999,
        @dorsal_oficial = 10,
        @nro_doc = 'TEST_JUG2',
        @tipo_doc = 'DNI',
        @estado_convocatoria = 'ACTIVO';

    PRINT 'CASO 2.1: FALLO - Debió rechazar por PK Duplicada.';
END TRY
BEGIN CATCH
    PRINT 'CASO 2.1: OK - PK Duplicada rechazada correctamente: ' + ERROR_MESSAGE();
END CATCH;

-- 2.2 Dominio inválido (dorsal fuera de 1-99)
BEGIN TRY
    EXEC torneo.sp_CONVOCATORIA_ABM 
        @Accion = 'A',
        @id_seleccion = 999,
        @dorsal_oficial = 150,
        @nro_doc = 'TEST_JUG2',
        @tipo_doc = 'DNI',
        @estado_convocatoria = 'ACTIVO';

    PRINT 'CASO 2.2: FALLO - Debió rechazar dorsal > 99.';
END TRY
BEGIN CATCH
    PRINT 'CASO 2.2: OK - Dominio incorrecto rechazado: ' + ERROR_MESSAGE();
END CATCH;

-- CASO 3: Modificación Exitosa (Actualización de atributos sobre registro existente)
--------------------------------------------------------------------------------
BEGIN TRY
    EXEC torneo.sp_CONVOCATORIA_ABM 
        @Accion = 'M',
        @id_seleccion = 999,
        @dorsal_oficial = 10,
        @nro_doc = 'TEST_JUG1',
        @tipo_doc = 'DNI',
        @estado_convocatoria = 'LESIONADO';

    PRINT 'CASO 3: OK - Modificación exitosa aplicada.';
END TRY
BEGIN CATCH
    PRINT 'CASO 3: FALLO INESPERADO - ' + ERROR_MESSAGE();
END CATCH;

-- CASO 4: Modificación Fallida (Error por intento de modificación de PK inexistente)
--------------------------------------------------------------------------------
BEGIN TRY
    EXEC torneo.sp_CONVOCATORIA_ABM 
        @Accion = 'M',
        @id_seleccion = 999,
        @dorsal_oficial = 99, -- PK no registrada
        @estado_convocatoria = 'SUSPENDIDO';

    PRINT 'CASO 4: FALLO - Debió rechazar modificación sobre registro inexistente.';
END TRY
BEGIN CATCH
    PRINT 'CASO 4: OK - Modificación de PK inexistente rechazada: ' + ERROR_MESSAGE();
END CATCH;

-- CASO 5: Baja Rechazada (Bloqueo de eliminación por FK dependiente en INCIDENCIA)
--------------------------------------------------------------------------------
-- Insertamos una incidencia hija vinculada a la convocatoria (999, dorsal 10)
INSERT INTO torneo.INCIDENCIA_CONVOCATORIA (id_seleccion, dorsal_oficial, fecha_incidencia, motivo_baja_lesion, es_baja_definitiva)
VALUES (999, 10, GETDATE(), 'Esguince de tobillo', 0);

BEGIN TRY
    EXEC torneo.sp_CONVOCATORIA_ABM 
        @Accion = 'B',
        @id_seleccion = 999,
        @dorsal_oficial = 10;

    PRINT 'CASO 5: FALLO - Debió bloquear la baja por tener incidencia asociada.';
END TRY
BEGIN CATCH
    PRINT 'CASO 5: OK - Eliminación bloqueada por FK/dependencia: ' + ERROR_MESSAGE();
END CATCH;

-- Limpieza de la incidencia para habilitar el Caso 6
DELETE FROM torneo.INCIDENCIA_CONVOCATORIA WHERE id_seleccion = 999 AND dorsal_oficial = 10;

-- CASO 6: Baja Exitosa (Eliminación limpia de registro sin dependencias)
--------------------------------------------------------------------------------
BEGIN TRY
    EXEC torneo.sp_CONVOCATORIA_ABM 
        @Accion = 'B',
        @id_seleccion = 999,
        @dorsal_oficial = 10;

    PRINT 'CASO 6: OK - Baja ejecutada limpiamente sin dependencias.';
END TRY
BEGIN CATCH
    PRINT 'CASO 6: FALLO INESPERADO - ' + ERROR_MESSAGE();
END CATCH;

-- LIMPIEZA FINAL DE DATOS DE PRUEBA
--------------------------------------------------------------------------------
DELETE FROM torneo.INCIDENCIA_CONVOCATORIA WHERE id_seleccion = 999;
DELETE FROM torneo.CONVOCATORIA WHERE id_seleccion = 999;
DELETE FROM persona.JUGADOR WHERE nro_doc IN ('TEST_JUG1', 'TEST_JUG2');
DELETE FROM persona.PERSONA WHERE nro_doc IN ('TEST_JUG1', 'TEST_JUG2');
DELETE FROM torneo.SELECCION WHERE id_seleccion = 999;
DELETE FROM geografia.PAIS WHERE id_pais = 'TST';
DELETE FROM geografia.CONFEDERACION WHERE id_confederacion = 999;
GO

-- 4.2 Preparacion de datos para test (Incercion manual)
--------------------------------------------------------------------------------
PRINT '--------------------------------------------------------------------------------' 
PRINT CHAR(13) + 'INICIO TEST sp_INCIDENCIAS_CONVOCATORIA' + CHAR(13);

INSERT INTO geografia.CONFEDERACION (id_confederacion, nombre_confederacion, sigla)
VALUES (888, 'Confederacion Incidencias', 'CINC');

INSERT INTO geografia.PAIS (id_pais, nombre_pais, moneda_pais, pbi_per_capita_actual)
VALUES ('TIN', 'Pais Incidencia', 'Moneda', 20000.00);

INSERT INTO torneo.SELECCION (id_seleccion, id_pais, id_confederacion, nombre_seleccion, grupo_asignado)
VALUES (888, 'TIN', 888, 'Seleccion Incidencia', 'B');

INSERT INTO persona.PERSONA (nro_doc, tipo_doc, id_nacionalidad_pais, nombre, apellido, fecha_nacimiento, tipo_persona)
VALUES ('INC_JUG1', 'DNI', 'TIN', 'Carlos', 'Prueba', '1998-04-10', 'JUGADOR');

INSERT INTO persona.JUGADOR (nro_doc, tipo_doc, posicion_habitual, club_origen, peso_kg, altura_cm, es_convocado)
VALUES ('INC_JUG1', 'DNI', 'Mediocampista', 'Club Test', 70.0, 175.0, 1);

INSERT INTO torneo.CONVOCATORIA (id_seleccion, dorsal_oficial, nro_doc, tipo_doc, estado_convocatoria)
VALUES (888, 7, 'INC_JUG1', 'DNI', 'ACTIVO');

-- CASO 1: Alta Exitosa (Inserción con datos válidos y completos)
--------------------------------------------------------------------------------
BEGIN TRY
    EXEC torneo.sp_INCIDENCIA_CONVOCATORIA_ABM
        @Accion = 'A',
        @id_seleccion = 888,
        @dorsal_oficial = 7,
        @fecha_incidencia = '2026-06-15',
        @motivo_baja_lesion = 'Desgarro en cuadriceps derecho',
        @es_baja_definitiva = 1;

    PRINT 'CASO 1: OK - Alta exitosa registrada correctamente.';
END TRY
BEGIN CATCH
    PRINT 'CASO 1: FALLO INESPERADO - ' + ERROR_MESSAGE();
END CATCH;

-- CASO 2: Alta Fallida (PK duplicada, campos nulos y dominios)
--------------------------------------------------------------------------------
-- 2.1 Intento de inserción con PK Duplicada (misma selección, dorsal y fecha)
BEGIN TRY
    EXEC torneo.sp_INCIDENCIA_CONVOCATORIA_ABM
        @Accion = 'A',
        @id_seleccion = 888,
        @dorsal_oficial = 7,
        @fecha_incidencia = '2026-06-15',
        @motivo_baja_lesion = 'Nueva lesion misma fecha',
        @es_baja_definitiva = 0;

    PRINT 'CASO 2.1: FALLO - Debió rechazar por PK duplicada.';
END TRY
BEGIN CATCH
    PRINT 'CASO 2.1: OK - PK duplicada rechazada: ' + ERROR_MESSAGE();
END CATCH;

-- 2.2 Validación de dominio / longitud (motivo < 10 caracteres)
BEGIN TRY
    EXEC torneo.sp_INCIDENCIA_CONVOCATORIA_ABM
        @Accion = 'A',
        @id_seleccion = 888,
        @dorsal_oficial = 7,
        @fecha_incidencia = '2026-06-20',
        @motivo_baja_lesion = 'Golpe', -- Menor a 10 caracteres
        @es_baja_definitiva = 0;

    PRINT 'CASO 2.2: FALLO - Debió rechazar por motivo demasiado corto.';
END TRY
BEGIN CATCH
    PRINT 'CASO 2.2: OK - Validación de dominio rechazada: ' + ERROR_MESSAGE();
END CATCH;

-- CASO 3: Modificación Exitosa (Actualización sobre registro existente)
--------------------------------------------------------------------------------
BEGIN TRY
    EXEC torneo.sp_INCIDENCIA_CONVOCATORIA_ABM
        @Accion = 'M',
        @id_seleccion = 888,
        @dorsal_oficial = 7,
        @fecha_incidencia = '2026-06-15',
        @motivo_baja_lesion = 'Rotura fibrilar grado 2 comprobada',
        @es_baja_definitiva = 1;

    PRINT 'CASO 3: OK - Modificación exitosa aplicada.';
END TRY
BEGIN CATCH
    PRINT 'CASO 3: FALLO INESPERADO - ' + ERROR_MESSAGE();
END CATCH;

-- CASO 4: Modificación Fallida (Error por PK inexistente)
--------------------------------------------------------------------------------
BEGIN TRY
    EXEC torneo.sp_INCIDENCIA_CONVOCATORIA_ABM
        @Accion = 'M',
        @id_seleccion = 888,
        @dorsal_oficial = 7,
        @fecha_incidencia = '2026-12-31', -- Fecha no existente
        @motivo_baja_lesion = 'Modificación de fecha inexistente',
        @es_baja_definitiva = 0;

    PRINT 'CASO 4: FALLO - Debió rechazar modificación por PK inexistente.';
END TRY
BEGIN CATCH
    PRINT 'CASO 4: OK - Modificación de PK inexistente rechazada: ' + ERROR_MESSAGE();
END CATCH;

-- CASO 5: Rechazo por Restricción de Clave Foránea (FK inexistente)
--------------------------------------------------------------------------------
-- Intentar registrar incidencia sobre un dorsal que no existe en CONVOCATORIA
BEGIN TRY
    EXEC torneo.sp_INCIDENCIA_CONVOCATORIA_ABM
        @Accion = 'A',
        @id_seleccion = 888,
        @dorsal_oficial = 99, -- Convocatoria no existente
        @fecha_incidencia = '2026-06-15',
        @motivo_baja_lesion = 'Fractura de menisco derecho',
        @es_baja_definitiva = 1;

    PRINT 'CASO 5: FALLO - Debió bloquear por violación de clave foránea hacia CONVOCATORIA.';
END TRY
BEGIN CATCH
    PRINT 'CASO 5: OK - Bloqueo por restricción de FK exitoso: ' + ERROR_MESSAGE();
END CATCH;

-- CASO 6: Baja Exitosa (Eliminación limpia del registro)
--------------------------------------------------------------------------------
BEGIN TRY
    EXEC torneo.sp_INCIDENCIA_CONVOCATORIA_ABM
        @Accion = 'B',
        @id_seleccion = 888,
        @dorsal_oficial = 7,
        @fecha_incidencia = '2026-06-15';

    PRINT 'CASO 6: OK - Baja ejecutada limpiamente.';
END TRY
BEGIN CATCH
    PRINT 'CASO 6: FALLO INESPERADO - ' + ERROR_MESSAGE();
END CATCH;

-- LIMPIEZA FINAL DE DATOS DE PRUEBA
--------------------------------------------------------------------------------
DELETE FROM torneo.INCIDENCIA_CONVOCATORIA WHERE id_seleccion = 888;
DELETE FROM torneo.CONVOCATORIA WHERE id_seleccion = 888;
DELETE FROM persona.JUGADOR WHERE nro_doc = 'INC_JUG1';
DELETE FROM persona.PERSONA WHERE nro_doc = 'INC_JUG1';
DELETE FROM torneo.SELECCION WHERE id_seleccion = 888;
DELETE FROM geografia.PAIS WHERE id_pais = 'TIN';
DELETE FROM geografia.CONFEDERACION WHERE id_confederacion = 888;