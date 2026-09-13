#!/usr/bin/env bash
# =============================================================================
#  aam — Scripts de desarrollo para el proyecto AAM
#
#  Stack:
#    reader/    Firmware C++ (framework Arduino) para ESP32 + PN532 — PlatformIO
#    backend/   Go + chi (router liviano) + PostgreSQL (pgx) + goose (migraciones)
#    frontend/  Flutter (Dart), móvil para preceptores y web/escritorio para dirección
# =============================================================================

set -euo pipefail

# ── Forzar codificación UTF-8 en Git Bash/MinGW para Flutter/Dart ───────────
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export PYTHONIOENCODING=utf-8

# ── Colores ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

SCRIPT_NAME="aam"

# ── Raíz del repo ───────────────────────────────────────────────────────────
# aam.sh vive en la raíz del repo, así que la ubicación del script es la fuente
# de verdad (más confiable que `git rev-parse` cuando hay repos anidados).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

BACKEND_DIR="$PROJECT_ROOT/backend"
FRONTEND_DIR="$PROJECT_ROOT/frontend"
READER_DIR="$PROJECT_ROOT/reader"

# ── Asegurar Go en el PATH ─────────────────────────────────────────────────
# Git Bash no siempre hereda el PATH de Go; lo agregamos si hace falta.
if ! command -v go &>/dev/null; then
    for _godir in "/c/Program Files/Go/bin" "/c/Go/bin" "$HOME/go/bin"; do
        [ -x "$_godir/go.exe" ] || [ -x "$_godir/go" ] && PATH="$PATH:$_godir"
    done
    export PATH
fi

# =============================================================================
# UTILIDADES
# =============================================================================

log()    { echo -e "${GREEN}▸${RESET} $*"; }
warn()   { echo -e "${YELLOW}⚠${RESET}  $*"; }
error()  { echo -e "${RED}✖${RESET}  $*" >&2; }
header() { echo -e "\n${BOLD}${CYAN}══ $* ══${RESET}\n"; }

have() { command -v "$1" &>/dev/null; }

# PlatformIO se instala como `pio` o `platformio`.
pio_bin() {
    if have pio; then echo "pio"
    elif have platformio; then echo "platformio"
    else return 1
    fi
}

# URL de Supabase para el backend, en este orden:
#   1) variable de entorno SUPABASE_DATABASE_URL
#   2) línea SUPABASE_DATABASE_URL=... en backend/.env
# Vacío si no está configurada o si todavía tiene el placeholder <PROJECT_REF>.
supabase_db_url() {
    local url="${SUPABASE_DATABASE_URL:-}"
    if [ -z "$url" ] && [ -f "$BACKEND_DIR/.env" ]; then
        url="$(grep -E '^[[:space:]]*SUPABASE_DATABASE_URL[[:space:]]*=' "$BACKEND_DIR/.env" 2>/dev/null | tail -1)"
        url="${url#*=}"
        url="$(printf '%s' "$url" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^["'\'']//' -e 's/["'\'']$//')"
    fi
    case "$url" in
        ""|*"<PROJECT_REF>"*) return 0 ;;
        *) printf '%s' "$url" ;;
    esac
}

require_git_repo() {
    if ! git -C "$PROJECT_ROOT" rev-parse --show-toplevel &>/dev/null; then
        error "No es un repositorio Git."
        exit 1
    fi
}

require_changes() {
    cd "$PROJECT_ROOT"

    if git diff --cached --quiet && \
       git diff --quiet && \
       [ -z "$(git ls-files --others --exclude-standard)" ]; then
        warn "No hay cambios para commitear."
        exit 0
    fi
}

# =============================================================================
# BUILD  (verificación de dependencias + análisis estático)
# =============================================================================

cmd_build() {
    header "AAM — Build completo"

    local failed=0

    # ── Backend (Go) ────────────────────────────────────────────────────────
    log "Backend → Go..."
    if [ -d "$BACKEND_DIR" ]; then
        cd "$BACKEND_DIR"
        if have go; then
            go mod tidy   || failed=1
            go build ./... || failed=1
            go vet ./...   || failed=1
        else
            warn "Go no encontrado (instalá Go 1.23+)."
        fi
        cd "$PROJECT_ROOT"
    else
        warn "backend/ no encontrado."
    fi

    # ── Frontend (Flutter) ─────────────────────────────────────────────────
    log "Frontend → Flutter..."
    if [ -d "$FRONTEND_DIR" ]; then
        cd "$FRONTEND_DIR"
        if have flutter; then
            flutter pub get || failed=1
            flutter analyze --no-fatal-warnings --no-fatal-infos || failed=1
        else
            warn "Flutter no encontrado."
        fi
        cd "$PROJECT_ROOT"
    else
        warn "frontend/ no encontrado."
    fi

    # ── Reader (ESP32 / PlatformIO) ────────────────────────────────────────
    log "Reader → PlatformIO..."
    if [ -d "$READER_DIR" ]; then
        cd "$READER_DIR"
        if PIO="$(pio_bin)"; then
            "$PIO" run || failed=1
        else
            warn "PlatformIO no encontrado (pip install platformio) — se omite el firmware."
        fi
        cd "$PROJECT_ROOT"
    else
        warn "reader/ no encontrado."
    fi

    echo ""
    if [ "$failed" -eq 0 ]; then
        echo -e "${GREEN}${BOLD}✔ Build OK${RESET}"
    else
        echo -e "${RED}${BOLD}✖ Build con errores${RESET}"
        exit 1
    fi
}

