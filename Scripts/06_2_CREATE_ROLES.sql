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

Archivo: 06_2_CREATE_ROLES.sql
Descripción:
  1. Creación de Logins a nivel Servidor con contraseñas.
  2. Creación de Usuarios en la base de datos DB_Mundial2026_Grupo10.
  3. Creación de Roles de Base de Datos y asignación de permisos (GRANT / DENY).
  4. Asignación de Usuarios como miembros de Roles (ALTER ROLE ... ADD MEMBER).
 
================================================================================
*/
USE DB_Mundial2026_Grupo10;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'seguridad')
BEGIN
    EXEC('CREATE SCHEMA seguridad AUTHORIZATION dbo;');
END;
GO


-- 1: En MASTER se crean los Logins y sus Claves (Nivel Servidor)
USE master;
GO

-- Login para Administrador
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'login_admin')
    CREATE LOGIN login_admin 
    WITH PASSWORD = N'Dba_Admin2026!#Mundial', 
         DEFAULT_DATABASE = [DB_Mundial2026_Grupo10], 
         CHECK_POLICY = ON;

-- Login para Operador de Torneo (Mesa de control)
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'login_operador')
    CREATE LOGIN login_operador 
    WITH PASSWORD = N'Operador#2026!Torneo', 
         DEFAULT_DATABASE = [DB_Mundial2026_Grupo10], 
         CHECK_POLICY = ON;

-- Login para Gestor Comercial (Publicidad)
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'login_comercial')
    CREATE LOGIN login_comercial 
    WITH PASSWORD = N'Comercial#2026!Pauta', 
         DEFAULT_DATABASE = [DB_Mundial2026_Grupo10], 
         CHECK_POLICY = ON;

-- Login para Consulta (Power BI / Prensa)
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'login_consulta')
    CREATE LOGIN login_consulta 
    WITH PASSWORD = N'Consulta#2026!PowerBI', 
         DEFAULT_DATABASE = [DB_Mundial2026_Grupo10], 
         CHECK_POLICY = ON;
GO

-- 2: se crean los Usuarios (Nivel Base de Datos)
USE DB_Mundial2026_Grupo10;
GO

IF USER_ID('usr_admin') IS NULL
    CREATE USER usr_admin FOR LOGIN login_admin;

IF USER_ID('usr_operador') IS NULL
    CREATE USER usr_operador FOR LOGIN login_operador;

IF USER_ID('usr_comercial') IS NULL
    CREATE USER usr_comercial FOR LOGIN login_comercial;

IF USER_ID('usr_consulta') IS NULL
    CREATE USER usr_consulta FOR LOGIN login_consulta;
GO

-- 3: Se crea y ejecuta el Stored Procedure que crea los ROLES y Permisos
CREATE OR ALTER PROCEDURE seguridad.sp_CONFIGURAR_ROLES_Y_PERMISOS
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Crear Roles si no existen
    IF DATABASE_PRINCIPAL_ID('rol_dba') IS NULL              CREATE ROLE rol_dba;
    IF DATABASE_PRINCIPAL_ID('rol_operador_torneo') IS NULL  CREATE ROLE rol_operador_torneo;
    IF DATABASE_PRINCIPAL_ID('rol_gestor_comercial') IS NULL CREATE ROLE rol_gestor_comercial;
    IF DATABASE_PRINCIPAL_ID('rol_consulta') IS NULL         CREATE ROLE rol_consulta;

    -- 2. Asignar Permisos GRANT / DENY
    GRANT CONTROL ON DATABASE::DB_Mundial2026_Grupo10 TO rol_dba;
    ALTER ROLE db_owner ADD MEMBER rol_dba;

    GRANT SELECT, INSERT, UPDATE ON SCHEMA::torneo TO rol_operador_torneo;
    GRANT SELECT ON SCHEMA::geografia TO rol_operador_torneo;
    GRANT EXECUTE ON OBJECT::persona.sp_JUGADOR_ABM TO rol_operador_torneo;
    DENY DELETE ON SCHEMA::torneo TO rol_operador_torneo;
    DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::comercial TO rol_operador_torneo;

    GRANT SELECT, INSERT, UPDATE ON SCHEMA::comercial TO rol_gestor_comercial;
    GRANT SELECT ON SCHEMA::geografia TO rol_gestor_comercial;
    DENY DELETE ON SCHEMA::comercial TO rol_gestor_comercial;
    DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::persona TO rol_gestor_comercial;

    GRANT SELECT ON SCHEMA::torneo TO rol_consulta;
    GRANT SELECT ON SCHEMA::persona TO rol_consulta;
    GRANT SELECT ON SCHEMA::geografia TO rol_consulta;
    GRANT SELECT ON SCHEMA::comercial TO rol_consulta;
    DENY INSERT, UPDATE, DELETE ON SCHEMA::torneo TO rol_consulta;
    DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::auditoria TO rol_consulta;

    -- 3. Vincular los Usuarios a sus respectivos Roles
    ALTER ROLE rol_dba              ADD MEMBER usr_admin;
    ALTER ROLE rol_operador_torneo  ADD MEMBER usr_operador;
    ALTER ROLE rol_gestor_comercial ADD MEMBER usr_comercial;
    ALTER ROLE rol_consulta         ADD MEMBER usr_consulta;

    PRINT '--> Configuración de roles y permisos aplicada con éxito.';
END;
GO

EXEC seguridad.sp_CONFIGURAR_ROLES_Y_PERMISOS;
GO