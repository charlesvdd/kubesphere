#!/usr/bin/env bash
#
# ███╗   ██╗███████╗██╗   ██╗ ██████╗ ██████╗ ███╗   ███╗██╗███╗   ██╗██╗██╗
# ████╗  ██║██╔════╝██║   ██║██╔════╝██╔═══██╗████╗ ████║██║████╗  ██║██║██║
# ██╔██╗ ██║█████╗  ██║   ██║██║     ██║   ██║██╔████╔██║██║██╔██╗ ██║██║██║
# ██║╚██╗██║██╔══╝  ╚██╗ ██╔╝██║     ██║   ██║██║╚██╔╝██║██║██║╚██╗██║╚═╝╚═╝
# ██║ ╚████║███████╗ ╚████╔╝ ╚██████╗╚██████╔╝██║ ╚═╝ ██║██║██║ ╚████║██╗██╗
# ╚═╝  ╚═══╝╚══════╝  ╚═══╝   ╚═════╝ ╚═════╝ ╚═╝     ╚═╝╚═╝╚═╝  ╚═══╝╚═╝╚═╝
#
#                         neomnia.net — Neomnia
#
echo:  Script : /var/scripts/precheck.sh
echo:  Auteur : Charles Van den driessche - Neomnia (neomnia.net)
# Usage  : Doit être exécuté en tant que root.
# Objet  : Vérifier les prérequis pour Kubesphere sur Ubuntu 22.04 / 24.04.
#--------------------------------------------------------------------------------

# Redirige sortie standard et erreurs vers un fichier de log horodaté
exec > >(tee -a /var/log/kubesphere-precheck-$(date +%F_%H-%M-%S).log) 2>&1

set -euo pipefail

# Fonctions de journalisation et d’erreur
log()  { printf "\e[1;34m[CHECK]\e[0m %s\n" "$*"; }
fail() { printf "\e[1;31m[FAIL]\e[0m  %s\n" "$*"; exit 1; }

# Vérifier l’utilisateur (doit être root)
log "Utilisateur = $(id -u)"
[[ "$(id -u)" -eq 0 ]] || fail "Exécutez ce script en tant que root."

# Vérifier la présence du dossier /var/scripts et le créer si nécessaire
if [[ ! -d /var/scripts ]]; then
  log "Création du répertoire /var/scripts"
  mkdir -p /var/scripts
fi

# Détection de la distribution et version
OS=$(lsb_release -is) 
VER=$(lsb_release -rs)
log "OS détecté = $OS $VER"
if [[ "$OS" != "Ubuntu" || ! "$VER" =~ ^(22|24)\.04$ ]]; then
  fail "Ubuntu 22.04 ou 24.04 requis. Système actuel : $OS $VER"
fi

# Vérifier que le swap est désactivé
log "Vérification que le swap est désactivé"
if swapon --summary | grep -q .; then
  fail "Le swap est encore actif. Désactivez-le avant d'exécuter ce script."
fi

# Vérifier les modules noyau nécessaires
log "Vérification des modules noyau requis (overlay, br_netfilter)"
for module in overlay br_netfilter; do
  if ! lsmod | grep -q "^$module"; then
    fail "Module noyau absent : $module"
  fi
done

# Vérifier les paramètres sysctl essentiels
log "Vérification des paramètres sysctl essentiels"
required_sysctls=(
  net.bridge.bridge-nf-call-iptables
  net.bridge.bridge-nf-call-ip6tables
  net.ipv4.ip_forward
)

for key in "${required_sysctls[@]}"; do
  value=$(sysctl -n "$key")
  if [[ "$value" -ne 1 ]]; then
    fail "Paramètre sysctl incorrect : $key = $value (doit être 1)"
  fi
done

# Vérifier la connectivité Internet sortante
log "Vérification de la connectivité Internet sortante"
if ! curl -fs https://github.com >/dev/null; then
  fail "Pas d'accès Internet sortant (impossible d'atteindre https://github.com)."
fi

echo -e "\e[1;32m✔ Pré-vérifications terminées : tout est OK.\e[0m"
