#ifndef HTTPSYNCCLIENT_H
#define HTTPSYNCCLIENT_H

#include "../domain/AttendanceRecord.h"
#include "../config/DeviceConfig.h"

class HttpSyncClient {
public:
    virtual ~HttpSyncClient() = default;

    /**
     * Sincroniza un registro de asistencia con el backend.
     * Debe enviar el POST Request incluyendo los headers de autorización.
     * @param record El registro a enviar.
     * @param config Configuración del dispositivo (para endpoint y apiKey).
     * @return true si el backend retorna 201 (Created) o 409 (Conflict/Ya existe).
     */
    virtual bool syncRecord(const AttendanceRecord& record, const DeviceConfig& config) = 0;
};

#endif // HTTPSYNCCLIENT_H
