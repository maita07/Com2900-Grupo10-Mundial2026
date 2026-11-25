/*
================================================================================
UNLaM - Base de Datos Aplicada (Comisión 5600)
Entrega 7 - Reporte 4: Ocupación Publicitaria por Sede y Partido
2026 - 2C
Grupo 10

Integrantes:
- Monasterio Erik: MonasteryEr
- Arena Ariel Ignacio: arielarena
- Castillo Gabriela Florencia: ItsFlorencia
- Maita Pitado Jose Gregorio: maita07

Archivo: 05_4_REPORT_OCUPACION_PUBLICITARIA.sql
Descripcion:
- Stored Procedure que reporta la ocupación publicitaria por sede y partido,
  detallando los anunciantes exhibidos en los cuatro espacios (letreros 1 a 4)
  y los ingresos generados en USD.
- Permite filtrar opcionalmente por sede (@IdSede) o fase (@IdFase).
- Salida en formato nativo XML o en grilla tabular (por defecto).
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

CREATE OR ALTER PROCEDURE reportes.sp_REPORTE_OCUPACION_PUBLICITARIA
    @IdSede     INT = NULL,  -- NULL = Todas las sedes
    @IdFase     INT = NULL,  -- NULL = Todas las fases
    @FormatoXML BIT = 0      -- 1 = Salida XML, 0 = Salida Tabular
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. SALIDA EN XML (Jerarquía: Sede -> Partido -> Espacio -> Exhibicion)
    IF @FormatoXML = 1
    BEGIN
        SELECT
            (
                SELECT
                    SED.id_sede                                                 AS [@IdSede],
                    SED.nombre_estadio                                          AS [@Estadio],
                    SED.ciudad                                                  AS [@Ciudad],
                    PA.nombre_pais                                              AS [@PaisSede],
                    COUNT(DISTINCT CONCAT(P.id_fase, '-', P.nro_partido_fase))  AS [@CantidadPartidos],
                    ISNULL(SUM(EP.costo_calculado_usd), 0)                      AS [@IngresosTotalesUSD],
                    -- Partidos disputados en esa sede
                    (
                        SELECT
                            F.nombre_fase                                           AS [@Fase],
                            P2.nro_partido_fase                                     AS [@NroPartido],
                            CONVERT(VARCHAR(16), P2.fecha_hora_local, 120)          AS [@FechaHoraLocal],
                            CONCAT(SL.nombre_seleccion, ' vs ', SV.nombre_seleccion) AS [@Encuentro],
                            ISNULL((
                                SELECT SUM(EP_Sub.costo_calculado_usd)
                                FROM comercial.EXHIBICION_PUBLICITARIA EP_Sub
                                WHERE EP_Sub.id_fase = P2.id_fase
                                  AND EP_Sub.nro_partido_fase = P2.nro_partido_fase
                            ), 0)                                                   AS [@IngresosPartidoUSD],
                            -- Los 4 espacios publicitarios del partido
                            (
                                SELECT
                                    Esp.nro_espacio                                 AS [@NroEspacio],
                                    ISNULL(SUM(EP2.costo_calculado_usd), 0)         AS [@IngresosEspacioUSD],
                                    COUNT(EP2.id_exhibicion)                        AS [@CantidadPautas],
                                    -- Anunciantes exhibidos dentro de cada espacio
                                    (
                                        SELECT
                                            EP3.minuto_inicio                       AS [@MinutoInicio],
                                            EP3.minuto_fin                          AS [@MinutoFin],
                                            A.marca_comercial                       AS [@Anunciante],
                                            A.rubro                                 AS [@Rubro],
                                            C.nombre_campania                       AS [@Campania],
                                            PP.descripcion_pieza                    AS [@Pieza],
                                            EP3.costo_calculado_usd                 AS [@CostoUSD]
                                        FROM comercial.EXHIBICION_PUBLICITARIA EP3
                                        INNER JOIN comercial.ANUNCIANTE A            ON EP3.id_anunciante = A.id_anunciante
                                        INNER JOIN comercial.CAMPANIA_PUBLICITARIA C ON EP3.id_campania = C.id_campania
                                        INNER JOIN comercial.PIEZA_PUBLICITARIA PP   ON EP3.id_pieza = PP.id_pieza
                                        WHERE EP3.id_fase = P2.id_fase
                                          AND EP3.nro_partido_fase = P2.nro_partido_fase
                                          AND EP3.letrero_posicion = Esp.nro_espacio
                                        ORDER BY EP3.minuto_inicio ASC
                                        FOR XML PATH('Exhibicion'), TYPE
                                    )
                                FROM (VALUES (1), (2), (3), (4)) AS Esp(nro_espacio)
                                LEFT JOIN comercial.EXHIBICION_PUBLICITARIA EP2
                                    ON EP2.id_fase = P2.id_fase
                                   AND EP2.nro_partido_fase = P2.nro_partido_fase
                                   AND EP2.letrero_posicion = Esp.nro_espacio
                                GROUP BY Esp.nro_espacio
                                ORDER BY Esp.nro_espacio ASC
                                FOR XML PATH('Espacio'), ROOT('Espacios'), TYPE
                            )
                        FROM torneo.PARTIDO P2
                        INNER JOIN torneo.FASE_TORNEO F  ON P2.id_fase = F.id_fase
                        INNER JOIN torneo.SELECCION SL   ON P2.id_seleccion_local = SL.id_seleccion
                        INNER JOIN torneo.SELECCION SV   ON P2.id_seleccion_visitante = SV.id_seleccion
                        WHERE P2.id_sede = SED.id_sede
                          AND (@IdFase IS NULL OR P2.id_fase = @IdFase)
                        ORDER BY F.orden_secuencia ASC, P2.nro_partido_fase ASC
                        FOR XML PATH('Partido'), ROOT('Partidos'), TYPE
                    )
                FROM torneo.SEDE SED
                INNER JOIN geografia.PAIS PA  ON SED.id_pais = PA.id_pais
                INNER JOIN torneo.PARTIDO P   ON SED.id_sede = P.id_sede
                LEFT JOIN comercial.EXHIBICION_PUBLICITARIA EP
                    ON P.id_fase = EP.id_fase
                   AND P.nro_partido_fase = EP.nro_partido_fase
                WHERE (@IdSede IS NULL OR SED.id_sede = @IdSede)
                  AND (@IdFase IS NULL OR P.id_fase = @IdFase)
                GROUP BY SED.id_sede, SED.nombre_estadio, SED.ciudad, PA.nombre_pais
                ORDER BY SED.ciudad ASC, SED.nombre_estadio ASC
                FOR XML PATH('Sede'), TYPE
            )
        FOR XML PATH(''), ROOT('ReporteOcupacionPublicitariaMundial2026');

        RETURN;
    END;

    -- 2. SALIDA TABULAR (Una fila por partido, con los 4 espacios en columnas + ingresos)
    WITH ExhibicionesUnicas AS (
        SELECT DISTINCT
            EP.id_fase,
            EP.nro_partido_fase,
            EP.letrero_posicion,
            A.marca_comercial
        FROM comercial.EXHIBICION_PUBLICITARIA EP
        INNER JOIN comercial.ANUNCIANTE A ON EP.id_anunciante = A.id_anunciante
    ),
    ResumenPorPartido AS (
        SELECT
            P.id_fase,
            P.nro_partido_fase,
            ISNULL(SUM(EP.costo_calculado_usd), 0) AS Ingresos_Partido_USD
        FROM torneo.PARTIDO P
        LEFT JOIN comercial.EXHIBICION_PUBLICITARIA EP
            ON P.id_fase = EP.id_fase
           AND P.nro_partido_fase = EP.nro_partido_fase
        GROUP BY P.id_fase, P.nro_partido_fase
    )
    SELECT
        SED.ciudad                                                      AS Ciudad,
        SED.nombre_estadio                                              AS Estadio,
        F.nombre_fase                                                   AS Fase,
        P.nro_partido_fase                                              AS Nro_Partido,
        P.fecha_hora_local                                              AS Fecha_Local,
        CONCAT(SL.nombre_seleccion, ' vs ', SV.nombre_seleccion)        AS Encuentro,
        ISNULL((SELECT STRING_AGG(marca_comercial, ', ') FROM ExhibicionesUnicas E WHERE E.id_fase = P.id_fase AND E.nro_partido_fase = P.nro_partido_fase AND E.letrero_posicion = 1), 'Sin pauta') AS Espacio_1,
        ISNULL((SELECT STRING_AGG(marca_comercial, ', ') FROM ExhibicionesUnicas E WHERE E.id_fase = P.id_fase AND E.nro_partido_fase = P.nro_partido_fase AND E.letrero_posicion = 2), 'Sin pauta') AS Espacio_2,
        ISNULL((SELECT STRING_AGG(marca_comercial, ', ') FROM ExhibicionesUnicas E WHERE E.id_fase = P.id_fase AND E.nro_partido_fase = P.nro_partido_fase AND E.letrero_posicion = 3), 'Sin pauta') AS Espacio_3,
        ISNULL((SELECT STRING_AGG(marca_comercial, ', ') FROM ExhibicionesUnicas E WHERE E.id_fase = P.id_fase AND E.nro_partido_fase = P.nro_partido_fase AND E.letrero_posicion = 4), 'Sin pauta') AS Espacio_4,
        RP.Ingresos_Partido_USD                                         AS Ingresos_Partido_USD,
        SUM(RP.Ingresos_Partido_USD) OVER (PARTITION BY SED.id_sede)    AS Ingresos_Totales_Sede_USD
    FROM torneo.PARTIDO P
    INNER JOIN torneo.SEDE SED          ON P.id_sede = SED.id_sede
    INNER JOIN torneo.FASE_TORNEO F     ON P.id_fase = F.id_fase
    INNER JOIN torneo.SELECCION SL      ON P.id_seleccion_local = SL.id_seleccion
    INNER JOIN torneo.SELECCION SV      ON P.id_seleccion_visitante = SV.id_seleccion
    INNER JOIN ResumenPorPartido RP     ON P.id_fase = RP.id_fase AND P.nro_partido_fase = RP.nro_partido_fase
    WHERE (@IdSede IS NULL OR SED.id_sede = @IdSede)
      AND (@IdFase IS NULL OR P.id_fase = @IdFase)
    ORDER BY SED.ciudad ASC, SED.nombre_estadio ASC, F.orden_secuencia ASC, P.nro_partido_fase ASC;
END;
GO