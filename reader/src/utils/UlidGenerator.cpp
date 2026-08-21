#include "UlidGenerator.h"
#include <esp_random.h>
#include <sys/time.h>

const char UlidGenerator::ENCODING_CHARS[33] = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";

std::string UlidGenerator::generateUlid(uint64_t timestampMs) {
    uint8_t bytes[16];

    // Timestamp (48 bits = 6 bytes), Big Endian
    bytes[0] = (timestampMs >> 40) & 0xFF;
    bytes[1] = (timestampMs >> 32) & 0xFF;
    bytes[2] = (timestampMs >> 24) & 0xFF;
    bytes[3] = (timestampMs >> 16) & 0xFF;
    bytes[4] = (timestampMs >> 8) & 0xFF;
    bytes[5] = timestampMs & 0xFF;

    // Randomness (80 bits = 10 bytes)
    for (int i = 6; i < 16; i++) {
        bytes[i] = esp_random() & 0xFF;
    }

    char output[27];
    output[26] = '\0';
    encodeCrockfordBase32(bytes, 16, output);

    return std::string(output);
}

void UlidGenerator::encodeCrockfordBase32(uint8_t* bytes, size_t len, char* output) {
    // ULID encoding rules:
    // 16 bytes = 128 bits. Every 5 bits is mapped to a character in ENCODING_CHARS.
    // 128 / 5 = 25.6 -> 26 characters.
    
    output[0] = ENCODING_CHARS[(bytes[0] & 224) >> 5];
    output[1] = ENCODING_CHARS[(bytes[0] & 31)];
    output[2] = ENCODING_CHARS[(bytes[1] & 248) >> 3];
    output[3] = ENCODING_CHARS[((bytes[1] & 7) << 2) | ((bytes[2] & 192) >> 6)];
    output[4] = ENCODING_CHARS[(bytes[2] & 62) >> 1];
    output[5] = ENCODING_CHARS[((bytes[2] & 1) << 4) | ((bytes[3] & 240) >> 4)];
    output[6] = ENCODING_CHARS[((bytes[3] & 15) << 1) | ((bytes[4] & 128) >> 7)];
    output[7] = ENCODING_CHARS[(bytes[4] & 124) >> 2];
    output[8] = ENCODING_CHARS[((bytes[4] & 3) << 3) | ((bytes[5] & 224) >> 5)];
    output[9] = ENCODING_CHARS[(bytes[5] & 31)];
    
    output[10] = ENCODING_CHARS[(bytes[6] & 248) >> 3];
    output[11] = ENCODING_CHARS[((bytes[6] & 7) << 2) | ((bytes[7] & 192) >> 6)];
    output[12] = ENCODING_CHARS[(bytes[7] & 62) >> 1];
    output[13] = ENCODING_CHARS[((bytes[7] & 1) << 4) | ((bytes[8] & 240) >> 4)];
    output[14] = ENCODING_CHARS[((bytes[8] & 15) << 1) | ((bytes[9] & 128) >> 7)];
    output[15] = ENCODING_CHARS[(bytes[9] & 124) >> 2];
    
    output[16] = ENCODING_CHARS[((bytes[9] & 3) << 3) | ((bytes[10] & 224) >> 5)];
    output[17] = ENCODING_CHARS[(bytes[10] & 31)];
    output[18] = ENCODING_CHARS[(bytes[11] & 248) >> 3];
    output[19] = ENCODING_CHARS[((bytes[11] & 7) << 2) | ((bytes[12] & 192) >> 6)];
    output[20] = ENCODING_CHARS[(bytes[12] & 62) >> 1];
    output[21] = ENCODING_CHARS[((bytes[12] & 1) << 4) | ((bytes[13] & 240) >> 4)];
    
    output[22] = ENCODING_CHARS[((bytes[13] & 15) << 1) | ((bytes[14] & 128) >> 7)];
    output[23] = ENCODING_CHARS[(bytes[14] & 124) >> 2];
    output[24] = ENCODING_CHARS[((bytes[14] & 3) << 3) | ((bytes[15] & 224) >> 5)];
    output[25] = ENCODING_CHARS[(bytes[15] & 31)];
}
