#include "TimeProvider.h"

#include <Arduino.h>
#include <time.h>

// ---------------------------------------------------------------------------
// Servidores NTP — pool global + respaldo de Google
// ---------------------------------------------------------------------------
static constexpr char NTP_SERVER_1[] = "pool.ntp.org";
static constexpr char NTP_SERVER_2[] = "time.google.com";

// GMT offset = 0 (siempre UTC). Ajuste de horario de verano = 0.
// La conversión a zona local corresponde al frontend / backend, no al firmware.
static constexpr long  GMT_OFFSET_SEC  = 0;
static constexpr int   DAYLIGHT_OFFSET = 0;

// Estado interno: indica si ya se obtuvo una sincronización válida.
static bool _synced = false;

// ---------------------------------------------------------------------------

bool TimeProvider::syncNtp(uint32_t timeoutMs) {
    configTime(GMT_OFFSET_SEC, DAYLIGHT_OFFSET, NTP_SERVER_1, NTP_SERVER_2);

    Serial.print("[TimeProvider] Esperando sincronización NTP");

    const uint32_t start = millis();
    struct tm timeinfo;

    while (millis() - start < timeoutMs) {
        if (getLocalTime(&timeinfo) && timeinfo.tm_year > (2020 - 1900)) {
            _synced = true;
            Serial.println(" OK");
            return true;
        }
        Serial.print(".");
        delay(500);
    }

    Serial.println(" TIMEOUT");
    _synced = false;
    return false;
}

std::string TimeProvider::nowIso8601Utc() {
    if (!_synced) {
        return "";
    }

    struct tm timeinfo;
    if (!getLocalTime(&timeinfo)) {
        return "";
    }

    // Formato: "2026-09-10T16:05:23Z"  (28 chars + null terminator)
    char buf[32];
    snprintf(buf, sizeof(buf),
             "%04d-%02d-%02dT%02d:%02d:%02dZ",
             timeinfo.tm_year + 1900,
             timeinfo.tm_mon  + 1,
             timeinfo.tm_mday,
             timeinfo.tm_hour,
             timeinfo.tm_min,
             timeinfo.tm_sec);

    return std::string(buf);
}

bool TimeProvider::isSynced() {
    return _synced;
}
