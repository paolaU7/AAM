#ifndef ESPHTTPSYNCCLIENT_H
#define ESPHTTPSYNCCLIENT_H

#include "HttpSyncClient.h"

/**
 * @brief Implementación concreta de HttpSyncClient para ESP32.
 *
 * Usa la librería HTTPClient del framework Arduino-ESP32 para enviar
 * registros de asistencia al backend via POST.
 *
 * Comportamiento:
 * - Serializa el AttendanceRecord a JSON con ArduinoJson.
 * - Envía POST con header Authorization: Bearer {apiKey}.
 * - Retorna true si el backend responde 201 (Created) o 409 (Conflict).
 * - Implementa reintentos con backoff exponencial ante errores de red.
 */
class EspHttpSyncClient : public HttpSyncClient {
public:
    /**
     * @param maxRetries Número máximo de reintentos ante error de red (default: 3).
     */
    explicit EspHttpSyncClient(uint8_t maxRetries = 3);

    bool syncRecord(const AttendanceRecord& record, const DeviceConfig& config) override;

private:
    uint8_t _maxRetries;

    /**
     * @brief Ejecuta un único intento de POST.
     * @return HTTP status code, o valor negativo si hubo error de conexión.
     */
    int postOnce(const AttendanceRecord& record, const DeviceConfig& config);
};

#endif // ESPHTTPSYNCCLIENT_H
