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
WITH HistorialAmarillas AS (
    SELECT 
        st.id_seleccion,
        st.dorsal_sancionado,
        st.id_fase,
        st.nro_partido_fase,
        ROW_NUMBER() OVER (
            PARTITION BY st.id_seleccion, st.dorsal_sancionado 
            ORDER BY st.id_fase ASC, st.nro_partido_fase ASC
        ) AS Nro_Amarilla
    FROM torneo.SANCION_TARJETA st
    WHERE st.tipo_tarjeta LIKE '%AMARILLA%' 
      AND st.tipo_tarjeta NOT LIKE '%DOBLE%' -- Solo amarillas simples acumulativas
),
SegundaAmarilla AS (
    -- Partido donde el jugador recibe la 2da amarilla y queda inhabilitado
    SELECT 
        ha.id_seleccion,
        ha.dorsal_sancionado,
        ha.id_fase          AS Fase_Segunda_Amarilla,
        ha.nro_partido_fase AS Partido_Segunda_Amarilla
    FROM HistorialAmarillas ha
    WHERE ha.Nro_Amarilla = 2
),
SiguientePartidoSeleccion AS (
    -- Busca cuál fue el partido inmediatamente posterior jugado por esa misma selección
    SELECT 
        sa.id_seleccion,
        sa.dorsal_sancionado,
        sa.Fase_Segunda_Amarilla,
        sa.Partido_Segunda_Amarilla,
        min_post.id_fase            AS Fase_Siguiente_Partido,
        min_post.nro_partido_fase   AS Nro_Siguiente_Partido
    FROM SegundaAmarilla sa
    CROSS APPLY (
        SELECT TOP 1 ja.id_fase, ja.nro_partido_fase
        FROM torneo.JUGADOR_ALINEACION ja
        WHERE ja.id_seleccion = sa.id_seleccion
          AND (
               ja.id_fase > sa.Fase_Segunda_Amarilla 
               OR (ja.id_fase = sa.Fase_Segunda_Amarilla AND ja.nro_partido_fase > sa.Partido_Segunda_Amarilla)
              )
        ORDER BY ja.id_fase ASC, ja.nro_partido_fase ASC
    ) min_post
)
SELECT 
    s.nombre_seleccion                                      AS [Selección],
    sps.dorsal_sancionado                                   AS [Dorsal Jugador],
    CONCAT('Fase ', sps.Fase_Segunda_Amarilla, ' - Part. ', sps.Partido_Segunda_Amarilla) AS [Partido 2da Amarilla (Sanción)],
    CONCAT('Fase ', sps.Fase_Siguiente_Partido, ' - Part. ', sps.Nro_Siguiente_Partido)   AS [Partido Siguiente (Cumplimiento)],
    CASE 
        WHEN ja_control.dorsal_oficial IS NULL 
        THEN 'CUMPLE: FUERA DEL PLANTEL (SUSPENDIDO)'
        ELSE 'VIOLACIÓN: APARECE EN PLANILLA'
    END                                                     AS [Estado_Suspension]
FROM SiguientePartidoSeleccion sps
INNER JOIN torneo.SELECCION s 
    ON sps.id_seleccion = s.id_seleccion
-- Verifica si el jugador fue incluido en la planilla del siguiente partido
LEFT JOIN torneo.JUGADOR_ALINEACION ja_control 
    ON sps.Fase_Siguiente_Partido = ja_control.id_fase
   AND sps.Nro_Siguiente_Partido = ja_control.nro_partido_fase
   AND sps.id_seleccion = ja_control.id_seleccion
   AND sps.dorsal_sancionado = ja_control.dorsal_oficial;

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
WHERE sus.minuto_cambio <= 20

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
SELECT 
    c.id_log AS [ID Registro],
    c.fecha_hora AS [Fecha Intento],
    c.id_partido AS [Partido],
    c.id_arbitro AS [Árbitro Descartado],
    per.apellido + ', ' + per.nombre AS [Nombre Árbitro],
    pa_arb.nombre_pais AS [Nacionalidad Árbitro],
    p_loc.nombre_pais AS [País Local],
    p_vis.nombre_pais AS [País Visitante],
    c.motivo_rechazo AS [Motivo del Bloqueo]
FROM auditoria.LOG_CONFLICTO_ARBITRAL c
INNER JOIN persona.ARBITRO a ON c.id_arbitro = a.id_arbitro
INNER JOIN persona.PERSONA per ON a.id_persona = per.id_persona
INNER JOIN geografia.PAIS pa_arb ON a.id_pais = pa_arb.id_pais
INNER JOIN torneo.PARTIDO part ON c.id_partido = part.id_partido
INNER JOIN geografia.PAIS p_loc ON part.id_pais_local = p_loc.id_pais
INNER JOIN geografia.PAIS p_vis ON part.id_pais_visitante = p_vis.id_pais;