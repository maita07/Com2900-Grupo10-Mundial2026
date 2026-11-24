"""
================================================================================
UNLaM - Universidad Nacional de La Matanza
Departamento de Ingeniería e Investigaciones Tecnológicas
Materia: Base de Datos Aplicada (Comisión 5600) - 2026 2C
Grupo 10: Copa Mundial de la FIFA 2026

Entrega 9
Archivo: 4_Validaciones.py (Pagina de Validaciones y Criterios de Aceptacion)
================================================================================
"""
import streamlit as st
import pandas as pd
import pyodbc
import os
import sys

# Conexión a la base de datos
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'src')))
try:
    from conexion import obtener_conexion
except ImportError:
    def obtener_conexion():
        cadena = (
            "DRIVER={ODBC Driver 17 for SQL Server};"
            "SERVER=localhost\\SQLEXPRESS;"
            "DATABASE=DB_Mundial2026_Grupo10;"
            "Trusted_Connection=yes;"
        )
        return pyodbc.connect(cadena)

st.set_page_config(page_title="Mundial 2026 - Criterios de Aceptación", page_icon="📋", layout="wide")

st.title("📋 Tablero de Control y Criterios de Aceptación")
st.write("Demostración interactiva de las reglas de negocio, sedes y casos obligatorios evaluados por la cátedra.")

tab_sedes, tab_expulsiones, tab_suspension, tab_cambios, tab_arbitros, tab_auditoria = st.tabs([
    "🏟️ Sedes y UTC",
    "🟥 1. Expulsiones",
    "⚠️ 2. Suspensión Activa",
    "⏱️ 3. Cambio < 20 min",
    "⚖️ 4. Regla Arbitral",
    "📑 5. Errores Parciales"
])

# 1. SEDES Y HUSOS HORARIOS
with tab_sedes:
    st.subheader("🏟️ Sedes Oficiales, Capacidad y Husos Horarios (UTC)")
    try:
        conn = obtener_conexion()
        query = """
            SELECT 
                P.nombre_pais AS [País Sede],
                S.ciudad AS [Ciudad],
                S.nombre_estadio AS [Estadio],
                S.capacidad AS [Capacidad],
                S.huso_horario_utc AS [Huso Horario UTC]
            FROM torneo.SEDE S
            INNER JOIN geografia.PAIS P ON S.id_pais = P.id_pais
            ORDER BY P.nombre_pais, S.capacidad DESC;
        """
        df = pd.read_sql(query, conn)
        conn.close()
        st.dataframe(df, use_container_width=True, hide_index=True)
    except Exception as e:
        st.error(f"Error al consultar sedes: {e}")

# 2. EXPULSIONES 
    st.subheader("🟥 Caso: Expulsión por Doble Amarilla y por Roja Directa")
    

# 3. SUSPENSIONES POR TARJETAS
    st.subheader("⚠️ Caso: Jugadores Inhabilitados por Acumulación de Amarillas")
   

# 4. CAMBIO POR LESIÓN
    st.subheader("⏱️ Caso: Sustitución por Lesión en los Primeros 20 Minutos")
    
# 5. REGLA ARBITRAL

    st.subheader("⚖️ Caso: Descarte Arbitral por Conflicto de Nacionalidad")
    st.caption("Verificación de que un árbitro no pueda ser designado si comparte nacionalidad con alguno de los países en cancha.")

