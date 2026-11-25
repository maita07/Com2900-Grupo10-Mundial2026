/*
================================================================================
UNLaM - Universidad Nacional de La Matanza
Departamento de Ingeniería e Investigaciones Tecnológicas
Materia: Base de Datos Aplicada (Comisión 5600)
Entrega 6 - Script 04_12: Creacion de los datos de EXHIBICION_PUBLICITARIA 
2026 - 2C
Grupo 10

Integrantes:
- Monasterio Erik: MonasteryEr
- Arena Ariel Ignacio: arielarena
- Castillo Gabriela Florencia: ItsFlorencia
- Maita Pitado Jose Gregorio: maita07

Archivo: 04_12_CREATE_DATOS_EXHIBICION_PUBLICITARIA.sql
Descripcion:
    Se realiza el sp para la creacion de los datos de EXHIBICION_PUBLICITARIA,
    la cual determinara las campañas publicitarias de cada partido segun el siguiente orden:
        1_El mercado destino sea jugador del partido
        2_El mercado destino con mas PBI por capita
        3_El mercado en el que sea Prime_Time

    Ademas se realiza la creacion de la funcion obtenerDesplazamientoUTC,
    la cual recibe por parametro el id del pais y devuelve el desplazamiento del horario UTC
    o 0 por defecto

================================================================================
*/

USE DB_Mundial2026_Grupo10
GO

CREATE OR ALTER FUNCTION geografia.fn_ObtenerDesplazamientoUTC (
    @id_pais CHAR(3)
)
RETURNS DECIMAL(4,1)
AS
BEGIN
    DECLARE @desplazamiento DECIMAL(4,1);

    SET @desplazamiento = CASE UPPER(LTRIM(RTRIM(@id_pais)))
        WHEN 'ALG' THEN 1 WHEN 'ARG' THEN -3 WHEN 'AUS' THEN 10
        WHEN 'AUT' THEN 1 WHEN 'BEL' THEN 1 WHEN 'BIH' THEN 1
        WHEN 'BRA' THEN -3 WHEN 'CAN' THEN -5 WHEN 'CIV' THEN 0
        WHEN 'COD' THEN 1 WHEN 'COL' THEN -5 WHEN 'CPV' THEN -1
        WHEN 'CRO' THEN 1 WHEN 'CUW' THEN -4 WHEN 'CZE' THEN 1
        WHEN 'ECU' THEN -5 WHEN 'EGY' THEN 2 WHEN 'ENG' THEN 0
        WHEN 'ESP' THEN 1 WHEN 'FRA' THEN 1 WHEN 'GER' THEN 1
        WHEN 'GHA' THEN 0 WHEN 'HAI' THEN -5 WHEN 'IRN' THEN 3.5
        WHEN 'IRQ' THEN 3 WHEN 'JOR' THEN 3 WHEN 'JPN' THEN 9
        WHEN 'KOR' THEN 9 WHEN 'KSA' THEN 3 WHEN 'MAR' THEN 1
        WHEN 'MEX' THEN -6 WHEN 'NED' THEN 1 WHEN 'NOR' THEN 1
        WHEN 'NZL' THEN 12 WHEN 'PAN' THEN -5 WHEN 'PAR' THEN -3
        WHEN 'POR' THEN 0 WHEN 'QAT' THEN 3 WHEN 'RSA' THEN 2
        WHEN 'SCO' THEN 0 WHEN 'SEN' THEN 0 WHEN 'SUI' THEN 1
        WHEN 'SWE' THEN 1 WHEN 'TUN' THEN 1 WHEN 'TUR' THEN 3
        WHEN 'URU' THEN -3 WHEN 'USA' THEN -5 WHEN 'UZB' THEN 5
        ELSE 0
    END;

    RETURN @desplazamiento;
END;
GO

