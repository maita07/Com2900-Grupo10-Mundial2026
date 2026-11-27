# UNLaM - Bases de Datos Aplicada (3641)

**Departamento de Ingeniería e Investigaciones Tecnológicas**  
**Trabajo Práctico Integrador:** Sistema Centralizado del Mundial de Fútbol 2026  
**Ciclo Lectivo:** 2026 - 2C  
**Comisión:** 2900  
**Grupo:** 10  

## Integrantes

| Nombre y Apellido | DNI |
| :--- | :--- |
| José Gregorio Maita Pitado | 95983375 |
| Gabriela Florencia Castillo | 32980931 |
| Ariel Ignacio Arena | 47147384 |
| Monasterio Erik Agustin | 44887958 |

---

# Guía Paso a Paso: Levantamiento y Pruebas de la Base de Datos

Procedimiento completo desde el borrado y creación de `DB_Mundial2026_Grupo10` hasta las validaciones, seguridad, Streamlit y Power BI.

## Prerrequisitos Previos

- **Microsoft SQL Server** en ejecución (preferentemente en Windows si se van a ejecutar las importaciones de APIs externas, ya que `MSXML2.ServerXMLHTTP` mediante `Ole Automation Procedures` solo funciona en SQL Server sobre Windows).
- **Acceso a Internet** para las importaciones que consumen APIs externas (`open.er-api.com`, `api.fifa.com` y Supabase).
- **Permisos de lectura** de la cuenta del servicio SQL Server sobre la carpeta `Data\` del repositorio (reemplazá `C:\RUTA_REPO` por la ruta absoluta donde clonaste el proyecto, por ejemplo `C:\Mundial2026`).
- Ejecutar todo como usuario **sysadmin / sa** hasta el paso de pruebas de roles.

---

## Paso 1: Borrado de la Base de Datos Existente (Reset desde Cero)

Si ya existe una instalación previa de `DB_Mundial2026_Grupo10`, ejecutá este bloque en `master` (SSMS o `sqlcmd`) para desconectar sesiones activas, eliminar la base de datos y limpiar opcionalmente los logins del servidor:

```sql
USE master;
GO

IF DB_ID(N'DB_Mundial2026_Grupo10') IS NOT NULL
BEGIN
    ALTER DATABASE DB_Mundial2026_Grupo10 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE DB_Mundial2026_Grupo10;
    PRINT 'Base de datos DB_Mundial2026_Grupo10 eliminada.';
END
GO

