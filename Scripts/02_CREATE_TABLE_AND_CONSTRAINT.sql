/*
---------------------------------------------------------
UNLaM - Universidad Nacional de La Matanza
Departamento de Ingeniería e Investigaciones Tecnológicas
Materia: Base de Datos Aplicada (Comisión 5600)
Entrega 5 - Base de Datos T-SQL
2026 - 2C
Grupo 10

Integrantes:
-Monasterio Erik: MonasteryEr
-Arena Ariel Ignacio: arielarena
-Castillo Gabriela Florencia: ItsFlorencia
-Maita Pitado Jose Gregorio: maita07

Descripcion: Creación de las tablas del Modelo Relacional 
             con todas sus Claves Primarias (PK), Claves Foráneas (FK) 
             y Restricciones de Dominio (CHECK / DEFAULT / UNIQUE).
---------------------------------------------------------
*/

USE DB_Mundial2026_Grupo10;
GO

-- 1. Creacion de las tablas 


--Tablas de esquema geografia_economia

--PAIS
CREATE TABLE geografia.PAIS (
    id_pais CHAR(3) NOT NULL,
    nombre_pais VARCHAR(50) NOT NULL,
    moneda_pais VARCHAR(30) NOT NULL,
    pbi_per_capita_actual DECIMAL (18,2) NOT NULL,
    CONSTRAINT PK_PAIS PRIMARY KEY (id_pais),
    CONSTRAINT CHK_PAIS_PBI CHECK (pbi_per_capita_actual >= 0)
);

--INDICADOR ECONOMICO

CREATE TABLE geografia.INDICADOR_ECONOMICO_PAIS (
    id_pais CHAR(3) NOT NULL,
    periodo_anio INT NOT NULL,
    pbi_per_capita_usd DECIMAL(18,2) NOT NULL,
    poblacion_total BIGINT NOT NULL,
    indice_inflacion DECIMAL(5,2) NOT NULL,
    CONSTRAINT PK_INDICADOR_ECONOMICO_PAIS PRIMARY KEY (id_pais, periodo_anio),
    CONSTRAINT FK_INDICADOR_PAIS FOREIGN KEY (id_pais) REFERENCES geografia.PAIS (id_pais),
    CONSTRAINT CHK_INDICADOR_PBI CHECK (pbi_per_capita_usd >= 0),
    CONSTRAINT CHK_INDICADOR_POBLACION CHECK (poblacion_total >= 0)
);

-- HISTORIAL DE TIPO DE CAMBIO
CREATE TABLE geografia.HISTORIAL_TIPO_CAMBIO (
    id_pais CHAR(3) NOT NULL,
    fecha_cotizacion DATE NOT NULL,
    valor_cotizacion DECIMAL(12,4) NOT NULL,
    codigo_moneda VARCHAR(5) NOT NULL,
    CONSTRAINT PK_HISTORIAL_TIPO_CAMBIO PRIMARY KEY (id_pais, fecha_cotizacion),
    CONSTRAINT FK_HISTORIAL_PAIS FOREIGN KEY (id_pais) REFERENCES geografia.PAIS (id_pais),
    CONSTRAINT CHK_TIPO_CAMBIO_VALOR CHECK (valor_cotizacion > 0)
);

-- CONFEDERACION
CREATE TABLE geografia.CONFEDERACION (
    id_confederacion INT NOT NULL,
    nombre_confederacion VARCHAR(50) NOT NULL,
    sigla VARCHAR(10) NOT NULL,
    CONSTRAINT PK_CONFEDERACION PRIMARY KEY (id_confederacion),
    CONSTRAINT UQ_CONFEDERACION_SIGLA UNIQUE (sigla)
);
GO


PRINT 'TABLAS DE ESQUEMA geografia CREADAS EXITOSAMENTE'


--Tablas de esquema de Torneo y personas

