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
             Procedures de ABM - Módulo 1 : Geografia y Economia
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

PRINT '         INICIO DE PRUEBAS: MÓDULO 1 (GEOGRAFÍA Y ECONOMÍA)  ';
GO

-- 1.1 SP: geografia.sp_PAIS_ABM
--------------------------------------------------------------------------------
PRINT '1.1 Test: geografia.sp_PAIS_ABM';

-- Caso 1: Alta Exitosa
PRINT '--> Caso 1: Insertando país de prueba válido (ZZZ)...';
EXEC geografia.sp_PAIS_ABM 
    @Accion = 'A', 
    @id_pais = 'ZZZ', 
    @nombre_pais = 'País Prueba', 
    @moneda_pais = 'Dolar ', 
    @pbi_per_capita_actual = 25000.50;

-- Verificación de inserción
SELECT id_pais, nombre_pais, moneda_pais, pbi_per_capita_actual 
FROM geografia.PAIS 
WHERE id_pais = 'ZZZ';

-- Caso 2: Alta Fallida (PK duplicada y PBI negativo)
PRINT '--> Caso 2: Provocando errores de validación (PK duplicada y PBI negativo)...';
BEGIN TRY
    EXEC geografia.sp_PAIS_ABM 
        @Accion = 'A', 
        @id_pais = 'ZZZ',                   -- Error: PK duplicada
        @nombre_pais = '',                  -- Error: Nombre vacío
        @moneda_pais = 'Dolar', 
        @pbi_per_capita_actual = -100.00;   -- Error: PBI negativo
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Mensaje capturado]: ' + ERROR_MESSAGE();
END CATCH;

-- Caso 3: Modificación Exitosa
PRINT '--> Caso 3: Modificando datos del país ZZZ...';
EXEC geografia.sp_PAIS_ABM 
    @Accion = 'M', 
    @id_pais = 'ZZZ', 
    @nombre_pais = 'País Prueba Modificado', 
    @moneda_pais = 'Euro', 
    @pbi_per_capita_actual = 28000.00;

-- Caso 4: Modificación Fallida (PK Inexistente)
PRINT '--> Caso 4: Intentando modificar país inexistente (NON)...';
BEGIN TRY
    EXEC geografia.sp_PAIS_ABM 
        @Accion = 'M', 
        @id_pais = 'NON', 
        @nombre_pais = 'No Existe', 
        @moneda_pais = 'N/A', 
        @pbi_per_capita_actual = 1000;
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Error capturado]: ' + ERROR_MESSAGE();
END CATCH;

-- Caso 5: Baja Rechazada por FK (País en uso por selecciones)
PRINT '--> Caso 5: Intentando eliminar un país con selecciones vinculadas (ARG)...';
BEGIN TRY
    EXEC geografia.sp_PAIS_ABM 
        @Accion = 'B', 
        @id_pais = 'ARG';
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Bloqueo de eliminación por FK]: ' + ERROR_MESSAGE();
END CATCH;

-- Caso 6: Baja Exitosa
PRINT '--> Caso 6: Eliminando país de prueba (ZZZ)...';
EXEC geografia.sp_PAIS_ABM 
    @Accion = 'B', 
    @id_pais = 'ZZZ';

SELECT COUNT(*) AS Existe_Pais_ZZZ FROM geografia.PAIS WHERE id_pais = 'ZZZ';
GO

-- 1.2 SP: geografia.sp_INDICADOR_ECONOMICO_PAIS_ABM

PRINT '1.2 Test: geografia.sp_INDICADOR_ECONOMICO_PAIS_ABM';

-- Se crea un país temporal auxiliar para asociarle indicadores
EXEC geografia.sp_PAIS_ABM 'A', 'ZZZ', 'País Indicadores', 'Dólar', 10000;

-- Caso 1: Alta Exitosa
PRINT '--> Caso 1: Registrando indicador económico para ZZZ (Año 2025)...';
EXEC geografia.sp_INDICADOR_ECONOMICO_PAIS_ABM 
    @Accion = 'A', 
    @id_pais = 'ZZZ', 
    @periodo_anio = 2025, 
    @pbi_per_capita_usd = 10500.00, 
    @poblacion_total = 45000000, 
    @indice_inflacion = 4.50;

SELECT * FROM geografia.INDICADOR_ECONOMICO_PAIS WHERE id_pais = 'ZZZ' AND periodo_anio = 2025;

-- Caso 2: Alta Fallida (Población negativa y País inexistente)
PRINT '--> Caso 2: Provocando errores de validación en Indicador...';
BEGIN TRY
    EXEC geografia.sp_INDICADOR_ECONOMICO_PAIS_ABM 
        @Accion = 'A', 
        @id_pais = 'XXX',               -- País inexistente
        @periodo_anio = 2025, 
        @pbi_per_capita_usd = -500,     -- PBI negativo
        @poblacion_total = -10,         -- Población negativa
        @indice_inflacion = 0;
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Error capturado]: ' + ERROR_MESSAGE();
END CATCH;

-- Caso 3: Modificación Exitosa
PRINT '--> Caso 3: Modificando indicador económico (Año 2025)...';
EXEC geografia.sp_INDICADOR_ECONOMICO_PAIS_ABM 
    @Accion = 'M', 
    @id_pais = 'ZZZ', 
    @periodo_anio = 2025, 
    @pbi_per_capita_usd = 11000.00, 
    @poblacion_total = 46000000, 
    @indice_inflacion = 3.80;

