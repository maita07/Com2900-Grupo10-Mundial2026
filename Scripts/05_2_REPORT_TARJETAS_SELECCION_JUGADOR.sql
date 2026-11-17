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

Archivo: 05_2_REPORTE_TARJETAS_SELECCION_JUGADOR.sql
Descripcion:
- Stored Procedure que reporta tarjetas amarillas y rojas por selección y jugador,
  con detalle de suspensiones activas por acumulación.
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

CREATE OR ALTER PROCEDURE reportes.sp_REPORTE_TARJETAS_SELECCION_JUGADOR
    @FormatoXML BIT = 1  -- 1 = Salida XML, 0 = Salida Tabular
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Tarjetas del torneo
    SELECT
        ST.nro_partido_fase,
        ST.id_tarjeta,
        ST.id_seleccion,
        ST.dorsal_sancionado,
        ST.tipo_tarjeta,
        ST.motivo,
        CONCAT(ST.minuto_sancion, '+' + CAST(ST.minuto_sancion_extra AS VARCHAR(5)), '''') AS minuto,
        F.nombre_fase,
        P.fecha_hora_local,
        SR.nombre_seleccion AS rival
    INTO #Tarjeta
    FROM torneo.SANCION_TARJETA ST
    INNER JOIN torneo.PARTIDO P     ON ST.id_fase = P.id_fase AND ST.nro_partido_fase = P.nro_partido_fase
    INNER JOIN torneo.FASE_TORNEO F ON ST.id_fase = F.id_fase
    INNER JOIN torneo.SELECCION SR  ON SR.id_seleccion = CASE WHEN P.id_seleccion_local = ST.id_seleccion
                                                              THEN P.id_seleccion_visitante
                                                              ELSE P.id_seleccion_local END;

    -- 2. Jugadores con tarjetas o con una suspensión pendiente
    SELECT
        C.id_seleccion,
        S.nombre_seleccion,
        S.grupo_asignado,
        C.dorsal_oficial,
        CONCAT(PER.nombre, ' ', PER.apellido) AS futbolista,
        PER.apellido,
        J.posicion_habitual,
        ISNULL(T.amarillas, 0)              AS amarillas,
        ISNULL(T.doble_amarilla, 0)         AS doble_amarilla,
        ISNULL(T.roja_directa, 0)           AS roja_directa,
        ISNULL(CS.amarillas_acumuladas, 0)  AS amarillas_vigentes,
        ISNULL(CS.partidos_suspension, 0)   AS partidos_pendientes,
        CASE WHEN CS.partidos_suspension > 0 THEN 'SUSPENDIDO'
             WHEN CS.cumplida = 1 THEN 'SUSPENSION CUMPLIDA'
             ELSE 'HABILITADO' END          AS estado,
        CAST(NULL AS VARCHAR(30))           AS origen
    INTO #Jugador
    FROM torneo.CONVOCATORIA C
    INNER JOIN torneo.SELECCION S  ON C.id_seleccion = S.id_seleccion
    INNER JOIN persona.PERSONA PER ON C.tipo_doc = PER.tipo_doc AND C.nro_doc = PER.nro_doc
    INNER JOIN persona.JUGADOR J   ON C.tipo_doc = J.tipo_doc AND C.nro_doc = J.nro_doc
    LEFT JOIN (
        SELECT
            id_seleccion,
            dorsal_sancionado,
            SUM(CASE WHEN tipo_tarjeta = 'AMARILLA' THEN 1 ELSE 0 END)       AS amarillas,
            SUM(CASE WHEN tipo_tarjeta = 'DOBLE_AMARILLA' THEN 1 ELSE 0 END) AS doble_amarilla,
            SUM(CASE WHEN tipo_tarjeta = 'ROJA_DIRECTA' THEN 1 ELSE 0 END)   AS roja_directa
        FROM #Tarjeta
        GROUP BY id_seleccion, dorsal_sancionado
    ) T ON C.id_seleccion = T.id_seleccion AND C.dorsal_oficial = T.dorsal_sancionado
    LEFT JOIN torneo.CONTROL_SUSPENSION CS ON C.id_seleccion = CS.id_seleccion AND C.dorsal_oficial = CS.dorsal_oficial
    WHERE T.id_seleccion IS NOT NULL OR CS.partidos_suspension > 0;

    -- Origen de la suspension pendiente (solo para suspendidos)
    UPDATE JG
    SET origen = CASE WHEN U.expulsion = 1 THEN 'Expulsión' ELSE 'Acumulación de amarillas' END
    FROM #Jugador JG
    CROSS APPLY (
        SELECT TOP 1 MAX(CASE WHEN X.tipo_tarjeta IN ('ROJA_DIRECTA', 'DOBLE_AMARILLA') THEN 1 ELSE 0 END) AS expulsion
        FROM torneo.SANCION_TARJETA X
        INNER JOIN torneo.PARTIDO PX ON X.id_fase = PX.id_fase AND X.nro_partido_fase = PX.nro_partido_fase
        WHERE X.id_seleccion = JG.id_seleccion
          AND X.dorsal_sancionado = JG.dorsal_oficial
        GROUP BY PX.fecha_hora_utc
        ORDER BY PX.fecha_hora_utc DESC
    ) U
    WHERE JG.partidos_pendientes > 0;

    -- 3. SALIDA EN XML (primero seleccion, despues jugador, y despues suspension/tarjetas)
    IF @FormatoXML = 1
    BEGIN
        SELECT
            (
                SELECT
                    JG.id_seleccion                                AS [@IdSeleccion],
                    JG.nombre_seleccion                            AS [@NombreSeleccion],
                    JG.grupo_asignado                              AS [@Grupo],
                    SUM(JG.amarillas)                              AS [@Amarillas],
                    SUM(JG.doble_amarilla)                         AS [@DobleAmarilla],
                    SUM(JG.roja_directa)                           AS [@RojaDirecta],
                    SUM(CASE WHEN JG.partidos_pendientes > 0 THEN 1 ELSE 0 END)     AS [@JugadoresSuspendidos],
                    -- Lista anidada de jugadores de la selección
                    (
                        SELECT
                            JG2.dorsal_oficial          AS [@Dorsal],
                            JG2.futbolista              AS [@Futbolista],
                            JG2.posicion_habitual       AS [@Posicion],
                            JG2.amarillas               AS [@Amarillas],
                            JG2.doble_amarilla          AS [@DobleAmarilla],
                            JG2.roja_directa            AS [@RojaDirecta],
                            JG2.estado                  AS [Suspension/@Estado],
                            JG2.amarillas_vigentes      AS [Suspension/@AmarillasVigentes],
                            JG2.partidos_pendientes     AS [Suspension/@PartidosPendientes],
                            JG2.origen                  AS [Suspension/@Origen],
                            -- Detalle de cada tarjeta del jugador
                            (
                                SELECT
                                    T.nombre_fase                                 AS [@Fase],
                                    T.nro_partido_fase                            AS [@NroPartido],
                                    CONVERT(VARCHAR(10), T.fecha_hora_local, 120) AS [@Fecha],
                                    T.rival                                       AS [@Rival],
                                    T.minuto                                      AS [@Minuto],
                                    T.tipo_tarjeta                                AS [@Tipo],
                                    T.motivo                                      AS [@Motivo]
                                FROM #Tarjeta T
                                WHERE T.id_seleccion = JG2.id_seleccion
                                  AND T.dorsal_sancionado = JG2.dorsal_oficial
                                ORDER BY T.fecha_hora_local, T.id_tarjeta
                                FOR XML PATH('Tarjeta'), TYPE
                            ) AS [Tarjetas]
                        FROM #Jugador JG2
                        WHERE JG2.id_seleccion = JG.id_seleccion
                        ORDER BY JG2.partidos_pendientes DESC,
                                 JG2.doble_amarilla + JG2.roja_directa DESC,
                                 JG2.amarillas DESC,
                                 JG2.apellido ASC
                        FOR XML PATH('Jugador'), ROOT('Jugadores'), TYPE
                    )
                FROM #Jugador JG
                GROUP BY JG.id_seleccion, JG.nombre_seleccion, JG.grupo_asignado
                ORDER BY SUM(JG.amarillas + JG.doble_amarilla + JG.roja_directa) DESC, JG.nombre_seleccion ASC
                FOR XML PATH('Seleccion'), TYPE
            )
        FOR XML PATH(''), ROOT('ReporteTarjetasMundial2026');

        RETURN;
    END;

    -- 4. SALIDA TABULAR (una fila por jugador)
    SELECT
        nombre_seleccion                                      AS Seleccion,
        dorsal_oficial                                        AS Dorsal,
        futbolista                                            AS Futbolista,
        posicion_habitual                                     AS Posicion,
        amarillas                                             AS Amarillas,
        doble_amarilla                                        AS Doble_Amarilla,
        roja_directa                                          AS Roja_Directa,
        amarillas + doble_amarilla + roja_directa             AS Total_Tarjetas,
        SUM(amarillas + doble_amarilla + roja_directa) OVER (PARTITION BY id_seleccion) AS Total_Tarjetas_Seleccion,
        amarillas_vigentes                                    AS Amarillas_Vigentes,
        partidos_pendientes                                   AS Partidos_Suspension_Pendientes,
        estado                                                AS Estado,
        origen                                                AS Origen_Suspension
    FROM #Jugador
    ORDER BY Total_Tarjetas_Seleccion DESC, Seleccion ASC, Partidos_Suspension_Pendientes DESC,
             Total_Tarjetas DESC, apellido ASC;
END;
GO