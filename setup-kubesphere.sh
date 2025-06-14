#!/usr/bin/env bash
set -euo pipefail

K8S_VERSION="1.28.0-00"
CNI_PLUGIN="https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml"
COLOR_RESET="\e[0m"
COLOR_OK="\e[32m"
COLOR_ERR="\e[31m"
COLOR_INFO="\e[34m"

log_success() { echo -e "${COLOR_OK}[OK]${COLOR_RESET} $1"; }
log_error()   { echo -e "${COLOR_ERR}[ERREUR]${COLOR_RESET} $1"; exit 1; }
log_info()    { echo -e "${COLOR_INFO}[INFO]${COLOR_RESET} $1"; }

check_step() {
  "$@" && log_success "$*" || log_error "$*"
}

# Vérification root
if [ "$EUID" -ne 0 ]; then
  log_error "Ce script doit être exécuté en tant que root."
fi
log_success "L'exécution se fait bien en tant que root."

# Modules kernel
log_info "Activation des modules kernel requis..."
check_step modprobe overlay
check_step modprobe br_netfilter

log_info "Configuration sysctl pour Kubernetes..."
tee /etc/sysctl.d/kubernetes.conf > /dev/null <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
check_step sysctl --system

# Installer containerd
log_info "Installation de containerd..."
check_step apt-get update
check_step apt-get install -y containerd

log_info "Configuration propre de containerd..."
check_step mkdir -p /etc/containerd
check_step rm -f /etc/containerd/config.toml
check_step containerd config default | tee /etc/containerd/config.toml > /dev/null
check_step sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
check_step systemctl daemon-reexec
check_step systemctl restart containerd
check_step systemctl enable containerd

# Ajouter le dépôt Kubernetes
log_info "Ajout du dépôt Kubernetes 1.28..."
check_step curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | \
  gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /" | \
  tee /etc/apt/sources.list.d/kubernetes.list > /dev/null

check_step apt-get update
check_step apt-get install -y kubelet=${K8S_VERSION} kubeadm=${K8S_VERSION} kubectl=${K8S_VERSION}
check_step apt-mark hold kubelet kubeadm kubectl

# Initialiser le cluster
log_info "Initialisation du cluster Kubernetes..."
check_step kubeadm init --kubernetes-version=1.28.0 --pod-network-cidr=10.244.0.0/16

# Configuration utilisateur
log_info "Configuration de kubectl pour l'utilisateur..."
mkdir -p $HOME/.kube
check_step cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
check_step chown $(id -u):$(id -g) $HOME/.kube/config

# Réseau CNI (Flannel)
log_info "Installation du réseau Flannel..."
check_step kubectl apply -f "${CNI_PLUGIN}"

# Vérification du nœud
log_info "Vérification de l'état du nœud..."
until kubectl get nodes 2>/dev/null | grep -q ' Ready '; do
  echo -n "." && sleep 3
done
log_success "Le nœud principal est en état 'Ready' !"
