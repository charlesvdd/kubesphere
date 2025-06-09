#!/bin/bash
set -e

# ================== ROOT CHECK ==================
if [ "$(id -u)" -ne 0 ]; then
  echo "Error: This script must be run as root. Please use sudo or log in as root."
  exit 1
fi

# ================= CONFIGURATION =================
# Kubernetes upstream version (must match v1.29.13)
K8S_VERSION="1.29.13-00"
# KubeSphere version to deploy
KUBESPHERE_VERSION="v4.1.3"
# Pod network CIDR for Calico (modify if needed)
POD_NETWORK_CIDR="192.168.0.0/16"

# ================= 1. PREREQUISITES =================
echo "Updating package lists and installing dependencies..."
apt-get update
apt-get install -y apt-transport-https ca-certificates curl software-properties-common

echo "Adding Kubernetes GPG key..."
curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg \
  https://packages.cloud.google.com/apt/doc/apt-key.gpg

echo "Adding Kubernetes APT repository..."
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] \
  https://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list

# ================= 2. INSTALL KUBERNETES =================
echo "Updating package lists..."
apt-get update
echo "Installing kubeadm, kubelet, and kubectl version ${K8S_VERSION}..."
apt-get install -y kubeadm=${K8S_VERSION} kubelet=${K8S_VERSION} kubectl=${K8S_VERSION}

echo "Locking package versions..."
apt-mark hold kubeadm kubelet kubectl

# ================= 3. INITIALIZE CONTROL PLAINECHO =================
echo "Initializing Kubernetes control plane..."
kubeadm init \
  --kubernetes-version=$(echo ${K8S_VERSION} | sed 's/-00//') \
  --pod-network-cidr=${POD_NETWORK_CIDR}

echo "Setting up kubeconfig for root user..."
export KUBECONFIG=/etc/kubernetes/admin.conf

# ================= 4. INSTALL NETWORK PLUGIN =================
echo "Deploying Calico network plugin..."
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

# ================= 5. DEPLOY KUBESPHERE =================
echo "Deploying KubeSphere ${KUBESPHERE_VERSION}..."
kubectl apply -f https://github.com/kubesphere/kubesphere/releases/download/${KUBESPHERE_VERSION}/kubesphere-installer.yaml

# ================= 6. VERIFICATION =================
echo "Waiting for KubeSphere pods to be ready (timeout: 10 minutes)..."
kubectl -n kubesphere-system wait --for=condition=Ready pods --all --timeout=10m

echo "Installation complete!"
echo "To access the KubeSphere console, run:"
echo "  kubectl get svc -n kubesphere-system | grep kubesphere-console"
