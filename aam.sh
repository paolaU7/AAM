#!/usr/bin/env bash
# =============================================================================
#  aam.sh — Scripts de desarrollo para el proyecto AAM
#  Uso: ./aam.sh <comando> [opciones]
# =============================================================================

set -euo pipefail

# ── Colores ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Raíz del proyecto (directorio donde vive este script) ────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# =============================================================================
#  UTILIDADES
# =============================================================================

log()    { echo -e "${GREEN}▸${RESET} $*"; }
warn()   { echo -e "${YELLOW}⚠${RESET}  $*"; }
error()  { echo -e "${RED}✖${RESET}  $*" >&2; }
header() { echo -e "\n${BOLD}${CYAN}══ $* ══${RESET}\n"; }

require_git_repo() {
    if ! git -C "$PROJECT_ROOT" rev-parse --git-dir &>/dev/null; then
        error "No es un repositorio Git. Inicializá con: git init"
        exit 1
    fi
}

require_clean_or_staged() {
    if git -C "$PROJECT_ROOT" diff --cached --quiet && \
       git -C "$PROJECT_ROOT" diff --quiet && \
       [ -z "$(git -C "$PROJECT_ROOT" ls-files --others --exclude-standard)" ]; then
        warn "No hay cambios para commitear."
        exit 0
    fi
}

# =============================================================================
#  COMANDO: build
#  Compila / verifica cada capa del proyecto AAM
# =============================================================================

cmd_build() {
    header "AAM — Build completo"

    local failed=0

    # ── Backend (FastAPI) ────────────────────────────────────────────────────
    log "Backend → verificando Python y dependencias..."
    if [ -d "$PROJECT_ROOT/backend" ]; then
        cd "$PROJECT_ROOT/backend"

        # Activar virtualenv si existe
        if [ -f ".venv/bin/activate" ]; then
            source .venv/bin/activate
            log "Virtualenv activado."
        elif [ -f "venv/bin/activate" ]; then
            source venv/bin/activate
            log "Virtualenv activado."
        else
            warn "No se encontró virtualenv en backend/. Usando Python del sistema."
        fi

        # Instalar/actualizar dependencias
        if [ -f "requirements.txt" ]; then
            log "Instalando dependencias (requirements.txt)..."
            pip install -q -r requirements.txt
        elif [ -f "pyproject.toml" ]; then
            log "Instalando dependencias (pyproject.toml)..."
            pip install -q -e .
        else
            warn "No se encontró requirements.txt ni pyproject.toml en backend/."
        fi

        # Lint rápido con ruff si está disponible
        if command -v ruff &>/dev/null; then
            log "Ejecutando ruff (lint)..."
            ruff check . || { error "ruff encontró errores en backend/."; failed=1; }
        fi

        # Type check con mypy si está disponible
        if command -v mypy &>/dev/null; then
            log "Ejecutando mypy (type check)..."
            mypy . --ignore-missing-imports || { warn "mypy reportó advertencias en backend/."; }
        fi

        cd "$PROJECT_ROOT"
        log "Backend OK."
    else
        warn "Directorio backend/ no encontrado. Saltando."
    fi

    # ── Frontend (Flutter) ───────────────────────────────────────────────────
    log "Frontend → verificando Flutter..."
    if [ -d "$PROJECT_ROOT/frontend" ]; then
        cd "$PROJECT_ROOT/frontend"

        if command -v flutter &>/dev/null; then
            log "flutter pub get..."
            flutter pub get

            log "flutter analyze..."
            flutter analyze || { error "flutter analyze reportó errores."; failed=1; }

            log "flutter test..."
            flutter test || { error "flutter test falló."; failed=1; }
        else
            warn "Flutter no está instalado o no está en PATH. Saltando frontend."
        fi

        cd "$PROJECT_ROOT"
        log "Frontend OK."
    else
        warn "Directorio frontend/ no encontrado. Saltando."
    fi

    # ── Firmware ESP32 (PlatformIO) ──────────────────────────────────────────
    log "Firmware → verificando PlatformIO..."
    if [ -d "$PROJECT_ROOT/reader" ]; then
        cd "$PROJECT_ROOT/reader"

        if command -v pio &>/dev/null; then
            log "pio run (compilación)..."
            pio run || { error "PlatformIO falló al compilar el firmware."; failed=1; }
        else
            warn "PlatformIO (pio) no encontrado. Saltando firmware ESP32."
        fi

        cd "$PROJECT_ROOT"
        log "Firmware OK."
    else
        warn "Directorio reader/ no encontrado. Saltando."
    fi

    # ── Resultado ────────────────────────────────────────────────────────────
    echo ""
    if [ "$failed" -eq 0 ]; then
        echo -e "${GREEN}${BOLD}✔ Build completado sin errores.${RESET}"
    else
        echo -e "${RED}${BOLD}✖ Build terminó con errores. Revisá los mensajes arriba.${RESET}"
        exit 1
    fi
}

# =============================================================================
#  COMANDO: push-main
#  Agrega todo, commitea y pushea directo a main
# =============================================================================