-- Opcional: eliminar los logins a nivel servidor para recrearlos desde cero en el Paso 7
IF SUSER_ID(N'login_admin')     IS NOT NULL DROP LOGIN login_admin;
IF SUSER_ID(N'login_operador')  IS NOT NULL DROP LOGIN login_operador;
IF SUSER_ID(N'login_comercial') IS NOT NULL DROP LOGIN login_comercial;
IF SUSER_ID(N'login_consulta')  IS NOT NULL DROP LOGIN login_consulta;
GO
```

---

## Paso 2: Creación de la Base de Datos, Esquemas y Tablas (DDL)

Ejecutá en orden los siguientes scripts en SSMS o Azure Data Studio:

1. `Scripts/01_CREATE_DATABASE_AND_SCHEMAS.sql` — Crea `DB_Mundial2026_Grupo10` y los esquemas `geografia`, `persona`, `torneo` y `comercial`.
2. `Scripts/02_CREATE_TABLE_AND_CONSTRAINT.sql` — Crea las 22 tablas base con sus PK, FK, `CHECK` y `DEFAULT`.
3. `Scripts/04_1_CREATE_TABLE_AND_SCHEMA_AUDITORIA.sql` — Crea el esquema `auditoria`, la tabla `auditoria.LOG_IMPORTACION` y el SP de registro de errores.
4. `Scripts/04_10_CREATE_TABLE_PIEZA_MERCADO.sql` — Crea la tabla `comercial.PIEZA_MERCADO` y su SP `comercial.sp_PIEZA_MERCADO_ABM`.

---

## Paso 3: Creación de Stored Procedures ABM (y Pruebas Unitarias Opcionales)

Ejecutá los 7 scripts de creación de SPs ABM en orden:

1. `Scripts/03_1_STORED_PROCEDURES_ABM.sql` — `geografia`: País, Confederación, Indicador, Tipo de Cambio.
2. `Scripts/03_2_STORED_PROCEDURES_ABM.sql` — `persona`: Jugador, Cuerpo Técnico, Árbitro.
3. `Scripts/03_3_STORED_PROCEDURES_ABM.sql` — `torneo`: Selección.
4. `Scripts/03_4_STORED_PROCEDURES_ABM.sql` — `torneo`: Convocatoria, Incidencia Convocatoria.
5. `Scripts/03_5_STORED_PROCEDURES_ABM.sql` — `torneo`: Rol Arbitral, Sede, Fase, Partido, Designación, Alineación, Jugador Alineación, Sustitución, Gol.
6. `Scripts/03_6_STORED_PROCEDURES_ABM.sql` — `torneo`: Sanción Tarjeta, Control Suspensión, Recálculo de Suspensión.
7. `Scripts/03_7_STORED_PROCEDURES_ABM.sql` — `comercial`: Anunciante, Campaña, Pieza, Exhibición.

### Pruebas unitarias de ABM (recomendado correr ahora, con la BD vacía o limpia):

- `Scripts/03_1_TEST_STORED_PROCEDURES.sql`
- `Scripts/03_2_TEST_STORED_PROCEDURES.sql`
- `Scripts/03_3_TEST_STORED_PROCEDURES_ABM.sql`
- `Scripts/03_4_TEST_STORED_PROCEDURES_ABM.sql`
- `Scripts/03_5_TEST_STORED_PROCEDURES.sql`
- `Scripts/03_6_TEST_STORED_PROCEDURES.sql`
- `Scripts/03_7_TEST_STORED_PROCEDURES.sql`

---

## Paso 4: Creación de Stored Procedures de Importación Masiva

Ejecutá estos scripts para compilar los procedimientos de carga (también habilitan `Ole Automation Procedures`):

1. `Scripts/04_2_IMPORT_PAISES_E_INDICADORES.sql`
2. `Scripts/04_3_IMPORT_SEDES_Y_FIXTURE.sql`
3. `Scripts/04_4_IMPORT_SELECCIONES_JUGADORES.sql`
4. `Scripts/04_5_IMPORT_ARBITROS.sql`
5. `Scripts/04_6_IMPORT_RESULTADOS_PARTIDOS.sql`
6. `Scripts/04_7_IMPORT_CUERPO_TECNICO.sql`
7. `Scripts/04_8_IMPORT_ALINEACIONES_SUSTITUCIONES.sql`
8. `Scripts/04_9_IMPORT_TARJETAS_SUSPENSIONES.sql`
9. `Scripts/04_11_IMPORT_ESQUEMA_COMERCIAL.sql`
10. `Scripts/04_12_CREATE_DATOS_EXHIBICION_PUBLICITARIA.sql`

---

## Paso 5: Ejecución de las Importaciones (en Orden de Dependencias FK)

Ejecutá el siguiente bloque en `DB_Mundial2026_Grupo10` respetando este orden exacto (reemplazando `C:\RUTA_REPO` por la ruta real de tu carpeta del proyecto):

```sql
USE DB_Mundial2026_Grupo10;
GO

-- 1. Países, indicadores económicos (CSV) y tipo de cambio (API)
EXEC geografia.sp_IMPORTAR_PAISES_E_INDICADORES
    @RutaCSV_Paises = 'C:\RUTA_REPO\Data\paises.csv';
EXEC geografia.sp_IMPORT_HISTORIAL_TIPO_CAMBIO_API;

-- 2. Confederaciones (XML), Fases, Sedes y Fixture (XML)
EXEC geografia.sp_IMPORTAR_CONFEDERACIONES_XML
    @RutaArchivo = 'C:\RUTA_REPO\Data\confederaciones.xml';
