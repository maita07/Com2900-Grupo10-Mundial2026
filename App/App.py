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
import os

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

# 2. Barra Lateral (Sidebar)
with st.sidebar:
    st.markdown("## ⚽ FIFA World Cup 2026")
    st.markdown("### **Panel de Control**")
    st.caption("Base de Datos Aplicada | Comisión 5600")
    
    st.write("---")
    st.markdown("👨‍💻 **Integrantes - Grupo 10:**")
    st.markdown("""
    * **Monasterio Erik** (*MonasteryEr*)
    * **Arena Ariel Ignacio** (*arielarena*)
    * **Castillo Gabriela Florencia** (*ItsFlorencia*)
    * **Maita Pitado Jose Gregorio** (*maita07*)
    """)
    st.write("---")
    st.caption("Utilice las páginas de arriba para navegar entre los módulos.")

# 3. Encabezado y Portada
col_titulo, col_logo = st.columns([4, 1])

with col_titulo:
    st.title("🏆 Copa Mundial de la FIFA 2026™")
    st.subheader("Sistema Integral de Gestión y Administración de Base de Datos")
    st.markdown("**Sedes Oficiales:** Estados Unidos 🇺🇸 | México 🇲🇽 | Canadá 🇨🇦")

st.write("---")


# 4. Estado del Servidor y Base de Datos 
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


# 5. Guía de Módulos del Sistema
st.markdown("### 🧭 Módulos Disponibles en la Aplicación")
st.markdown("Seleccione cualquiera de los módulos desde la barra lateral izquierda:")

col_m1, col_m2, col_m3 = st.columns(3)

with col_m1:
    st.markdown("""
    #### 📥 1. Importación Masiva (Entrega 6)
    * **Carga de Datos:** Selecciones (`CSV`), Planteles (`CSV`), Sedes y Fixture (`XML`), y Países (`CSV`).
    * **Lógica Upsert:** Validación de integridad y prevención de duplicados.
    * **Auditoría en Vivo:** Visualización directa de errores y advertencias en `auditoria.LOG_IMPORTACION`.
    """)

with col_m2:
    st.markdown("""
    #### ⚽ 2. Gestión de Planteles (Entrega 5)
    * **ABM Centralizado:** Operaciones de Alta, Baja y Modificación sobre `persona.sp_JUGADOR_ABM`.
    * **Filtros Dinámicos:** Búsqueda rápida de futbolistas por país convocante y posición en el campo.
    * **Integridad Referencial:** Control estricto de documentos y convocatorias oficiales.
    """)

with col_m3:
    st.markdown("""
    #### 📊 3. Reportes y Analítica (Entrega 7/9)
    * **Métricas del Torneo:** Estadísticas de goles por fase, capacidad de estadios y fixture.
    * **Indicadores Económicos:** Relación de selecciones y PBI per cápita de sus federaciones.
    * **Seguridad y Roles:** Compatibilidad con las políticas POLP del rol de consulta.
    """)

st.write("---")

# 6. Pie de Página Institucional

st.caption("Trabajo Práctico Integrador 2026 - 2C | Universidad Nacional de La Matanza (UNLaM) | Base de Datos Aplicadas")