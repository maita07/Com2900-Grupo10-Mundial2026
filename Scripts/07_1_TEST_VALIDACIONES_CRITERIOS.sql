/*
================================================================================
UNLaM - Universidad Nacional de La Matanza
Departamento de Ingeniería e Investigaciones Tecnológicas
Materia: Base de Datos Aplicada (Comisión 5600)
Entrega 9 - Script 07_1: Prueba de valiadaciones y criterios de aceptacion del TP.
2026 - 2C
Grupo 10

Integrantes:
- Monasterio Erik: MonasteryEr
- Arena Ariel Ignacio: arielarena
- Castillo Gabriela Florencia: ItsFlorencia
- Maita Pitado Jose Gregorio: maita07

Archivo: 07_1_TEST_VALIDACIONES_CRITERIOS.sql
Descripcion:
- Consultas necesarias para cumplir con los Criterios de Aceptacion.
================================================================================
*/

USE DB_Mundial2026_Grupo10;
GO

--1. Al menos 8 sedes, con huso horario distinto entre al menos tres de ellas
-- Verifica cantidad de sedes y variedad de husos horarios

WITH SedesConHuso AS (
    SELECT 
        s.id_sede,
        s.nombre_estadio,
        s.ciudad,
        -- Determinación del huso horario según la ciudad de la sede
        CASE 
            WHEN s.ciudad IN ('Vancouver', 'Seattle', 'San Francisco', 'Los Ángeles', 'Los Angeles') 
                THEN 'UTC-7'
            WHEN s.ciudad IN ('Guadalajara', 'Ciudad de México', 'Monterrey', 'Dallas', 'Houston', 'Kansas City') 
                THEN 'UTC-5'
            WHEN s.ciudad IN ('Atlanta', 'Miami', 'Boston', 'Nueva York / Nueva Jersey', 'New York/New Jersey', 'Toronto', 'Filadelfia') 
                THEN 'UTC-4'
            ELSE 'UTC-5'
        END AS huso_horario
    FROM torneo.SEDE s
)
SELECT 
    COUNT(DISTINCT id_sede) AS Total_Sedes,
    COUNT(DISTINCT huso_horario) AS Total_Husos_Distintos,
    (
        -- En SQL Server se hace el DISTINCT dentro de una subconsulta para STRING_AGG
        SELECT STRING_AGG(huso, ', ')
        FROM (SELECT DISTINCT huso_horario AS huso FROM SedesConHuso) AS sub
    ) AS Husos_Horarios_Detectados,
    CASE 
        WHEN COUNT(DISTINCT id_sede) >= 8 AND COUNT(DISTINCT huso_horario) >= 3 
        THEN 'CUMPLE CON LA REGLA' 
        ELSE 'NO CUMPLE' 
    END AS Estado_Validacion
FROM SedesConHuso;

-- detalle fila por fila de cada sede con su huso:
SELECT 
    s.id_sede AS [ID Sede],
    s.nombre_estadio AS [Estadio],
    s.ciudad AS [Ciudad],
    s.capacidad AS [Capacidad],
    CASE 
        WHEN s.ciudad IN ('Vancouver', 'Seattle', 'San Francisco', 'Los Ángeles', 'Los Angeles') THEN 'UTC-7 (Pacífico)'
        WHEN s.ciudad IN ('Guadalajara', 'Ciudad de México', 'Monterrey', 'Dallas', 'Houston', 'Kansas City') THEN 'UTC-5 (Central)'
        WHEN s.ciudad IN ('Atlanta', 'Miami', 'Boston', 'Nueva York / Nueva Jersey', 'New York/New Jersey', 'Toronto', 'Filadelfia') THEN 'UTC-4 (Este)'
        ELSE 'UTC-5 (Central)'
    END AS [Huso Horario Asignado]
FROM torneo.SEDE s
ORDER BY [Huso Horario Asignado], s.ciudad;

