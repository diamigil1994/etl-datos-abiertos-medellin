import os
import pyodbc
from dotenv import load_dotenv

load_dotenv()

servidor = os.getenv("DB_SERVER")
usuario = os.getenv("DB_USER")
clave = os.getenv("DB_PASSWORD")

# Sin DATABASE: la base IncidentesViales todavía no existe, entramos a la del sistema
conexion = pyodbc.connect(
    "DRIVER={ODBC Driver 18 for SQL Server};"
    f"SERVER={servidor};UID={usuario};PWD={clave};"
    "TrustServerCertificate=yes;",
    timeout=10,
)

cursor = conexion.cursor()
cursor.execute("SELECT @@VERSION")
print(cursor.fetchone()[0])
conexion.close()