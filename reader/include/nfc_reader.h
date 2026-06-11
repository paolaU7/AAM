/*
 * NFC Reader Module — PN532 Communication
 */

#ifndef NFC_READER_H
#define NFC_READER_H

#include <stdint.h>

class NFCReader {
public:
    NFCReader();
    bool begin();
    bool readUID(uint8_t* uid, uint8_t* uidLength);
    void end();
};

#endif
