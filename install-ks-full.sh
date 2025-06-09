#!/usr/bin/env bash
set -euo pipefail

### Variables à ajuster ###
K3S_VERSION="v1.33.1+k3s1"
KS_VERSION="v3.4.1"
GIT_REPO="git@github.com:charlesvdd/kubesphere.git"
GIT_BRANCH="master"
STORAGE_CLASS=""
SWAP_SIZE_GB=4
WORKDIR="$HOME/kubesphere"
###############################################################################

function title() {
  echo -e "\n===== $1 ====="
}

function pre_checks() {
  title "VÉRIFICATIONS PRÉALABLES"
  echo -n "→ OS: " && lsb_release -ds
  MEM_GB=$(free -g | awk '/^Mem:/ {print $2}')
  echo "→ RAM: ${MEM_GB} Go"
  (( MEM_GB < 8 )) && echo "⚠️  Moins de 8 Go de RAM."
  swapon --show | grep -q '/swapfile' && echo "→ Swap: ok" || echo "⚠️  Pas de swap."
}

function deploy() {
  title "DÉPLOIEMENT"

  # Clone ou pull
  if [ ! -d "$WORKDIR/.git" ]; then
    echo "→ Clonage SSH de $GIT_REPO"
    git clone --branch "$GIT_BRANCH" "$GIT_REPO" "$WORKDIR"
  else
    echo "→ Mise à jour du dépôt"
    cd "$WORKDIR"
    git fetch origin "$GIT_BRANCH"
    git reset --hard "origin/$GIT_BRANCH"
  fi
  cd "$WORKDIR"

  echo "→ Mise à jour apt + dépendances"
  sudo apt update && sudo apt upgrade -y
  sudo apt install -y curl apt-transport-https vim git ca-certificates lsb-release

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
  sudo systemctl restart containerd && sudo systemctl enable containerd

  # k3s
  echo "→ Installation k3s ${K3S_VERSION}"
  curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="${K3S_VERSION}" sh -s - \
    --disable traefik --kubelet-arg="eviction-hard=imagefs.available<15%,nodefs.available<15%>"

  # kubectl config
  echo "→ Configuration kubectl"
  mkdir -p $HOME/.kube
  sudo cp /etc/rancher/k3s/k3s.yaml $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
  export KUBECONFIG=$HOME/.kube/config

  # Attente du cluster Ready
  title "ATTENTE Kubernetes Ready"
  until kubectl get nodes &> /dev/null; do
    echo "→ Waiting for Kubernetes API..."; sleep 5
  done
  until kubectl get nodes | grep -w 'Ready'; do
    echo "→ Waiting for node Ready status..."; sleep 5
  done
  echo "→ Kubernetes API is ready"

  # Manifest preparation
  echo "→ Préparation du manifest"
  VPS_IP=$(hostname -I | awk '{print $1}')
  echo "   IP détectée: $VPS_IP"
  cp cluster-configuration.yaml cluster-configuration-patched.yaml
  sed -i -E \
    -e "s#(endpointIps:) .*#\1 $VPS_IP#" \
    -e "s#(storageClass:) .*#\1 \"${STORAGE_CLASS}\"#" \
    cluster-configuration-patched.yaml

  git config user.email "autodeploy@kubesphere.local"
  git config user.name "KubeSphere AutoDeploy Bot"
  if ! diff -q cluster-configuration.yaml cluster-configuration-patched.yaml >/dev/null; then
    title "COMMIT & PUSH"
    mv cluster-configuration-patched.yaml cluster-configuration.yaml
    git add cluster-configuration.yaml
    git commit -m "Update config with IP $VPS_IP"
    git push origin "$GIT_BRANCH"
  else
    echo "→ Pas de changements dans manifest"
  fi

  # Deploy KubeSphere
  echo "→ Déploiement KubeSphere (désactivation validation OpenAPI)"
  kubectl apply --validate=false -f https://github.com/kubesphere/ks-installer/releases/download/${KS_VERSION}/kubesphere-installer.yaml
  kubectl apply -f cluster-configuration.yaml
}

function evaluation() {
  title "AUTO-ÉVALUATION"
  end=$((SECONDS + 900))
  while :; do
    if ! kubectl get pods -n kubesphere-system --no-headers | grep -E 'ContainerCreating|Pending|CrashLoopBackOff'; then break; fi
    (( SECONDS > end )) && { echo "⚠️ Timeout pods"; kubectl get pods -n kubesphere-system; exit 1; }
    sleep 10
  done
  echo "→ Pods Running ✅"
  kubectl get pods -n kubesphere-system -o wide
  echo "→ Nodes Ready"; kubectl get nodes
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$VPS_IP:30880)
  [ "$HTTP_CODE" = "200" ] && echo "UI OK" || echo "UI HTTP $HTTP_CODE"
  echo -e "\n🎉 Terminé"
}

# MAIN
pre_checks
deploy
evaluation
