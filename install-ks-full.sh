#!/usr/bin/env bash
set -euo pipefail

### Variables à ajuster ###
K3S_VERSION="v1.33.1+k3s1"
KS_VERSION="v3.4.1"
# Utiliser l'URL HTTPS pour éviter les problèmes de clé SSH
GIT_REPO="https://github.com/charlesvdd/kubesphere.git"
STORAGE_CLASS=""  # ou ton StorageClass
SWAP_SIZE_GB=4
WORKDIR="$HOME/kubesphere"
###############################################################################

echo -e "\n🚀 Déploiement K3s + KubeSphere ${KS_VERSION} Full Package\n"

# Clone ou pull du repo en HTTPS
if [ ! -d "$WORKDIR/.git" ]; then
  echo "➡️ Clonage du dépôt $GIT_REPO dans $WORKDIR"
  git clone "$GIT_REPO" "$WORKDIR"
else
  echo "➡️ Mise à jour du dépôt existant"
  cd "$WORKDIR"
  git pull origin main
fi
cd "$WORKDIR"

# 1️⃣ Mise à jour de l’OS & dépendances
echo "1️⃣ Mise à jour et installation dépendances..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl apt-transport-https vim git ca-certificates

# 2️⃣ Swap
echo "2️⃣ Configuration swap (${SWAP_SIZE_GB} Go)"
if ! swapon --show | grep -q '/swapfile'; then
  sudo fallocate -l ${SWAP_SIZE_GB}G /swapfile
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
else
  echo "→ Swap déjà configuré, on passe."
fi

# 3️⃣ Installation de containerd
echo "3️⃣ Installation containerd..."
sudo apt install -y containerd
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo systemctl restart containerd
sudo systemctl enable containerd

# 4️⃣ Installation de k3s
echo "4️⃣ Installation k3s ${K3S_VERSION}..."
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="${K3S_VERSION}" sh -s - \
  --disable traefik \
  --kubelet-arg="eviction-hard=imagefs.available<15%,nodefs.available<15%>"

# 5️⃣ Configuration kubectl
echo "5️⃣ Configuration kubectl..."
mkdir -p $HOME/.kube
sudo cp /etc/rancher/k3s/k3s.yaml $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
export KUBECONFIG=$HOME/.kube/config

# 6️⃣ Préparation du manifest KubeSphere
echo "6️⃣ Préparation manifest KubeSphere..."
VPS_IP=$(hostname -I | awk '{print $1}')
echo "   → IP détectée: $VPS_IP"
KS_CFG_URL="https://raw.githubusercontent.com/kubesphere/ks-installer/${KS_VERSION}/deploy/cluster-configuration.yaml"
curl -fsSL "$KS_CFG_URL" -o cluster-configuration.yaml

# Application du patch (IP et StorageClass)
sed -i -E "
  s#(endpointIps:) .*#\1 $VPS_IP#;
  s#(storageClass:) .*#\1 \"${STORAGE_CLASS}\"#g
" cluster-configuration.yaml

# 7️⃣ Commit & push manifest
if git status --porcelain cluster-configuration.yaml | grep -q .; then
  echo "7️⃣ Commit & push cluster-configuration.yaml"
  git add cluster-configuration.yaml
  git commit -m "Add KubeSphere cluster config with IP $VPS_IP"
  git push origin main
else
  echo "→ Pas de changements à commit"
fi

# 8️⃣ Déploiement
echo "8️⃣ Déploiement KubeSphere..."
kubectl apply -f https://github.com/kubesphere/ks-installer/releases/download/${KS_VERSION}/kubesphere-installer.yaml
kubectl apply -f cluster-configuration.yaml

echo -e "\n✅ Déploiement lancé. Suivez les logs :"
echo "kubectl logs -n kubesphere-system \$(kubectl get pod -n kubesphere-system -l app=ks-install -o jsonpath='{.items[0].metadata.name}') -f"
echo "Accès UI : http://${VPS_IP}:30880 (user: admin / pwd: P@88w0rd)"
