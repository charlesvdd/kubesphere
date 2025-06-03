root@ubuntu:/# curl -fsSL https://raw.githubusercontent.com/charlesvdd/kubesphere/release/install.sh | head -n50
#!/usr/bin/env bash
###############################################################################
#    ____        _    ____  _                   _              
#   / ___| _   _| | _|  _ \| | _____   _____  _| |_ ___  _ __  
#   \___ \| | | | |/ / |_) | |/ _ \ \ / / _ \| | __/ _ \| '_ \ 
#    ___) | |_| |   <|  __/| |  __/\ V / (_) | | || (_) | | | |
#   |____/ \__,_|_|\_\_|   |_|\___| \_/ \___/|_|\__\___/|_| |_|
#
#    Script d'installation & vérification (sans APT pour kubectl)
#    Dépôt : charlesvdd/kubesphere (branche : release)
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
