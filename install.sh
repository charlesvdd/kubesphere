#!/usr/bin/env bash
###############################################################################
#    ____        _    ____  _                   _              
#   / ___| _   _| | _|  _ \| | _____   _____  _| |_ ___  _ __  
#   \___ \| | | | |/ / |_) | |/ _ \ \ / / _ \| | __/ _ \| '_ \ 
#    ___) | |_| |   <|  __/| |  __/\ V / (_) | | || (_) | | | |
#   |____/ \__,_|_|\_\_|   |_|\___| \_/ \___/|_|\__\___/|_| |_|
#
#    Script d'installation & vérification avec LOG + Design
#    Dépôt : charlesvdd/kubesphere (branche : install)
###############################################################################

# ─── COULEURS ANSI ───────────────────────────────────────────────────────────
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
BLUE="\e[34m"
CYAN="\e[36m"
BOLD="\e[1m"
RESET="\e[0m"

# ─── FONCTIONS UTILITAIRES ───────────────────────────────────────────────────
function header() {
  echo -e "${CYAN}${BOLD}================================================================${RESET}"
  echo -e "${CYAN}${BOLD}  $1${RESET}"
  echo -e "${CYAN}${BOLD}================================================================${RESET}"
}

function info() {
  echo -e "${BLUE}[INFO]${RESET} $1"
}

function success() {
  echo -e "${GREEN}[✔]${RESET} $1"
}

function warning() {
  echo -e "${YELLOW}[!]${RESET} $1"
}

function error() {
  echo -e "${RED}[✖]${RESET} $1"
}

# ─── DÉBUT DU SCRIPT ──────────────────────────────────────────────────────────
set -euo pipefail

LOGFILE="/tmp/kubesphere_install_$(date '+%Y%m%d_%H%M%S').log"
exec > >(tee -a "${LOGFILE}") 2>&1

header "DÉMARRAGE DU SCRIPT D'INSTALLATION"
info "Date/Heure : $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# ─── BLOC INSTALLATION ────────────────────────────────────────────────────────
header "INSTALLATION DES DÉPENDANCES"

# Exemple : installation de curl
if ! command -v curl &>/dev/null; then
  info "curl non trouvé → installation en cours..."
  if sudo apt-get update && sudo apt-get install -y curl; then
    success "curl installé avec succès."
  else
    error "Échec de l'installation de curl."
    exit 1
  fi
else
  success "curl déjà présent ($(curl --version | head -n1))."
fi

# Exemple : installation de kubectl
if ! command -v kubectl &>/dev/null; then
  info "kubectl non trouvé → installation en cours..."
  if sudo apt-get update && sudo apt-get install -y kubectl; then
    success "kubectl installé ($(kubectl version --client --short))."
  else
    error "Échec de l'installation de kubectl."
    exit 1
  fi
else
  success "kubectl déjà présent ($(kubectl version --client --short))."
fi

info "Installation du binaire kubesphere (simulée)…"
sleep 1  # Simuler un téléchargement/compilation
success "kubesphere installé."

echo ""

# ─── BLOC TESTS DE VÉRIFICATION ─────────────────────────────────────────────────
header "VÉRIFICATIONS POST-INSTALLATION"

PASS_COUNT=0
FAIL_COUNT=0

# Test 1 : version minimale de kubectl
info "Test 1 : vérifier que kubectl ≥ 1.20.0"
KUBECTL_VER="$(kubectl version --client --short | awk '{print $3}' | sed 's/v//')"
REQUIRED_VER="1.20.0"
if dpkg --compare-versions "${KUBECTL_VER}" ge "${REQUIRED_VER}"; then
  success "kubectl (${KUBECTL_VER}) satisfait la version minimale (${REQUIRED_VER})."
  ((PASS_COUNT++))
else
  error "kubectl (${KUBECTL_VER}) est inférieur à ${REQUIRED_VER}."
  ((FAIL_COUNT++))
fi

# Test 2 : service kubelet actif
info "Test 2 : vérification du service kubelet"
if systemctl is-active --quiet kubelet; then
  success "Service kubelet actif."
  ((PASS_COUNT++))
else
  error "Service kubelet inactif."
  ((FAIL_COUNT++))
fi

# Test 3 : port Kubernetes standard (6443) ouvert
info "Test 3 : vérifier que le port 6443 est à l'écoute"
if ss -tuln | grep -q ":6443"; then
  success "Port 6443 en écoute."
  ((PASS_COUNT++))
else
  warning "Port 6443 non trouvé ouvert."
  ((FAIL_COUNT++))
fi

echo ""
header "RÉSULTATS DES TESTS"
info "Tests réussis : ${PASS_COUNT}"
if [ "${FAIL_COUNT}" -gt 0 ]; then
  warning "Tests échoués : ${FAIL_COUNT}"
else
  success "Aucun test en échec."
fi
echo ""

# ─── ENVOI DU LOG ──────────────────────────────────────────────────────────────
header "ENVOI DU LOG D'INSTALLATION"

ENDPOINT="https://mon-serveur.example.com/upload"
info "Envoi du log (${LOGFILE}) vers ${ENDPOINT}..."

if curl -X POST \
        -H "Content-Type: multipart/form-data" \
        -F "file=@${LOGFILE}" \
        "${ENDPOINT}" \
        --silent --show-error; then
  success "Log envoyé avec succès."
else
  error "L'envoi du log a échoué."
fi

echo ""
header "FIN DU SCRIPT"
info "Date/Heure : $(date '+%Y-%m-%d %H:%M:%S')"
exit 0
