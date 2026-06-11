/*
 * AAM Reader Configuration
 */

#ifndef CONFIG_H
#define CONFIG_H

// WiFi
#define WIFI_SSID "your-ssid"
#define WIFI_PASSWORD "your-password"

// Backend API
#define API_HOST "192.168.1.100"
#define API_PORT 8000
#define API_KEY "device-key-v1-replace-me"

// PN532 I2C Address
#define PN532_I2C_ADDRESS 0x24

// Buffer settings
#define LITTLEFS_BUFFER_SIZE 3000  // ~3MB

#endif
