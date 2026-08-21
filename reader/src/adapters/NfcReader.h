#ifndef NFCREADER_H
#define NFCREADER_H

#include <string>
#include <Adafruit_PN532.h>

class NfcReader {
public:
    NfcReader();
    
    /**
     * Inicializa el módulo NFC y lo configura.
     * @return true si el lector fue encontrado e inicializado correctamente.
     */
    bool begin();
    
    /**
     * Intenta leer pasivamente un UID (ej. NTAG213, NTAG215).
     * @param outUid String donde se guardará el UID leído en formato hexadecimal.
     * @return true si se detectó y leyó un UID.
     */
    bool tryReadTag(std::string& outUid);

private:
    Adafruit_PN532 _nfc;
    
    // Función auxiliar para convertir el buffer a string hex
    std::string bytesToHexString(const uint8_t* buffer, uint8_t length);
};

#endif // NFCREADER_H
