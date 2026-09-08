# AAM — Backend (Go)

Backend de AAM en Go, con **arquitectura hexagonal** (puertos y adaptadores).
Reemplaza al backend anterior en Python (FastAPI + SQLAlchemy) conservando el
mismo dominio, las mismas reglas de negocio y **los mismos endpoints** que
consume el panel Flutter.

## Stack

- **Router:** `chi` (net/http estándar — el dominio no conoce el framework)
- **DB:** PostgreSQL vía `pgx` (SQL escrito a mano; deduplicación por ULID con
  `INSERT ... ON CONFLICT DO NOTHING`)
- **Migraciones:** `goose` (embebidas; tabla `goose_db_version`)
- **ULID:** `oklog/ulid` para validar/parsear los IDs que genera el ESP32
- **Excel:** `excelize` (carga de alumnos por planilla)
- **Auth:** `bcrypt` (compatible con los hashes del backend anterior) + JWT

## Estructura

```
cmd/api/                 punto de entrada + subcomando `migrate`
internal/
  domain/                entidades + puertos (interfaces). Sin imports de infra.
  app/                   casos de uso (orquestación). Solo depende de domain.
  adapter/
    http/                handlers chi + DTOs (compatibles con el Flutter actual)
    postgres/            implementación de los repositorios con pgx
    auth/                bcrypt, JWT, autenticador secundario (QR estático)
  migrate/               migraciones SQL embebidas (goose)
  config/                carga de configuración (.env / entorno)
```

Regla de dependencia: `domain` ⟵ `app` ⟵ `adapter/*` ⟵ `cmd/api`.

## Correr

Requiere **Go 1.23+** y una base PostgreSQL accesible por `DATABASE_URL`
(ver `.env` / `.env.example`).

```bash
# dependencias
go mod tidy

# migraciones (idempotentes: no-op sobre una DB que ya tiene el esquema)
go run ./cmd/api migrate up
go run ./cmd/api migrate status

# servidor (http://localhost:8000)
go run ./cmd/api

# tests
go test ./...
```

## Endpoints

Paridad total con el backend anterior para el panel Flutter:
`/health`, `/courses…`, `/alumnos…`, `/users…`, `/attendance…`, `/subjects`,
`/teachers`, `/specialties`, `/school-settings`, `/notifications`,
`/workshop-groups…`. Errores con el sobre `{"detail": "<mensaje>"}`.

Nuevos (scaffolding, aditivos — no afectan al Flutter):

| Método | Ruta | Auth | Descripción |
|---|---|---|---|
| POST | `/auth/login` | — | login usuario/contraseña → token + rol |
| GET  | `/device/health` | API Key | ping del lector |
| POST | `/device/attendance` | API Key | un registro NFC (ULID del ESP32) |
| POST | `/device/sync` | API Key | batch del buffer offline (dedup por ULID) |
| POST | `/device/secondary-auth` | API Key | verifica QR estático (extensible) |

Auth de dispositivo: header `X-API-Key` validado contra `devices.api_key_hash`.
