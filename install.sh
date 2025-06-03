#!/usr/bin/env bash
# -----------------------------------------------------------------------------
#  Updated install.sh â€“ KubernetesÂ 1.24 + KubeSphereÂ 3.3.x on UbuntuÂ 22.04/24.04
#  * Purge anciens dÃ©pÃ´ts Kubernetes xâ€‘enial
#  * DÃ©tection automatique des miroirs (deb.k8s.io â†’ pkgs.k8s.io â†’ aliyun)
#  * Gestion clÃ©s GPG miroirs
#  * DÃ©ploiement Localâ€‘Path provisioner & StorageClass par dÃ©faut
#  * Suppression des taints controlâ€‘plane pour cluster singleâ€‘node
#  * Logging complet dans /var/log/kubesphere-installâ€‘<DATE>.log
# -----------------------------------------------------------------------------
set -euo pipefail
exec > >(tee -a "/var/log/kubesphere-install-$(date +%F_%H-%M-%S).log") 2>&1

POD_CIDR="10.233.0.0/18"
K8S_VER="1.24.17-00"    # derniÃ¨re 1.24.x disponible sur tous les miroirs

###########################################################
### 0. PrÃ©â€‘requis de base (swap, modules, packages)     ###
###########################################################

# DÃ©sactivation du swap
swapoff -a || true
sed -i '/swap/ s/^/#/' /etc/fstab

# Modules noyau nÃ©cessaires
cat >/etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF
modprobe overlay || true
modprobe br_netfilter || true

# ParamÃ¨tres sysctl pour Kubernetes
cat >/etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system

apt update && apt install -y apt-transport-https ca-certificates curl gnupg lsb-release ufw bash-completion net-tools

###########################################################
### 1. Purge d'anciens dÃ©pÃ´ts Kubernetes                ###
###########################################################
find /etc/apt/sources.list.d -type f -name '*kubernetes*.list' -delete || true
sed -i '/kubernetes/d' /etc/apt/sources.list || true

###########################################################
### 2. DÃ©tection miroir Kubernetes + clÃ© GPG            ###
###########################################################
mkdir -p /etc/apt/keyrings

declare -A MIRRORS=(
  [debk8s]="https://deb.k8s.io/ kubernetes-xenial main|google"
  [pkgs]  ="https://pkgs.k8s.io/core/stable/v1.24/deb/ /|google"
  [aliyun]="https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main|aliyun"
)
CHOSEN_URL=""
CHOSEN_KEY=""
for key in debk8s pkgs aliyun; do
  IFS='|' read -r URL KEY <<< "${MIRRORS[$key]}"
  TEST_URL=$(awk '{print $1}' <<< "$URL")"dists/kubernetes-xenial/Release"
  echo "[INFO] Test $key â€¦ ($TEST_URL)"
  if curl -fs --connect-timeout 5 "$TEST_URL" >/dev/null; then
    CHOSEN_URL="$URL"
    CHOSEN_KEY="$KEY"
    echo "[OK]  $key retenu"
    break
  else
    echo "[WARN] $key indisponible"
  fi
done
if [[ -z "$CHOSEN_URL" ]]; then
  echo "[FATAL] Aucun dÃ©pÃ´t Kubernetes accessible." >&2
  exit 1
fi

if [[ "$CHOSEN_KEY" == "google" ]]; then
  curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg |
    gpg --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg
  KEYFILE=/etc/apt/keyrings/kubernetes-archive-keyring.gpg
else # aliyun
  curl -fsSL https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg |
    gpg --dearmor -o /etc/apt/keyrings/kubernetes-aliyun.gpg
  KEYFILE=/etc/apt/keyrings/kubernetes-aliyun.gpg
fi

echo "deb [signed-by=$KEYFILE] $CHOSEN_URL" >/etc/apt/sources.list.d/kubernetes.list

###########################################################
### 3. Installation containerd + Kubernetes binaries    ###
###########################################################

# containerd
curl -fsSL https://download.docker.com/linux/ubuntu/gpg |
  gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  >/etc/apt/sources.list.d/docker.list

apt update
apt install -y containerd.io
mkdir -p /etc/containerd
containerd config default >/etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd && systemctl enable containerd

# Kubernetes bins
apt install -y kubelet=${K8S_VER} kubeadm=${K8S_VER} kubectl=${K8S_VER}
apt-mark hold kubelet kubeadm kubectl

###########################################################
### 4. Init cluster control-plane                       ###
###########################################################

kubeadm init \
  --pod-network-cidr=${POD_CIDR} \
  --cri-socket=unix:///run/containerd/containerd.sock

mkdir -p $HOME/.kube && cp /etc/kubernetes/admin.conf $HOME/.kube/config

###########################################################
### 5. CNI Calico                                       ###
###########################################################

curl -sSL https://docs.projectcalico.org/manifests/calico.yaml |
  sed "s#192.168.0.0/16#${POD_CIDR}#" | kubectl apply -f -

###########################################################
### 6. StorageClass Localâ€‘Path (default)                ###
###########################################################

kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
# Patch pour rendre default
kubectl patch storageclass local-path \
  -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

###########################################################
### 7. Retrait taint controlâ€‘plane (singleâ€‘node)        ###
###########################################################

kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true
kubectl taint nodes --all node-role.kubernetes.io/master- || true

###########################################################
### 8. DÃ©ploiement KubeSphere 3.3.2                     ###
###########################################################

kubectl apply -f https://github.com/kubesphere/ks-installer/releases/download/v3.3.2/kubesphere-installer.yaml
kubectl apply -f https://github.com/kubesphere/ks-installer/releases/download/v3.3.2/cluster-configuration.yaml

echo "[INFO] ks-installer lancÃ© â€” suivez le log avec :"
echo "       kubectl logs -f -n kubesphere-system \$(kubectl get pod -n kubesphere-system -l app=ks-installer -o name)"

auto_wait() {
  echo -n "[INFO] Attente de $1 â€¦"
  until kubectl get pod -n "$2" -l "$3" 2>/dev/null | grep -q "Running"; do
    echo -n "."; sleep 5;
  done; echo " OK";
}

auto_wait "Calico" kube-system "k8s-app=calico-node"
auto_wait "ks-installer" kubesphere-system "app=ks-installer"

echo "\n#####################################################"
echo "###              Welcome to KubeSphere!        ###"
echo "#####################################################"
echo "Console : http://$(hostname -I | awk '{print $1}'):30880"
echo "Compte  : admin"
echo "Password: P@88w0rd"
echo "NOTES : 1) Changez le mot de passe aprÃ¨s connexion."
echo "        2) Patientez jusqu'Ã  ce que tous les pods   "
echo "           KubeSphere passent en Running.          "
echo "#####################################################"

###########################################################
### 9. Pareâ€‘feu UFW (port 22 + 30880)                   ###
###########################################################

ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 30880/tcp
ufw --force enable

echo "[SUCCESS] Installation terminÃ©e."