EXEC torneo.sp_IMPORTAR_FASES;
EXEC torneo.sp_IMPORTAR_SEDES_Y_FIXTURE_XML
    @RutaArchivo = 'C:\RUTA_REPO\Data\sedes_fixture.xml';

-- 3. Selecciones y Jugadores / Convocatorias (CSV)
EXEC torneo.sp_IMPORTAR_SELECCIONES_CSV
    @RutaArchivo = 'C:\RUTA_REPO\Data\teams.csv';
EXEC persona.sp_IMPORTAR_JUGADORES_CSV
    @RutaCSV = 'C:\RUTA_REPO\Data\SquadLists.csv';

-- 4. Árbitros y Designaciones Arbitrales (CSV + HTML + API FIFA)
EXEC persona.sp_IMPORTAR_ARBITROS
    @RutaArchivoCSV   = 'C:\RUTA_REPO\Data\arbitros.csv',
    @RutaArchivoHTML  = 'C:\RUTA_REPO\Data\2026 FIFA World Cup officials - Wikipedia.html',
    @RutaCSV_Paises   = 'C:\RUTA_REPO\Data\paises.csv';

-- 5. Resultados de Partidos (CSV) y Goles (JSON)
EXEC torneo.sp_IMPORTAR_PARTIDOS_Y_GOLES_CSV
    @RutaMatches = 'C:\RUTA_REPO\Data\matches_detailed.csv',
    @RutaGoles   = 'C:\RUTA_REPO\Data\worldcup.json';

-- 6. Cuerpo Técnico (API FIFA)
EXEC persona.sp_IMPORTAR_CUERPO_TECNICO_API;

-- 7. Alineaciones y Sustituciones (API FIFA)
EXEC torneo.sp_IMPORTAR_ALINEACIONES_Y_SUSTITUCIONES_FIFA;

-- 8. Tarjetas y Control de Suspensiones (API FIFA)
EXEC torneo.sp_IMPORTAR_TARJETAS_FIFA;

-- 9. Esquema Comercial (Supabase API) y Exhibiciones Publicitarias
EXEC comercial.sp_IMPORT_ESQUEMA_COMERCIAL;
EXEC comercial.sp_CREAR_DATOS_EXHIBICION_PUBLICITARIA;
GO

-- Verificación rápida de auditoría de importación:
SELECT * FROM auditoria.LOG_IMPORTACION ORDER BY id_log DESC;
```

---

## Paso 6: Creación y Prueba de los 7 Reportes Analíticos

Primero compilá los 7 scripts de reportes:

1. `Scripts/05_1_REPORT_GOLEADORES_SELECCION_FASE_TORNEO.sql`
2. `Scripts/05_2_REPORT_TARJETAS_SELECCION_JUGADOR.sql`
3. `Scripts/05_3_REPORT_DESIGNACIONES_ARBITRALES.sql`
4. `Scripts/05_4_REPORT_OCUPACION_PUBLICITARIA.sql`
5. `Scripts/05_5_REPORT_MATRIZ_PRIME_TIME.sql`
6. `Scripts/05_6_REPORT_SELECCIONES_PLANTILLAS.sql`
7. `Scripts/05_7_REPORT_RESULTADOS_ENCUENTROS.sql`

Luego probá todos en modo tabular (`@FormatoXML = 0`) y XML (`@FormatoXML = 1`):

```sql
EXEC reportes.sp_REPORTE_GOLEADORES_SELECCION_FASE_TORNEO @Top = 10, @FormatoXML = 0;
EXEC reportes.sp_REPORTE_GOLEADORES_SELECCION_FASE_TORNEO @Top = 10, @FormatoXML = 1;

EXEC reportes.sp_REPORTE_TARJETAS_SELECCION_JUGADOR @FormatoXML = 0;
EXEC reportes.sp_REPORTE_TARJETAS_SELECCION_JUGADOR @FormatoXML = 1;

EXEC reportes.sp_REPORTE_DESIGNACIONES_ARBITRALES @FormatoXML = 0;
EXEC reportes.sp_REPORTE_DESIGNACIONES_ARBITRALES @FormatoXML = 1;

