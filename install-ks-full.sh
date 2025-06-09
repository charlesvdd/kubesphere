#!/usr/bin/env bash
set -euo pipefail

### Variables à ajuster si besoin ###
K3S_VERSION="v1.33.1+k3s1"
KS_VERSION="v3.4.1"
STORAGE_CLASS=""        # Laisser vide pour défaut, ou nommez votre StorageClass
SWAP_SIZE_GB=4          # Taille du swap à créer
###############################################################################

echo -e "\n🚀 Début du déploiement complet K3s + KubeSphere ${KS_VERSION} Full Package\n"

# 1️⃣ Mise à jour & dépendances
echo "1️⃣ Mise à jour de l’OS et installation des dépendances..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl apt-transport-https vim git ca-certificates

# 2️⃣ Swap
echo "2️⃣ Configuration du swap (${SWAP_SIZE_GB} Go)…"
if ! swapon --show | grep -q '/swapfile'; then
  sudo fallocate -l ${SWAP_SIZE_GB}G /swapfile
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
else
  echo "→ Swap déjà configuré, on passe."
fi

# 3️⃣ containerd
echo "3️⃣ Installation et configuration de containerd..."
sudo apt install -y containerd
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo systemctl restart containerd
sudo systemctl enable containerd

# 4️⃣ k3s
echo "4️⃣ Installation de k3s ${K3S_VERSION} (single-node)…"
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="${K3S_VERSION}" sh -s - \
  --disable traefik \
  --kubelet-arg="eviction-hard=imagefs.available<15%,nodefs.available<15%"

# 5️⃣ kubectl context
echo "5️⃣ Configuration de kubectl pour l’utilisateur courant…"
mkdir -p $HOME/.kube
sudo cp /etc/rancher/k3s/k3s.yaml $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
export KUBECONFIG=$HOME/.kube/config

# 6️⃣ Préparation du manifest KubeSphere
echo "6️⃣ Préparation du manifest KubeSphere v${KS_VERSION}…"
VPS_IP=$(hostname -I | awk '{print $1}')
echo "   → IP détectée : ${VPS_IP}"

KS_CFG_URL="https://raw.githubusercontent.com/kubesphere/ks-installer/${KS_VERSION}/deploy/cluster-configuration.yaml"
curl -fsSL "$KS_CFG_URL" -o cluster-configuration.yaml

# Patch IP et StorageClass
sed -i -E "
  s#(endpointIps:) .*#\1 ${VPS_IP}#;
  s#(storageClass:).*#\1 \"${STORAGE_CLASS}\"#g
" cluster-configuration.yaml

# 7️⃣ Déploiement
echo "7️⃣ Déploiement de KubeSphere…"
kubectl apply -f https://github.com/kubesphere/ks-installer/releases/download/${KS_VERSION}/kubesphere-installer.yaml
kubectl apply -f cluster-configuration.yaml

echo -e "\n✅ Installation lancée. Surveillez les logs pour suivre la progression :"
echo "   kubectl logs -n kubesphere-system \$(kubectl get pod -n kubesphere-system -l app=ks-install -o jsonpath='{.items[0].metadata.name}') -f"
echo -e "\nAccès UI : http://${VPS_IP}:30880 (user: admin / pwd: P@88w0rd)\n"
