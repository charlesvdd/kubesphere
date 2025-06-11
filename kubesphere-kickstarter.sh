#!/usr/bin/env bash
# install_kubesphere.sh
# Installation script for MicroK8s (v1.29.15) and KubeSphere 4.1.3 via Helm (ks-core chart v1.1.4)

set -euo pipefail

# Ensure UNIX line endings (help with CRLF issues)
if command -v dos2unix &>/dev/null; then
  dos2unix "$0" &>/dev/null || true
fi

# Prompt for project name
echo -n "Enter a project name (used for directory and namespace): "
read -r PROJECT_NAME

# Define installation directory
echo "🔄 Setting up project '$PROJECT_NAME'..."
INSTALL_DIR="$HOME/kubesphere-$PROJECT_NAME"
NAMESPACE="kubesphere-$PROJECT_NAME"

# Create install directory and navigate into it
echo "   Creating directory: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

echo "✅ Project directory ready: $INSTALL_DIR"
echo "✅ Kubernetes namespace: $NAMESPACE"

# 1. Install MicroK8s

echo "🔄 Installing MicroK8s (v1.29.15) via Snap..."
sudo snap install microk8s --classic --channel=1.29/stable

# Add current user to the microk8s group
CURRENT_USER=$(whoami)
echo "🔄 Adding user '$CURRENT_USER' to the 'microk8s' group..."
sudo usermod -aG microk8s "$CURRENT_USER"
echo "   ⚠️ Log out and back in for group changes to apply."

# Configure kubeconfig directory and file
echo "🔄 Configuring kubeconfig for MicroK8s..."
mkdir -p "$HOME/.kube"
sudo microk8s config > "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"

# Enable essential addons
echo "🔄 Enabling MicroK8s addons: dns, storage, ingress, rbac..."
sudo microk8s enable dns storage ingress rbac

# Wait for node readiness
echo "⏳ Waiting for Kubernetes node to become Ready..."
until sudo microk8s kubectl get nodes --no-headers 2>/dev/null | grep -q "Ready"; do
  echo "   ...still waiting"
  sleep 5
done

echo "✅ MicroK8s is up and running."

# 2. Install Helm 3 (if missing)
echo "🔄 Installing Helm 3..."
if ! command -v helm &>/dev/null; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
  echo "   Helm already installed: $(helm version --short)"
fi
echo "✅ Helm is ready."

# 3. Deploy KubeSphere via Helm
echo "🔄 Deploying KubeSphere 4.1.3 (ks-core v1.1.4) into namespace '$NAMESPACE'..."
helm repo add kubesphere https://charts.kubesphere.io/main
helm repo update

sudo microk8s kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | sudo microk8s kubectl apply -f -
helm install kubesphere kubesphere/ks-core \
  --namespace "$NAMESPACE" \
  --version 1.1.4 \
  --wait

echo "✅ KubeSphere deployed in namespace '$NAMESPACE'."

# 4. Expose KubeSphere console
echo "🔄 Setting up port-forward for KubeSphere console..."
sudo microk8s kubectl -n "$NAMESPACE" port-forward svc/ks-console 30880:80 &

# 5. Display first login details
echo -e "\n🎉 Installation complete!"
echo "Access the console at: http://localhost:30880"
echo "Username: admin"
echo "Password: P@88w0rd (please change on first login)"
