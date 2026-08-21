#ifndef ULIDGENERATOR_H
#define ULIDGENERATOR_H

#include <string>
#include <stdint.h>

class UlidGenerator {
public:
    /**
     * Generates a random ULID string based on the given timestamp.
     * Uses esp_random() internally for the randomness part.
     */
    static std::string generateUlid(uint64_t timestampMs);

private:
    static const char ENCODING_CHARS[33];
    static void encodeCrockfordBase32(uint8_t* bytes, size_t len, char* output);
};

#endif // ULIDGENERATOR_H