-- SELECCION
CREATE TABLE torneo.SELECCION (
    id_seleccion INT NOT NULL,
    id_pais CHAR(3) NOT NULL,
    id_confederacion INT NOT NULL,
    nombre_seleccion VARCHAR(50) NOT NULL,
    grupo_asignado CHAR(1) NOT NULL,
    CONSTRAINT PK_SELECCION PRIMARY KEY (id_seleccion),
    CONSTRAINT FK_SELECCION_PAIS FOREIGN KEY (id_pais) REFERENCES geografia.PAIS (id_pais),
    CONSTRAINT FK_SELECCION_CONFEDERACION FOREIGN KEY (id_confederacion) REFERENCES geografia.CONFEDERACION (id_confederacion),
    CONSTRAINT CHK_SELECCION_GRUPO CHECK (grupo_asignado BETWEEN 'A' AND 'L')
);

-- PERSONA (Superclase)
CREATE TABLE persona.PERSONA (
    nro_doc VARCHAR(20) NOT NULL,
    tipo_doc VARCHAR(10) NOT NULL,
    id_nacionalidad_pais CHAR(3) NOT NULL,
    nombre VARCHAR(50) NOT NULL,
    apellido VARCHAR(50) NOT NULL,
    fecha_nacimiento DATE NOT NULL,
    tipo_persona VARCHAR(20) NOT NULL,
    CONSTRAINT PK_PERSONA PRIMARY KEY (nro_doc, tipo_doc),
    CONSTRAINT FK_PERSONA_PAIS FOREIGN KEY (id_nacionalidad_pais) REFERENCES geografia.PAIS (id_pais),
    CONSTRAINT CHK_PERSONA_TIPO CHECK (tipo_persona IN ('JUGADOR', 'CUERPO_TECNICO', 'ARBITRO'))
);

-- JUGADOR (Subclase)
CREATE TABLE persona.JUGADOR (
    nro_doc VARCHAR(20) NOT NULL,
    tipo_doc VARCHAR(10) NOT NULL,
    posicion_habitual VARCHAR(30) NOT NULL,
    club_origen VARCHAR(50) NOT NULL,
    peso_kg DECIMAL(5,2) NOT NULL,
    altura_cm DECIMAL(5,2) NOT NULL,
    es_convocado BIT CONSTRAINT DF_JUGADOR_CONVOCADO DEFAULT 0 NOT NULL,
    CONSTRAINT PK_JUGADOR PRIMARY KEY (nro_doc, tipo_doc),
    CONSTRAINT FK_JUGADOR_PERSONA FOREIGN KEY (nro_doc, tipo_doc) REFERENCES persona.PERSONA (nro_doc, tipo_doc),
    CONSTRAINT CHK_JUGADOR_PESO CHECK (peso_kg > 0),
    CONSTRAINT CHK_JUGADOR_ALTURA CHECK (altura_cm > 0)
);

-- CUERPO_TECNICO (Subclase)
CREATE TABLE persona.CUERPO_TECNICO (
    nro_doc VARCHAR(20) NOT NULL,
    tipo_doc VARCHAR(10) NOT NULL,
    id_seleccion INT NOT NULL,
    cargo_tecnico VARCHAR(40) NOT NULL,
    CONSTRAINT PK_CUERPO_TECNICO PRIMARY KEY (nro_doc, tipo_doc),
    CONSTRAINT FK_CUERPO_TECNICO_PERSONA FOREIGN KEY (nro_doc, tipo_doc) REFERENCES persona.PERSONA (nro_doc, tipo_doc),
    CONSTRAINT FK_CUERPO_TECNICO_SELECCION FOREIGN KEY (id_seleccion) REFERENCES torneo.SELECCION (id_seleccion)
);

-- ROL_ARBITRAL
CREATE TABLE torneo.ROL_ARBITRAL (
    id_rol INT NOT NULL,
    rol_descripcion VARCHAR(40) NOT NULL,
    CONSTRAINT PK_ROL_ARBITRAL PRIMARY KEY (id_rol)
);

