#ifndef DEVICECONFIG_H
#define DEVICECONFIG_H

#include <string>

struct DeviceConfig {
    std::string deviceId;
    std::string apiKey;
    std::string endpoint;
    std::string wifiSsid;
    std::string wifiPassword;
};

#endif // DEVICECONFIG_H
