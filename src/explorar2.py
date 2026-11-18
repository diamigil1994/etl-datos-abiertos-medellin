import pandas as pd

RUTA = "data/raw/victimas_incidentes_viales.csv"
df = pd.read_csv(RUTA, dtype=str)

# 1. Filas completamente vacías
vacias = df.isna().all(axis=1)
print("Filas totalmente vacías:", vacias.sum())
df = df[~vacias]
print("Filas con datos:", len(df))
print()

# 2. Cuántas filas hay por año
print(df["Año"].value_counts().sort_index())
print()

# 3. Radicado
print("Radicados únicos:", df["Radicado"].nunique())
print("Radicados nulos:", df["Radicado"].isna().sum())
print()

# 4. Duplicados exactos
print("Filas duplicadas exactas:", df.duplicated().sum())
print()

# 5. Categorías
for col in ["Gravedad_victima", "Clase_incidente", "Sexo", "Condicion", "Grupo_edad"]:
    print(df[col].value_counts(dropna=False))
    print()

# 6. Edad (convertida a número solo para mirar)
edad = pd.to_numeric(df["Edad"], errors="coerce")
print(edad.describe())