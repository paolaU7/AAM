#include "EspHttpSyncClient.h"

#include <Arduino.h>
#include <HTTPClient.h>
#include <WiFi.h>
#include <ArduinoJson.h>

// ---------------------------------------------------------------------------

EspHttpSyncClient::EspHttpSyncClient(uint8_t maxRetries)
    : _maxRetries(maxRetries) {}

// ---------------------------------------------------------------------------

int EspHttpSyncClient::postOnce(const AttendanceRecord& record,
                                const DeviceConfig& config) {
    HTTPClient http;

    if (!http.begin(config.endpoint.c_str())) {
        Serial.println("[HTTP] Error al inicializar conexión.");
        return -1;
    }

    // Headers
    http.addHeader("Content-Type", "application/json");

    std::string authHeader = "Bearer " + config.apiKey;
    http.addHeader("Authorization", authHeader.c_str());

    // Serializar el registro a JSON con ArduinoJson v7
    JsonDocument doc;
    doc["record_id"]   = record.recordId;
    doc["tag_uid"]     = record.tagUid;
    doc["device_id"]   = record.deviceId;
    doc["recorded_at"] = record.recordedAt;

    std::string jsonPayload;
    serializeJson(doc, jsonPayload);

    // Enviar POST
    int httpCode = http.POST(jsonPayload.c_str());

    // Log del response para debugging
    if (httpCode > 0) {
        Serial.printf("[HTTP] POST → %d\n", httpCode);
        if (httpCode != 201 && httpCode != 409) {
            // Loguear body del error para diagnóstico
            String responseBody = http.getString();
            Serial.printf("[HTTP] Body: %s\n", responseBody.c_str());
        }
    } else {
        Serial.printf("[HTTP] Error de conexión: %s\n",
                      http.errorToString(httpCode).c_str());
    }

    http.end();
    return httpCode;
}

// ---------------------------------------------------------------------------

bool EspHttpSyncClient::syncRecord(const AttendanceRecord& record,
                                   const DeviceConfig& config) {
    // Verificar que WiFi esté conectado antes de intentar
    if (WiFi.status() != WL_CONNECTED) {
        Serial.println("[HTTP] Sin conexión WiFi. Abortando sync.");
        return false;
    }

    uint32_t backoffMs = 1000; // Backoff inicial: 1 segundo

    for (uint8_t attempt = 0; attempt <= _maxRetries; ++attempt) {
        if (attempt > 0) {
            Serial.printf("[HTTP] Reintento %d/%d en %lu ms...\n",
                          attempt, _maxRetries, backoffMs);
            delay(backoffMs);
            backoffMs *= 2; // Backoff exponencial: 1s → 2s → 4s
        }

        int httpCode = postOnce(record, config);

        // 201 Created → registro nuevo aceptado
        // 409 Conflict → registro ya existía (idempotente, se considera éxito)
        if (httpCode == 201 || httpCode == 409) {
            if (httpCode == 409) {
                Serial.println("[HTTP] Registro ya existente (409). OK.");
            }
            return true;
        }

        // Errores de cliente (4xx excepto 409) → no tiene sentido reintentar
        if (httpCode >= 400 && httpCode < 500) {
            Serial.printf("[HTTP] Error de cliente %d. No reintentable.\n", httpCode);
            return false;
        }

        // Errores de servidor (5xx) o de red (negativo) → reintentar
    }

    Serial.println("[HTTP] Agotados todos los reintentos.");
    return false;
}
