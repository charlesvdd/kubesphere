#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# install.sh – Kubernetes 1.24 + KubeSphere 3.3.x sur Ubuntu 22.04/24.04
# © 2025 Charles van den Driessche – Neomnia
#
# • Purge anciens dépôts Kubernetes xenial
# • Détection automatique des miroirs (deb.k8s.io → pkgs.k8s.io → aliyun)
# • Gestion clés GPG miroirs
# • Déploiement Local-Path provisioner & StorageClass par défaut
# • Suppression des taints control-plane pour cluster single-node
# • Logging complet dans /var/log/kubesphere-install-<DATE>.log
# -----------------------------------------------------------------------------
set -euo pipefail
exec > >(tee -a "/var/log/kubesphere-install-$(date +%F_%H-%M-%S).log") 2>&1

# ----------------------- Bannière ASCII -----------------------
cat << 'EOF'
   ██╗  ██╗██╗   ██╗███████╗███████╗███████╗██████╗ ███████╗██████╗ 
   ██║ ██╔╝██║   ██║██╔════╝██╔════╝██╔════╝██╔══██╗██╔════╝██╔══██╗
   █████╔╝ ██║   ██║█████╗  █████╗  █████╗  ██████╔╝█████╗  ██████╔╝
   ██╔═██╗ ██║   ██║██╔══╝  ██╔══╝  ██╔══╝  ██╔══██╗██╔══╝  ██╔══██╗
   ██║  ██╗╚██████╔╝██║     ███████╗███████╗██║  ██║███████╗██║  ██║
   ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚══════╝╚══════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝

    ██████╗ ██╗   ██╗██╗███████╗███████╗██████╗  ██████╗██╗     ███████╗
   ██╔═══██╗██║   ██║██║██╔════╝██╔════╝██╔══██╗██╔════╝██║     ██╔════╝
   ██║   ██║██║   ██║██║█████╗  █████╗  ██████╔╝██║     ██║     ███████╗
   ██║   ██║██║   ██║██║██╔══╝  ██╔══╝  ██╔══██╗██║     ██║     ╚════██║
   ╚██████╔╝╚██████╔╝██║███████╗███████╗██║  ██║╚██████╗███████╗███████║
    ╚═════╝  ╚═════╝ ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝ ╚═════╝╚══════╝╚══════╝

                         Installation Kubernetes + KubeSphere
EOF
echo ""

POD_CIDR="10.233.0.0/18"
K8S_VER="1.24.17-00"    # dernière 1.24.x disponible

log()  { printf "\e[1;34m[INFO]\e[0m  %s\n" "$*"; }
fail() { printf "\e[1;31m[FAIL]\e[0m  %s\n" "$*\n" >&2; exit 1; }

log "Prise en compte des paramètres…"

# -----------------------------------------------------------
# 0. Pré-requis de base (swap, modules, paquets)
# -----------------------------------------------------------
log "Désactivation du swap"
swapoff -a || true
sed -i '/swap/ s/^/#/' /etc/fstab

log "Chargement des modules noyau nécessaires"
cat >/etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF
modprobe overlay || true
modprobe br_netfilter || true

log "Configuration sysctl pour Kubernetes"
cat >/etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system

log "Installation des paquets de base"
apt update
DEBIAN_FRONTEND=noninteractive apt install -y \
  apt-transport-https ca-certificates curl gnupg lsb-release ufw \
  bash-completion net-tools software-properties-common

# -----------------------------------------------------------
# 1. Purge d'anciens dépôts Kubernetes
# -----------------------------------------------------------
log "Purge des anciens dépôts Kubernetes"
find /etc/apt/sources.list.d -type f -name '*kubernetes*.list' -delete || true
sed -i '/kubernetes/d' /etc/apt/sources.list || true

# -----------------------------------------------------------
# 2. Détection miroir Kubernetes + clés GPG
# -----------------------------------------------------------
log "Détection automatique du miroir Kubernetes et récupération de la clé GPG"
mkdir -p /etc/apt/keyrings

declare -A MIRRORS
MIRRORS[debk8s]="https://deb.k8s.io/ kubernetes-xenial main|google"
MIRRORS[pkgs]="https://pkgs.k8s.io/core/stable/v1.24/deb/ /|google"
MIRRORS[aliyun]="https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main|aliyun"

CHOSEN_URL=""
CHOSEN_KEY=""

for key in debk8s pkgs aliyun; do
  IFS='|' read -r URL KEY <<< "${MIRRORS[$key]}"
  TEST_URL="$(awk '{print $1}' <<< "$URL")dists/kubernetes-xenial/Release"
  echo -n "  → Test miroir $key… "
  if curl -fs --connect-timeout 5 "$TEST_URL" >/dev/null; then
    CHOSEN_URL="$URL"
    CHOSEN_KEY="$KEY"
    echo -e "\e[1;32mOK\e[0m"
    break
  else
    echo -e "\e[1;33mNON\e[0m"
  fi
