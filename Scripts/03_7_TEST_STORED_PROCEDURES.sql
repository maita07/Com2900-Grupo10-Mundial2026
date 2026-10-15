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
             Procedures de ABM - Módulo 7 : Publicidad y Comercial
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

PRINT '         INICIO DE PRUEBAS: MÓDULO 7 (PUBLICIDAD Y COMERCIAL)  ';
GO

-- 7.1 SP: comercial.sp_ANUNCIANTE_ABM
--------------------------------------------------------------------------------
PRINT '7.1 Test: comercial.sp_ANUNCIANTE_ABM';

-- Caso 1: Alta Exitosa
PRINT '--> Caso 1: Insertando anunciante de prueba válido (ID 999)...';
EXEC comercial.sp_ANUNCIANTE_ABM 
    @Accion          = 'A', 
    @id_anunciante   = 999, 
    @id_pais_origen  = 'ARG', 
    @razon_social    = 'Anunciante Prueba S.A.', 
    @marca_comercial = 'Marca Test', 
    @rubro           = 'Tecnología';

-- Verificación de inserción
SELECT id_anunciante, id_pais_origen, razon_social, marca_comercial, rubro 
FROM comercial.ANUNCIANTE 
WHERE id_anunciante = 999;

-- Caso 2: Alta Fallida (PK duplicada, País inexistente y campos vacíos)
PRINT '--> Caso 2: Provocando errores de validación (PK duplicada, país inexistente y campos vacíos)...';
BEGIN TRY
    EXEC comercial.sp_ANUNCIANTE_ABM 
        @Accion          = 'A', 
        @id_anunciante   = 999,     -- Error: PK duplicada
        @id_pais_origen  = 'NON',   -- Error: País inexistente
        @razon_social    = '',      -- Error: Razón social vacía
        @marca_comercial = '',      -- Error: Marca comercial vacía
        @rubro           = '';      -- Error: Rubro vacío
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Mensaje capturado]: ' + ERROR_MESSAGE();
END CATCH;

-- Caso 3: Modificación Exitosa
PRINT '--> Caso 3: Modificando datos del anunciante (ID 999)...';
EXEC comercial.sp_ANUNCIANTE_ABM 
    @Accion          = 'M', 
    @id_anunciante   = 999, 
    @id_pais_origen  = 'ARG', 
    @razon_social    = 'Anunciante Prueba Modificado S.A.', 
    @marca_comercial = 'Marca Test Pro', 
    @rubro           = 'Telecomunicaciones';

-- Caso 4: Modificación Fallida (PK Inexistente)
PRINT '--> Caso 4: Intentando modificar anunciante inexistente (ID 9999)...';
BEGIN TRY
    EXEC comercial.sp_ANUNCIANTE_ABM 
        @Accion          = 'M', 
        @id_anunciante   = 9999, 
        @id_pais_origen  = 'ARG', 
        @razon_social    = 'No Existe', 
        @marca_comercial = 'N/A', 
        @rubro           = 'N/A';
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Error capturado]: ' + ERROR_MESSAGE();
END CATCH;

-- Se registra una campaña temporal vinculada al anunciante 999 para probar la restricción de Baja (Caso 5)
EXEC comercial.sp_CAMPANIA_PUBLICITARIA_ABM 'A', 999, 999, 'Campaña Auxiliar FK', 10000.00, '2026-06-01', '2026-07-01';

-- Caso 5: Baja Rechazada por FK (Anunciante con campañas registradas)
PRINT '--> Caso 5: Intentando eliminar un anunciante con campañas vinculadas (ID 999)...';
BEGIN TRY
    EXEC comercial.sp_ANUNCIANTE_ABM 
        @Accion        = 'B', 
        @id_anunciante = 999;
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Bloqueo de eliminación por FK]: ' + ERROR_MESSAGE();
END CATCH;

-- Se elimina la campaña temporal para liberar al anunciante y probar su Baja Exitosa (Caso 6)
EXEC comercial.sp_CAMPANIA_PUBLICITARIA_ABM 'B', 999;

-- Caso 6: Baja Exitosa
PRINT '--> Caso 6: Eliminando anunciante de prueba (ID 999)...';
EXEC comercial.sp_ANUNCIANTE_ABM 
    @Accion        = 'B', 
    @id_anunciante = 999;

SELECT COUNT(*) AS Existe_Anunciante_999 FROM comercial.ANUNCIANTE WHERE id_anunciante = 999;
GO

