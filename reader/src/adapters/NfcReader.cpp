#include "NfcReader.h"
#include <Arduino.h>
#include <Wire.h>

NfcReader::NfcReader() : _nfc(-1, -1) {
    // -1, -1 para usar I2C sin pines IRQ/RESET explícitos
}

bool NfcReader::begin() {
    Wire.begin(21, 22); // Inicializar explícitamente I2C en los pines por defecto del ESP32
    delay(1000);        // Esperar a que el módulo PN532 encienda y esté listo
    
    _nfc.begin();

    uint32_t versiondata = _nfc.getFirmwareVersion();
    if (!versiondata) {
        Serial.println("No se encontró el chip PN53x");
        return false;
    }

    Serial.print("Encontrado chip PN5"); 
    Serial.println((versiondata >> 24) & 0xFF, HEX);
    
    // Configurar para leer etiquetas RFID/NFC
    _nfc.SAMConfig();
    return true;
}

bool NfcReader::tryReadTag(std::string& outUid) {
    uint8_t uid[7];
    uint8_t uidLength;

    bool success = _nfc.readPassiveTargetID(PN532_MIFARE_ISO14443A, uid, &uidLength, 50); // timeout corto de 50ms para no bloquear

    if (success) {
        outUid = bytesToHexString(uid, uidLength);
        return true;
    }
    return false;
}

std::string NfcReader::bytesToHexString(const uint8_t* buffer, uint8_t length) {
    std::string hexStr = "";
    char hexChars[3];
    for (uint8_t i = 0; i < length; i++) {
        sprintf(hexChars, "%02X", buffer[i]);
        hexStr += hexChars;
    }
    return hexStr;
}
