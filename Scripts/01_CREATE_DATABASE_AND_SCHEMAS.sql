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

Descripcion: Creacion de la base de datos DB_Mundial2026_Grupo10 y esquemas geografia, persona, torneo y comercial.
---------------------------------------------------------
*/

-- 1. Creacion de la base de datos 
USE master;
GO

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'DB_Mundial2026_Grupo10')
BEGIN
    CREATE DATABASE DB_Mundial2026_Grupo10;
    PRINT 'Base de datos DB_Mundial2026_Grupo10 creada correctamente.';
END
ELSE
BEGIN
    PRINT 'La base de datos DB_Mundial2026_Grupo10 ya existe.';
END
GO

USE DB_Mundial2026_Grupo10;
GO

-- 2. Creacion de esquemas
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = N'geografia') EXEC('CREATE SCHEMA geografia;');
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = N'persona') EXEC('CREATE SCHEMA persona;');
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = N'torneo') EXEC('CREATE SCHEMA torneo;');
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = N'comercial') EXEC('CREATE SCHEMA comercial;');
GO

PRINT 'Esquemas geografia, persona, torneo y comercial creados correctamente.';
GO