"""
================================================================================
UNLaM - Universidad Nacional de La Matanza
Departamento de Ingeniería e Investigaciones Tecnológicas
Materia: Base de Datos Aplicada (Comisión 5600) - 2026 2C
Grupo 10: Copa Mundial de la FIFA 2026

Entrega 9
Archivo: Reportes.py (Pagina de Reportes)
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
    st.header(" 📊 Reportes (Entrega 7)")
st.write("---")  

conn = obtener_conexion()
st.markdown("##### Tarjetas por selección y jugador")
tarjetas = conn.execute("EXEC reportes.sp_REPORTE_TARJETAS_SELECCION_JUGADOR @FormatoXML = 0").fetchall()
estado = st.radio("Estado", ["Todos", "HABILITADO", "SUSPENDIDO", "SUSPENSION CUMPLIDA"])
if estado != "Todos":
    tarjetas = [t for t in tarjetas if t.Estado == estado]
st.table([tuple(t) for t in tarjetas])
xml = "".join(fila[0] for fila in conn.execute("EXEC reportes.sp_REPORTE_TARJETAS_SELECCION_JUGADOR @FormatoXML = 1").fetchall())
st.download_button("Descargar XML de tarjetas", xml, file_name="reporte_tarjetas.xml")

st.write("---")

st.markdown("##### Designaciones arbitrales")
st.table([tuple(f) for f in conn.execute("EXEC reportes.sp_REPORTE_DESIGNACIONES_ARBITRALES @FormatoXML = 0").fetchall()])
xml = "".join(fila[0] for fila in conn.execute("EXEC reportes.sp_REPORTE_DESIGNACIONES_ARBITRALES @FormatoXML = 1").fetchall())
st.download_button("Descargar XML de arbitros", xml, file_name="reporte_arbitros.xml")

st.write("---")

st.markdown("##### Ocupacion publicitaria por sede")
cursor = conn.execute("EXEC reportes.sp_REPORTE_OCUPACION_PUBLICITARIA @FormatoXML = 0")
columnas = [col[0].replace("_"," ") for col in cursor.description]
datos = [dict(zip(columnas, fila)) for fila in cursor.fetchall()]
st.table(datos)
xml = "".join(fila[0] for fila in conn.execute("EXEC reportes.sp_REPORTE_OCUPACION_PUBLICITARIA @FormatoXML = 1").fetchall())
st.download_button("Descargar XML de ocupacion publicitaria", xml, file_name="reporte_ocupacion.xml")

conn.close()
st.write("---")
# Pie de Página Institucional

st.caption("Trabajo Práctico Integrador 2026 - 2C | Universidad Nacional de La Matanza (UNLaM) | Bases de Datos Aplicadas | Grupo 10")
