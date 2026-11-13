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

Archivo: 05_01_REPORTE_GOLEADORES_SELECCION_FASE_TORNEO.sql
Descripcion:
- Stored Procedure que reporta los goleadores del Mundial 2026 clasificados
  por Selección, Fase y total del Torneo.
- Excluye autogoles del cómputo individual del futbolista.
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

CREATE OR ALTER PROCEDURE reportes.sp_REPORTE_GOLEADORES_SELECCION_FASE_TORNEO
    @IdSeleccion INT = NULL,  -- NULL = Todas las selecciones
    @IdFase      INT = NULL,  -- NULL = Todas las fases del torneo
    @Top         INT = NULL,  -- NULL = Todos (o ej: 10 para Top 10)
    @FormatoXML  BIT = 1      -- 1 = Salida XML, 0 = Salida Tabular
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. SALIDA EN XML (Jerarquía: Seleccion -> Goleador -> DesgloseFases)
    IF @FormatoXML = 1
    BEGIN
        SELECT 
            (
                SELECT 
                    S.id_seleccion                                  AS [@IdSeleccion],
                    S.nombre_seleccion                              AS [@NombreSeleccion],
                    S.grupo_asignado                                AS [@Grupo],
                    -- Total de goles a favor de la selección
                    (
                        SELECT COUNT(*) 
                        FROM torneo.GOL G_Tot 
                        WHERE G_Tot.id_seleccion = S.id_seleccion 
                          AND G_Tot.tipo_gol <> 'AUTOGOL'
                    )                                               AS [@GolesTotalesSeleccion],
                    -- Lista anidada de goleadores de la selección
                    (
                        SELECT 
                            C.dorsal_oficial                        AS [@Dorsal],
                            CONCAT(PER.nombre, ' ', PER.apellido)   AS [@Futbolista],
                            J.posicion_habitual                     AS [@Posicion],
                            J.club_origen                           AS [@Club],
                            COUNT(G.id_gol)                         AS [@TotalGolesJugador],
                            SUM(CASE WHEN G.tipo_gol = 'PENAL' THEN 1 ELSE 0 END) AS [@GolesPenal],
                            SUM(CASE WHEN G.tipo_gol = 'JUGADA' THEN 1 ELSE 0 END) AS [@GolesJugada],
                            -- Desglose anidado de goles por cada Fase
                            (
                                SELECT 
                                    F_Sub.id_fase                   AS [@IdFase],
                                    F_Sub.nombre_fase               AS [@NombreFase],
                                    COUNT(G_Sub.id_gol)             AS [@GolesEnFase]
                                FROM torneo.GOL G_Sub
                                INNER JOIN torneo.FASE_TORNEO F_Sub ON G_Sub.id_fase = F_Sub.id_fase
                                WHERE G_Sub.id_seleccion = S.id_seleccion
                                  AND G_Sub.dorsal_autor = C.dorsal_oficial
                                  AND G_Sub.tipo_gol <> 'AUTOGOL'
                                  AND (@IdFase IS NULL OR G_Sub.id_fase = @IdFase)
                                GROUP BY F_Sub.id_fase, F_Sub.nombre_fase, F_Sub.orden_secuencia
                                ORDER BY F_Sub.orden_secuencia
                                FOR XML PATH('Fase'), TYPE
                            ) AS [DesgloseFases]
                        FROM torneo.GOL G
                        INNER JOIN torneo.CONVOCATORIA C ON G.id_seleccion = C.id_seleccion AND G.dorsal_autor = C.dorsal_oficial
                        INNER JOIN persona.PERSONA PER   ON C.tipo_doc = PER.tipo_doc AND C.nro_doc = PER.nro_doc
                        INNER JOIN persona.JUGADOR J     ON C.tipo_doc = J.tipo_doc AND C.nro_doc = J.nro_doc
                        WHERE G.id_seleccion = S.id_seleccion
                          AND G.tipo_gol <> 'AUTOGOL'
                          AND (@IdFase IS NULL OR G.id_fase = @IdFase)
                        GROUP BY C.dorsal_oficial, PER.nombre, PER.apellido, J.posicion_habitual, J.club_origen
                        ORDER BY COUNT(G.id_gol) DESC, PER.apellido ASC
                        FOR XML PATH('Goleador'), ROOT('Goleadores'), TYPE
                    )
                FROM torneo.SELECCION S
                WHERE (@IdSeleccion IS NULL OR S.id_seleccion = @IdSeleccion)
                  AND EXISTS (
                      SELECT 1 
                      FROM torneo.GOL G_Ex 
                      WHERE G_Ex.id_seleccion = S.id_seleccion 
                        AND G_Ex.tipo_gol <> 'AUTOGOL'
                        AND (@IdFase IS NULL OR G_Ex.id_fase = @IdFase)
                  )
                ORDER BY [@GolesTotalesSeleccion] DESC, S.nombre_seleccion ASC
                FOR XML PATH('Seleccion'), TYPE
            )
        FOR XML PATH(''), ROOT('ReporteGoleadoresMundial2026');

        RETURN;
    END;


    -- 2. SALIDA TABULAR
    ;WITH ResumenPorFase AS (
        SELECT 
            S.id_seleccion,
            S.nombre_seleccion AS Seleccion,
            C.dorsal_oficial AS Dorsal,
            CONCAT(PER.nombre, ' ', PER.apellido) AS Futbolista,
            J.posicion_habitual AS Posicion,
            F.id_fase,
            F.nombre_fase AS Fase,
            F.orden_secuencia,
            COUNT(G.id_gol) AS Goles_En_Fase,
            SUM(CASE WHEN G.tipo_gol = 'PENAL' THEN 1 ELSE 0 END) AS De_Penal,
            SUM(CASE WHEN G.tipo_gol = 'JUGADA' THEN 1 ELSE 0 END) AS De_Jugada
        FROM torneo.GOL G
        INNER JOIN torneo.FASE_TORNEO F  ON G.id_fase = F.id_fase
        INNER JOIN torneo.SELECCION S    ON G.id_seleccion = S.id_seleccion
        INNER JOIN torneo.CONVOCATORIA C ON G.id_seleccion = C.id_seleccion AND G.dorsal_autor = C.dorsal_oficial
        INNER JOIN persona.PERSONA PER   ON C.tipo_doc = PER.tipo_doc AND C.nro_doc = PER.nro_doc
        INNER JOIN persona.JUGADOR J     ON C.tipo_doc = J.tipo_doc AND C.nro_doc = J.nro_doc
        WHERE G.tipo_gol <> 'AUTOGOL'
          AND (@IdSeleccion IS NULL OR G.id_seleccion = @IdSeleccion)
          AND (@IdFase IS NULL OR G.id_fase = @IdFase)
        GROUP BY 
            S.id_seleccion, S.nombre_seleccion, C.dorsal_oficial, 
            PER.nombre, PER.apellido, J.posicion_habitual, 
            F.id_fase, F.nombre_fase, F.orden_secuencia
    ),
    AcumuladoJugador AS (
        SELECT 
            RPF.*,
            -- Paso 1: Calculamos la suma total por jugador en el torneo
            SUM(RPF.Goles_En_Fase) OVER(PARTITION BY RPF.id_seleccion, RPF.Dorsal) AS Goles_Totales_Torneo
        FROM ResumenPorFase RPF
    ),
    RankingGoleadores AS (
        SELECT 
            AJ.*,
            -- Paso 2: Ahora aplicamos DENSE_RANK() directamente sobre la columna ya calculada
            DENSE_RANK() OVER(ORDER BY AJ.Goles_Totales_Torneo DESC) AS Puesto_Bota_Oro
        FROM AcumuladoJugador AJ
    )
    SELECT 
        CASE 
            WHEN @Top IS NOT NULL AND Puesto_Bota_Oro <= @Top THEN Puesto_Bota_Oro
            WHEN @Top IS NULL THEN Puesto_Bota_Oro
            ELSE NULL 
        END AS Ranking_Torneo,
        Seleccion,
        Dorsal,
        Futbolista,
        Posicion,
        Fase,
        Goles_En_Fase,
        De_Penal,
        De_Jugada,
        Goles_Totales_Torneo
    FROM RankingGoleadores
    WHERE (@Top IS NULL OR Puesto_Bota_Oro <= @Top)
    ORDER BY Goles_Totales_Torneo DESC, Futbolista ASC, orden_secuencia ASC;
END;
GO