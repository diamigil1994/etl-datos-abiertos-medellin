import time

import extraer
import transformar
import cargar


def paso(nombre, funcion):
    """Ejecuta una etapa y muestra cuánto tardó."""
    print(f"\n=== {nombre} ===")
    inicio = time.time()
    funcion()
    print(f"Duración: {time.time() - inicio:.1f} s")


if __name__ == "__main__":
    inicio = time.time()

    paso("1. Extraer", extraer.ejecutar)
    paso("2. Transformar", transformar.ejecutar)
    paso("3. Cargar", cargar.ejecutar)

    print(f"\nPipeline completo en {time.time() - inicio:.1f} s")