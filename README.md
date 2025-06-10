\#!/usr/bin/env bash

# install\_kubesphere.sh

# Installation script for MicroK8s (v1.29.15) and KubeSphere 4.1.3 via Helm (ks-core chart v1.1.4)

set -euo pipefail

# 1. Install MicroK8s using Snap

echo "🔄 Installing MicroK8s (v1.29.15) via Snap..."
sudo snap install microk8s --classic --channel=1.29/stable

# Add current user to the microk8s group for permissions

echo "🔄 Adding current user to 'microk8s' group..."
sudo usermod -aG microk8s "\$USER"
echo "   ⚠️ You may need to log out and log back in for group changes to take effect."

# Export MicroK8s kubeconfig to user’s home

echo "🔄 Configuring kubeconfig for MicroK8s..."
sudo microk8s config > \~/.kube/config
sudo chown "\$(id -u):\$(id -g)" \~/.kube/config

echo "🔄 Enabling essential MicroK8s addons: DNS, storage, ingress, RBAC..."
microk8s enable dns storage ingress rbac

# Wait until the Kubernetes node is Ready

echo "⏳ Waiting for the Kubernetes node to become Ready..."
until microk8s kubectl get nodes 2>/dev/null | grep -q "Ready"; do
echo "   ...still waiting"
sleep 5
done
echo "✅ MicroK8s is up and running."

# 2. Install Helm 3 for package management

echo "🔄 Installing Helm 3..."
curl -fsSL [https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3](https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3) | bash
echo "✅ Helm installation complete."

# 3. Deploy KubeSphere using the ks-core Helm chart

echo "🔄 Deploying KubeSphere 4.1.3 (ks-core chart v1.1.4)..."
NAMESPACE="kubesphere-system"
RELEASE\_NAME="kubesphere"
CHART\_NAME="ks-core"
CHART\_VERSION="1.1.4"

# Create namespace if it doesn't exist

microk8s kubectl create namespace "\$NAMESPACE" --dry-run=client -o yaml | microk8s kubectl apply -f -

# Add and update the KubeSphere Helm repository

helm repo add kubesphere [https://charts.kubesphere.io/main](https://charts.kubesphere.io/main)
helm repo update

# Install the chart and wait for all resources to be ready

helm install "\$RELEASE\_NAME" kubesphere/"\$CHART\_NAME"&#x20;
\--namespace "\$NAMESPACE"&#x20;
\--version "\$CHART\_VERSION"&#x20;
\--wait

echo "✅ KubeSphere 4.1.3 has been successfully deployed."

# 4. Expose the KubeSphere console via port-forwarding

echo "🔄 Setting up port-forward to access the KubeSphere console..."
microk8s kubectl -n "\$NAMESPACE" port-forward svc/ks-console 30880:80 &

echo -e "\n✅ Port-forward established: [http://localhost:30880](http://localhost:30880)"
echo "   Login with username: admin, password: P\@88w0rd (remember to change it after first login)."
echo "🎉 Installation complete!"