-- ARBITRO
CREATE TABLE persona.ARBITRO (
    nro_doc VARCHAR(20) NOT NULL,
    tipo_doc VARCHAR(10) NOT NULL,
    id_rol INT NOT NULL,
    categoria_fifa VARCHAR(50) NOT NULL,
    anios_experiencia INT NOT NULL,
    CONSTRAINT PK_ARBITRO PRIMARY KEY (nro_doc, tipo_doc),
    CONSTRAINT FK_ARBITRO_PERSONA FOREIGN KEY (nro_doc, tipo_doc) REFERENCES persona.PERSONA (nro_doc, tipo_doc),
    CONSTRAINT FK_ARBITRO_ROL FOREIGN KEY (id_rol) REFERENCES torneo.ROL_ARBITRAL (id_rol),
    CONSTRAINT CHK_ARBITRO_EXP CHECK (anios_experiencia >= 0)
);

-- CONVOCATORIA
CREATE TABLE torneo.CONVOCATORIA (
    id_seleccion INT NOT NULL,
    dorsal_oficial INT NOT NULL,
    nro_doc VARCHAR(20) NOT NULL,
    tipo_doc VARCHAR(10) NOT NULL,
    estado_convocatoria VARCHAR(20) CONSTRAINT DF_CONVOCATORIA_ESTADO DEFAULT 'ACTIVO' NOT NULL,
    CONSTRAINT PK_CONVOCATORIA PRIMARY KEY (id_seleccion, dorsal_oficial),
    CONSTRAINT FK_CONVOCATORIA_SELECCION FOREIGN KEY (id_seleccion) REFERENCES torneo.SELECCION (id_seleccion),
    CONSTRAINT FK_CONVOCATORIA_JUGADOR FOREIGN KEY (nro_doc, tipo_doc) REFERENCES persona.JUGADOR (nro_doc, tipo_doc),
    CONSTRAINT CHK_CONVOCATORIA_DORSAL CHECK (dorsal_oficial BETWEEN 1 AND 99)
);

-- INCIDENCIA_CONVOCATORIA
CREATE TABLE torneo.INCIDENCIA_CONVOCATORIA (
    id_seleccion INT NOT NULL,
    dorsal_oficial INT NOT NULL,
    fecha_incidencia DATE NOT NULL,
    motivo_baja_lesion VARCHAR(100) NOT NULL,
    es_baja_definitiva BIT CONSTRAINT DF_INCIDENCIA_BAJA DEFAULT 1 NOT NULL,
    CONSTRAINT PK_INCIDENCIA_CONVOCATORIA PRIMARY KEY (id_seleccion, dorsal_oficial, fecha_incidencia),
    CONSTRAINT FK_INCIDENCIA_CONVOCATORIA FOREIGN KEY (id_seleccion, dorsal_oficial) REFERENCES torneo.CONVOCATORIA (id_seleccion, dorsal_oficial)
);
GO

PRINT 'TABLAS DE ESQUEMA de personal del torneo y personas CREADAS EXITOSAMENTE'

-- Tablas de esquema TORNEO-Equipos

-- SEDE
CREATE TABLE torneo.SEDE (
    id_sede INT NOT NULL,
    id_pais CHAR(3) NOT NULL,
    nombre_estadio VARCHAR(50) NOT NULL,
    ciudad VARCHAR(50) NOT NULL,
    capacidad INT NOT NULL,
    huso_horario_utc VARCHAR(10) NOT NULL,
    CONSTRAINT PK_SEDE PRIMARY KEY (id_sede),
    CONSTRAINT FK_SEDE_PAIS FOREIGN KEY (id_pais) REFERENCES geografia.PAIS (id_pais),
    CONSTRAINT CHK_SEDE_CAPACIDAD CHECK (capacidad > 0)
);

