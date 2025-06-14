#!/usr/bin/env bash
set -euo pipefail

# === CONFIGURATION ===
K8S_VERSION="1.28.0-00"
KUBESPHERE_VERSION="v3.4.1"
CNI_YAML="https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml"

# === 1. Préparation du système ===
sudo apt-get update && sudo apt-get install -y apt-transport-https ca-certificates curl gpg lsb-release

# Ajout du dépôt Kubernetes
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Installation kubeadm/kubelet/kubectl
sudo apt-get update
sudo apt-get install -y kubelet=$K8S_VERSION kubeadm=$K8S_VERSION kubectl=$K8S_VERSION containerd
sudo apt-mark hold kubelet kubeadm kubectl

# Configuration de containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo systemctl restart containerd

# Désactivation de swap (obligatoire pour kubeadm)
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# === 2. Initialisation du cluster ===
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --kubernetes-version=1.28.0

# === 3. Configuration de kubectl ===
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown "$(id -u):$(id -g)" $HOME/.kube/config

# === 4. Installation du réseau Flannel ===
kubectl apply -f $CNI_YAML

# Attente que les nœuds soient prêts
echo "⏳ Attente de la disponibilité du noeud..."
until kubectl get nodes | grep -q " Ready "; do sleep 5; done

# === 5. Installation de KubeSphere (v3.4.1) ===
kubectl apply -f https://github.com/kubesphere/ks-installer/releases/download/${KUBESPHERE_VERSION}/kubesphere-installer.yaml
kubectl apply -f https://github.com/kubesphere/ks-installer/releases/download/${KUBESPHERE_VERSION}/cluster-configuration.yaml

# Message final
echo "✅ Installation terminée !"
echo "➡️  Tu peux suivre les pods avec : kubectl get pods -A"
