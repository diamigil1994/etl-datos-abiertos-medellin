import pandas as pd
from pathlib import Path

RUTA_RAW = Path("data/raw/victimas_incidentes_viales.csv")
RUTA_SALIDA = Path("data/processed/victimas_extraido.csv")


def extraer():
    """Lee el CSV crudo y descarta las filas completamente vacías."""
    # Todo como texto: en esta capa no se interpreta nada
    df = pd.read_csv(RUTA_RAW, dtype=str)
    total_leidas = len(df)

    # Número de línea en el archivo original (la línea 1 es el encabezado)
    df["id_fila_origen"] = df.index + 2

    # Una fila está vacía si TODAS las columnas de datos son nulas
    columnas_datos = [c for c in df.columns if c != "id_fila_origen"]
    vacias = df[columnas_datos].isna().all(axis=1)
    descartadas = int(vacias.sum())

    df = df[~vacias]
    return df, total_leidas, descartadas


def ejecutar():
    df, total_leidas, descartadas = extraer()

    RUTA_SALIDA.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(RUTA_SALIDA, index=False, encoding="utf-8")

    print("Filas leídas:      ", total_leidas)
    print("Filas descartadas: ", descartadas)
    print("Filas conservadas: ", len(df))


if __name__ == "__main__":
    ejecutar()