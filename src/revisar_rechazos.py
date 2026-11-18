import pandas as pd

r = pd.read_csv("data/processed/victimas_rechazos.csv")

print(r["Edad"].value_counts().sort_index())
print()
print(r["Año"].value_counts().sort_index())
print()
print(r["Grupo_edad"].value_counts())