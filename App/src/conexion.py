import pyodbc

def obtener_conexion():

    #Función compartida para conectar a SQL Server.

    cadena_conexion = (
        "DRIVER={ODBC Driver 17 for SQL Server};"
        "SERVER=localhost\\SQLEXPRESS;" #uso SQLEXPRESS, sino se debe modificar 
        "DATABASE=DB_Mundial2026_Grupo10;"
        "Trusted_Connection=yes;"
    )
    return pyodbc.connect(cadena_conexion)