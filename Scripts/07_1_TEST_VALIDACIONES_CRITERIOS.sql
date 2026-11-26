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

SELECT 
    COUNT(DISTINCT s.id_sede) AS Total_Sedes,
    COUNT(DISTINCT s.huso_horario) AS Total_Husos_Distintos,
    STRING_AGG(DISTINCT s.huso_horario, ', ') AS Husos_Horarios_Detectados,
    CASE 
        WHEN COUNT(DISTINCT s.id_sede) >= 8 AND COUNT(DISTINCT s.huso_horario) >= 3 
        THEN 'CUMPLE CON LA REGLA' 
        ELSE 'NO CUMPLE' 
    END AS Estado_Validacion
FROM torneo.SEDE s;

-- Detalle individual de las sedes con sus husos horarios:
SELECT 
    s.id_sede,
    s.nombre_estadio,
    s.ciudad,
    p.nombre_pais,
    s.huso_horario
FROM torneo.SEDE s
INNER JOIN geografia.PAIS p ON s.id_pais = p.id_pais
ORDER BY s.huso_horario, s.ciudad;

--2. Al menos 16 selecciones participantes, cada una con al menos 23 convocados
-- Muestra la lista de selecciones con su conteo de convocados y si cumplen el mínimo de 23
SELECT 
    p.id_pais,
    p.nombre_pais AS Seleccion,
    COUNT(j.id_jugador) AS Cantidad_Convocados,
    CASE 
        WHEN COUNT(j.id_jugador) >= 23 THEN 'CUMPLE (>= 23)' 
        ELSE 'INCOMPLETO (< 23)' 
    END AS Estado_Convocatoria
FROM geografia.PAIS p
INNER JOIN plantel.CONVOCATORIA c ON p.id_pais = c.id_pais
INNER JOIN plantel.JUGADOR j ON c.id_convocatoria = j.id_convocatoria
GROUP BY p.id_pais, p.nombre_pais
HAVING COUNT(j.id_jugador) >= 23
ORDER BY Cantidad_Convocados DESC;

-- Validación global: Al menos 16 selecciones con >= 23 convocados
SELECT 
    COUNT(*) AS Total_Selecciones_Con_Mas_De_23,
    CASE WHEN COUNT(*) >= 16 THEN 'CUMPLE CON LA REGLA (>= 16)' ELSE 'NO CUMPLE' END AS Estado_Global
FROM (
    SELECT p.id_pais
    FROM geografia.PAIS p
    INNER JOIN plantel.CONVOCATORIA c ON p.id_pais = c.id_pais
    INNER JOIN plantel.JUGADOR j ON c.id_convocatoria = j.id_convocatoria
    GROUP BY p.id_pais
    HAVING COUNT(j.id_jugador) >= 23
) AS Sub;

--3. Al menos 24 partidos (grupos y eliminación directa) con titulares y suplentes
-- Detalla partidos, fase, y cuenta de titulares (11) y suplentes por equipo
SELECT 
    part.id_partido,
    part.fase AS [Fase], -- 'Grupos', 'Octavos', etc.
    p_local.nombre_pais AS [Local],
    p_visit.nombre_pais AS [Visitante],
    SUM(CASE WHEN a.es_titular = 1 THEN 1 ELSE 0 END) AS [Total_Titulares],
    SUM(CASE WHEN a.es_titular = 0 THEN 1 ELSE 0 END) AS [Total_Suplentes],
    CASE 
        WHEN SUM(CASE WHEN a.es_titular = 1 THEN 1 ELSE 0 END) = 22 -- 11 por cada equipo
             AND SUM(CASE WHEN a.es_titular = 0 THEN 1 ELSE 0 END) >= 14 
        THEN 'ALINEACIÓN COMPLETA' 
        ELSE 'INCOMPLETO' 
    END AS [Estado_Alineacion]
FROM torneo.PARTIDO part
INNER JOIN geografia.PAIS p_local ON part.id_pais_local = p_local.id_pais
INNER JOIN geografia.PAIS p_visit ON part.id_pais_visitante = p_visit.id_pais
INNER JOIN partido.ALINEACION a ON part.id_partido = a.id_partido
GROUP BY part.id_partido, part.fase, p_local.nombre_pais, p_visit.nombre_pais
ORDER BY part.id_partido;

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