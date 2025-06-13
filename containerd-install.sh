#!/bin/bash
set -e

LOG_FILE="logs/install.log"
mkdir -p logs

### Vérifier si root
if [[ "$EUID" -ne 0 ]]; then
  echo "❌ Ce script doit être exécuté en root." | tee -a "$LOG_FILE"
  exit 1
fi

log() {
  echo -e "\n🛠️  $1" | tee -a "$LOG_FILE"
}

log "1. Préparation de l’environnement"
apt-get update && apt-get install -y apt-transport-https curl gnupg lsb-release ca-certificates software-properties-common | tee -a "$LOG_FILE"

log "2. Installation de containerd"
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list

apt-get update
apt-get install -y containerd.io | tee -a "$LOG_FILE"

log "3. Configuration de containerd avec cgroup=systemd"
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd && systemctl enable containerd

log "4. Désactivation du swap & configuration sysctl"
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab
cat <<EOF > /etc/sysctl.d/kubernetes.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system | tee -a "$LOG_FILE"

log "5. Installation de kubeadm, kubelet, kubectl (v1.28.0)"
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - | tee -a "$LOG_FILE"
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install -y kubelet=1.28.0-00 kubeadm=1.28.0-00 kubectl=1.28.0-00
apt-mark hold kubelet kubeadm kubectl

log "6. Initialisation du cluster Kubernetes"
kubeadm init \
  --kubernetes-version=1.28.0 \
  --pod-network-cidr=10.244.0.0/16 \
  --cri-socket=unix:///run/containerd/containerd.sock | tee -a "$LOG_FILE"

log "7. Configuration kubectl pour root"
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

log "8. Installation du plugin réseau Flannel"
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml | tee -a "$LOG_FILE"

echo -e "\n✅ Installation terminée. Utilisez 'kubectl get pods -A' pour vérifier le cluster." | tee -a "$LOG_FILE"
