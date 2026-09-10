#include "LittleFsBuffer.h"

#include <Arduino.h>
#include <LittleFS.h>
#include <ArduinoJson.h>

// Definición out-of-line requerida por C++14 (GCC 8.4 Xtensa)
constexpr char LittleFsBuffer::PENDING_DIR[];

// ---------------------------------------------------------------------------

std::string LittleFsBuffer::filePath(const std::string& recordId) const {
    return std::string(PENDING_DIR) + "/" + recordId + ".json";
}

// ---------------------------------------------------------------------------

bool LittleFsBuffer::begin() {
    // formatOnFail = true: si la partición no tiene filesystem, la formatea
    // automáticamente. Esto ocurre solo la primera vez que se usa el ESP32.
    if (!LittleFS.begin(true)) {
        Serial.println("[Buffer] Error crítico al montar LittleFS.");
        return false;
    }

    // Crear directorio de pendientes si no existe
    if (!LittleFS.exists(PENDING_DIR)) {
        LittleFS.mkdir(PENDING_DIR);
    }

    Serial.printf("[Buffer] LittleFS montado. Pendientes: %d\n", pendingCount());
    return true;
}

// ---------------------------------------------------------------------------

bool LittleFsBuffer::saveRecord(const AttendanceRecord& record) {
    std::string path = filePath(record.recordId);

    File file = LittleFS.open(path.c_str(), "w");
    if (!file) {
        Serial.printf("[Buffer] Error al crear archivo: %s\n", path.c_str());
        return false;
    }

    // Serializar con ArduinoJson (mismo formato que el POST al backend)
    JsonDocument doc;
    doc["record_id"]   = record.recordId;
    doc["tag_uid"]     = record.tagUid;
    doc["device_id"]   = record.deviceId;
    doc["recorded_at"] = record.recordedAt;

    size_t bytesWritten = serializeJson(doc, file);
    file.close();

    if (bytesWritten == 0) {
        Serial.printf("[Buffer] Error al escribir JSON: %s\n", path.c_str());
        LittleFS.remove(path.c_str());
        return false;
    }

    Serial.printf("[Buffer] Registro guardado: %s (%d bytes)\n",
                  record.recordId.c_str(), bytesWritten);
    return true;
}

// ---------------------------------------------------------------------------

bool LittleFsBuffer::hasPendingRecords() {
    File dir = LittleFS.open(PENDING_DIR);
    if (!dir || !dir.isDirectory()) {
        return false;
    }

    File entry = dir.openNextFile();
    bool hasPending = (entry) ? true : false;
    entry.close();
    dir.close();
    return hasPending;
}

// ---------------------------------------------------------------------------

bool LittleFsBuffer::getNextRecord(AttendanceRecord& outRecord) {
    File dir = LittleFS.open(PENDING_DIR);
    if (!dir || !dir.isDirectory()) {
        return false;
    }

    File entry = dir.openNextFile();
    if (!entry) {
        dir.close();
        return false;
    }

    // Deserializar el JSON del archivo
    JsonDocument doc;
    DeserializationError error = deserializeJson(doc, entry);
    entry.close();
    dir.close();

    if (error) {
        Serial.printf("[Buffer] Error al parsear JSON: %s\n",
                      error.c_str());
        return false;
    }

    outRecord.recordId   = doc["record_id"].as<std::string>();
    outRecord.tagUid     = doc["tag_uid"].as<std::string>();
    outRecord.deviceId   = doc["device_id"].as<std::string>();
    outRecord.recordedAt = doc["recorded_at"].as<std::string>();

    return true;
}

// ---------------------------------------------------------------------------

bool LittleFsBuffer::deleteRecord(const std::string& recordId) {
    std::string path = filePath(recordId);

    if (!LittleFS.exists(path.c_str())) {
        // Ya no existe — considerarlo éxito (idempotente)
        return true;
    }

    if (LittleFS.remove(path.c_str())) {
        Serial.printf("[Buffer] Registro eliminado: %s\n", recordId.c_str());
        return true;
    }

    Serial.printf("[Buffer] Error al eliminar: %s\n", path.c_str());
    return false;
}

// ---------------------------------------------------------------------------

uint16_t LittleFsBuffer::pendingCount() {
    File dir = LittleFS.open(PENDING_DIR);
    if (!dir || !dir.isDirectory()) {
        return 0;
    }

    uint16_t count = 0;
    File entry = dir.openNextFile();
    while (entry) {
        count++;
        entry = dir.openNextFile();
    }
    dir.close();
    return count;
}