-- FASE_TORNEO
CREATE TABLE torneo.FASE_TORNEO (
    id_fase INT NOT NULL,
    nombre_fase VARCHAR(40) NOT NULL,
    orden_secuencia INT NOT NULL,
    CONSTRAINT PK_FASE_TORNEO PRIMARY KEY (id_fase),
    CONSTRAINT CHK_FASE_ORDEN CHECK (orden_secuencia > 0)
);

-- PARTIDO
CREATE TABLE torneo.PARTIDO (
    id_fase INT NOT NULL,
    nro_partido_fase INT NOT NULL,
    id_sede INT NOT NULL,
    id_seleccion_local INT NOT NULL,
    id_seleccion_visitante INT NOT NULL,
    fecha_hora_utc DATETIME2 NOT NULL,
    fecha_hora_local DATETIME2 NOT NULL,
    asistencia_oficial INT CONSTRAINT DF_PARTIDO_ASISTENCIA DEFAULT 0 NOT NULL,
    goles_local INT CONSTRAINT DF_PARTIDO_GOLES_LOC DEFAULT 0 NOT NULL,
    goles_visitante INT CONSTRAINT DF_PARTIDO_GOLES_VIS DEFAULT 0 NOT NULL,
    CONSTRAINT PK_PARTIDO PRIMARY KEY (id_fase, nro_partido_fase),
    CONSTRAINT FK_PARTIDO_FASE FOREIGN KEY (id_fase) REFERENCES torneo.FASE_TORNEO (id_fase),
    CONSTRAINT FK_PARTIDO_SEDE FOREIGN KEY (id_sede) REFERENCES torneo.SEDE (id_sede),
    CONSTRAINT FK_PARTIDO_LOCAL FOREIGN KEY (id_seleccion_local) REFERENCES torneo.SELECCION (id_seleccion),
    CONSTRAINT FK_PARTIDO_VISITANTE FOREIGN KEY (id_seleccion_visitante) REFERENCES torneo.SELECCION (id_seleccion),
    CONSTRAINT CHK_PARTIDO_DISTINTAS_SELECCIONES CHECK (id_seleccion_local <> id_seleccion_visitante),
    CONSTRAINT CHK_PARTIDO_GOLES_LOC CHECK (goles_local >= 0),
    CONSTRAINT CHK_PARTIDO_GOLES_VIS CHECK (goles_visitante >= 0)
);

-- DESIGNACION_ARBITRAL
CREATE TABLE torneo.DESIGNACION_ARBITRAL (
    id_fase INT NOT NULL,
    nro_partido_fase INT NOT NULL,
    nro_doc VARCHAR(20) NOT NULL,
    tipo_doc VARCHAR(10) NOT NULL,
    id_rol INT NOT NULL,
    CONSTRAINT PK_DESIGNACION_ARBITRAL PRIMARY KEY (id_fase, nro_partido_fase, nro_doc, tipo_doc),
    CONSTRAINT FK_DESIGNACION_PARTIDO FOREIGN KEY (id_fase, nro_partido_fase) REFERENCES torneo.PARTIDO (id_fase, nro_partido_fase),
    CONSTRAINT FK_DESIGNACION_ARBITRO FOREIGN KEY (nro_doc, tipo_doc) REFERENCES persona.ARBITRO (nro_doc, tipo_doc),
    CONSTRAINT FK_DESIGNACION_ROL FOREIGN KEY (id_rol) REFERENCES torneo.ROL_ARBITRAL (id_rol)
);
GO

PRINT 'TABLAS DE ESQUEMA equipos del torneo CREADAS EXITOSAMENTE'

-- Tablas de esquema torneo-Partido

-- ALINEACION_PARTIDO
CREATE TABLE torneo.ALINEACION_PARTIDO (
    id_fase INT NOT NULL,
    nro_partido_fase INT NOT NULL,
    id_seleccion INT NOT NULL,
    esquema_tactico VARCHAR(10) NOT NULL,
    CONSTRAINT PK_ALINEACION_PARTIDO PRIMARY KEY (id_fase, nro_partido_fase, id_seleccion),
    CONSTRAINT FK_ALINEACION_PARTIDO FOREIGN KEY (id_fase, nro_partido_fase) REFERENCES torneo.PARTIDO (id_fase, nro_partido_fase),
    CONSTRAINT FK_ALINEACION_SELECCION FOREIGN KEY (id_seleccion) REFERENCES torneo.SELECCION (id_seleccion)
);

