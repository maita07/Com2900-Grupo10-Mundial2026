"""
================================================================================
UNLaM - Universidad Nacional de La Matanza
Departamento de Ingeniería e Investigaciones Tecnológicas
Materia: Base de Datos Aplicada (Comisión 5600) - 2026 2C
Grupo 10: Copa Mundial de la FIFA 2026

Entrega 9
Archivo: 1_Importacion.py (Pagina de Importacion masiva)
================================================================================
"""
import streamlit as st
import sys
import base64
import os

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
st.markdown("""
    <style>
        /* 1. FIJAR ANCHO DEL SIDEBAR (250px exactos) */
        section[data-testid="stSidebar"],
        [data-testid="stSidebarContent"],
        [data-testid="stSidebarUserContent"],
        [data-testid="stSidebarNav"] {
            width: 250px !important;
            min-width: 250px !important;
            max-width: 250px !important;
            overflow-x: clip !important; /* 'clip' es más estricto que 'hidden' y no genera contexto de scroll */
        }

        /* ELIMINAR CUALQUIER BARRA HORIZONTAL DEL SIDEBAR */
        section[data-testid="stSidebar"]::-webkit-scrollbar,
        [data-testid="stSidebarContent"]::-webkit-scrollbar,
        [data-testid="stSidebarNav"]::-webkit-scrollbar,
        div[data-testid="stSidebarUserContent"]::-webkit-scrollbar,
        section[data-testid="stSidebar"] *::-webkit-scrollbar:horizontal {
            display: none !important;
            width: 0px !important;
            height: 0px !important;
        }

        /* Firefox y Edge moderno */
        section[data-testid="stSidebar"],
        section[data-testid="stSidebar"] * {
            scrollbar-width: none !important;
            -ms-overflow-style: none !important;
        }

        /* ÍCONOS COMPLETOS */
        ul[data-testid="stSidebarNavItems"] a {
            display: flex !important;
            align-items: center !important;
            padding: 0.35rem 0.5rem !important;
            overflow: hidden !important;
        }

        /* Ancho rígido para el emoji / icono */
        ul[data-testid="stSidebarNavItems"] a span:first-child,
        ul[data-testid="stSidebarNavItems"] a svg {
            min-width: 1.4rem !important;
            width: 1.4rem !important;
            flex-shrink: 0 !important;
            margin-right: 0.4rem !important;
        }

        /* Texto sin saltar ni desbordar */
        ul[data-testid="stSidebarNavItems"] a span:last-child {
            white-space: nowrap !important;
            overflow: hidden !important;
            text-overflow: ellipsis !important;
            flex-grow: 1 !important;
        }

        /* 4. OCULTAR BOTÓN (<<) Y CONTROL DE ARRASTRE */
        [data-testid="stSidebarCollapseButton"],
        [data-testid="stSidebarHeader"] button,
        [data-testid="collapsedControl"],
        [data-testid="stSidebarResizeHandle"] {
            display: none !important;
            visibility: hidden !important;
        }
    </style>
""", unsafe_allow_html=True)

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
        st.image(ruta_logo,width=220)

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
    ruta_fondo = os.path.join(os.path.dirname(__file__),"..", "assets", "fondo_mundial2026.png")
    
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
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__),"..", 'src')))

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
  
# Encabezado y Portada
col_titulo, col_logo = st.columns([4, 1])

with col_titulo:
    st.header("📥 Centro de Importación Masiva (Entrega 6)")
    st.markdown("Seleccione el proceso que desea ejecutar para sincronizar los datos en SQL Server:")
    

opciones_sp = [
    "1. Países e Indicadores Económicos (.csv)",
    "2. Sedes y Fixture Oficial (.xml)",
    "3. Árbitros y Designaciones (CSV + HTML)"
]
proceso_elegido = st.selectbox("📂 Proceso de Importación:", opciones_sp)

st.write("---")


