# Hallazgos de calidad de datos

Dataset: Víctimas en Incidentes viales (MEData, Alcaldía de Medellín).
Exploración hecha el 17-nov-2026 con `src/explorar2.py`.

## Resumen

- El archivo trae 1.048.317 filas, pero **812.474 están vacías**. Los datos reales son **235.843 filas** (una fila por víctima).
- Los datos cubren de **2014 a 2021**, aunque el portal indica última modificación en 2025.
- Hay 189.106 radicados únicos, por lo que cada incidente tiene en promedio más de una víctima.

## Hallazgos y decisiones

| Hallazgo | Decisión en el pipeline |
|---|---|
| 812.474 filas vacías | Descartar y registrar el conteo en la bitácora |
| `Radicado` no es único (identifica el incidente, no la víctima) | Fila = víctima; usar un id propio de fila |
| 197 duplicados exactos | Marcar, no borrar; pueden ser víctimas distintas del mismo incidente |
| `Sin Inf` / `Sin inf`, `Motocicleta` / `motocicleta` |
| Latitud y longitud intercambiadas (2.112 filas) | Intercambiar los valores y dejarlos en su columna |
| Coordenadas fuera del Valle de Aburrá (3 filas) | Dejar en `NULL` |
| ~20.800 filas sin coordenadas (8,8 %) | Conservar con `NULL`; indicar en el dashboard |
| 355 edades mayores a 110 | Rechazar y guardar en `victimas_rechazos.csv` |