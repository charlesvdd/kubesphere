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
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $*" | tee -a "\${LOG_FILE:-install.log}"
}

# Afficher les informations de démarrage
echo "[START] \$SCRIPT_NAME v\$VERSION"
echo "[INFO] Auteur: \$AUTHOR"
echo "[INFO] Début de l'exécution du script..."

# Vérification et correction des problèmes de dpkg
log "Vérification et correction des problèmes de dpkg"
sudo dpkg --configure -a
sudo apt-get install -f -y

# Récupération de la dernière version stable de Kubernetes
log "Récupération de la dernière version stable de Kubernetes"
LATEST_K8S_VERSION=\$(curl -fsSL https://storage.googleapis.com/kubernetes-release/release/stable.txt)
LATEST_K8S_VERSION="\${LATEST_K8S_VERSION#v}"

# Versions (paramètres ou dernières versions)
K8S_VERSION="\${1:-\${LATEST_K8S_VERSION}}"
KUBESPHERE_VERSION="\${2:-v3.5.0}"
LOG_FILE="install-\$(date +%Y%m%d%H%M%S).log"

# Installation des dépendances
log "Installation des dépendances"
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release

# Installation de kubectl
log "Installation de kubectl"
curl -LO "https://dl.k8s.io/release/\$K8S_VERSION/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Installation de containerd et des outils
log "Installation de containerd et des outils"
sudo apt-get install -y containerd.io

# Configuration de containerd
log "Configuration de containerd"
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
sudo systemctl restart containerd

# Initialisation du cluster maître Kubernetes
log "Initialisation du cluster maître Kubernetes"
sudo kubeadm init --kubernetes-version="v\${K8S_VERSION}" --pod-network-cidr=10.244.0.0/16 | tee -a "\${LOG_FILE}"

# Configuration de kubectl pour l'utilisateur actuel
log "Configuration de kubectl pour l'utilisateur actuel"
mkdir -p \$HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):\$(id -g) \$HOME/.kube/config

# Déploiement du réseau Pod (Flannel)
log "Déploiement du réseau Pod (Flannel)"
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

# Installation de KubeSphere
log "Installation de KubeSphere \${KUBESPHERE_VERSION}"
kubectl apply -f https://github.com/kubesphere/kubesphere/releases/download/\${KUBESPHERE_VERSION}/kubesphere-installer.yaml

# Application du manifest de surcharge pour activer tous les plugins
log "Application du manifest de surcharge pour KubeSphere"
cat <<EOF | kubectl apply -f -
apiVersion: installer.kubesphere.io/v1alpha1
kind: ClusterConfiguration
metadata:
  name: ks-installer
  namespace: kubespere-system
  labels:
    version: \${KUBESPHERE_VERSION}
spec:
  persistence:
    storageClass: ""
  authentication:
    jwtSecret: ""
  zone: ""
  local_registry: ""
  common:
    redis:
      enabled: true
    openldap:
      enabled: true
    minio:
      enabled: true
    mysql:
      enabled: true
    etcd:
      enabled: true
  console:
    enableMultiLogin
