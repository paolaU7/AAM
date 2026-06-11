# AAM — Guía de Instalación del Entorno

## ⚠️ Tareas que requieren interacción manual (priorizadas 🔴 Alta)

---

### **1.1 ✋ Instalar Python 3.10+**

**Windows:**
1. Descargar desde https://www.python.org/downloads/
2. Ejecutar instalador
3. ✅ **MARCAR: "Add Python to PATH"** (importante)
4. Click en "Install Now"

**Verificar instalación:**
```bash
python --version
```

**Debe mostrar:** `Python 3.10.0` o superior

---

### **1.2 ✋ Instalar PostgreSQL**

**Opción A: Con Docker (recomendado, más fácil)**

1. Descargar Docker Desktop: https://www.docker.com/products/docker-desktop/
2. Instalar y ejecutar
3. Ir a `backend/` y ejecutar:
   ```bash
   docker-compose up -d
   ```
4. ✅ Listo. PostgreSQL corre en `localhost:5432`

**Verificar conexión:**
```bash
# Instalar cliente (opcional):
# Windows: https://www.postgresql.org/download/windows/
# Luego:
psql -U aam_user -d aam_dev -h localhost
# Password: aam_password
```

**Opción B: PostgreSQL nativo (si no tienes Docker)**

1. Descargar instalador: https://www.postgresql.org/download/
2. Ejecutar instalador
3. Anotar puerto: por defecto 5432
4. Crear usuario `aam_user` con contraseña `aam_password`
5. Crear BD vacía `aam_dev`
6. En `backend/.env`, verificar:
   ```
   DATABASE_URL=postgresql://aam_user:aam_password@localhost:5432/aam_dev
   ```

---

### **1.5 ✋ Instalar Arduino IDE + ESP32 Toolchain**

**Opción A: VS Code + PlatformIO (recomendado)**

1. Abrir VS Code
2. Extensions (Ctrl+Shift+X) → Buscar "PlatformIO IDE" → Instalar
3. Reiniciar VS Code
4. En carpeta `reader/`, hacer clic en "PlatformIO: Build"
5. ✅ Se descarga automáticamente el toolchain ESP32

**Opción B: Arduino IDE**

1. Descargar: https://www.arduino.cc/en/software
2. Abrir → Preferences
3. En "Additional Boards Manager URLs", agregar:
   ```
   https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
   ```
4. Tools → Board Manager → Buscar "esp32" → Instalar "ESP32 by Espressif Systems"
5. ✅ Listo

---

## ✅ Tareas completadas automáticamente

| Tarea | Estado | Ubicación |
|---|---|---|
| **1.3** Crear estructura carpetas | ✅ | `backend/`, `reader/src`, `reader/lib`, `reader/include` |
| **1.4** Inicializar FastAPI | ✅ | `backend/main.py`, `backend/app/`, `backend/requirements.txt` |
| **1.6** Crear carpeta reader | ✅ | `reader/platformio.ini`, `reader/src/main.cpp`, headers |
| **1.7** Actualizar pubspec.yaml | ✅ | Agregadas: provider, http, dio, floor, qr_flutter, file_picker, excel |

---

## 🚀 Siguientes pasos después de la instalación manual

1. **Verificar Python:**
   ```bash
   python --version
   ```

2. **Crear virtual environment y instalar dependencias backend:**
   ```bash
   cd backend
   python -m venv venv
   # Windows: venv\Scripts\activate
   # macOS/Linux: source venv/bin/activate
   pip install -r requirements.txt
   ```

3. **Levantar PostgreSQL (Docker):**
   ```bash
   docker-compose up -d
   ```

4. **Copiar archivo de config:**
   ```bash
   cp .env.example .env
   ```

5. **Ejecutar servidor FastAPI:**
   ```bash
   python main.py
   ```
   Acceder a: http://localhost:8000/docs

6. **Para firmware ESP32:**
   - Conectar ESP32 por USB
   - Abrir `reader/` en VS Code con PlatformIO
   - Ejecutar "Build" y "Upload"

---

## 📚 Documentación

- [Backend README](./backend/README.md) — Detalles FastAPI, estructura, roadmap
- [Reader README](./reader/README.md) — Detalles ESP32, conexión PN532, roadmap
- [Visión del Proyecto](./docs/vision.md) — Contexto completo, features, stakeholders

---

## ❓ Soporte

Si tenés errores durante la instalación, revisa:

1. **Python no encontrado:** Reinstalar con "Add Python to PATH" marcado
2. **PostgreSQL no conecta:** Verificar que corre (`docker ps` o Services en Windows)
3. **PlatformIO no descarga ESP32:** Reiniciar VS Code, hacer clic en "PlatformIO Home"
4. **Puerto 5432 en uso:** Cambiar puerto en `docker-compose.yml` (línea `5432:5432` → `5433:5432`)

---

**Fecha de creación:** 2026-06-11  
**Fase:** 2 — Inicialización del Entorno  
**Responsable:** Equipo AAM
