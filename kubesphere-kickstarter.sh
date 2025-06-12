#!/usr/bin/env bash
# install_kubesphere.sh
# Installation script for MicroK8s (v1.28.0) and KubeSphere 4.1.3 via Helm (ks-core chart v1.1.4)

set -euo pipefail

# Ensure UNIX line endings (avoid \r issues)
if command -v dos2unix &>/dev/null; then
    dos2unix "$0" &>/dev/null || true
fi

# Prompt for project directory name
echo -n "Enter a project name (directory will be '~/kubesphere-<name>'): "
read -r PROJECT_NAME
INSTALL_DIR="$HOME/kubesphere-$PROJECT_NAME"

# Prompt for KubeSphere instance (release) name
echo -n "Enter a name for your KubeSphere instance (Helm release name, default 'kubesphere'): "
read -r RELEASE_NAME_INPUT
RELEASE_NAME=${RELEASE_NAME_INPUT:-kubesphere}

# Fixed namespace required by Helm chart
NAMESPACE="kubesphere-system"
CHART=ks-core
CHART_VER=1.1.4

# Create and move to install directory
echo "🔄 Creating install directory: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"
echo "✅ Directory ready."

echo "Project: $PROJECT_NAME"
echo "Instance (release) name: $RELEASE_NAME"
echo "Namespace: $NAMESPACE"

# 1) Install MicroK8s if missing
echo "\n1) Installing MicroK8s v1.28.0..."
if ! snap list microk8s &>/dev/null; then
    sudo snap install microk8s --classic --channel=1.28/stable
else
    echo "   MicroK8s already installed."
fi

# Add current user to microk8s group
USER=$(whoami)
echo "🔄 Adding $USER to microk8s group..."
sudo usermod -aG microk8s "$USER"
echo "   ⚠️ Please run 'newgrp microk8s' or re-login to apply."

# Configure kubeconfig
echo "🔄 Configuring kubeconfig..."
mkdir -p "$HOME/.kube"
sudo microk8s config > "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"

# Enable addons
echo "🔄 Enabling MicroK8s addons: dns, hostpath-storage, ingress, rbac..."
sudo microk8s enable dns hostpath-storage ingress rbac

# Wait for node to be ready
echo "⏳ Waiting for MicroK8s node Ready..."
until sudo microk8s kubectl get nodes --no-headers 2>/dev/null | grep -q "Ready"; do
    sleep 5
    echo "   still waiting..."
done

echo "✅ MicroK8s is Ready."

# 2) Install Helm
echo "\n2) Installing Helm 3..."
if ! command -v helm &>/dev/null; then
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
    echo "   Helm already installed: $(helm version --short)"
fi

echo "✅ Helm is ready."

# 3) Deploy KubeSphere via Helm
echo "\n3) Deploying KubeSphere $CHART_VER as release '$RELEASE_NAME' into namespace $NAMESPACE..."
helm repo add kubesphere https://charts.kubesphere.io/main
helm repo update

microk8s kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | microk8s kubectl apply -f -

helm install "$RELEASE_NAME" kubesphere/$CHART \
  --namespace "$NAMESPACE" \
  --version "$CHART_VER" \
  --wait

echo "✅ Helm release '$RELEASE_NAME' installed in namespace '$NAMESPACE'."

echo "Waiting for all pods to be Running..."
until [ "$(microk8s kubectl get pods -n "$NAMESPACE" --no-headers | awk '{print $3}' | grep -cv Running)" -eq 0 ]; do
    sleep 5
    echo "   Waiting for pods..."
done

echo "✅ All KubeSphere pods are Running."

# 4) Expose console
echo "\n4) Setting up port-forward for KubeSphere console..."
microk8s kubectl -n "$NAMESPACE" port-forward svc/ks-console 30880:80 &
echo "✅ Port-forward established."

# 5) Display access details
echo -e "\n🎉 Installation complete!"
echo "Access the console at: http://localhost:30880" 
echo "If remote, replace 'localhost' with your server IP or hostname."
echo -e "Login credentials:\n  Username: admin\n  Password: P@88w0rd\n(please change after first login)"
