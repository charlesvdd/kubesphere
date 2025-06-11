#!/usr/bin/env bash
# install_kubesphere.sh
# Installation script for MicroK8s (v1.29.15) and KubeSphere 4.1.3 via Helm (ks-core chart v1.1.4)

set -euo pipefail

# Prompt for project name
echo -n "Enter a project name (used for directory and namespace): "
read -r PROJECT_NAME

# Define installation directory
INSTALL_DIR="$HOME/kubesphere-$PROJECT_NAME"
namespace="kubesphere-$PROJECT_NAME"

# Create install directory
echo "🔄 Creating installation directory at $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

echo "✅ Using project name: $PROJECT_NAME"
echo "✅ Namespace will be: $namespace"

# 1. Install MicroK8s

echo "🔄 Installing MicroK8s (v1.29.15) via Snap..."
sudo snap install microk8s --classic --channel=1.29/stable

echo "🔄 Adding current user ($USER) to 'microk8s' group..."
sudo usermod -aG microk8s "$USER"
echo "   ⚠️ You may need to log out and log back in for group changes to take effect."

# Configure kubeconfig
echo "🔄 Configuring kubeconfig for MicroK8s..."
mkdir -p "$HOME/.kube"
sudo microk8s config > "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"

echo "🔄 Enabling essential MicroK8s addons: DNS, storage, ingress, RBAC..."
microk8s enable dns storage ingress rbac

# Wait for node readiness
echo "⏳ Waiting for Kubernetes node to become Ready..."
until microk8s kubectl get nodes --no-headers 2>/dev/null | grep -q "Ready"; do
  echo "   ...still waiting"
  sleep 5
done

echo "✅ MicroK8s is up and running."

# 2. Install Helm 3
echo "🔄 Installing Helm 3..."
if ! command -v helm &>/dev/null; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
  echo "   Helm already installed: $(helm version --short)"
fi

echo "✅ Helm installation complete."

# 3. Deploy KubeSphere via Helm
echo "🔄 Deploying KubeSphere 4.1.3 (ks-core chart v1.1.4) into namespace $namespace..."
RELEASE_NAME="kubesphere"
CHART_NAME="ks-core"
CHART_VERSION="1.1.4"

microk8s kubectl create namespace "$namespace" --dry-run=client -o yaml | microk8s kubectl apply -f -

helm repo add kubesphere https://charts.kubesphere.io/main
helm repo update

helm install "$RELEASE_NAME" kubesphere/$CHART_NAME \
  --namespace "$namespace" \
  --version "$CHART_VERSION" \
  --wait

echo "✅ KubeSphere 4.1.3 has been successfully deployed in $namespace."

# 4. Expose console

echo "🔄 Setting up port-forward to access the KubeSphere console..."
microk8s kubectl -n "$namespace" port-forward svc/ks-console 30880:80 &

# 5. First login information
echo -e "\n🎉 Installation complete!"
echo "Access the console at: http://localhost:30880"
echo "Login with username: admin"
echo "Password: P@88w0rd (change it after first login)"
