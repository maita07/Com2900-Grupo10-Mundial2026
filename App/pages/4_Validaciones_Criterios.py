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
import base64
import sys

# Configuración de página
st.set_page_config(
    page_title="BASES DE DATOS APLICADAS - Mundial 2026",
    page_icon="⚽",
    layout="wide"  # 'wide' aprovecha todo el ancho de la ventana
)

# Ruta a la imagen del banner
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
RUTA_BANNER = os.path.join(BASE_DIR, "..","assets", "Banner.jpg")

# Mostrar el banner arriba de todo
if os.path.exists(RUTA_BANNER):
    st.image(RUTA_BANNER, use_container_width=True)
elif os.path.exists("Banner.jpg"):
    st.image("Banner.jpg", use_container_width=True)
else:
    st.warning("⚠️ No se encontró el archivo del banner.")

# BARRA LATERAL PERSONALIZADA
with st.sidebar:
    # Ocultamos el menú automático nativo de Streamlit
    st.markdown("""
    <style>
        [data-testid="stSidebarNav"] {
            display: none !important;
        }
        /* Estilo sutil para los enlaces de navegación */
        .stPageLink {
            font-weight: 500;
        }
    </style>
    """, unsafe_allow_html=True)

    # Logo institucional arriba (si existe en assets)
    ruta_logo = os.path.join(os.path.dirname(__file__),"..", "assets", "logo_mundial2026_unlam.png")
    if os.path.exists(ruta_logo):
        st.image(ruta_logo, use_container_width=True)

    # 3. Título del panel
    st.markdown("### **Panel de Control**")
    
    # Enlace a esta misma página renombrada como "Página Principal"
    
    st.page_link("App.py", label="Página Principal", icon="🏠")
    
    # Enlace a tu pantalla de importación
    st.page_link("pages/4_Validaciones_Criterios.py", label="Criterios de Aceptacion", icon="📖")
    st.page_link("pages/1_Importacion.py", label="Importación", icon="📥")
    st.page_link("pages/2_Gestion_ABM.py", label="Gestión de ABM", icon="⚽")
    st.page_link("pages/3_Reportes.py", label="Reportes del Torneo", icon="📊")

    st.write("---")
 

# Función para aplicar la imagen de fondo con estética del banner
def aplicar_fondo_personalizado():
    ruta_fondo = os.path.join(os.path.dirname(__file__), "assets", "fondo_mundial2026.png")
    
    if os.path.exists(ruta_fondo):
        # Convertimos la imagen local a base64
        with open(ruta_fondo, "rb") as f:
            data = base64.b64encode(f.read()).decode("utf-8")
        
        css_fondo = f"""
        <style>
        .stApp {{
            background: 
                linear-gradient(rgba(7, 15, 38, 0.82), rgba(7, 15, 38, 0.88)),
                url("data:image/png;base64,{data}");
            background-size: cover;
            background-position: center;
            background-attachment: fixed;
        }}
        
        /* Ajuste de contraste para textos y títulos */
        h1, h2, h3, p, span, label {{
            color: #E2E8F0 !important;
        }}
        
        /* Tarjetas con efecto glassmorphism (vidrio esmerilado) */
        .modulo-card {{
            background: rgba(15, 23, 42, 0.75);
            backdrop-filter: blur(8px);
            border: 1px solid rgba(0, 210, 255, 0.2);
            border-radius: 12px;
            padding: 20px;
            margin-bottom: 15px;
            transition: all 0.3s ease;
        }}
        .modulo-card:hover {{
            border-color: #00D2FF;
            box-shadow: 0 0 15px rgba(0, 210, 255, 0.3);
            transform: translateY(-3px);
        }}
        .modulo-title {{
            color: #00D2FF !important;
            font-size: 1.25rem;
            font-weight: 700;
            margin-bottom: 8px;
        }}
        .modulo-desc {{
            color: #CBD5E1 !important;
            font-size: 0.92rem;
            line-height: 1.45;
        }}
        </style>
        """
        st.markdown(css_fondo, unsafe_allow_html=True)
    else:
        # Alternativa de respaldo con gradiente CSS puro si no encuentra la imagen
        st.markdown("""
        <style>
        .stApp {
            background: radial-gradient(circle at 80% 20%, #0d2b45 0%, #070f26 60%, #030712 100%);
            background-attachment: fixed;
        }
        </style>
        """, unsafe_allow_html=True)

aplicar_fondo_personalizado()

# importar módulos desde la subcarpeta src/
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), 'src')))

try:
    from conexion import obtener_conexion
    CONEXION_DISPONIBLE = True
except ImportError:
    CONEXION_DISPONIBLE = False

# 1. Configuración General de la Página

st.set_page_config(
    page_title="Mundial FIFA 2026 - Panel Principal",
    page_icon="🏆",
    layout="wide",
    initial_sidebar_state="expanded"
)
  
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

