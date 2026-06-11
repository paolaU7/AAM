/*
 * AAM Reader Firmware
 * ESP32 + PN532 NFC Reader
 * 
 * Entry point for the firmware.
 */

#include <Arduino.h>

void setup() {
    Serial.begin(115200);
    delay(1000);
    
    Serial.println("\n\n");
    Serial.println("==================================");
    Serial.println("AAM Reader — ESP32 + PN532");
    Serial.println("==================================");
    Serial.println("Starting up...");
}

void loop() {
    delay(1000);
    // TODO: Implement NFC reading, buffer sync
    Serial.println("Running...");
}