# FORMULARIO DINÁMICO SEGÚN EL DATASET ELEGIDO
if proceso_elegido.startswith("1. Países"):
    sp_a_ejecutar = "geografia.sp_IMPORTAR_PAISES_E_INDICADORES"
    st.info("ℹ️ Carga el catálogo de países. Los indicadores economicos se consumen desde la API del Banco Mundial.")
    tipo_archivo = "csv"
    archivo = st.file_uploader("Arrastrá el archivo `paises.csv`:", type=["csv"], key="upl_paises")
    ruta_manual = st.text_input("O ingresá la ruta completa en disco:", value=r"C:\Mundial2026\Data\paises.csv", key="txt_paises")

elif proceso_elegido.startswith("2. Sedes"):
    sp_a_ejecutar = "torneo.sp_IMPORTAR_SEDES_Y_FIXTURE_XML"
    st.info("ℹ️ Carga Confederaciones, Sedes y Fixture Oficial desde XML.")
    tipo_archivo = "xml"
    
    col1, col2 = st.columns(2)
    with col1:
        archivo_confederacion = st.file_uploader("Arrastrá `confederaciones.xml`:", type=["xml"], key="upl_conf")
        ruta_confederacion = st.text_input("O ingresá la ruta completa en disco:", value=r"C:\Mundial2026\confederaciones.xml", key="txt_conf")

    with col2:
        archivo_sedes_fixture = st.file_uploader("Arrastrá `SedesYFixture.xml`:", type=["xml"], key="upl_sedes")
        ruta_sedes_fixture = st.text_input("O ingresá la ruta completa en disco:", value=r"C:\Mundial2026\SedesYFixture.xml", key="txt_sedes")

elif proceso_elegido.startswith("3. Árbitros"):
    sp_a_ejecutar = "persona.sp_IMPORTAR_ARBITROS"
    st.info("ℹ️ Sincroniza el cuerpo arbitral y sus designaciones combinando el catálogo de Wikidata (CSV) con el fixture de Wikipedia (HTML).")
    
    col_a1, col_a2 = st.columns(2)
    with col_a1:
        archivo_arbitros_csv = st.file_uploader(
            "Arrastrá `arbitros.csv` (Wikidata):", 
            type=["csv"], 
            key="upl_arb_csv"
        )
        ruta_arbitros_csv = st.text_input(
            "Ruta CSV en disco:", 
            value=r"C:\Mundial2026\Data\arbitros.csv", 
            key="txt_arb_csv"
        )
        
    with col_a2:
        archivo_arbitros_html = st.file_uploader(
            "Arrastrá `arbitros.html` (Wikipedia):", 
            type=["html", "htm"], 
            key="upl_arb_html"
        )
        ruta_arbitros_html = st.text_input(
            "Ruta HTML en disco:", 
            value=r"C:\Mundial2026\Data\arbitros.html", 
            key="txt_arb_html"
        )
    

# VISOR DE AUDITORÍA EN TIEMPO REAL (auditoria.LOG_IMPORTACION)
st.write("---")
col_tit, col_btn = st.columns([12, 14])
with col_tit:
    st.subheader("📋 Registro de Control y Auditoría (`auditoria.LOG_IMPORTACION`)")
with col_btn:
    if st.button("🔄 Actualizar Auditoría", use_container_width=True):
        st.rerun()

try:
    conn = obtener_conexion()
    query_auditoria = """
        SELECT TOP 25
            id_log AS [ID],
            fecha_hora AS [Fecha / Hora],
            proceso_origen AS [Procedimiento Origen],
            nro_fila AS [Fila],
            clave_registro AS [Clave / Detalle],
            mensaje_error AS [Descripción del Error],
            linea_error AS [Línea T-SQL]
        FROM auditoria.LOG_IMPORTACION
        ORDER BY id_log DESC;
    """
    df_auditoria = pd.read_sql(query_auditoria, conn)
    conn.close()

    if df_auditoria.empty:
        st.success("🟢 No hay errores registrados en la auditoría. Todas las cargas fueron limpias.")
    else:
        st.dataframe(df_auditoria, use_container_width=True, hide_index=True)
except Exception as e:
    st.warning(f"⚠️ No se pudo consultar la tabla de auditoría: `{e}`")

st.write("---")
# Pie de Página Institucional

st.caption("Trabajo Práctico Integrador 2026 - 2C | Universidad Nacional de La Matanza (UNLaM) | Bases de Datos Aplicadas | Grupo 10")