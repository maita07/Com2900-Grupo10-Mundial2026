/*
================================================================================
UNLaM - Base de Datos Aplicada (Comisión 5600)
Entrega 7 - Reporte 1: Goleadores por Selección, Fase y Torneo
2026 - 2C
Grupo 10

Integrantes:
- Monasterio Erik: MonasteryEr
- Arena Ariel Ignacio: arielarena
- Castillo Gabriela Florencia: ItsFlorencia
- Maita Pitado Jose Gregorio: maita07

Archivo: 05_3_REPORTE_DESIGNACIONES_ARBITRALES.sql
Descripcion:
- Stored Procedure que reporta partidos dirigidos por cada árbitro, 
  con las amonestaciones/expulsiones que señaló.
- Salida en ARCHIVO.XML o en grilla tabular.
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

CREATE OR ALTER PROCEDURE reportes.sp_REPORTE_DESIGNACIONES_ARBITRALES
    @IdRolPrincipal INT = 1,  -- Rol de arbitro principal 
    @FormatoXML     BIT = 1   -- 1 = Salida XML, 0 = Salida Tabular
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Partidos dirigidos con el resumen de tarjetas de cada uno
    SELECT
        D.id_fase,
        D.nro_partido_fase,
        D.nro_doc,
        D.tipo_doc,
        F.nombre_fase,
        P.fecha_hora_local,
        SED.nombre_estadio,
        SED.ciudad,
        CONCAT(SL.nombre_seleccion, ' ', P.goles_local, ' - ', P.goles_visitante, ' ', SV.nombre_seleccion,
               ' (pen. ' + CAST(P.penales_local AS VARCHAR(3)) + '-' + CAST(P.penales_visitante AS VARCHAR(3)) + ')') AS resultado,
        T.amarillas,
        T.doble_amarilla,
        T.roja_directa
    INTO #Dirigido
    FROM torneo.DESIGNACION_ARBITRAL D
    INNER JOIN torneo.PARTIDO P      ON D.id_fase = P.id_fase AND D.nro_partido_fase = P.nro_partido_fase
    INNER JOIN torneo.FASE_TORNEO F  ON D.id_fase = F.id_fase
    INNER JOIN torneo.SEDE SED       ON P.id_sede = SED.id_sede
    INNER JOIN torneo.SELECCION SL   ON P.id_seleccion_local = SL.id_seleccion
    INNER JOIN torneo.SELECCION SV   ON P.id_seleccion_visitante = SV.id_seleccion
    CROSS APPLY (
        SELECT
            COUNT(CASE WHEN ST.tipo_tarjeta = 'AMARILLA' THEN 1 END)       AS amarillas,
            COUNT(CASE WHEN ST.tipo_tarjeta = 'DOBLE_AMARILLA' THEN 1 END) AS doble_amarilla,
            COUNT(CASE WHEN ST.tipo_tarjeta = 'ROJA_DIRECTA' THEN 1 END)   AS roja_directa
        FROM torneo.SANCION_TARJETA ST
        WHERE ST.id_fase = D.id_fase
          AND ST.nro_partido_fase = D.nro_partido_fase
    ) T
    WHERE D.id_rol = @IdRolPrincipal;

    -- 2. SALIDA EN XML (primero arbitro, despues partido, y despues tarjetas)
    IF @FormatoXML = 1
    BEGIN
        SELECT
            (
                SELECT
                    A.nro_doc                                AS [@Documento],
                    CONCAT(PE.nombre, ' ', PE.apellido)      AS [@Arbitro],
                    PA.nombre_pais                           AS [@Pais],
                    A.categoria_fifa                         AS [@Categoria],
                    COUNT(*)                                 AS [@PartidosDirigidos],
                    SUM(D.amarillas)                         AS [@Amonestaciones],
                    SUM(D.doble_amarilla + D.roja_directa)   AS [@Expulsiones],
                    -- Lista anidada de partidos que dirigió
                    (
                        SELECT
                            D2.nombre_fase                                 AS [@Fase],
                            D2.nro_partido_fase                            AS [@NroPartido],
                            CONVERT(VARCHAR(16), D2.fecha_hora_local, 120) AS [@FechaHoraLocal],
                            D2.resultado                                   AS [@Resultado],
                            D2.nombre_estadio                              AS [@Estadio],
                            D2.ciudad                                      AS [@Ciudad],
                            D2.amarillas                                   AS [@Amonestaciones],
                            D2.doble_amarilla + D2.roja_directa            AS [@Expulsiones],
                            -- Tarjetas que mostró en el partido
                            (
                                SELECT
                                    CONCAT(ST.minuto_sancion, '+' + CAST(ST.minuto_sancion_extra AS VARCHAR(5)), '''') AS [@Minuto],
                                    ST.tipo_tarjeta                          AS [@Tipo],
                                    S.nombre_seleccion                       AS [@Seleccion],
                                    ST.dorsal_sancionado                     AS [@Dorsal],
                                    CONCAT(PER.nombre, ' ', PER.apellido)    AS [@Futbolista],
                                    ST.motivo                                AS [@Motivo]
                                FROM torneo.SANCION_TARJETA ST
                                INNER JOIN torneo.SELECCION S    ON ST.id_seleccion = S.id_seleccion
                                INNER JOIN torneo.CONVOCATORIA C ON ST.id_seleccion = C.id_seleccion AND ST.dorsal_sancionado = C.dorsal_oficial
                                INNER JOIN persona.PERSONA PER   ON C.tipo_doc = PER.tipo_doc AND C.nro_doc = PER.nro_doc
                                WHERE ST.id_fase = D2.id_fase
                                  AND ST.nro_partido_fase = D2.nro_partido_fase
                                ORDER BY ST.minuto_sancion, ST.minuto_sancion_extra, ST.id_tarjeta
                                FOR XML PATH('Tarjeta'), TYPE
                            ) AS [Tarjetas]
                        FROM #Dirigido D2
                        WHERE D2.nro_doc = A.nro_doc
                          AND D2.tipo_doc = A.tipo_doc
                        ORDER BY D2.fecha_hora_local
                        FOR XML PATH('Partido'), ROOT('Partidos'), TYPE
                    )
                FROM #Dirigido D
                INNER JOIN persona.ARBITRO A  ON D.nro_doc = A.nro_doc AND D.tipo_doc = A.tipo_doc
                INNER JOIN persona.PERSONA PE ON A.nro_doc = PE.nro_doc AND A.tipo_doc = PE.tipo_doc
                INNER JOIN geografia.PAIS PA  ON PE.id_nacionalidad_pais = PA.id_pais
                GROUP BY A.nro_doc, A.tipo_doc, PE.nombre, PE.apellido, PA.nombre_pais, A.categoria_fifa
                ORDER BY COUNT(*) DESC, PE.apellido ASC
                FOR XML PATH('Arbitro'), TYPE
            )
        FOR XML PATH(''), ROOT('ReporteDesignacionesArbitralesMundial2026');

        RETURN;
    END;

    -- 3. SALIDA TABULAR (una fila por partido dirigido)
    SELECT
        CONCAT(PE.nombre, ' ', PE.apellido)  AS Arbitro,
        PA.nombre_pais                       AS Pais,
        D.nombre_fase                        AS Fase,
        D.nro_partido_fase                   AS Nro_Partido,
        D.fecha_hora_local                   AS Fecha,
        D.resultado                          AS Partido,
        D.amarillas                          AS Amonestaciones,
        D.doble_amarilla                     AS Doble_Amarilla,
        D.roja_directa                       AS Roja_Directa,
        (
            SELECT STRING_AGG(CONCAT(ST.minuto_sancion, '+' + CAST(ST.minuto_sancion_extra AS VARCHAR(5)), ''' ',
                                     ST.tipo_tarjeta, ' ', S.id_pais, ' #', ST.dorsal_sancionado), ' | ')
                   WITHIN GROUP (ORDER BY ST.minuto_sancion, ST.minuto_sancion_extra, ST.id_tarjeta)
            FROM torneo.SANCION_TARJETA ST
            INNER JOIN torneo.SELECCION S ON ST.id_seleccion = S.id_seleccion
            WHERE ST.id_fase = D.id_fase
              AND ST.nro_partido_fase = D.nro_partido_fase
        )                                    AS Detalle_Tarjetas,
        COUNT(*) OVER (PARTITION BY D.nro_doc, D.tipo_doc)                                             AS Partidos_Dirigidos_Total,
        SUM(D.amarillas + D.doble_amarilla + D.roja_directa) OVER (PARTITION BY D.nro_doc, D.tipo_doc) AS Tarjetas_Total
    FROM #Dirigido D
    INNER JOIN persona.PERSONA PE ON D.nro_doc = PE.nro_doc AND D.tipo_doc = PE.tipo_doc
    INNER JOIN geografia.PAIS PA  ON PE.id_nacionalidad_pais = PA.id_pais
    ORDER BY Partidos_Dirigidos_Total DESC, PE.apellido ASC, D.nro_doc ASC, D.fecha_hora_local ASC;
END;
GO