#include <Arduino.h>
#include <Wire.h>
#include <WiFiManager.h>

#include "config/DeviceConfig.h"
#include "domain/AttendanceRecord.h"
#include "adapters/NfcReader.h"
#include "utils/UlidGenerator.h"
#include "utils/TimeProvider.h"

// ---------------------------------------------------------------------------
// Variables globales (orquestación)
// ---------------------------------------------------------------------------
DeviceConfig deviceConfig;
NfcReader    nfcReader;

#ifndef PIO_UNIT_TESTING

void setup() {
    Serial.begin(115200);
    while (!Serial) delay(10);

    Serial.println("\n=== AAM Firmware: Inicializando ===");

    // -----------------------------------------------------------------------
    // 1. Configuración estática del dispositivo
    //    WiFi SSID/Password ya no se hardcodean: los provee WiFiManager.
    // -----------------------------------------------------------------------
    deviceConfig.deviceId = "ESP32-AULA-12";
    deviceConfig.apiKey   = "placeholder-api-key";
    deviceConfig.endpoint = "http://backend.local/api/v1/attendance-records";

    // -----------------------------------------------------------------------
    // 2. WiFi — portal cautivo con WiFiManager
    //    Si el dispositivo ya conoce las credenciales, conecta directamente.
    //    Si no, levanta el AP "AAM-Setup" para que el usuario las configure
    //    desde cualquier dispositivo móvil o PC.
    // -----------------------------------------------------------------------
    Serial.println("[WiFi] Iniciando WiFiManager...");
    WiFiManager wifiManager;

    // En producción se puede habilitar wifiManager.resetSettings() una sola
    // vez para forzar reconfiguración; no se deja activo por defecto.
    wifiManager.setConnectTimeout(30);  // segundos hasta timeout en AP mode
    wifiManager.setConfigPortalTimeout(120); // segundos del portal cautivo

    // autoConnect: si falla la conexión automática, abre el portal "AAM-Setup"
    if (!wifiManager.autoConnect("AAM-Setup")) {
        Serial.println("[WiFi] No se pudo conectar. Reiniciando...");
        delay(3000);
        ESP.restart();
    }

    Serial.print("[WiFi] Conectado. IP: ");
    Serial.println(WiFi.localIP());

    // -----------------------------------------------------------------------
    // 3. NTP — sincronización de reloj (UTC)
    //    Debe ejecutarse DESPUÉS de obtener conexión WiFi.
    // -----------------------------------------------------------------------
    if (!TimeProvider::syncNtp()) {
        // Sin hora confiable los registros no tienen valor; se reinicia para
        // intentar de nuevo. En una futura iteración podría usarse el buffer
        // offline en lugar de reiniciar.
        Serial.println("[NTP] Fallo crítico de sincronización. Reiniciando...");
        delay(3000);
        ESP.restart();
    }

    // -----------------------------------------------------------------------
    // 4. Lector NFC
    // -----------------------------------------------------------------------
    if (!nfcReader.begin()) {
        Serial.println("[NFC] Error Fatal: No se detecta el PN532. Revise el cableado I2C.");
        while (true) delay(1000);
    }

    Serial.println("[NFC] Lector listo. Acerque una pulsera o tarjeta...");
    Serial.println("===================================");
}

void loop() {
    std::string tagUid;

    // Encuesta el lector NFC (no bloqueante, timeout corto en el adaptador)
    if (nfcReader.tryReadTag(tagUid)) {
        Serial.print("Etiqueta detectada - UID: ");
        Serial.println(tagUid.c_str());

        // Obtener timestamp UTC real desde el reloj sincronizado con NTP
        std::string recordedAt = TimeProvider::nowIso8601Utc();
        if (recordedAt.empty()) {
            // Reloj perdió sincronización (ej: después de un deep sleep largo)
            Serial.println("[WARN] Reloj no sincronizado; descartando registro.");
            delay(1500);
            return;
        }

        // Generar ULID usando epoch en ms para la parte temporal
        struct tm timeinfo;
        getLocalTime(&timeinfo);
        uint64_t epochMs = (uint64_t)mktime(&timeinfo) * 1000ULL;
        std::string ulid = UlidGenerator::generateUlid(epochMs);

        // Ensamblar registro de dominio
        AttendanceRecord record;
        record.recordId   = ulid;
        record.tagUid     = tagUid;
        record.deviceId   = deviceConfig.deviceId;
        record.recordedAt = recordedAt;

        // Mostrar registro (próximo paso: enviar al backend / buffer offline)
        Serial.println("Registro de Asistencia Ensamblado:");
        Serial.printf("  record_id:   %s\n", record.recordId.c_str());
        Serial.printf("  tag_uid:     %s\n", record.tagUid.c_str());
        Serial.printf("  device_id:   %s\n", record.deviceId.c_str());
        Serial.printf("  recorded_at: %s\n", record.recordedAt.c_str());
        Serial.println("-----------------------------------");

        // Pausa para evitar registros duplicados por dejar la tarjeta apoyada
        delay(1500);
    }
}

#endif // PIO_UNIT_TESTING