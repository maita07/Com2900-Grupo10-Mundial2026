/*
================================================================================
UNLaM - Universidad Nacional de La Matanza
Departamento de Ingeniería e Investigaciones Tecnológicas
Materia: Base de Datos Aplicada (Comisión 5600)
Entrega 8 - Seguridad: Creación de Logins, Roles, Usuarios y Asignación de Permisos
2026 - 2C
Grupo 10

Integrantes:
- Monasterio Erik: MonasteryEr
- Arena Ariel Ignacio: arielarena
- Castillo Gabriela Florencia: ItsFlorencia
- Maita Pitado Jose Gregorio: maita07

Archivo: 06_3_TEST_ROLES.sql
Descripción:
Pruebas de seguridad y permisos por rol.
 
================================================================================
*/
USE DB_Mundial2026_Grupo10;
GO

PRINT '  PRUEBAS DE SEGURIDAD Y PERMISOS POR ROL (ENTREGA 8)     ';

-- 1. TEST USUARIO: usr_operador (rol_operador_torneo)
PRINT '>>> 1. TEST usr_operador...';
EXECUTE AS USER = 'usr_operador';
PRINT '    Usuario activo: ' + CURRENT_USER;

-- Permitido: SELECT en torneo y geografia
BEGIN TRY
    SELECT TOP 1 nro_partido_fase FROM torneo.PARTIDO;
    SELECT TOP 1 id_pais FROM geografia.PAIS;
    PRINT '    [OK - PERMITIDO]: SELECT sobre torneo y geografia exitoso.';
END TRY
BEGIN CATCH
    PRINT '    [ERROR INESPERADO]: ' + ERROR_MESSAGE();
END CATCH;

-- Bloqueado: DENY DELETE en torneo
BEGIN TRY
    DELETE FROM torneo.GOL WHERE id_fase = 999;
    PRINT '    [FALLO DE SEGURIDAD]: usr_operador NO debería poder hacer DELETE en torneo.';
END TRY
BEGIN CATCH
    PRINT '    [OK - DENEGADO ESPERADO]: DELETE bloqueado en torneo -> ' + ERROR_MESSAGE();
END CATCH;

-- Bloqueado: DENY SELECT en comercial (no debe ver anunciantes ni tarifas)
BEGIN TRY
    SELECT TOP 1 * FROM comercial.ANUNCIANTE;
    PRINT '    [FALLO DE SEGURIDAD]: usr_operador NO debería poder leer comercial.';
END TRY
BEGIN CATCH
    PRINT '    [OK - DENEGADO ESPERADO]: Acceso denegado a comercial -> ' + ERROR_MESSAGE();
END CATCH;

REVERT;
PRINT '    Sesión restaurada a: ' + CURRENT_USER;
GO

-- 2. TEST USUARIO: usr_comercial (rol_gestor_comercial)
PRINT '>>> 2. TEST usr_comercial...';
EXECUTE AS USER = 'usr_comercial';
PRINT '    Usuario activo: ' + CURRENT_USER;

-- Permitido: SELECT en comercial y geografia
BEGIN TRY
    SELECT TOP 1 id_anunciante FROM comercial.ANUNCIANTE;
    SELECT TOP 1 id_pais FROM geografia.PAIS;
    PRINT '    [OK - PERMITIDO]: SELECT sobre comercial y geografia exitoso.';
END TRY
BEGIN CATCH
    PRINT '    [ERROR INESPERADO]: ' + ERROR_MESSAGE();
END CATCH;

-- Bloqueado: DENY DELETE en comercial
BEGIN TRY
    DELETE FROM comercial.ANUNCIANTE WHERE id_anunciante = 999;
    PRINT '    [FALLO DE SEGURIDAD]: usr_comercial NO debería poder hacer DELETE en comercial.';
END TRY
BEGIN CATCH
    PRINT '    [OK - DENEGADO ESPERADO]: DELETE bloqueado en comercial -> ' + ERROR_MESSAGE();
END CATCH;

-- Bloqueado: DENY SELECT en persona (protección de datos personales/sensibles)
BEGIN TRY
    SELECT TOP 1 * FROM persona.PERSONA;
    PRINT '    [FALLO DE SEGURIDAD]: usr_comercial NO debería acceder a datos personales.';
END TRY
BEGIN CATCH
    PRINT '    [OK - DENEGADO ESPERADO]: Acceso denegado a persona -> ' + ERROR_MESSAGE();
END CATCH;

REVERT;
PRINT '    Sesión restaurada a: ' + CURRENT_USER;
GO

-- 3. TEST USUARIO: usr_consulta (rol_consulta)
PRINT '>>> 3. TEST usr_consulta...';
EXECUTE AS USER = 'usr_consulta';
PRINT '    Usuario activo: ' + CURRENT_USER;

-- Permitido: SELECT en torneo y comercial
BEGIN TRY
    SELECT TOP 1 id_seleccion FROM torneo.SELECCION;
    SELECT TOP 1 id_anunciante FROM comercial.ANUNCIANTE;
    PRINT '    [OK - PERMITIDO]: Lectura en torneo y comercial exitosa.';
END TRY
BEGIN CATCH
    PRINT '    [ERROR INESPERADO]: ' + ERROR_MESSAGE();
END CATCH;

-- Bloqueado: DENY UPDATE en torneo (no puede alterar resultados)
BEGIN TRY
    UPDATE torneo.SELECCION SET nombre_seleccion = 'Test' WHERE id_seleccion = 1;
    PRINT '    [FALLO DE SEGURIDAD]: usr_consulta NO debería modificar datos.';
END TRY
BEGIN CATCH
    PRINT '    [OK - DENEGADO ESPERADO]: Modificación bloqueada en torneo -> ' + ERROR_MESSAGE();
END CATCH;

-- Bloqueado: DENY en auditoria (no puede ver logs de errores ni auditoría interna)
BEGIN TRY
    SELECT TOP 1 * FROM auditoria.LOG_IMPORTACION;
    PRINT '    [FALLO DE SEGURIDAD]: usr_consulta NO debería ver los logs de auditoría.';
END TRY
BEGIN CATCH
    PRINT '    [OK - DENEGADO ESPERADO]: Acceso denegado a auditoria -> ' + ERROR_MESSAGE();
END CATCH;

REVERT;
PRINT '    Sesión restaurada a: ' + CURRENT_USER;
GO