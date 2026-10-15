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
             Procedures de ABM - Módulo 6 : Disciplinario y Control
             Matriz de Cobertura de Pruebas por SP:
             1. Caso 1 (Alta Exitosa): Inserción con datos válidos y completos.
             2. Caso 2 (Alta Fallida): Validación de PK duplicada, campos nulos y dominios.
             3. Caso 3 (Modificación Exitosa): Actualización de atributos sobre registros existentes.
             4. Caso 4 (Modificación Fallida): Error por intento de modificación de PK inexistente.
             5. Caso 5 (Baja Fallida): Bloqueo o error por intento de eliminación de PK inexistente.
             6. Caso 6 (Baja Exitosa): Eliminación limpia de registros sin dependencias.

---------------------------------------------------------
*/

USE DB_Mundial2026_Grupo10;
GO

PRINT '         INICIO DE PRUEBAS: MÓDULO 6 (DISCIPLINARIO Y CONTROL)  ';
GO

-- 6.1 SP: torneo.sp_SANCION_TARJETA_ABM
--------------------------------------------------------------------------------
PRINT '6.1 Test: torneo.sp_SANCION_TARJETA_ABM';

-- Caso 1: Alta Exitosa
PRINT '--> Caso 1: Insertando sanción con tarjeta de prueba válida (Fase 1, Partido 1, Tarjeta 99)...';
EXEC torneo.sp_SANCION_TARJETA_ABM 
    @Accion                = 'A', 
    @id_fase               = 1, 
    @nro_partido_fase      = 1, 
    @id_tarjeta            = 99, 
    @id_seleccion          = 1, 
    @dorsal_sancionado     = 10, 
    @minuto_sancion        = 35, 
    @minuto_sancion_extra  = NULL, 
    @tipo_tarjeta          = 'AMARILLA', 
    @motivo                = 'Falta táctica reiterada en mitad de cancha';

-- Verificación de inserción
SELECT id_fase, nro_partido_fase, id_tarjeta, id_seleccion, dorsal_sancionado, minuto_sancion, minuto_sancion_extra, tipo_tarjeta, motivo 
FROM torneo.SANCION_TARJETA 
WHERE id_fase = 1 AND nro_partido_fase = 1 AND id_tarjeta = 99;

-- Caso 2: Alta Fallida (PK duplicada, partido/convocado inexistente, minuto fuera de rango, tipo inválido y motivo vacío)
PRINT '--> Caso 2: Provocando errores de validación en Sanción Tarjeta (PK duplicada y dominios inválidos)...';
BEGIN TRY
    EXEC torneo.sp_SANCION_TARJETA_ABM 
        @Accion                = 'A', 
        @id_fase               = 1, 
        @nro_partido_fase      = 1, 
        @id_tarjeta            = 99,        -- Error: PK duplicada
        @id_seleccion          = 999,       -- Error: Convocado inexistente
        @dorsal_sancionado     = 99, 
        @minuto_sancion        = 135,       -- Error: Minuto fuera de rango (1..120)
        @minuto_sancion_extra  = -2,        -- Error: Minuto extra <= 0
        @tipo_tarjeta          = 'AZUL',    -- Error: Tipo de tarjeta inválido
        @motivo                = '';        -- Error: Motivo vacío
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Mensaje capturado]: ' + ERROR_MESSAGE();
END CATCH;

-- Caso 3: Modificación Exitosa
PRINT '--> Caso 3: Modificando datos de la sanción con tarjeta (Fase 1, Partido 1, Tarjeta 99)...';
EXEC torneo.sp_SANCION_TARJETA_ABM 
    @Accion                = 'M', 
    @id_fase               = 1, 
    @nro_partido_fase      = 1, 
    @id_tarjeta            = 99, 
    @id_seleccion          = 1, 
    @dorsal_sancionado     = 10, 
    @minuto_sancion        = 45, 
    @minuto_sancion_extra  = 2, 
    @tipo_tarjeta          = 'ROJA_DIRECTA', 
    @motivo                = 'Conducta violenta tras revisión VAR';

SELECT id_fase, nro_partido_fase, id_tarjeta, minuto_sancion, minuto_sancion_extra, tipo_tarjeta, motivo 
FROM torneo.SANCION_TARJETA 
WHERE id_fase = 1 AND nro_partido_fase = 1 AND id_tarjeta = 99;

-- Caso 4: Modificación Fallida (PK Inexistente)
PRINT '--> Caso 4: Intentando modificar sanción con tarjeta inexistente (Tarjeta 999)...';
BEGIN TRY
    EXEC torneo.sp_SANCION_TARJETA_ABM 
        @Accion                = 'M', 
        @id_fase               = 1, 
        @nro_partido_fase      = 1, 
        @id_tarjeta            = 999, 
        @id_seleccion          = 1, 
        @dorsal_sancionado     = 10, 
        @minuto_sancion        = 50, 
        @minuto_sancion_extra  = NULL, 
        @tipo_tarjeta          = 'AMARILLA', 
        @motivo                = 'No Existe';
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Error capturado]: ' + ERROR_MESSAGE();
END CATCH;

