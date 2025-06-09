#!/usr/bin/env bash

# Script d'installation automatisée de Kubernetes + KubeSphere sur Ubuntu VPS
# Auteur: Votre Nom
# Version: 1.0
# Licence: MIT

set -euo pipefail

# Informations de démarrage du script
SCRIPT_NAME="Installation de Kubernetes et KubeSphere"
AUTHOR="Votre Nom"
VERSION="1.0"

log() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $*" | tee -a "${LOG_FILE:-install.log}"
}

# Afficher les informations de démarrage
echo "[START] $SCRIPT_NAME v$VERSION"
echo "[INFO] Auteur: $AUTHOR"
echo "[INFO] Début de l'exécution du script..."

# Vérification et correction des problèmes de dpkg
log "Vérification et correction des problèmes de dpkg"
sudo dpkg --configure -a
sudo apt-get install -f -y

# Récupération de la dernière version stable de Kubernetes
log "Récupération de la dernière version stable de Kubernetes"
LATEST_K8S_VERSION=$(curl -fsSL https://storage.googleapis.com/kubernetes-release/release/stable.txt)
LATEST_K8S_VERSION="${LATEST_K8S_VERSION#v}"

# Versions (paramètres ou dernières versions)
K8S_VERSION="${1:-${LATEST_K8S_VERSION}}"
KUBESPHERE_VERSION="${2:-v3.5.0}"
LOG_FILE="install-$(date +%Y%m%d%H%M%S).log"

# Installation des dépendances
log "Installing containerd and tools"
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release

# Ajout du dépôt Kubernetes
log "Ajout du dépôt Kubernetes"
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update

# Installation de kubectl
log "Installation de kubectl"
sudo apt-get install -y kubectl

# Suite de votre script...