-- Validación global: Al menos 16 selecciones con >= 23 convocados
-- Detalle por selección:
SELECT 
    COUNT(*) AS Total_Selecciones_Con_Mas_De_23,
    CASE 
        WHEN COUNT(*) >= 16 THEN 'CUMPLE CON LA REGLA (>= 16)' 
        ELSE 'NO CUMPLE' 
    END AS Estado_Global
FROM (
    SELECT 
        c.id_seleccion
    FROM torneo.CONVOCATORIA c
    GROUP BY c.id_seleccion
    HAVING COUNT(DISTINCT c.nro_doc) >= 23
) AS Sub;

--3. Al menos 24 partidos (grupos y eliminación directa) con titulares y suplentes
WITH EquiposValidosPorPartido AS (
    SELECT 
        ja.id_fase,
        ja.nro_partido_fase,
        ja.id_seleccion,
        SUM(CASE WHEN ja.es_titular = 1 THEN 1 ELSE 0 END) AS cant_titulares,
        SUM(CASE WHEN ja.es_titular = 0 THEN 1 ELSE 0 END) AS cant_suplentes
    FROM torneo.JUGADOR_ALINEACION ja
    GROUP BY ja.id_fase, ja.nro_partido_fase, ja.id_seleccion
    HAVING SUM(CASE WHEN ja.es_titular = 1 THEN 1 ELSE 0 END) = 11
       AND SUM(CASE WHEN ja.es_titular = 0 THEN 1 ELSE 0 END) >= 1
),
PartidosCompletos AS (
    SELECT 
        id_fase,
        nro_partido_fase
    FROM EquiposValidosPorPartido
    GROUP BY id_fase, nro_partido_fase
    HAVING COUNT(id_seleccion) = 2  -- Ambos equipos con 11 titulares y suplentes
)
SELECT 
    COUNT(*) AS Total_Partidos_Completos,
    COUNT(DISTINCT id_fase) AS Total_Fases_Distintas,
    CASE 
        WHEN COUNT(*) >= 24 AND COUNT(DISTINCT id_fase) >= 2
        THEN 'CUMPLE CON LA REGLA (>= 24 Partidos en Grupos y Eliminación)' 
        ELSE 'NO CUMPLE' 
    END AS Estado_Global
FROM PartidosCompletos;


--4. Al menos 15 árbitros con asignación completa en cada partido (Principal, Asistentes, 4to y VAR)
-- 1. Verifica que existan al menos 15 árbitros en la nómina
SELECT 
    COUNT(DISTINCT CONCAT(a.tipo_doc, '-', a.nro_doc)) AS Total_Arbitros_Nomina,
    CASE 
        WHEN COUNT(DISTINCT CONCAT(a.tipo_doc, '-', a.nro_doc)) >= 15 
        THEN 'CUMPLE CON LA REGLA (>= 15 Árbitros en Nómina)' 
        ELSE 'NO CUMPLE' 
    END AS Estado_Nomina
FROM persona.ARBITRO a;

