#!/usr/bin/env bash
set -euo pipefail

# === CONFIGURATION ===
K8S_VERSION="1.28.0-00"
KUBESPHERE_VERSION="v3.4.1"
CNI_YAML="https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml"

# === 1. Préparation du système ===
echo "🔧 Mise à jour et installation des paquets de base..."
sudo apt-get update && sudo apt-get install -y apt-transport-https ca-certificates curl gpg lsb-release

# Ajout du dépôt Kubernetes
echo "📦 Ajout du dépôt Kubernetes..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Installation kubeadm/kubelet/kubectl + containerd
echo "📦 Installation de Kubernetes $K8S_VERSION et containerd..."
sudo apt-get update
sudo apt-get install -y kubelet=$K8S_VERSION kubeadm=$K8S_VERSION kubectl=$K8S_VERSION containerd
sudo apt-mark hold kubelet kubeadm kubectl

# Configuration containerd
echo "⚙️  Configuration de containerd..."
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo systemctl restart containerd

# Désactivation du swap
echo "🔒 Désactivation du swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# === 2. Initialisation du cluster ===
echo "🚀 Initialisation du cluster Kubernetes..."
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --kubernetes-version=1.28.0

# === 3. Configuration de kubectl ===
echo "🔍 Configuration de kubectl pour l'utilisateur courant..."
if [[ "$EUID" -eq 0 ]]; then
  USER_HOME=$(eval echo ~${SUDO_USER:-$USER})
  USER_NAME=${SUDO_USER:-$USER}
else
  USER_HOME=$HOME
  USER_NAME=$USER
fi

mkdir -p "$USER_HOME/.kube"
sudo cp /etc/kubernetes/admin.conf "$USER_HOME/.kube/config"
sudo chown $(id -u "$USER_NAME"):$(id -g "$USER_NAME") "$USER_HOME/.kube/config"

echo "✅ kubeconfig configuré pour $USER_NAME"

# === 4. Installation de Flannel (réseau CNI) ===
echo "🌐 Installation de Flannel CNI..."
kubectl apply -f "$CNI_YAML"

# Attente que le nœud soit prêt
echo "⏳ Attente de la disponibilité du noeud..."
until kubectl get nodes | grep -q " Ready "; do
  echo "⌛ En attente du noeud..."
  sleep 5
done

# === 5. Installation de KubeSphere ===
echo "🎯 Installation de KubeSphere version $KUBESPHERE_VERSION..."
kubectl apply -f "https://github.com/kubesphere/ks-installer/releases/download/${KUBESPHERE_VERSION}/kubesphere-installer.yaml"
kubectl apply -f "https://github.com/kubesphere/ks-installer/releases/download/${KUBESPHERE_VERSION}/cluster-configuration.yaml"

# === FIN ===
echo ""
echo "✅ Installation terminée avec succès !"
echo "📡 Suis les pods avec : kubectl get pods -A"
echo "📦 KubeSphere sera disponible après quelques minutes selon les ressources."
