/*
================================================================================
UNLaM - Base de Datos Aplicada (Comisión 5600)
Entrega 7 - Reporte 5: Matriz de Prime Time (Pivot por Mercado/País)
2026 - 2C
Grupo 10

Integrantes:
- Monasterio Erik: MonasteryEr
- Arena Ariel Ignacio: arielarena
- Castillo Gabriela Florencia: ItsFlorencia
- Maita Pitado Jose Gregorio: maita07

Archivo: 05_5_REPORT_MATRIZ_PRIME_TIME.sql
Descripcion:
- Stored Procedure que genera una tabla cruzada (PIVOT) indicando para cada
  partido en qué mercados/países su horario de inicio cae en prime time.
- Salida en grilla tabular PIVOT (por defecto) o en formato nativo XML.
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

CREATE OR ALTER PROCEDURE reportes.sp_REPORTE_MATRIZ_PRIME_TIME
    @HoraInicioPrimeTime INT = 19,
    @HoraFinPrimeTime    INT = 23,
    @IdFase              INT = NULL,-- NULL = Todas las fases
    @FormatoXML          BIT = 0    -- 0 = Tabla Cruzada PIVOT (por defecto), 1 = XML
AS
BEGIN
    SET NOCOUNT ON;

    CREATE TABLE #MercadosEvaluar (
        id_pais CHAR(3) PRIMARY KEY,
        nombre_pais VARCHAR(50),
        desplazamiento_utc DECIMAL(4,1)
    );

    INSERT INTO #MercadosEvaluar (id_pais, nombre_pais, desplazamiento_utc)
    SELECT DISTINCT
        PA.id_pais,
        PA.nombre_pais,
        geografia.fn_ObtenerDesplazamientoUTC(PA.id_pais)
    FROM comercial.PIEZA_MERCADO PM
    INNER JOIN geografia.PAIS PA ON PM.id_pais = PA.id_pais;

    -- 1. SALIDA EN XML (Partido con vector anidado de mercados en Prime Time)
    IF @FormatoXML = 1
    BEGIN
        SELECT
            (
                SELECT
                    F.nombre_fase                                               AS [@Fase],
                    P.nro_partido_fase                                          AS [@NroPartido],
                    CONCAT(SL.nombre_seleccion, ' vs ', SV.nombre_seleccion)    AS [@Encuentro],
                    CONVERT(VARCHAR(16), P.fecha_hora_utc, 120)                 AS [@FechaHoraUTC],
                    (
                        SELECT COUNT(*)
                        FROM #MercadosEvaluar M_Cnt
                        WHERE DATEPART(HOUR, DATEADD(MINUTE, CAST(M_Cnt.desplazamiento_utc * 60 AS INT), P.fecha_hora_utc))
                              BETWEEN @HoraInicioPrimeTime AND @HoraFinPrimeTime
                    )                                                           AS [@TotalMercadosPrimeTime],
                    -- Vector de países donde el partido cae en Prime Time
                    (
                        SELECT
                            M.id_pais                                           AS [@CodigoPais],
                            M.nombre_pais                                       AS [@Pais],
                            FORMAT(DATEADD(MINUTE, CAST(M.desplazamiento_utc * 60 AS INT), P.fecha_hora_utc), 'HH:mm') AS [@HoraLocalMercado]
                        FROM #MercadosEvaluar M
                        WHERE DATEPART(HOUR, DATEADD(MINUTE, CAST(M.desplazamiento_utc * 60 AS INT), P.fecha_hora_utc))
                              BETWEEN @HoraInicioPrimeTime AND @HoraFinPrimeTime
                        ORDER BY M.id_pais ASC
                        FOR XML PATH('Mercado'), ROOT('MercadosPrimeTime'), TYPE
                    )
                FROM torneo.PARTIDO P
                INNER JOIN torneo.FASE_TORNEO F ON P.id_fase = F.id_fase
                INNER JOIN torneo.SELECCION SL  ON P.id_seleccion_local = SL.id_seleccion
                INNER JOIN torneo.SELECCION SV  ON P.id_seleccion_visitante = SV.id_seleccion
                WHERE (@IdFase IS NULL OR P.id_fase = @IdFase)
                ORDER BY F.orden_secuencia ASC, P.nro_partido_fase ASC
                FOR XML PATH('Partido'), TYPE
            )
        FOR XML PATH(''), ROOT('ReporteMatrizPrimeTimeMundial2026');

        RETURN;
    END;

    -- 2. SALIDA TABULAR: MATRIZ CRUZADA (PIVOT DINÁMICO)
    DECLARE @ColumnasPivot NVARCHAR(MAX);
    DECLARE @SQL           NVARCHAR(MAX);

    SELECT @ColumnasPivot = STRING_AGG(QUOTENAME(id_pais), ',') WITHIN GROUP (ORDER BY id_pais)
    FROM #MercadosEvaluar;

    IF @ColumnasPivot IS NULL
    BEGIN
        SELECT 'No hay mercados disponibles para generar la matriz.' AS Mensaje;
        RETURN;
    END;

    SET @SQL = N'
    WITH BasePrimeTime AS (
        SELECT
            F.orden_secuencia,
            F.nombre_fase AS Fase,
            P.nro_partido_fase AS Nro_Partido,
            CONCAT(SL.nombre_seleccion, '' vs '', SV.nombre_seleccion) AS Encuentro,
            CONVERT(VARCHAR(16), P.fecha_hora_utc, 120) AS Fecha_Hora_UTC,
            M.id_pais,
            CASE
                WHEN DATEPART(HOUR, DATEADD(MINUTE, CAST(M.desplazamiento_utc * 60 AS INT), P.fecha_hora_utc))
                     BETWEEN @pHoraIni AND @pHoraFin
                THEN ''SI ('' + FORMAT(DATEADD(MINUTE, CAST(M.desplazamiento_utc * 60 AS INT), P.fecha_hora_utc), ''HH:mm'') + '')''
                ELSE ''NO''
            END AS Estado_Prime_Time
        FROM torneo.PARTIDO P
        INNER JOIN torneo.FASE_TORNEO F ON P.id_fase = F.id_fase
        INNER JOIN torneo.SELECCION SL  ON P.id_seleccion_local = SL.id_seleccion
        INNER JOIN torneo.SELECCION SV  ON P.id_seleccion_visitante = SV.id_seleccion
        CROSS JOIN #MercadosEvaluar M
        WHERE (@pIdFase IS NULL OR P.id_fase = @pIdFase)
    )
    SELECT
        Fase,
        Nro_Partido,
        Encuentro,
        Fecha_Hora_UTC,
        ' + @ColumnasPivot + N'
    FROM BasePrimeTime
    PIVOT (
        MAX(Estado_Prime_Time)
        FOR id_pais IN (' + @ColumnasPivot + N')
    ) AS Matriz
    ORDER BY orden_secuencia ASC, Nro_Partido ASC;';

    EXEC sp_executesql
        @SQL,
        N'@pHoraIni INT, @pHoraFin INT, @pIdFase INT',
        @pHoraIni = @HoraInicioPrimeTime,
        @pHoraFin = @HoraFinPrimeTime,
        @pIdFase  = @IdFase;
END;
GO