-- 2. Verifica la cuarteta + VAR en cada partido
WITH RolesPorPartido AS (
    SELECT 
        d.id_fase,
        d.nro_partido_fase,
        COUNT(DISTINCT CONCAT(d.tipo_doc, '-', d.nro_doc)) AS Total_Arbitros,
        -- Verificación de roles clave según rol_descripcion
        SUM(CASE WHEN r.rol_descripcion LIKE '%Principal%' OR r.rol_descripcion LIKE '%Árbitro%' THEN 1 ELSE 0 END) AS Principal,
        SUM(CASE WHEN r.rol_descripcion LIKE '%Asistente%' OR r.rol_descripcion LIKE '%Línea%' THEN 1 ELSE 0 END)     AS Asistentes,
        SUM(CASE WHEN r.rol_descripcion LIKE '%Cuarto%' OR r.rol_descripcion LIKE '%4to%' THEN 1 ELSE 0 END)          AS Cuarto_Arbitro,
        SUM(CASE WHEN r.rol_descripcion LIKE '%VAR%' THEN 1 ELSE 0 END)                                                AS VAR
    FROM torneo.DESIGNACION_ARBITRAL d
    INNER JOIN torneo.ROL_ARBITRAL r 
        ON d.id_rol = r.id_rol
    GROUP BY d.id_fase, d.nro_partido_fase
)
SELECT 
    id_fase                                                                 AS [Fase],
    nro_partido_fase                                                        AS [Partido #],
    Total_Arbitros                                                          AS [Total Designados],
    Principal                                                               AS [Principal],
    Asistentes                                                              AS [Asistentes],
    Cuarto_Arbitro                                                          AS [4to Árbitro],
    VAR                                                                     AS [VAR],
    CASE 
        WHEN Total_Arbitros >= 5 THEN 'CUARTETA + VAR COMPLETA'
        ELSE 'INCOMPLETA'
    END                                                                     AS [Estado_Partido]
FROM RolesPorPartido
ORDER BY id_fase ASC, nro_partido_fase ASC;


--5. Historial de campañas publicitarias con anunciantes de al menos 6 países distintos
-- Conteo de anunciantes por país y verificación del mínimo de 6 países
WITH PaisesDistintosAnunciantes AS (
    SELECT DISTINCT 
        pa.id_pais,
        pa.nombre_pais
    FROM comercial.CAMPANIA_PUBLICITARIA cp
    INNER JOIN comercial.ANUNCIANTE an 
        ON cp.id_anunciante = an.id_anunciante
    INNER JOIN geografia.PAIS pa 
        ON an.id_pais_origen = pa.id_pais
)
SELECT 
    COUNT(*) AS Total_Paises_Anunciantes,
    STRING_AGG(nombre_pais, ', ') WITHIN GROUP (ORDER BY nombre_pais ASC) AS Paises_Involucrados,
    CASE 
        WHEN COUNT(*) >= 6 THEN 'CUMPLE CON LA REGLA (>= 6 Países)' 
        ELSE 'NO CUMPLE' 
    END AS Estado_Validacion
FROM PaisesDistintosAnunciantes;

--6. Casos Obligatorios: Un partido con expulsión por doble amarilla y otro con roja directa
WITH ExpulsionesDetectadas AS (
    SELECT 
        id_fase,
        nro_partido_fase,
        CASE 
            WHEN tipo_tarjeta LIKE '%DOBLE%' OR motivo LIKE '%Doble%' THEN 'DOBLE_AMARILLA'
            WHEN tipo_tarjeta LIKE '%ROJA%' OR motivo LIKE '%Directa%' OR motivo LIKE '%Roja%' THEN 'ROJA_DIRECTA'
            ELSE 'OTRO'
        END AS Categoria_Expulsion
    FROM torneo.SANCION_TARJETA
)
SELECT 
    COUNT(CASE WHEN Categoria_Expulsion = 'DOBLE_AMARILLA' THEN CONCAT(id_fase, '-', nro_partido_fase) END) AS Partidos_Con_Doble_Amarilla,
    COUNT(CASE WHEN Categoria_Expulsion = 'ROJA_DIRECTA' THEN CONCAT(id_fase, '-', nro_partido_fase) END)   AS Partidos_Con_Roja_Directa,
    CASE 
        WHEN COUNT(DISTINCT CASE WHEN Categoria_Expulsion = 'DOBLE_AMARILLA' THEN CONCAT(id_fase, '-', nro_partido_fase) END) >= 1
         AND COUNT(DISTINCT CASE WHEN Categoria_Expulsion = 'ROJA_DIRECTA' THEN CONCAT(id_fase, '-', nro_partido_fase) END) >= 1
        THEN 'CUMPLE CON LA REGLA (Ambos Casos Registrados)' 
        ELSE 'NO CUMPLE' 
    END AS Estado_Validacion
FROM ExpulsionesDetectadas;

--7. Casos Obligatorios: Jugador suspendido por acumulación de amarillas que queda afuera del siguiente partido
WITH Amarillas AS (
    SELECT st.id_seleccion, st.dorsal_sancionado, st.id_fase, st.nro_partido_fase, p.fecha_hora_utc,
           DENSE_RANK() OVER (
               PARTITION BY st.id_seleccion, st.dorsal_sancionado,
                            CASE WHEN st.id_fase = 1 THEN 1 WHEN st.id_fase <= 4 THEN 2 ELSE 3 END
               ORDER BY p.fecha_hora_utc) AS Nro_Amarilla
    FROM torneo.SANCION_TARJETA st
    INNER JOIN torneo.PARTIDO p ON p.id_fase = st.id_fase AND p.nro_partido_fase = st.nro_partido_fase
    WHERE st.tipo_tarjeta = 'AMARILLA'
      AND NOT EXISTS (SELECT 1 FROM torneo.SANCION_TARJETA d
                      WHERE d.id_fase = st.id_fase AND d.nro_partido_fase = st.nro_partido_fase
                        AND d.id_seleccion = st.id_seleccion AND d.dorsal_sancionado = st.dorsal_sancionado
                        AND d.tipo_tarjeta = 'DOBLE_AMARILLA')
)
SELECT
    s.nombre_seleccion                                              AS [Selección],
    a.dorsal_sancionado                                             AS [Dorsal],
    CONCAT('Fase ', a.id_fase, ' - Part. ', a.nro_partido_fase)     AS [Partido Sanción],
    IIF(sig.id_fase IS NULL, '-',
        CONCAT('Fase ', sig.id_fase, ' - Part. ', sig.nro_partido_fase)) AS [Partido Cumplimiento],
    CASE WHEN sig.id_fase IS NULL       THEN 'SIN PARTIDO POSTERIOR (SELECCIÓN ELIMINADA)'
         WHEN ja.dorsal_oficial IS NULL THEN 'CUMPLE: FUERA DE LA PLANILLA (SUSPENDIDO)'
         ELSE 'VIOLACIÓN: APARECE EN PLANILLA'
    END                                                             AS [Estado_Suspension]
FROM Amarillas a
INNER JOIN torneo.SELECCION s ON s.id_seleccion = a.id_seleccion
OUTER APPLY (SELECT TOP 1 p.id_fase, p.nro_partido_fase
             FROM torneo.PARTIDO p
             WHERE a.id_seleccion IN (p.id_seleccion_local, p.id_seleccion_visitante)
               AND p.fecha_hora_utc > a.fecha_hora_utc
             ORDER BY p.fecha_hora_utc) sig
LEFT JOIN torneo.JUGADOR_ALINEACION ja
    ON ja.id_fase = sig.id_fase AND ja.nro_partido_fase = sig.nro_partido_fase
   AND ja.id_seleccion = a.id_seleccion AND ja.dorsal_oficial = a.dorsal_sancionado
WHERE a.Nro_Amarilla = 2;

--8. Casos Obligatorios: Cambio realizado por lesión dentro de los primeros 20 minutos
;WITH FormacionPorPartido AS(
    SELECT s.id_seleccion,
    s.nombre_seleccion,
           con.dorsal_oficial AS Nro_Camiseta,
           per.nombre AS Nombre,
           per.apellido AS Apellido
    FROM torneo.SELECCION s
    JOIN torneo.CONVOCATORIA con ON con.id_seleccion = s.id_seleccion
    JOIN persona.PERSONA per ON per.nro_doc = con.nro_doc AND per.tipo_doc = con.tipo_doc
           
)
SELECT 
    sus.nro_partido_fase AS Nro_Partido,
    p_entra.nombre_seleccion AS Seleccion,
    sus.minuto_cambio AS [Minuto Cambio],
    p_sale.apellido + ' ' + p_sale.nombre AS [Sale Lesionado],
    p_entra.apellido + ' ' + p_entra.nombre AS [Entra al Campo],
    CASE 
        WHEN sus.minuto_cambio <= 20
        THEN 'CUMPLE CASO (<= 20 min)'
        ELSE 'Otro Cambio'
    END AS [Estado]
FROM torneo.SUSTITUCION sus
JOIN FormacionPorPartido p_entra ON sus.dorsal_entra = p_entra.Nro_Camiseta AND sus.id_seleccion = p_entra.id_seleccion
JOIN FormacionPorPartido p_sale ON sus.dorsal_sale = p_sale.Nro_Camiseta AND sus.id_seleccion = p_sale.id_seleccion
WHERE sus.minuto_cambio <= 20;

--9. Casos Obligatorios: Partido en Prime Time con más de 4 mercados y priorización de 4
WITH MercadosPartidoHoraLocal AS (
    SELECT DISTINCT
        ep.id_fase,
        ep.nro_partido_fase,
        pm.id_pais,
        DATEADD(MINUTE,
        CAST(geografia.fn_ObtenerDesplazamientoUTC(pm.id_pais) * 60 AS INT),
            p.fecha_hora_utc
        ) AS fecha_hora_mercado
    FROM comercial.EXHIBICION_PUBLICITARIA ep
    INNER JOIN comercial.PIEZA_MERCADO pm ON ep.id_pieza = pm.id_pieza
    INNER JOIN torneo.PARTIDO p ON ep.id_fase = p.id_fase AND ep.nro_partido_fase = p.nro_partido_fase
)
SELECT
    p.id_fase,
    ft.nombre_fase,
    p.nro_partido_fase,
    sl.nombre_seleccion AS Local,
    sv.nombre_seleccion AS Visitante,
    p.fecha_hora_utc,
    COUNT(DISTINCT mph.id_pais) AS Cant_Mercados_Prime_Time 
FROM torneo.PARTIDO p
JOIN torneo.FASE_TORNEO ft ON p.id_fase = ft.id_fase
JOIN torneo.SELECCION sl ON p.id_seleccion_local = sl.id_seleccion
JOIN torneo.SELECCION sv ON p.id_seleccion_visitante = sv.id_seleccion
JOIN MercadosPartidoHoraLocal mph ON p.id_fase = mph.id_fase AND p.nro_partido_fase = mph.nro_partido_fase
WHERE DATEPART(HOUR, mph.fecha_hora_mercado) BETWEEN 19 AND 22
GROUP BY
    p.id_fase,
    ft.nombre_fase,
    p.nro_partido_fase,
    sl.nombre_seleccion,
    sv.nombre_seleccion,
    p.fecha_hora_utc
HAVING COUNT(DISTINCT mph.id_pais) >= 4
ORDER BY
    Cant_Mercados_Prime_Time DESC,
    p.fecha_hora_utc ASC;


--10. Casos Obligatorios: Designación arbitral descartada por conflicto de nacionalidad
DECLARE @fase INT, @nro INT, @doc VARCHAR(20), @tipo VARCHAR(10), @rol INT;

SELECT TOP 1 @fase = p.id_fase, @nro = p.nro_partido_fase, @doc = a.nro_doc, @tipo = a.tipo_doc, @rol = a.id_rol
FROM torneo.PARTIDO p
INNER JOIN torneo.SELECCION s ON s.id_seleccion IN (p.id_seleccion_local, p.id_seleccion_visitante)
INNER JOIN persona.PERSONA pe ON pe.id_nacionalidad_pais = s.id_pais
INNER JOIN persona.ARBITRO a ON a.nro_doc = pe.nro_doc AND a.tipo_doc = pe.tipo_doc;

BEGIN TRY
    EXEC torneo.sp_DESIGNACION_ARBITRAL_ABM @Accion = 'A', @id_fase = @fase, @nro_partido_fase = @nro,
         @nro_doc = @doc, @tipo_doc = @tipo, @id_rol = @rol;
    SELECT 'NO CUMPLE: la designación fue aceptada' AS Estado_Validacion;
END TRY
BEGIN CATCH
    SELECT @fase AS Fase, @nro AS Partido, @doc AS Doc_Arbitro, ERROR_MESSAGE() AS Motivo_Rechazo;
END CATCH;