EXEC reportes.sp_REPORTE_OCUPACION_PUBLICITARIA @FormatoXML = 0;
EXEC reportes.sp_REPORTE_OCUPACION_PUBLICITARIA @FormatoXML = 1;

EXEC reportes.sp_REPORTE_MATRIZ_PRIME_TIME @FormatoXML = 0;
EXEC reportes.sp_REPORTE_MATRIZ_PRIME_TIME @FormatoXML = 1;

EXEC reportes.sp_REPORTE_SELECCIONES_PLANTILLAS @FormatoXML = 0;
EXEC reportes.sp_REPORTE_SELECCIONES_PLANTILLAS @FormatoXML = 1;

EXEC reportes.sp_REPORTE_RESULTADOS_ENCUENTROS @FormatoXML = 0;
EXEC reportes.sp_REPORTE_RESULTADOS_ENCUENTROS @FormatoXML = 1;
```

---

## Paso 7: Cifrado de Datos Personales y Seguridad (Roles y Permisos)

1. **Cifrado:** Ejecutá `Scripts/06_1_CIFRADO.sql` (agrega las columnas cifradas, ejecuta `seguridad.sp_CIFRAR_DATOS_PERSONALES` y crea la función de descifrado).
2. **Roles, logins y usuarios:** Ejecutá `Scripts/06_2_CREATE_ROLES.sql` (crea `login_admin`, `login_operador`, `login_comercial`, `login_consulta`, sus usuarios, roles y permisos).
3. **Prueba de permisos (POLP):** Ejecutá `Scripts/06_3_TEST_ROLES.sql` y verificá en la pestaña *Messages* que todos los bloques impriman `[OK - PERMITIDO]` o `[OK - DENEGADO ESPERADO]` (ningún `[FALLO DE SEGURIDAD]`).

Verificación de descifrado:

```sql
SELECT TOP 10 * FROM persona.fn_DATOS_PERSONALES(N'cifrado datos');
```

---

## Paso 8: Validaciones de Criterios de Aceptación

Ejecutá `Scripts/07_1_TEST_VALIDACIONES_CRITERIOS.sql`:

- **Puntos 1 a 7:** deben devolver `CUMPLE CON LA REGLA` (sedes/husos, >= 16 selecciones con >= 23 jugadores, >= 24 partidos con titulares/suplentes, >= 15 árbitros + cuarteta y VAR, >= 6 países anunciantes, expulsiones doble amarilla/roja directa, suspendido fuera del siguiente partido).

> **Observación importante sobre los puntos 8, 9 y 10:**  
> Los puntos **8, 9 y 10** del script actual fallan porque referencian tablas y columnas inexistentes en el esquema (`partido.CAMBIO`, `transmision.PRIME_TIME_LOG`, `auditoria.LOG_CONFLICTO_ARBITRAL`). Conviene corregir esas 3 consultas contra las tablas reales antes de correr el archivo completo.

---

## Paso 9: Levantar y Probar la Aplicación Web (Streamlit) y Power BI

1. Verificá la cadena de conexión en `App/src/conexion.py` (`SERVER=localhost\SQLEXPRESS`, `DRIVER={ODBC Driver 17 for SQL Server}`).
2. Instalá dependencias y ejecutá Streamlit desde la raíz del repositorio:

```bash
pip install streamlit pyodbc pandas
streamlit run App/App.py
```

3. **Power BI:** Abrí `doc/Entrega 9 Power BI - Grupo 10.pbix`, actualizá el origen de datos a tu instancia local de `DB_Mundial2026_Grupo10` y refrescá los visuales.

> **Nota previa sobre Streamlit:**  
> Antes de levantar la aplicación web, eliminá las llamadas duplicadas a `st.set_page_config()` en `App.py`, `2_Gestion_ABM.py`, `3_Reportes.py` y `4_Validaciones_Criterios.py` para evitar el error `StreamlitAPIException` al abrir cada página.