-- Caso 4: Modificación Fallida (PK Inexistente)
PRINT '--> Caso 4: Intentando modificar indicador inexistente...';
BEGIN TRY
    EXEC geografia.sp_INDICADOR_ECONOMICO_PAIS_ABM 
        @Accion = 'M', 
        @id_pais = 'ZZZ', 
        @periodo_anio = 1900, 
        @pbi_per_capita_usd = 1000, 
        @poblacion_total = 1000, 
        @indice_inflacion = 1;
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Error capturado]: ' + ERROR_MESSAGE();
END CATCH;

-- Caso 6: Baja Exitosa
PRINT '--> Caso 6: Eliminando indicador económico (Año 2025)...';
EXEC geografia.sp_INDICADOR_ECONOMICO_PAIS_ABM 
    @Accion = 'B', 
    @id_pais = 'ZZZ', 
    @periodo_anio = 2025;
GO

-- 1.3 SP: geografia.sp_HISTORIAL_TIPO_CAMBIO_ABM
PRINT '1.3 Test: geografia.sp_HISTORIAL_TIPO_CAMBIO_ABM';

-- Caso 1: Alta Exitosa
PRINT '--> Caso 1: Registrando cotización de moneda para ZZZ...';
EXEC geografia.sp_HISTORIAL_TIPO_CAMBIO_ABM 
    @Accion = 'A', 
    @id_pais = 'ZZZ', 
    @fecha_cotizacion = '2026-06-01', 
    @valor_cotizacion = 985.5000, 
    @codigo_moneda = 'USD';

SELECT * FROM geografia.HISTORIAL_TIPO_CAMBIO WHERE id_pais = 'ZZZ' AND fecha_cotizacion = '2026-06-01';

-- Caso 2: Alta Fallida (Valor cotización menor o igual a 0)
PRINT '--> Caso 2: Intentando ingresar cotización inválida (<= 0)...';
BEGIN TRY
    EXEC geografia.sp_HISTORIAL_TIPO_CAMBIO_ABM 
        @Accion = 'A', 
        @id_pais = 'ZZZ', 
        @fecha_cotizacion = '2026-06-02', 
        @valor_cotizacion = -10.0, 
        @codigo_moneda = 'USD';
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Error capturado]: ' + ERROR_MESSAGE();
END CATCH;

-- Caso 3: Modificación Exitosa
PRINT '--> Caso 3: Modificando valor de cotización...';
EXEC geografia.sp_HISTORIAL_TIPO_CAMBIO_ABM 
    @Accion = 'M', 
    @id_pais = 'ZZZ', 
    @fecha_cotizacion = '2026-06-01', 
    @valor_cotizacion = 990.0000, 
    @codigo_moneda = 'USD';

-- Caso 6: Baja Exitosa y Limpieza del país temporal
PRINT '--> Caso 6: Eliminando registro de cotización y país auxiliar...';
EXEC geografia.sp_HISTORIAL_TIPO_CAMBIO_ABM 
    @Accion = 'B', 
    @id_pais = 'ZZZ', 
    @fecha_cotizacion = '2026-06-01';

EXEC geografia.sp_PAIS_ABM 'B', 'ZZZ';
GO

-- 1.4 SP: geografia.sp_CONFEDERACION_ABM
PRINT '1.4 Test: geografia.sp_CONFEDERACION_ABM';

-- Caso 1: Alta Exitosa
PRINT '--> Caso 1: Registrando confederación de prueba (ID 99)...';
EXEC geografia.sp_CONFEDERACION_ABM 
    @Accion = 'A', 
    @id_confederacion = 99, 
    @nombre_confederacion = 'Confederación Test FIFA', 
    @sigla = 'CTF';

SELECT * FROM geografia.CONFEDERACION WHERE id_confederacion = 99;

-- Caso 2: Alta Fallida (Campos obligatorios vacíos)
PRINT '--> Caso 2: Provocando error de campos nulos/vacíos...';
BEGIN TRY
    EXEC geografia.sp_CONFEDERACION_ABM 
        @Accion = 'A', 
        @id_confederacion = 99, 
        @nombre_confederacion = '', 
        @sigla = '';
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Error capturado]: ' + ERROR_MESSAGE();
END CATCH;

-- Caso 3: Modificación Exitosa
PRINT '--> Caso 3: Modificando confederación (ID 99)...';
EXEC geografia.sp_CONFEDERACION_ABM 
    @Accion = 'M', 
    @id_confederacion = 99, 
    @nombre_confederacion = 'Confederación Test Modificada', 
    @sigla = 'CTM';

-- Caso 5: Baja Rechazada por FK (Confederación en uso por selecciones)
PRINT '--> Caso 5: Intentando eliminar confederación en uso (CONMEBOL ID 1)...';
BEGIN TRY
    EXEC geografia.sp_CONFEDERACION_ABM 
        @Accion = 'B', 
        @id_confederacion = 1;
END TRY
BEGIN CATCH
    PRINT '    [RESULTADO ESPERADO - Bloqueo de eliminación por FK]: ' + ERROR_MESSAGE();
END CATCH;

-- Caso 6: Baja Exitosa
PRINT '--> Caso 6: Eliminando confederación de prueba (ID 99)...';
EXEC geografia.sp_CONFEDERACION_ABM 
    @Accion = 'B', 
    @id_confederacion = 99;
GO

PRINT '         FIN DE PRUEBAS: MÓDULO 1 (GEOGRAFÍA Y ECONOMÍA) - ÉXITO        ';
GO