# =============================================================================
# TEST
# =============================================================================

cmd_test() {
    header "AAM — Tests"

    local failed=0

    if [ -d "$BACKEND_DIR" ] && have go; then
        log "Backend → go test ./..."
        cd "$BACKEND_DIR"
        go test ./... || failed=1
        cd "$PROJECT_ROOT"
    else
        warn "Se omiten tests de backend (falta backend/ o Go)."
    fi

    if [ -d "$FRONTEND_DIR" ] && have flutter; then
        log "Frontend → flutter test"
        cd "$FRONTEND_DIR"
        flutter test || failed=1
        cd "$PROJECT_ROOT"
    else
        warn "Se omiten tests de frontend (falta frontend/ o Flutter)."
    fi

    echo ""
    if [ "$failed" -eq 0 ]; then
        echo -e "${GREEN}${BOLD}✔ Tests OK${RESET}"
    else
        echo -e "${RED}${BOLD}✖ Tests con errores${RESET}"
        exit 1
    fi
}

# =============================================================================
# MIGRACIONES  (goose embebido en el binario de Go)
# =============================================================================

cmd_migrate() {
    header "AAM — Migraciones (goose)"

    if [ ! -d "$BACKEND_DIR" ]; then
        error "backend/ no encontrado."
        exit 1
    fi
    if ! have go; then
        error "Go no encontrado (instalá Go 1.23+)."
        exit 1
    fi

    local sub="${1:-up}"   # up | down | status
    case "$sub" in
        up|down|status) ;;
        *) error "Subcomando inválido: '$sub' (up | down | status)"; exit 1 ;;
    esac

    cd "$BACKEND_DIR"
    log "go run ./cmd/api migrate $sub"
    go run ./cmd/api migrate "$sub"
}

# =============================================================================
# RUN BACKEND / FRONTEND / FULL
# =============================================================================

cmd_run_back() {
    header "AAM — Backend"

    if [ ! -d "$BACKEND_DIR" ]; then
        warn "backend/ no encontrado."
        return
    fi
    if ! have go; then
        error "Go no encontrado (instalá Go 1.23+)."
        exit 1
    fi

    cd "$BACKEND_DIR"
    # El esquema se administra a mano con backend/schema.sql (aplicalo en tu
    # Postgres local o en el SQL Editor de Supabase). Las migraciones goose
    # quedaron desactualizadas, por eso no se corren solas.
    log "Levantando backend en http://localhost:8000 ..."
    go run ./cmd/api
}

cmd_run_front() {
    header "AAM — Frontend"

    if [ ! -d "$FRONTEND_DIR" ]; then
        warn "frontend/ no encontrado."
        return
    fi
    if ! have flutter; then
        error "Flutter no encontrado."
        exit 1
    fi

    local device="${1:-chrome}"   # chrome | linux | windows | macos | <id de dispositivo>
    cd "$FRONTEND_DIR"
    log "Levantando frontend (-d $device) ..."
    flutter run -d "$device"
}

cmd_run() {
    header "AAM — Run completo"

    BACK_PID=""
    FRONT_PID=""

    cleanup() {
        [ -n "$BACK_PID" ]  && kill "$BACK_PID"  2>/dev/null || true
        [ -n "$FRONT_PID" ] && kill "$FRONT_PID" 2>/dev/null || true
    }
    trap cleanup EXIT INT TERM

    if [ -d "$BACKEND_DIR" ] && have go; then
        # `aam run` apunta el backend a Supabase. La URL sale de
        # SUPABASE_DATABASE_URL (variable de entorno o backend/.env).
        # Esquema: se aplica a mano con backend/schema.sql.
        local sb_url
        sb_url="$(supabase_db_url)"
        if [ -n "$sb_url" ]; then
            log "Levantando backend → Supabase ..."
            ( cd "$BACKEND_DIR" && DATABASE_URL="$sb_url" go run ./cmd/api ) &
        else
            warn "SUPABASE_DATABASE_URL no configurada en backend/.env — el backend usa DATABASE_URL de .env."
            log "Levantando backend..."
            ( cd "$BACKEND_DIR" && go run ./cmd/api ) &
        fi
        BACK_PID=$!
    else
        warn "backend/ no se inicia (falta backend/ o Go)."
    fi

    if [ -d "$FRONTEND_DIR" ] && have flutter; then
        log "Levantando frontend..."
        ( cd "$FRONTEND_DIR" && flutter run -d chrome ) &
        FRONT_PID=$!
    else
        warn "frontend/ no se inicia (falta frontend/ o Flutter)."
    fi

    if [ -z "$BACK_PID" ] && [ -z "$FRONT_PID" ]; then
        error "Nada para ejecutar."
        exit 1
    fi

    echo ""
    echo -e "${GREEN}${BOLD}✔ Servicios iniciados.${RESET}"
    echo -e "${CYAN}Backend PID:${RESET}  ${BACK_PID:-N/A}"
    echo -e "${CYAN}Frontend PID:${RESET} ${FRONT_PID:-N/A}"

    wait
}