CREATE OR ALTER PROCEDURE comercial.sp_CREAR_DATOS_EXHIBICION_PUBLICITARIA AS
BEGIN
SET NOCOUNT ON;

    DECLARE @Proceso VARCHAR(100) = 'comercial.sp_CREACION_DATOS_EXHIBICION_PUBLICITARIA'; 
    DECLARE @Fila INT, @Total INT, @Accion CHAR(1),@Registro INT, @Altas INT, @Mod INT, @Err INT

    DECLARE @FilaInt INT, @Costo DECIMAL(18,2),@Ini INT, @Fin INT, @Cap INT, @Tarifa INT,
    @FactorLetrero DECIMAL (3,2),@Msg VARCHAR(200)

    DECLARE @id_fase INT,@nro_partido_fase INT,@id_anunciante INT,
            @id_campania INT,@id_pieza INT, @letrero_posicion INT;

    CREATE TABLE #mejoresCuatro(
        id_fase INT,
        nro_partido_fase INT,
        letrero_pos INT, 
        id_pieza INT,
        id_campania INT,
        id_anunciante INT,
        equipo_juega INT,
        PBI DECIMAL(18,2),
        prime_time BIT
    );

    WITH paises_partido AS(
        SELECT 
            part.id_fase, part.nro_partido_fase,
            sl.id_pais AS id_pais_local,
            sv.id_pais AS id_pais_visitante,
            part.fecha_hora_utc
        FROM torneo.PARTIDO part
        INNER JOIN torneo.SELECCION sl 
            ON part.id_seleccion_local = sl.id_seleccion
        INNER JOIN torneo.SELECCION sv 
            ON part.id_seleccion_visitante = sv.id_seleccion
    )
    SELECT ROW_NUMBER() OVER (ORDER BY id_fase, nro_partido_fase) AS nro_fila,
    id_fase,nro_partido_fase,id_pais_local, id_pais_visitante, fecha_hora_utc
    INTO #datosPartido
    FROM paises_partido

    SELECT @Fila = 1, @Registro= 1, @Total = COUNT(*), @Altas = 0, @Mod = 0, @Err = 0 FROM #datosPartido
    WHILE @Fila <= @Total

    BEGIN

        TRUNCATE TABLE #mejoresCuatro;
        
        WITH pieza_candidata AS(
            SELECT par.id_fase, par.nro_partido_fase, pp.id_pieza, camp.id_campania, camp.id_anunciante,
            p.pbi_per_capita_actual AS PBI,
            CASE WHEN mer.id_pais IN (par.id_pais_local, par.id_pais_visitante)
                THEN 1 ELSE 0 END AS equipo_juega,
            CASE WHEN CAST(DATEADD(MINUTE, geografia.fn_ObtenerDesplazamientoUTC(p.id_pais)*60, par.fecha_hora_utc) AS TIME) >= '19:00'
                AND CAST(DATEADD(MINUTE, geografia.fn_ObtenerDesplazamientoUTC(p.id_pais)*60, par.fecha_hora_utc) AS TIME) <= '23:00'
                THEN 1 ELSE 0 END AS prime_time
            FROM #datosPartido par
            JOIN comercial.CAMPANIA_PUBLICITARIA camp
                ON CAST(par.fecha_hora_utc AS DATE) BETWEEN camp.fecha_inicio AND camp.fecha_fin
            JOIN comercial.PIEZA_PUBLICITARIA pp ON pp.id_campania = camp.id_campania
            JOIN comercial.PIEZA_MERCADO mer ON mer.id_pieza = pp.id_pieza
            JOIN geografia.PAIS p ON p.id_pais = mer.id_pais

            WHERE par.nro_fila = @Fila
        ), 
        mejor_mercado AS(
            SELECT *, ROW_NUMBER() OVER (
                PARTITION BY id_pieza
                ORDER BY equipo_juega DESC, PBI desc,prime_time DESC) AS nro_pieza
            FROM pieza_candidata
        ),
        ranking AS (
            SELECT *, ROW_NUMBER() OVER (
                ORDER BY equipo_juega DESC,PBI DESC, prime_time DESC, id_pieza
            )AS puesto
            FROM mejor_mercado
        )
        INSERT INTO #mejoresCuatro(id_fase,nro_partido_fase,letrero_pos,id_pieza,id_campania,id_anunciante,equipo_juega,PBI, prime_time)
        SELECT id_fase,nro_partido_fase,puesto AS letrero_pos, id_pieza, id_campania,id_anunciante,
        equipo_juega,PBI, prime_time
        FROM ranking
        WHERE puesto <=4
        ORDER BY puesto;
        
        SET @FilaInt = 1;
        SET @Ini = 0; 
        SET @Fin = 0;
        WHILE @FilaInt <= 4
        BEGIN

            SELECT @letrero_posicion = letrero_pos, @id_anunciante = id_anunciante, @id_fase = id_fase,
            @nro_partido_fase = nro_partido_fase, @id_campania = id_campania, @id_pieza = id_pieza
            FROM #mejoresCuatro WHERE letrero_pos = @FilaInt

            BEGIN TRY
                SET @Accion = CASE WHEN EXISTS (SELECT 1 FROM comercial.EXHIBICION_PUBLICITARIA
                                            WHERE id_exhibicion = @Registro)
                               THEN 'M' ELSE 'A' END;
                

                SET @Ini = @Fin
                SET @Fin += 22.5

                SELECT @Cap = s.capacidad
                FROM torneo.SEDE s
                JOIN torneo.PARTIDO par
                    ON s.id_sede = par.id_sede


                IF @Cap IS NULL
                    THROW 50001, 'No se encontró el partido o la capacidad de su sede.', 1;

                SET @Tarifa = CASE @id_fase
                                    WHEN 1 THEN 8000  WHEN 2 THEN 12000 WHEN 3 THEN 18000
                                    WHEN 4 THEN 28000 WHEN 5 THEN 45000 WHEN 6 THEN 30000
                                    WHEN 7 THEN 90000 END;

                SET @FactorLetrero = CASE @letrero_posicion
                                        WHEN 1 THEN 1.25 WHEN 2 THEN 1.10
                                        WHEN 3 THEN 1.00 WHEN 4 THEN 0.90 END;

                IF @Tarifa IS NULL 
                BEGIN
                    SET @Msg = CONCAT('Fase fuera de rango: ', ISNULL(CAST(@id_fase AS VARCHAR(10)), 'ES NULL'));
                    THROW 50002, @Msg, 1;
                END;
                IF @FactorLetrero IS NULL
                BEGIN
                    SET @Msg  = CONCAT('Letrero fuera de rango: ', ISNULL(CAST(@letrero_posicion AS VARCHAR(10)), 'ES NULL'));
                    THROW 50002, @Msg, 1;
                END;

                SET @Costo = ROUND(@Tarifa * (@Fin - @Ini) * (@Cap / 60000.0) * @FactorLetrero, 2);


                EXEC comercial.sp_EXHIBICION_PUBLICITARIA_ABM
                    @Accion = @Accion,
                    @id_exhibicion = @Registro,
                    @id_fase = @id_fase,
                    @nro_partido_fase = @nro_partido_fase,
                    @id_anunciante = @id_anunciante,
                    @id_campania = @id_campania,
                    @id_pieza = @id_pieza,
                    @letrero_posicion = @letrero_posicion,
                    @minuto_inicio = @Ini,
                    @minuto_fin = @Fin,
                    @costo_calculado_usd = @Costo

                    IF @Accion = 'A' SET @Altas += 1; ELSE SET @Mod += 1;
            END TRY
            BEGIN CATCH
                SET @Err += 1;
                INSERT INTO auditoria.LOG_IMPORTACION (proceso_origen, nro_fila, clave_registro, mensaje_error, linea_error)
                VALUES (@Proceso, @Fila, CONCAT('ID Exhibicion ', @Registro, ' - ID Fase partido ', @id_fase,' - Nro Partido ', @nro_partido_fase, ' -Posicion de Letrero ', @letrero_posicion), ERROR_MESSAGE(), ERROR_LINE());
            END CATCH
                SET @FilaInt +=1;
                SET @Registro +=1;

         END

        SET @Fila += 1;
    END;

    PRINT CONCAT('--> Exhibiciones publicitarias: ', @Total, ' | Altas: ', @Altas, ' | Mod: ', @Mod, ' | Error: ', @Err);

END