cmd_push_main() {
    header "AAM — Push a main"
    require_git_repo
    require_clean_or_staged

    cd "$PROJECT_ROOT"

    # Pedir mensaje de commit
    local msg=""
    if [ -n "${1:-}" ]; then
        msg="$1"
    else
        echo -e "${CYAN}Mensaje de commit:${RESET} "
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
        warn "Estás en la rama '$current_branch', no en 'main'."
        echo -ne "  ¿Hacer checkout a main y mergear? [s/N] "
        read -r confirm
        if [[ "$confirm" =~ ^[sS]$ ]]; then
            git checkout main
            git merge "$current_branch" --no-ff -m "Merge $current_branch → main"
        else
            warn "Push cancelado. Hacé checkout a main manualmente."
            exit 0
        fi
    fi

    log "git push origin main"
    git push origin main

    echo -e "\n${GREEN}${BOLD}✔ Cambios pusheados a main.${RESET}"
}

# =============================================================================
#  COMANDO: push-branch
#  Crea una nueva rama, commitea y pushea
# =============================================================================

cmd_push_branch() {
    header "AAM — Push a nueva rama"
    require_git_repo
    require_clean_or_staged

    cd "$PROJECT_ROOT"

    # Nombre de rama
    local branch=""
    if [ -n "${1:-}" ]; then
        branch="$1"
    else
        echo -e "${CYAN}Nombre de la nueva rama${RESET} (ej: feature/nfc-reader, fix/sync-bug): "
        read -r branch
    fi

    if [ -z "$branch" ]; then
        error "El nombre de la rama no puede estar vacío."
        exit 1
    fi

    # Normalizar: espacios → guiones, minúsculas
    branch=$(echo "$branch" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

    # Mensaje de commit
    local msg=""
    if [ -n "${2:-}" ]; then
        msg="$2"
    else
        echo -e "${CYAN}Mensaje de commit:${RESET} "
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
    echo -e "  Para abrir un Pull Request:"
    echo -e "  ${CYAN}https://github.com/<tu-usuario>/aam/compare/$branch${RESET}"
}

# =============================================================================
#  COMANDO: help
#  Muestra todos los comandos disponibles
# =============================================================================

cmd_help() {
    echo -e "
${BOLD}${CYAN}╔══════════════════════════════════════════════════════╗
║          AAM — Script de desarrollo v1.0             ║
╚══════════════════════════════════════════════════════╝${RESET}

${BOLD}COMANDOS DISPONIBLES${RESET}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

${BOLD}${GREEN}1. build${RESET} — Compila y verifica el proyecto completo

   Qué hace:
     • Backend  → instala dependencias, revisa errores de código
     • Frontend → descarga paquetes Flutter, analiza y testea
     • Firmware → compila el código C++ del ESP32

   Cómo se usa:
     ${CYAN}./aam.sh build${RESET}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

${BOLD}${GREEN}2. push-main${RESET} — Sube todos los cambios directo a main

   Qué hace:
     • Agrega todos los archivos modificados
     • Crea un commit con tu mensaje
     • Pushea a la rama main

   Cómo se usa (dos formas):

     Forma 1 — el mensaje lo escribís cuando el script lo pide:
       ${CYAN}./aam.sh push-main${RESET}
       El script te va a preguntar: Mensaje de commit:
       Ahí escribís, por ejemplo:  feat: agrego modelo de alumno

     Forma 2 — el mensaje va directo en el comando (entre comillas):
       ${CYAN}./aam.sh push-main \"feat: agrego modelo de alumno\"${RESET}
                           ↑
                     acá va tu mensaje de commit

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

${BOLD}${GREEN}3. push-branch${RESET} — Crea una rama nueva, commitea y pushea

   Qué hace:
     • Crea una rama nueva desde donde estás parado
     • Agrega todos los archivos modificados
     • Crea un commit con tu mensaje
     • Pushea la rama nueva a GitHub

   Cómo se usa (dos formas):

     Forma 1 — el script te va preguntando todo:
       ${CYAN}./aam.sh push-branch${RESET}
       Primero te pide:  Nombre de la nueva rama:
       Después te pide:  Mensaje de commit:

     Forma 2 — pasás todo en el comando:
       ${CYAN}./aam.sh push-branch feature/nfc-reader \"feat: lectura UID con PN532\"${RESET}
                            ↑                    ↑
                      nombre de la rama     mensaje de commit

   Nombres de rama sugeridos:
     feature/lo-que-agregás   → funcionalidad nueva
     fix/lo-que-arreglás      → corrección de bug
     chore/lo-que-cambiás     → refactor o limpieza
     docs/lo-que-documentás   → solo documentación

   Ejemplos concretos para AAM:
     ${CYAN}./aam.sh push-branch feature/littlefs-sync \"feat: buffer offline en ESP32\"${RESET}
     ${CYAN}./aam.sh push-branch fix/ulid-duplicado \"fix: ON CONFLICT DO NOTHING en PostgreSQL\"${RESET}
     ${CYAN}./aam.sh push-branch feature/login-flutter \"feat: pantalla de login preceptor\"${RESET}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

${BOLD}${GREEN}4. help${RESET} — Muestra este mensaje

   ${CYAN}./aam.sh help${RESET}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
"
}

# =============================================================================
#  DISPATCHER
# =============================================================================

case "${1:-help}" in
    build)        cmd_build ;;
    push-main)    shift; cmd_push_main "$@" ;;
    push-branch)  shift; cmd_push_branch "$@" ;;
    help|--help|-h) cmd_help ;;
    *)
        error "Comando desconocido: '${1}'"
        cmd_help
        exit 1
        ;;
esac