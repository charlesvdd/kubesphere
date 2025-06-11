#!/usr/bin/env bash
# install_kubesphere.sh
# Installation script for MicroK8s (v1.29.15) and KubeSphere 4.1.3 via Helm (ks-core chart v1.1.4)

set -euo pipefail

# Ensure UNIX line endings (help with CRLF issues)
if command -v dos2unix &>/dev/null; then
  dos2unix "$0" &>/dev/null || true
fi

# Prompt for project name
echo -n "Enter a project name (used for installation directory): "
read -r PROJECT_NAME

# Define installation directory
INSTALL_DIR="$HOME/kubesphere-$PROJECT_NAME"
NAMESPACE="kubesphere-system"
RELEASE_NAME="kubesphere"
CHART_NAME="ks-core"
CHART_VERSION="1.1.4"

# Create install directory and navigate into it
echo "🔄 Setting up project directory at $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

echo "✅ Project directory ready: $INSTALL_DIR"
echo "✅ KubeSphere will be installed into namespace: $NAMESPACE"

echo "
1) Installing MicroK8s..."
# 1. Install MicroK8s
sudo snap install microk8s --classic --channel=1.29/stable

CURRENT_USER=$(whoami)
echo "🔄 Adding user '$CURRENT_USER' to 'microk8s' group..."
sudo usermod -aG microk8s "$CURRENT_USER"
echo "   ⚠️ Log out and log back in for group changes to apply."

echo "🔄 Configuring kubeconfig for MicroK8s..."
mkdir -p "$HOME/.kube"
sudo microk8s config > "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"

echo "🔄 Enabling MicroK8s addons: dns, storage, ingress, rbac..."
sudo microk8s enable dns storage ingress rbac

echo "⏳ Waiting for Kubernetes node to become Ready..."
until sudo microk8s kubectl get nodes --no-headers 2>/dev/null | grep -q "Ready"; do
  echo "   ...still waiting"
  sleep 5
done

echo "✅ MicroK8s is up and running."

echo "
2) Installing Helm 3..."
# 2. Install Helm
if ! command -v helm &>/dev/null; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
  echo "   Helm already installed: $(helm version --short)"
fi

echo "✅ Helm is ready."

echo "
3) Deploying KubeSphere..."
# 3. Deploy KubeSphere
helm repo add kubesphere https://charts.kubesphere.io/main
helm repo update

# Create fixed namespace
sudo microk8s kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | sudo microk8s kubectl apply -f -

helm install "$RELEASE_NAME" kubesphere/$CHART_NAME \
  --namespace "$NAMESPACE" \
  --version "$CHART_VERSION" \
  --wait

echo "✅ KubeSphere deployed into namespace '$NAMESPACE'."

echo "
4) Exposing KubeSphere console..."
# 4. Expose console
sudo microk8s kubectl -n "$NAMESPACE" port-forward svc/ks-console 30880:80 &

echo -e "\n🎉 Installation complete!"
echo "Access: http://localhost:30880"
echo "Username: admin"
echo "Password: P@88w0rd (change after first login)"
