#!/usr/bin/env bash
# =============================================================================
#  aam — Scripts de desarrollo para el proyecto AAM
#  Uso: aam <comando> [opciones]
# =============================================================================

set -euo pipefail

# ── Colores ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Nombre del comando ──────────────────────────────────────────────────────
SCRIPT_NAME="aam"

# ── Detectar raíz REAL del repo Git ─────────────────────────────────────────
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"

# =============================================================================
#  UTILIDADES
# =============================================================================

log()    { echo -e "${GREEN}▸${RESET} $*"; }
warn()   { echo -e "${YELLOW}⚠${RESET}  $*"; }
error()  { echo -e "${RED}✖${RESET}  $*" >&2; }
header() { echo -e "\n${BOLD}${CYAN}══ $* ══${RESET}\n"; }

require_git_repo() {
    if [ -z "$PROJECT_ROOT" ]; then
        error "No es un repositorio Git. Inicializá con: git init"
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
#  COMANDO: build
# =============================================================================

cmd_build() {
    require_git_repo

    header "AAM — Build completo"

    local failed=0

    # ── Backend ──────────────────────────────────────────────────────────────
    log "Backend → verificando Python y dependencias..."

    if [ -d "$PROJECT_ROOT/backend" ]; then
        cd "$PROJECT_ROOT/backend"

        if [ -f ".venv/bin/activate" ]; then
            source .venv/bin/activate
            log "Virtualenv activado."
        elif [ -f "venv/bin/activate" ]; then
            source venv/bin/activate
            log "Virtualenv activado."
        else
            warn "No se encontró virtualenv. Usando Python del sistema."
        fi

        if [ -f "requirements.txt" ]; then
            log "Instalando dependencias..."
            pip install -q -r requirements.txt
        elif [ -f "pyproject.toml" ]; then
            log "Instalando dependencias..."
            pip install -q -e .
        else
            warn "No se encontraron dependencias."
        fi

        if command -v ruff &>/dev/null; then
            log "Ejecutando ruff..."
            ruff check . || {
                error "ruff encontró errores."
                failed=1
            }
        fi

        if command -v mypy &>/dev/null; then
            log "Ejecutando mypy..."
            mypy . --ignore-missing-imports || warn "mypy reportó advertencias."
        fi

        cd "$PROJECT_ROOT"
        log "Backend OK."
    else
        warn "Directorio backend/ no encontrado."
    fi

    # ── Frontend ─────────────────────────────────────────────────────────────
    log "Frontend → verificando Flutter..."

    if [ -d "$PROJECT_ROOT/frontend" ]; then
        cd "$PROJECT_ROOT/frontend"

        if command -v flutter &>/dev/null; then
            log "flutter pub get..."
            flutter pub get

            log "flutter analyze..."
            flutter analyze || {
                error "flutter analyze reportó errores."
                failed=1
            }

            log "flutter test..."
            flutter test || {
                error "flutter test falló."
                failed=1
            }
        else
            warn "Flutter no encontrado."
        fi

        cd "$PROJECT_ROOT"
        log "Frontend OK."
    else
        warn "Directorio frontend/ no encontrado."
    fi

    # ── Firmware ─────────────────────────────────────────────────────────────
    log "Firmware → verificando PlatformIO..."

    if [ -d "$PROJECT_ROOT/reader" ]; then
        cd "$PROJECT_ROOT/reader"

        if command -v pio &>/dev/null; then
            log "pio run..."
            pio run || {
                error "PlatformIO falló."
                failed=1
            }
        else
            warn "PlatformIO no encontrado."
        fi

        cd "$PROJECT_ROOT"
        log "Firmware OK."
    else
        warn "Directorio reader/ no encontrado."
    fi

    echo ""

    if [ "$failed" -eq 0 ]; then
        echo -e "${GREEN}${BOLD}✔ Build completado sin errores.${RESET}"
    else
        echo -e "${RED}${BOLD}✖ Build terminó con errores.${RESET}"
        exit 1
    fi
}

# =============================================================================
#  COMANDO: push-main
# =============================================================================

cmd_push_main() {
    header "AAM — Push a main"

    require_git_repo
    require_changes

    cd "$PROJECT_ROOT"

    local msg="${1:-}"

    if [ -z "$msg" ]; then
        echo -e "${CYAN}Mensaje de commit:${RESET}"
        read -r msg
    fi

    if [ -z "$msg" ]; then
        error "El mensaje de commit no puede estar vacío."
        exit 1
    fi

    log "git add -A"
    git add -A

    log "git commit -m \"$msg\""
    git commit -m "$msg"

    local current_branch
    current_branch=$(git rev-parse --abbrev-ref HEAD)

    if [ "$current_branch" != "main" ]; then
        warn "Estás en '$current_branch', no en 'main'."

        echo -ne "¿Hacer checkout a main y mergear? [s/N] "
        read -r confirm

        if [[ "$confirm" =~ ^[sS]$ ]]; then
            git checkout main
            git merge "$current_branch" --no-ff -m "Merge $current_branch → main"
        else
            warn "Push cancelado."
            exit 0
        fi
    fi

    log "git push origin main"
    git push origin main

    echo -e "\n${GREEN}${BOLD}✔ Cambios pusheados a main.${RESET}"
}

# =============================================================================
#  COMANDO: push-branch
# =============================================================================

cmd_push_branch() {
    header "AAM — Push a nueva rama"

    require_git_repo
    require_changes

    cd "$PROJECT_ROOT"

    local branch="${1:-}"
    local msg="${2:-}"

    if [ -z "$branch" ]; then
        echo -e "${CYAN}Nombre de la nueva rama:${RESET}"
        read -r branch
    fi

    if [ -z "$branch" ]; then
        error "El nombre de la rama no puede estar vacío."
        exit 1
    fi

    branch=$(echo "$branch" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

    if [ -z "$msg" ]; then
        echo -e "${CYAN}Mensaje de commit:${RESET}"
        read -r msg
    fi

    if [ -z "$msg" ]; then
        error "El mensaje de commit no puede estar vacío."
        exit 1
    fi

    log "git checkout -b \"$branch\""
    git checkout -b "$branch"

    log "git add -A"
    git add -A

    log "git commit -m \"$msg\""
    git commit -m "$msg"

    log "git push -u origin \"$branch\""
    git push -u origin "$branch"

    echo -e "\n${GREEN}${BOLD}✔ Rama '$branch' creada y pusheada.${RESET}"
}

# =============================================================================
#  COMANDO: help
# =============================================================================

cmd_help() {
    echo -e "
${BOLD}${CYAN}╔══════════════════════════════════════════════════════╗
║                AAM CLI v1.0                          ║
╚══════════════════════════════════════════════════════╝${RESET}

${BOLD}COMANDOS DISPONIBLES${RESET}

${GREEN}${SCRIPT_NAME} build${RESET}
   Compila y verifica backend, frontend y firmware.

${GREEN}${SCRIPT_NAME} push-main${RESET}
   Commit + push directo a main.

${GREEN}${SCRIPT_NAME} push-main \"mensaje\"${RESET}
   Push a main con mensaje automático.

${GREEN}${SCRIPT_NAME} push-branch${RESET}
   Crea rama nueva y hace push.

${GREEN}${SCRIPT_NAME} push-branch feature/login \"feat: login\"${RESET}
   Crea rama y pushea automáticamente.

${GREEN}${SCRIPT_NAME} help${RESET}
   Muestra esta ayuda.
"
}

# =============================================================================
#  DISPATCHER
# =============================================================================

case "${1:-help}" in
    build)
        cmd_build
        ;;

    push-main)
        shift
        cmd_push_main "$@"
        ;;

    push-branch)
        shift
        cmd_push_branch "$@"
        ;;

    help|--help|-h)
        cmd_help
        ;;

    *)
        error "Comando desconocido: '${1:-}'" 
        echo ""
        cmd_help
        exit 1
        ;;
esac