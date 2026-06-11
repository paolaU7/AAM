# AAM Backend — FastAPI + SQLAlchemy

## Setup Inicial

### 1. Instalar Python 3.10+

```bash
# Verificar que tengas Python instalado
python --version  # O python3 --version
```

**Si no tienes Python:** Descargar desde https://www.python.org/downloads/ (Windows 10+)

### 2. Crear entorno virtual

```bash
cd backend
python -m venv venv
```

**Windows:**
```bash
venv\Scripts\activate
```

**macOS/Linux:**
```bash
source venv/bin/activate
```

### 3. Instalar dependencias

```bash
pip install -r requirements.txt
```

### 4. Configurar PostgreSQL

**Opción A: Con Docker (recomendado)**

```bash
# Instalar Docker desde https://www.docker.com/products/docker-desktop/
# Luego:
docker-compose up -d
```

Esto levanta PostgreSQL automáticamente en `localhost:5432`.

**Opción B: PostgreSQL nativo**

- Descargar desde https://www.postgresql.org/download/
- Crear usuario `aam_user` con password `aam_password`
- Crear BD `aam_dev`
- Copiar `DATABASE_URL` a `.env`

### 5. Copiar archivo de configuración

```bash
cp .env.example .env
# Editar .env si es necesario
```

### 6. Ejecutar servidor

```bash
cd backend
python main.py
```

Accede a `http://localhost:8000` (Swagger en `/docs`)

---

## Estructura

```
backend/
├── main.py                          ← Entry point
├── requirements.txt                 ← Dependencies
├── docker-compose.yml               ← PostgreSQL + tools
├── .env.example                     ← Template de configuración
│
└── app/
    ├── __init__.py
    ├── core/
    │   ├── __init__.py
    │   ├── config.py                ← Settings, env vars
    │   └── security.py              ← JWT, API Key auth (TODO)
    │
    ├── domain/                      ← NÚCLEO (zero dependencies)
    │   ├── __init__.py
    │   ├── entities/                ← Modelos de negocio
    │   │   ├── usuario.py
    │   │   ├── alumno.py
    │   │   ├── curso.py
    │   │   ├── asistencia.py
    │   │   ├── retiro.py
    │   │   └── excepcion.py
    │   ├── repositories/            ← Puertos (interfaces)
    │   │   ├── usuario_repository.py
    │   │   ├── alumno_repository.py
    │   │   └── ...
    │   └── usecases/                ← Lógica de negocio
    │       ├── registrar_asistencia.py
    │       ├── crear_usuario.py
    │       ├── cargar_horarios.py
    │       └── ...
    │
    ├── infrastructure/              ← ADAPTADORES
    │   ├── __init__.py
    │   ├── database.py              ← SQLAlchemy setup
    │   ├── models/                  ← ORM models (SQLAlchemy)
    │   │   ├── usuario_model.py
    │   │   ├── alumno_model.py
    │   │   └── ...
    │   └── repositories/            ← Implementaciones
    │       ├── usuario_repository_impl.py
    │       └── ...
    │
    └── api/                         ← ROUTES (FastAPI)
        ├── __init__.py
        ├── auth.py                  ← POST /login, /register
        ├── attendance.py            ← POST /register, POST /sync
        ├── users.py                 ← GET /users, POST /users
        ├── courses.py               ← GET /courses, ...
        └── admin.py                 ← Panel dirección
```

---

## Roadmap (Fase 3)

- [x] Estructura base FastAPI
- [ ] Entidades de dominio (Etapa 2, Tarea 2.1)
- [ ] Repositorios (interfaces) (Etapa 2, Tarea 2.2)
- [ ] Casos de uso (Etapa 2, Tarea 2.3)
- [ ] Modelos SQLAlchemy + migrations (Etapa 2, Tarea 2.4/2.5)
- [ ] Endpoints públicos (Etapa 2, Tarea 2.6)
- [ ] Endpoints privados (Etapa 2, Tarea 2.7)
- [ ] Sistema de auth + roles (Etapa 2, Tarea 2.8)
- [ ] Validación (Etapa 2, Tarea 2.9)
- [ ] Tests unitarios (Etapa 2, Tarea 2.10)

---

## Documentación

- Visión del proyecto: `../docs/vision.md`
- Design System: `../docs/design-system.md`
- Especificaciones API: `../docs/api-spec.md` (TODO)
- Decisiones técnicas: `../docs/adr/` (TODO)
