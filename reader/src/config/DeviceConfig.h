#ifndef DEVICECONFIG_H
#define DEVICECONFIG_H

#include <string>

/**
 * @brief Configuración estática del dispositivo.
 *
 * Las credenciales WiFi NO se almacenan aquí: WiFiManager las persiste
 * internamente en el NVS (Non-Volatile Storage) del ESP32.
 */
struct DeviceConfig {
    std::string deviceId;   ///< Identificador único del lector (ej: "ESP32-AULA-12")
    std::string apiKey;     ///< Clave de autorización para el backend
    std::string endpoint;   ///< URL del endpoint de registro de asistencia
};

#endif // DEVICECONFIG_H
