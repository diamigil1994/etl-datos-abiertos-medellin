import pandas as pd
from pathlib import Path

RUTA_ENTRADA = Path("data/processed/victimas_extraido.csv")
RUTA_SALIDA = Path("data/processed/victimas_transformado.csv")
RUTA_RECHAZOS = Path("data/processed/victimas_rechazos.csv")

SIN_INFO = "Sin información"
EDAD_MAX = 110


def limpiar_texto(df):
    """Quita espacios al inicio, al final y los dobles dentro del texto."""
    for col in df.columns:
        df[col] = df[col].str.strip().str.replace(r"\s+", " ", regex=True)
    return df


def normalizar_categorias(df):
    """Unifica la forma de escribir las categorías."""
    # Sexo: solo M, F; cualquier otra cosa (incluido nulo) = sin información
    df["Sexo"] = df["Sexo"].str.upper()
    df.loc[~df["Sexo"].isin(["M", "F"]), "Sexo"] = SIN_INFO

    # Primera letra en mayúscula y el resto en minúscula
    for col in ["Gravedad_victima", "Clase_incidente", "Condicion"]:
        df[col] = df[col].str.capitalize()

    df["Grupo_edad"] = df["Grupo_edad"].replace({"Sin Inf": SIN_INFO})
    return df


def convertir_tipos(df):
    """Convierte texto a fecha y números."""
    df["Fecha_incidente"] = pd.to_datetime(
        df["Fecha_incidente"], format="%d/%m/%Y", errors="coerce"
    )
    # errors="coerce": lo que no se pueda convertir queda vacío (así 'Sin Inf' pasa a NULL)
    df["Edad"] = pd.to_numeric(df["Edad"], errors="coerce")
    for col in ["Latitud", "Longitud"]:
        df[col] = pd.to_numeric(
            df[col].str.replace(",", ".", regex=False), errors="coerce"
        )
    return df


def corregir_coordenadas(df):
    """Corrige latitud/longitud intercambiadas y anula las que quedan fuera del área."""
    # Latitud negativa y longitud positiva = columnas intercambiadas
    intercambiadas = (df["Latitud"] < 0) & (df["Longitud"] > 0)
    df.loc[intercambiadas, ["Latitud", "Longitud"]] = (
        df.loc[intercambiadas, ["Longitud", "Latitud"]].values
    )

    # Área aproximada del Valle de Aburrá; fuera de ella = dato dudoso
    dentro = df["Latitud"].between(6.0, 6.5) & df["Longitud"].between(-75.8, -75.3)
    fuera = df["Latitud"].notna() & ~dentro
    df.loc[fuera, ["Latitud", "Longitud"]] = float("nan")

    return df, int(intercambiadas.sum()), int(fuera.sum())


def anular_edades_invalidas(df):
    """Edades fuera de 0-110 son códigos de 'sin información': se anulan y la fila se conserva."""
    fuera = (df["Edad"] < 0) | (df["Edad"] > EDAD_MAX)
    df.loc[fuera, "Edad"] = float("nan")
    return df, int(fuera.sum())


def aplicar_reglas(df):
    """Separa filas válidas de rechazadas, con el primer motivo que falla."""
    motivo = pd.Series(None, index=df.index, dtype="object")

    reglas = [
        ("Fecha inválida", df["Fecha_incidente"].isna()),
        ("Gravedad inválida", ~df["Gravedad_victima"].isin(["Heridos", "Muertos"])),
    ]
    for nombre, falla in reglas:
        # Solo se asigna si la fila todavía no tiene motivo (el primero que falla)
        motivo = motivo.mask(motivo.isna() & falla, nombre)

    rechazados = df[motivo.notna()].copy()
    rechazados["motivo_rechazo"] = motivo[motivo.notna()]
    validos = df[motivo.isna()].copy()
    return validos, rechazados


def ejecutar():
    df = pd.read_csv(RUTA_ENTRADA, dtype=str)
    total = len(df)

    df = limpiar_texto(df)
    df = normalizar_categorias(df)
    df = convertir_tipos(df)
    df, n_intercambiadas, n_fuera = corregir_coordenadas(df)
    df, n_edades = anular_edades_invalidas(df)
    validos, rechazados = aplicar_reglas(df)

    print("Filas de entrada:                     ", total)
    print("Coordenadas intercambiadas corregidas:", n_intercambiadas)
    print("Coordenadas fuera de área anuladas:   ", n_fuera)
    print("Edades inválidas anuladas (NULL):     ", n_edades)
    print("Filas válidas:                        ", len(validos))
    print("Filas rechazadas:                     ", len(rechazados))

    # Conciliación: nada se pierde sin explicación
    assert len(validos) + len(rechazados) == total

    validos.to_csv(RUTA_SALIDA, index=False)
    rechazados.to_csv(RUTA_RECHAZOS, index=False)


if __name__ == "__main__":
    ejecutar()