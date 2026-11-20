"""
================================================================================
UNLaM - Universidad Nacional de La Matanza
Departamento de Ingeniería e Investigaciones Tecnológicas
Materia: Base de Datos Aplicada (Comisión 5600) - 2026 2C
Grupo 10: Copa Mundial de la FIFA 2026

Entrega 9
Archivo: App.py (Pagina principal del sistema Streamlit)
================================================================================
"""
import streamlit as st
import sys
import base64
import os


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
    ruta_logo = os.path.join(os.path.dirname(__file__), "assets", "logo_mundial2026_unlam.png")
    if os.path.exists(ruta_logo):
        st.image(ruta_logo, use_container_width=True)

    # 3. Título del panel
    st.markdown("### **Panel de Control**")
    
    # Enlace a esta misma página renombrada como "Página Principal"
    
    st.page_link("App.py", label="Página Principal", icon="🏠")
    
    # Enlace a tu pantalla de importación
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
  
# Encabezado y Portada
col_titulo, col_logo = st.columns([4, 1])

with col_titulo:
    st.title("🏆 Copa Mundial de la FIFA 2026™")
    st.subheader("Sistema Integral de Gestión y Administración de Base de Datos")
   

st.write("---")

st.markdown("""
#### 📥 1. Importación Masiva (Entrega 6)
* **Carga de Datos:** Selecciones (`CSV`), Planteles (`CSV`), Sedes y Fixture (`XML`), y Países (`CSV`).
* **Lógica Upsert:** Validación de integridad y prevención de duplicados.
* **Auditoría en Vivo:** Visualización directa de errores y advertencias en `auditoria.LOG_IMPORTACION`.
""")



st.write("---")

# Estado del Servidor y Base de Datos 
st.markdown("### 🔌 Estado de Conexión al Motor de Base de Datos")

if CONEXION_DISPONIBLE:
    try:
        conn = obtener_conexion()
        cursor = conn.cursor()
        cursor.execute("SELECT @@SERVERNAME, DB_NAME(), GETDATE();")
        servidor, base_datos, fecha_hora = cursor.fetchone()
        conn.close()

        col_st1, col_st2, col_st3 = st.columns(3)
        with col_st1:
            st.success(f"🟢 **Servidor Conectado:**\n`{servidor}`")
        with col_st2:
            st.info(f"🗄️ **Base de Datos:**\n`{base_datos}`")
        with col_st3:
            st.metric(label="Hora del Servidor SQL", value=fecha_hora.strftime("%H:%M:%S"))
    except Exception as e:
        st.error(f"🔴 **Error de Conexión a SQL Server:** No se pudo enlazar con la base.\n\n*Detalle técnico:* `{e}`")
        st.warning("Verifique que el servicio de SQL Server esté iniciado y que `src/conexion.py` tenga el servidor correcto.")
else:
    st.warning("⚠️ No se encontró el archivo `src/conexion.py`.")

st.write("---")

# Pie de Página Institucional

st.caption("Trabajo Práctico Integrador 2026 - 2C | Universidad Nacional de La Matanza (UNLaM) | Base de Datos Aplicadas")