done

[[ -n "$CHOSEN_URL" ]] || fail "Aucun dépôt Kubernetes accessible."

if [[ "$CHOSEN_KEY" == "google" ]]; then
  curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
    | gpg --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg
  KEYFILE=/etc/apt/keyrings/kubernetes-archive-keyring.gpg
else
  curl -fsSL https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg \
    | gpg --dearmor -o /etc/apt/keyrings/kubernetes-aliyun.gpg
  KEYFILE=/etc/apt/keyrings/kubernetes-aliyun.gpg
fi

echo "deb [signed-by=$KEYFILE] $CHOSEN_URL" >/etc/apt/sources.list.d/kubernetes.list

# -----------------------------------------------------------
# 3. Installation containerd + binaires Kubernetes
# -----------------------------------------------------------
log "Ajout du dépôt Docker pour containerd"
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  >/etc/apt/sources.list.d/docker.list

log "Installation de containerd"
apt update
DEBIAN_FRONTEND=noninteractive apt install -y containerd.io
mkdir -p /etc/containerd
containerd config default >/etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd && systemctl enable containerd

log "Installation de kubelet, kubeadm, kubectl"
DEBIAN_FRONTEND=noninteractive apt install -y \
  kubelet="${K8S_VER}" kubeadm="${K8S_VER}" kubectl="${K8S_VER}"
apt-mark hold kubelet kubeadm kubectl

# -----------------------------------------------------------
# 4. Initialisation du cluster control-plane
# -----------------------------------------------------------
log "Initialisation du cluster control-plane avec kubeadm"
kubeadm init \
  --pod-network-cidr="${POD_CIDR}" \
  --cri-socket=unix:///run/containerd/containerd.sock

log "Configuration de kubectl pour l’utilisateur courant"
mkdir -p "$HOME/.kube"
cp -i /etc/kubernetes/admin.conf "$HOME/.kube/config"
chmod 600 "$HOME/.kube/config"

# -----------------------------------------------------------
# 5. Déploiement de Calico (CNI)
# -----------------------------------------------------------
log "Déploiement de Calico (CNI)"
curl -sSL https://docs.projectcalico.org/manifests/calico.yaml \
  | sed "s#192.168.0.0/16#${POD_CIDR}#" \
  | kubectl apply -f -

# -----------------------------------------------------------
# 6. Provisioner local-path + StorageClass par défaut
# -----------------------------------------------------------
log "Déploiement du provisioner local-path et définition comme StorageClass par défaut"
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
kubectl patch storageclass local-path \
  -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# -----------------------------------------------------------
# 7. Retrait des taints control-plane (single-node)
# -----------------------------------------------------------
log "Retrait des taints control-plane (cluster single-node)"
kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true
kubectl taint nodes --all node-role.kubernetes.io/master- || true

# -----------------------------------------------------------
# 8. Déploiement de KubeSphere 3.3.2
# -----------------------------------------------------------
log "Déploiement de KubeSphere 3.3.2"
kubectl apply -f https://github.com/kubesphere/ks-installer/releases/download/v3.3.2/kubesphere-installer.yaml
kubectl apply -f https://github.com/kubesphere/ks-installer/releases/download/v3.3.2/cluster-configuration.yaml

echo ""
log "ks-installer lancé — suivez le log avec :"
echo "    kubectl logs -f -n kubesphere-system \$(kubectl get pod -n kubesphere-system -l app=ks-installer -o name)"
echo ""

wait_for() {
  local label="$1" ns="$2" selector="$3"
  echo -n "[INFO] Attente de $label… "
  until kubectl get pod -n "$ns" -l "$selector" 2>/dev/null | grep -q "Running"; do
    echo -n "."; sleep 5
  done
  echo -e " \e[1;32mOK\e[0m"
}

wait_for "Calico"       kube-system       "k8s-app=calico-node"
wait_for "ks-installer" kubesphere-system "app=ks-installer"

cat << 'EOF'

#####################################################
###            KubeSphere est opérationnel !      ###
#####################################################
Console : http://$(hostname -I | awk '{print $1}'):30880
Compte : admin
Password: P@88w0rd
EOF

# -----------------------------------------------------------
# 9. Configuration pare-feu UFW (port 22 + 30880)
# -----------------------------------------------------------
log "Configuration du pare-feu UFW"
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 30880/tcp
ufw --force enable

echo ""
log "Installation terminée avec succès !"
echo ""
