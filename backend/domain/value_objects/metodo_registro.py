from enum import Enum


class MetodoRegistro(str, Enum):
    NFC    = "nfc"
    QR     = "qr"
    MANUAL = "manual"