-- JUGADOR_ALINEACION
CREATE TABLE torneo.JUGADOR_ALINEACION (
    id_fase INT NOT NULL,
    nro_partido_fase INT NOT NULL,
    id_seleccion INT NOT NULL,
    dorsal_oficial INT NOT NULL,
    es_titular BIT NOT NULL,
    posicion_campo VARCHAR(30) NOT NULL,
    minuto_ingreso INT CONSTRAINT DF_JUG_ALIN_INGRESO DEFAULT 0 NOT NULL,
    minuto_ingreso_extra INT NULL,
    minuto_salida INT NULL,
    minuto_salida_extra INT NULL,
    CONSTRAINT PK_JUGADOR_ALINEACION PRIMARY KEY (id_fase, nro_partido_fase, id_seleccion, dorsal_oficial),
    CONSTRAINT FK_JUG_ALIN_ALINEACION FOREIGN KEY (id_fase, nro_partido_fase, id_seleccion) REFERENCES torneo.ALINEACION_PARTIDO (id_fase, nro_partido_fase, id_seleccion),
    CONSTRAINT FK_JUG_ALIN_CONVOCATORIA FOREIGN KEY (id_seleccion, dorsal_oficial) REFERENCES torneo.CONVOCATORIA (id_seleccion, dorsal_oficial),
    CONSTRAINT CHK_JUG_ALIN_MINUTOS CHECK (minuto_ingreso >= 0 AND (minuto_salida IS NULL OR minuto_salida >= minuto_ingreso))
);

-- SUSTITUCION
CREATE TABLE torneo.SUSTITUCION (
    id_fase INT NOT NULL,
    nro_partido_fase INT NOT NULL,
    id_secuencia INT NOT NULL,
    id_seleccion INT NOT NULL,
    dorsal_sale INT NOT NULL,
    dorsal_entra INT NOT NULL,
    minuto_cambio INT NOT NULL,
    minuto_cambio_extra INT NULL,
    ventana_numero INT NOT NULL,
    CONSTRAINT PK_SUSTITUCION PRIMARY KEY (id_fase, nro_partido_fase, id_secuencia),
    CONSTRAINT FK_SUSTITUCION_PARTIDO FOREIGN KEY (id_fase, nro_partido_fase) REFERENCES torneo.PARTIDO (id_fase, nro_partido_fase),
    CONSTRAINT FK_SUSTITUCION_SELECCION FOREIGN KEY (id_seleccion) REFERENCES torneo.SELECCION (id_seleccion),
    CONSTRAINT CHK_SUSTITUCION_MINUTO CHECK (minuto_cambio BETWEEN 1 AND 120),
    CONSTRAINT CHK_SUSTITUCION_MINUTO_EXTRA CHECK (minuto_cambio_extra > 0),
    CONSTRAINT CHK_SUSTITUCION_VENTANA CHECK (ventana_numero BETWEEN 1 AND 4)
);

