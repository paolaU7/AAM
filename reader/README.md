# AAM Reader — ESP32 + PN532 NFC Firmware

## Setup Inicial

### 1. Instalar PlatformIO

**Opción A: VS Code Extension (recomendado)**

1. Abrir VS Code
2. Ir a Extensions (Ctrl+Shift+X)
3. Buscar "PlatformIO IDE"
4. Instalar

**Opción B: Arduino IDE**

1. Descargar Arduino IDE desde https://www.arduino.cc/en/software
2. En Boards Manager, instalar "ESP32 by Espressif Systems"

### 2. Hardware requerido

- ✅ ESP32 (30 pines o compatible)
- ✅ ELECHOUSE PN532 NFC V3 (ya adquirido)
- ✅ Pulseras NTAG213/215 (ya adquiridas)
- Cable USB mini-B o USB-C
- Cables DuPont para conexión I2C

### 3. Conexión PN532 ↔ ESP32 (I2C)

| PN532 Pin | ESP32 Pin | Cable |
|---|---|---|
| GND | GND | Negro |
| VCC | 5V (o 3.3V) | Rojo |
| SCL | GPIO 22 | Amarillo |
| SDA | GPIO 21 | Verde |

**Nota:** PN532 V3 soporta I2C y SPI. Estamos usando I2C (más simple).

### 4. Compilar y subir

```bash
cd reader

# Con PlatformIO (recomendado)
pio run -e esp32 -t upload

# O con Arduino IDE:
# Sketch → Upload
```

Monitor serial:
```bash
pio device monitor -b 115200
```

---

## Estructura

```
reader/
├── platformio.ini                   ← Configuración PlatformIO
├── README.md                        ← Este archivo
│
├── src/
│   └── main.cpp                     ← Entry point
│
├── lib/
│   ├── nfc_reader.cpp              ← PN532 communication
│   ├── littlefs_buffer.cpp         ← Offline storage
│   ├── http_client.cpp             ← Backend sync
│   └── ulid_generator.cpp          ← ULID generation
│
└── include/
    ├── config.h                     ← WiFi, API, pins
    ├── nfc_reader.h
    ├── littlefs_buffer.h
    ├── http_client.h
    └── ulid_generator.h
```

---

## Configuración

Editar `include/config.h`:

```cpp
#define WIFI_SSID "tu-red"
#define WIFI_PASSWORD "tu-contraseña"
#define API_HOST "192.168.x.x"        // IP del servidor FastAPI
#define API_KEY "device-key-v1-..."   // Clave del dispositivo
```

---

## Funcionamiento

1. **Lectura NFC:** PN532 detecta pulsera NTAG213/215 → obtiene UID
2. **Generación ULID:** ESP32 genera ULID con timestamp local
3. **Envío HTTP:** POST a `{API_HOST}:8000/api/attendance/register` con ULID
4. **Buffer offline:** Si no hay red → guarda en LittleFS
5. **Sincronización automática:** Cada 30s, intenta enviar registros no sincronizados
6. **Indicadores:** LED WiFi, LED sync, buzzer en caso de error

---

## Roadmap (Fase 4)

- [x] Estructura inicial + headers
- [ ] Conexión PN532 I2C (Etapa 3, Tarea 3.1)
- [ ] Generación ULID (Etapa 3, Tarea 3.2)
- [ ] Buffer LittleFS (Etapa 3, Tarea 3.3)
- [ ] Cliente HTTP (Etapa 3, Tarea 3.4)
- [ ] Hilo de sincronización (Etapa 3, Tarea 3.5)
- [ ] Almacenamiento API Key (Etapa 3, Tarea 3.6)
- [ ] Deduplicación local (Etapa 3, Tarea 3.7)
- [ ] Indicadores visuales (Etapa 3, Tarea 3.8)
- [ ] Testing (Etapa 3, Tarea 3.9)

---

## Troubleshooting

**El ESP32 no se detecta:**
- Instalar driver CH340 desde https://www.wemos.cc/en/latest/ch340_driver.html
- Reiniciar el IDE

**PN532 no responde:**
- Verificar conexión I2C (SCL/SDA en pines correctos)
- Verificar voltaje: PN532 V3 puede necesitar regulador si usa 5V

**Buffer LittleFS lleno:**
- Configurar `LITTLEFS_BUFFER_SIZE` en `config.h`
- Aumentar frecuencia de sincronización

---

## Documentación

- Visión del proyecto: `../docs/vision.md`
- PN532 Datasheet: https://www.nxp.com/docs/en/data-sheet/NXP_PN532.pdf
- ESP32 API: https://docs.espressif.com/projects/esp-idf/en/latest/
