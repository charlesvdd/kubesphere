#!/bin/bash

set -e

# ========== CONFIG ==========
K3S_VERSION="v1.29.0+k3s1"
INSTALL_DIR="/usr/local/bin"
VELA_VERSION="v1.9.0" # ou la dernière compatible avec KubeSphere 4.1

echo "🚀 Installation de K3s $K3S_VERSION"
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="$K3S_VERSION" sh -

echo "✅ K3s installé"
echo "📦 Vérification du cluster..."
/usr/local/bin/kubectl get nodes

# Ajout du KUBECONFIG pour l'utilisateur root
echo "🛠 Configuration KUBECONFIG"
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# ========== Installation de Vela ==========
echo "🌐 Téléchargement de KubeVela $VELA_VERSION"
curl -fsSl https://kubevela.io/script/install.sh | bash

export PATH=$PATH:/root/.vela/bin

echo "✅ Vela installé"
vela version

echo "⏳ Initialisation de Vela dans le cluster"
vela install

# ========== Addons ==========
echo "📦 Installation des addons KubeSphere"
vela addon enable kubesphere
vela addon enable observability
vela addon enable devops
vela addon enable logging

echo "✅ Tous les composants ont été installés avec succès"
echo "🌐 Accès à l'interface KubeSphere :"
echo "   ➤ kubectl get svc -A | grep kubesphere"
