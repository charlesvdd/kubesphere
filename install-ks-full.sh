#!/usr/bin/env bash
set -euo pipefail

### Variables à ajuster ###
K3S_VERSION="v1.33.1+k3s1"
KS_VERSION="v3.4.1"
GIT_REPO="https://github.com/charlesvdd/kubesphere.git"
STORAGE_CLASS=""  # ou ton StorageClass
SWAP_SIZE_GB=4
WORKDIR="$HOME/kubesphere"
###############################################################################

# Affiche un titre coloré
function title() {
  echo -e "\n===== $1 ====="
}

# 0️⃣ Pré-vérifications
function pre_checks() {
  title "VÉRIFICATIONS PRÉALABLES"
  # OS
  echo -n "→ OS: " && lsb_release -ds
  # Mémoire
  MEM_GB=$(free -g | awk '/^Mem:/ {print $2}')
  echo "→ RAM installée: ${MEM_GB} Go"
  if (( MEM_GB < 8 )); then
    echo "⚠️  Moins de 8 Go RAM, performance réduite."
  fi
  # Swap
  if swapon --show | grep -q '/swapfile'; then
    echo "→ Swap détecté: ok"
  else
    echo "⚠️  Pas de swap détecté. Le script va créer ${SWAP_SIZE_GB}G de swap."
  fi
}

# 1️⃣ Installation complète
function deploy() {
  title "DÉPLOIEMENT"

  # Clone ou pull de ton repo
  if [ ! -d "$WORKDIR/.git" ]; then
    echo "→ Clonage de $GIT_REPO"
    git clone "$GIT_REPO" "$WORKDIR"
  else
    echo "→ Mise à jour du dépôt"
    cd "$WORKDIR"
    git pull origin main
  fi
  cd "$WORKDIR"

  # OS & dépendances
  echo "→ Mise à jour apt + dépendances"
  sudo apt update && sudo apt upgrade -y
  sudo apt install -y curl apt-transport-https vim git ca-certificates

  # Swap
  if ! swapon --show | grep -q '/swapfile'; then
    echo "→ Création swap ${SWAP_SIZE_GB}G"
    sudo fallocate -l ${SWAP_SIZE_GB}G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
  fi

  # containerd
  echo "→ Installation containerd"
  sudo apt install -y containerd
  sudo mkdir -p /etc/containerd
  sudo containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
  sudo systemctl restart containerd
  sudo systemctl enable containerd

  # k3s
  echo "→ Installation k3s ${K3S_VERSION}"
  curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="${K3S_VERSION}" sh -s - \
    --disable traefik \
    --kubelet-arg="eviction-hard=imagefs.available<15%,nodefs.available<15%>"

  # kubectl config
  echo "→ Configuration kubectl"
  mkdir -p $HOME/.kube
  sudo cp /etc/rancher/k3s/k3s.yaml $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
  export KUBECONFIG=$HOME/.kube/config

  # Manifest KubeSphere
  echo "→ Préparation manifest KubeSphere"
  VPS_IP=$(hostname -I | awk '{print $1}')
  echo "   IP détectée: $VPS_IP"
  KS_CFG_URL="https://raw.githubusercontent.com/kubesphere/ks-installer/${KS_VERSION}/deploy/cluster-configuration.yaml"
  curl -fsSL "$KS_CFG_URL" -o cluster-configuration.yaml

  sed -i -E "
    s#(endpointIps:) .*#\1 $VPS_IP#;
    s#(storageClass:) .*#\1 \"${STORAGE_CLASS}\"#g
  " cluster-configuration.yaml

  # Commit & push
  if git status --porcelain cluster-configuration.yaml | grep -q .; then
    git add cluster-configuration.yaml
    git commit -m "Add KubeSphere config with IP $VPS_IP"
    git push origin main
  fi

  # Déploiement KubeSphere
  echo "→ Déploiement KubeSphere"
  kubectl apply -f https://github.com/kubesphere/ks-installer/releases/download/${KS_VERSION}/kubesphere-installer.yaml
  kubectl apply -f cluster-configuration.yaml
}

# 2️⃣ Auto-évaluation
function evaluation() {
  title "AUTO-ÉVALUATION"
  echo "Attente des pods KubeSphere (max 15mn)…"
  end=$((SECONDS + 900))
  while true; do
    PENDING=$(kubectl get pods -n kubesphere-system --no-headers | grep -E 'ContainerCreating|Pending|CrashLoopBackOff' || true)
    if [ -z "$PENDING" ]; then
      break
    fi
    if (( SECONDS > end )); then
      echo "⚠️ Certains pods n'ont pas démarré"
      kubectl get pods -n kubesphere-system
      exit 1
    fi
    sleep 10
  done

  echo "→ Tous les pods KubeSphere sont Running ✅"
  kubectl get pods -n kubesphere-system -o wide

  echo "→ Vérification du noeud"
  kubectl get nodes

  echo "→ Vérification de l'UI"
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$VPS_IP:30880)
  if [ "$HTTP_CODE" = "200" ]; then
    echo "UI accessible sur http://$VPS_IP:30880 ✅"
  else
    echo "⚠️ UI non accessible (HTTP $HTTP_CODE)"
  fi

  echo -e "\n🎉 DÉPLOIEMENT ET VÉRIFICATIONS TERMINÉS"
}

# ====== MAIN ======
pre_checks
deploy
evaluation
