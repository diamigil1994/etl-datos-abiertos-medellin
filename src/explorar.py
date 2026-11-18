import pandas as pd

RUTA = "data/raw/victimas_incidentes_viales.csv"

# dtype=str: leemos TODO como texto, sin que pandas adivine tipos.
# En la capa raw no se interpreta nada; eso se hace al transformar.
df = pd.read_csv(RUTA, dtype=str)

print("Filas y columnas:", df.shape)
print()
print("Columnas:", df.columns.tolist())
print()
print(df.head())
print()
print("Valores vacíos por columna:")
print(df.isna().sum())