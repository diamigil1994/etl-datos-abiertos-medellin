import os
import re
from pathlib import Path
from urllib.parse import quote_plus

import pandas as pd
import pyodbc
from dotenv import load_dotenv
from sqlalchemy import create_engine

load_dotenv()

SERVIDOR = os.getenv("DB_SERVER")
BASE = os.getenv("DB_NAME")
USUARIO = os.getenv("DB_USER")
CLAVE = os.getenv("DB_PASSWORD")

RUTA_CSV = Path("data/processed/victimas_transformado.csv")
RUTA_SQL_STAGING = Path("sql/01_staging.sql")
RUTA_SQL_MODELO = Path("sql/02_modelo.sql")
RUTA_SQL_CARGA = Path("sql/03_carga_modelo.sql")


def cadena_conexion(base):
    return (
        "DRIVER={ODBC Driver 18 for SQL Server};"
        f"SERVER={SERVIDOR};DATABASE={base};UID={USUARIO};PWD={CLAVE};"
        "TrustServerCertificate=yes;"
    )


def crear_base():
    """Crea la base de datos si no existe (CREATE DATABASE exige autocommit)."""
    conexion = pyodbc.connect(cadena_conexion("master"), autocommit=True)
    conexion.execute(f"IF DB_ID('{BASE}') IS NULL CREATE DATABASE [{BASE}]")
    conexion.close()


def ejecutar_script(ruta):
    """Ejecuta un archivo .sql, dividiéndolo en lotes en cada línea GO."""
    texto = ruta.read_text(encoding="utf-8")
    lotes = re.split(r"^\s*GO\s*$", texto, flags=re.IGNORECASE | re.MULTILINE)

    conexion = pyodbc.connect(cadena_conexion(BASE), autocommit=True)
    for lote in lotes:
        if lote.strip():
            conexion.execute(lote)
    conexion.close()


def preparar_datos():
    """Lee el CSV transformado y deja cada columna con el tipo que espera SQL."""
    df = pd.read_csv(RUTA_CSV, dtype=str)

    # Nombres en minúscula y sin 'ñ', como en la tabla de staging
    df.columns = [c.lower().replace("año", "anio") for c in df.columns]

    df["id_fila_origen"] = df["id_fila_origen"].astype(int)
    df["fecha_incidente"] = pd.to_datetime(df["fecha_incidente"])
    df["edad"] = pd.to_numeric(df["edad"]).astype("Int64")  # entero con NULL
    df["latitud"] = pd.to_numeric(df["latitud"])
    df["longitud"] = pd.to_numeric(df["longitud"])
    return df


def cargar_staging(df):
    """Inserta las filas en stg.victimas por lotes."""
    engine = create_engine(
        "mssql+pyodbc:///?odbc_connect=" + quote_plus(cadena_conexion(BASE)),
        fast_executemany=True,
    )
    df.to_sql(
        "victimas",
        engine,
        schema="stg",
        if_exists="append",
        index=False,
        chunksize=5000,
    )
    engine.dispose()


def contar_staging():
    conexion = pyodbc.connect(cadena_conexion(BASE))
    total = conexion.execute("SELECT COUNT(*) FROM stg.victimas").fetchone()[0]
    conexion.close()
    return total


def cargar_modelo():
    """Ejecuta el procedimiento que llena el modelo estrella y devuelve la última fila de la bitácora."""
    conexion = pyodbc.connect(cadena_conexion(BASE), autocommit=True)
    conexion.execute("EXEC dwh.sp_cargar_modelo")
    fila = conexion.execute(
        "SELECT TOP 1 filas_leidas, filas_cargadas, estado "
        "FROM dwh.bitacora_carga ORDER BY carga_id DESC"
    ).fetchone()
    conexion.close()
    return fila


def ejecutar():
    crear_base()

    # Staging: se recrea vacío y se llena desde el CSV transformado
    ejecutar_script(RUTA_SQL_STAGING)
    df = preparar_datos()
    cargar_staging(df)
    en_sql = contar_staging()
    print("Filas a cargar:        ", len(df))
    print("Filas en stg.victimas: ", en_sql)

    # Conciliación: lo que sale de Python debe ser igual a lo que entra a SQL Server
    assert en_sql == len(df)

    # Modelo estrella: se crean las tablas y el procedimiento, y se ejecuta la carga
    ejecutar_script(RUTA_SQL_MODELO)
    ejecutar_script(RUTA_SQL_CARGA)
    leidas, cargadas, estado = cargar_modelo()
    print("Modelo estrella:        leídas", leidas, "| cargadas", cargadas, "|", estado)


if __name__ == "__main__":
    ejecutar()