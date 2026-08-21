#include <Arduino.h>
#include <unity.h>

#include "../src/domain/AttendanceRecord.h"
#include "../src/utils/UlidGenerator.h"

// Se ejecuta antes de cada prueba
void setUp(void) {
}

// Se ejecuta después de cada prueba
void tearDown(void) {
}

void test_attendance_record_struct(void) {
    AttendanceRecord record;
    record.recordId = "01J5X3A";
    record.tagUid = "04A3B2C1";
    record.deviceId = "TEST-DEVICE";
    record.recordedAt = "2026-08-20T12:00:00Z";

    TEST_ASSERT_EQUAL_STRING("01J5X3A", record.recordId.c_str());
    TEST_ASSERT_EQUAL_STRING("04A3B2C1", record.tagUid.c_str());
    TEST_ASSERT_EQUAL_STRING("TEST-DEVICE", record.deviceId.c_str());
}

void test_ulid_generator_length(void) {
    uint64_t timestamp = 1691308992000; // Timestamp arbitrario
    std::string ulid = UlidGenerator::generateUlid(timestamp);
    
    // Un ULID estándar siempre tiene exactamente 26 caracteres de longitud
    TEST_ASSERT_EQUAL_INT(26, ulid.length());
}

void test_ulid_generator_randomness(void) {
    uint64_t timestamp = 1691308992000;
    
    std::string ulid1 = UlidGenerator::generateUlid(timestamp);
    std::string ulid2 = UlidGenerator::generateUlid(timestamp);
    
    // Incluso con el mismo timestamp, los 80 bits de entropía deben asegurar que sean distintos
    TEST_ASSERT_NOT_EQUAL(0, ulid1.compare(ulid2));
}

void setup() {
    // Pausa para estabilizar la conexión serial antes de que Unity empiece a emitir los resultados
    delay(2000); 
    
    UNITY_BEGIN();
    
    RUN_TEST(test_attendance_record_struct);
    RUN_TEST(test_ulid_generator_length);
    RUN_TEST(test_ulid_generator_randomness);
    
    UNITY_END();
}

void loop() {
    delay(100);
}
