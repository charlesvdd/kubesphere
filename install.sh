#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Script d'installation automatisée de Kubernetes + KubeSphere sur Ubuntu VPS
# Récupère dynamiquement la dernière version stable de Kubernetes si non précisée
# Usage : ./install.sh [K8S_VERSION] [KUBESPHERE_VERSION]
# Exemple : ./install.sh 1.27.4 v3.6.1
# Licence : MIT
# ----------------------------------------------------------------------------

set -euo pipefail

# 0) Auto-élévation pour exécution en root
if [ "$EUID" -ne 0 ]; then
  echo "This script requires root privileges. Re-running with sudo..."
  exec sudo bash "$0" "$@"
fi

log() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $*" | tee -a "${LOG_FILE:-install.log}"
}

log "Retrieving latest stable Kubernetes version"
LATEST_K8S_VERSION=$(curl -fsSL https://storage.googleapis.com/kubernetes-release/release/stable.txt)
LATEST_K8S_VERSION="${LATEST_K8S_VERSION#v}"

# 1) Versions (paramètres ou dernières versions)
K8S_VERSION="${1:-${LATEST_K8S_VERSION}}"
KUBESPHERE_VERSION="${2:-v3.5.0}"
LOG_FILE="install-$(date +%Y%m%d%H%M%S).log"

# 2) Pré-requis système
log "Disabling swap"
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

log "Loading network modules"
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF
sudo modprobe br_netfilter

log "Applying sysctl settings for Kubernetes"
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system

# 3) Installation des dépendances
log "Installing containerd and tools"
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release

log "Adding Docker repository"
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y containerd.io

log "Configuring containerd"
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
sudo systemctl restart containerd

# 4) Installation de Kubernetes
log "Adding Kubernetes repository"
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update

log "Installing kubelet kubeadm kubectl version ${K8S_VERSION}"
sudo apt-get install -y kubelet="${K8S_VERSION}-00" kubeadm="${K8S_VERSION}-00" kubectl="${K8S_VERSION}-00"
sudo apt-mark hold kubelet kubeadm kubectl

# 5) Initialisation du cluster maître
log "Initializing Kubernetes cluster"
sudo kubeadm init --kubernetes-version="v${K8S_VERSION}" --pod-network-cidr=10.244.0.0/16 | tee -a "${LOG_FILE}"

log "Setting up kubectl for current user"
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# 6) Déploiement du réseau Pod (Flannel)
log "Deploying Flannel CNI"
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

# 7) Installation de KubeSphere
log "Installing KubeSphere ${KUBESPHERE_VERSION}"
kubectl apply -f https://github.com/kubesphere/kubesphere/releases/download/${KUBESPHERE_VERSION}/kubesphere-installer.yaml

log "Waiting for KubeSphere to be ready"
kubectl wait --for=condition=ready pods -n kubesphere-system --timeout=10m | tee -a "${LOG_FILE}"

log "Installation completed. Access KubeSphere at http://<MASTER_IP>:30880"

# End of script