-- GOL
CREATE TABLE torneo.GOL (
    id_fase INT NOT NULL,
    nro_partido_fase INT NOT NULL,
    id_gol INT NOT NULL,
    minuto_gol INT NOT NULL,
    minuto_gol_extra INT NULL,
    tipo_gol VARCHAR(20) NOT NULL,
    id_seleccion INT NOT NULL,
    dorsal_autor INT NOT NULL,
    dorsal_asistente INT NULL,
    CONSTRAINT PK_GOL PRIMARY KEY (id_fase, nro_partido_fase, id_gol),
    CONSTRAINT FK_GOL_PARTIDO FOREIGN KEY (id_fase, nro_partido_fase) REFERENCES torneo.PARTIDO (id_fase, nro_partido_fase),
    CONSTRAINT FK_GOL_AUTOR FOREIGN KEY (id_seleccion, dorsal_autor) REFERENCES torneo.CONVOCATORIA (id_seleccion, dorsal_oficial),
    CONSTRAINT FK_GOL_ASISTENTE FOREIGN KEY (id_seleccion, dorsal_asistente) 
    REFERENCES torneo.CONVOCATORIA (id_seleccion, dorsal_oficial),
    CONSTRAINT CHK_GOL_MINUTO CHECK (minuto_gol BETWEEN 1 AND 120),
    CONSTRAINT CHK_GOL_MINUTO_EXTRA CHECK (minuto_gol_extra > 0),
    CONSTRAINT CHK_GOL_TIPO CHECK (tipo_gol IN ('JUGADA', 'CABEZA', 'PENAL', 'TIRO_LIBRE', 'AUTOGOL'))
);

-- SANCION_TARJETA
CREATE TABLE torneo.SANCION_TARJETA (
    id_fase INT NOT NULL,
    nro_partido_fase INT NOT NULL,
    id_tarjeta INT NOT NULL,
    minuto_sancion INT NOT NULL,
    minuto_sancion_extra INT NULL,
    tipo_tarjeta VARCHAR(20) NOT NULL,
    motivo VARCHAR(100) NOT NULL,
    id_seleccion INT NOT NULL,
    dorsal_sancionado INT NOT NULL,
    CONSTRAINT PK_SANCION_TARJETA PRIMARY KEY (id_fase, nro_partido_fase, id_tarjeta),
    CONSTRAINT FK_SANCION_PARTIDO FOREIGN KEY (id_fase, nro_partido_fase) REFERENCES torneo.PARTIDO (id_fase, nro_partido_fase),
    CONSTRAINT FK_SANCION_JUGADOR FOREIGN KEY (id_seleccion, dorsal_sancionado) REFERENCES torneo.CONVOCATORIA (id_seleccion, dorsal_oficial),
    CONSTRAINT CHK_SANCION_MINUTO CHECK (minuto_sancion BETWEEN 1 AND 120),
    CONSTRAINT CHK_SANCION_MINUTO_EXTRA CHECK (minuto_sancion_extra > 0),
    CONSTRAINT CHK_SANCION_TIPO CHECK (tipo_tarjeta IN ('AMARILLA', 'ROJA_DIRECTA', 'DOBLE_AMARILLA'))
);

-- CONTROL_SUSPENSION
CREATE TABLE torneo.CONTROL_SUSPENSION (
    id_seleccion INT NOT NULL,
    dorsal_oficial INT NOT NULL,
    amarillas_acumuladas INT CONSTRAINT DF_SUSPENSION_AMARILLAS DEFAULT 0 NOT NULL,
    partidos_suspension INT CONSTRAINT DF_SUSPENSION_PARTIDOS DEFAULT 0 NOT NULL,
    cumplida BIT CONSTRAINT DF_SUSPENSION_CUMPLIDA DEFAULT 0 NOT NULL,
    CONSTRAINT PK_CONTROL_SUSPENSION PRIMARY KEY (id_seleccion, dorsal_oficial),
    CONSTRAINT FK_SUSPENSION_CONVOCATORIA FOREIGN KEY (id_seleccion, dorsal_oficial) REFERENCES torneo.CONVOCATORIA (id_seleccion, dorsal_oficial)
);
GO

PRINT 'TABLAS DE ESQUEMA partido del torneo CREADAS EXITOSAMENTE'

-- Esquema Comercial

-- ANUNCIANTE
CREATE TABLE comercial.ANUNCIANTE (
    id_anunciante INT NOT NULL,
    id_pais_origen CHAR(3) NOT NULL,
    razon_social VARCHAR(100) NOT NULL,
    marca_comercial VARCHAR(50) NOT NULL,
    rubro VARCHAR(50) NOT NULL,
    CONSTRAINT PK_ANUNCIANTE PRIMARY KEY (id_anunciante),
    CONSTRAINT FK_ANUNCIANTE_PAIS FOREIGN KEY (id_pais_origen) REFERENCES geografia.PAIS (id_pais)
);