-- 7.2 SP: comercial.sp_CAMPANIA_PUBLICITARIA_ABM
--------------------------------------------------------------------------------
PRINT '7.2 Test: comercial.sp_CAMPANIA_PUBLICITARIA_ABM';

-- Se crea un anunciante temporal auxiliar para asociarle campañas
EXEC comercial.sp_ANUNCIANTE_ABM 'A', 999, 'ARG', 'Anunciante Auxiliar', 'Marca Aux', 'Deportes';

-- Caso 1: Alta Exitosa
PRINT '--> Caso 1: Registrando campaña publicitaria válida (ID 999)...';
EXEC comercial.sp_CAMPANIA_PUBLICITARIA_ABM 
    @Accion              = 'A', 
    @id_campania         = 999, 
    @id_anunciante       = 999, 
    @nombre_campania     = 'Campaña Mundialista 2026', 
    @presupuesto_max_usd = 500000.00, 
    @fecha_inicio        = '2026-06-01', 
    @fecha_fin           = '2026-07-19';

SELECT * FROM comercial.CAMPANIA_PUBLICITARIA WHERE id_campania = 999;

-- Caso 2: Alta Fallida (PK duplicada, anunciante inexistente, presupuesto <= 0 y fecha_fin < fecha_inicio)
PRINT '--> Caso 2: Provocando errores de validación en Campaña Publicitaria...';
BEGIN TRY
    EXEC comercial.sp_CAMPANIA_PUBLICITARIA_ABM 
        @Accion              = 'A', 
        @id_campania         = 999,          -- Error: PK duplicada
        @id_anunciante       = 9999,         -- Error: Anunciante inexistente
        @nombre_campania     = '',           -- Error: Nombre vacío
        @presupuesto_max_usd = -100.00,      -- Error: Presupuesto <= 0
        @fecha_inicio        = '2026-07-20', 
        @fecha_fin           = '2026-06-01'; -- Error: fecha_fin < fecha_inicio
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Error capturado]: ' + ERROR_MESSAGE();
END CATCH;

-- Caso 3: Modificación Exitosa
PRINT '--> Caso 3: Modificando campaña publicitaria (ID 999)...';
EXEC comercial.sp_CAMPANIA_PUBLICITARIA_ABM 
    @Accion              = 'M', 
    @id_campania         = 999, 
    @id_anunciante       = 999, 
    @nombre_campania     = 'Campaña Mundialista 2026 Extendida', 
    @presupuesto_max_usd = 750000.00, 
    @fecha_inicio        = '2026-06-01', 
    @fecha_fin           = '2026-07-31';

-- Caso 4: Modificación Fallida (PK Inexistente)
PRINT '--> Caso 4: Intentando modificar campaña inexistente (ID 9999)...';
BEGIN TRY
    EXEC comercial.sp_CAMPANIA_PUBLICITARIA_ABM 
        @Accion              = 'M', 
        @id_campania         = 9999, 
        @id_anunciante       = 999, 
        @nombre_campania     = 'No Existe', 
        @presupuesto_max_usd = 1000.00, 
        @fecha_inicio        = '2026-06-01', 
        @fecha_fin           = '2026-06-15';
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Error capturado]: ' + ERROR_MESSAGE();
END CATCH;

-- Se registra una pieza temporal para probar bloqueo de Baja en campaña (Caso 5)
EXEC comercial.sp_PIEZA_PUBLICITARIA_ABM 'A', 999, 999, 'https://test.com/ad.mp4', 15, 'ES', 'Pieza Auxiliar FK';

-- Caso 5: Baja Rechazada por FK (Campaña con piezas publicitarias vinculadas)
PRINT '--> Caso 5: Intentando eliminar campaña con piezas vinculadas (ID 999)...';
BEGIN TRY
    EXEC comercial.sp_CAMPANIA_PUBLICITARIA_ABM 
        @Accion      = 'B', 
        @id_campania = 999;
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Bloqueo de eliminación por FK]: ' + ERROR_MESSAGE();
END CATCH;

-- Se limpia la pieza temporal para permitir la Baja de la campaña
EXEC comercial.sp_PIEZA_PUBLICITARIA_ABM 'B', 999;

-- Caso 6: Baja Exitosa
PRINT '--> Caso 6: Eliminando campaña publicitaria (ID 999)...';
EXEC comercial.sp_CAMPANIA_PUBLICITARIA_ABM 
    @Accion      = 'B', 
    @id_campania = 999;
GO

