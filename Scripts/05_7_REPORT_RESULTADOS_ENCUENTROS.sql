/*
================================================================================
UNLaM - Base de Datos Aplicada (Comisión 5600)
Entrega 7 - Reporte 7: Resultados de los Encuentros (Formato XML / Tabular)
2026 - 2C
Grupo 10

Integrantes:
- Monasterio Erik: MonasteryEr
- Arena Ariel Ignacio: arielarena
- Castillo Gabriela Florencia: ItsFlorencia
- Maita Pitado Jose Gregorio: maita07

Archivo: 07_7_REPORT_RESULTADOS_ENCUENTROS.sql
Descripcion:
- Stored Procedure que reporta los resultados de los 104 partidos del Mundial.
- Retorna la información estructurada jerárquicamente en formato nativo XML
  (cumpliendo el requerimiento de al menos dos reportes con salida XML).
- Modos parametrizables: filtrado por Fase, Selección puntual o salida Tabular.
- No genera archivo físico en disco, devuelve el flujo XML directamente a pantalla.
================================================================================
*/
USE DB_Mundial2026_Grupo10;
GO

-- Asegurar existencia del esquema reportes
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'reportes')
BEGIN
    EXEC('CREATE SCHEMA reportes;');
END;
GO

CREATE OR ALTER PROCEDURE reportes.sp_REPORTE_RESULTADOS_ENCUENTROS
    @IdFase        INT         = NULL,  -- NULL = Todas las fases (1 a 7)
    @IdSeleccion   INT         = NULL,  -- NULL = Todas las selecciones
    @FormatoXML    BIT         = 1      -- 1 = Retorno XML (Por defecto para Entrega 7), 0 = Tabular
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. RETORNO EN FORMATO NATIVO XML (REQUERIMIENTO OBLIGATORIO)
    IF @FormatoXML = 1
    BEGIN
        SELECT 
            P.nro_partido_fase           AS [@NroPartido],
            F.nombre_fase                AS [@Fase],
            CONVERT(VARCHAR(19), P.fecha_hora_local, 120) AS [@FechaHoraLocal],
            SED.ciudad                   AS [Estadio/@Ciudad],
            SED.nombre_estadio           AS [Estadio/@Nombre],
            P.asistencia_oficial         AS [Estadio/@Asistencia],
            -- Detalle del Equipo Local
            SL.nombre_seleccion          AS [Resultado/Local/@Equipo],
            P.goles_local                AS [Resultado/Local/@Goles],
            P.penales_local              AS [Resultado/Local/@Penales],
            -- Detalle del Equipo Visitante
            SV.nombre_seleccion          AS [Resultado/Visitante/@Equipo],
            P.goles_visitante            AS [Resultado/Visitante/@Goles],
            P.penales_visitante          AS [Resultado/Visitante/@Penales],
            -- Ganador del Encuentro
            CASE 
                WHEN P.id_ganador_penales IS NOT NULL THEN S_Penal.nombre_seleccion + ' (por penales)'
                WHEN P.goles_local > P.goles_visitante THEN SL.nombre_seleccion
                WHEN P.goles_visitante > P.goles_local THEN SV.nombre_seleccion
                ELSE 'Empate'
            END AS [Resultado/@GanadorOficial],
            -- Sub-consulta anidada para eventos de GOL (1 a N)
            (
                SELECT 
                    G.id_gol                      AS [@NroGol],
                    CASE 
                        WHEN G.minuto_gol_extra IS NOT NULL 
                            THEN CAST(G.minuto_gol AS VARCHAR(5)) + '+' + CAST(G.minuto_gol_extra AS VARCHAR(5)) + ''''
                        ELSE CAST(G.minuto_gol AS VARCHAR(5)) + ''''
                    END                           AS [@Minuto],
                    G.tipo_gol                    AS [@Tipo],
                    S_Gol.nombre_seleccion        AS [@Equipo],
                    ISNULL(CONCAT(PER.nombre, ' ', PER.apellido), 'Jugador Desconocido') AS [@Autor],
                    C.dorsal_oficial              AS [@Dorsal]
                FROM torneo.GOL G
                INNER JOIN torneo.SELECCION S_Gol ON G.id_seleccion = S_Gol.id_seleccion
                LEFT JOIN  torneo.CONVOCATORIA C  ON G.id_seleccion = C.id_seleccion AND G.dorsal_autor = C.dorsal_oficial
                LEFT JOIN  persona.PERSONA PER    ON C.tipo_doc = PER.tipo_doc AND C.nro_doc = PER.nro_doc
                WHERE G.id_fase = P.id_fase 
                  AND G.nro_partido_fase = P.nro_partido_fase
                ORDER BY G.minuto_gol, G.id_gol
                FOR XML PATH('Gol'), TYPE
            ) AS [Goles]
        FROM torneo.PARTIDO P
        INNER JOIN torneo.FASE_TORNEO F      ON P.id_fase = F.id_fase
        INNER JOIN torneo.SEDE SED           ON P.id_sede = SED.id_sede
        INNER JOIN torneo.SELECCION SL       ON P.id_seleccion_local = SL.id_seleccion
        INNER JOIN torneo.SELECCION SV       ON P.id_seleccion_visitante = SV.id_seleccion
        LEFT JOIN  torneo.SELECCION S_Penal  ON P.id_ganador_penales = S_Penal.id_seleccion
        WHERE (@IdFase IS NULL OR P.id_fase = @IdFase)
          AND (@IdSeleccion IS NULL OR P.id_seleccion_local = @IdSeleccion OR P.id_seleccion_visitante = @IdSeleccion)
        ORDER BY F.orden_secuencia, P.nro_partido_fase
        FOR XML PATH('Partido'), ROOT('ResultadosMundial2026');

        RETURN;
    END;

    -- 2. RETORNO EN FORMATO TABULAR CON ILUSTRACIÓN DE MARCADOR
    SELECT 
        F.nombre_fase AS Fase,
        P.nro_partido_fase AS Nro_Partido,
        P.fecha_hora_local AS Fecha,
        SED.ciudad AS Sede,
        SED.nombre_estadio AS Estadio,
        -- Marcador Ilustrativo Estilo TV
        CONCAT(
            SL.nombre_seleccion, '  ', 
            P.goles_local, ' - ', P.goles_visitante, '  ', 
            SV.nombre_seleccion,
            CASE 
                WHEN P.id_ganador_penales IS NOT NULL 
                    THEN CONCAT(' (Pen: ', P.penales_local, '-', P.penales_visitante, ' - Ganó ', S_Penal.nombre_seleccion, ')')
                ELSE ''
            END
        ) AS Marcador_Oficial,
        P.asistencia_oficial AS Asistencia_Publico,
        -- Total de goles convertidos en el encuentro
        (SELECT COUNT(*) FROM torneo.GOL G WHERE G.id_fase = P.id_fase AND G.nro_partido_fase = P.nro_partido_fase) AS Cantidad_Goles
    FROM torneo.PARTIDO P
    INNER JOIN torneo.FASE_TORNEO F     ON P.id_fase = F.id_fase
    INNER JOIN torneo.SEDE SED          ON P.id_sede = SED.id_sede
    INNER JOIN torneo.SELECCION SL      ON P.id_seleccion_local = SL.id_seleccion
    INNER JOIN torneo.SELECCION SV      ON P.id_seleccion_visitante = SV.id_seleccion
    LEFT JOIN  torneo.SELECCION S_Penal ON P.id_ganador_penales = S_Penal.id_seleccion
    WHERE (@IdFase IS NULL OR P.id_fase = @IdFase)
      AND (@IdSeleccion IS NULL OR P.id_seleccion_local = @IdSeleccion OR P.id_seleccion_visitante = @IdSeleccion)
    ORDER BY F.orden_secuencia, P.nro_partido_fase;
END;
GO