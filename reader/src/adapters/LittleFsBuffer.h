#ifndef LITTLEFSBUFFER_H
#define LITTLEFSBUFFER_H

#include "OfflineBuffer.h"

/**
 * @brief Implementación concreta de OfflineBuffer usando LittleFS.
 *
 * Almacena cada AttendanceRecord como un archivo JSON individual en el
 * directorio /pending/ de la partición flash del ESP32.
 *
 * Estrategia de almacenamiento:
 * - Un archivo por registro: /pending/{recordId}.json
 * - getNextRecord() retorna el primer archivo encontrado en el directorio
 *   (el orden no está garantizado, pero todos se enviarán eventualmente).
 * - deleteRecord() elimina el archivo tras sincronización exitosa.
 *
 * LittleFS soporta ~1.5 MB en la partición por defecto del ESP32,
 * suficiente para miles de registros (~200 bytes c/u).
 */
class LittleFsBuffer : public OfflineBuffer {
public:
    /**
     * @brief Monta el filesystem LittleFS. Formatea si es la primera vez.
     * Debe llamarse una vez en setup().
     * @return true si el montaje fue exitoso.
     */
    bool begin();

    bool saveRecord(const AttendanceRecord& record) override;
    bool hasPendingRecords() override;
    bool getNextRecord(AttendanceRecord& outRecord) override;
    bool deleteRecord(const std::string& recordId) override;

    /**
     * @brief Retorna la cantidad de registros pendientes (para diagnóstico).
     */
    uint16_t pendingCount();

private:
    static constexpr char PENDING_DIR[] = "/pending";

    /**
     * @brief Construye la ruta completa del archivo para un recordId.
     */
    std::string filePath(const std::string& recordId) const;
};

#endif // LITTLEFSBUFFER_H
