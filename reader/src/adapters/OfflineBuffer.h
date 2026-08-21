#ifndef OFFLINEBUFFER_H
#define OFFLINEBUFFER_H

#include "../domain/AttendanceRecord.h"
#include <string>

class OfflineBuffer {
public:
    virtual ~OfflineBuffer() = default;

    /**
     * Guarda un registro en el almacenamiento persistente.
     * @param record El registro de asistencia.
     * @return true si se guardó correctamente.
     */
    virtual bool saveRecord(const AttendanceRecord& record) = 0;

    /**
     * @return true si hay al menos un registro sin sincronizar.
     */
    virtual bool hasPendingRecords() = 0;

    /**
     * Recupera el registro más antiguo pendiente de enviar.
     * @param outRecord Donde se guardará el registro leído.
     * @return true si se leyó correctamente.
     */
    virtual bool getNextRecord(AttendanceRecord& outRecord) = 0;

    /**
     * Elimina un registro del almacenamiento por su ID.
     * Usado después de que un registro fue enviado exitosamente al backend.
     * @param recordId El identificador único del registro.
     * @return true si se eliminó correctamente.
     */
    virtual bool deleteRecord(const std::string& recordId) = 0;
};

#endif // OFFLINEBUFFER_H