-- 7.3 SP: comercial.sp_PIEZA_PUBLICITARIA_ABM
--------------------------------------------------------------------------------
PRINT '7.3 Test: comercial.sp_PIEZA_PUBLICITARIA_ABM';

-- Se recrea la campaña auxiliar 999 para asociarle piezas publicitarias
EXEC comercial.sp_CAMPANIA_PUBLICITARIA_ABM 'A', 999, 999, 'Campaña Auxiliar Piezas', 500000.00, '2026-06-01', '2026-07-19';

-- Caso 1: Alta Exitosa
PRINT '--> Caso 1: Registrando pieza publicitaria válida (ID 999)...';
EXEC comercial.sp_PIEZA_PUBLICITARIA_ABM 
    @Accion            = 'A', 
    @id_pieza          = 999, 
    @id_campania       = 999, 
    @url_contenido     = 'https://cdn.mundial2026.com/spot_test.mp4', 
    @duracion_segundos = 15, 
    @idioma            = 'ES', 
    @descripcion_pieza = 'Spot LED estático de prueba';

SELECT * FROM comercial.PIEZA_PUBLICITARIA WHERE id_pieza = 999;

-- Caso 2: Alta Fallida (Duración <= 0, campaña inexistente y textos vacíos)
PRINT '--> Caso 2: Provocando errores de validación en Pieza Publicitaria...';
BEGIN TRY
    EXEC comercial.sp_PIEZA_PUBLICITARIA_ABM 
        @Accion            = 'A', 
        @id_pieza          = 999,   -- Error: PK duplicada
        @id_campania       = 9999,  -- Error: Campaña inexistente
        @url_contenido     = '',    -- Error: URL vacía
        @duracion_segundos = 0,     -- Error: Duración <= 0
        @idioma            = '',    -- Error: Idioma vacío
        @descripcion_pieza = '';    -- Error: Descripción vacía
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Error capturado]: ' + ERROR_MESSAGE();
END CATCH;

-- Caso 3: Modificación Exitosa
PRINT '--> Caso 3: Modificando pieza publicitaria (ID 999)...';
EXEC comercial.sp_PIEZA_PUBLICITARIA_ABM 
    @Accion            = 'M', 
    @id_pieza          = 999, 
    @id_campania       = 999, 
    @url_contenido     = 'https://cdn.mundial2026.com/spot_test_v2.mp4', 
    @duracion_segundos = 30, 
    @idioma            = 'EN', 
    @descripcion_pieza = 'Spot LED animado versión inglés';

-- Caso 4: Modificación Fallida (PK Inexistente)
PRINT '--> Caso 4: Intentando modificar pieza inexistente (ID 9999)...';
BEGIN TRY
    EXEC comercial.sp_PIEZA_PUBLICITARIA_ABM 
        @Accion            = 'M', 
        @id_pieza          = 9999, 
        @id_campania       = 999, 
        @url_contenido     = 'https://cdn.mundial2026.com/no_existe.mp4', 
        @duracion_segundos = 10, 
        @idioma            = 'ES', 
        @descripcion_pieza = 'No Existe';
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Error capturado]: ' + ERROR_MESSAGE();
END CATCH;

-- Se registra una exhibición temporal para probar bloqueo de Baja en pieza (Caso 5)
EXEC comercial.sp_EXHIBICION_PUBLICITARIA_ABM 'A', 999, 1, 1, 999, 999, 999, 1, 5, 10, 15000.00;

-- Caso 5: Baja Rechazada por FK (Pieza con exhibiciones registradas)
PRINT '--> Caso 5: Intentando eliminar pieza con exhibiciones registradas (ID 999)...';
BEGIN TRY
    EXEC comercial.sp_PIEZA_PUBLICITARIA_ABM 
        @Accion   = 'B', 
        @id_pieza = 999;
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Bloqueo de eliminación por FK]: ' + ERROR_MESSAGE();
END CATCH;

-- Se elimina la exhibición temporal para liberar la pieza
EXEC comercial.sp_EXHIBICION_PUBLICITARIA_ABM 'B', 999;

-- Caso 6: Baja Exitosa
PRINT '--> Caso 6: Eliminando pieza publicitaria (ID 999)...';
EXEC comercial.sp_PIEZA_PUBLICITARIA_ABM 
    @Accion   = 'B', 
    @id_pieza = 999;
GO

-- 7.4 SP: comercial.sp_EXHIBICION_PUBLICITARIA_ABM
--------------------------------------------------------------------------------
PRINT '7.4 Test: comercial.sp_EXHIBICION_PUBLICITARIA_ABM';