-- CAMPANIA_PUBLICITARIA
CREATE TABLE comercial.CAMPANIA_PUBLICITARIA (
    id_campania INT NOT NULL,
    id_anunciante INT NOT NULL,
    nombre_campania VARCHAR(100) NOT NULL,
    presupuesto_max_usd DECIMAL(18,2) NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NOT NULL,
    CONSTRAINT PK_CAMPANIA_PUBLICITARIA PRIMARY KEY (id_campania),
    CONSTRAINT FK_CAMPANIA_ANUNCIANTE FOREIGN KEY (id_anunciante) REFERENCES comercial.ANUNCIANTE (id_anunciante),
    CONSTRAINT CHK_CAMPANIA_PRESUPUESTO CHECK (presupuesto_max_usd > 0),
    CONSTRAINT CHK_CAMPANIA_FECHAS CHECK (fecha_fin >= fecha_inicio)
);

-- PIEZA_PUBLICITARIA
CREATE TABLE comercial.PIEZA_PUBLICITARIA (
    id_pieza INT NOT NULL,
    id_campania INT NOT NULL,
    url_contenido VARCHAR(255) NOT NULL,
    duracion_segundos INT NOT NULL,
    idioma VARCHAR(20) NOT NULL,
    descripcion_pieza VARCHAR(100) NOT NULL,
    CONSTRAINT PK_PIEZA_PUBLICITARIA PRIMARY KEY (id_pieza),
    CONSTRAINT FK_PIEZA_CAMPANIA FOREIGN KEY (id_campania) REFERENCES comercial.CAMPANIA_PUBLICITARIA (id_campania),
    CONSTRAINT CHK_PIEZA_DURACION CHECK (duracion_segundos > 0)
);

-- EXHIBICION_PUBLICITARIA
CREATE TABLE comercial.EXHIBICION_PUBLICITARIA (
    id_exhibicion INT NOT NULL,
    id_fase INT NOT NULL,
    nro_partido_fase INT NOT NULL,
    id_anunciante INT NOT NULL,
    id_campania INT NOT NULL,
    id_pieza INT NOT NULL,
    letrero_posicion INT NOT NULL,
    minuto_inicio INT NOT NULL,
    minuto_fin INT NOT NULL,
    costo_calculado_usd DECIMAL(18,2) NOT NULL,
    CONSTRAINT PK_EXHIBICION_PUBLICITARIA PRIMARY KEY (id_exhibicion),
    CONSTRAINT FK_EXHIBICION_PARTIDO FOREIGN KEY (id_fase, nro_partido_fase) REFERENCES torneo.PARTIDO (id_fase, nro_partido_fase),
    CONSTRAINT FK_EXHIBICION_ANUNCIANTE FOREIGN KEY (id_anunciante) REFERENCES comercial.ANUNCIANTE (id_anunciante),
    CONSTRAINT FK_EXHIBICION_CAMPANIA FOREIGN KEY (id_campania) REFERENCES comercial.CAMPANIA_PUBLICITARIA (id_campania),
    CONSTRAINT FK_EXHIBICION_PIEZA FOREIGN KEY (id_pieza) REFERENCES comercial.PIEZA_PUBLICITARIA (id_pieza),
    CONSTRAINT CHK_EXHIBICION_LETRERO CHECK (letrero_posicion BETWEEN 1 AND 4),
    CONSTRAINT CHK_EXHIBICION_MINUTOS CHECK (minuto_inicio >= 0 AND minuto_fin > minuto_inicio),
    CONSTRAINT CHK_EXHIBICION_COSTO CHECK (costo_calculado_usd >= 0)
);
GO

PRINT 'TABLAS DE ESQUEMA comercial CREADAS EXITOSAMENTE'