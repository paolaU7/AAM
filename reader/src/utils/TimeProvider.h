#ifndef TIMEPROVIDER_H
#define TIMEPROVIDER_H

#include <string>

/**
 * @brief Proveedor de tiempo sincronizado vía NTP.
 *
 * Responsabilidad única: ofrecer la hora actual en UTC como string ISO 8601.
 * La conversión a zona horaria local es responsabilidad de las capas de
 * presentación (frontend o queries del backend), no del firmware.
 */
class TimeProvider {
public:
    /**
     * @brief Sincroniza el reloj interno del ESP32 con servidores NTP.
     *
     * Debe llamarse una vez en setup(), después de conectarse a WiFi.
     * Bloquea hasta obtener una sincronización válida o agotar el timeout.
     *
     * @param timeoutMs Tiempo máximo de espera en ms (default: 10 000 ms).
     * @return true  si la sincronización fue exitosa.
     * @return false si se agotó el timeout sin obtener hora válida.
     */
    static bool syncNtp(uint32_t timeoutMs = 10000);

    /**
     * @brief Retorna la hora actual en formato ISO 8601 / RFC 3339 (UTC estricto).
     *
     * Ejemplo de retorno: "2026-09-10T16:05:23Z"
     *
     * @return std::string con timestamp UTC, o cadena vacía si el reloj
     *         aún no fue sincronizado.
     */
    static std::string nowIso8601Utc();

    /**
     * @brief Indica si el reloj ya fue sincronizado exitosamente con NTP.
     */
    static bool isSynced();
};

#endif // TIMEPROVIDER_H
