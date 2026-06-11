/*
 * LittleFS Buffer Module — Offline Storage
 */

#ifndef LITTLEFS_BUFFER_H
#define LITTLEFS_BUFFER_H

#include <vector>
#include <string>

struct BufferRecord {
    std::string ulid;
    uint64_t timestamp;
    bool synced;
};

class LittleFSBuffer {
public:
    LittleFSBuffer();
    bool begin();
    bool save(const BufferRecord& record);
    std::vector<BufferRecord> readUnsyncedRecords();
    bool markSynced(const std::string& ulid);
    void end();
};

#endif
