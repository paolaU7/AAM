#!/usr/bin/env bash
# =============================================================================
#  aam — Scripts de desarrollo para el proyecto AAM
# =============================================================================

set -euo pipefail

# ── Colores ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

SCRIPT_NAME="aam"

# ── Detectar raíz del repo ──────────────────────────────────────────────────
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"

# =============================================================================
# UTILIDADES
# =============================================================================

log()    { echo -e "${GREEN}▸${RESET} $*"; }
warn()   { echo -e "${YELLOW}⚠${RESET}  $*"; }
error()  { echo -e "${RED}✖${RESET}  $*" >&2; }
header() { echo -e "\n${BOLD}${CYAN}══ $* ══${RESET}\n"; }

require_git_repo() {
    if [ -z "$PROJECT_ROOT" ]; then
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
# BUILD
# =============================================================================

cmd_build() {
    require_git_repo

    header "AAM — Build completo"

    local failed=0

    # Backend
    log "Backend → verificando dependencias..."

    if [ -d "$PROJECT_ROOT/backend" ]; then
        cd "$PROJECT_ROOT/backend"

        if [ -f "pyproject.toml" ]; then
            poetry install || failed=1
        elif [ -f "requirements.txt" ]; then
            pip install -r requirements.txt || failed=1
        else
            warn "No se encontraron dependencias."
        fi

        if command -v ruff &>/dev/null; then
            ruff check . || failed=1
        fi

        cd "$PROJECT_ROOT"
    else
        warn "backend/ no encontrado."
    fi

    # Frontend
    log "Frontend → verificando Flutter..."

    if [ -d "$PROJECT_ROOT/frontend" ]; then
        cd "$PROJECT_ROOT/frontend"

        if command -v flutter &>/dev/null; then
            flutter pub get || failed=1
            flutter analyze --no-fatal-warnings --no-fatal-infos || failed=1
        else
            warn "Flutter no encontrado."
        fi

        cd "$PROJECT_ROOT"
    else
        warn "frontend/ no encontrado."
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
# RUN BACKEND / FRONTEND / FULL
# =============================================================================

cmd_run_back() {
    require_git_repo

    header "AAM — Backend"

    if [ -d "$PROJECT_ROOT/backend" ]; then
        cd "$PROJECT_ROOT/backend"
        log "Levantando backend en http://localhost:8000 ..."
        PYTHONPATH=. poetry run uvicorn app.main:app --reload
    else
        warn "backend/ no encontrado."
    fi
}

cmd_run_front() {
    require_git_repo

    header "AAM — Frontend"

    if [ -d "$PROJECT_ROOT/frontend" ]; then
        cd "$PROJECT_ROOT/frontend"
        log "Levantando frontend..."
        flutter run -d chrome
    else
        warn "frontend/ no encontrado."
    fi
}

cmd_run() {
    require_git_repo

    header "AAM — Run completo"

    if [ -d "$PROJECT_ROOT/backend" ]; then
        log "Levantando backend..."
        cd "$PROJECT_ROOT/backend"
        PYTHONPATH=. poetry run uvicorn app.main:app --reload &
        BACK_PID=$!
        cd "$PROJECT_ROOT"
    else
        warn "backend/ no encontrado."
        BACK_PID=""
    fi

    if [ -d "$PROJECT_ROOT/frontend" ]; then
        log "Levantando frontend..."
        cd "$PROJECT_ROOT/frontend"
        flutter run -d chrome &
        FRONT_PID=$!
        cd "$PROJECT_ROOT"
    else
        warn "frontend/ no encontrado."
        FRONT_PID=""
    fi

    echo ""
    echo -e "${GREEN}${BOLD}✔ Backend y frontend iniciados.${RESET}"
    echo -e "${CYAN}Backend PID:${RESET}  ${BACK_PID:-N/A}"
    echo -e "${CYAN}Frontend PID:${RESET} ${FRONT_PID:-N/A}"

    wait
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

${GREEN}aam build${RESET}
${GREEN}aam run${RESET}
${GREEN}aam run-back${RESET}
${GREEN}aam run-front${RESET}
${GREEN}aam push${RESET}
"
}

# =============================================================================
# DISPATCHER
# =============================================================================

case "${1:-help}" in
    build) cmd_build ;;
    run) cmd_run ;;
    run-back) cmd_run_back ;;
    run-front) cmd_run_front ;;
    push) cmd_push ;;
    help|--help|-h) cmd_help ;;
    *) error "Comando desconocido: ${1:-}" ; cmd_help ;;
esac