import os
from pathlib import Path

from dotenv import load_dotenv

# carga el .env que esta junto a este archivo
load_dotenv(Path(__file__).resolve().with_name(".env"))


def _requerida(nombre):
    valor = os.getenv(nombre)
    if not valor:
        raise RuntimeError(f"falta la variable de entorno {nombre} en el archivo .env")
    return valor


class Config:
    ORACLE_USER = _requerida("ORACLE_USER")
    ORACLE_PASSWORD = _requerida("ORACLE_PASSWORD")
    ORACLE_DSN = _requerida("ORACLE_DSN")
    ORACLE_WALLET_DIR = _requerida("ORACLE_WALLET_DIR")
    ORACLE_WALLET_PASSWORD = os.getenv("ORACLE_WALLET_PASSWORD") or None
    ORACLE_POOL_MIN = int(os.getenv("ORACLE_POOL_MIN", "1"))
    ORACLE_POOL_MAX = int(os.getenv("ORACLE_POOL_MAX", "5"))
