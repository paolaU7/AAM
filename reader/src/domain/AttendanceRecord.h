#ifndef ATTENDANCERECORD_H
#define ATTENDANCERECORD_H

#include <string>

struct AttendanceRecord {
    std::string recordId;
    std::string tagUid;
    std::string deviceId;
    std::string recordedAt;
};

#endif // ATTENDANCERECORD_H
