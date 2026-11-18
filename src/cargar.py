import os
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


def crear_staging():
    """Ejecuta sql/01_staging.sql: recrea la tabla stg.victimas vacía."""
    sql = RUTA_SQL_STAGING.read_text(encoding="utf-8")
    conexion = pyodbc.connect(cadena_conexion(BASE), autocommit=True)
    conexion.execute(sql)
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


if __name__ == "__main__":
    crear_base()
    crear_staging()

    df = preparar_datos()
    print("Filas a cargar:      ", len(df))

    cargar_staging(df)
    en_sql = contar_staging()
    print("Filas en stg.victimas:", en_sql)

    # Conciliación: lo que sale de Python debe ser igual a lo que entra a SQL Server
    assert en_sql == len(df)
    print("Carga conciliada.")