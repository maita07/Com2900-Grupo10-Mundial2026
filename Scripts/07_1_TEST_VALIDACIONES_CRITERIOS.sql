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
    COUNT(DISTINCT a.id_arbitro) AS Total_Arbitros_Registrados,
    CASE WHEN COUNT(DISTINCT a.id_arbitro) >= 15 THEN 'CUMPLE (>= 15)' ELSE 'NO CUMPLE' END AS Estado_Nomina
FROM persona.ARBITRO a;

-- 2. Verifica la cuarteta + VAR en cada partido
SELECT 
    p.id_partido,
    COUNT(da.id_arbitro) AS Total_Arbitros_Asignados,
    STRING_AGG(CONCAT(da.rol_partido, ': ', per.apellido), ' | ') AS [Cuerpo_Arbitral_Designado],
    CASE 
        WHEN COUNT(DISTINCT da.rol_partido) >= 4 THEN 'ASIGNACIÓN COMPLETA'
        ELSE 'ASIGNACIÓN INCOMPLETA'
    END AS Estado_Asignacion
FROM torneo.PARTIDO p
INNER JOIN partido.DESIGNACION_ARBITRAL da ON p.id_partido = da.id_partido
INNER JOIN persona.ARBITRO a ON da.id_arbitro = a.id_arbitro
INNER JOIN persona.PERSONA per ON a.id_persona = per.id_persona
GROUP BY p.id_partido;

--5. Historial de campañas publicitarias con anunciantes de al menos 6 países distintos
-- Conteo de anunciantes por país y verificación del mínimo de 6 países
SELECT 
    COUNT(DISTINCT pa.id_pais) AS Total_Paises_Anunciantes,
    STRING_AGG(DISTINCT pa.nombre_pais, ', ') AS Paises_Involucrados,
    CASE 
        WHEN COUNT(DISTINCT pa.id_pais) >= 6 THEN 'CUMPLE (>= 6 Países)' 
        ELSE 'NO CUMPLE' 
    END AS Estado_Validacion
FROM marketing.CAMPANIA_PUBLICITARIA cp
INNER JOIN marketing.ANUNCIANTE an ON cp.id_anunciante = an.id_anunciante
INNER JOIN geografia.PAIS pa ON an.id_pais = pa.id_pais;

-- Detalle del historial de campañas por anunciante y país:
SELECT 
    cp.id_campania,
    cp.nombre_campania,
    an.nombre_empresa AS Anunciante,
    pa.nombre_pais AS Pais_Origen,
    cp.fecha_inicio,
    cp.fecha_fin
FROM marketing.CAMPANIA_PUBLICITARIA cp
INNER JOIN marketing.ANUNCIANTE an ON cp.id_anunciante = an.id_anunciante
INNER JOIN geografia.PAIS pa ON an.id_pais = pa.id_pais
ORDER BY pa.nombre_pais, cp.fecha_inicio DESC;

--6. Casos Obligatorios: Un partido con expulsión por doble amarilla y otro con roja directa
SELECT 
    inc.id_partido,
    part.fase AS Fase,
    per.apellido + ', ' + per.nombre AS Jugador,
    pais.nombre_pais AS Seleccion,
    inc.minuto AS Minuto_Expulsion,
    inc.tipo_tarjeta AS Tipo_Sancion, -- 'DOBLE_AMARILLA' o 'ROJA_DIRECTA'
    inc.observacion AS Detalle
FROM partido.INCIDENCIA_DISCIPLINARIA inc
INNER JOIN torneo.PARTIDO part ON inc.id_partido = part.id_partido
INNER JOIN plantel.JUGADOR j ON inc.id_jugador = j.id_jugador
INNER JOIN persona.PERSONA per ON j.id_persona = per.id_persona
INNER JOIN geografia.PAIS pais ON j.id_pais = pais.id_pais
WHERE inc.tipo_tarjeta IN ('DOBLE_AMARILLA', 'ROJA_DIRECTA')
ORDER BY inc.tipo_tarjeta, inc.id_partido;

--7. Casos Obligatorios: Jugador suspendido por acumulación de amarillas que queda afuera del siguiente partido
SELECT 
    per.apellido + ', ' + per.nombre AS [Jugador Suspendido],
    p.nombre_pais AS [Selección],
    s.partido_origen AS [ID Partido Suspensión],
    s.partido_inhabilitado AS [ID Partido Siguiente (Inhabilitado)],
    s.motivo_sancion AS [Motivo (Acumulación)],
    CASE 
        WHEN NOT EXISTS (
            SELECT 1 
            FROM partido.ALINEACION al 
            WHERE al.id_partido = s.partido_inhabilitado 
              AND al.id_jugador = s.id_jugador 
              AND al.es_titular = 1
        ) THEN 'CORRECTO: Quedó fuera de la formación titular'
        ELSE 'ERROR: Aparece como titular estando suspendido'
    END AS [Control_Reglamentario]
FROM disciplina.SUSPENSION s
INNER JOIN plantel.JUGADOR j ON s.id_jugador = j.id_jugador
INNER JOIN persona.PERSONA per ON j.id_persona = per.id_persona
INNER JOIN geografia.PAIS p ON j.id_pais = p.id_pais
WHERE s.motivo_sancion LIKE '%AMARILLAS%';

--8. Casos Obligatorios: Cambio realizado por lesión dentro de los primeros 20 minutos
SELECT 
    c.id_partido,
    c.minuto AS [Minuto Cambio],
    p_sale.apellido + ' ' + p_sale.nombre AS [Sale Lesionado],
    p_entra.apellido + ' ' + p_entra.nombre AS [Entra al Campo],
    c.motivo_cambio AS [Motivo Informado],
    CASE 
        WHEN c.minuto <= 20 AND c.motivo_cambio LIKE '%Lesi%' 
        THEN 'CUMPLE CASO: Lesión prematura (<= 20 min)'
        ELSE 'Otro Cambio'
    END AS [Estado]
FROM partido.CAMBIO c
INNER JOIN plantel.JUGADOR j_sale ON c.id_jugador_sale = j_sale.id_jugador
INNER JOIN persona.PERSONA p_sale ON j_sale.id_persona = p_sale.id_persona
INNER JOIN plantel.JUGADOR j_entra ON c.id_jugador_entra = j_entra.id_jugador
INNER JOIN persona.PERSONA p_entra ON j_entra.id_persona = p_entra.id_persona
WHERE c.minuto <= 20 AND c.motivo_cambio LIKE '%Lesi%';

--9. Casos Obligatorios: Partido en Prime Time con más de 4 mercados y priorización de 4
SELECT 
    pt.id_partido,
    part.fecha_hora_partido AS [Horario Kickoff],
    pt.mercados_candidatos_total AS [Total Mercados en Prime Time],
    pt.mercados_seleccionados AS [Top 4 Mercados Asignados],
    pt.criterio_priorizacion AS [Criterio de Selección Aplicado],
    CASE 
        WHEN pt.mercados_candidatos_total > 4 AND LEN(pt.mercados_seleccionados) > 0 
        THEN 'CUMPLE: Se priorizaron 4 mercados comerciales'
        ELSE 'Revisar cálculo'
    END AS [Estado_Validacion]
FROM transmision.PRIME_TIME_LOG pt
INNER JOIN torneo.PARTIDO part ON pt.id_partido = part.id_partido;

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