# =============================================================================
# READER  (firmware ESP32 vía PlatformIO)
# =============================================================================

cmd_reader() {
    local sub="${1:-build}"   # build | flash | monitor
    header "AAM — Reader ($sub)"

    if [ ! -d "$READER_DIR" ]; then
        error "reader/ no encontrado."
        exit 1
    fi
    local PIO
    if ! PIO="$(pio_bin)"; then
        error "PlatformIO no encontrado (pip install platformio)."
        exit 1
    fi

    cd "$READER_DIR"
    case "$sub" in
        build)   "$PIO" run ;;
        flash)   "$PIO" run --target upload ;;
        monitor) "$PIO" device monitor ;;
        *) error "Subcomando inválido: '$sub' (build | flash | monitor)"; exit 1 ;;
    esac
}

# =============================================================================
# PUSH
# =============================================================================

cmd_push() {
    require_git_repo
    require_changes

    header "AAM — Push"

    cd "$PROJECT_ROOT"

    echo -e "${CYAN}Rama destino:${RESET}"
    read -r branch

    if [ -z "$branch" ]; then
        error "La rama no puede estar vacía."
        exit 1
    fi

    if ! git show-ref --verify --quiet "refs/heads/$branch"; then
        error "La rama '$branch' no existe."
        exit 1
    fi

    echo -e "${CYAN}Mensaje de commit:${RESET}"
    read -r msg

    if [ -z "$msg" ]; then
        error "El mensaje no puede estar vacío."
        exit 1
    fi

    log "git checkout $branch"
    git checkout "$branch"

    log "git add -A"
    git add -A

    log "git commit -m \"$msg\""
    git commit -m "$msg"

    log "git push origin $branch"
    git push origin "$branch"

    echo ""
    echo -e "${GREEN}${BOLD}✔ Push completado.${RESET}"
}

# =============================================================================
# HELP
# =============================================================================

cmd_help() {
    echo -e "
${BOLD}${CYAN}AAM CLI${RESET}

${GREEN}${SCRIPT_NAME} build${RESET}              - Dependencias + análisis estático (backend Go, frontend Flutter, reader PlatformIO)
${GREEN}${SCRIPT_NAME} test${RESET}               - Corre los tests (go test / flutter test)
${GREEN}${SCRIPT_NAME} migrate [up|down|status]${RESET}
                        - Migraciones goose del backend (por defecto: up)
${GREEN}${SCRIPT_NAME} run${RESET}                - Inicia backend (→ Supabase, ver SUPABASE_DATABASE_URL en backend/.env) y frontend juntos
${GREEN}${SCRIPT_NAME} run-back${RESET}           - Inicia solo el backend con DATABASE_URL de backend/.env (http://localhost:8000)
${GREEN}${SCRIPT_NAME} run-front [device]${RESET} - Inicia solo el frontend (device por defecto: chrome)
${GREEN}${SCRIPT_NAME} reader [build|flash|monitor]${RESET}
                        - Firmware del ESP32 vía PlatformIO (por defecto: build)
${GREEN}${SCRIPT_NAME} push${RESET}               - Agrega, commitea y sube cambios a una rama existente
"
}

# =============================================================================
# DISPATCHER
# =============================================================================

case "${1:-help}" in
    build)      cmd_build ;;
    test)       cmd_test ;;
    migrate)    shift || true; cmd_migrate "$@" ;;
    run)        cmd_run ;;
    run-back)   cmd_run_back ;;
    run-front)  shift || true; cmd_run_front "$@" ;;
    reader)     shift || true; cmd_reader "$@" ;;
    push)       cmd_push ;;
    help|--help|-h) cmd_help ;;
    *) error "Comando desconocido: ${1:-}" ; cmd_help ; exit 1 ;;
esac
