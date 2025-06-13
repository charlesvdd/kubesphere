#!/usr/bin/env bash

set -euo pipefail

# ───────────────────────────────
# CONFIGURATION
# ───────────────────────────────
K8S_VERSION="1.28.0-00"
KUBESPHERE_VERSION="v4.1.3"
INSTALL_DIR="/opt/k8s"
KUBESPHERE_DIR="/opt/kubesphere"

echo "[+] Starting Kubernetes $K8S_VERSION & KubeSphere $KUBESPHERE_VERSION install..."

# ───────────────────────────────
# PRÉREQUIS SYSTÈME
# ───────────────────────────────
echo "[+] Disabling swap & updating system"
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab
apt-get update && apt-get upgrade -y

echo "[+] Installing required packages"
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release socat conntrack

# ───────────────────────────────
# INSTALLATION DE CONTAINERD
# ───────────────────────────────
echo "[+] Installing containerd"
apt install -y containerd
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

# ───────────────────────────────
# INSTALLATION DE KUBERNETES
# ───────────────────────────────
echo "[+] Adding Kubernetes repo"
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] \
https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install -y kubelet=$K8S_VERSION kubeadm=$K8S_VERSION kubectl=$K8S_VERSION
apt-mark hold kubelet kubeadm kubectl

# ───────────────────────────────
# INITIALISATION DU CLUSTER
# ───────────────────────────────
echo "[+] Initializing Kubernetes cluster"
kubeadm init --pod-network-cidr=10.244.0.0/16 --kubernetes-version=$K8S_VERSION

echo "[+] Configuring kubectl for root"
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

# ───────────────────────────────
# INSTALLATION RÉSEAU (flannel)
# ───────────────────────────────
echo "[+] Installing Flannel network plugin"
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

# ───────────────────────────────
# INSTALLATION DE KUBESPHERE
# ───────────────────────────────
echo "[+] Downloading KubeSphere installer"
mkdir -p $KUBESPHERE_DIR
cd $KUBESPHERE_DIR
curl -LO https://github.com/kubesphere/ks-installer/releases/download/$KUBESPHERE_VERSION/kubesphere-installer.yaml
curl -LO https://github.com/kubesphere/ks-installer/releases/download/$KUBESPHERE_VERSION/cluster-configuration.yaml

echo "[+] Installing KubeSphere..."
kubectl apply -f kubesphere-installer.yaml
kubectl apply -f cluster-configuration.yaml

echo "[✔] Installation complete. It may take 10–15 minutes for all pods to become ready."
kubectl get pod -n kubesphere-system -w
