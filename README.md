# AAM — Panel Directivo (Arquitectura Hexagonal)

## Estructura completa

```
lib/
├── main.dart                                    ← Entry point, MaterialApp
│
├── domain/                                      ← NÚCLEO — cero dependencias externas
│   ├── entities/
│   │   ├── alumno.dart                          ← Alumno, EstadoRegularidad
│   │   ├── registro_asistencia.dart             ← RegistroAsistencia, MetodoIngreso, EstadoAsistencia
│   │   ├── usuario.dart                         ← Usuario, RolUsuario, generarUsername()
│   │   └── curso.dart                           ← Curso, ResumenAsistencia
│   ├── repositories/                            ← Puertos (interfaces abstractas)
│   │   ├── alumno_repository.dart
│   │   ├── asistencia_repository.dart
│   │   ├── curso_repository.dart
│   │   └── usuario_repository.dart
│   └── usecases/                                ← Lógica de negocio
│       ├── get_resumen_dashboard.dart
│       ├── get_alumnos.dart                     ← GetAlumnos, GetAlumnosEnRiesgo
│       ├── get_asistencia_diaria.dart           ← GetAsistenciaDiaria, RegistrarIngresoManual, RegistrarRetiro
│       └── crear_usuario.dart                   ← CrearUsuario + validación de dominio
│
├── infrastructure/                              ← ADAPTADORES — implementan los puertos
│   ├── datasources/
│   │   └── mock_datasource.dart                 ← Datos hardcodeados (swap por ApiDatasource)
│   └── repositories/
│       ├── alumno_repository_impl.dart
│       ├── asistencia_repository_impl.dart
│       ├── curso_repository_impl.dart
│       └── usuario_repository_impl.dart
│
└── presentation/                                ← UI — consume use cases, ignora infra
    ├── widgets/
    │   └── aam_design_system.dart               ← AAMColors, AAMButton, AAMBadge, AAMTopbar, etc.
    ├── shell/
    │   └── app_shell.dart                       ← Sidebar + navegación principal
    └── screens/
        ├── dashboard_screen.dart
        ├── alumnos_screen.dart
        ├── asistencia_screen.dart
        ├── horarios_screen.dart
        ├── usuarios_screen.dart
        └── reportes_screen.dart
```

---

## Setup

```bash
# 1. Copiar toda la estructura a lib/
# 2. Agregar dependencia
flutter pub add google_fonts
flutter pub get

# 3. Correr
flutter run -d chrome
```

---

## Backend (Go)

El backend vive en [`backend/`](backend/) y está escrito en **Go** con
arquitectura hexagonal (`chi` + `pgx` + `goose`). Reemplazó a la versión
anterior en Python (FastAPI + SQLAlchemy) conservando el mismo dominio y **los
mismos endpoints**, así que `frontend/lib/infrastructure/datasources/api_datasource.dart`
(que apunta a `http://localhost:8000`) no necesita cambios.

```bash
cd backend
go mod tidy
go run ./cmd/api migrate up   # esquema (idempotente)
go run ./cmd/api              # servidor en http://localhost:8000
```

Ver [`backend/README.md`](backend/README.md) para el detalle de capas, endpoints
nuevos (login de panel, endpoints del lector ESP32 con API Key, sync del buffer
offline) y el punto de extensión de autenticación secundaria.

---

## Reglas de arquitectura

| Capa           | Puede importar       | No puede importar          |
|----------------|----------------------|----------------------------|
| `domain`       | Solo Dart puro       | flutter, http, infra, pres |
| `infrastructure` | `domain`           | `presentation`             |
| `presentation` | `domain`, `infra`   | Nada externo a la app      |

---

## Próximos pasos sugeridos

1. Agregar `flutter_riverpod` o `provider` para eliminar la inyección manual en `initState`
2. Crear `ApiDatasource` que consuma el backend FastAPI
3. Agregar `fromJson` / `toJson` a las entidades para parsear respuestas HTTP
4. Agregar autenticación JWT y manejo de sesión


# Darle permisos la primera vez
chmod +x aam.sh

./aam.sh build          # compila backend + frontend + firmware
./aam.sh push-main      # add + commit + push a main
./aam.sh push-branch    # crea rama, commitea y pushea
./aam.sh help           # muestra todos los comandos