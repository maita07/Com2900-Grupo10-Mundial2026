/*
================================================================================
UNLaM - Base de Datos Aplicada (Comisión 5600)
Entrega 8 - Cifrado
2026 - 2C
Grupo 10

Integrantes:
- Monasterio Erik: MonasteryEr
- Arena Ariel Ignacio: arielarena
- Castillo Gabriela Florencia: ItsFlorencia
- Maita Pitado Jose Gregorio: maita07

Archivo: 06_1_CIFRADO.sql
Descripcion:
- Stored Procedure que cifra la fecha de nacimiento, peso y altura de las personas y jugadores.
- Usa AES256 ya que permite descifrar para leer dicho dato. Con sha256 no se puede.
- No ciframos otros datos debido a que se llaman o utilizan regularmente, como el dni como PK.
================================================================================
*/


--------------------------------------------
-- 
--       LEER ANTES DE EJECUTAR
-- al ejecutar esto, la gran mayoria de scripts (especialmente los de abm y los de import) van a dejar de funcionar correctamente
-- ya que modifica las estructuras originales
--
--------------------------------------------





USE DB_Mundial2026_Grupo10;
GO

-- Asegurar esquema seguridad
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'seguridad')
BEGIN
    EXEC('CREATE SCHEMA seguridad;');
END;
GO

-- 1. COLUMNAS PARA LOS DATOS CIFRADOS
ALTER TABLE persona.PERSONA ADD nombre_cifrado VARBINARY(256) NULL, apellido_cifrado VARBINARY(256) NULL,
                                fecha_nacimiento_cifrada VARBINARY(256) NULL;
ALTER TABLE persona.JUGADOR ADD peso_kg_cifrado VARBINARY(256) NULL, altura_cm_cifrado VARBINARY(256) NULL;
GO

-- 2. CIFRADO
CREATE OR ALTER PROCEDURE seguridad.sp_CIFRAR_DATOS_PERSONALES
    @FraseClave NVARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE persona.PERSONA
        SET nombre_cifrado           = ENCRYPTBYPASSPHRASE(@FraseClave, nombre, 1, nro_doc + '|' + tipo_doc),
            apellido_cifrado         = ENCRYPTBYPASSPHRASE(@FraseClave, apellido, 1, nro_doc + '|' + tipo_doc),
            fecha_nacimiento_cifrada = ENCRYPTBYPASSPHRASE(@FraseClave, CONVERT(VARCHAR(10), fecha_nacimiento, 23), 1, nro_doc + '|' + tipo_doc);

        UPDATE persona.JUGADOR
        SET peso_kg_cifrado   = ENCRYPTBYPASSPHRASE(@FraseClave, CONVERT(VARCHAR(10), peso_kg), 1, nro_doc + '|' + tipo_doc),
            altura_cm_cifrado = ENCRYPTBYPASSPHRASE(@FraseClave, CONVERT(VARCHAR(10), altura_cm), 1, nro_doc + '|' + tipo_doc);

        ALTER TABLE persona.PERSONA ALTER COLUMN nombre_cifrado VARBINARY(256) NOT NULL;
        ALTER TABLE persona.PERSONA ALTER COLUMN apellido_cifrado VARBINARY(256) NOT NULL;
        ALTER TABLE persona.PERSONA ALTER COLUMN fecha_nacimiento_cifrada VARBINARY(256) NOT NULL;
        ALTER TABLE persona.JUGADOR ALTER COLUMN peso_kg_cifrado VARBINARY(256) NOT NULL;
        ALTER TABLE persona.JUGADOR ALTER COLUMN altura_cm_cifrado VARBINARY(256) NOT NULL;

        ALTER TABLE persona.PERSONA DROP COLUMN nombre, apellido, fecha_nacimiento;
        ALTER TABLE persona.JUGADOR DROP CONSTRAINT CHK_JUGADOR_PESO, CHK_JUGADOR_ALTURA;
        ALTER TABLE persona.JUGADOR DROP COLUMN peso_kg, altura_cm;

        COMMIT TRANSACTION;
        PRINT 'Datos personales cifrados correctamente.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @ErrorMsg NVARCHAR(4000) = ERROR_MESSAGE();
        THROW 50001, @ErrorMsg, 1;
    END CATCH;
END;
GO

-- 3. EJECUCIÓN DEL CIFRADO
EXEC seguridad.sp_CIFRAR_DATOS_PERSONALES @FraseClave = N'cifrado datos';
GO

-- 4. FUNCION PARA CONSULTA DE DATOS PERSONALES DESCIFRADOS
CREATE OR ALTER FUNCTION persona.fn_DATOS_PERSONALES (@FraseClave NVARCHAR(128))
RETURNS TABLE
AS
RETURN
    SELECT P.nro_doc, P.tipo_doc,
           CONVERT(VARCHAR(50), DECRYPTBYPASSPHRASE(@FraseClave, P.nombre_cifrado, 1, K.aut)) AS nombre,
           CONVERT(VARCHAR(50), DECRYPTBYPASSPHRASE(@FraseClave, P.apellido_cifrado, 1, K.aut)) AS apellido,
           CONVERT(DATE, CONVERT(VARCHAR(10), DECRYPTBYPASSPHRASE(@FraseClave, P.fecha_nacimiento_cifrada, 1, K.aut)), 23) AS fecha_nacimiento,
           CONVERT(DECIMAL(5,2), CONVERT(VARCHAR(10), DECRYPTBYPASSPHRASE(@FraseClave, J.peso_kg_cifrado, 1, K.aut))) AS peso_kg,
           CONVERT(DECIMAL(5,2), CONVERT(VARCHAR(10), DECRYPTBYPASSPHRASE(@FraseClave, J.altura_cm_cifrado, 1, K.aut))) AS altura_cm,
           P.id_nacionalidad_pais, P.tipo_persona
    FROM persona.PERSONA P
    LEFT JOIN persona.JUGADOR J ON J.nro_doc = P.nro_doc AND J.tipo_doc = P.tipo_doc
    CROSS APPLY (SELECT P.nro_doc + '|' + P.tipo_doc AS aut) K;
GO