-- Se recrea la pieza auxiliar 999 para probar las exhibiciones
EXEC comercial.sp_PIEZA_PUBLICITARIA_ABM 'A', 999, 999, 'https://cdn.mundial2026.com/spot_test.mp4', 15, 'ES', 'Spot Auxiliar Exhibicion';

-- Caso 1: Alta Exitosa
PRINT '--> Caso 1: Registrando exhibición publicitaria de prueba (ID 999)...';
EXEC comercial.sp_EXHIBICION_PUBLICITARIA_ABM 
    @Accion              = 'A', 
    @id_exhibicion       = 999, 
    @id_fase             = 1, 
    @nro_partido_fase    = 1, 
    @id_anunciante       = 999, 
    @id_campania         = 999, 
    @id_pieza            = 999, 
    @letrero_posicion    = 1, 
    @minuto_inicio       = 10, 
    @minuto_fin          = 15, 
    @costo_calculado_usd = 25000.00;

SELECT * FROM comercial.EXHIBICION_PUBLICITARIA WHERE id_exhibicion = 999;

-- Caso 2: Alta Fallida (PK duplicada, FKs inexistentes, letrero fuera de 1..4, minutos inválidos y costo negativo)
PRINT '--> Caso 2: Provocando errores de validación en Exhibición Publicitaria...';
BEGIN TRY
    EXEC comercial.sp_EXHIBICION_PUBLICITARIA_ABM 
        @Accion              = 'A', 
        @id_exhibicion       = 999,     -- Error: PK duplicada
        @id_fase             = 99,      -- Error: Partido inexistente
        @nro_partido_fase    = 99, 
        @id_anunciante       = 9999,    -- Error: Anunciante inexistente
        @id_campania         = 9999,    -- Error: Campaña inexistente
        @id_pieza            = 9999,    -- Error: Pieza inexistente
        @letrero_posicion    = 8,       -- Error: Letrero fuera de rango (1..4)
        @minuto_inicio       = -5,      -- Error: minuto_inicio < 0
        @minuto_fin          = -10,     -- Error: minuto_fin <= minuto_inicio
        @costo_calculado_usd = -500.00; -- Error: Costo < 0
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Error capturado]: ' + ERROR_MESSAGE();
END CATCH;

-- Caso 3: Modificación Exitosa
PRINT '--> Caso 3: Modificando exhibición publicitaria (ID 999)...';
EXEC comercial.sp_EXHIBICION_PUBLICITARIA_ABM 
    @Accion              = 'M', 
    @id_exhibicion       = 999, 
    @id_fase             = 1, 
    @nro_partido_fase    = 1, 
    @id_anunciante       = 999, 
    @id_campania         = 999, 
    @id_pieza            = 999, 
    @letrero_posicion    = 2, 
    @minuto_inicio       = 20, 
    @minuto_fin          = 30, 
    @costo_calculado_usd = 45000.00;

-- Caso 4: Modificación Fallida (PK Inexistente)
PRINT '--> Caso 4: Intentando modificar exhibición inexistente (ID 9999)...';
BEGIN TRY
    EXEC comercial.sp_EXHIBICION_PUBLICITARIA_ABM 
        @Accion              = 'M', 
        @id_exhibicion       = 9999, 
        @id_fase             = 1, 
        @nro_partido_fase    = 1, 
        @id_anunciante       = 999, 
        @id_campania         = 999, 
        @id_pieza            = 999, 
        @letrero_posicion    = 1, 
        @minuto_inicio       = 0, 
        @minuto_fin          = 5, 
        @costo_calculado_usd = 1000.00;
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Error capturado]: ' + ERROR_MESSAGE();
END CATCH;

-- Caso 6: Baja Exitosa y Limpieza de registros auxiliares del módulo
PRINT '--> Caso 6: Eliminando exhibición publicitaria y registros auxiliares (ID 999)...';
EXEC comercial.sp_EXHIBICION_PUBLICITARIA_ABM 
    @Accion        = 'B', 
    @id_exhibicion = 999;

EXEC comercial.sp_PIEZA_PUBLICITARIA_ABM 'B', 999;
EXEC comercial.sp_CAMPANIA_PUBLICITARIA_ABM 'B', 999;
EXEC comercial.sp_ANUNCIANTE_ABM 'B', 999;
GO

PRINT '         FIN DE PRUEBAS: MÓDULO 7 (PUBLICIDAD Y COMERCIAL) - ÉXITO        ';
GO