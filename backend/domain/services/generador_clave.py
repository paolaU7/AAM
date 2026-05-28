import random
import string


def claveGenerada() -> str:
    """
    Genera una contraseña con el formato abc.123:
    3 letras minúsculas, un punto, 3 dígitos.
    Función pura — sin efectos laterales.
    """
    letras  = random.choices(string.ascii_lowercase, k=3)
    digitos = random.choices(string.digits, k=3)
    return f"{''.join(letras)}.{''.join(digitos)}"
