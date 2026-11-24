/*
================================================================================
UNLaM - Base de Datos Aplicada (Comisión 5600)
Entrega 7 - Reporte 6: Selecciones y Plantillas
2026 - 2C
Grupo 10

Integrantes:
- Monasterio Erik: MonasteryEr
- Arena Ariel Ignacio: arielarena
- Castillo Gabriela Florencia: ItsFlorencia
- Maita Pitado Jose Gregorio: maita07

Archivo: 05_6_REPORT_SELECCIONES_PLANTILLAS.sql
Descripcion:
- Stored Procedure que reporta el listado de selecciones con un vector anidado
  de convocados (nombre, posición, club, dorsal).
- Permite filtrar opcionalmente por selección (@IdSeleccion) o grupo (@Grupo).
- Salida en formato nativo XML (por defecto) o en grilla tabular.
================================================================================
*/
USE DB_Mundial2026_Grupo10;
GO

-- Asegurar esquema reportes
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'reportes')
BEGIN
    EXEC('CREATE SCHEMA reportes;');
END;
GO

CREATE OR ALTER PROCEDURE reportes.sp_REPORTE_SELECCIONES_PLANTILLAS
    @IdSeleccion INT     = NULL,  -- NULL = Todas las selecciones
    @Grupo       CHAR(1) = NULL,  -- NULL = Todos los grupos (A..L)
    @FormatoXML  BIT     = 1      -- 1 = Salida XML (vector anidado), 0 = Salida Tabular
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. SALIDA EN XML (Jerarquía: Seleccion -> Plantilla -> Convocado)
    IF @FormatoXML = 1
    BEGIN
        SELECT
            (
                SELECT
                    S.id_seleccion                                  AS [@IdSeleccion],
                    S.nombre_seleccion                              AS [@NombreSeleccion],
                    S.id_pais                                       AS [@CodigoPais],
                    S.grupo_asignado                                AS [@Grupo],
                    CONF.sigla                                      AS [@Confederacion],
                    (
                        SELECT COUNT(*)
                        FROM torneo.CONVOCATORIA C_Tot
                        WHERE C_Tot.id_seleccion = S.id_seleccion
                    )                                               AS [@CantidadConvocados],
                    -- Vector anidado de convocados de la selección (nombre, posición, club, dorsal)
                    (
                        SELECT
                            C.dorsal_oficial                        AS [@Dorsal],
                            CONCAT(PER.nombre, ' ', PER.apellido)   AS [@Nombre],
                            J.posicion_habitual                     AS [@Posicion],
                            J.club_origen                           AS [@Club],
                            C.estado_convocatoria                   AS [@Estado]
                        FROM torneo.CONVOCATORIA C
                        INNER JOIN persona.JUGADOR J   ON C.nro_doc = J.nro_doc AND C.tipo_doc = J.tipo_doc
                        INNER JOIN persona.PERSONA PER ON C.nro_doc = PER.nro_doc AND C.tipo_doc = PER.tipo_doc
                        WHERE C.id_seleccion = S.id_seleccion
                        ORDER BY C.dorsal_oficial ASC
                        FOR XML PATH('Convocado'), ROOT('Plantilla'), TYPE
                    )
                FROM torneo.SELECCION S
                INNER JOIN geografia.CONFEDERACION CONF ON S.id_confederacion = CONF.id_confederacion
                WHERE (@IdSeleccion IS NULL OR S.id_seleccion = @IdSeleccion)
                  AND (@Grupo IS NULL OR S.grupo_asignado = UPPER(@Grupo))
                ORDER BY S.grupo_asignado ASC, S.nombre_seleccion ASC
                FOR XML PATH('Seleccion'), TYPE
            )
        FOR XML PATH(''), ROOT('ReporteSeleccionesPlantillasMundial2026');

        RETURN;
    END;

    -- 2. SALIDA TABULAR (una fila por convocado de cada selección)
    SELECT
        S.id_seleccion                                              AS Id_Seleccion,
        S.nombre_seleccion                                          AS Seleccion,
        S.id_pais                                                   AS Codigo_Pais,
        S.grupo_asignado                                            AS Grupo,
        CONF.sigla                                                  AS Confederacion,
        C.dorsal_oficial                                            AS Dorsal,
        CONCAT(PER.nombre, ' ', PER.apellido)                       AS Nombre,
        J.posicion_habitual                                         AS Posicion,
        J.club_origen                                               AS Club,
        C.estado_convocatoria                                       AS Estado,
        COUNT(*) OVER (PARTITION BY S.id_seleccion)                 AS Total_Convocados_Seleccion
    FROM torneo.SELECCION S
    INNER JOIN geografia.CONFEDERACION CONF ON S.id_confederacion = CONF.id_confederacion
    INNER JOIN torneo.CONVOCATORIA C        ON S.id_seleccion = C.id_seleccion
    INNER JOIN persona.JUGADOR J            ON C.nro_doc = J.nro_doc AND C.tipo_doc = J.tipo_doc
    INNER JOIN persona.PERSONA PER          ON C.nro_doc = PER.nro_doc AND C.tipo_doc = PER.tipo_doc
    WHERE (@IdSeleccion IS NULL OR S.id_seleccion = @IdSeleccion)
      AND (@Grupo IS NULL OR S.grupo_asignado = UPPER(@Grupo))
    ORDER BY S.grupo_asignado ASC, S.nombre_seleccion ASC, C.dorsal_oficial ASC;
END;
GO
