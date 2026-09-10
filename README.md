# AAM (Automatic Attendance Manager)

Sistema de asistencia por NFC diseñado bajo Arquitectura Hexagonal y principios SOLID. 
El proyecto se compone de tres piezas principales: Lector NFC (ESP32), Backend (Go) y Panel Directivo (Flutter).

## Arquitectura y Componentes

### 1. Lector NFC (Firmware ESP32)
Ubicación: [`reader/`](reader/)

Firmware para ESP32 NodeMCU-32S encargado de leer tags NFC (PN532 vía I2C) y reportar la asistencia.

- **Stack**: C++ / Arduino Framework (PlatformIO).
- **Características**:
  - Portal cautivo (`WiFiManager`) para configuración de conectividad.
  - Generación de identificadores únicos (ULID) nativa.
  - Sincronización estricta de tiempo UTC vía NTP.
  - Almacenamiento offline con LittleFS: retiene registros ante fallas de red y los sincroniza automáticamente al reconectar.
  - Comunicación HTTP con backoff exponencial y soporte de idempotencia (códigos 201/409).

### 2. Backend (API REST)
Ubicación: [`backend/`](backend/)

- **Stack**: Go (`chi` para ruteo, `pgx` para PostgreSQL, `goose` para migraciones).
- **Características**:
  - Arquitectura Hexagonal estricta (`cmd`, `internal/domain`, `internal/infrastructure`, `internal/app`).
  - Endpoints de ingesta de datos para hardware con autenticación Bearer (`ApiKey`).
  - Resolución de conflictos basada en el identificador único de cada registro (ULID) enviado por el hardware.
  - API REST para el panel directivo.

Para levantar el entorno:
```bash
cd backend
go mod tidy
go run ./cmd/api migrate up
go run ./cmd/api
```

### 3. Panel Directivo (Frontend)
Ubicación: [`frontend/`](frontend/)

- **Stack**: Dart / Flutter.
- **Características**:
  - Separación de capas (`domain`, `infrastructure`, `presentation`) manteniendo la lógica agnóstica del framework.
  - Interfaz para visualización de asistencia, gestión de alumnos y configuración de dispositivos.
  - Conversión de zonas horarias (de UTC a local) centralizada en la capa de presentación.

Para levantar el entorno:
```bash
cd frontend
flutter pub get
flutter run -d chrome
```

## Reglas de Arquitectura

Estas restricciones aplican a los tres componentes del sistema (C++, Go y Dart):

| Capa             | Dependencias permitidas         | Dependencias prohibidas                     |
|------------------|---------------------------------|---------------------------------------------|
| `domain`         | Código nativo del lenguaje      | Infraestructura, UI, frameworks externos    |
| `infrastructure` | `domain`, librerías externas    | `presentation`                              |
| `presentation`   | `domain`, `infrastructure`      | Lógica de negocio, acceso directo a I/O     |

## Scripts de Utilidad

Se incluye `aam.sh` en la raíz para facilitar operaciones comunes:

```bash
chmod +x aam.sh
./aam.sh build          # Compila backend, frontend y firmware
./aam.sh push-main      # Add, commit y push a la rama main
./aam.sh push-branch    # Crea rama, commitea y pushea
./aam.sh help           # Muestra todos los comandos
```