-- Caso 5: Baja Fallida (PK Inexistente)
PRINT '--> Caso 5: Intentando eliminar sanción con tarjeta inexistente (Tarjeta 999)...';
BEGIN TRY
    EXEC torneo.sp_SANCION_TARJETA_ABM 
        @Accion           = 'B', 
        @id_fase          = 1, 
        @nro_partido_fase = 1, 
        @id_tarjeta       = 999;
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Error capturado]: ' + ERROR_MESSAGE();
END CATCH;

-- Caso 6: Baja Exitosa
PRINT '--> Caso 6: Eliminando sanción con tarjeta de prueba (Tarjeta 99)...';
EXEC torneo.sp_SANCION_TARJETA_ABM 
    @Accion           = 'B', 
    @id_fase          = 1, 
    @nro_partido_fase = 1, 
    @id_tarjeta       = 99;

SELECT COUNT(*) AS Existe_Tarjeta_99 
FROM torneo.SANCION_TARJETA 
WHERE id_fase = 1 AND nro_partido_fase = 1 AND id_tarjeta = 99;
GO

-- 6.2 SP: torneo.sp_CONTROL_SUSPENSION_ABM
--------------------------------------------------------------------------------
PRINT '6.2 Test: torneo.sp_CONTROL_SUSPENSION_ABM';

-- Limpieza preventiva por si el jugador de prueba ya tenía un registro previo en CONTROL_SUSPENSION
IF EXISTS (SELECT 1 FROM torneo.CONTROL_SUSPENSION WHERE id_seleccion = 1 AND dorsal_oficial = 10)
    EXEC torneo.sp_CONTROL_SUSPENSION_ABM @Accion = 'B', @id_seleccion = 1, @dorsal_oficial = 10;

-- Caso 1: Alta Exitosa
PRINT '--> Caso 1: Registrando control de suspensión para Selección 1, Dorsal 10...';
EXEC torneo.sp_CONTROL_SUSPENSION_ABM 
    @Accion               = 'A', 
    @id_seleccion         = 1, 
    @dorsal_oficial       = 10, 
    @amarillas_acumuladas = 1, 
    @partidos_suspension  = 0, 
    @cumplida             = 0;

SELECT * FROM torneo.CONTROL_SUSPENSION WHERE id_seleccion = 1 AND dorsal_oficial = 10;

-- Caso 2: Alta Fallida (PK duplicada, amarillas negativas, suspensión negativa y cumplida nula)
PRINT '--> Caso 2: Provocando errores de validación en Control Suspensión...';
BEGIN TRY
    EXEC torneo.sp_CONTROL_SUSPENSION_ABM 
        @Accion               = 'A', 
        @id_seleccion         = 1, 
        @dorsal_oficial       = 10,     -- Error: PK duplicada
        @amarillas_acumuladas = -1,     -- Error: Amarillas < 0
        @partidos_suspension  = -2,     -- Error: Partidos suspensión < 0
        @cumplida             = NULL;   -- Error: Cumplida nula
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Error capturado]: ' + ERROR_MESSAGE();
END CATCH;

-- Caso 3: Modificación Exitosa
PRINT '--> Caso 3: Modificando control de suspensión (Selección 1, Dorsal 10)...';
EXEC torneo.sp_CONTROL_SUSPENSION_ABM 
    @Accion               = 'M', 
    @id_seleccion         = 1, 
    @dorsal_oficial       = 10, 
    @amarillas_acumuladas = 2, 
    @partidos_suspension  = 1, 
    @cumplida             = 1;

SELECT * FROM torneo.CONTROL_SUSPENSION WHERE id_seleccion = 1 AND dorsal_oficial = 10;

-- Caso 4: Modificación Fallida (PK / Convocado Inexistente)
PRINT '--> Caso 4: Intentando modificar control de suspensión inexistente (Dorsal 99)...';
BEGIN TRY
    EXEC torneo.sp_CONTROL_SUSPENSION_ABM 
        @Accion               = 'M', 
        @id_seleccion         = 1, 
        @dorsal_oficial       = 99, 
        @amarillas_acumuladas = 0, 
        @partidos_suspension  = 0, 
        @cumplida             = 0;
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Error capturado]: ' + ERROR_MESSAGE();
END CATCH;

-- Caso 6: Baja Exitosa
PRINT '--> Caso 6: Eliminando control de suspensión de prueba (Selección 1, Dorsal 10)...';
EXEC torneo.sp_CONTROL_SUSPENSION_ABM 
    @Accion         = 'B', 
    @id_seleccion   = 1, 
    @dorsal_oficial = 10;

SELECT COUNT(*) AS Existe_Control_Suspension 
FROM torneo.CONTROL_SUSPENSION 
WHERE id_seleccion = 1 AND dorsal_oficial = 10;
GO

PRINT '         FIN DE PRUEBAS: MÓDULO 6 (DISCIPLINARIO Y CONTROL) - ÉXITO        ';
GO