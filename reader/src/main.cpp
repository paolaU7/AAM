#include <Arduino.h>
#include <Wire.h>

#include "config/DeviceConfig.h"
#include "domain/AttendanceRecord.h"
#include "adapters/NfcReader.h"
#include "utils/UlidGenerator.h"

// Variables Globales (Orquestación)
DeviceConfig deviceConfig;
NfcReader nfcReader;

/**
 * Simula la obtención de la hora actual en milisegundos.
 * Próximo paso: integrar con reloj interno (NTP) cuando se configure WiFi.
 */
uint64_t getCurrentTimestampMs() {
    return (uint64_t)millis(); 
}

/**
 * Obtiene la fecha actual en formato ISO 8601.
 * Placeholder hasta tener sincronización NTP.
 */
std::string getIso8601Time() {
    return "2026-08-20T12:00:00Z";
}

#ifndef PIO_UNIT_TESTING

void setup() {
    Serial.begin(115200);
    while (!Serial) delay(10);
    
    Serial.println("\n=== AAM Firmware: Inicializando ===");

    // Cargar configuración (valores temporales hasta implementar WiFiManager y almacenamiento)
    deviceConfig.deviceId = "ESP32-AULA-12";
    deviceConfig.apiKey = "placeholder-api-key";
    deviceConfig.endpoint = "http://backend.local/api/v1/attendance-records";
    deviceConfig.wifiSsid = "SSID_PLACEHOLDER";
    deviceConfig.wifiPassword = "PASSWORD_PLACEHOLDER";

    // Iniciar adaptador NFC
    if (!nfcReader.begin()) {
        Serial.println("Error Fatal: No se detecta el lector PN532. Revise el cableado I2C.");
        while (true) {
            delay(1000);
        }
    }

    Serial.println("Lector NFC listo. Acerque una pulsera o tarjeta...");
    Serial.println("===================================");
}

void loop() {
    std::string tagUid;

    // Encuesta el lector NFC (no bloqueante, con timeout corto implementado en el adaptador)
    if (nfcReader.tryReadTag(tagUid)) {
        Serial.print("Etiqueta detectada - UID: ");
        Serial.println(tagUid.c_str());

        // Ensamblar los datos requeridos para el dominio
        uint64_t timestamp = getCurrentTimestampMs();
        std::string ulid = UlidGenerator::generateUlid(timestamp);

        // Crear el registro de dominio
        AttendanceRecord record;
        record.recordId = ulid;
        record.tagUid = tagUid;
        record.deviceId = deviceConfig.deviceId;
        record.recordedAt = getIso8601Time();

        // Mostrar registro ensamblado para verificación manual (simulando que se envía al backend/buffer)
        Serial.println("Registro de Asistencia Ensamblado:");
        Serial.printf("  record_id:   %s\n", record.recordId.c_str());
        Serial.printf("  tag_uid:     %s\n", record.tagUid.c_str());
        Serial.printf("  device_id:   %s\n", record.deviceId.c_str());
        Serial.printf("  recorded_at: %s\n", record.recordedAt.c_str());
        Serial.println("-----------------------------------");

        // Pausa para evitar registros duplicados inmediatos por dejar la tarjeta apoyada
        delay(1500);
    }
}

#endif // PIO_UNIT_TESTING